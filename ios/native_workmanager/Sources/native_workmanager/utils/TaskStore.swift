import Foundation

/// Persistent task storage for iOS using atomic file-based JSON records.
/// 
/// Instead of a database, each task is stored as a separate .json file in the
/// app's Application Support directory. This ensures high reliability and
/// performance without the overhead of SQLite or CoreData.
///
/// Uses .atomic writing to guarantee data integrity across app crashes and reboots.
@available(iOS 13.0, *)
public class TaskStore {
    
    public struct TaskRecord: Codable {
        public let taskId: String
        public let tag: String?
        public let status: String
        public let workerClassName: String
        public let workerConfig: String?
        public let createdAt: Int64
        public let updatedAt: Int64
        public let resultData: String?
        public let constraintsJson: String?
        
        /// Returns a sanitized version of the record with sensitive config fields removed.
        /// Prevents leaking auth tokens or passwords via backups or file system dumps.
        public func sanitized() -> TaskRecord {
            guard let config = workerConfig else { return self }
            return TaskRecord(
                taskId: taskId,
                tag: tag,
                status: status,
                workerClassName: workerClassName,
                workerConfig: TaskStore.sanitizeConfig(config),
                createdAt: createdAt,
                updatedAt: updatedAt,
                resultData: resultData,
                constraintsJson: constraintsJson
            )
        }
        
        /// For backward compatibility with existing plugin logic.
        public func toFlutterMap() -> [String: Any?] {
            return [
                "taskId": taskId,
                "tag": tag,
                "status": status,
                "workerClassName": workerClassName,
                "createdAt": createdAt,
                "updatedAt": updatedAt,
                "resultData": resultData
            ]
        }
    }
    
    public static let shared = TaskStore()
    
    private let fileManager = FileManager.default
    private let tasksDir: URL
    
    private init() {
        // Use Application Support directory for persistent data (standard iOS practice).
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        tasksDir = appSupport.appendingPathComponent("native_workmanager/tasks", isDirectory: true)
        
        // Ensure the directory exists.
        if !fileManager.fileExists(atPath: tasksDir.path) {
            try? fileManager.createDirectory(at: tasksDir, withIntermediateDirectories: true)
        }
    }
    
    /// Persist or update a task record.
    /// Uses .atomic writing to prevent file corruption.
    public func upsert(
        taskId: String,
        tag: String?,
        status: String,
        workerClassName: String,
        workerConfig: String?,
        constraintsJson: String? = nil
    ) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let existing = getTask(taskId: taskId)
        
        let record = TaskRecord(
            taskId: taskId,
            tag: tag,
            status: status,
            workerClassName: workerClassName,
            workerConfig: workerConfig,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            resultData: existing?.resultData,
            constraintsJson: constraintsJson
        )
        
        save(record)
    }
    
    /// Update status and optional result data for an existing task.
    public func updateStatus(taskId: String, status: String, resultData: String? = nil) {
        guard var record = getTask(taskId: taskId) else { return }
        
        record = TaskRecord(
            taskId: record.taskId,
            tag: record.tag,
            status: status,
            workerClassName: record.workerClassName,
            workerConfig: record.workerConfig,
            createdAt: record.createdAt,
            updatedAt: Int64(Date().timeIntervalSince1970 * 1000),
            resultData: resultData ?? record.resultData,
            constraintsJson: record.constraintsJson
        )
        
        save(record)
    }
    
    /// Retrieve a task by ID.
    public func getTask(taskId: String) -> TaskRecord? {
        let fileURL = tasksDir.appendingPathComponent("\(taskId).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(TaskRecord.self, from: data)
    }
    
    /// Compatibility alias for getTask
    public func task(taskId: String) -> TaskRecord? {
        return getTask(taskId: taskId)
    }
    
    /// Retrieve all tasks, sorted by updatedAt descending.
    public func getAllTasks() -> [TaskRecord] {
        guard let files = try? fileManager.contentsOfDirectory(at: tasksDir, includingPropertiesForKeys: nil) else {
            return []
        }
        
        let records = files.compactMap { fileURL -> TaskRecord? in
            guard fileURL.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            return try? JSONDecoder().decode(TaskRecord.self, from: data)
        }
        
        return records.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    /// Compatibility alias for getAllTasks
    public func allTasks() -> [TaskRecord] {
        return getAllTasks()
    }
    
    /// Delete a task record.
    public func delete(taskId: String) {
        let fileURL = tasksDir.appendingPathComponent("\(taskId).json")
        try? fileManager.removeItem(at: fileURL)
    }

    /// Recover "Zombie" tasks that are stuck in 'running' state.
    /// 
    /// FIX #03: Added Heartbeat check. Only recover tasks that have been in 'running'
    /// state without any update for more than 5 minutes. This prevents killing
    /// tasks that were just started by the OS during app launch.
    public func recoverZombieTasks() {
        let all = getAllTasks()
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let timeoutMs: Int64 = 5 * 60 * 1000 // 5 minutes heartbeat timeout
        
        var recoveredCount = 0
        for record in all where record.status == "running" {
            if (now - record.updatedAt) > timeoutMs {
                updateStatus(
                    taskId: record.taskId,
                    status: "failed",
                    resultData: "{\"message\": \"Process died or hung (heartbeat timeout)\", \"shouldRetry\": true}"
                )
                recoveredCount += 1
            }
        }
        if recoveredCount > 0 {
            print("TaskStore: Recovered \(recoveredCount) zombie tasks (heartbeat based)")
        }
    }

    /// Delete old tasks (cleanup).
    public func deleteCompleted(olderThanMs: Int64 = 0) {
        let threshold = olderThanMs > 0 ? Int64(Date().timeIntervalSince1970 * 1000) - olderThanMs : Int64.max
        let all = getAllTasks()
        
        for record in all {
            let s = record.status
            if (s == "completed" || s == "failed" || s == "cancelled") && record.updatedAt < threshold {
                delete(taskId: record.taskId)
            }
        }
    }
    
    private func save(_ record: TaskRecord) {
        let fileURL = tasksDir.appendingPathComponent("\(record.taskId).json")
        
        // Sanitize before persisting to prevent sensitive data leakage.
        let sanitized = record.sanitized()
        
        if let data = try? JSONEncoder().encode(sanitized) {
            // .atomic writing ensures the old file is only replaced if the new write succeeds.
            try? data.write(to: fileURL, options: .atomic)
        }
    }
    
    // MARK: - Security & Sanitization
    
    private static let sensitiveKeys = [
        "authToken", "authorization", "cookies", "password", "secret",
        "accessToken", "refreshToken", "apiKey", "token", "bearer"
    ]
    
    /// Recursively strips sensitive keys from JSON config before persistence.
    public static func sanitizeConfig(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              var dict = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) else {
            return json
        }
        
        sanitizeDictionary(&dict)
        
        if let sanitizedData = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let result = String(data: sanitizedData, encoding: .utf8) {
            return result
        }
        return json
    }
    
    public static func sanitizeDictionary(_ dict: inout [String: Any]) {
        for key in dict.keys {
            if sensitiveKeys.contains(where: { $0.lowercased() == key.lowercased() }) {
                dict[key] = "[REDACTED]"
            } else if var nestedDict = dict[key] as? [String: Any] {
                sanitizeDictionary(&nestedDict)
                dict[key] = nestedDict
            } else if var nestedArray = dict[key] as? [[String: Any]] {
                for i in 0..<nestedArray.count {
                    sanitizeDictionary(&nestedArray[i])
                }
                dict[key] = nestedArray
            }
        }
    }
}
