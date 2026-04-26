

import Foundation
import KMPWorkManager
import BackgroundTasks

/// Manager for iOS background task scheduling using BGTaskScheduler.
///
/// Handles registration, scheduling, and execution of background tasks
/// on iOS 13+.
///
/// **Usage:**
/// 1. Add task identifiers to Info.plist:
///    ```xml
///    <key>BGTaskSchedulerPermittedIdentifiers</key>
///    <array>
///        <string>dev.brewkits.native_workmanager.task</string>
///        <string>dev.brewkits.native_workmanager.refresh</string>
///    </array>
///    ```
///
/// 2. Register handlers in AppDelegate:
///    ```swift
///    BGTaskSchedulerManager.shared.registerHandlers()
///    ```
///
/// 3. Schedule tasks:
///    ```swift
///    BGTaskSchedulerManager.shared.scheduleTask(
///        identifier: "dev.brewkits.native_workmanager.task",
///        taskId: "my-task",
///        workerClassName: "HttpRequestWorker",
///        workerConfig: [...]
///    )
///    ```
@available(iOS 13.0, *)
class BGTaskSchedulerManager {

    // MARK: - Singleton

    static let shared = BGTaskSchedulerManager()

    private init() {}

    // MARK: - Constants

    /// Default task identifier for background processing
    static let defaultTaskIdentifier = "dev.brewkits.native_workmanager.task"

    /// Task identifier for app refresh
    static let refreshTaskIdentifier = "dev.brewkits.native_workmanager.refresh"

    // MARK: - Properties

    /// Callback for task completion events
    var onTaskComplete: ((String, Bool, String?) -> Void)?

    /// Callback when a background task handler is invoked by the OS.
    /// Used to trigger resumePendingChains/Graphs in the main plugin.
    var onTaskStart: (() -> Void)?

    /// Callback for task execution. If provided, overrides internal simple execution.
    /// This allows the main plugin to apply middleware and observability.
    var taskExecutor: ((TaskInfo) async -> Any)?

    /// Callback when a background task expires before completing.
    /// Used to call stopAllWorkers() in the main plugin.
    var onExpiration: (() -> Void)?

    /// Fired when a Task begins executing so the plugin can track it in activeTasks
    /// for cooperative cancellation via NativeWorkManager.cancel(taskId).
    var onTaskRunning: ((String, Task<Void, Never>) -> Void)?

    /// Stores the currently running worker to handle stop/expiration.
    private var activeWorker: IosWorker?

    /// Stores pending tasks (taskId -> task info)
    private var pendingTasks: [String: TaskInfo] = [:]
    private let queue = DispatchQueue(label: "dev.brewkits.bgtask_manager")

    /// Guards a single disk-load on first access (cold-start BGTask invocation).
    private var pendingTasksLoaded = false

    // MARK: - Task Info

    struct TaskInfo: Codable {
        let taskId: String
        let workerClassName: String
        let workerConfig: [String: AnyCodable]
        let requiresNetwork: Bool
        let requiresExternalPower: Bool
        let isHeavyTask: Bool
        let qos: String

        enum CodingKeys: String, CodingKey {
            case taskId, workerClassName, workerConfig
            case requiresNetwork, requiresExternalPower
            case isHeavyTask, qos
        }
    }

    // MARK: - Registration

    /// Register background task handlers.
    ///
    /// Call this in AppDelegate's `application(_:didFinishLaunchingWithOptions:)`
    /// BEFORE the app finishes launching.
    func registerHandlers() {
        // Register processing task handler
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BGTaskSchedulerManager.defaultTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundTask(task as! BGProcessingTask)
        }

