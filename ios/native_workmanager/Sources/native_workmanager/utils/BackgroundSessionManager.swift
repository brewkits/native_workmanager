import Foundation

/// Manages iOS background URLSession for downloads and uploads that survive app termination.
///
/// **Features:**
/// - Downloads/uploads continue when app is terminated
/// - No time limits (can run for hours)
/// - System-managed retry on network changes
/// - Battery-efficient scheduling
/// - Automatic app relaunch when transfers complete
///
/// **Usage:**
/// ```swift
/// let manager = BackgroundSessionManager.shared
/// let taskId = "download-123"
///
/// manager.download(
///     url: URL(string: "https://example.com/large-file.zip")!,
///     to: destinationURL,
///     taskId: taskId
/// ) { result in
///     switch result {
///     case .success(let location):
///         print("Downloaded to: \(location)")
///     case .failure(let error):
///         print("Download failed: \(error)")
///     }
/// }
/// ```
///
/// **Important:**
/// - Session identifier must match `handleEventsForBackgroundURLSession` in AppDelegate
/// - App is relaunched when transfers complete (if terminated)
/// - All completion handlers stored in memory (cleared on app termination)
@available(iOS 13.0, *)
public class BackgroundSessionManager: NSObject {

    // MARK: - Singleton

    public static let shared = BackgroundSessionManager()

    private override init() {
        super.init()
        self.session = createBackgroundSession()
        // Reconnect in-memory taskIdMap using persisted URL→taskId mappings.
        // Required when the OS relaunches the app to deliver background-session callbacks
        // after the app was terminated mid-download.
        restoreTaskIdMappings()
    }

    // MARK: - Properties

    /// Background URLSession instance
    private var session: URLSession!

    /// Session identifier (must be unique per app)
    private let sessionIdentifier = "dev.brewkits.native_workmanager.background"

    /// Stores completion handlers for active tasks (taskId -> handler)
    /// Note: Cleared when app terminates. Use persistent storage for critical state.
    private var downloadHandlers: [String: (Result<URL, Error>) -> Void] = [:]

    /// Stores upload completion handlers (taskId -> handler)
    private var uploadHandlers: [String: (Result<URLResponse, Error>) -> Void] = [:]

    /// Stores task IDs mapped to URLSessionTask identifiers (URLSessionTask.taskIdentifier -> taskId)
    private var taskIdMap: [Int: String] = [:]

    /// Thread-safe access to handlers and maps
    private let queue = DispatchQueue(label: "dev.brewkits.background_session_manager", attributes: .concurrent)

    /// Background completion handlers keyed by session identifier.
    ///
    /// iOS may deliver `urlSessionDidFinishEvents` for any session that was
    /// active when the app was last terminated, so we must store one handler
    /// per session identifier — not a single overwriting var.
    ///
    /// The backward-compatible computed property below exposes the single-session
    /// API that AppDelegate already uses; multi-session callers can call
    /// `setBackgroundCompletionHandler(_:for:)` directly.
    private var backgroundCompletionHandlers: [String: () -> Void] = [:]

    /// Backward-compatible access for the default session identifier.
    public var backgroundCompletionHandler: (() -> Void)? {
        get { queue.sync { backgroundCompletionHandlers[sessionIdentifier] } }
        set {
            queue.async(flags: .barrier) {
                if let h = newValue {
                    self.backgroundCompletionHandlers[self.sessionIdentifier] = h
                } else {
                    self.backgroundCompletionHandlers.removeValue(forKey: self.sessionIdentifier)
                }
            }
        }
    }

    /// Register a completion handler for a specific session identifier.
    /// AppDelegate should call this from `handleEventsForBackgroundURLSession`.
    public func setBackgroundCompletionHandler(_ handler: @escaping () -> Void, for identifier: String) {
        queue.async(flags: .barrier) {
            self.backgroundCompletionHandlers[identifier] = handler
        }
    }

    /// Progress delegate for reporting download/upload progress to Flutter
    public var progressDelegate: ((String, Double) -> Void)?

