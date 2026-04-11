import Foundation
import SQLite3

/// Internal SQLite wrapper for native_workmanager persistence on iOS.
/// Uses the system's sqlite3 library directly to avoid external dependencies.
class SQLiteStore {
    private var db: OpaquePointer?
    private let dbPath: String
    private let queue = DispatchQueue(label: "dev.brewkits.native_workmanager.db", qos: .utility)

    init(name: String) {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeDir = appSupport.appendingPathComponent("native_workmanager", isDirectory: true)
        
        if !fileManager.fileExists(atPath: storeDir.path) {
            try? fileManager.createDirectory(at: storeDir, withIntermediateDirectories: true)
        }
        
        self.dbPath = storeDir.appendingPathComponent("\(name).sqlite").path
        open()
    }

    deinit {
        close()
    }

    private func open() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("[NativeWorkmanager] Error opening database at \(dbPath)")
        } else {
            // Enable WAL mode for better concurrency (one writer, many readers)
            execute(sql: "PRAGMA journal_mode=WAL;")
        }
    }

    private func close() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    @discardableResult
    func execute(sql: String, params: [Any] = []) -> Bool {
        return queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
                print("[NativeWorkmanager] Error preparing SQL: \(sql)")
                return false
            }
            
            bind(statement: statement, params: params)
            
            // Loop until SQLITE_DONE and handle SQLITE_BUSY (retry up to maxRetries times)
            var result = sqlite3_step(statement)
            var retryCount = 0
            let maxRetries = 5
            
            while result == SQLITE_BUSY && retryCount < maxRetries {
                retryCount += 1
                usleep(50_000) // Sleep 50ms
                result = sqlite3_step(statement)
            }
            
            sqlite3_finalize(statement)
            return result == SQLITE_DONE
        }
    }

    func query(sql: String, params: [Any] = []) -> [[String: Any]] {
        return queue.sync {
            var statement: OpaquePointer?
            var results: [[String: Any]] = []
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
                print("[NativeWorkmanager] Error preparing query: \(sql)")
                return []
            }
            
            bind(statement: statement, params: params)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                var row: [String: Any] = [:]
                let columnCount = sqlite3_column_count(statement)
                
                for i in 0..<columnCount {
                    let name = String(cString: sqlite3_column_name(statement, i))
                    let type = sqlite3_column_type(statement, i)
                    
                    switch type {
                    case SQLITE_INTEGER:
                        row[name] = Int(sqlite3_column_int64(statement, i))
                    case SQLITE_FLOAT:
                        row[name] = Double(sqlite3_column_double(statement, i))
                    case SQLITE_TEXT:
                        row[name] = String(cString: sqlite3_column_text(statement, i))
                    case SQLITE_BLOB:
                        let data = sqlite3_column_blob(statement, i)
                        let size = sqlite3_column_bytes(statement, i)
                        if let data = data {
                            row[name] = Data(bytes: data, count: Int(size))
                        }
                    case SQLITE_NULL:
                        row[name] = NSNull()
                    default:
                        break
                    }
                }
                results.append(row)
            }
            
            sqlite3_finalize(statement)
            return results
        }
    }

    private func bind(statement: OpaquePointer?, params: [Any]) {
        for (i, param) in params.enumerated() {
            let index = Int32(i + 1)
            if let value = param as? Int {
                sqlite3_bind_int64(statement, index, Int64(value))
            } else if let value = param as? Double {
                sqlite3_bind_double(statement, index, value)
            } else if let value = param as? String {
                sqlite3_bind_text(statement, index, (value as NSString).utf8String, -1, nil)
            } else if let value = param as? Data {
                sqlite3_bind_blob(statement, index, (value as NSData).bytes, Int32(value.count), nil)
            } else if param is NSNull {
                sqlite3_bind_null(statement, index)
            } else if let value = param as? Bool {
                sqlite3_bind_int(statement, index, value ? 1 : 0)
            }
        }
    }
}
