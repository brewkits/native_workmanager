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

    /// Background completion handler from AppDelegate
    public var backgroundCompletionHandler: (() -> Void)?

    /// Progress delegate for reporting download/upload progress to Flutter
    public var progressDelegate: ((String, Double) -> Void)?

    /// Resume data storage for failed downloads (taskId -> resumeData)
    private var resumeDataStorage: [String: Data] = [:]

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

        // Start download
        task.resume()

        NSLog("BackgroundSessionManager: Started download for \(taskId)")
        return task
    }

    /// Resume a paused/failed download from partial data.
    ///
    /// - Parameters:
    ///   - resumeData: Resume data from previous download attempt
    ///   - taskId: Unique task identifier
    ///   - completion: Called when download completes or fails
    /// - Returns: URLSessionDownloadTask instance (already resumed)
    @discardableResult
    func resumeDownload(
        with resumeData: Data,
        taskId: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> URLSessionDownloadTask {
        let task = session.downloadTask(withResumeData: resumeData)

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

    /// Clear resume data for a task.
    ///
    /// - Parameter taskId: The task identifier
    public func clearResumeData(taskId: String) {
        queue.async(flags: .barrier) {
            self.resumeDataStorage.removeValue(forKey: taskId)
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

            // Remove from taskIdMap
            if let key = self.taskIdMap.first(where: { $0.value == taskId })?.key {
                self.taskIdMap.removeValue(forKey: key)
            }
        }
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
            NSLog("BackgroundSessionManager: Warning - No taskId found for completed download")
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

        NSLog("BackgroundSessionManager: Download progress for \(taskId): \(Int(progress))%")

        // Report progress to Flutter via delegate
        DispatchQueue.main.async { [weak self] in
            self?.progressDelegate?(taskId, progress)
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

        NSLog("BackgroundSessionManager: Upload progress for \(taskId): \(Int(progress))%")

        // Report progress to Flutter via delegate
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
        NSLog("BackgroundSessionManager: All background tasks completed")

        // Call the completion handler from AppDelegate
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
