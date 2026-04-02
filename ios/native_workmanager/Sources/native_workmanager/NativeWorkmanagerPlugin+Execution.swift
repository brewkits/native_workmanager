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

                await resumeChain(chainState: chainState)
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
            let stepTasks = steps[stepIndex]
            NativeLogger.d("Chain '\(chainId)' - Step \(stepIndex + 1)/\(steps.count)")

            // Get previous step's result for data flow
            let previousStepData = try? await chainStateManager.getPreviousStepResult(
                chainId: chainId,
                currentStepIndex: stepIndex
            )

            // Execute tasks in parallel
            var stepSucceeded = false
            var stepResultData: [String: Any]? = nil

            await withTaskGroup(of: WorkerResult.self) { group in
                for task in stepTasks {
                    let taskId = task.taskId
                    let workerClassName = task.workerClassName
                    // Unwrap AnyCodable → Any for each key.  The previous
                    // cast-to-[String:Any] pipeline silently dropped all flat values
                    // (strings, ints, bools) because they failed the cast and became
                    // empty dicts that were then compactMapped away.
                    var workerConfig: [String: Any] = task.workerConfig.mapValues { $0.value }

                    // 🔗 Merge previous step's output into current step's input
                    if let previousData = previousStepData {
                        NativeLogger.d("Merging \(previousData.count) keys from previous step into '\(taskId)'")
                        workerConfig.merge(previousData) { (current, _) in current }
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

                // Wait for all tasks
                var allSucceeded = true
                for await taskResult in group {
                    if !taskResult.success {
                        allSucceeded = false
                    } else {
                        // Capture result data from successful task
                        if let data = taskResult.data {
                            stepResultData = data
                        }
                    }
                }
                stepSucceeded = allSucceeded
            }

            // If step failed, stop and mark as failed
            if !stepSucceeded {
                NativeLogger.d("Chain '\(chainId)' failed at step \(stepIndex + 1)")
                try? await chainStateManager.markChainFailed(chainId: chainId)
                return
            }

            // Step completed - save result data and progress
            do {
                // Save result data first
                try await chainStateManager.saveStepResult(
                    chainId: chainId,
                    stepIndex: stepIndex,
                    resultData: stepResultData
                )

                // Then advance to next step
                try await chainStateManager.advanceToNextStep(chainId: chainId)
                NativeLogger.d("Chain '\(chainId)' progress saved (\(stepIndex + 1)/\(steps.count))")
            } catch {
                NativeLogger.d("Failed to save chain progress: \(error)")
            }
        }

        // All steps completed
        do {
            try await chainStateManager.markChainCompleted(chainId: chainId)
            NativeLogger.d("Chain '\(chainId)' resumed and completed successfully")
        } catch {
            NativeLogger.d("Failed to mark chain completed: \(error)")
        }
    }

    // MARK: - Chain Execution

    /// Execute a task chain sequentially.
    ///
    /// **Platform note:** iOS executes chains directly (in-process) while Android uses
    /// WorkManager. Completion and failures are reported via emitTaskEvent so the Dart
    /// side receives them through the existing EventChannel — same as individual tasks.
    ///
    /// **Cancellation:** store the Task handle in activeTasks[chainCancelId] before this
    /// runs (done by handleEnqueueChain). Calling cancel(chainCancelId) will set
    /// Task.isCancelled; this function checks it between every step.
    func executeChain(
        chainCancelId: String,
        steps: [[Any]],
        chainName: String?,
        constraintsMap: [String: Any]?,
        qos: String
    ) async {
        // Generate a unique internal chain ID for state persistence.
        let chainId = "\(chainName ?? "chain")_\(UUID().uuidString)"

        // Create initial chain state
        do {
            let initialState = try ChainStateManager.createInitialState(
                chainId: chainId,
                chainName: chainName,
                stepsData: steps
            )
            try await chainStateManager.saveChainState(initialState)
            NativeLogger.d("Created chain state '\(chainId)'")
        } catch {
            NativeLogger.d("Failed to create chain state: \(error)")
            // Continue anyway - state is optional enhancement
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

            NativeLogger.d("Chain '\(chainName ?? "unnamed")' - Step \(stepIndex + 1)/\(steps.count)")

            // Parse tasks in this step
            guard let stepTasks = stepData as? [[String: Any]] else {
                try? await chainStateManager.markChainFailed(chainId: chainId)
                stateQueue.async(flags: .barrier) {
                    self.activeTasks.removeValue(forKey: chainCancelId)
                    self.taskStates[chainCancelId] = "failed"
                }
                emitTaskEvent(taskId: chainCancelId, success: false,
                              message: "Step \(stepIndex) has invalid format")
                return
            }

            // Get previous step's result for data flow
            let previousStepData = try? await chainStateManager.getPreviousStepResult(
                chainId: chainId,
                currentStepIndex: stepIndex
            )

            // Execute tasks in parallel (if multiple tasks in step)
            var stepSucceeded = false
            var stepResultData: [String: Any]? = nil

            await withTaskGroup(of: WorkerResult.self) { group in
                for taskData in stepTasks {
                    guard let taskId = taskData["id"] as? String,
                          let workerClassName = taskData["workerClassName"] as? String,
                          var workerConfig = taskData["workerConfig"] as? [String: Any] else {
                        continue
                    }

                    // Merge previous step's output into current step's input
                    if let previousData = previousStepData {
                        NativeLogger.d("Merging \(previousData.count) keys from previous step into '\(taskId)'")
                        workerConfig.merge(previousData) { (current, _) in current }
                    }

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
                        // Last successful task's data wins (same as Android WorkManager)
                        stepResultData = data
                    }
                }
                stepSucceeded = allSucceeded
            }

            // If step failed, stop the chain and report via EventChannel
            if !stepSucceeded {
                try? await chainStateManager.markChainFailed(chainId: chainId)
                stateQueue.async(flags: .barrier) {
                    self.activeTasks.removeValue(forKey: chainCancelId)
                    self.taskStates[chainCancelId] = "failed"
                }
                emitTaskEvent(taskId: chainCancelId, success: false,
                              message: "Chain step \(stepIndex + 1) failed")
                return
            }

            // Step completed - save result data and advance progress.
            // A transient I/O hiccup (e.g. filesystem busy) can cause a one-off
            // failure, so we retry once after a short pause before giving up.
            // Silently continuing on failure would desync the chain state and
            // cause future steps to start from the wrong index.
            do {
                try await chainStateManager.saveStepResult(
                    chainId: chainId,
                    stepIndex: stepIndex,
                    resultData: stepResultData
                )
                try await chainStateManager.advanceToNextStep(chainId: chainId)
                NativeLogger.d("Chain '\(chainId)' progress saved (\(stepIndex + 1)/\(steps.count))")
            } catch {
                NativeLogger.w("Chain '\(chainId)' state save failed, retrying in 200ms: \(error)")
                do {
                    try await Task.sleep(nanoseconds: 200_000_000) // 200 ms
                    try await chainStateManager.saveStepResult(
                        chainId: chainId,
                        stepIndex: stepIndex,
                        resultData: stepResultData
                    )
                    try await chainStateManager.advanceToNextStep(chainId: chainId)
                    NativeLogger.d("Chain '\(chainId)' progress saved after retry (\(stepIndex + 1)/\(steps.count))")
                } catch {
                    NativeLogger.e("Chain '\(chainId)' state persistence failed after retry: \(error)")
                    try? await chainStateManager.markChainFailed(chainId: chainId)
                    stateQueue.async(flags: .barrier) {
                        self.activeTasks.removeValue(forKey: chainCancelId)
                        self.taskStates[chainCancelId] = "failed"
                    }
                    emitTaskEvent(
                        taskId: chainCancelId,
                        success: false,
                        message: "Chain aborted: state persistence failed (disk full?). Step \(stepIndex + 1)/\(steps.count)"
                    )
                    return
                }
            }
        }

        // All steps completed
        do {
            try await chainStateManager.markChainCompleted(chainId: chainId)
            NativeLogger.d("Chain '\(chainName ?? "unnamed")' completed")
        } catch {
            NativeLogger.d("Failed to mark chain completed: \(error)")
        }

        stateQueue.async(flags: .barrier) {
            self.activeTasks.removeValue(forKey: chainCancelId)
            self.taskStates[chainCancelId] = "completed"
        }
        emitTaskEvent(taskId: chainCancelId, success: true, message: "Chain completed")
    }

    // MARK: - Worker Execution

    /// Retry policy parsed from the Dart `Constraints` map.
    ///
    /// `maxRetries = 0` preserves the original single-attempt behaviour so that
    /// chain tasks and DartWorkers (which manage retries at a higher level) are
    /// unaffected when `RetryConfig.noRetry` is used.
    struct RetryConfig {
        let maxRetries: Int       // 0 = no retry
        let initialDelayMs: Int64
        let policy: String        // "exponential" | "linear"

        static let noRetry = RetryConfig(maxRetries: 0, initialDelayMs: 30_000, policy: "exponential")

        /// Build from a Dart `Constraints.toMap()` result.
        static func from(constraintsMap: [String: Any]?) -> RetryConfig {
            // Default to 0 (no retry) to match Android WorkManager's default behaviour.
            // Callers that want retries must pass maxRetries explicitly via Constraints.
            let maxRetries  = constraintsMap?["maxRetries"]    as? Int    ?? 0
            let delayMs     = (constraintsMap?["backoffDelayMs"] as? NSNumber)?.int64Value ?? 30_000
            let policy      = constraintsMap?["backoffPolicy"] as? String ?? "exponential"
            return RetryConfig(maxRetries: maxRetries, initialDelayMs: delayMs, policy: policy)
        }
    }

    /// Execute a worker synchronously, respecting the concurrency limit and retry policy.
    ///
    /// Acquires a slot from [concurrencyLimiter] per attempt and releases it
    /// immediately after each attempt so other tasks can run during the backoff
    /// sleep. At most `maxConcurrentTasks` workers hold a slot simultaneously.
    ///
    /// - Parameters:
    ///   - retryConfig: Retry policy parsed from the Dart `Constraints` map.
    ///     `.noRetry` (default) preserves the pre-existing single-attempt behaviour.
    func executeWorkerSync(
        taskId: String,
        workerClassName: String,
        workerConfig: [String: Any],
        qos: String = "background",
        retryConfig: RetryConfig = .noRetry
    ) async -> WorkerResult {
        // Emit "started" lifecycle event before the first attempt so that
        // ObservabilityConfig.onTaskStart fires for all tasks — including
        // fast workers that never emit a progress update.
        emitTaskStarted(taskId: taskId, workerType: workerClassName)

        let totalAttempts = 1 + max(0, retryConfig.maxRetries)
        var delayMs = retryConfig.initialDelayMs
        var lastResult: WorkerResult = .failure(message: "No attempt made")

        for attempt in 1...totalAttempts {
            guard !Task.isCancelled else {
                return .failure(message: "Cancelled before attempt \(attempt)/\(totalAttempts)")
            }
            await concurrencyLimiter.acquire()
            // Emit the real event only on the final attempt so the Dart side
            // never sees intermediate failure events during retry backoff.
            lastResult = await _executeWorker(
                taskId: taskId,
                workerClassName: workerClassName,
                workerConfig: workerConfig,
                qos: qos,
                shouldEmitEvent: false // always suppress; executeWorkerSync emits after the loop
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

        // Emit the final event here (not inside _executeWorker) so retries
        // don't flood the Dart event stream with intermediate failures.
        if lastResult.success {
            NativeLogger.d("Task '\(taskId)' completed successfully")
            emitTaskEvent(taskId: taskId, success: true, message: lastResult.message, resultData: lastResult.data)
        } else {
            NativeLogger.d("Task '\(taskId)' failed after \(totalAttempts) attempt(s)")
            emitTaskEvent(taskId: taskId, success: false, message: lastResult.message ?? "Worker failed", resultData: lastResult.data)
        }

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

        // Map QoS string to DispatchQoS
        let qosClass = mapQoS(qos)

        return await withCheckedContinuation { (continuation: CheckedContinuation<WorkerResult, Never>) in
            // Special case: DartCallbackWorker — invoke executeDartCallback on the main
            // method channel instead of using FlutterEngineManager (which requires AOT/release
            // mode via FlutterCallbackCache). This path works in debug mode (integration tests)
            // and whenever the app is in the foreground.
            if workerClassName == "DartCallbackWorker" {
                Task {
                    let result = await self.executeDartWorkerViaMethodChannel(
                        workerConfig: workerConfig,
                        taskId: taskId
                    )
                    // Event emission is handled by executeWorkerSync — do NOT emit here.
                    continuation.resume(returning: result)
                }
                return
            }

            DispatchQueue.global(qos: qosClass).async {
                Task {
                    // Custom workers (NativeWorker.custom) store user data under the
                    // "input" key as a pre-encoded JSON string. Pass that directly to
                    // doWork() so the worker reads its own fields without knowing the
                    // outer workerConfig structure — consistent with Android behavior.
                    // Built-in workers have no "input" key, so they receive the full config.
                    let inputJson: String
                    if let nestedInput = workerConfig["input"] as? String {
                        inputJson = nestedInput
                    } else {
                        // Inject __taskId so workers can report progress via ProgressReporter
                        // (matches Android plugin behaviour at NativeWorkmanagerPlugin.kt:531,848).
                        var enrichedConfig = workerConfig
                        enrichedConfig["__taskId"] = taskId
                        guard let jsonData = try? JSONSerialization.data(withJSONObject: enrichedConfig),
                              let configJson = String(data: jsonData, encoding: .utf8) else {
                            NativeLogger.d("Error serializing worker config")
                            continuation.resume(returning: .failure(message: "Config serialization failed"))
                            return
                        }
                        inputJson = configJson
                    }

                    // Create worker
                    guard let worker = IosWorkerFactory.createWorker(className: workerClassName) else {
                        NativeLogger.d("Unknown worker class: \(workerClassName)")
                        continuation.resume(returning: .failure(message: "Unknown worker class"))
                        return
                    }

                    // Execute worker (v2.3.0+: returns WorkerResult)
                    // Event emission is handled by executeWorkerSync to avoid flooding
                    // the Dart event channel during intermediate retry attempts.
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

    /// Execute a DartCallbackWorker by invoking `executeDartCallback` on the main Flutter
    /// method channel (Native → Dart call).
    ///
    /// **Why this approach?**
    /// `FlutterEngineManager` launches a secondary engine and uses `FlutterCallbackCache` to
    /// look up the callback entry point. `FlutterCallbackCache` only works in AOT (release)
    /// mode — it returns `nil` in debug/JIT mode, causing ALL DartWorker calls to fail during
    /// integration tests. By invoking `executeDartCallback` on the existing main method channel,
    /// we reuse the already-initialized Dart isolate, which works in any build mode.
    ///
    /// **Fallback:** When `methodChannel` is nil (killed-app background execution), we fall
    /// back to `FlutterEngineManager` which works in release builds where AOT is active.
    func executeDartWorkerViaMethodChannel(
        workerConfig: [String: Any],
        taskId: String
    ) async -> WorkerResult {
        guard let callbackId = workerConfig["callbackId"] as? String else {
            return WorkerResult.failure(message: "DartCallbackWorker: missing callbackId in config")
        }
        let input = workerConfig["input"] as? String

        guard let channel = methodChannel else {
            // No main channel (app was killed) — fall back to FlutterEngineManager.
            // This path requires AOT (release build); FlutterCallbackCache returns nil in debug.
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
                        // nil result = no callback executor registered
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
