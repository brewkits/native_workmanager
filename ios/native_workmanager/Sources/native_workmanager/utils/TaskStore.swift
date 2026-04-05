import Foundation

/// Persistent store for background tasks and URLSession mappings on iOS.
///
/// This store manages:
/// 1. Individual task metadata (status, configuration, results)
/// 2. Background session mapping (url -> taskId) to survive app termination
/// 3. Task tags for grouped cancellation
///
/// Replaces UserDefaults and provides ACID compliance for background operations.
@available(iOS 13.0, *)
class TaskStore {
    
    static let shared = TaskStore(name: "native_workmanager_tasks")
    
    private let sqlite: SQLiteStore

    init(name: String) {
        self.sqlite = SQLiteStore(name: name)
        setup()
    }

    private func setup() {
        // Table for individual task metadata
        let tasksSql = """
        CREATE TABLE IF NOT EXISTS tasks (
            task_id TEXT PRIMARY KEY,
            tag TEXT,
            status TEXT NOT NULL, -- pending, running, success, failed, cancelled, paused
            worker_class_name TEXT NOT NULL,
            worker_config TEXT, -- FULL JSON configuration
            result_data TEXT,
            error_message TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );
        """
        sqlite.execute(sql: tasksSql)
        sqlite.execute(sql: "CREATE INDEX IF NOT EXISTS idx_tasks_tag ON tasks(tag);")
        sqlite.execute(sql: "CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);")

        // Table for background URLSession mapping (replaces UserDefaults)
        // Stores enough info to re-attach a taskId to a system URLSession relaunch event.
        let registrySql = """
        CREATE TABLE IF NOT EXISTS background_registry (
            task_id TEXT PRIMARY KEY,
            url_string TEXT NOT NULL,
            destination_path TEXT NOT NULL,
            resume_data BLOB,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );
        """
        sqlite.execute(sql: registrySql)
        sqlite.execute(sql: "CREATE INDEX IF NOT EXISTS idx_registry_url ON background_registry(url_string);")
        
        // ✅ NEW: Migrate data from legacy UserDefaults if exists
        migrateFromUserDefaults()
    }

    /// Migration logic for upgrading from legacy versions (< 1.1.0) that used UserDefaults.
    /// Moves persisted background session mappings to the new SQLite registry table.
    private func migrateFromUserDefaults() {
        let defaults = UserDefaults.standard
        let destRegistryKey = "NativeWorkManager.BGSession.destinations" // [taskId: destPath]
        let urlRegistryKey  = "NativeWorkManager.BGSession.urls"         // [urlString: taskId]
        
        guard let dests = defaults.dictionary(forKey: destRegistryKey) as? [String: String],
              let urls = defaults.dictionary(forKey: urlRegistryKey) as? [String: String] else {
            return
        }
        
        NativeLogger.d("📦 Found legacy background task registry in UserDefaults. Starting migration...")
        
        var migratedCount = 0
        for (taskId, destPath) in dests {
            // Find the URL for this taskId from the urls registry
            // Legacy mapping was urlString -> taskId
            if let url = urls.first(where: { $0.value == taskId })?.key {
                registerBackgroundDownload(taskId: taskId, url: url, destinationPath: destPath)
                migratedCount += 1
            }
        }
        
        // ✅ Clean up: Remove old keys after successful migration to avoid re-migration
        defaults.removeObject(forKey: destRegistryKey)
        defaults.removeObject(forKey: urlRegistryKey)
        
        NativeLogger.d("✅ Successfully migrated \(migratedCount) records from UserDefaults to SQLite.")
    }

    // MARK: - Task Management

    func upsert(taskId: String, tag: String?, status: String, workerClassName: String, workerConfig: String?) {
        let now = Int(Date().timeIntervalSince1970)
        let sql = """
        INSERT INTO tasks (task_id, tag, status, worker_class_name, worker_config, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(task_id) DO UPDATE SET
            status = excluded.status,
            updated_at = excluded.updated_at;
        """
        sqlite.execute(sql: sql, params: [
            taskId,
            tag ?? NSNull(),
            status,
            workerClassName,
            workerConfig ?? NSNull(),
            now,
            now
        ])
    }

    func updateStatus(taskId: String, status: String, resultData: String? = nil, errorMessage: String? = nil) {
        let now = Int(Date().timeIntervalSince1970)
        let sql = """
        UPDATE tasks SET 
            status = ?, 
            result_data = ?, 
            error_message = ?, 
            updated_at = ? 
        WHERE task_id = ?;
        """
        sqlite.execute(sql: sql, params: [status, resultData ?? NSNull(), errorMessage ?? NSNull(), now, taskId])
    }

    func task(taskId: String) -> TaskRecord? {
        let sql = "SELECT * FROM tasks WHERE task_id = ? LIMIT 1;"
        guard let row = sqlite.query(sql: sql, params: [taskId]).first else { return nil }
        return TaskRecord(from: row)
    }

