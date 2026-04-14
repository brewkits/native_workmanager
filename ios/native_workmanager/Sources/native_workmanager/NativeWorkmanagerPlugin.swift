import Flutter
import UIKit
import UserNotifications

public class NativeWorkmanagerPlugin: NSObject, FlutterPlugin {

    var methodChannel: FlutterMethodChannel?
    var eventChannel: FlutterEventChannel?
    var progressChannel: FlutterEventChannel?

    var eventSink: FlutterEventSink?
    var progressSink: FlutterEventSink?

    static let methodChannelName = "dev.brewkits/native_workmanager"
    static let eventChannelName = "dev.brewkits/native_workmanager/events"
    static let progressChannelName = "dev.brewkits/native_workmanager/progress"

    let workerQueue = DispatchQueue(label: "dev.brewkits.native_workmanager.worker", qos: .utility)

    // Tag storage for fast lookup
    var taskTags: [String: String] = [:]
    var taskStates: [String: String] = [:]
    let stateQueue = DispatchQueue(label: "dev.brewkits.native_workmanager.state", attributes: .concurrent)

    var debugMode = false
    var taskStartTimes: [String: Date] = [:]
    var activeTasks: [String: Task<Void, Never>] = [:]
    var workers: [String: IosWorker] = [:]

    lazy var chainStateManager: ChainStateManager = {
        let sqlite = SQLiteStore(name: "native_workmanager_chains")
        let store = ChainStore(sqlite: sqlite)
        return ChainStateManager(chainStore: store)
    }()

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
        let messenger = registrar.messenger()
        
        instance.methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel!)

        instance.eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
        instance.eventChannel?.setStreamHandler(instance)

        instance.progressChannel = FlutterEventChannel(name: progressChannelName, binaryMessenger: messenger)
        instance.progressChannel?.setStreamHandler(ProgressStreamHandler(plugin: instance))

        KMPBridge.shared.initialize()

        if #available(iOS 13.0, *) {
            BGTaskSchedulerManager.shared.registerHandlers()
            BGTaskSchedulerManager.shared.onTaskComplete = { [weak instance] taskId, success, message in
                instance?.emitTaskEvent(taskId: taskId, success: success, message: message)
            }
            BGTaskSchedulerManager.shared.onTaskStart = { [weak instance] in
                Task { await instance?.resumePendingChains(); instance?.resumePendingGraphs() }
            }
            BGTaskSchedulerManager.shared.onExpiration = { [weak instance] in
                instance?.stopAllWorkers()
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

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        NSLog("[NativeWorkManager] handle: \(call.method)")
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
        default: handleExtensionMethods(call: call, result: result)
        }
    }

    private func handleInitialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let args = call.arguments as? [String: Any] {
            if let callbackHandle = args["callbackHandle"] as? Int64 {
                FlutterEngineManager.shared.setCallbackHandle(callbackHandle)
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
        NSLog("[NativeWorkManager] handleEnqueue called")
        guard let args = call.arguments as? [String: Any],
              let taskId = args["taskId"] as? String,
              let workerClassName = args["workerClassName"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing args", details: nil))
            return
        }

        let tag = args["tag"] as? String
        stateQueue.sync(flags: .barrier) {
            self.taskStates[taskId] = "pending"
            if let t = tag { self.taskTags[taskId] = t }
        }

        if #available(iOS 13.0, *) {
            let configRaw = args["workerConfig"] as? [String: Any]
            let configJson = configRaw.flatMap { try? JSONSerialization.data(withJSONObject: $0) }.flatMap { String(data: $0, encoding: .utf8) }
            taskStore?.upsert(taskId: taskId, tag: tag, status: "pending", workerClassName: workerClassName, workerConfig: configJson)
        }

        let workerConfig = args["workerConfig"] as? [String: Any] ?? [:]
        let triggerMap = args["trigger"] as? [String: Any]
        let initialDelayMs = (triggerMap?["initialDelayMs"] as? Int) ?? 0

        // Create the Swift Task first so cancel() can find it in activeTasks
        // immediately after result("ACCEPTED") returns to Dart.
        let task = Task { [weak self] in
            guard let self else { return }
            if initialDelayMs > 0 {
                try? await Task.sleep(nanoseconds: UInt64(initialDelayMs) * 1_000_000)
            }
            guard !Task.isCancelled else { return }
            await self.executeWorkerSync(taskId: taskId, workerClassName: workerClassName, workerConfig: workerConfig, qos: "background")
        }
        stateQueue.sync(flags: .barrier) { self.activeTasks[taskId] = task }

        result("ACCEPTED")
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
            for (_, task) in activeTasks {
                task.cancel()
            }
            activeTasks.removeAll()
            // Also notify workers directly if possible
            for (_, worker) in workers {
                // Future: add stop() method to IosWorker if needed
            }
        }
        NativeLogger.w("⚠️ OS Expiration: Stopped all active workers")
    }

    private func handleGetTaskStatus(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any], let taskId = args["taskId"] as? String else { return }
        result(stateQueue.sync { taskStates[taskId] })
    }

    private func handleGetTaskRecord(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any], let taskId = args["taskId"] as? String else {
            result(nil)
            return
        }
        
        workerQueue.async {
            let record = self.taskStore?.task(taskId: taskId)
            if let r = record {
                NSLog("[NativeWorkManager] handleGetTaskRecord: found task \(taskId), status \(r.status), hasResultData=\(r.resultData != nil)")
            } else {
                NSLog("[NativeWorkManager] handleGetTaskRecord: task \(taskId) not found")
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
        guard let args = call.arguments as? [String: Any], let taskId = args["taskId"] as? String else { return }
        stateQueue.async(flags: .barrier) {
            self.activeTasks[taskId]?.cancel()
            self.activeTasks.removeValue(forKey: taskId)
            self.taskStates[taskId] = "cancelled"
        }
        if #available(iOS 13.0, *) {
            cleanupTempFiles(forTaskId: taskId)
            taskStore?.updateStatus(taskId: taskId, status: "cancelled")
        }
        result(nil)
    }

    private func handleExtensionMethods(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "enqueueChain": handleEnqueueChain(call: call, result: result)
        case "enqueueGraph": handleEnqueueGraph(call: call, result: result)
        case "enqueueOfflineQueue": handleOfflineQueueEnqueue(call: call, result: result)
        case "registerRemoteTrigger": handleRegisterRemoteTrigger(call: call, result: result)
        case "registerMiddleware": handleRegisterMiddleware(call: call, result: result)
        default: result(FlutterMethodNotImplemented)
        }
    }
}
