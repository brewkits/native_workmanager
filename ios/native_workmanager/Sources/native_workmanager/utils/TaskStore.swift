import Foundation
import SQLite3

/// Lightweight SQLite-backed task store for native_workmanager.
///
/// Schema (v2):
/// ```
/// tasks (task_id TEXT PK, tag TEXT, status TEXT, worker_class TEXT,
///         worker_config TEXT, created_at INTEGER, updated_at INTEGER, result_data TEXT)
/// ```
@available(iOS 13.0, *)
final class TaskStore {

    static let shared = TaskStore()

    struct TaskRecord {
        let taskId: String
        let tag: String?
        let status: String
        let workerClassName: String
        let workerConfig: String?
        let createdAt: Int64
        let updatedAt: Int64
        let resultData: String?

        func toFlutterMap() -> [String: Any?] {
            [
                "taskId":          taskId,
                "tag":             tag as Any,
                "status":          status,
                "workerClassName": workerClassName,
                "createdAt":       createdAt,
                "updatedAt":       updatedAt,
                "resultData":      resultData as Any
            ]
        }
    }

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "dev.brewkits.taskstore", attributes: .concurrent)

    private init() {
        openDatabase()
        createTable()
    }

    deinit { sqlite3_close(db) }

    // MARK: - Setup

    private func openDatabase() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path = dir.appendingPathComponent("native_workmanager.db").path
        if sqlite3_open(path, &db) != SQLITE_OK {
            NSLog("TaskStore: Failed to open database at \(path)")
        }
    }

    private func createTable() {
        let sql = """
            CREATE TABLE IF NOT EXISTS tasks (
                task_id       TEXT PRIMARY KEY,
                tag           TEXT,
                status        TEXT NOT NULL,
                worker_class  TEXT NOT NULL,
                worker_config TEXT,
                created_at    INTEGER NOT NULL,
                updated_at    INTEGER NOT NULL,
                result_data   TEXT
            );
        """
        queue.sync(flags: .barrier) {
            _ = sqlite3_exec(db, sql, nil, nil, nil)
        }
    }

    // MARK: - Write

    func upsert(
        taskId: String,
        tag: String?,
        status: String,
        workerClassName: String,
        workerConfig: String?
    ) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        queue.async(flags: .barrier) {
            // INSERT OR IGNORE so created_at is preserved on update
            let insert = "INSERT OR IGNORE INTO tasks (task_id,tag,status,worker_class,worker_config,created_at,updated_at) VALUES (?,?,?,?,?,?,?)"
            if let stmt = self.prepare(insert) {
                sqlite3_bind_text(stmt, 1, taskId, -1, Self.TRANSIENT)
                self.bindNullableText(stmt, 2, tag)
                sqlite3_bind_text(stmt, 3, status, -1, Self.TRANSIENT)
                sqlite3_bind_text(stmt, 4, workerClassName, -1, Self.TRANSIENT)
                self.bindNullableText(stmt, 5, workerConfig)
                sqlite3_bind_int64(stmt, 6, now)
                sqlite3_bind_int64(stmt, 7, now)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
            // UPDATE mutable columns
            let update = "UPDATE tasks SET status=?, updated_at=?, tag=COALESCE(?,tag) WHERE task_id=?"
            if let stmt = self.prepare(update) {
                sqlite3_bind_text(stmt, 1, status, -1, Self.TRANSIENT)
                sqlite3_bind_int64(stmt, 2, now)
                self.bindNullableText(stmt, 3, tag)
                sqlite3_bind_text(stmt, 4, taskId, -1, Self.TRANSIENT)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }

    func updateStatus(taskId: String, status: String, resultData: String? = nil) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        queue.async(flags: .barrier) {
            let sql = "UPDATE tasks SET status=?, updated_at=?, result_data=COALESCE(?,result_data) WHERE task_id=?"
            if let stmt = self.prepare(sql) {
                sqlite3_bind_text(stmt, 1, status, -1, Self.TRANSIENT)
                sqlite3_bind_int64(stmt, 2, now)
                self.bindNullableText(stmt, 3, resultData)
                sqlite3_bind_text(stmt, 4, taskId, -1, Self.TRANSIENT)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }

    // MARK: - Read

    func allTasks() -> [TaskRecord] {
        return queue.sync {
            readRecords("SELECT * FROM tasks ORDER BY updated_at DESC", params: [])
        }
    }

    func task(taskId: String) -> TaskRecord? {
        return queue.sync {
            readRecords("SELECT * FROM tasks WHERE task_id = ?", params: [taskId]).first
        }
    }

    func tasks(forTag tag: String) -> [TaskRecord] {
        return queue.sync {
            readRecords("SELECT * FROM tasks WHERE tag = ? ORDER BY updated_at DESC", params: [tag])
        }
    }

    func delete(taskId: String) {
        queue.async(flags: .barrier) {
            if let stmt = self.prepare("DELETE FROM tasks WHERE task_id = ?") {
                sqlite3_bind_text(stmt, 1, taskId, -1, Self.TRANSIENT)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }

    /// Delete terminal-state tasks older than [olderThanMs] milliseconds.
    ///
    /// Call on initialize() to auto-prune the task store and prevent unbounded growth.
    func deleteCompleted(olderThanMs: Int64 = 0) {
        let threshold = olderThanMs > 0
            ? Int64(Date().timeIntervalSince1970 * 1000) - olderThanMs
            : Int64.max
        queue.async(flags: .barrier) {
            let sql = "DELETE FROM tasks WHERE status IN ('completed','failed','cancelled') AND updated_at < ?"
            if let stmt = self.prepare(sql) {
                sqlite3_bind_int64(stmt, 1, threshold)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }

    /// Returns a sanitized copy of a JSON worker-config string with sensitive
    /// fields (auth tokens, cookies) removed before persisting to disk.
    ///
    /// Sensitive keys stripped: `authToken`, `cookies`, `password`, `secret`.
    /// The worker runtime always receives the full in-memory config; only the
    /// persisted (SQLite) copy is sanitized.
    static func sanitizeConfig(_ json: String?) -> String? {
        guard let json = json,
              let data = json.data(using: .utf8),
              var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return json
        }
        let sensitiveKeys: Set<String> = ["authToken", "cookies", "password", "secret"]
        sensitiveKeys.forEach { dict.removeValue(forKey: $0) }
        guard let sanitized = try? JSONSerialization.data(withJSONObject: dict),
              let result = String(data: sanitized, encoding: .utf8) else { return json }
        return result
    }

    // MARK: - Helpers

    private func prepare(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK { return nil }
        return stmt
    }

    private func bindNullableText(_ stmt: OpaquePointer, _ idx: Int32, _ value: String?) {
        if let v = value {
            sqlite3_bind_text(stmt, idx, v, -1, Self.TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, idx)
        }
    }

    private func readRecords(_ sql: String, params: [String]) -> [TaskRecord] {
        guard let stmt = prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }
        for (i, p) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), p, -1, Self.TRANSIENT)
        }
        var records: [TaskRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            func col(_ i: Int32) -> String? {
                guard let ptr = sqlite3_column_text(stmt, i) else { return nil }
                return String(cString: ptr)
            }
            records.append(TaskRecord(
                taskId:          col(0) ?? "",
                tag:             col(1),
                status:          col(2) ?? "unknown",
                workerClassName: col(3) ?? "",
                workerConfig:    col(4),
                createdAt:       sqlite3_column_int64(stmt, 5),
                updatedAt:       sqlite3_column_int64(stmt, 6),
                resultData:      col(7)
            ))
        }
        return records
    }

    private static let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