    /// Rich progress delegate — passes full progress dict including bytesDownloaded,
    /// totalBytes, networkSpeed (bytes/sec), and timeRemainingMs to Flutter.
    /// When set, this takes priority over `progressDelegate` for download progress.
    public var richProgressDelegate: ((String, [String: Any]) -> Void)?

    /// Resume data storage for failed downloads (taskId -> resumeData)
    private var resumeDataStorage: [String: Data] = [:]

    // MARK: - Background Relaunch Support

    /// Called when a download completes in a background-relaunch scenario — the app was
    /// killed while URLSession was active and OS relaunched it to deliver the result.
    /// The plugin sets this to forward the event to Flutter via emitTaskEvent.
    public var relaunchCompletionDelegate: ((String, Result<URL, Error>) -> Void)?

    // UserDefaults keys for persisted task registry (survives app termination).
    private let destRegistryKey = "NativeWorkManager.BGSession.destinations" // [taskId: destPath]
    private let urlRegistryKey  = "NativeWorkManager.BGSession.urls"         // [urlString: taskId]

    /// Last progress emit time per task — used to throttle rapid URLSession callbacks.
    /// Prevents flooding the Flutter bridge when downloading large files in small chunks.
    private var lastProgressTimes: [String: Date] = [:]
    private let progressThrottleInterval: TimeInterval = 0.1 // 100ms

    // Speed tracking per task (all protected by queue)
    private var speedWindowBytes: [String: Int64] = [:]
    private var speedWindowStart: [String: Date] = [:]
    private var smoothedSpeedBps: [String: Double] = [:]

    // MARK: - Session Creation

    private func createBackgroundSession() -> URLSession {
        let config = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)

        // Configure for immediate execution (not discretionary)
        config.isDiscretionary = false

        // Allow cellular downloads
        config.allowsCellularAccess = true

        // Wake app when transfers complete
        config.sessionSendsLaunchEvents = true

        // Timeout intervals
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 7 * 24 * 60 * 60 // 7 days max

        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Persistence Helpers

    /// Persist a pending download so it can be recovered after app relaunch.
    private func persistDownloadTask(taskId: String, destinationPath: String, urlString: String) {
        var dests = UserDefaults.standard.dictionary(forKey: destRegistryKey) as? [String: String] ?? [:]
        var urls  = UserDefaults.standard.dictionary(forKey: urlRegistryKey)  as? [String: String] ?? [:]
        dests[taskId]   = destinationPath
        urls[urlString] = taskId
        UserDefaults.standard.set(dests, forKey: destRegistryKey)
        UserDefaults.standard.set(urls,  forKey: urlRegistryKey)
    }

    /// Remove a task from the persistent registry (called in cleanup).
    private func removePersistedTask(taskId: String) {
        var dests = UserDefaults.standard.dictionary(forKey: destRegistryKey) as? [String: String] ?? [:]
        // Find and remove the url → taskId entry too
        var urls = UserDefaults.standard.dictionary(forKey: urlRegistryKey) as? [String: String] ?? [:]
        urls = urls.filter { $0.value != taskId }
        dests.removeValue(forKey: taskId)
        UserDefaults.standard.set(dests, forKey: destRegistryKey)
        UserDefaults.standard.set(urls,  forKey: urlRegistryKey)
    }

    /// On init after a relaunch, enumerate the surviving URLSession tasks and reconnect
    /// `taskIdMap` using the persisted URL → taskId mapping so that delegate callbacks
    /// can resolve the correct taskId without the in-memory dictionary.
    private func restoreTaskIdMappings() {
        let urlRegistry = UserDefaults.standard.dictionary(forKey: urlRegistryKey) as? [String: String] ?? [:]
        guard !urlRegistry.isEmpty else { return }

        session.getAllTasks { [weak self] tasks in
            guard let self = self else { return }
            self.queue.async(flags: .barrier) {
                for task in tasks {
                    guard let urlStr = task.originalRequest?.url?.absoluteString,
                          let taskId = urlRegistry[urlStr] else { continue }
                    self.taskIdMap[task.taskIdentifier] = taskId
                    NSLog("BackgroundSessionManager: Restored mapping for '\(taskId)' after relaunch")
                }
            }
        }
    }

