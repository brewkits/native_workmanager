import Foundation
import SQLite3

/// Persistent store for remote trigger rules (FCM/APNs mappings) on iOS.
///
/// **Security:** Sensitive `secret_key` is stored in the iOS Keychain via KeystorePasswordVault.
/// The `secret_key` column in SQLite is preserved for backward compatibility and migration.
@available(iOS 13.0, *)
final class RemoteTriggerStore {

    static let shared = RemoteTriggerStore()

    struct RemoteTriggerRecord {
        let source: String
        let payloadKey: String
        let workerMappingsJson: String
        let updatedAt: Int64
        let secretKey: String?
    }

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "dev.brewkits.remotetriggerstore", attributes: .concurrent)
    private let migrationLock = NSLock()

    private init() {
        openDatabase()
        createTable()
        upgradeSchema()
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
                updated_at           INTEGER NOT NULL,
                secret_key           TEXT
            );
        """
        queue.async(flags: .barrier) {
            _ = sqlite3_exec(self.db, sql, nil, nil, nil)
        }
    }

    private func upgradeSchema() {
        queue.async(flags: .barrier) {
            // Simple check to add secret_key if it doesn't exist
            let sql = "ALTER TABLE remote_triggers ADD COLUMN secret_key TEXT"
            _ = sqlite3_exec(self.db, sql, nil, nil, nil)
        }
    }

    func upsert(source: String, payloadKey: String, workerMappingsJson: String, secretKey: String? = nil) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        
        if let key = secretKey {
            KeystorePasswordVault.shared.upsert(account: "rt_\(source)", secret: key)
        } else {
            KeystorePasswordVault.shared.deletePersistent(account: "rt_\(source)")
        }

        queue.async(flags: .barrier) {
            let sql = "INSERT OR REPLACE INTO remote_triggers (source, payload_key, worker_mappings_json, updated_at, secret_key) VALUES (?, ?, ?, ?, ?)"
            if let stmt = self.prepare(sql) {
                sqlite3_bind_text(stmt, 1, source, -1, Self.TRANSIENT)
                sqlite3_bind_text(stmt, 2, payloadKey, -1, Self.TRANSIENT)
                sqlite3_bind_text(stmt, 3, workerMappingsJson, -1, Self.TRANSIENT)
                sqlite3_bind_int64(stmt, 4, now)
                sqlite3_bind_null(stmt, 5)
                
                let result = sqlite3_step(stmt)
                if result == SQLITE_FULL {
                    NativeLogger.e("🚨 DISK FULL: Cannot upsert remote trigger")
                }
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
                
                let sourceVal = col(0) ?? ""
                let sqliteSecretKey = col(4)
                
                var finalSecretKey = KeystorePasswordVault.shared.retrieve(account: "rt_\(sourceVal)")
                
                if finalSecretKey == nil && sqliteSecretKey != nil {
                    // SEC-001: Thread-safe migration
                    migrationLock.lock()
                    defer { migrationLock.unlock() }
                    
                    finalSecretKey = KeystorePasswordVault.shared.retrieve(account: "rt_\(sourceVal)")
                    if finalSecretKey == nil, let keyToMigrate = sqliteSecretKey {
                        KeystorePasswordVault.shared.upsert(account: "rt_\(sourceVal)", secret: keyToMigrate)
                        finalSecretKey = keyToMigrate
                    }
                }

                return RemoteTriggerRecord(
                    source: sourceVal,
                    payloadKey: col(1) ?? "",
                    workerMappingsJson: col(2) ?? "{}",
                    updatedAt: sqlite3_column_int64(stmt, 3),
                    secretKey: finalSecretKey
                )
            }
            return nil
        }
    }

    func delete(source: String) {
        KeystorePasswordVault.shared.deletePersistent(account: "rt_\(source)")
        queue.async(flags: .barrier) {
            let sql = "DELETE FROM remote_triggers WHERE source = ?"
            if let stmt = self.prepare(sql) {
                sqlite3_bind_text(stmt, 1, source, -1, Self.TRANSIENT)
                let result = sqlite3_step(stmt)
                if result == SQLITE_FULL {
                    NativeLogger.e("🚨 DISK FULL: Cannot delete remote trigger")
                }
                sqlite3_finalize(stmt)
            }
        }
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK { return nil }
        return stmt
    }

    private static let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
