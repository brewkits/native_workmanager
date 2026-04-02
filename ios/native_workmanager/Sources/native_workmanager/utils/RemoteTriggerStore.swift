import Foundation
import SQLite3

/// Persistent store for remote trigger rules (FCM/APNs mappings) on iOS.
@available(iOS 13.0, *)
final class RemoteTriggerStore {

    static let shared = RemoteTriggerStore()

    struct RemoteTriggerRecord {
        let source: String
        let payloadKey: String
        let workerMappingsJson: String
        let updatedAt: Int64
    }

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "dev.brewkits.remotetriggerstore", attributes: .concurrent)

    private init() {
        openDatabase()
        createTable()
    }

    deinit { sqlite3_close(db) }

    private func openDatabase() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path = dir.appendingPathComponent("native_workmanager.db").path
        if sqlite3_open(path, &db) != SQLITE_OK {
            NSLog("RemoteTriggerStore: Failed to open database at \(path)")
        }
    }

    private func createTable() {
        let sql = """
            CREATE TABLE IF NOT EXISTS remote_triggers (
                source               TEXT PRIMARY KEY,
                payload_key          TEXT NOT NULL,
                worker_mappings_json TEXT NOT NULL,
                updated_at           INTEGER NOT NULL
            );
        """
        queue.sync(flags: .barrier) {
            _ = sqlite3_exec(db, sql, nil, nil, nil)
        }
    }

    func upsert(source: String, payloadKey: String, workerMappingsJson: String) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        queue.async(flags: .barrier) {
            let sql = "INSERT OR REPLACE INTO remote_triggers (source, payload_key, worker_mappings_json, updated_at) VALUES (?, ?, ?, ?)"
            if let stmt = self.prepare(sql) {
                sqlite3_bind_text(stmt, 1, source, -1, Self.TRANSIENT)
                sqlite3_bind_text(stmt, 2, payloadKey, -1, Self.TRANSIENT)
                sqlite3_bind_text(stmt, 3, workerMappingsJson, -1, Self.TRANSIENT)
                sqlite3_bind_int64(stmt, 4, now)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }

    func getRule(source: String) -> RemoteTriggerRecord? {
        return queue.sync {
            guard let stmt = prepare("SELECT * FROM remote_triggers WHERE source = ?") else { return nil }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, source, -1, Self.TRANSIENT)
            
            if sqlite3_step(stmt) == SQLITE_ROW {
                func col(_ i: Int32) -> String? {
                    guard let ptr = sqlite3_column_text(stmt, i) else { return nil }
                    return String(cString: ptr)
                }
                return RemoteTriggerRecord(
                    source: col(0) ?? "",
                    payloadKey: col(1) ?? "",
                    workerMappingsJson: col(2) ?? "{}",
                    updatedAt: sqlite3_column_int64(stmt, 3)
                )
            }
            return nil
        }
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK { return nil }
        return stmt
    }

    private static let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