    // MARK: - Download API

    /// Start a background download task.
    ///
    /// - Parameters:
    ///   - url: URL to download from
    ///   - destination: Local file URL to save to (will be overwritten)
    ///   - taskId: Unique task identifier for tracking
    ///   - headers: Optional HTTP headers
    ///   - completion: Called when download completes or fails
    /// - Returns: URLSessionDownloadTask instance (already resumed)
    @discardableResult
    func download(
        url: URL,
        to destination: URL,
        taskId: String,
        headers: [String: String]? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> URLSessionDownloadTask {
        // Build request
        var request = URLRequest(url: url)
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        // Create download task
        let task = session.downloadTask(with: request)

        // Store completion handler and task mapping
        queue.async(flags: .barrier) {
            self.downloadHandlers[taskId] = completion
            self.taskIdMap[task.taskIdentifier] = taskId
        }

        // Persist task info so it can be recovered if the app is killed.
        persistDownloadTask(taskId: taskId, destinationPath: destination.path, urlString: url.absoluteString)

        // Start download
        task.resume()

        NSLog("BackgroundSessionManager: Started download for \(taskId)")
        return task
    }

    /// Resume a paused/failed download from partial data.
    ///
    /// - Parameters:
    ///   - resumeData: Resume data from previous download attempt. If `nil`,
    ///     the resume data previously stored by `pause(taskId:completion:)` is used.
    ///   - taskId: Unique task identifier
    ///   - completion: Called when download completes or fails
    /// - Returns: URLSessionDownloadTask instance (already resumed), or nil if no resume data available.
    @discardableResult
    func resumeDownload(
        with resumeData: Data?,
        taskId: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> URLSessionDownloadTask? {
        let data: Data? = resumeData ?? queue.sync { resumeDataStorage[taskId] }
        guard let effectiveData = data else {
            NSLog("BackgroundSessionManager: No resume data for \(taskId)")
            completion(.failure(NSError(domain: "BackgroundSessionManager", code: -1,
                                       userInfo: [NSLocalizedDescriptionKey: "No resume data available"])))
            return nil
        }

        // Clear stored resume data now that we are using it
        queue.async(flags: .barrier) {
            self.resumeDataStorage.removeValue(forKey: taskId)
        }

        let task = session.downloadTask(withResumeData: effectiveData)

        queue.async(flags: .barrier) {
            self.downloadHandlers[taskId] = completion
            self.taskIdMap[task.taskIdentifier] = taskId
        }

        task.resume()

        NSLog("BackgroundSessionManager: Resumed download for \(taskId)")
        return task
    }

    // MARK: - Upload API

    /// Start a background upload task.
    ///
    /// - Parameters:
    ///   - url: URL to upload to
    ///   - fileURL: Local file URL to upload from
    ///   - taskId: Unique task identifier for tracking
    ///   - headers: Optional HTTP headers
    ///   - completion: Called when upload completes or fails
    /// - Returns: URLSessionUploadTask instance (already resumed)
    @discardableResult
    func upload(
        to url: URL,
        from fileURL: URL,
        taskId: String,
        headers: [String: String]? = nil,
        completion: @escaping (Result<URLResponse, Error>) -> Void
    ) -> URLSessionUploadTask {
        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        // Create upload task
        let task = session.uploadTask(with: request, fromFile: fileURL)

        // Store completion handler and task mapping
        queue.async(flags: .barrier) {
            self.uploadHandlers[taskId] = completion
            self.taskIdMap[task.taskIdentifier] = taskId
        }

        // Start upload
        task.resume()

        NSLog("BackgroundSessionManager: Started upload for \(taskId)")
        return task
    }

    // MARK: - Task Management

    /// Cancel a task by ID.
    func cancel(taskId: String) {
        session.getAllTasks { tasks in
            for task in tasks {
                if self.taskIdMap[task.taskIdentifier] == taskId {
                    task.cancel()
                    NSLog("BackgroundSessionManager: Cancelled task \(taskId)")
                    break
                }
            }
        }
    }

    /// Cancel all tasks.
    func cancelAll() {
        session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }

        queue.async(flags: .barrier) {
            self.downloadHandlers.removeAll()
            self.uploadHandlers.removeAll()
            self.taskIdMap.removeAll()
            self.resumeDataStorage.removeAll()
        }

        NSLog("BackgroundSessionManager: Cancelled all tasks")
    }

    /// Get resume data for a task (if available).
    ///
    /// - Parameter taskId: The task identifier
    /// - Returns: Resume data if available, nil otherwise
    public func getResumeData(taskId: String) -> Data? {
        return queue.sync {
            resumeDataStorage[taskId]
        }
    }

    /// Returns `true` if resume data is stored for the given task.
    public func hasResumeData(forTaskId taskId: String) -> Bool {
        return queue.sync { resumeDataStorage[taskId] != nil }
    }

    /// Clear resume data for a task.
    ///
    /// - Parameter taskId: The task identifier
    public func clearResumeData(taskId: String) {
        queue.async(flags: .barrier) {
            self.resumeDataStorage.removeValue(forKey: taskId)
        }
    }

    /// Pause a background download by cancelling with resume data.
    ///
    /// The resume data is stored in `resumeDataStorage` keyed by taskId.
    /// Call `resumeDownload(with:taskId:completion:)` to restart.
    public func pause(taskId: String, completion: @escaping (Bool) -> Void) {
        session.getAllTasks { tasks in
            guard let task = tasks.first(where: { self.taskIdMap[$0.taskIdentifier] == taskId }) as? URLSessionDownloadTask else {
                completion(false)
                return
            }
            task.cancel(byProducingResumeData: { resumeData in
                if let data = resumeData {
                    self.queue.async(flags: .barrier) {
                        self.resumeDataStorage[taskId] = data
                    }
                    NSLog("BackgroundSessionManager: Paused download for '\(taskId)', resume data \(data.count) bytes")
                    completion(true)
                } else {
                    NSLog("BackgroundSessionManager: Pause for '\(taskId)' — no resume data (full restart required)")
                    completion(false)
                }
            })
        }
    }

    // MARK: - Helper Methods

    private func getTaskId(for task: URLSessionTask) -> String? {
        return queue.sync {
            taskIdMap[task.taskIdentifier]
        }
    }

    private func cleanup(taskId: String) {
        queue.async(flags: .barrier) {
            self.downloadHandlers.removeValue(forKey: taskId)
            self.uploadHandlers.removeValue(forKey: taskId)
            self.lastProgressTimes.removeValue(forKey: taskId)
            self.speedWindowBytes.removeValue(forKey: taskId)
            self.speedWindowStart.removeValue(forKey: taskId)
            self.smoothedSpeedBps.removeValue(forKey: taskId)

            // Remove from taskIdMap
            if let key = self.taskIdMap.first(where: { $0.value == taskId })?.key {
                self.taskIdMap.removeValue(forKey: key)
            }
        }
        // Remove from persistent registry (can run off the barrier queue).
        removePersistedTask(taskId: taskId)
    }
}

// MARK: - URLSessionDownloadDelegate

@available(iOS 13.0, *)
extension BackgroundSessionManager: URLSessionDownloadDelegate {

