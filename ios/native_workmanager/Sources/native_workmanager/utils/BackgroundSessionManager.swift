import Foundation

/// Manages iOS background URLSession for downloads and uploads that survive app termination.
///
/// Refactored to use SQLite (TaskStore) for persistence, ensuring ACID compliance
/// and survival across app kills and reboots.
@available(iOS 13.0, *)
public class BackgroundSessionManager: NSObject {

    public static let shared = BackgroundSessionManager()

    private override init() {
        super.init()
        self.session = createBackgroundSession()
        restoreTaskIdMappings()
    }

    // MARK: - Properties

    private var session: URLSession!
    private let sessionIdentifier = "dev.brewkits.native_workmanager.background"

    private var downloadHandlers: [String: (Result<URL, Error>) -> Void] = [:]
    private var uploadHandlers: [String: (Result<URLResponse, Error>) -> Void] = [:]
    private var taskIdMap: [Int: String] = [:]

    private let queue = DispatchQueue(label: "dev.brewkits.background_session_manager", attributes: .concurrent)
    private var backgroundCompletionHandlers: [String: () -> Void] = [:]

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

    public func setBackgroundCompletionHandler(_ handler: @escaping () -> Void, for identifier: String) {
        queue.async(flags: .barrier) {
            self.backgroundCompletionHandlers[identifier] = handler
        }
    }

    // Progress and Speed tracking
    public var progressDelegate: ((String, Double) -> Void)?
    public var richProgressDelegate: ((String, [String: Any]) -> Void)?
    public var relaunchCompletionDelegate: ((String, Result<URL, Error>) -> Void)?

    private var lastProgressTimes: [String: Date] = [:]
    private let progressThrottleInterval: TimeInterval = 0.1
    private var speedWindowBytes: [String: Int64] = [:]
    private var speedWindowStart: [String: Date] = [:]
    private var smoothedSpeedBps: [String: Double] = [:]

    // MARK: - Session Creation

