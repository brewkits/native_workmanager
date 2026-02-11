import Flutter
import UIKit
import UserNotifications
// KMPWorkManager will be available after pod install
// import KMPWorkManager

/// Native WorkManager Flutter Plugin for iOS.
///
/// This plugin provides native background task scheduling using iOS workers
/// (Mode 1: Native HTTP workers) and Dart workers (Mode 2: FlutterEngine-based).
///
/// **Architecture:**
/// - Mode 1: Native workers (HttpRequest, Upload, Download, Sync) - Zero Flutter overhead
/// - Mode 2: Dart workers (DartCallbackWorker) - Full Flutter plugin access
///
/// **Workers are executed via iOS URLSession and FlutterEngine respectively.**
public class NativeWorkmanagerPlugin: NSObject, FlutterPlugin {

    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var progressChannel: FlutterEventChannel?

    private var eventSink: FlutterEventSink?
    fileprivate var progressSink: FlutterEventSink?

    private static let methodChannelName = "dev.brewkits/native_workmanager"
    private static let eventChannelName = "dev.brewkits/native_workmanager/events"
    private static let progressChannelName = "dev.brewkits/native_workmanager/progress"

    // Background task execution queue
    private let workerQueue = DispatchQueue(label: "dev.brewkits.native_workmanager.worker",
                                           qos: .utility)

    // Tag storage: taskId -> tag mapping
    private var taskTags: [String: String] = [:]

    // Task status tracking: taskId -> status ("running", "completed", "failed", "cancelled")
    private var taskStates: [String: String] = [:]

    // Thread-safe access to task states
    private let stateQueue = DispatchQueue(label: "dev.brewkits.native_workmanager.state", attributes: .concurrent)

    // Debug mode flag
    private var debugMode = false

    // Task start times for debug mode
    private var taskStartTimes: [String: Date] = [:]

    // Chain state manager for persistence
    private let chainStateManager = ChainStateManager()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = NativeWorkmanagerPlugin()

        // Setup Method Channel
        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        instance.methodChannel = methodChannel

        // Setup Event Channel for task completion events
        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
        instance.eventChannel = eventChannel

        // Setup Progress Channel for task progress updates
        let progressChannel = FlutterEventChannel(
            name: progressChannelName,
            binaryMessenger: registrar.messenger()
        )
        progressChannel.setStreamHandler(ProgressStreamHandler(plugin: instance))
        instance.progressChannel = progressChannel

        // Register BGTaskScheduler handlers (iOS 13+)
        if #available(iOS 13.0, *) {
            // Validate Info.plist configuration
            InfoPlistValidator.printSetupGuideIfNeeded()

            BGTaskSchedulerManager.shared.registerHandlers()
            BGTaskSchedulerManager.shared.onTaskComplete = { taskId, success, message in
                instance.emitTaskEvent(taskId: taskId, success: success, message: message)
            }