    /// Called when download finishes successfully.
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let taskId = getTaskId(for: downloadTask) else {
            // taskIdMap is empty — app was killed and relaunched by the OS.
            // Try to recover context from persistent registry using the original URL.
            handleRelaunched(downloadTask: downloadTask, tempLocation: location)
            return
        }

        NSLog("BackgroundSessionManager: Download completed for \(taskId)")

        // Get completion handler
        let handler = queue.sync { downloadHandlers[taskId] }

        // Call handler on main thread
        DispatchQueue.main.async {
            handler?(.success(location))
        }

        cleanup(taskId: taskId)
    }

    /// Handles a download completion received during a background-relaunch.
    /// Moves the temporary file to the persisted destination and notifies via delegate.
    private func handleRelaunched(downloadTask: URLSessionDownloadTask, tempLocation: URL) {
        guard let urlStr = downloadTask.originalRequest?.url?.absoluteString else {
            NSLog("BackgroundSessionManager: Relaunch — cannot recover task (no original URL)")
            return
        }
        let urlRegistry  = UserDefaults.standard.dictionary(forKey: urlRegistryKey)  as? [String: String] ?? [:]
        let destRegistry = UserDefaults.standard.dictionary(forKey: destRegistryKey) as? [String: String] ?? [:]

        guard let taskId = urlRegistry[urlStr],
              let destPath = destRegistry[taskId] else {
            NSLog("BackgroundSessionManager: Relaunch — no persisted record for url '\(urlStr)'")
            return
        }

        NSLog("BackgroundSessionManager: Relaunch — recovering download for '\(taskId)'")

        let destination = URL(fileURLWithPath: destPath)
        do {
            let fm = FileManager.default
            if fm.fileExists(atPath: destPath) { try fm.removeItem(at: destination) }
            try fm.moveItem(at: tempLocation, to: destination)
            DispatchQueue.main.async {
                self.relaunchCompletionDelegate?(taskId, .success(destination))
            }
        } catch {
            NSLog("BackgroundSessionManager: Relaunch — file move failed: \(error)")
            DispatchQueue.main.async {
                self.relaunchCompletionDelegate?(taskId, .failure(error))
            }
        }
        removePersistedTask(taskId: taskId)
    }

