import Foundation

/// Persistent store for task chains on iOS using SQLite.
/// Replaces UserDefaults for improved reliability and ACID compliance.
class ChainStore {
    private let sqlite: SQLiteStore

    init(sqlite: SQLiteStore) {
        self.sqlite = sqlite
        createTable()
    }

    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS chains (
            id TEXT PRIMARY KEY,
            name TEXT,
            total_steps INTEGER NOT NULL,
            current_step INTEGER NOT NULL,
            is_completed INTEGER NOT NULL,
            full_state_json TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );
        """
        sqlite.execute(sql: sql)
    }

    func upsertChain(id: String, name: String?, totalSteps: Int, currentStep: Int, isCompleted: Bool, stateJson: String) {
        let now = Int(Date().timeIntervalSince1970)
        let sql = """
        INSERT INTO chains (id, name, total_steps, current_step, is_completed, full_state_json, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            current_step = excluded.current_step,
            is_completed = excluded.is_completed,
            full_state_json = excluded.full_state_json,
            updated_at = excluded.updated_at;
        """
        sqlite.execute(sql: sql, params: [
            id, 
            name ?? NSNull(), 
            totalSteps, 
            currentStep, 
            isCompleted ? 1 : 0, 
            stateJson, 
            now, 
            now
        ])
    }

    func getChain(id: String) -> [String: Any]? {
        let sql = "SELECT * FROM chains WHERE id = ? LIMIT 1;"
        return sqlite.query(sql: sql, params: [id]).first
    }

    func getAllChains() -> [[String: Any]] {
        let sql = "SELECT * FROM chains;"
        return sqlite.query(sql: sql)
    }

    func deleteChain(id: String) {
        let sql = "DELETE FROM chains WHERE id = ?;"
        sqlite.execute(sql: sql, params: [id])
    }

    func cleanup(olderThan: Date) {
        let timestamp = Int(olderThan.timeIntervalSince1970)
        let sql = "DELETE FROM chains WHERE updated_at < ? AND is_completed = 1;"
        sqlite.execute(sql: sql, params: [timestamp])
    }
}
