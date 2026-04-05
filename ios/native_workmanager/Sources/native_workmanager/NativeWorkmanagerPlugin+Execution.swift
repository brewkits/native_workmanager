import Flutter
import UIKit

// MARK: - Task Execution
// Separated from NativeWorkmanagerPlugin.swift to reduce God Object complexity.
// Contains chain execution, worker dispatch, retry logic, and QoS mapping.

extension NativeWorkmanagerPlugin {

    // MARK: - Chain Resume

    /// Resume incomplete chains that were interrupted by app kill
    func resumePendingChains() async {
        NativeLogger.d("Checking for pending chains to resume...")

        do {
            // Cleanup old/completed chains first
            try await chainStateManager.cleanupOldStates()

            // Load resumable chains
            let resumableChains = try await chainStateManager.loadResumableChains()

            if resumableChains.isEmpty {
                NativeLogger.d("No pending chains to resume")
                return
            }

            NativeLogger.d("Found \(resumableChains.count) chain(s) to resume")

            // Resume each chain
            for chainState in resumableChains {
                NativeLogger.d("Resuming chain '\(chainState.chainId)'")
                NativeLogger.d("  Progress: Step \(chainState.currentStep + 1)/\(chainState.totalSteps)")

                // ✅ ISSUE 2 FIX: Wrap resumption in a background task
                let taskId = UIApplication.shared.beginBackgroundTask(withName: "ResumingChain_\(chainState.chainId)") { [weak self] in
                    self?.stopAllWorkers()
                }
                
                await resumeChain(chainState: chainState)
                
                UIApplication.shared.endBackgroundTask(taskId)
            }
        } catch {
            NativeLogger.d("Error resuming chains: \(error)")
        }
    }

    /// Resume a specific chain from saved state
    func resumeChain(chainState: ChainStateManager.ChainState) async {
        let chainId = chainState.chainId
        let startStep = chainState.currentStep
        let steps = chainState.steps

        NativeLogger.d("Resuming chain '\(chainId)' from step \(startStep + 1)")

        // Execute remaining steps
        for stepIndex in startStep..<steps.count {
            // Check cancellation
            guard !Task.isCancelled else { return }
            
            let stepTasks = steps[stepIndex]
            NativeLogger.d("Chain '\(chainId)' - Step \(stepIndex + 1)/\(steps.count)")

            // Get previous step's result for data flow
            let previousStepData = try? await chainStateManager.getPreviousStepResult(
                chainId: chainId,
                currentStepIndex: stepIndex
            )

            // Execute tasks in the step
            var stepSucceeded = false
            var stepResultData: [String: Any]? = nil

            // iOS 15 (Swift 5.5) compat: DartCallbackWorker tasks must run
            // sequentially (see executeChain for rationale).
            let hasDartCallback = stepTasks.contains {
                $0.workerClassName == "DartCallbackWorker"
            }

            if hasDartCallback {
                var allSucceeded = true
                for task in stepTasks {
                    let taskId = task.taskId
                    let workerClassName = task.workerClassName
                    var workerConfig: [String: Any] = task.workerConfig.mapValues { $0.value }
                    if let previousData = previousStepData {
                        workerConfig = substitutePlaceholders(config: workerConfig, data: previousData)
                    }
                    let taskResult = await executeWorkerSync(
                        taskId: taskId,
                        workerClassName: workerClassName,
                        workerConfig: workerConfig,
                        qos: "background"
                    )
                    if !taskResult.success {
                        allSucceeded = false
                    } else if let data = taskResult.data {
                        stepResultData = data
                    }
                }
                stepSucceeded = allSucceeded
            } else {
                await withTaskGroup(of: WorkerResult.self) { group in
                    for task in stepTasks {
                        let taskId = task.taskId
                        let workerClassName = task.workerClassName
                        // ✅ ISSUE 1 FIX: Secure placeholder substitution
                        var workerConfig: [String: Any] = task.workerConfig.mapValues { $0.value }
                        if let previousData = previousStepData {
                            workerConfig = substitutePlaceholders(config: workerConfig, data: previousData)
                        }
                        group.addTask {
                            await self.executeWorkerSync(
                                taskId: taskId,
                                workerClassName: workerClassName,
                                workerConfig: workerConfig,
                                qos: "background"
                            )
                        }
                    }
                    var allSucceeded = true
                    for await taskResult in group {
                        if !taskResult.success {
                            allSucceeded = false
                        } else if let data = taskResult.data {
                            stepResultData = data
                        }
                    }
                    stepSucceeded = allSucceeded
                }
            }

            // If step failed, stop and mark as failed
            if !stepSucceeded {
                NativeLogger.d("Chain '\(chainId)' failed at step \(stepIndex + 1)")
                try? await chainStateManager.markChainFailed(chainId: chainId)
                return
            }

            // Step completed - save result data and progress
            do {
                try await chainStateManager.saveStepResult(
                    chainId: chainId,
                    stepIndex: stepIndex,
                    resultData: stepResultData
                )
                try await chainStateManager.advanceToNextStep(chainId: chainId)
            } catch {
                NativeLogger.d("Failed to save chain progress: \(error)")
            }
        }

        // All steps completed
        try? await chainStateManager.markChainCompleted(chainId: chainId)
    }