    func allTasks() -> [TaskRecord] {
        let sql = "SELECT * FROM tasks ORDER BY created_at DESC;"
        return sqlite.query(sql: sql).map { TaskRecord(from: $0) }
    }

    func delete(taskId: String) {
        sqlite.execute(sql: "DELETE FROM tasks WHERE task_id = ?;", params: [taskId])
    }

    func deleteCompleted(olderThanMs: Int64) {
        let threshold = Int64(Date().timeIntervalSince1970 * 1000) - olderThanMs
        let thresholdSec = Int(threshold / 1000)
        let sql = "DELETE FROM tasks WHERE status IN ('success', 'failed', 'cancelled') AND updated_at < ?;"
        sqlite.execute(sql: sql, params: [thresholdSec])
    }

    func recoverZombieTasks() {
        let now = Int(Date().timeIntervalSince1970)
        // If app crashed/rebooted, tasks stuck in 'running' or 'pending' for over 1 hour 
        // without an update should be marked as failed so they can be retried.
        let oneHourAgo = now - 3600
        let sql = "UPDATE tasks SET status = 'failed', error_message = 'Process terminated unexpectedly' WHERE status IN ('running', 'pending') AND updated_at < ?;"
        sqlite.execute(sql: sql, params: [oneHourAgo])
    }

    // MARK: - Background Registry (Replacing UserDefaults)

    func registerBackgroundDownload(taskId: String, url: String, destinationPath: String) {
        let now = Int(Date().timeIntervalSince1970)
        let sql = """
        INSERT INTO background_registry (task_id, url_string, destination_path, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(task_id) DO UPDATE SET
            url_string = excluded.url_string,
            destination_path = excluded.destination_path,
            updated_at = excluded.updated_at;
        """
        sqlite.execute(sql: sql, params: [taskId, url, destinationPath, now, now])
    }

    func updateResumeData(taskId: String, data: Data?) {
        let now = Int(Date().timeIntervalSince1970)
        let sql = "UPDATE background_registry SET resume_data = ?, updated_at = ? WHERE task_id = ?;"
        sqlite.execute(sql: sql, params: [data ?? NSNull(), now, taskId])
    }

    func getRegistryByTaskId(taskId: String) -> [String: Any]? {
        let sql = "SELECT * FROM background_registry WHERE task_id = ? LIMIT 1;"
        return sqlite.query(sql: sql, params: [taskId]).first
    }

    func getRegistryByUrl(url: String) -> [String: Any]? {
        let sql = "SELECT * FROM background_registry WHERE url_string = ? LIMIT 1;"
        return sqlite.query(sql: sql, params: [url]).first
    }

    func unregisterBackgroundDownload(taskId: String) {
        sqlite.execute(sql: "DELETE FROM background_registry WHERE task_id = ?;", params: [taskId])
    }

    // MARK: - Helpers

    /// Redacts sensitive information from a worker configuration dictionary for safe logging or storage.
    static func sanitizeConfig(_ config: [String: Any]?) -> [String: Any]? {
        guard var sanitized = config else { return nil }
        let sensitiveKeys = ["authToken", "password", "apiKey", "secret", "token", "cookies"]
        
        for key in sensitiveKeys {
            if sanitized[key] != nil {
                sanitized[key] = "[redacted]"
            }
        }
        
        // Deep sanitize headers if present
        if var headers = sanitized["headers"] as? [String: String] {
            let sensitiveHeaders = ["Authorization", "Cookie", "Set-Cookie", "x-api-key"]
            for hKey in headers.keys {
                if sensitiveHeaders.contains(where: { hKey.caseInsensitiveCompare($0) == .orderedSame }) {
                    headers[hKey] = "[redacted]"
                }
            }
            sanitized["headers"] = headers
        }
        
        return sanitized
    }
}

/// Data record for a task.
struct TaskRecord {
    let taskId: String
    let tag: String?
    let status: String
    let workerClassName: String
    let workerConfig: String?
    let resultData: String?
    let errorMessage: String?
    let createdAt: Int
    let updatedAt: Int

    init(from row: [String: Any]) {
        self.taskId = row["task_id"] as? String ?? ""
        self.tag = row["tag"] as? String
        self.status = row["status"] as? String ?? "unknown"
        self.workerClassName = row["worker_class_name"] as? String ?? ""
        self.workerConfig = row["worker_config"] as? String
        self.resultData = row["result_data"] as? String
        self.errorMessage = row["error_message"] as? String
        self.createdAt = row["created_at"] as? Int ?? 0
        self.updatedAt = row["updated_at"] as? Int ?? 0
    }

    func toFlutterMap() -> [String: Any] {
        return [
            "taskId": taskId,
            "tag": tag as Any,
            "status": status,
            "workerClassName": workerClassName,
            "createdAt": createdAt * 1000, // Ms for Dart
            "updatedAt": updatedAt * 1000
        ]
    }
}