    /// Called to report download progress.
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let taskId = getTaskId(for: downloadTask) else { return }

        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) * 100
            : 0

        // Throttle + speed tracking (barrier needed: reads and writes)
        let now = Date()
        let result: (Bool, Double?, Int64?) = queue.sync(flags: .barrier) {
            // Always accumulate bytes for the speed window
            speedWindowBytes[taskId] = (speedWindowBytes[taskId] ?? 0) + bytesWritten

            // Throttle gate: skip emit if interval not elapsed
            if let last = lastProgressTimes[taskId],
               now.timeIntervalSince(last) < progressThrottleInterval {
                return (false, nil, nil)
            }
            lastProgressTimes[taskId] = now

            // Update speed every ~500ms (exponential moving average, α=0.3)
            var speed: Double? = nil
            var etaMs: Int64? = nil
            let wStart = speedWindowStart[taskId] ?? now
            let wElapsed = now.timeIntervalSince(wStart)
            if wElapsed >= 0.5 {
                let wBytes = speedWindowBytes[taskId] ?? 0
                let instant = Double(wBytes) / wElapsed
                let prev = smoothedSpeedBps[taskId] ?? 0
                let smoothed = prev == 0 ? instant : 0.3 * instant + 0.7 * prev
                smoothedSpeedBps[taskId] = smoothed
                speedWindowStart[taskId] = now
                speedWindowBytes[taskId] = 0
                if smoothed > 0 { speed = smoothed }
            } else if let s = smoothedSpeedBps[taskId], s > 0 {
                speed = s
            }
            if let s = speed, totalBytesExpectedToWrite > 0 {
                let remaining = totalBytesExpectedToWrite - totalBytesWritten
                if remaining > 0 { etaMs = Int64(Double(remaining) / s * 1000) }
            }
            return (true, speed, etaMs)
        }

        let (shouldEmit, speed, etaMs) = result
        guard shouldEmit else { return }

        NSLog("BackgroundSessionManager: Download progress for \(taskId): \(Int(progress))%")

        if richProgressDelegate != nil {
            var dict: [String: Any] = ["taskId": taskId, "progress": Int(progress)]
            if totalBytesExpectedToWrite > 0 {
                dict["bytesDownloaded"] = totalBytesWritten
                dict["totalBytes"] = totalBytesExpectedToWrite
            }
            if let s = speed { dict["networkSpeed"] = s }
            if let eta = etaMs { dict["timeRemainingMs"] = eta }
            DispatchQueue.main.async { [weak self] in
                self?.richProgressDelegate?(taskId, dict)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.progressDelegate?(taskId, progress)
            }
        }
    }

    /// Called when download is resumed from previous session.
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didResumeAtOffset fileOffset: Int64,
        expectedTotalBytes: Int64
    ) {
        guard let taskId = getTaskId(for: downloadTask) else { return }
        NSLog("BackgroundSessionManager: Download resumed for \(taskId) at offset \(fileOffset)")
    }
}