    // MARK: - Chain Execution

    /// Execute a task chain sequentially.
    func executeChain(
        chainCancelId: String,
        steps: [[Any]],
        chainName: String?,
        constraintsMap: [String: Any]?,
        qos: String,
        onEnqueued: (() -> Void)? = nil
    ) async {
        // ✅ ISSUE 2 FIX: Wrap in UIBackgroundTaskIdentifier to extend background time (30s -> 3min)
        let bgTask = UIApplication.shared.beginBackgroundTask(withName: "NativeWorkManagerChain_\(chainCancelId)") { [weak self] in
            NativeLogger.w("Chain background task for '\(chainCancelId)' expired! Stopping all workers.")
            self?.stopAllWorkers()
        }
        
        defer {
            UIApplication.shared.endBackgroundTask(bgTask)
        }

        let chainId = "\(chainName ?? "chain")_\(UUID().uuidString)"

        // Create initial chain state
        do {
            let initialState = try ChainStateManager.createInitialState(
                chainId: chainId,
                chainName: chainName,
                stepsData: steps
            )
            try await chainStateManager.saveChainState(initialState)
            // ✅ ISSUE 4 FIX: Only notify Dart AFTER state is persisted to SQLite
            onEnqueued?()
        } catch {
            NativeLogger.d("Failed to create chain state: \(error)")
            // If persistence fails, notify anyway so the chain can at least try to run in-memory
            onEnqueued?()
        }

        // Execute chain steps
        for (stepIndex, stepData) in steps.enumerated() {
            // FIX C1: Honour cancellation between steps.
            guard !Task.isCancelled else {
                NativeLogger.d("Chain '\(chainCancelId)' cancelled at step \(stepIndex + 1)")
                try? await chainStateManager.markChainFailed(chainId: chainId)
                stateQueue.async(flags: .barrier) {
                    self.activeTasks.removeValue(forKey: chainCancelId)
                    self.taskStates[chainCancelId] = "cancelled"
                }
                emitTaskEvent(taskId: chainCancelId, success: false, message: "Chain cancelled")
                return
            }

            // Parse tasks
            guard let stepTasks = stepData as? [[String: Any]] else {
                try? await chainStateManager.markChainFailed(chainId: chainId)
                stateQueue.async(flags: .barrier) {
                    self.activeTasks.removeValue(forKey: chainCancelId)
                    self.taskStates[chainCancelId] = "failed"
                }
                emitTaskEvent(taskId: chainCancelId, success: false, message: "Invalid format")
                return
            }

            // Get previous results
            let previousStepData = try? await chainStateManager.getPreviousStepResult(
                chainId: chainId,
                currentStepIndex: stepIndex
            )

            var stepSucceeded = false
            var stepResultData: [String: Any]? = nil

            // iOS 15 (Swift 5.5) compat: DartCallbackWorker tasks must run
            // sequentially because two concurrent withCheckedContinuation +
            // DispatchQueue.main.async invocations inside withTaskGroup can
            // prevent continuations from being resumed on the iOS 15 runtime.
            // Native workers don't use the main-thread bridge and are safe to
            // run in parallel via withTaskGroup.
            let hasDartCallbackWorker = stepTasks.contains {
                ($0["workerClassName"] as? String) == "DartCallbackWorker"
            }

            if hasDartCallbackWorker {
                // Serial path: run each task one after another, emitting per-task events.
                var allSucceeded = true
                for taskData in stepTasks {
                    guard let taskId = taskData["id"] as? String,
                          let workerClassName = taskData["workerClassName"] as? String,
                          let originalConfig = taskData["workerConfig"] as? [String: Any] else {
                        continue
                    }
                    let workerConfig = substitutePlaceholders(config: originalConfig, data: previousStepData ?? [:])
                    let taskResult = await executeWorkerSync(
                        taskId: taskId,
                        workerClassName: workerClassName,
                        workerConfig: workerConfig,
                        qos: qos
                    )
                    if !taskResult.success {
                        allSucceeded = false
                    } else if let data = taskResult.data {
                        stepResultData = data
                    }
                }
                stepSucceeded = allSucceeded
            } else {
                // Parallel path: native workers can run concurrently.
                await withTaskGroup(of: WorkerResult.self) { group in
                    for taskData in stepTasks {
                        guard let taskId = taskData["id"] as? String,
                              let workerClassName = taskData["workerClassName"] as? String,
                              let originalConfig = taskData["workerConfig"] as? [String: Any] else {
                            continue
                        }
                        let workerConfig = substitutePlaceholders(config: originalConfig, data: previousStepData ?? [:])
                        group.addTask {
                            await self.executeWorkerSync(
                                taskId: taskId,
                                workerClassName: workerClassName,
                                workerConfig: workerConfig,
                                qos: qos
                            )
                        }
                    }
                    var allSucceeded = true
                    for await taskResult in group {
                        if !taskResult.success {
                            allSucceeded = false
                        } else if let data = taskResult.data {
                            stepResultData = data
                        }
                    }
                    stepSucceeded = allSucceeded
                }
            }

            if !stepSucceeded {
                try? await chainStateManager.markChainFailed(chainId: chainId)
                stateQueue.async(flags: .barrier) {
                    self.activeTasks.removeValue(forKey: chainCancelId)
                    self.taskStates[chainCancelId] = "failed"
                }
                emitTaskEvent(taskId: chainCancelId, success: false, message: "Chain failed at step \(stepIndex + 1)")
                return
            }

            // Save progress
            try? await chainStateManager.saveStepResult(chainId: chainId, stepIndex: stepIndex, resultData: stepResultData)
            try? await chainStateManager.advanceToNextStep(chainId: chainId)
        }

        // Complete
        try? await chainStateManager.markChainCompleted(chainId: chainId)
        stateQueue.async(flags: .barrier) {
            self.activeTasks.removeValue(forKey: chainCancelId)
            self.taskStates[chainCancelId] = "completed"
        }
        emitTaskEvent(taskId: chainCancelId, success: true, message: "Chain completed")
    }

