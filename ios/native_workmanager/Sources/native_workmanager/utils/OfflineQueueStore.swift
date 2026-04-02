import Foundation
import SQLite3

/// Persistent store for the Offline Queue Pattern on iOS.
@available(iOS 13.0, *)
final class OfflineQueueStore {

    static let shared = OfflineQueueStore()

    struct QueueRecord {
        let id: Int64
        let queueId: String
        let taskId: String
        let workerClassName: String
        let workerConfig: String?
        let retryPolicy: String?
        let createdAt: Int64
    }

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "dev.brewkits.offlinequeuestore", attributes: .concurrent)

    private init() {
        openDatabase()
        createTable()
    }

    deinit { sqlite3_close(db) }

    private func openDatabase() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path = dir.appendingPathComponent("native_workmanager.db").path
        if sqlite3_open(path, &db) != SQLITE_OK {
            NSLog("OfflineQueueStore: Failed to open database at \(path)")
        }
    }

    private func createTable() {
        let sql = """
            CREATE TABLE IF NOT EXISTS offline_queue (
                id              INTEGER PRIMARY KEY AUTOINCREMENT,
                queue_id        TEXT NOT NULL,
                task_id         TEXT NOT NULL,
                worker_class    TEXT NOT NULL,
                worker_config   TEXT,
                retry_policy    TEXT,
                created_at      INTEGER NOT NULL
            );
        """
        queue.sync(flags: .barrier) {
            _ = sqlite3_exec(db, sql, nil, nil, nil)
        }
    }

    func enqueue(
        queueId: String,
        taskId: String,
        workerClassName: String,
        workerConfig: String?,
        retryPolicy: String?
    ) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        queue.async(flags: .barrier) {
            let sql = "INSERT INTO offline_queue (queue_id, task_id, worker_class, worker_config, retry_policy, created_at) VALUES (?, ?, ?, ?, ?, ?)"
            if let stmt = self.prepare(sql) {
                sqlite3_bind_text(stmt, 1, queueId, -1, Self.TRANSIENT)
                sqlite3_bind_text(stmt, 2, taskId, -1, Self.TRANSIENT)
                sqlite3_bind_text(stmt, 3, workerClassName, -1, Self.TRANSIENT)
                self.bindNullableText(stmt, 4, workerConfig)
                self.bindNullableText(stmt, 5, retryPolicy)
                sqlite3_bind_int64(stmt, 6, now)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }

    func getNextEntries(limit: Int = 10) -> [QueueRecord] {
        return queue.sync {
            readRecords("SELECT * FROM offline_queue ORDER BY created_at ASC LIMIT ?", params: [String(limit)])
        }
    }

    func delete(id: Int64) {
        queue.async(flags: .barrier) {
            if let stmt = self.prepare("DELETE FROM offline_queue WHERE id = ?") {
                sqlite3_bind_int64(stmt, 1, id)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }

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

    private func readRecords(_ sql: String, params: [String]) -> [QueueRecord] {
        guard let stmt = prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }
        for (i, p) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), p, -1, Self.TRANSIENT)
        }
        var records: [QueueRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            func col(_ i: Int32) -> String? {
                guard let ptr = sqlite3_column_text(stmt, i) else { return nil }
                return String(cString: ptr)
            }
            records.append(QueueRecord(
                id:              sqlite3_column_int64(stmt, 0),
                queueId:         col(1) ?? "",
                taskId:          col(2) ?? "",
                workerClassName: col(3) ?? "",
                workerConfig:    col(4),
                retryPolicy:     col(5),
                createdAt:       sqlite3_column_int64(stmt, 6)
            ))
        }
        return records
    }

    private static let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