        // Register refresh task handler
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BGTaskSchedulerManager.refreshTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleAppRefreshTask(task as! BGAppRefreshTask)
        }

        NativeLogger.d("BGTaskSchedulerManager: Handlers registered")
    }

    // MARK: - Scheduling

    /// Schedule a background task.
    ///
    /// - Parameters:
    ///   - identifier: BGTaskScheduler identifier (must be in Info.plist)
    ///   - taskId: Unique task ID
    ///   - workerClassName: Name of worker class to execute
    ///   - workerConfig: Configuration for the worker
    ///   - earliestBeginDate: Earliest time to run (default: now)
    ///   - requiresNetwork: Whether task needs network (default: false)
    ///   - requiresExternalPower: Whether task needs charging (default: false)
    ///   - isHeavyTask: Use BGProcessingTask (60s) instead of BGAppRefreshTask (30s)
    ///   - qos: Quality of Service for task execution (default: background)
    /// - Returns: true if scheduled successfully
    @discardableResult
    func scheduleTask(
        identifier: String = defaultTaskIdentifier,
        taskId: String,
        workerClassName: String,
        workerConfig: [String: Any],
        earliestBeginDate: Date = Date(),
        requiresNetwork: Bool = false,
        requiresExternalPower: Bool = false,
        isHeavyTask: Bool = false,
        qos: String = "background"
    ) -> Bool {
        // Store task info
        let taskInfo = TaskInfo(
            taskId: taskId,
            workerClassName: workerClassName,
            workerConfig: workerConfig.mapValues { AnyCodable($0) },
            requiresNetwork: requiresNetwork,
            requiresExternalPower: requiresExternalPower,
            isHeavyTask: isHeavyTask,
            qos: qos
        )

        queue.sync {
            pendingTasks[taskId] = taskInfo
            savePendingTasks()
        }

        // Create request based on task type
        let request: BGTaskRequest

        if isHeavyTask {
            // Heavy task: Use BGProcessingTask (60s limit, supports network/power constraints)
            // Use the provided identifier (must be registered in Info.plist)
            let processingRequest = BGProcessingTaskRequest(identifier: identifier)
            processingRequest.requiresNetworkConnectivity = requiresNetwork
            processingRequest.requiresExternalPower = requiresExternalPower
            request = processingRequest
            NativeLogger.d("BGTaskSchedulerManager: Using BGProcessingTask for heavy task with identifier '\(identifier)'")
        } else {
            // Normal task: Use BGAppRefreshTask (30s limit, no network/power constraints).
            // Use the provided identifier — the caller is responsible for registering it
            // in Info.plist as a BGAppRefreshTask identifier. Silently substituting
            // refreshTaskIdentifier here meant that tasks scheduled with a custom
            // identifier would silently execute under a different BGTask slot, making
            // per-task scheduling impossible.
            request = BGAppRefreshTaskRequest(identifier: identifier)
            NativeLogger.d("BGTaskSchedulerManager: Using BGAppRefreshTask with identifier '\(identifier)'")
        }

        request.earliestBeginDate = earliestBeginDate

        // Submit request
        do {
            try BGTaskScheduler.shared.submit(request)
            NativeLogger.d("BGTaskSchedulerManager: Scheduled task '\(taskId)' with identifier '\(identifier)'")
            return true
        } catch {
            NativeLogger.e("BGTaskSchedulerManager: failed to schedule task")
            return false
        }
    }

    /// Cancel a scheduled task.
    ///
    /// - Note: `BGTaskScheduler` has no API to cancel individual task requests by identifier —
    ///   only `cancelAllTaskRequests()` exists at the OS level. Removing the task from
    ///   `pendingTasks` here is sufficient: if the OS still fires the BGTask, the execution
    ///   handler will find no pending entry and return early without running the worker.
    ///   Callers should be aware that one additional OS-level fire may occur after this call.
    func cancelTask(taskId: String) {
        queue.sync {
            pendingTasks.removeValue(forKey: taskId)
            savePendingTasks()
        }
        NativeLogger.d("BGTaskSchedulerManager: Cancelled task '\(taskId)' (OS-level request may still fire once)")
    }

    /// Cancel all scheduled tasks.
    func cancelAllTasks() {
        queue.sync {
            pendingTasks.removeAll()
            savePendingTasks()
        }

        BGTaskScheduler.shared.cancelAllTaskRequests()
        NativeLogger.d("BGTaskSchedulerManager: Cancelled all tasks")
    }

    // MARK: - Task Execution

    /// Ensures `bgTask.setTaskCompleted` is called exactly once per BGTask instance.
    ///
    /// The singleton-level flag approach breaks when iOS fires two BGTasks concurrently:
    /// Task A resets the flag, Task B could see Task A's flag state. Per-instance guard
    /// binds completion lifetime to the BGTask itself.
    private final class TaskCompletionGuard {
        private var fired = false
        private let lock = NSLock()
        func completeOnce(task: BGTask, success: Bool) {
            lock.lock()
            defer { lock.unlock() }
            guard !fired else { return }
            fired = true
            task.setTaskCompleted(success: success)
        }
    }

    /// Handle BGProcessingTask execution.
    private func handleBackgroundTask(_ task: BGProcessingTask) {
        NativeLogger.d("BGTaskSchedulerManager: Processing task started")
        let completionGuard = TaskCompletionGuard()
        onTaskStart?()

        guard let taskInfo = popNextPendingTask() else {
            NativeLogger.d("BGTaskSchedulerManager: No pending tasks")
            completionGuard.completeOnce(task: task, success: true)
            return
        }

        task.expirationHandler = { [weak self] in
            NativeLogger.d("BGTaskSchedulerManager: Task expired")
            self?.activeWorker?.stop()
            self?.onExpiration?()
            self?.onTaskComplete?(taskInfo.taskId, false, "Task expired")
            completionGuard.completeOnce(task: task, success: false)
        }

        let runningTask = Task(priority: .background) { [weak self] in
            guard let self = self else { return }
            let success = await self.runExecutor(taskInfo: taskInfo)
            completionGuard.completeOnce(task: task, success: success)
            self.activeWorker = nil
        }
        onTaskRunning?(taskInfo.taskId, runningTask)
    }

    /// Handle BGAppRefreshTask execution.
    private func handleAppRefreshTask(_ task: BGAppRefreshTask) {
        NativeLogger.d("BGTaskSchedulerManager: App refresh task started")
        let completionGuard = TaskCompletionGuard()
        onTaskStart?()

        guard let taskInfo = popNextPendingTask() else {
            completionGuard.completeOnce(task: task, success: true)
            return
        }

        task.expirationHandler = { [weak self] in
            NativeLogger.d("BGTaskSchedulerManager: Refresh task expired")
            self?.activeWorker?.stop()
            self?.onExpiration?()
            self?.onTaskComplete?(taskInfo.taskId, false, "Refresh expired")
            completionGuard.completeOnce(task: task, success: false)
        }

        let runningTask = Task(priority: .background) { [weak self] in
            guard let self = self else { return }
            let success = await self.runExecutor(taskInfo: taskInfo)
            completionGuard.completeOnce(task: task, success: success)
            self.activeWorker = nil
        }
        onTaskRunning?(taskInfo.taskId, runningTask)
    }

    /// Shared execution path for both BGProcessingTask and BGAppRefreshTask.
    private func runExecutor(taskInfo: TaskInfo) async -> Bool {
        if let executor = taskExecutor {
            let result = await executor(taskInfo)
            if let workerResult = result as? WorkerResult { return workerResult.success }
            if let boolResult = result as? Bool { return boolResult }
            return true
        } else {
            let success = await executeWorker(taskInfo: taskInfo)
            onTaskComplete?(taskInfo.taskId, success, success ? nil : "Worker execution failed")
            return success
        }
    }

    /// Execute a worker with the given task info.
    ///
    /// Uses native Swift Concurrency throughout — no DispatchQueue wrapping needed.
    /// Task(priority:) in the caller already sets the execution context; wrapping in
    /// DispatchQueue.global().async { Task { } } would create an orphaned child Task that
    /// doesn't inherit cancellation from its parent, wasting a thread in the process.
    private func executeWorker(taskInfo: TaskInfo) async -> Bool {
        NativeLogger.d("BGTaskSchedulerManager: Executing worker '\(taskInfo.workerClassName)' for task '\(taskInfo.taskId)'")

        guard let worker = IosWorkerFactory.createWorker(className: taskInfo.workerClassName) else {
            NativeLogger.e("BGTaskSchedulerManager: unknown worker class '\(taskInfo.workerClassName)'")
            return false
        }
        activeWorker = worker

        do {
            // Custom workers (via NativeWorker.custom) store user data under the "input" key
            // as a pre-encoded JSON string. Built-in workers receive the full config.
            let inputForWorker: String?
            if let inputAnyCodable = taskInfo.workerConfig["input"],
               let inputString = inputAnyCodable.value as? String {
                inputForWorker = inputString
            } else {
                let configData = try JSONEncoder().encode(taskInfo.workerConfig)
                inputForWorker = String(data: configData, encoding: .utf8)
            }

            let result = try await worker.doWork(
                input: inputForWorker,
                env: WorkerEnvironment(progressListener: nil, isCancelled: { KotlinBoolean(bool: false) })
            )
            NativeLogger.d("BGTaskSchedulerManager: Worker \(result.success ? "succeeded" : "failed")")
            return result.success
        } catch {
            NativeLogger.e("BGTaskSchedulerManager: worker execution error — \(error)")
            return false
        }
    }

    // MARK: - Persistence

    private var storageURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("pending_tasks.json")
    }

    private func savePendingTasks() {
        do {
            let data = try JSONEncoder().encode(pendingTasks)
            try data.write(to: storageURL)
        } catch {
            NativeLogger.e("BGTaskSchedulerManager: failed to save pending tasks")
        }
    }

    private func loadPendingTasks() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            pendingTasks = try JSONDecoder().decode([String: TaskInfo].self, from: data)
            NativeLogger.d("BGTaskSchedulerManager: Loaded \(pendingTasks.count) pending tasks")
        } catch {
            NativeLogger.e("BGTaskSchedulerManager: failed to load pending tasks")
        }
    }

    /// Atomically pops the next pending task.
    ///
    /// On cold-start BGTask invocations `pendingTasks` is empty (no prior `scheduleTask` call
    /// in this process). Load from disk once, then pop — guarantees no two concurrent
    /// BGTask handlers can dequeue the same task, preventing duplicate execution and
    /// starvation of other queued tasks.
    private func popNextPendingTask() -> TaskInfo? {
        return queue.sync {
            if !pendingTasksLoaded {
                loadPendingTasks()
                pendingTasksLoaded = true
            }
            guard let key = pendingTasks.keys.first else { return nil }
            let taskInfo = pendingTasks.removeValue(forKey: key)
            if taskInfo != nil { savePendingTasks() }
            return taskInfo
        }
    }

    // MARK: - Testing Support

    #if DEBUG
    /// Simulate background task execution (for testing in simulator).
    ///
    /// Usage in terminal:
    /// ```bash
    /// e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"dev.brewkits.native_workmanager.task"]
    /// ```
    func simulateTaskExecution(identifier: String = defaultTaskIdentifier) {
        NativeLogger.d("BGTaskSchedulerManager: Simulating task execution for '\(identifier)'")
        // This is called via debugger commands
    }
    #endif
}
