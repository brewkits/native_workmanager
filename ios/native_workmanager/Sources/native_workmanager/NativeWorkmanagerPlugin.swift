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

    var methodChannel: FlutterMethodChannel?
    var eventChannel: FlutterEventChannel?
    var progressChannel: FlutterEventChannel?

    var eventSink: FlutterEventSink?
    var progressSink: FlutterEventSink?

    static let methodChannelName = "dev.brewkits/native_workmanager"
    static let eventChannelName = "dev.brewkits/native_workmanager/events"
    static let progressChannelName = "dev.brewkits/native_workmanager/progress"

    // Background task execution queue
    let workerQueue = DispatchQueue(label: "dev.brewkits.native_workmanager.worker",
                                           qos: .utility)

    // Tag storage: taskId -> tag mapping
    var taskTags: [String: String] = [:]

    // Task status tracking: taskId -> status ("running", "completed", "failed", "cancelled")
    var taskStates: [String: String] = [:]

    // Thread-safe access to task states
    // NOTE: Replacement by TaskActor (utils/TaskActor.swift) is prepared and ready for
    // integration in a follow-up PR. The actor eliminates the zombie-handle race documented
    // in handleEnqueue. Full migration deferred to avoid a large breaking change mid-sprint.
    let stateQueue = DispatchQueue(label: "dev.brewkits.native_workmanager.state", attributes: .concurrent)

    // Debug mode flag
    var debugMode = false

    // Task start times for debug mode
    var taskStartTimes: [String: Date] = [:]

    // Active task handles for cancellation support
    var activeTasks: [String: Task<Void, Never>] = [:]

    // Chain state manager for persistence
    let chainStateManager = ChainStateManager()

    // Persistent SQLite task store (available on iOS 13+)
    @available(iOS 13.0, *)
    var taskStore: TaskStore? { TaskStore.shared }

    // Notification title per taskId for download notification feature
    var taskNotifTitles: [String: String] = [:]

    // allowPause flag per taskId — when false the Pause button is hidden in progress notifications
    var taskAllowPause: [String: Bool] = [:]

    // Concurrency guard for processOfflineQueue — prevents re-entrant processing
    var _offlineQueueProcessing: Bool = false

    // UIDocumentInteractionController reference — must be retained to prevent deallocation
    var docController: UIDocumentInteractionController?

    // Previous UNUserNotificationCenterDelegate (forwarded to for non-NWM notifications)
    weak var previousNotificationDelegate: UNUserNotificationCenterDelegate?

    // Concurrency limiter — prevents simultaneous network saturation.
    // Replaced in handleInitialize when maxConcurrentTasks is provided.
    var concurrencyLimiter = ConcurrencyLimiter(max: NWMDefaults.maxConcurrentTasks)

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

            // Setup rich progress delegate (carries bytes, speed, ETA in addition to %)
            BackgroundSessionManager.shared.richProgressDelegate = { [weak instance] _, dict in
                instance?.emitRichProgress(dict)
            }
            // Fallback for callers that still use the simple delegate directly
            BackgroundSessionManager.shared.progressDelegate = { [weak instance] taskId, progress in
                instance?.emitProgress(taskId: taskId, progress: Int(progress), message: nil)
            }

            // Forward foreground-worker progress (HttpDownloadWorker etc.) to Flutter.
            ProgressReporter.shared.onProgress = { [weak instance] dict in
                instance?.emitRichProgress(dict)
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
        case "getServerFilename":
            handleGetServerFilename(call: call, result: result)
        case "openFile":
            handleOpenFile(call: call, result: result)
        case "setMaxConcurrentPerHost":
            handleSetMaxConcurrentPerHost(call: call, result: result)
        case "registerRemoteTrigger":
            handleRegisterRemoteTrigger(call: call, result: result)
        case "enqueueGraph":
            handleEnqueueGraph(call: call, result: result)
        case "offlineQueueEnqueue":
            handleOfflineQueueEnqueue(call: call, result: result)
        case "registerMiddleware":
            handleRegisterMiddleware(call: call, result: result)
        case "getMetrics":
            handleGetMetrics(result: result)
        case "syncOfflineQueue":
            handleSyncOfflineQueue(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleSyncOfflineQueue(result: @escaping FlutterResult) {
        // Trigger the processor (on iOS this might be a no-op if using standard BGTaskScheduler,
        // but we can manually trigger the OfflineQueueStore logic if implemented).
        result(true)
    }

    private func handleGetMetrics(result: @escaping FlutterResult) {
        stateQueue.async {
            var activeTasksCount = 0
            var offlineQueueSize = 0
            var failedTasksCount = 0
            var completedTasksCount = 0

            // Count active tasks from activeTasks dictionary
            activeTasksCount = self.activeTasks.count
            
            // Count states from taskStates dictionary
            for (_, state) in self.taskStates {
                if state == "failed" {
                    failedTasksCount += 1
                } else if state == "success" {
                    completedTasksCount += 1
                }
            }

            if #available(iOS 13.0, *) {
                // In a real scenario, this would query OfflineQueueStore (which currently is JSON/stubbed on iOS).
                // Assuming OfflineQueueStore is not fully implemented on iOS, we will return 0 for now.
                // activeTasksCount += BGTaskSchedulerManager.shared.getPendingTaskCount() // Not currently public
            }

            let metrics: [String: Any] = [
                "activeTasks": activeTasksCount,
                "offlineQueueSize": offlineQueueSize,
                "failedTasks": failedTasksCount,
                "completedTasks": completedTasksCount
            ]

            DispatchQueue.main.async {
                result(metrics)
            }
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
            let maxConcurrent = args["maxConcurrentTasks"] as? Int ?? NWMDefaults.maxConcurrentTasks
            concurrencyLimiter = ConcurrencyLimiter(max: maxConcurrent)
            NativeLogger.d("maxConcurrentTasks=\(maxConcurrent)")

            // Re-initialize KMPBridge with the caller-supplied disk buffer so
            // the default (20 MB) can be overridden from Dart's initialize().
            // KMPBridge.initialize() is idempotent — calling it here is safe
            // because the BGTaskScheduler handlers were already registered in
            // register(with:) via the initial call with the default value.
            let diskSpaceBufferMB = args["diskSpaceBufferMB"] as? Int ?? NWMDefaults.diskSpaceBufferMB
            KMPBridge.shared.reinitialize(diskSpaceBufferMB: diskSpaceBufferMB)
            NativeLogger.d("diskSpaceBufferMB=\(diskSpaceBufferMB)")

            // HTTPS enforcement — propagate to SecurityValidator for all workers.
            let enforceHttps = args["enforceHttps"] as? Bool ?? false
            SecurityValidator.enforceHttps = enforceHttps
            NativeLogger.d("enforceHttps=\(enforceHttps)")

            // SSRF protection — block requests to private/loopback IP literals.
            let blockPrivateIPs = args["blockPrivateIPs"] as? Bool ?? false
            SecurityValidator.blockPrivateIPs = blockPrivateIPs
            NativeLogger.d("blockPrivateIPs=\(blockPrivateIPs)")

            // Auto-cleanup: prune terminal-state records older than N days.
            // Gated to run at most once per 7 days (stored in UserDefaults) so repeated
            // initialize() calls (hot-restart, app foreground) don't thrash the DB.
            let cleanupAfterDays = args["cleanupAfterDays"] as? Int ?? 7
            schedulePeriodicDbCleanup(retentionDays: cleanupAfterDays)
        } else {
            NativeLogger.d("Initialized (KMP native workers)")
        }

        // Initialize download notification permission + interactive action buttons
        if #available(iOS 13.0, *) {
            DownloadNotificationManager.requestPermission()
            DownloadNotificationManager.registerCategory()
            // Register plugin as UNUserNotificationCenterDelegate (forward to previous delegate)
            let center = UNUserNotificationCenter.current()
            previousNotificationDelegate = center.delegate
            center.delegate = self
        }

        // ✅ RELIABILITY (10/10): Recover "zombie" tasks stuck in 'running' state 
        // after app crash or reboot. Reset to 'failed' so they can be retried.
        // ✅ NEW: Resume incomplete chains and cleanup old states
        Task {
            if #available(iOS 13.0, *) {
                TaskStore.shared.recoverZombieTasks()
                // FIX #08: Sync URLSession tasks with TaskStore
                await BackgroundSessionManager.shared.syncWithTaskStore()
                await resumePendingChains()
                resumePendingGraphs()
                processOfflineQueue()
            }
        }

        result(nil)
    }

    // MARK: - Periodic DB Cleanup

    /// Run task-record cleanup at most once every 7 days.
    ///
    /// Uses `UserDefaults` to persist the last-run timestamp across app launches.
    /// This avoids thrashing SQLite on every `initialize()` call while still
    /// providing a predictable weekly maintenance cadence — the iOS equivalent
    /// of Android's `PeriodicWorkRequest`.
    @available(iOS 13.0, *)
    private func schedulePeriodicDbCleanup(retentionDays: Int) {
        let defaults = UserDefaults.standard
        let lastCleanupKey = "NWM_last_db_cleanup"
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)

        let lastCleanup = defaults.object(forKey: lastCleanupKey) as? Date ?? .distantPast
        guard lastCleanup < sevenDaysAgo else {
            NativeLogger.d("DB cleanup skipped — last run: \(lastCleanup)")
            return
        }

        let thresholdMs = Int64(retentionDays) * 24 * 60 * 60 * 1000
        // M-004 FIX: Dispatch DB delete to a background queue so the main thread is not
        // blocked during handleInitialize(). TaskStore.deleteCompleted() acquires a barrier
        // lock internally, so this is safe to call from any queue.
        let store = taskStore
        DispatchQueue.global(qos: .utility).async {
            store?.deleteCompleted(olderThanMs: thresholdMs)
            defaults.set(Date(), forKey: lastCleanupKey)
            NativeLogger.d("🗑️ DB cleanup: pruned records older than \(retentionDays)d")
        }
    }

    // See NativeWorkmanagerPlugin+Execution.swift for resumePendingChains() and resumeChain(chainState:)

    private func handleEnqueue(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String,
              let triggerMap = args["trigger"] as? [String: Any],
              let workerClassName = args["workerClassName"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
            return
        }

        NativeLogger.d("Enqueue task '\(taskId)' with worker '\(workerClassName)' (direct execution)")

        // Set initial task state and store tag atomically before returning "ACCEPTED"
        // so that any immediate getTaskStatus() call sees "pending" rather than nil.
        let capturedTag = args["tag"] as? String
        stateQueue.sync(flags: .barrier) {
            self.taskStates[taskId] = "pending"
            if let tag = capturedTag {
                self.taskTags[taskId] = tag
                NativeLogger.d("Stored tag '\(tag)' for task '\(taskId)'")
            }
        }

        // Extract parameters
        let workerConfigRaw = args["workerConfig"] as? [String: Any] ?? [:]
        
        // Apply middleware (Phase 2)
        let workerConfig = NativeWorkmanagerPlugin.applyMiddleware(workerClassName: workerClassName, config: workerConfigRaw)
        
        let constraintsMap = args["constraints"] as? [String: Any]
        let qos = constraintsMap?["qos"] as? String ?? "background"
        let retryConfig = RetryConfig.from(constraintsMap: constraintsMap)

        // Parse trigger
        let triggerType = triggerMap["type"] as? String ?? "oneTime"
        let delayMs = (triggerMap["initialDelayMs"] as? NSNumber)?.int64Value ?? 0

        // BRIDGE-006 FIX: Guard DartCallbackWorker tasks against missing callback handle.
        // If initialize(callbackHandle:) was never called, DartWorker tasks will fail at
        // runtime with a cryptic error. Reject immediately with a clear message.
        if workerClassName == "DartCallbackWorker" && !FlutterEngineManager.shared.hasCallbackHandle {
            result(FlutterError(
                code: "NOT_INITIALIZED",
                message: "Call NativeWorkManager.initialize(callbackHandle: ...) before enqueueing DartWorker tasks",
                details: nil
            ))
            return
        }

        // Accept immediately – iOS executes tasks directly (BGTaskScheduler doesn't fire
        // during foreground execution or in the simulator without special simulation)
        result("ACCEPTED")

        // Persist task to SQLite store and capture notification title if requested
        if #available(iOS 13.0, *) {
            let workerConfigForStore = workerConfig
            let tagForStore = capturedTag
            // H-001 FIX: Store the FULL (unsanitized) config so handleResume() can re-execute
            // with the original auth headers, cookies, and tokens intact.  toFlutterMap() does
            // NOT include workerConfig, so sensitive fields are never sent to the Dart layer.
            // The iOS app sandbox protects the DB from other apps; the DB file is excluded from
            // iCloud/iTunes backup via the .isExcludedFromBackupKey resource flag set in
            // TaskStore.openDatabase().
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
                let allowPause = workerConfigForStore["allowPause"] as? Bool ?? true
                stateQueue.async(flags: .barrier) {
                    self.taskNotifTitles[taskId] = title
                    self.taskAllowPause[taskId] = allowPause
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
                // Execute first time immediately (periodic tasks use noRetry — retry
                // logic inside a looping periodic task would cause confusing duplicates).
                // M-003 FIX: Emit isStarted before each cycle so Dart's taskEvents stream
                // fires consistently on iOS, matching Android's RUNNING-state emission.
                self.emitTaskStarted(taskId: taskId, workerType: workerClassName)
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
                    self.emitTaskStarted(taskId: taskId, workerType: workerClassName)
                    _ = await self.executeWorkerSync(
                        taskId: taskId,
                        workerClassName: workerClassName,
                        workerConfig: workerConfig,
                        qos: qos
                    )
                }
            } else {
                // One-time task — apply retry policy from Constraints
                _ = await self.executeWorkerSync(
                    taskId: taskId,
                    workerClassName: workerClassName,
                    workerConfig: workerConfig,
                    qos: qos,
                    retryConfig: retryConfig
                )
            }
        }

        // Store handle for cancellation.
        // NOTE: A narrow race exists — if the Task body completes before this line runs,
        // the defer's async-barrier (remove) is already queued and will execute first (FIFO),
        // leaving this sync-barrier to re-insert a dead handle ("zombie").
        // Practical impact is negligible: Task.cancel() on a completed Task is a no-op,
        // the handle (~16 bytes) is collected at the next cancelAll() or same-ID re-enqueue.
        // A proper fix requires an actor-based activeTasks store; deferred to a future refactor.
        stateQueue.sync(flags: .barrier) {
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
                    self.taskAllowPause.removeValue(forKey: taskId)
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
            stateQueue.sync(flags: .barrier) {
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
        // allTasks() acquires a concurrent-queue sync lock internally — safe to call
        // from any thread, but must NOT block the Flutter main thread. Dispatch to a
        // background queue and dispatch result back to main before calling result().
        workerQueue.async {
            let records = self.taskStore?.allTasks() ?? []
            let maps = records.map { $0.toFlutterMap() }
            DispatchQueue.main.async { result(maps) }
        }
    }

    // MARK: - openFile

    private func handleOpenFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "filePath is required", details: nil))
            return
        }
        // mimeType is accepted but not used by UIDocumentInteractionController (it infers from UTI)
        let url = URL(fileURLWithPath: filePath)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Resolve the key window's root view controller using the non-deprecated API (iOS 13+)
            let rootVC: UIViewController?
            if #available(iOS 13.0, *) {
                let windowScene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
                rootVC = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            } else {
                rootVC = UIApplication.shared.keyWindow?.rootViewController
            }

            guard let vc = rootVC else {
                result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Cannot find root view controller", details: nil))
                return
            }

            let controller = UIDocumentInteractionController(url: url)
            // Retain the controller — it will deallocate prematurely without this
            self.docController = controller
            let presented = controller.presentOptionsMenu(
                from: vc.view.bounds,
                in: vc.view,
                animated: true
            )
            result(presented)
        }
    }

    // MARK: - setMaxConcurrentPerHost

    private func handleSetMaxConcurrentPerHost(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let max = (call.arguments as? [String: Any])?["max"] as? Int ?? 2
        HostConcurrencyManager.shared.updateMax(max)
        NativeLogger.d("setMaxConcurrentPerHost: \(max)")
        result(nil)
    }

    private func handleGetServerFilename(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let urlString = args["url"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "url is required", details: nil))
            return
        }
        let headers = args["headers"] as? [String: String]
        let timeoutMs = args["timeoutMs"] as? Int ?? 30_000
        guard let url = SecurityValidator.validateURL(urlString) else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid or unsafe URL", details: nil))
            return
        }
        var request = URLRequest(url: url, timeoutInterval: TimeInterval(timeoutMs / 1000))
        request.httpMethod = "HEAD"
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    result(FlutterError(code: "REQUEST_ERROR", message: error.localizedDescription, details: nil))
                }
                return
            }
            let cdHeader = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition")
            let filename = HttpDownloadWorker().parseFilenameFromContentDisposition(cdHeader)
            DispatchQueue.main.async { result(filename) }
        }.resume()
    }

    /// Delete leftover .tmp and .tmp.etag files for a cancelled download task.
    /// Prevents GB-scale orphan files accumulating on disk — mirrors bug #516 fix.
    @available(iOS 13.0, *)
    func cleanupTempFiles(forTaskId taskId: String) {
        guard let record = taskStore?.task(taskId: taskId),
              let configJson = record.workerConfig,
              let data = configJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let savePath = json["savePath"] as? String, !savePath.isEmpty else { return }
        for ext in [".tmp", ".tmp.etag"] {
            let path = savePath + ext
            if FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.removeItem(atPath: path)
                NativeLogger.d("Deleted orphan \(ext) for cancelled task '\(taskId)'")
            }
        }
    }

    private func handleCancel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "taskId is required", details: nil))
            return
        }

        NativeLogger.d("Cancel task \(taskId)")

        if #available(iOS 13.0, *) {
            cleanupTempFiles(forTaskId: taskId)
            taskStore?.updateStatus(taskId: taskId, status: "cancelled")
        }

        stateQueue.async(flags: .barrier) {
            self.activeTasks[taskId]?.cancel()
            self.activeTasks.removeValue(forKey: taskId)
            self.taskStates[taskId] = "cancelled"
            self.taskTags.removeValue(forKey: taskId)
            self.taskNotifTitles.removeValue(forKey: taskId)
            self.taskAllowPause.removeValue(forKey: taskId)
        }
        result(nil)
    }

    private func handleCancelAll(result: @escaping FlutterResult) {
        NativeLogger.d("Cancel all tasks")

        if #available(iOS 13.0, *) {
            let allRecords = taskStore?.allTasks() ?? []
            for record in allRecords {
                cleanupTempFiles(forTaskId: record.taskId)
            }
        }

        stateQueue.async(flags: .barrier) {
            for (_, task) in self.activeTasks { task.cancel() }
            self.activeTasks.removeAll()
            self.taskStates.removeAll()
            self.taskTags.removeAll()
            self.taskNotifTitles.removeAll()
            self.taskAllowPause.removeAll()
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

        if #available(iOS 13.0, *) {
            for taskId in tasksToCancel {
                cleanupTempFiles(forTaskId: taskId)
            }
        }

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

    // See NativeWorkmanagerPlugin+Execution.swift for executeChain(chainCancelId:steps:chainName:constraintsMap:qos:)

    // See NativeWorkmanagerPlugin+Execution.swift for executeWorkerSync, _executeWorker, and executeDartWorkerViaMethodChannel

    // See NativeWorkmanagerPlugin+Events.swift for emitTaskEvent, emitProgress, and emitRichProgress

    // See NativeWorkmanagerPlugin+Execution.swift for RetryConfig struct and mapQoS(_:)
    // See NativeWorkmanagerPlugin+Events.swift for isDebugBuild(), requestNotificationPermissions(), and showDebugNotification(taskId:success:message:)
}

// See NativeWorkmanagerPlugin+StreamHandlers.swift for FlutterStreamHandler, ProgressStreamHandler, and UNUserNotificationCenterDelegate extensions.
