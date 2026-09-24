import Flutter
import UIKit
import UserNotifications

/// Type-safe task lifecycle states — replaces stringly-typed [String: String] map.
/// `rawValue` is the canonical string forwarded to Flutter and persisted to SQLite.
enum TaskState: String {
    case pending    = "pending"
    case running    = "running"
    case paused     = "paused"
    case cancelled  = "cancelled"
    case completed  = "completed"
    case failed     = "failed"
}

public class NativeWorkmanagerPlugin: NSObject, FlutterPlugin {

    var methodChannel: FlutterMethodChannel?
    var eventChannel: FlutterEventChannel?
    var progressChannel: FlutterEventChannel?
    // Foreground DartWorker callbacks run in the main engine and call
    // MethodChannel('dev.brewkits/dart_worker_channel').invokeMethod('reportProgress').
    // The main engine must handle it (the FlutterEngineManager background engine has
    // its own copy); without this, reportDartWorkerProgress() throws MissingPluginException
    // and the callback fails. Retained so its handler is not deallocated.
    var dartWorkerChannel: FlutterMethodChannel?
    var systemErrorChannel: FlutterEventChannel?

    var eventSink: FlutterEventSink?
    var progressSink: FlutterEventSink?
    var systemErrorSink: FlutterEventSink?

    static let methodChannelName = "dev.brewkits/native_workmanager"
    static let eventChannelName = "dev.brewkits/native_workmanager/events"
    static let progressChannelName = "dev.brewkits/native_workmanager/progress"
    static let systemErrorChannelName = "dev.brewkits/native_workmanager/system_errors"

    public typealias PluginRegistrantCallback = (FlutterPluginRegistry) -> Void
    public static var pluginRegistrantCallback: PluginRegistrantCallback? = nil

    @objc
    public static func setPluginRegistrantCallback(_ callback: @escaping PluginRegistrantCallback) {
        pluginRegistrantCallback = callback
    }

