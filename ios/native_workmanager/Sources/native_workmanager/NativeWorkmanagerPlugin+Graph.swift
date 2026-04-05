import Foundation
import Flutter

extension NativeWorkmanagerPlugin {

    internal func handleEnqueueGraph(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let graphMap = args["graph"] as? [String: Any],
              let graphId = graphMap["id"] as? String,
              let nodeMaps = graphMap["nodes"] as? [[String: Any]] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
            return
        }

        NativeLogger.d("🕸️ Enqueuing native TaskGraph '\(graphId)' with \(nodeMaps.count) nodes")

        guard #available(iOS 13.0, *) else {
            result(FlutterError(code: "UNSUPPORTED_OS",
                                message: "TaskGraph requires iOS 13.0 or later",
                                details: nil))
            return
        }

        // 1. Persist all nodes to GraphStore
        for nodeData in nodeMaps {
            let nodeId = nodeData["id"] as? String ?? ""
            let workerClassName = nodeData["workerClassName"] as? String ?? ""
            let workerConfigRaw = nodeData["workerConfig"] as? [String: Any] ?? [:]

            // Apply middleware (Phase 2)
            let workerConfig = NativeWorkmanagerPlugin.applyMiddleware(workerClassName: workerClassName, config: workerConfigRaw)

            let dependsOn = nodeData["dependsOn"] as? [String] ?? []
            let constraints = nodeData["constraints"] as? [String: Any]

            let configJson: String? = {
                let dict = TaskStore.sanitizeConfig(workerConfig)
                guard let data = try? JSONSerialization.data(withJSONObject: dict as Any),
                      let s = String(data: data, encoding: .utf8) else { return nil }
                return s
            }()

            let constraintsJson: String? = {
                guard let dict = constraints,
                      let data = try? JSONSerialization.data(withJSONObject: dict),
                      let s = String(data: data, encoding: .utf8) else { return nil }
                return s
            }()

            let record = GraphStore.NodeRecord(
                graphId: graphId,
                nodeId: nodeId,
                dependsOn: dependsOn,
                status: "pending",
                workerClassName: workerClassName,
                workerConfig: configJson,
                constraints: constraintsJson
            )
            GraphStore.shared.upsertNode(record: record)

            // Also persist to TaskStore so allTasks() surfaces graph nodes
            let taskId = "\(graphId)__\(nodeId)"
            taskStore?.upsert(
                taskId: taskId,
                tag: graphId,
                status: "pending",
                workerClassName: workerClassName,
                workerConfig: configJson
            )
        }

        // 2. Start root nodes (those with no dependencies)
        let allNodes = GraphStore.shared.getNodes(forGraph: graphId)
        let rootNodes = allNodes.filter { $0.dependsOn.isEmpty }

        for node in rootNodes {
            executeGraphNode(node)
        }

        result("ACCEPTED")
    }

    @available(iOS 13.0, *)
    internal func executeGraphNode(_ node: GraphStore.NodeRecord) {
        let taskId = "\(node.graphId)__\(node.nodeId)"
        
        NativeLogger.d("🚀 Executing graph node: \(taskId)")
        
        GraphStore.shared.updateNodeStatus(graphId: node.graphId, nodeId: node.nodeId, status: "running")
        
        // Use existing executeWorkerSync logic
        guard let configData = node.workerConfig?.data(using: .utf8),
              let workerConfig = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] else {
            NativeLogger.e("❌ Failed to parse config for graph node \(taskId)")
            handleGraphNodeCompletion(graphId: node.graphId, nodeId: node.nodeId, success: false, message: "Config error")
            return
        }

        Task {
            let success = await self.executeWorkerSync(
                taskId: taskId,
                workerClassName: node.workerClassName,
                workerConfig: workerConfig,
                qos: "background"
            )

            handleGraphNodeCompletion(graphId: node.graphId, nodeId: node.nodeId, success: success.success, message: success.message)
        }
    }

    @available(iOS 13.0, *)
    private func handleGraphNodeCompletion(graphId: String, nodeId: String, success: Bool, message: String?) {
        let status = success ? "completed" : "failed"
        GraphStore.shared.updateNodeStatus(graphId: graphId, nodeId: nodeId, status: status)
        
        if success {
            // Check dependents
            let dependents = GraphStore.shared.getDependents(graphId: graphId, completedNodeId: nodeId)
            for dependent in dependents {
                checkAndStartNode(dependent)
            }
        } else {
            // Fail downstream nodes
            cancelDownstreamNodes(graphId: graphId, failedNodeId: nodeId)
        }
    }

    @available(iOS 13.0, *)
    private func checkAndStartNode(_ node: GraphStore.NodeRecord) {
        let graphId = node.graphId
        let allNodes = GraphStore.shared.getNodes(forGraph: graphId)
        let nodeMap = Dictionary(uniqueKeysWithValues: allNodes.map { ($0.nodeId, $0) })
        
        // Are all dependencies completed?
        let allDepsDone = node.dependsOn.allSatisfy { depId in
            nodeMap[depId]?.status == "completed"
        }
        
        if allDepsDone && node.status == "pending" {
            executeGraphNode(node)
        }
    }

    @available(iOS 13.0, *)
    private func cancelDownstreamNodes(graphId: String, failedNodeId: String) {
        var queue = [failedNodeId]
        var visited = Set<String>()
        
        while !queue.isEmpty {
            let currentId = queue.removeFirst()
            let dependents = GraphStore.shared.getDependents(graphId: graphId, completedNodeId: currentId)
            for dep in dependents {
                if !visited.contains(dep.nodeId) {
                    GraphStore.shared.updateNodeStatus(graphId: graphId, nodeId: dep.nodeId, status: "cancelled")
                    visited.insert(dep.nodeId)
                    queue.append(dep.nodeId)
                }
            }
        }
    }
    
    @available(iOS 13.0, *)
    internal func resumePendingGraphs() {
        // Collect every pending/running node across all graphs and start any whose
        // dependencies are fully completed. This covers the app-killed scenario where
        // a node was "running" or "pending" when the process was terminated.
        let allNodes = GraphStore.shared.getAllNodes()
        guard !allNodes.isEmpty else { return }

        // Group by graphId for efficient dependency lookups
        let byGraph = Dictionary(grouping: allNodes, by: { $0.graphId })

        for (_, nodes) in byGraph {
            let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.nodeId, $0) })

            for node in nodes {
                // Re-run nodes that are pending or were interrupted mid-execution (running)
                guard node.status == "pending" || node.status == "running" else { continue }

                let allDepsDone = node.dependsOn.allSatisfy { depId in
                    nodeMap[depId]?.status == "completed"
                }

                if allDepsDone {
                    NativeLogger.d("🔄 Resuming graph node: \(node.graphId)__\(node.nodeId) (was \(node.status))")
                    executeGraphNode(node)
                }
            }
        }
    }
}