    // MARK: - Security Helpers

    /// ✅ ISSUE 1 FIX: Replace placeholders like {{taskId.key}} with values from previous steps.
    private func substitutePlaceholders(config: [String: Any], data: [String: Any]) -> [String: Any] {
        var result = config
        
        for (key, value) in config {
            if let strValue = value as? String {
                result[key] = performSubstitution(in: strValue, with: data)
            } else if let dictValue = value as? [String: Any] {
                result[key] = substitutePlaceholders(config: dictValue, data: data)
            } else if let arrayValue = value as? [[String: Any]] {
                result[key] = arrayValue.map { substitutePlaceholders(config: $0, data: data) }
            }
        }
        
        return result
    }

    private func performSubstitution(in text: String, with data: [String: Any]) -> String {
        var substituted = text
        let pattern = "\\{\\{([^\\}]+)\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        for match in matches.reversed() {
            guard let keyRange = Range(match.range(at: 1), in: text) else { continue }
            let placeholderKey = String(text[keyRange]).trimmingCharacters(in: .whitespaces)
            
            if let replacementValue = data[placeholderKey] {
                let stringReplacement = "\(replacementValue)"
                if let fullRange = Range(match.range, in: substituted) {
                    substituted.replaceSubrange(fullRange, with: stringReplacement)
                }
            }
        }
        