    /// Explicitly register the plugin's BGTaskScheduler launch handlers.
    ///
    /// **Usually unnecessary** — the plugin auto-registers its handlers in an
    /// ObjC `+load` hook (NWMBGTaskRegistrar), which runs before the app
    /// finishes launching on every Flutter template, old or new (Issue #36).
    ///
    /// Call this from `application(_:didFinishLaunchingWithOptions:)` only as a
    /// belt-and-braces measure, or if your build strips ObjC `+load` sections:
    ///
    /// ```swift
    /// override func application(_ application: UIApplication,
    ///     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    ///     NativeWorkmanagerPlugin.registerBGTaskHandlers()
    ///     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    /// }
    /// ```
    ///
    /// Idempotent and exception-safe: duplicate or late registration degrades
    /// to a logged system error instead of a crash.
    @objc
    public static func registerBGTaskHandlers() {
        if #available(iOS 13.0, *) {
            BGTaskSchedulerManager.shared.registerHandlers()
        }
    }

    private static var shared: NativeWorkmanagerPlugin?

    let workerQueue = DispatchQueue(label: "dev.brewkits.native_workmanager.worker", qos: .utility)

    // Tag storage for fast lookup
    var taskTags: [String: String] = [:]
    var taskStates: [String: TaskState] = [:]
    let stateQueue = DispatchQueue(label: "dev.brewkits.native_workmanager.state", attributes: .concurrent)

    var debugMode = false
    var taskStartTimes: [String: Date] = [:]
    var activeTasks: [String: Task<Void, Never>] = [:]
    var workers: [String: IosWorker] = [:]

    /// taskId -> a fresh id minted each time `handleEnqueue`'s direct
    /// (one-time) path stores a new entry in `activeTasks`. `activeTasks`
    /// itself is never cleared when a direct task finishes NATURALLY
    /// (success, failure, or timeout) — only explicit cancel paths
    /// (handleCancel/cancelAll/cancelByTag/notification-cancel) ever call
    /// `removeValue`. Before existingPolicy was implemented that was a
    /// harmless leak (a `Task` value is cheap and nothing read the dict as a
    /// liveness signal). It is not harmless now: `existingPolicy` reads
    /// `activeTasks[taskId] != nil` to decide whether a taskId is "still
    /// running". Confirmed on a simulator (2026-09-23 lib/ audit follow-up):
    /// re-enqueuing a taskId whose task had already completed, with
    /// `existingPolicy: .keep`, was silently dropped forever — `.keep` saw
    /// the stale entry and concluded something was still running. This id
    /// lets the completing Task's own cleanup remove its `activeTasks` entry
    /// exactly once it is truly done, while guarding against a replacing
    /// execution's entry being wiped out from under it (same "clear only if
    /// still current" pattern as `DartTaskCancellationRegistry.endExecution`).
    var activeTaskGenerations: [String: UUID] = [:]

    @available(iOS 13.0, *)
    var chainStateManager: ChainStateManager { ChainStateManager.shared }

    @available(iOS 13.0, *)
    var taskStore: TaskStore? { TaskStore.shared }

    var taskNotifTitles: [String: String] = [:]
    var taskAllowPause: [String: Bool] = [:]
    var _offlineQueueProcessing: Bool = false
    var docController: UIDocumentInteractionController?
    weak var previousNotificationDelegate: UNUserNotificationCenterDelegate?
    var concurrencyLimiter = ConcurrencyLimiter(max: 4)

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = NativeWorkmanagerPlugin()
        shared = instance
        let messenger = registrar.messenger()
        
        instance.methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel!)

        instance.eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
        instance.eventChannel?.setStreamHandler(instance)

        instance.progressChannel = FlutterEventChannel(name: progressChannelName, binaryMessenger: messenger)
        instance.progressChannel?.setStreamHandler(ProgressStreamHandler(plugin: instance))
        
        instance.systemErrorChannel = FlutterEventChannel(name: systemErrorChannelName, binaryMessenger: messenger)
        instance.systemErrorChannel?.setStreamHandler(SystemErrorStreamHandler(plugin: instance))

        // Handle progress reports from foreground DartWorker callbacks (they run in
        // the main engine, not the FlutterEngineManager background engine).
        instance.dartWorkerChannel = FlutterMethodChannel(
            name: "dev.brewkits/dart_worker_channel", binaryMessenger: messenger)
        instance.dartWorkerChannel?.setMethodCallHandler { (call, result) in
            let args = call.arguments as? [String: Any]
            switch call.method {
            case "reportProgress":
                let taskId   = args?["taskId"]   as? String ?? ""
                let progress = args?["progress"] as? Int    ?? 0
                let message  = args?["message"]  as? String
                // Route through ProgressReporter (same as the FlutterEngineManager
                // background path): forwards to the progress EventChannel via onProgress,
                // records lastEmittedUpdates, and persists last_progress_json to SQLite.
                ProgressReporter.shared.report(taskId: taskId, progress: progress, message: message)
                result(nil)
            // Issue #66: cooperative cancellation poll from a foreground
            // DartWorker callback (running in this main isolate, not the
            // headless FlutterEngineManager engine — see DartTaskCancellationRegistry).
            case "isTaskCancelled":
                let taskId = args?["taskId"] as? String ?? ""
                // Issue #72: precise per-execution check when the Dart side's
                // Zone had an executionId to send (see method_channel.dart's
                // _executeDartCallback); falls back to the coarse taskId
                // check otherwise.
                if let executionId = args?["executionId"] as? String {
                    result(DartTaskCancellationRegistry.shared.isCancelled(executionId: executionId))
                } else {
                    result(DartTaskCancellationRegistry.shared.isCancelled(taskId))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        KMPBridge.shared.initialize()

        if #available(iOS 13.0, *) {
            BGTaskSchedulerManager.shared.registerHandlers()
            BGTaskSchedulerManager.shared.taskExecutor = { [weak instance] taskInfo in
                guard let instance = instance else { return false }
                return await instance.executeWorkerSync(
                    taskId: taskInfo.taskId,
                    workerClassName: taskInfo.workerClassName,
                    workerConfig: taskInfo.workerConfig.mapValues { $0.value },
                    qos: taskInfo.qos
                )
            }
            BGTaskSchedulerManager.shared.onTaskComplete = { [weak instance] taskId, success, message in
                instance?.emitTaskEvent(taskId: taskId, success: success, message: message)
            }
            BGTaskSchedulerManager.shared.onTaskStart = { [weak instance] in
                Task { await instance?.resumePendingChains(); instance?.resumePendingGraphs() }
            }
            BGTaskSchedulerManager.shared.onExpiration = { [weak instance] in
                instance?.stopAllWorkers()
            }
            BGTaskSchedulerManager.shared.onTaskRunning = { [weak instance] taskId, runningTask in
                // Track OS-triggered running tasks so NativeWorkManager.cancel(taskId) can
                // cancel the Swift Task via cooperative cancellation.
                guard let instance else { return }
                // Improvement pass, 2026-09-24: this used to just store the Task with no
                // generation tracking, so — same bug shape as handleEnqueue/handleResume
                // before they were fixed — a periodic/refresh task that finishes NATURALLY
                // (not via expiration) never had its activeTasks entry cleared, leaving a
                // stale "still running" signal for that taskId forever (existingPolicy
                // could misread it, cancel(taskId) would try to cancel an already-finished
                // Task). Expiration already self-heals via stopAllWorkers(), which clears
                // everything — this is specifically for the non-expiring completion path.
                //
                // BGTaskSchedulerManager creates and owns `runningTask` itself (it's what
                // actually drives the BGProcessingTask/BGAppRefreshTask lifecycle), so this
                // closure can't wrap its body in a defer the way handleEnqueue/handleResume
                // wrap their own `Task { }` via replaceActiveTask. Instead, observe its
                // completion from the outside: `Task<Void, Never>.value` suspends until the
                // task's closure returns — success, failure, or an early cancelled return —
                // then run the exact same "clear only if still current" cleanup as
                // everywhere else, guarding against a taskId that got replaced in the
                // meantime.
                let generationId = UUID()
                instance.stateQueue.sync(flags: .barrier) {
                    instance.activeTasks[taskId] = runningTask
                    instance.activeTaskGenerations[taskId] = generationId
                }
                Task { [weak instance] in
                    _ = await runningTask.value
                    guard let instance else { return }
                    instance.stateQueue.sync(flags: .barrier) {
                        guard instance.activeTaskGenerations[taskId] == generationId else { return }
                        instance.activeTasks.removeValue(forKey: taskId)
                        instance.activeTaskGenerations.removeValue(forKey: taskId)
                    }
                }
            }
            BackgroundSessionManager.shared.richProgressDelegate = { [weak instance] _, dict in
                instance?.emitRichProgress(dict)
            }
            BackgroundSessionManager.shared.relaunchCompletionDelegate = { [weak instance] taskId, result in
                switch result {
                case .success: instance?.emitTaskEvent(taskId: taskId, success: true, message: "Download completed")
                case .failure(let error): instance?.emitTaskEvent(taskId: taskId, success: false, message: error.localizedDescription)
                }
            }
        }
    }

    public static func emitSystemError(code: String, message: String) {
        NativeLogger.e("🚨 SYSTEM ERROR [\(code)]: \(message)")
        DispatchQueue.main.async {
            shared?.systemErrorSink?([
                "code": code,
                "message": message,
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
            ])
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        NativeLogger.d("handle: \(call.method)")
        switch call.method {
        case "initialize":              handleInitialize(call: call, result: result)
        case "enqueue":                 handleEnqueue(call: call, result: result)
        case "cancel":                  handleCancel(call: call, result: result)
        case "cancelAll":               handleCancelAll(result: result)
        case "cancelByTag":             handleCancelByTag(call: call, result: result)
        case "getTasksByTag":           handleGetTasksByTag(call: call, result: result)
        case "getAllTags":              handleGetAllTags(result: result)
        case "getTaskStatus":           handleGetTaskStatus(call: call, result: result)
        case "getTaskRecord":           handleGetTaskRecord(call: call, result: result)
        case "allTasks":                handleAllTasks(result: result)

        case "pause":                   handlePause(call: call, result: result)
        case "resume":                  handleResume(call: call, result: result)
        case "getServerFilename":       handleGetServerFilename(call: call, result: result)
        case "setMaxConcurrentPerHost": result(nil)  // no-op on iOS
        case "getMetrics":             result([:])   // stub
        case "syncOfflineQueue":        result(false) // stub
        case "getRunningProgress":      result(ProgressReporter.shared.getRunningProgress())
        case "openFile":                handleOpenFile(call: call, result: result)
        // iOS has no battery-optimization exemption list. BGTaskScheduler grants background
        // time from its own budget and there is nothing an app can ask to be excused from,
        // so these report "not applicable" rather than a reassuring default. isExempt is
        // nil (NSNull over the channel) so Dart can distinguish "no such concept" from
        // "not exempt" — see BatteryRestrictionReport.isSupported.
        case "batteryRestriction":
            result([
                "isExempt": NSNull(),
                "manufacturer": NSNull(),
                "canOpenSettings": false,
            ])
        case "openBatteryOptimizationSettings":
            result(false)
        case "requestDisableBatteryOptimization":
            result("notSupported")
        case "debugBGTaskRegistration": // issue_36 regression probe (iOS-only, debug/testing)
            if #available(iOS 13.0, *) {
                result(BGTaskSchedulerManager.shared.registrationDebugInfo())
            } else {
                result([:])
            }
        default: handleExtensionMethods(call: call, result: result)
        }
    }

    private func handleInitialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let args = call.arguments as? [String: Any] {
            if let callbackHandle = args["callbackHandle"] as? Int64 {
                FlutterEngineManager.shared.setCallbackHandle(callbackHandle)
            }
            if let registerPlugins = args["registerPlugins"] as? Bool {
                FlutterEngineManager.shared.setRegisterPlugins(registerPlugins)
            }
            debugMode = args["debugMode"] as? Bool ?? false
        }
        if #available(iOS 13.0, *) {
            Task {
                TaskStore.shared.recoverZombieTasks()
                await BackgroundSessionManager.shared.syncWithTaskStore()
                await resumePendingChains()
                resumePendingGraphs()
            }
        }
        result(nil)
    }

    private func handleEnqueue(call: FlutterMethodCall, result: @escaping FlutterResult) {
        NativeLogger.d("handleEnqueue called")
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String,
              let workerClassName = args["workerClassName"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing args", details: nil))
            return
        }

        let tag = args["tag"] as? String
        stateQueue.sync(flags: .barrier) {
            self.taskStates[taskId] = .pending
            if let t = tag { self.taskTags[taskId] = t }
        }

        if #available(iOS 13.0, *) {
            let configRaw = args["workerConfig"] as? [String: Any]
            // Sanitize before persisting to SQLite — plaintext secrets must never reach disk.
            // 1. CryptoWorker: move password into Keychain, replace with a vault key that the
            //    worker resolves at runtime (mirrors Android's KeystorePasswordVault pattern).
            // 2. All workers: redact authToken / apiKey / Authorization headers etc.
            var configForStorage = configRaw
            if var config = configRaw {
                if workerClassName.contains("CryptoWorker"),
                   let password = config["password"] as? String, !password.isEmpty {
                    let vaultKey = KeystorePasswordVault.shared.store(password)
                    config.removeValue(forKey: "password")
                    config["passwordKey"] = vaultKey
                }
                configForStorage = TaskStore.sanitizeConfig(config) ?? config
            }
            let configJson = configForStorage
                .flatMap { try? JSONSerialization.data(withJSONObject: $0) }
                .flatMap { String(data: $0, encoding: .utf8) }
            taskStore?.upsert(taskId: taskId, tag: tag, status: "pending", workerClassName: workerClassName, workerConfig: configJson)
        }

            let workerConfig = args["workerConfig"] as? [String: Any] ?? [:]
        let triggerMap = args["trigger"] as? [String: Any]
        let initialDelayMs = (triggerMap?["initialDelayMs"] as? Int) ?? 0
        let runImmediately = (triggerMap?["runImmediately"] as? Bool) ?? true
        let intervalMs = (triggerMap?["intervalMs"] as? Int) ?? 0

        if #available(iOS 13.0, *), (triggerMap?["type"] as? String) == "periodic" {
            // iOS doesn't have a "periodic" scheduler like Android, but we can simulate
            // the initial delay and runImmediately: false by setting earliestBeginDate.
            var effectiveDelayMs = Double(initialDelayMs)
            if !runImmediately && effectiveDelayMs == 0 {
                effectiveDelayMs = Double(intervalMs)
            }
            let earliestBeginDate = Date(timeIntervalSinceNow: effectiveDelayMs / 1000.0)
            
            let constraintsMap = args["constraints"] as? [String: Any]
            
            // Respect bgTaskType if provided, otherwise fallback to auto-selection via isHeavyTask.
            let bgTaskType = constraintsMap?["bgTaskType"] as? String
            let isHeavyTask: Bool
            if let type = bgTaskType {
                isHeavyTask = (type == "processing")
            } else {
                isHeavyTask = constraintsMap?["isHeavyTask"] as? Bool ?? false
            }

            // requiresUnmeteredNetwork (WiFi-only) also implies network required.
            // iOS BGTask doesn't distinguish metered vs unmetered, so both map to requiresNetwork.
            let requiresNetwork = (constraintsMap?["requiresNetwork"] as? Bool ?? false)
                || (constraintsMap?["requiresUnmeteredNetwork"] as? Bool ?? false)
            let requiresExternalPower = constraintsMap?["requiresCharging"] as? Bool ?? false
            let qos = (constraintsMap?["qos"] as? String) ?? "background"
            // Note: backoffPolicy, backoffDelayMs, and systemConstraints (DEVICE_IDLE,
            // REQUIRE_BATTERY_NOT_LOW) have no BGTask equivalents and are intentionally ignored.

            let identifier = isHeavyTask ? BGTaskSchedulerManager.defaultTaskIdentifier : BGTaskSchedulerManager.refreshTaskIdentifier

            BGTaskSchedulerManager.shared.scheduleTask(
                identifier: identifier,
                taskId: taskId,
                workerClassName: workerClassName,
                workerConfig: workerConfig,
                earliestBeginDate: earliestBeginDate,
                requiresNetwork: requiresNetwork,
                requiresExternalPower: requiresExternalPower,
                isHeavyTask: isHeavyTask,
                qos: qos
            )

            // Track periodic tasks in activeTasks so cancel() works.
            // The Task body is intentionally empty — it completes immediately.
            // Its presence in the dict is the only requirement: handleCancel reads
            // activeTasks to decide whether to call BGTaskSchedulerManager.cancelTask().
            stateQueue.sync(flags: .barrier) {
                self.activeTasks[taskId] = Task { }
            }

            result("ACCEPTED")
            return
        }

        let directConstraintsMap = args["constraints"] as? [String: Any]
        let directQos = (directConstraintsMap?["qos"] as? String) ?? "background"
        let directRetryConfig = RetryConfig.from(constraintsMap: directConstraintsMap)

        // existingPolicy was accepted from Dart but never read here — every repeat
        // enqueue() of the same taskId silently started a second, fully independent
        // concurrent Task, regardless of what policy the caller asked for, because this
        // dictionary write always just clobbered whatever was there. Confirmed on a
        // simulator (2026-09-23 lib/ audit): two DartWorker executions of one taskId,
        // 600ms apart, both ran to full completion independently. "replace" (the
        // default, matching Android and NativeWorkManager.enqueue's own default) now
        // stops the outgoing execution the same way handleCancel does before starting
        // the new one; "keep" leaves the running execution alone and ignores the new
        // request, matching WorkManager's ExistingWorkPolicy.KEEP on Android, which also
        // always reports the enqueue as accepted regardless of whether it was a no-op.
        let existingPolicyStr = (args["existingPolicy"] as? String)?.lowercased() ?? "replace"
        var skippedForKeep = false
        // Minted here (not lazily inside executeDartWorkerViaMethodChannel) only for
        // DartCallbackWorker — see replaceActiveTask's doc comment. Any other worker
        // class has no cancellation-registry entry to pre-register, and doing it
        // anyway would leak: only executeDartWorkerViaMethodChannel's `defer` calls
        // endExecution.
        let dartExecutionId = workerClassName == "DartCallbackWorker" ? UUID().uuidString : nil
        replaceActiveTask(
            taskId: taskId,
            skipIfAlreadyRunning: existingPolicyStr == "keep",
            dartExecutionId: dartExecutionId,
            onSkipped: { skippedForKeep = true }
        ) { [weak self] preMintedExecutionId in
            guard let self else { return }
            if initialDelayMs > 0 {
                try? await Task.sleep(nanoseconds: UInt64(initialDelayMs) * 1_000_000)
            }
            guard !Task.isCancelled else { return }
            await self.executeWorkerSync(
                taskId: taskId,
                workerClassName: workerClassName,
                workerConfig: workerConfig,
                qos: directQos,
                retryConfig: directRetryConfig,
                preMintedExecutionId: preMintedExecutionId
            )
        }
        if skippedForKeep {
            NativeLogger.d("handleEnqueue: '\(taskId)' already running, existingPolicy=keep — new request ignored")
        }

        result("ACCEPTED")
    }

    /// Cancels whatever is currently registered for `taskId` in `activeTasks` and
    /// registers a fresh execution, atomically — the "check-decide-store" sequence
    /// `handleEnqueue`'s `existingPolicy` handling and `handleResume` both need, pulled
    /// into one place after duplicating it once already produced a gap (`handleResume`
    /// used to build its own untracked `Task {}`, found in the 2026-09-24 iOS
    /// improvement pass: a paused-then-resumed NON-background-session task could run
    /// TWO concurrent executions, because `handlePause` never actually stops anything
    /// for a task `BackgroundSessionManager` doesn't recognize as a real download, and
    /// the resumed `Task` was never registered in `activeTasks` for anything to check
    /// against).
    ///
    /// The whole thing runs inside one `stateQueue` barrier block so two overlapping
    /// calls for the same `taskId` (an enqueue racing a resume, a resume racing another
    /// resume, ...) can't both see "nothing running yet" and both proceed.
    ///
    /// - Parameters:
    ///   - skipIfAlreadyRunning: `true` for `existingPolicy: .keep` — leaves a running
    ///     execution alone and calls `onSkipped` instead of starting `work`.
    ///   - work: the body to run as the new tracked `Task`. Checking `Task.isCancelled`
    ///     inside `work` (e.g. after an initial delay) is the caller's job, same as
    ///     before this was extracted.
    func replaceActiveTask(
        taskId: String,
        skipIfAlreadyRunning: Bool = false,
        dartExecutionId: String? = nil,
        onSkipped: (() -> Void)? = nil,
        work: @escaping (String?) async -> Void
    ) {
        stateQueue.sync(flags: .barrier) {
            if let existingTask = self.activeTasks[taskId] {
                if skipIfAlreadyRunning {
                    onSkipped?()
                    return
                }
                // Cancelling the Swift Task only unblocks whatever it's synchronously
                // awaiting (irrelevant for a DartCallbackWorker, which awaits a method
                // channel round-trip, not a cancellable operation). The registry mark is
                // what a running DartWorker's isTaskCancelled() poll actually sees —
                // same two calls handleCancel makes for an explicit user cancel().
                existingTask.cancel()
                DartTaskCancellationRegistry.shared.markCancelled(taskId)
                self.workers[taskId]?.stop()
            }

            // 2026-09-24: if the caller already minted an executionId for the
            // INCOMING execution (dartExecutionId — handleEnqueue/handleResume
            // do this only when workerClassName == "DartCallbackWorker"),
            // register it as taskId's current execution in this SAME
            // barrier-protected block that just cancelled the outgoing one.
            // Closes a real, easily-reproduced gap (not the narrow race it
            // was originally scoped as): without this, there was a window
            // between "decided to run" and "executeDartWorkerViaMethodChannel
            // actually mints+registers its own id" — most commonly the task
            // sitting parked in ConcurrencyLimiter.acquire() once the default
            // 4 concurrent slots are full — where an explicit cancel(taskId)
            // landing in that gap would resolve against whichever execution
            // DartTaskCancellationRegistry knew about yet (the just-cancelled
            // outgoing one on a replace, or nothing at all on a first-time
            // enqueue — see markCancelled's taskId fallback), not this
            // incoming one. See lib_audit_5 in device_integration_test.dart
            // for the red-then-green repro (5 DartWorkers in flight, no
            // artificial delay needed).
            if let dartExecutionId {
                DartTaskCancellationRegistry.shared.beginExecution(dartExecutionId, taskId: taskId)
            }

            // See activeTaskGenerations' doc comment: this id is what lets the
            // Task below tell, once IT finishes, whether it is still the
            // current occupant of activeTasks[taskId] — a naturally-completing
            // task must remove its own entry so a later call doesn't mistake a
            // long-finished taskId for one still running.
            let generationId = UUID()
            let task = Task { [weak self] in
                // Unconditional and outside the `guard let self` / generation
                // checks below: whichever exit path `work` takes must still
                // drop this execution's registry entry, or it leaks (and
                // `currentExecutionId[taskId]` is left pointing at a dead id
                // forever). This matters because `work` CAN bail out WITHOUT
                // ever reaching executeDartWorkerViaMethodChannel's own
                // `defer { endExecution(...) }` — but NOT via
                // ConcurrencyLimiter.acquire(): a task parked there is NOT
                // cancellation-aware and DOES eventually proceed once a slot
                // frees (confirmed by lib_audit_5 — that's exactly why a
                // pre-minted id is needed there in the first place; see
                // executeDartWorkerViaMethodChannel's own comment). The real
                // bail-out paths this defer exists for are: handleEnqueue's
                // closure's `guard !Task.isCancelled` (checked once, after
                // the initialDelay `Task.sleep`, before `work` is ever
                // called), executeWorkerSync's per-attempt top-of-loop
                // `guard !Task.isCancelled`, and `self` being nil below.
                // endExecution is idempotent (guarded on
                // currentExecutionId[taskId] still pointing at this id), so
                // whichever of this defer or executeDartWorkerViaMethodChannel's
                // own defer runs first makes the other a no-op.
                defer {
                    if let dartExecutionId {
                        DartTaskCancellationRegistry.shared.endExecution(dartExecutionId, taskId: taskId)
                    }
                }
                guard let self else { return }
                defer {
                    self.stateQueue.sync(flags: .barrier) {
                        // Only clear if nothing has replaced us in the meantime —
                        // a call racing in after we started but before we finish
                        // must not have its brand-new entry wiped out by our own
                        // late cleanup.
                        guard self.activeTaskGenerations[taskId] == generationId else { return }
                        self.activeTasks.removeValue(forKey: taskId)
                        self.activeTaskGenerations.removeValue(forKey: taskId)
                    }
                }
                await work(dartExecutionId)
            }
            self.activeTasks[taskId] = task
            self.activeTaskGenerations[taskId] = generationId
        }
    }

    @available(iOS 13.0, *)
    internal func cleanupTempFiles(forTaskId taskId: String) {
        guard let registry = taskStore?.getRegistryByTaskId(taskId: taskId),
              let destPath = registry["destination_path"] as? String else { return }
        
        let fm = FileManager.default
        let tmpPath = destPath + ".tmp"
        let etagPath = destPath + ".tmp.etag"
        
        try? fm.removeItem(atPath: tmpPath)
        try? fm.removeItem(atPath: etagPath)
    }

    internal func stopAllWorkers() {
        stateQueue.sync(flags: .barrier) {
            for (taskId, task) in activeTasks {
                // Pre-existing gap, found during the 2026-09-23 lib/ audit: this
                // used to cancel the Swift Task without ever marking the
                // registry, so a DartWorker callback cooperatively polling
                // isTaskCancelled() during a real OS-triggered BGTask
                // expiration would never find out — the same information
                // handleCancel/cancelAll/cancelByTag already give an
                // explicitly-cancelled task.
                DartTaskCancellationRegistry.shared.markCancelled(taskId)
                task.cancel()
            }
            activeTasks.removeAll()
            activeTaskGenerations.removeAll() // see its doc comment
        }
        NativeLogger.w("⚠️ OS Expiration: Stopped all active workers")
    }

    private func handleGetTaskStatus(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any], let taskId = args["taskId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "taskId required", details: nil))
            return
        }
        result(stateQueue.sync { taskStates[taskId]?.rawValue })
    }

    private func handleGetTaskRecord(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any], let taskId = args["taskId"] as? String else {
            result(nil)
            return
        }
        
        workerQueue.async {
            let record = self.taskStore?.task(taskId: taskId)
            if let r = record {
                NativeLogger.d("handleGetTaskRecord: found task \(taskId), status \(r.status), hasResultData=\(r.resultData != nil)")
            } else {
                NativeLogger.d("handleGetTaskRecord: task \(taskId) not found")
            }
            DispatchQueue.main.async { result(record?.toFlutterMap()) }
        }
    }

    private func handleAllTasks(result: @escaping FlutterResult) {
        if #available(iOS 13.0, *) {
            workerQueue.async {
                let maps = self.taskStore?.allTasks().map { $0.toFlutterMap() } ?? []
                DispatchQueue.main.async { result(maps) }
            }
        } else { result([]) }
    }

    private func handleCancel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any], let taskId = args["taskId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "taskId required", details: nil))
            return
        }
        // Issue #66: activeTasks[taskId]?.cancel() below only unblocks whatever
        // Swift Task is awaiting — it does not reach the Dart isolate, so a
        // running DartWorker callback would otherwise never know it was
        // cancelled. Mark it here so NativeWorkManager.isTaskCancelled(taskId)
        // (polled cooperatively from inside the callback) can see it.
        DartTaskCancellationRegistry.shared.markCancelled(taskId)
        stateQueue.async(flags: .barrier) {
            self.activeTasks[taskId]?.cancel()
            self.activeTasks.removeValue(forKey: taskId)
            self.activeTaskGenerations.removeValue(forKey: taskId) // see its doc comment
            self.taskStates[taskId] = .cancelled
            self.workers[taskId]?.stop()
        }
        if #available(iOS 13.0, *) {
            BackgroundSessionManager.shared.cancel(taskId: taskId)
            cleanupTempFiles(forTaskId: taskId)
            taskStore?.updateStatus(taskId: taskId, status: "cancelled")
            BGTaskSchedulerManager.shared.cancelTask(taskId: taskId)
        }
        result(nil)
    }

    private func handleExtensionMethods(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "enqueueChain": handleEnqueueChain(call: call, result: result)
        case "enqueueGraph": handleEnqueueGraph(call: call, result: result)
        // Name must match what Dart invokes ('offlineQueueEnqueue') and what Android
        // registers. iOS spelled it "enqueueOfflineQueue" — the words the other way
        // round — so every offline-queue enqueue fell through to
        // FlutterMethodNotImplemented and threw MissingPluginException. The feature
        // has never worked on iOS. Guarded by channel_method_parity_test.dart.
        case "offlineQueueEnqueue": handleOfflineQueueEnqueue(call: call, result: result)
        case "registerRemoteTrigger": handleRegisterRemoteTrigger(call: call, result: result)
        case "registerMiddleware": handleRegisterMiddleware(call: call, result: result)
        default: result(FlutterMethodNotImplemented)
        }
    }
}

class SystemErrorStreamHandler: NSObject, FlutterStreamHandler {
    private weak var plugin: NativeWorkmanagerPlugin?
    init(plugin: NativeWorkmanagerPlugin) { self.plugin = plugin }
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.systemErrorSink = events
        return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.systemErrorSink = nil
        return nil
    }
}