            // Setup progress delegate for BackgroundSessionManager
            BackgroundSessionManager.shared.progressDelegate = { [weak instance] taskId, progress in
                instance?.emitProgress(taskId: taskId, progress: Int(progress), message: nil)
            }
        }

        print("NativeWorkmanagerPlugin: Registered")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            handleInitialize(call: call, result: result)
        case "enqueue":
            handleEnqueue(call: call, result: result)
        case "cancel":
            handleCancel(call: call, result: result)
        case "cancelAll":
            handleCancelAll(result: result)
        case "cancelByTag":
            handleCancelByTag(call: call, result: result)
        case "getTasksByTag":
            handleGetTasksByTag(call: call, result: result)
        case "getAllTags":
            handleGetAllTags(result: result)
        case "getTaskStatus":
            handleGetTaskStatus(call: call, result: result)
        case "enqueueChain":
            handleEnqueueChain(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Method Handlers

    private func handleInitialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Initialize KMP WorkManager
        KMPBridge.shared.initialize()

        // Extract arguments
        if let args = call.arguments as? [String: Any] {
            // Extract callback handle if provided (for Dart workers)
            if let callbackHandle = args["callbackHandle"] as? Int64 {
                FlutterEngineManager.shared.setCallbackHandle(callbackHandle)
                print("NativeWorkManager: Initialized with Dart callback handle: \(callbackHandle)")
            }

            // Extract debug mode
            debugMode = args["debugMode"] as? Bool ?? false
            if debugMode && isDebugBuild() {
                print("✅ Debug mode enabled - notifications will show for all task events")
                requestNotificationPermissions()
            }
        } else {
            print("NativeWorkManager: Initialized (KMP native workers)")
        }

        // ✅ NEW: Resume incomplete chains and cleanup old states
        Task {
            await resumePendingChains()
        }

        result(nil)
    }

    /// Resume incomplete chains that were interrupted by app kill
    private func resumePendingChains() async {
        print("NativeWorkManager: Checking for pending chains to resume...")

        do {
            // Cleanup old/completed chains first
            try await chainStateManager.cleanupOldStates()

            // Load resumable chains
            let resumableChains = try await chainStateManager.loadResumableChains()

            if resumableChains.isEmpty {
                print("NativeWorkManager: No pending chains to resume")
                return
            }

            print("NativeWorkManager: Found \(resumableChains.count) chain(s) to resume")

            // Resume each chain
            for chainState in resumableChains {
                print("NativeWorkManager: Resuming chain '\(chainState.chainId)'")
                print("  Progress: Step \(chainState.currentStep + 1)/\(chainState.totalSteps)")

                await resumeChain(chainState: chainState)
            }
        } catch {
            print("NativeWorkManager: Error resuming chains: \(error)")
        }
    }

    /// Resume a specific chain from saved state
    private func resumeChain(chainState: ChainStateManager.ChainState) async {
        let chainId = chainState.chainId
        let startStep = chainState.currentStep
        let steps = chainState.steps

        print("NativeWorkManager: Resuming chain '\(chainId)' from step \(startStep + 1)")

        // Execute remaining steps
        for stepIndex in startStep..<steps.count {
            let stepTasks = steps[stepIndex]
            print("NativeWorkManager: Chain '\(chainId)' - Step \(stepIndex + 1)/\(steps.count)")

            // Execute tasks in parallel
            var stepSucceeded = false
            await withTaskGroup(of: Bool.self) { group in
                for task in stepTasks {
                    let taskId = task.taskId
                    let workerClassName = task.workerClassName
                    let workerConfig = task.workerConfig.mapValues { $0.value as? [String: Any] ?? [:] }
                                                        .compactMapValues { $0.isEmpty ? nil : $0 }
                                                        .reduce(into: [String: Any]()) { $0[$1.key] = $1.value }

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
                for await success in group {
                    if !success {
                        allSucceeded = false
                    }
                }
                stepSucceeded = allSucceeded
            }

            // If step failed, stop and mark as failed
            if !stepSucceeded {
                print("NativeWorkManager: Chain '\(chainId)' failed at step \(stepIndex + 1)")
                try? await chainStateManager.markChainFailed(chainId: chainId)
                return
            }

            // Step completed - save progress
            do {
                try await chainStateManager.advanceToNextStep(chainId: chainId)
                print("NativeWorkManager: Chain '\(chainId)' progress saved (\(stepIndex + 1)/\(steps.count))")
            } catch {
                print("NativeWorkManager: Failed to save chain progress: \(error)")
            }
        }

        // All steps completed
        do {
            try await chainStateManager.markChainCompleted(chainId: chainId)
            print("NativeWorkManager: Chain '\(chainId)' resumed and completed successfully")
        } catch {
            print("NativeWorkManager: Failed to mark chain completed: \(error)")
        }
    }

    private func handleEnqueue(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String,
              let triggerMap = args["trigger"] as? [String: Any],
              let workerClassName = args["workerClassName"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
            return
        }

        print("NativeWorkManager: Enqueue task '\(taskId)' with worker '\(workerClassName)' via KMP scheduler")

        // Get KMP scheduler
        guard let scheduler = KMPBridge.shared.getScheduler() else {
            result(FlutterError(
                code: "NOT_INITIALIZED",
                message: "KMP WorkManager not initialized",
                details: nil
            ))
            return
        }

        // Extract parameters
        let constraintsMap = args["constraints"] as? [String: Any]
        let workerConfig = args["workerConfig"] as? [String: Any]
        let policyString = args["existingPolicy"] as? String
        let tag = args["tag"] as? String

        // Store tag if provided
        if let tag = tag {
            taskTags[taskId] = tag
            print("NativeWorkManager: Stored tag '\(tag)' for task '\(taskId)'")
        }

        // Set initial task state to running
        stateQueue.async(flags: .barrier) {
            self.taskStates[taskId] = "running"
        }

        // Convert workerConfig to JSON string for KMP
        var inputJson: String? = nil
        if let config = workerConfig,
           let jsonData = try? JSONSerialization.data(withJSONObject: config),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            inputJson = jsonString
        }

        // Call KMP scheduler
        KMPSchedulerBridge.enqueue(
            scheduler: scheduler,
            taskId: taskId,
            triggerMap: triggerMap,
            workerClassName: workerClassName,
            constraintsMap: constraintsMap,
            inputJson: inputJson,
            policyString: policyString
        ) { scheduleResult in
            switch scheduleResult {
            case .success(let schedResult):
                let resultString = KMPSchedulerBridge.scheduleResultToString(schedResult)
                print("✅ KMP Scheduler: Task '\(taskId)' enqueued with result: \(resultString)")
                result(resultString)
            case .failure(let error):
                print("❌ KMP Scheduler: Failed to enqueue task '\(taskId)' - \(error)")
                result(FlutterError(
                    code: "ENQUEUE_FAILED",
                    message: error.localizedDescription,
                    details: nil
                ))
            }
        }
    }

    // MARK: - Legacy Implementation (Removed in Phase 2)
    // The old direct Swift worker execution has been replaced with KMP scheduler calls
    // All background tasks are now scheduled through kmpworkmanager v2.3.0


    private func handleCancel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "taskId is required", details: nil))
            return
        }

        print("NativeWorkManager: Cancel task \(taskId) via KMP scheduler")

        // Get KMP scheduler
        guard let scheduler = KMPBridge.shared.getScheduler() else {
            // Fallback to legacy BGTaskScheduler if KMP not ready
            if #available(iOS 13.0, *) {
                BGTaskSchedulerManager.shared.cancelTask(taskId: taskId)
            }
            // Remove tag mapping
            taskTags.removeValue(forKey: taskId)
            result(nil)
            return
        }

        // Cancel via KMP scheduler
        scheduler.cancel(id: taskId)
        // Remove tag mapping
        taskTags.removeValue(forKey: taskId)
        // Update task state
        stateQueue.async(flags: .barrier) {
            self.taskStates[taskId] = "cancelled"
        }
        print("✅ KMP Scheduler: Task '\(taskId)' cancelled")
        result(nil)
    }

    private func handleCancelAll(result: @escaping FlutterResult) {
        print("NativeWorkManager: Cancel all tasks via KMP scheduler")

        // Get KMP scheduler
        guard let scheduler = KMPBridge.shared.getScheduler() else {
            // Fallback to legacy BGTaskScheduler if KMP not ready
            if #available(iOS 13.0, *) {
                BGTaskSchedulerManager.shared.cancelAllTasks()
            }
            // Clear all tag mappings
            taskTags.removeAll()
            result(nil)
            return
        }

        // Cancel all via KMP scheduler
        scheduler.cancelAll()
        // Clear all tag mappings
        taskTags.removeAll()
        // Clear all task states
        stateQueue.async(flags: .barrier) {
            self.taskStates.removeAll()
        }
        print("✅ KMP Scheduler: All tasks cancelled")
        result(nil)
    }

    private func handleCancelByTag(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let tag = args["tag"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "tag is required", details: nil))
            return
        }

        // Find all tasks with this tag
        let tasksToCancel = taskTags.filter { $0.value == tag }.map { $0.key }

        print("NativeWorkManager: Canceling \(tasksToCancel.count) tasks with tag '\(tag)'")

        // Get KMP scheduler
        guard let scheduler = KMPBridge.shared.getScheduler() else {
            // Fallback to legacy BGTaskScheduler if KMP not ready
            if #available(iOS 13.0, *) {
                for taskId in tasksToCancel {
                    BGTaskSchedulerManager.shared.cancelTask(taskId: taskId)
                    taskTags.removeValue(forKey: taskId)
                }
            }
            result(nil)
            return
        }

        // Cancel each task
        for taskId in tasksToCancel {
            scheduler.cancel(id: taskId)
            taskTags.removeValue(forKey: taskId)
            // Update task state
            stateQueue.async(flags: .barrier) {
                self.taskStates[taskId] = "cancelled"
            }
        }

        result(nil)
    }

    private func handleGetTasksByTag(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let tag = args["tag"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "tag is required", details: nil))
            return
        }

        // Find all tasks with this tag
        let tasks = taskTags.filter { $0.value == tag }.map { $0.key }
        result(tasks)
    }

    private func handleGetAllTags(result: @escaping FlutterResult) {
        // Get all unique tags
        let tags = Array(Set(taskTags.values))
        result(tags)
    }

    private func handleGetTaskStatus(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "taskId is required", details: nil))
            return
        }

        // Get task status from state map
        let status = stateQueue.sync {
            taskStates[taskId] ?? "unknown"
        }

        result(["status": status])
    }

    private func handleEnqueueChain(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let stepsData = args["steps"] as? [[Any]] else {
            result(FlutterError(code: "INVALID_ARGS", message: "steps is required", details: nil))
            return
        }

        let chainName = args["name"] as? String
        let constraintsMap = args["constraints"] as? [String: Any]
        let qos = constraintsMap?["qos"] as? String ?? "background"

        print("NativeWorkManager: Enqueue chain '\(chainName ?? "unnamed")' with \(stepsData.count) steps")

        // Platform Limitation: iOS uses direct execution for chains
        // Currently iOS executes chains directly while Android uses KMP scheduler.
        // This works correctly and provides the same end-user behavior (sequential/parallel execution),
        // but iOS bypasses KMP's scheduling logic (constraints, persistence, retry).
        //
        // Rationale: KMP framework doesn't expose chain API (beginWith/then/enqueue) to iOS bridge.
        // Adding this would require extending KMPSchedulerBridge with TaskChain support.
        //
        // Status: This is an acceptable platform-specific implementation difference.
        // See: https://github.com/brewkits/native_workmanager/issues/16

        // Execute chain steps sequentially (direct execution approach)
        workerQueue.async { [weak self] in
            self?.executeChain(
                steps: stepsData,
                chainName: chainName,
                constraintsMap: constraintsMap,
                qos: qos,
                result: result
            )
        }
    }

    /// Execute a task chain sequentially.
    ///
    /// **Platform Inconsistency Note:**
    /// iOS executes chains by directly invoking workers, while Android uses KMP scheduler's
    /// beginWith/then/enqueue API. This provides the same end result (sequential/parallel execution)
    /// but bypasses KMP's scheduling logic (constraints, persistence, retry).
    ///
    /// **Why:**
    /// KMP framework doesn't currently expose chain API to iOS bridge. This would require
    /// extending KMPSchedulerBridge with TaskChain support.
    ///
    /// **Impact:**
    /// - ✅ Chains work correctly on iOS
    /// - ✅ Sequential and parallel execution respected
    /// - ❌ Constraints may not be enforced as strictly
    /// - ❌ Chain persistence differs from Android
    ///
    /// **Future Work:**
    /// See GitHub issue #16 for plan to add KMP chain support to iOS.
    private func executeChain(
        steps: [[Any]],
        chainName: String?,
        constraintsMap: [String: Any]?,
        qos: String,
        result: @escaping FlutterResult
    ) {
        Task {
            // Generate unique chain ID
            let chainId = "\(chainName ?? "chain")_\(UUID().uuidString)"

            // Create initial chain state
            do {
                let initialState = try ChainStateManager.createInitialState(
                    chainId: chainId,
                    chainName: chainName,
                    stepsData: steps
                )
                try await chainStateManager.saveChainState(initialState)
                print("NativeWorkManager: Created chain state '\(chainId)'")
            } catch {
                print("NativeWorkManager: Failed to create chain state: \(error)")
                // Continue anyway - state is optional enhancement
            }

            // Execute chain steps
            for (stepIndex, stepData) in steps.enumerated() {
                print("NativeWorkManager: Chain '\(chainName ?? "unnamed")' - Step \(stepIndex + 1)/\(steps.count)")

                // Parse tasks in this step
                guard let stepTasks = stepData as? [[String: Any]] else {
                    // Mark chain as failed
                    try? await chainStateManager.markChainFailed(chainId: chainId)

                    result(FlutterError(
                        code: "INVALID_STEP",
                        message: "Step \(stepIndex) has invalid format",
                        details: nil
                    ))
                    return
                }

                // Execute tasks in parallel (if multiple tasks in step)
                var stepSucceeded = false
                await withTaskGroup(of: Bool.self) { group in
                    for taskData in stepTasks {
                        guard let taskId = taskData["id"] as? String,
                              let workerClassName = taskData["workerClassName"] as? String,
                              let workerConfig = taskData["workerConfig"] as? [String: Any] else {
                            continue
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

                    // Wait for all tasks in this step to complete
                    var allSucceeded = true
                    for await success in group {
                        if !success {
                            allSucceeded = false
                        }
                    }

                    stepSucceeded = allSucceeded
                }

                // If step failed, stop the chain
                if !stepSucceeded {
                    // Mark chain as failed and remove state
                    try? await chainStateManager.markChainFailed(chainId: chainId)

                    result(FlutterError(
                        code: "CHAIN_FAILED",
                        message: "Chain step \(stepIndex + 1) failed",
                        details: nil
                    ))
                    return
                }

                // ✅ Step completed - save progress
                do {
                    try await chainStateManager.advanceToNextStep(chainId: chainId)
                    print("NativeWorkManager: Chain '\(chainId)' progress saved (\(stepIndex + 1)/\(steps.count))")
                } catch {
                    print("NativeWorkManager: Failed to save chain progress: \(error)")
                    // Continue anyway - state is optional
                }
            }

            // All steps completed
            do {
                try await chainStateManager.markChainCompleted(chainId: chainId)
                print("NativeWorkManager: Chain '\(chainName ?? "unnamed")' completed and state saved")
            } catch {
                print("NativeWorkManager: Failed to mark chain completed: \(error)")
            }

            result("ACCEPTED")
        }
    }

    /// Execute a worker synchronously and return success status.
    private func executeWorkerSync(
        taskId: String,
        workerClassName: String,
        workerConfig: [String: Any],
        qos: String = "background"
    ) async -> Bool {
        print("NativeWorkManager: Executing task '\(taskId)' in chain with QoS: \(qos)...")

        // Map QoS string to DispatchQoS
        let qosClass = mapQoS(qos)

        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            DispatchQueue.global(qos: qosClass).async {
                Task {
                    // Convert worker config to JSON string
                    guard let jsonData = try? JSONSerialization.data(withJSONObject: workerConfig),
                          let inputJson = String(data: jsonData, encoding: .utf8) else {
                        print("NativeWorkManager: Error serializing worker config")
                        self.emitTaskEvent(taskId: taskId, success: false, message: "Config serialization failed")
                        continuation.resume(returning: false)
                        return
                    }

                    // Create worker
                    guard let worker = IosWorkerFactory.createWorker(className: workerClassName) else {
                        print("NativeWorkManager: Unknown worker class: \(workerClassName)")
                        self.emitTaskEvent(taskId: taskId, success: false, message: "Unknown worker class")
                        continuation.resume(returning: false)
                        return
                    }

                    // Execute worker (v2.3.0+: returns WorkerResult)
                    do {
                        let result = try await worker.doWork(input: inputJson)

                        if result.success {
                            print("NativeWorkManager: Task '\(taskId)' completed successfully")
                            self.emitTaskEvent(taskId: taskId, success: true, message: result.message, resultData: result.data)
                        } else {
                            print("NativeWorkManager: Task '\(taskId)' failed")
                            self.emitTaskEvent(taskId: taskId, success: false, message: result.message ?? "Worker returned failure", resultData: result.data)
                        }

                        continuation.resume(returning: result.success)
                    } catch {
                        print("NativeWorkManager: Task '\(taskId)' error: \(error.localizedDescription)")
                        self.emitTaskEvent(taskId: taskId, success: false, message: error.localizedDescription)
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    // MARK: - Event Emission

    func emitTaskEvent(taskId: String, success: Bool, message: String?, resultData: [String: Any]? = nil) {
        // Update task state
        stateQueue.async(flags: .barrier) {
            self.taskStates[taskId] = success ? "completed" : "failed"
        }

        // Show debug notification if enabled
        if debugMode && isDebugBuild() {
            showDebugNotification(taskId: taskId, success: success, message: message)
        }

        // Always emit event to Dart (v2.3.0+: includes resultData)
        var event: [String: Any] = [
            "taskId": taskId,
            "success": success,
            "message": message as Any,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]

        if let data = resultData {
            event["resultData"] = data
        }

        // Ensure event is emitted on the main thread
        DispatchQueue.main.async {
            self.eventSink?(event)
        }
    }

    func emitProgress(taskId: String, progress: Int, message: String?) {
        progressSink?([
            "taskId": taskId,
            "progress": progress,
            "message": message as Any
        ])
    }

    // MARK: - Helper Methods
    
    /// Map QoS string to DispatchQoS
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

    // MARK: - Debug Mode Helpers

    private func isDebugBuild() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private func requestNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("✅ Notification permissions granted for debug mode")
            } else if let error = error {
                print("⚠️ Notification permissions denied: \(error.localizedDescription)")
            }
        }
    }

    private func showDebugNotification(taskId: String, success: Bool, message: String?) {
        let startTime = taskStartTimes[taskId]
        let executionTime: String
        if let startTime = startTime {
            let elapsed = Date().timeIntervalSince(startTime)
            executionTime = String(format: "%.0fms", elapsed * 1000)
            taskStartTimes.removeValue(forKey: taskId)
        } else {
            executionTime = "N/A"
        }

        let title = success ? "✅ Task Completed: \(taskId)" : "❌ Task Failed: \(taskId)"
        var body = "Execution time: \(executionTime)"
        if let message = message {
            body += "\n\(message)"
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "debug_\(taskId)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing debug notification: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - FlutterStreamHandler

extension NativeWorkmanagerPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
                self.eventSink = events

        // Platform Limitation: Kotlin SharedFlow not directly compatible with Swift
        // Note: Kotlin SharedFlow doesn't conform to Swift's AsyncSequence protocol, preventing
        // direct iteration in Swift. This is a known Kotlin/Native interop limitation.
        //
        // Workaround: Events are emitted through native callbacks instead of SharedFlow subscription.
        // Native workers and KMP scheduler call emitTaskEvent() directly, which then forwards
        // events to the Flutter event sink. This provides equivalent functionality.
        //
        // Status: This is a documented Kotlin/Swift interop workaround that achieves the same result.
        Task { [weak self] in
            guard let self = self else { return }
            // Placeholder - actual events come through native callbacks
            print("EventSink registered - listening for task events")
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

// MARK: - Progress Stream Handler

private class ProgressStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: NativeWorkmanagerPlugin?

    init(plugin: NativeWorkmanagerPlugin) {
        self.plugin = plugin
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // Set progress sink on plugin
        plugin?.progressSink = events
        print("ProgressStreamHandler: Progress sink registered - listening for progress updates")
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.progressSink = nil
        print("ProgressStreamHandler: Progress sink cancelled")
        return nil
    }
}