        return substituted
    }

    // MARK: - Worker Execution

    struct RetryConfig {
        let maxRetries: Int
        let initialDelayMs: Int64
        let policy: String

        static let noRetry = RetryConfig(maxRetries: 0, initialDelayMs: 30_000, policy: "exponential")

        static func from(constraintsMap: [String: Any]?) -> RetryConfig {
            let maxRetries  = constraintsMap?["maxRetries"]    as? Int    ?? 0
            let delayMs     = (constraintsMap?["backoffDelayMs"] as? NSNumber)?.int64Value ?? 30_000
            let policy      = constraintsMap?["backoffPolicy"] as? String ?? "exponential"
            return RetryConfig(maxRetries: maxRetries, initialDelayMs: delayMs, policy: policy)
        }
    }

    func executeWorkerSync(
        taskId: String,
        workerClassName: String,
        workerConfig: [String: Any],
        qos: String = "background",
        retryConfig: RetryConfig = .noRetry
    ) async -> WorkerResult {
        let workerStartTime = Date()
        emitTaskStarted(taskId: taskId, workerType: workerClassName)

        let totalAttempts = 1 + max(0, retryConfig.maxRetries)
        var delayMs = retryConfig.initialDelayMs
        var lastResult: WorkerResult = .failure(message: "No attempt made")

        for attempt in 1...totalAttempts {
            guard !Task.isCancelled else {
                return .failure(message: "Cancelled before attempt \(attempt)/\(totalAttempts)")
            }
            await concurrencyLimiter.acquire()
            lastResult = await _executeWorker(
                taskId: taskId,
                workerClassName: workerClassName,
                workerConfig: workerConfig,
                qos: qos,
                shouldEmitEvent: false
            )
            await concurrencyLimiter.release()

            if lastResult.success { break }

            if attempt < totalAttempts {
                NativeLogger.d("[Retry] Task '\(taskId)': attempt \(attempt)/\(totalAttempts) failed — retrying in \(delayMs)ms")
                try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                guard !Task.isCancelled else {
                    return .failure(message: "Cancelled during retry backoff (attempt \(attempt)/\(totalAttempts))")
                }
                if retryConfig.policy == "exponential" {
                    delayMs = min(delayMs * 2, 3_600_000) // cap at 1 hour
                }
            }
        }

        let durationMs = Int64(Date().timeIntervalSince(workerStartTime) * 1000)

        if lastResult.success {
            NativeLogger.d("Task '\(taskId)' completed successfully")
            emitTaskEvent(taskId: taskId, success: true, message: lastResult.message, resultData: lastResult.data)
        } else {
            NativeLogger.d("Task '\(taskId)' failed after \(totalAttempts) attempt(s)")
            emitTaskEvent(taskId: taskId, success: false, message: lastResult.message ?? "Worker failed", resultData: lastResult.data)
        }

        // Fire LoggingMiddleware POST (fire-and-forget, never blocks worker result).
        NativeWorkmanagerPlugin.applyLoggingMiddleware(
            taskId: taskId,
            workerClassName: workerClassName,
            success: lastResult.success,
            message: lastResult.message,
            durationMs: durationMs
        )

        return lastResult
    }

    func _executeWorker(
        taskId: String,
        workerClassName: String,
        workerConfig: [String: Any],
        qos: String = "background",
        shouldEmitEvent: Bool = false
    ) async -> WorkerResult {
        NativeLogger.d("Executing task '\(taskId)' in chain with QoS: \(qos)...")

        // DartCallbackWorker is async-native — await directly, no withCheckedContinuation needed.
        // Using an unstructured Task {} inside withCheckedContinuation caused scheduling issues
        // on iOS 15 when two DartCallbackWorker tasks ran in parallel inside withTaskGroup.
        if workerClassName == "DartCallbackWorker" {
            return await executeDartWorkerViaMethodChannel(workerConfig: workerConfig, taskId: taskId)
        }

        let qosClass = mapQoS(qos)

        return await withCheckedContinuation { (continuation: CheckedContinuation<WorkerResult, Never>) in
            DispatchQueue.global(qos: qosClass).async {
                Task {
                    var enrichedConfig = workerConfig
                    enrichedConfig["__taskId"] = taskId
                    
                    let inputJson: String
                    if let nestedInput = workerConfig["input"] as? String {
                        inputJson = nestedInput
                    } else {
                        guard let jsonData = try? JSONSerialization.data(withJSONObject: enrichedConfig),
                              let configJson = String(data: jsonData, encoding: .utf8) else {
                            NativeLogger.d("Error serializing worker config")
                            continuation.resume(returning: .failure(message: "Config serialization failed"))
                            return
                        }
                        inputJson = configJson
                    }

                    guard let worker = IosWorkerFactory.createWorker(className: workerClassName) else {
                        NativeLogger.d("Unknown worker class: \(workerClassName)")
                        continuation.resume(returning: .failure(message: "Unknown worker class"))
                        return
                    }
                    
                    // ✅ ISSUE 2 FIX: Register active worker
                    self.stateQueue.sync(flags: .barrier) {
                        self.workers[taskId] = worker
                    }
                    
                    defer {
                        // ✅ ISSUE 2 FIX: Unregister worker on completion
                        self.stateQueue.sync(flags: .barrier) {
                            self.workers.removeValue(forKey: taskId)
                        }
                    }

                    do {
                        let result = try await worker.doWork(input: inputJson)
                        continuation.resume(returning: result)
                    } catch {
                        NativeLogger.d("Task '\(taskId)' error: \(error.localizedDescription)")
                        continuation.resume(returning: .failure(message: error.localizedDescription))
                    }
                }
            }
        }
    }

    func executeDartWorkerViaMethodChannel(
        workerConfig: [String: Any],
        taskId: String
    ) async -> WorkerResult {
        guard let callbackId = workerConfig["callbackId"] as? String else {
            return WorkerResult.failure(message: "DartCallbackWorker: missing callbackId in config")
        }
        let input = workerConfig["input"] as? String

        guard let channel = methodChannel else {
            let handleValue = workerConfig["callbackHandle"]
            guard let callbackHandle = (handleValue as? NSNumber)?.int64Value
                                    ?? (handleValue as? Int64) else {
                return WorkerResult.failure(message: "DartCallbackWorker: missing callbackHandle for background execution")
            }
            NativeLogger.d("DartCallbackWorker: No main channel — using FlutterEngineManager for '\(callbackId)'")
            do {
                let success = try await FlutterEngineManager.shared.executeDartCallback(
                    callbackHandle: callbackHandle, input: input)
                return success ? .success(message: "Callback returned true")
                               : .failure(message: "Callback returned false")
            } catch {
                return WorkerResult.failure(message: "DartCallbackWorker: \(error.localizedDescription)")
            }
        }

        NativeLogger.d("DartCallbackWorker: Executing '\(callbackId)' via main method channel")
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                channel.invokeMethod("executeDartCallback", arguments: [
                    "callbackId": callbackId,
                    "input": input as Any
                ]) { result in
                    if let success = result as? Bool {
                        continuation.resume(returning: success
                            ? .success(message: "Callback returned true")
                            : .failure(message: "Callback returned false"))
                    } else if let flutterError = result as? FlutterError {
                        continuation.resume(returning: .failure(
                            message: "Callback error: \(flutterError.message ?? "unknown")"))
                    } else {
                        continuation.resume(returning: .failure(
                            message: "No callback executor — call NativeWorkManager.initialize(dartWorkers:)"))
                    }
                }
            }
        }
    }

    private func mapQoS(_ qos: String) -> DispatchQoS.QoSClass {
        switch qos.lowercased() {
        case "userinteractive":
            return .userInteractive
        case "userinitiated":
            return .userInitiated
        case "utility":
            return .utility
        case "background":
            return .background
        default:
            return .background
        }
    }
}
