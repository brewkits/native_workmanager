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

    // Active task handles for cancellation support
    private var activeTasks: [String: Task<Void, Never>] = [:]

    // Chain state manager for persistence
    private let chainStateManager = ChainStateManager()

    // Persistent SQLite task store (available on iOS 13+)
    @available(iOS 13.0, *)
    private var taskStore: TaskStore? { TaskStore.shared }

    // Notification title per taskId for download notification feature
    private var taskNotifTitles: [String: String] = [:]

    // Concurrency limiter — prevents simultaneous network saturation.
    // Replaced in handleInitialize when maxConcurrentTasks is provided.
    private var concurrencyLimiter = ConcurrencyLimiter(max: 4)

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

        // Initialize KMPBridge at launch time (CRITICAL: BGTaskScheduler handlers must
        // be registered before app finishes launching, not lazily on Dart's initialize())
        KMPBridge.shared.initialize()

        // Register BGTaskScheduler handlers (iOS 13+)
        if #available(iOS 13.0, *) {
            // Validate Info.plist configuration
            InfoPlistValidator.printSetupGuideIfNeeded()

            BGTaskSchedulerManager.shared.registerHandlers()
            BGTaskSchedulerManager.shared.onTaskComplete = { [weak instance] taskId, success, message in
                instance?.emitTaskEvent(taskId: taskId, success: success, message: message)
            }

            // Setup progress delegate for BackgroundSessionManager
            BackgroundSessionManager.shared.progressDelegate = { [weak instance] taskId, progress in
                instance?.emitProgress(taskId: taskId, progress: Int(progress), message: nil)
            }

            // Handle downloads that completed while app was killed (background relaunch).
            // The OS relaunches the app and delivers the result via URLSession delegate;
            // since downloadHandlers is empty after a kill, we forward the result here.
            BackgroundSessionManager.shared.relaunchCompletionDelegate = { [weak instance] taskId, result in
                switch result {
                case .success:
                    instance?.emitTaskEvent(taskId: taskId, success: true,
                                            message: "Download completed (background relaunch)")
                case .failure(let error):
                    instance?.emitTaskEvent(taskId: taskId, success: false,
                                            message: error.localizedDescription)
                }
            }
        }

        NativeLogger.d("Plugin registered")
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
        case "pause":
            handlePause(call: call, result: result)
        case "resume":
            handleResume(call: call, result: result)
        case "allTasks":
            handleAllTasks(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Method Handlers

    private func handleInitialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Note: KMPBridge is already initialized at plugin registration time.
        // KMPBridge.shared.initialize() is called in register(with:) to ensure
        // BGTaskScheduler handlers are registered before app finishes launching.

        // Extract arguments
        if let args = call.arguments as? [String: Any] {
            // Extract callback handle if provided (for Dart workers)
            if let callbackHandle = args["callbackHandle"] as? Int64 {
                FlutterEngineManager.shared.setCallbackHandle(callbackHandle)
                NativeLogger.d("Initialized with Dart callback handle: \(callbackHandle)")
            }

            // Extract debug mode and wire up the centralised logger.
            debugMode = args["debugMode"] as? Bool ?? false
            NativeLogger.enabled = debugMode && isDebugBuild()
            if NativeLogger.enabled {
                NativeLogger.d("Debug mode enabled - notifications will show for all task events")
                requestNotificationPermissions()
            }

            // Apply maxConcurrentTasks limit (default 4).
            let maxConcurrent = args["maxConcurrentTasks"] as? Int ?? 4
            concurrencyLimiter = ConcurrencyLimiter(max: maxConcurrent)
            NativeLogger.d("maxConcurrentTasks=\(maxConcurrent)")
        } else {
            NativeLogger.d("Initialized (KMP native workers)")
        }

        // Initialize download notification permission (required for showNotification feature)
        if #available(iOS 13.0, *) {
            DownloadNotificationManager.requestPermission()
        }

        // ✅ NEW: Resume incomplete chains and cleanup old states
        Task {
            await resumePendingChains()
        }

        result(nil)
    }

    /// Resume incomplete chains that were interrupted by app kill
    private func resumePendingChains() async {
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
    private func resumeChain(chainState: ChainStateManager.ChainState) async {
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

    private func handleEnqueue(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String,
              let triggerMap = args["trigger"] as? [String: Any],
              let workerClassName = args["workerClassName"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
            return
        }

        NativeLogger.d("Enqueue task '\(taskId)' with worker '\(workerClassName)' (direct execution)")

        // Set initial task state and store tag atomically
        let capturedTag = args["tag"] as? String
        stateQueue.async(flags: .barrier) {
            self.taskStates[taskId] = "pending"
            if let tag = capturedTag {
                self.taskTags[taskId] = tag
                NativeLogger.d("Stored tag '\(tag)' for task '\(taskId)'")
            }
        }

        // Extract parameters
        let workerConfig = args["workerConfig"] as? [String: Any] ?? [:]
        let constraintsMap = args["constraints"] as? [String: Any]
        let qos = constraintsMap?["qos"] as? String ?? "background"

        // Parse trigger
        let triggerType = triggerMap["type"] as? String ?? "oneTime"
        let delayMs = (triggerMap["initialDelayMs"] as? NSNumber)?.int64Value ?? 0

        // Accept immediately – iOS executes tasks directly (BGTaskScheduler doesn't fire
        // during foreground execution or in the simulator without special simulation)
        result("ACCEPTED")

        // Persist task to SQLite store and capture notification title if requested
        if #available(iOS 13.0, *) {
            let workerConfigForStore = workerConfig
            let tagForStore = capturedTag
            let configJson: String? = {
                guard let data = try? JSONSerialization.data(withJSONObject: workerConfigForStore),
                      let s = String(data: data, encoding: .utf8) else { return nil }
                return s
            }()
            taskStore?.upsert(
                taskId: taskId,
                tag: tagForStore,
                status: "pending",
                workerClassName: workerClassName,
                workerConfig: configJson
            )
            if workerConfigForStore["showNotification"] as? Bool == true {
                let url = workerConfigForStore["url"] as? String ?? ""
                let fileNameFromUrl = url.components(separatedBy: "/").last
                let title: String = (workerConfigForStore["notificationTitle"] as? String)
                    ?? (fileNameFromUrl.flatMap { $0.isEmpty ? nil : $0 } ?? taskId)
                stateQueue.async(flags: .barrier) {
                    self.taskNotifTitles[taskId] = title
                }
            }
        }

        // Launch async task (stored so it can be cancelled)
        let taskHandle = Task { [weak self] in
            // Always remove from activeTasks when done — covers success, failure, and
            // system-cancel paths that would otherwise leave a stale entry (memory leak).
            defer {
                self?.stateQueue.async(flags: .barrier) {
                    self?.activeTasks.removeValue(forKey: taskId)
                }
            }
            guard let self = self else { return }

            // Apply initial delay if requested
            if delayMs > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            }
            guard !Task.isCancelled else { return }

            if triggerType == "periodic" {
                let intervalMs = (triggerMap["intervalMs"] as? NSNumber)?.int64Value ?? 900_000
                // KNOWN LIMITATION (C2): iOS periodic tasks run in-process.
                // They repeat correctly while the app is open (foreground or active background
                // session), but are NOT re-scheduled by the OS after the app is killed.
                // Android WorkManager re-schedules workers across kills — iOS does not.
                // For true background periodic work on iOS, integrate BGAppRefreshTask
                // in AppDelegate and call NativeWorkManager.enqueue() from its handler.
                NativeLogger.d("[iOS] Periodic task '\(taskId)' started — NOTE: only runs while app is active. For true background recurrence, use BGAppRefreshTask.")
                // Execute first time immediately
                _ = await self.executeWorkerSync(
                    taskId: taskId,
                    workerClassName: workerClassName,
                    workerConfig: workerConfig,
                    qos: qos
                )
                // Repeat until cancelled (simulates periodic behavior while app is active)
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: UInt64(intervalMs) * 1_000_000)
                    guard !Task.isCancelled else { break }
                    _ = await self.executeWorkerSync(
                        taskId: taskId,
                        workerClassName: workerClassName,
                        workerConfig: workerConfig,
                        qos: qos
                    )
                }
            } else {
                // One-time task
                _ = await self.executeWorkerSync(
                    taskId: taskId,
                    workerClassName: workerClassName,
                    workerConfig: workerConfig,
                    qos: qos
                )
            }
        }

        // Store handle for cancellation
        stateQueue.async(flags: .barrier) {
            self.activeTasks[taskId] = taskHandle
        }
    }


    private func handlePause(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "taskId is required", details: nil))
            return
        }

        NativeLogger.d("Pause task \(taskId)")

        // Try pausing via BackgroundSessionManager (download tasks using background session)
        if #available(iOS 13.0, *) {
            BackgroundSessionManager.shared.pause(taskId: taskId) { [weak self] didPause in
                guard let self = self else { return }
                // Whether or not resume data was saved, cancel the in-process Swift Task
                self.stateQueue.async(flags: .barrier) {
                    self.activeTasks[taskId]?.cancel()
                    self.activeTasks.removeValue(forKey: taskId)
                    self.taskStates[taskId] = "paused"
                    self.taskNotifTitles.removeValue(forKey: taskId)
                }
                self.taskStore?.updateStatus(taskId: taskId, status: "paused")
                if !didPause {
                    NativeLogger.d("Pause for '\(taskId)': no resume data — will restart on resume")
                }
            }
        } else {
            // iOS < 13: just cancel the task handle
            stateQueue.async(flags: .barrier) {
                self.activeTasks[taskId]?.cancel()
                self.activeTasks.removeValue(forKey: taskId)
                self.taskStates[taskId] = "paused"
            }
        }
        result(nil)
    }

    private func handleResume(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "taskId is required", details: nil))
            return
        }

        NativeLogger.d("Resume task \(taskId)")

        guard #available(iOS 13.0, *) else {
            result(FlutterError(code: "UNSUPPORTED", message: "resume() requires iOS 13+", details: nil))
            return
        }

        // Look up the paused task from the store
        guard let record = taskStore?.task(taskId: taskId) else {
            result(FlutterError(code: "NOT_FOUND", message: "Task '\(taskId)' not found in store", details: nil))
            return
        }

        guard record.status == "paused" else {
            result(FlutterError(code: "INVALID_STATE",
                                message: "Task '\(taskId)' is not paused (status: \(record.status))",
                                details: nil))
            return
        }

        // Check if BackgroundSessionManager has resume data
        let hasResumeData = BackgroundSessionManager.shared.hasResumeData(forTaskId: taskId)

        if hasResumeData {
            // Resume the background URLSession download from where it left off.
            // The completion block fires when the download *finishes* (success) or fails.
            _ = BackgroundSessionManager.shared.resumeDownload(with: nil, taskId: taskId) { [weak self] resumeResult in
                guard let self = self else { return }
                switch resumeResult {
                case .success:
                    // Download completed successfully
                    NativeLogger.d("Task '\(taskId)' resumed and completed via background session")
                    self.emitTaskEvent(taskId: taskId, success: true, message: "Download completed (resume)")
                case .failure(let error):
                    NativeLogger.e("Resume for '\(taskId)' failed: \(error.localizedDescription)")
                    self.emitTaskEvent(taskId: taskId, success: false,
                                       message: "Resume failed: \(error.localizedDescription)")
                }
            }
            // Update state to running immediately (download is in progress)
            stateQueue.async(flags: .barrier) {
                self.taskStates[taskId] = "running"
            }
            taskStore?.updateStatus(taskId: taskId, status: "running")
            result(nil)
        } else {
            // No resume data — re-execute the worker from scratch using the stored config
            guard let configJson = record.workerConfig,
                  let configData = configJson.data(using: .utf8),
                  let workerConfig = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] else {
                result(FlutterError(code: "CONFIG_ERROR", message: "Cannot parse stored config for '\(taskId)'", details: nil))
                return
            }

            taskStore?.updateStatus(taskId: taskId, status: "pending")
            stateQueue.async(flags: .barrier) {
                self.taskStates[taskId] = "pending"
            }

            let workerClassName = record.workerClassName
            let taskHandle = Task { [weak self] in
                defer {
                    self?.stateQueue.async(flags: .barrier) {
                        self?.activeTasks.removeValue(forKey: taskId)
                    }
                }
                guard let self = self else { return }
                _ = await self.executeWorkerSync(
                    taskId: taskId,
                    workerClassName: workerClassName,
                    workerConfig: workerConfig,
                    qos: "background"
                )
            }
            stateQueue.async(flags: .barrier) {
                self.activeTasks[taskId] = taskHandle
            }
            result(nil)
        }
    }

    private func handleAllTasks(result: @escaping FlutterResult) {
        guard #available(iOS 13.0, *) else {
            result([])
            return
        }
        let records = taskStore?.allTasks() ?? []
        let maps = records.map { $0.toFlutterMap() }
        result(maps)
    }

    private func handleCancel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "taskId is required", details: nil))
            return
        }

        NativeLogger.d("Cancel task \(taskId)")

        if #available(iOS 13.0, *) {
            taskStore?.updateStatus(taskId: taskId, status: "cancelled")
        }

        stateQueue.async(flags: .barrier) {
            self.activeTasks[taskId]?.cancel()
            self.activeTasks.removeValue(forKey: taskId)
            self.taskStates[taskId] = "cancelled"
            self.taskTags.removeValue(forKey: taskId)
            self.taskNotifTitles.removeValue(forKey: taskId)
        }
        result(nil)
    }

    private func handleCancelAll(result: @escaping FlutterResult) {
        NativeLogger.d("Cancel all tasks")

        stateQueue.async(flags: .barrier) {
            for (_, task) in self.activeTasks { task.cancel() }
            self.activeTasks.removeAll()
            self.taskStates.removeAll()
            self.taskTags.removeAll()
        }
        result(nil)
    }

    private func handleCancelByTag(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let tag = args["tag"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "tag is required", details: nil))
            return
        }

        // Read taskTags under a shared lock, then cancel under a barrier lock
        let tasksToCancel = stateQueue.sync {
            taskTags.filter { $0.value == tag }.map { $0.key }
        }
        NativeLogger.d("Canceling \(tasksToCancel.count) tasks with tag '\(tag)'")

        stateQueue.async(flags: .barrier) {
            for taskId in tasksToCancel {
                self.activeTasks[taskId]?.cancel()
                self.activeTasks.removeValue(forKey: taskId)
                self.taskStates[taskId] = "cancelled"
                self.taskTags.removeValue(forKey: taskId)
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

        // Find all tasks with this tag (shared read lock)
        let tasks = stateQueue.sync {
            taskTags.filter { $0.value == tag }.map { $0.key }
        }
        result(tasks)
    }

    private func handleGetAllTags(result: @escaping FlutterResult) {
        // Get all unique tags (shared read lock)
        let tags = stateQueue.sync {
            Array(Set(taskTags.values))
        }
        result(tags)
    }

    private func handleGetTaskStatus(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "taskId is required", details: nil))
            return
        }

        // Get task status from state map
        // Returns plain String to match Android's getTaskStatus return type
        let status = stateQueue.sync {
            taskStates[taskId]
        }

        result(status)
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

        // FIX C1: Use chainName (or a UUID) as the cancel key so callers can
        // cancel("myChain") and the Task handle is found in activeTasks.
        let chainCancelId = chainName ?? "chain_\(UUID().uuidString)"

        NativeLogger.d("Enqueue chain '\(chainName ?? "unnamed")' with \(stepsData.count) steps [cancelId: \(chainCancelId)]")

        // FIX M1: Return ACCEPTED immediately (non-blocking, consistent with Android).
        // Chain completion / failure is delivered via emitTaskEvent on the EventChannel.
        result("ACCEPTED")

        // FIX C1: Create the Task and store the handle BEFORE it starts running so
        // handleCancel can find and cancel it via activeTasks[chainCancelId].
        let chainTask = Task { [weak self] in
            defer {
                self?.stateQueue.async(flags: .barrier) {
                    self?.activeTasks.removeValue(forKey: chainCancelId)
                }
            }
            guard let self = self else { return }
            await self.executeChain(
                chainCancelId: chainCancelId,
                steps: stepsData,
                chainName: chainName,
                constraintsMap: constraintsMap,
                qos: qos
            )
        }
        stateQueue.async(flags: .barrier) {
            self.activeTasks[chainCancelId] = chainTask
            self.taskStates[chainCancelId] = "running"
        }
    }

    /// Execute a task chain sequentially.
    ///
    /// **Platform note:** iOS executes chains directly (in-process) while Android uses
    /// WorkManager. Completion and failures are reported via emitTaskEvent so the Dart
    /// side receives them through the existing EventChannel — same as individual tasks.
    ///
    /// **Cancellation:** store the Task handle in activeTasks[chainCancelId] before this
    /// runs (done by handleEnqueueChain). Calling cancel(chainCancelId) will set
    /// Task.isCancelled; this function checks it between every step.
    private func executeChain(
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

    /// Execute a worker synchronously, respecting the concurrency limit.
    ///
    /// Acquires a slot from [concurrencyLimiter] before running and releases it
    /// when the worker finishes, ensuring at most `maxConcurrentTasks` workers
    /// run in parallel across both direct enqueue and chain execution paths.
    private func executeWorkerSync(
        taskId: String,
        workerClassName: String,
        workerConfig: [String: Any],
        qos: String = "background"
    ) async -> WorkerResult {
        await concurrencyLimiter.acquire()
        let result = await _executeWorker(taskId: taskId, workerClassName: workerClassName, workerConfig: workerConfig, qos: qos)
        await concurrencyLimiter.release()
        return result
    }

    private func _executeWorker(
        taskId: String,
        workerClassName: String,
        workerConfig: [String: Any],
        qos: String = "background"
    ) async -> WorkerResult {
        NativeLogger.d("Executing task '\(taskId)' in chain with QoS: \(qos)...")
        // Record start time for debug notification timing
        stateQueue.async(flags: .barrier) {
            self.taskStartTimes[taskId] = Date()
        }

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
                    if result.success {
                        self.emitTaskEvent(taskId: taskId, success: true, message: result.message, resultData: result.data)
                    } else {
                        self.emitTaskEvent(taskId: taskId, success: false, message: result.message ?? "DartWorker failed")
                    }
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
                        guard let jsonData = try? JSONSerialization.data(withJSONObject: workerConfig),
                              let configJson = String(data: jsonData, encoding: .utf8) else {
                            NativeLogger.d("Error serializing worker config")
                            let result = WorkerResult.failure(message: "Config serialization failed")
                            self.emitTaskEvent(taskId: taskId, success: false, message: result.message)
                            continuation.resume(returning: result)
                            return
                        }
                        inputJson = configJson
                    }

                    // Create worker
                    guard let worker = IosWorkerFactory.createWorker(className: workerClassName) else {
                        NativeLogger.d("Unknown worker class: \(workerClassName)")
                        let result = WorkerResult.failure(message: "Unknown worker class")
                        self.emitTaskEvent(taskId: taskId, success: false, message: result.message)
                        continuation.resume(returning: result)
                        return
                    }

                    // Execute worker (v2.3.0+: returns WorkerResult)
                    do {
                        let result = try await worker.doWork(input: inputJson)

                        if result.success {
                            NativeLogger.d("Task '\(taskId)' completed successfully")
                            self.emitTaskEvent(taskId: taskId, success: true, message: result.message, resultData: result.data)
                        } else {
                            NativeLogger.d("Task '\(taskId)' failed")
                            self.emitTaskEvent(taskId: taskId, success: false, message: result.message ?? "Worker returned failure", resultData: result.data)
                        }

                        continuation.resume(returning: result)
                    } catch {
                        NativeLogger.d("Task '\(taskId)' error: \(error.localizedDescription)")
                        let result = WorkerResult.failure(message: error.localizedDescription)
                        self.emitTaskEvent(taskId: taskId, success: false, message: result.message)
                        continuation.resume(returning: result)
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
    private func executeDartWorkerViaMethodChannel(
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

    // MARK: - Event Emission

    func emitTaskEvent(taskId: String, success: Bool, message: String?, resultData: [String: Any]? = nil) {
        // Update task state
        stateQueue.async(flags: .barrier) {
            self.taskStates[taskId] = success ? "completed" : "failed"
        }

        // Persist status change to SQLite store
        if #available(iOS 13.0, *) {
            let resultJson: String? = resultData.flatMap { data in
                (try? JSONSerialization.data(withJSONObject: data))
                    .flatMap { String(data: $0, encoding: .utf8) }
            }
            taskStore?.updateStatus(
                taskId: taskId,
                status: success ? "completed" : "failed",
                resultData: resultJson
            )

            // Show download completion/failure notification if enabled for this task
            let notifTitle: String? = stateQueue.sync { taskNotifTitles[taskId] }
            if let title = notifTitle {
                stateQueue.async(flags: .barrier) {
                    self.taskNotifTitles.removeValue(forKey: taskId)
                }
                if success {
                    DownloadNotificationManager.showCompleted(taskId: taskId, title: title, fileName: nil)
                } else {
                    DownloadNotificationManager.showFailed(taskId: taskId, title: title, error: message ?? "Download failed")
                }
            }
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
        // Show download progress notification if enabled for this task
        if #available(iOS 13.0, *) {
            let notifTitle: String? = stateQueue.sync { taskNotifTitles[taskId] }
            if let title = notifTitle {
                DownloadNotificationManager.showProgress(
                    taskId: taskId,
                    title: title,
                    progress: Double(progress),
                    message: message
                )
            }
        }

        // FlutterEventSink must be called on the main thread
        DispatchQueue.main.async {
            self.progressSink?([
                "taskId": taskId,
                "progress": progress,
                "message": message as Any
            ])
        }
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
                NativeLogger.d("Notification permissions granted for debug mode")
            } else if let error = error {
                NativeLogger.w("Notification permissions denied: \(error.localizedDescription)")
            }
        }
    }

    private func showDebugNotification(taskId: String, success: Bool, message: String?) {
        // FIX H3: Read and remove taskStartTimes under the state lock to prevent data races.
        // emitTaskEvent (which calls this) can be called from multiple threads.
        let startTime: Date? = stateQueue.sync { taskStartTimes[taskId] }
        stateQueue.async(flags: .barrier) { self.taskStartTimes.removeValue(forKey: taskId) }
        let executionTime: String
        if let startTime = startTime {
            let elapsed = Date().timeIntervalSince(startTime)
            executionTime = String(format: "%.0fms", elapsed * 1000)
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
                NativeLogger.e("Error showing debug notification: \(error.localizedDescription)")
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
            NativeLogger.d("EventSink registered - listening for task events")
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
        NativeLogger.d("ProgressStreamHandler: Progress sink registered")
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.progressSink = nil
        NativeLogger.d("ProgressStreamHandler: Progress sink cancelled")
        return nil
    }
}
