import Flutter

// MARK: - Chain Enqueue
// Handles the `enqueueChain` method channel call.
// Separated from NativeWorkmanagerPlugin.swift to reduce God Object complexity.

extension NativeWorkmanagerPlugin {

    /// Handle `enqueueChain` method channel call.
    ///
    /// Parses the chain payload from Dart (`name`, `steps`, `constraints`),
    /// registers all step task IDs in `activeTasks` pointing to the same Swift
    /// `Task` so that `cancel(taskId: stepId)` cancels the entire chain, then
    /// returns "ACCEPTED" to Dart immediately before executing asynchronously.
    func handleEnqueueChain(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let steps = args["steps"] as? [[Any]],
              !steps.isEmpty else {
            result(FlutterError(code: "INVALID_ARGS", message: "Chain must have at least one step", details: nil))
            return
        }

        let chainName = args["name"] as? String
        let constraintsMap = args["constraints"] as? [String: Any]
        let chainCancelId = "chain_\(UUID().uuidString)"

        // Collect all step task IDs so we can register them for individual cancellation.
        var allStepIds: [String] = []
        for step in steps {
            if let stepTasks = step as? [[String: Any]] {
                for task in stepTasks {
                    if let taskId = task["id"] as? String {
                        allStepIds.append(taskId)
                    }
                }
            }
        }

        // Start the chain task. Return ACCEPTED to Dart first (M1 fix: don't block).
        let chainTask = Task { [weak self] in
            guard let self else { return }
            await self.executeChain(
                chainCancelId: chainCancelId,
                steps: steps,
                chainName: chainName,
                constraintsMap: constraintsMap,
                qos: "background"
            )
            // Cleanup step-ID → task mappings after the chain finishes.
            self.stateQueue.async(flags: .barrier) {
                for stepId in allStepIds {
                    self.activeTasks.removeValue(forKey: stepId)
                }
                self.activeTasks.removeValue(forKey: chainCancelId)
            }
        }

        // Register the chain and every individual step ID in activeTasks.
        // This means cancel(taskId: idB) will cancel the whole chain Task,
        // which is checked via `Task.isCancelled` between steps in executeChain.
        stateQueue.sync(flags: .barrier) {
            activeTasks[chainCancelId] = chainTask
            taskStates[chainCancelId] = "pending"
            for stepId in allStepIds {
                activeTasks[stepId] = chainTask
                taskStates[stepId] = "pending"
            }
        }

        result("ACCEPTED")
    }
}