// MARK: - URLSessionTaskDelegate

@available(iOS 13.0, *)
extension BackgroundSessionManager: URLSessionTaskDelegate {

    /// Called when any task (download/upload) completes with error or success.
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let taskId = getTaskId(for: task) else {
            return
        }

        if let error = error {
            NSLog("BackgroundSessionManager: Task \(taskId) failed with error: \(error.localizedDescription)")

            // Check if we can resume download
            if task is URLSessionDownloadTask,
               let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                NSLog("BackgroundSessionManager: Resume data available for \(taskId) (\(resumeData.count) bytes)")

                // Store resume data for retry
                queue.async(flags: .barrier) {
                    self.resumeDataStorage[taskId] = resumeData
                }
            }

            // Call appropriate completion handler
            if let handler = queue.sync(execute: { downloadHandlers[taskId] }) {
                DispatchQueue.main.async {
                    handler(.failure(error))
                }
            } else if let handler = queue.sync(execute: { uploadHandlers[taskId] }) {
                DispatchQueue.main.async {
                    handler(.failure(error))
                }
            }

            cleanup(taskId: taskId)
        } else {
            // Success case for uploads (downloads handled in didFinishDownloadingTo)
            if task is URLSessionUploadTask,
               let response = task.response,
               let handler = queue.sync(execute: { uploadHandlers[taskId] }) {
                NSLog("BackgroundSessionManager: Upload completed for \(taskId)")

                DispatchQueue.main.async {
                    handler(.success(response))
                }

                cleanup(taskId: taskId)
            }
        }
    }

    /// Called to report upload progress.
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard let taskId = getTaskId(for: task) else { return }

        let progress = totalBytesExpectedToSend > 0
            ? Double(totalBytesSent) / Double(totalBytesExpectedToSend) * 100
            : 0

        // Throttle: same 100ms gate as download progress.
        let now = Date()
        let shouldEmit = queue.sync {
            guard let last = lastProgressTimes[taskId] else {
                lastProgressTimes[taskId] = now
                return true
            }
            if now.timeIntervalSince(last) >= progressThrottleInterval {
                lastProgressTimes[taskId] = now
                return true
            }
            return false
        }
        guard shouldEmit else { return }

        NSLog("BackgroundSessionManager: Upload progress for \(taskId): \(Int(progress))%")

        DispatchQueue.main.async { [weak self] in
            self?.progressDelegate?(taskId, progress)
        }
    }
}

// MARK: - URLSessionDelegate

@available(iOS 13.0, *)
extension BackgroundSessionManager: URLSessionDelegate {

    /// Called when all background tasks finish and app is in background.
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // Key by the session's own identifier so that multiple sessions each
        // invoke the correct AppDelegate completion handler rather than all
        // sharing (and overwriting) a single var.
        let identifier = session.configuration.identifier ?? sessionIdentifier
        NSLog("BackgroundSessionManager: All background tasks completed for session '\(identifier)'")

        // Atomically pop the handler so it cannot be called twice.
        let handler: (() -> Void)? = queue.sync(flags: .barrier) {
            backgroundCompletionHandlers.removeValue(forKey: identifier)
        }
        DispatchQueue.main.async {
            handler?()
        }
    }
}
