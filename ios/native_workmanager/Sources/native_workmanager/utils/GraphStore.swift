import Foundation
import SQLite3

/// Persistent store for TaskGraph nodes and their dependencies on iOS.
@available(iOS 13.0, *)
final class GraphStore {

    static let shared = GraphStore()

    struct NodeRecord {
        let graphId: String
        let nodeId: String
        let dependsOn: [String]
        let status: String // pending | running | completed | failed | cancelled
        let workerClassName: String
        let workerConfig: String?
        let constraints: String?
    }

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "dev.brewkits.graphstore", attributes: .concurrent)

    private init() {
        openDatabase()
        createTables()
    }

    deinit { sqlite3_close(db) }

    private func openDatabase() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path = dir.appendingPathComponent("native_workmanager.db").path
        if sqlite3_open(path, &db) != SQLITE_OK {
            NSLog("GraphStore: Failed to open database at \(path)")
        }
    }

    private func createTables() {
        let sqlNodes = """
            CREATE TABLE IF NOT EXISTS graph_nodes (
                graph_id         TEXT NOT NULL,
                node_id          TEXT NOT NULL,
                depends_on       TEXT, -- JSON array of node_ids
                status           TEXT NOT NULL,
                worker_class     TEXT NOT NULL,
                worker_config    TEXT,
                constraints      TEXT,
                updated_at       INTEGER NOT NULL,
                PRIMARY KEY (graph_id, node_id)
            );
        """
        queue.sync(flags: .barrier) {
            _ = sqlite3_exec(db, sqlNodes, nil, nil, nil)
        }
    }

    func upsertNode(record: NodeRecord) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let dependsOnJson = try? JSONSerialization.data(withJSONObject: record.dependsOn)
        let dependsOnString = dependsOnJson.flatMap { String(data: $0, encoding: .utf8) }

        queue.async(flags: .barrier) {
            let sql = "INSERT OR REPLACE INTO graph_nodes (graph_id, node_id, depends_on, status, worker_class, worker_config, constraints, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
            if let stmt = self.prepare(sql) {
                sqlite3_bind_text(stmt, 1, record.graphId, -1, Self.TRANSIENT)
                sqlite3_bind_text(stmt, 2, record.nodeId, -1, Self.TRANSIENT)
                self.bindNullableText(stmt, 3, dependsOnString)
                sqlite3_bind_text(stmt, 4, record.status, -1, Self.TRANSIENT)
                sqlite3_bind_text(stmt, 5, record.workerClassName, -1, Self.TRANSIENT)
                self.bindNullableText(stmt, 6, record.workerConfig)
                self.bindNullableText(stmt, 7, record.constraints)
                sqlite3_bind_int64(stmt, 8, now)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }

    func updateNodeStatus(graphId: String, nodeId: String, status: String) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        queue.async(flags: .barrier) {
            let sql = "UPDATE graph_nodes SET status = ?, updated_at = ? WHERE graph_id = ? AND node_id = ?"
            if let stmt = self.prepare(sql) {
                sqlite3_bind_text(stmt, 1, status, -1, Self.TRANSIENT)
                sqlite3_bind_int64(stmt, 2, now)
                sqlite3_bind_text(stmt, 3, graphId, -1, Self.TRANSIENT)
                sqlite3_bind_text(stmt, 4, nodeId, -1, Self.TRANSIENT)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }

    func getNodes(forGraph graphId: String) -> [NodeRecord] {
        return queue.sync {
            readRecords("SELECT * FROM graph_nodes WHERE graph_id = ?", params: [graphId])
        }
    }

    func getAllNodes() -> [NodeRecord] {
        return queue.sync {
            readRecords("SELECT * FROM graph_nodes", params: [])
        }
    }
    
    func getNode(graphId: String, nodeId: String) -> NodeRecord? {
        return queue.sync {
            readRecords("SELECT * FROM graph_nodes WHERE graph_id = ? AND node_id = ?", params: [graphId, nodeId]).first
        }
    }
    
    func getDependents(graphId: String, completedNodeId: String) -> [NodeRecord] {
        // Find nodes that have completedNodeId in their depends_on JSON array
        return queue.sync {
            let all = readRecords("SELECT * FROM graph_nodes WHERE graph_id = ?", params: [graphId])
            return all.filter { record in
                record.dependsOn.contains(completedNodeId)
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

    private func readRecords(_ sql: String, params: [String]) -> [NodeRecord] {
        guard let stmt = prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }
        for (i, p) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), p, -1, Self.TRANSIENT)
        }
        var records: [NodeRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            func col(_ i: Int32) -> String? {
                guard let ptr = sqlite3_column_text(stmt, i) else { return nil }
                return String(cString: ptr)
            }
            let dependsOnJson = col(2) ?? "[]"
            let dependsOn: [String]
            if let data = dependsOnJson.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String] {
                dependsOn = parsed
            } else {
                NSLog("GraphStore: failed to parse depends_on JSON: \(dependsOnJson)")
                dependsOn = []
            }
            
            records.append(NodeRecord(
                graphId:         col(0) ?? "",
                nodeId:          col(1) ?? "",
                dependsOn:       dependsOn,
                status:          col(3) ?? "unknown",
                workerClassName: col(4) ?? "",
                workerConfig:    col(5),
                constraints:     col(6)
            ))
        }
        return records
    }

    private static let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
