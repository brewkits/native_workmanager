import Foundation
import SQLite3

/// Persistent store for task middleware rules on iOS.
@available(iOS 13.0, *)
final class MiddlewareStore {

    static let shared = MiddlewareStore()

    struct MiddlewareRecord {
        let id: Int64
        let type: String
        let configJson: String
        let updatedAt: Int64
    }

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "dev.brewkits.middlewarestore", attributes: .concurrent)

    private init() {
        openDatabase()
        createTable()
    }

    deinit { sqlite3_close(db) }

    private func openDatabase() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path = dir.appendingPathComponent("native_workmanager.db").path
        if sqlite3_open(path, &db) != SQLITE_OK {
            NSLog("MiddlewareStore: Failed to open database at \(path)")
        }
    }

    private func createTable() {
        let sql = """
            CREATE TABLE IF NOT EXISTS middleware (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                type        TEXT NOT NULL,
                config_json TEXT NOT NULL,
                updated_at  INTEGER NOT NULL
            );
        """
        queue.sync(flags: .barrier) {
            _ = sqlite3_exec(db, sql, nil, nil, nil)
        }
    }

    func add(type: String, configJson: String) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        queue.async(flags: .barrier) {
            let sql = "INSERT INTO middleware (type, config_json, updated_at) VALUES (?, ?, ?)"
            if let stmt = self.prepare(sql) {
                sqlite3_bind_text(stmt, 1, type, -1, Self.TRANSIENT)
                sqlite3_bind_text(stmt, 2, configJson, -1, Self.TRANSIENT)
                sqlite3_bind_int64(stmt, 3, now)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }

    func getAll() -> [MiddlewareRecord] {
        return queue.sync {
            readRecords("SELECT * FROM middleware", params: [])
        }
    }

    func clear() {
        queue.async(flags: .barrier) {
            _ = sqlite3_exec(self.db, "DELETE FROM middleware", nil, nil, nil)
        }
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK { return nil }
        return stmt
    }

    private func readRecords(_ sql: String, params: [String]) -> [MiddlewareRecord] {
        guard let stmt = prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }
        for (i, p) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), p, -1, Self.TRANSIENT)
        }
        var records: [MiddlewareRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            func col(_ i: Int32) -> String? {
                guard let ptr = sqlite3_column_text(stmt, i) else { return nil }
                return String(cString: ptr)
            }
            records.append(MiddlewareRecord(
                id:         sqlite3_column_int64(stmt, 0),
                type:       col(1) ?? "",
                configJson: col(2) ?? "{}",
                updatedAt:  sqlite3_column_int64(stmt, 3)
            ))
        }
        return records
    }

    private static let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