    private func createBackgroundSession() -> URLSession {
        let config = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        config.isDiscretionary = false
        config.allowsCellularAccess = true
        config.sessionSendsLaunchEvents = true
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 7 * 24 * 60 * 60
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Persistence Logic (SQLite)

    private func restoreTaskIdMappings() {
        session.getAllTasks { [weak self] tasks in
            guard let self = self else { return }
            self.queue.async(flags: .barrier) {
                for task in tasks {
                    guard let urlStr = task.originalRequest?.url?.absoluteString,
                          let registry = TaskStore.shared.getRegistryByUrl(url: urlStr),
                          let taskId = registry["task_id"] as? String else { continue }
                    self.taskIdMap[task.taskIdentifier] = taskId
                    NSLog("BackgroundSessionManager: Restored mapping for '\(taskId)'")
                }
            }
        }
    }

    public func syncWithTaskStore() async {
        let tasks = await session.allTasks
        let activeTaskIds = tasks.compactMap { task -> String? in
            return queue.sync { taskIdMap[task.taskIdentifier] }
        }
        
        let storedTasks = TaskStore.shared.allTasks()
        for record in storedTasks where record.status == "running" {
            if record.workerClassName.contains("Http") && !activeTaskIds.contains(record.taskId) {
                TaskStore.shared.updateStatus(
                    taskId: record.taskId,
                    status: "failed",
                    errorMessage: "Background transfer lost by system"
                )
            }
        }
    }

    // MARK: - Download/Upload API

    /// Convenience method to start a download from a worker config dictionary.
    @discardableResult
    public func download(taskId: String, config: [String: Any], completion: @escaping (Result<URL, Error>) -> Void) -> URLSessionDownloadTask? {
        guard let urlStr = config["url"] as? String,
              let url = URL(string: urlStr) else {
            completion(.failure(NSError(domain: "BackgroundSessionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return nil
        }

        let savePath = config["savePath"] as? String ?? ""
        let destination = URL(fileURLWithPath: savePath)
        let headers = config["headers"] as? [String: String]

        return download(url: url, to: destination, taskId: taskId, headers: headers, completion: completion)
    }

    @discardableResult
    func download(url: URL, to destination: URL, taskId: String, headers: [String: String]? = nil, completion: @escaping (Result<URL, Error>) -> Void) -> URLSessionDownloadTask {
        var request = URLRequest(url: url)
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let task = session.downloadTask(with: request)
        queue.async(flags: .barrier) {
            self.downloadHandlers[taskId] = completion
            self.taskIdMap[task.taskIdentifier] = taskId
        }

        TaskStore.shared.registerBackgroundDownload(taskId: taskId, url: url.absoluteString, destinationPath: destination.path)
        task.resume()
        return task
    }

    @discardableResult
    func resumeDownload(with resumeData: Data?, taskId: String, completion: @escaping (Result<URL, Error>) -> Void) -> URLSessionDownloadTask? {
        let data: Data? = resumeData ?? (TaskStore.shared.getRegistryByTaskId(taskId: taskId)?["resume_data"] as? Data)
        guard let effectiveData = data else {
            completion(.failure(NSError(domain: "BackgroundSessionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No resume data available"])))
            return nil
        }

        TaskStore.shared.updateResumeData(taskId: taskId, data: nil)
        let task = session.downloadTask(withResumeData: effectiveData)
        queue.async(flags: .barrier) {
            self.downloadHandlers[taskId] = completion
            self.taskIdMap[task.taskIdentifier] = taskId
        }
        task.resume()
        return task
    }

    public func hasResumeData(forTaskId taskId: String) -> Bool {
        return (TaskStore.shared.getRegistryByTaskId(taskId: taskId)?["resume_data"] as? Data) != nil
    }

    public func pause(taskId: String, completion: @escaping (Bool) -> Void) {
        session.getAllTasks { tasks in
            guard let task = tasks.first(where: { self.getTaskId(for: $0) == taskId }) as? URLSessionDownloadTask else {
                completion(false)
                return
            }
            task.cancel(byProducingResumeData: { resumeData in
                if let data = resumeData {
                    TaskStore.shared.updateResumeData(taskId: taskId, data: data)
                    completion(true)
                } else {
                    completion(false)
                }
            })
        }
    }

    @discardableResult
    func upload(to url: URL, from fileURL: URL, taskId: String, headers: [String: String]? = nil, completion: @escaping (Result<URLResponse, Error>) -> Void) -> URLSessionUploadTask {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let task = session.uploadTask(with: request, fromFile: fileURL)
        queue.async(flags: .barrier) {
            self.uploadHandlers[taskId] = completion
            self.taskIdMap[task.taskIdentifier] = taskId
        }

        TaskStore.shared.registerBackgroundDownload(taskId: taskId, url: url.absoluteString, destinationPath: fileURL.path)
        task.resume()
        return task
    }

    func cancel(taskId: String) {
        session.getAllTasks { tasks in
            tasks.first(where: { self.getTaskId(for: $0) == taskId })?.cancel()
        }
        cleanup(taskId: taskId)
    }

    private func getTaskId(for task: URLSessionTask) -> String? {
        return queue.sync { taskIdMap[task.taskIdentifier] }
    }

    private func cleanup(taskId: String) {
        queue.async(flags: .barrier) {
            self.downloadHandlers.removeValue(forKey: taskId)
            self.uploadHandlers.removeValue(forKey: taskId)
            self.lastProgressTimes.removeValue(forKey: taskId)
            self.speedWindowBytes.removeValue(forKey: taskId)
            self.speedWindowStart.removeValue(forKey: taskId)
            self.smoothedSpeedBps.removeValue(forKey: taskId)
            if let key = self.taskIdMap.first(where: { $0.value == taskId })?.key {
                self.taskIdMap.removeValue(forKey: key)
            }
        }
        TaskStore.shared.unregisterBackgroundDownload(taskId: taskId)
    }
}

// MARK: - Delegates

@available(iOS 13.0, *)
extension BackgroundSessionManager: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let taskId = getTaskId(for: downloadTask) else {
            handleRelaunched(downloadTask: downloadTask, tempLocation: location)
            return
        }
        let handler = queue.sync { downloadHandlers[taskId] }
        DispatchQueue.main.async { handler?(.success(location)) }
        cleanup(taskId: taskId)
    }

    private func handleRelaunched(downloadTask: URLSessionDownloadTask, tempLocation: URL) {
        guard let urlStr = downloadTask.originalRequest?.url?.absoluteString,
              let registry = TaskStore.shared.getRegistryByUrl(url: urlStr),
              let taskId = registry["task_id"] as? String,
              let destPath = registry["destination_path"] as? String else { return }

        let destination = URL(fileURLWithPath: destPath)
        do {
            if FileManager.default.fileExists(atPath: destPath) { try FileManager.default.removeItem(at: destination) }
            try FileManager.default.moveItem(at: tempLocation, to: destination)
            DispatchQueue.main.async { self.relaunchCompletionDelegate?(taskId, .success(destination)) }
        } catch {
            DispatchQueue.main.async { self.relaunchCompletionDelegate?(taskId, .failure(error)) }
        }
        TaskStore.shared.unregisterBackgroundDownload(taskId: taskId)
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let taskId = getTaskId(for: downloadTask) else { return }
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) * 100 : 0
        let now = Date()
        let res: (Bool, Double?, Int64?) = queue.sync(flags: .barrier) {
            speedWindowBytes[taskId] = (speedWindowBytes[taskId] ?? 0) + bytesWritten
            if let last = lastProgressTimes[taskId], now.timeIntervalSince(last) < progressThrottleInterval { return (false, nil, nil) }
            lastProgressTimes[taskId] = now
            var speed: Double? = nil
            var eta: Int64? = nil
            let start = speedWindowStart[taskId] ?? now
            let elapsed = now.timeIntervalSince(start)
            if elapsed >= 0.5 {
                let instant = Double(speedWindowBytes[taskId] ?? 0) / elapsed
                let prev = smoothedSpeedBps[taskId] ?? 0
                let smoothed = prev == 0 ? instant : 0.3 * instant + 0.7 * prev
                smoothedSpeedBps[taskId] = smoothed
                speedWindowStart[taskId] = now
                speedWindowBytes[taskId] = 0
                speed = smoothed
            } else { speed = smoothedSpeedBps[taskId] }
            if let s = speed, totalBytesExpectedToWrite > 0 {
                let rem = totalBytesExpectedToWrite - totalBytesWritten
                if rem > 0 { eta = Int64(Double(rem) / s * 1000) }
            }
            return (true, speed, eta)
        }
        if !res.0 { return }
        if richProgressDelegate != nil {
            var dict: [String: Any] = ["taskId": taskId, "progress": Int(progress), "bytesDownloaded": totalBytesWritten, "totalBytes": totalBytesExpectedToWrite]
            if let s = res.1 { dict["networkSpeed"] = s }
            if let e = res.2 { dict["timeRemainingMs"] = e }
            DispatchQueue.main.async { self.richProgressDelegate?(taskId, dict) }
        } else {
            DispatchQueue.main.async { [weak self] in self?.progressDelegate?(taskId, progress) }
        }
    }
}

@available(iOS 13.0, *)
extension BackgroundSessionManager: URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let taskId = getTaskId(for: task) else { return }
        if let error = error {
            if task is URLSessionDownloadTask, let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                TaskStore.shared.updateResumeData(taskId: taskId, data: resumeData)
            }
            let handler = queue.sync { downloadHandlers[taskId] }
            DispatchQueue.main.async { handler?(.failure(error)) }
            cleanup(taskId: taskId)
        }
    }

    public func urlSession(_ session: URLSession, didFinishEventsForBackgroundURLSession identifier: String) {
        let handler = queue.sync(flags: .barrier) { backgroundCompletionHandlers.removeValue(forKey: identifier) }
        DispatchQueue.main.async { handler?() }
    }
}
