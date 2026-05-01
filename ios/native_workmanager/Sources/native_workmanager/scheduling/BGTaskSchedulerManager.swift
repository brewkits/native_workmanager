
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

    /// Stores pending tasks in an ordered list to ensure FIFO execution.
    /// FIX I1: Changed from Dictionary to Array to ensure stable order and
    /// allow filtering by type when popping.
    private var pendingTasks: [TaskInfo] = []
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
            // FIX I1: Append to array instead of dictionary to preserve order.
            // If task ID already exists, replace it (ExistingTaskPolicy.replace behavior).
            if let index = pendingTasks.firstIndex(where: { $0.taskId == taskId }) {
                pendingTasks[index] = taskInfo
            } else {
                pendingTasks.append(taskInfo)
            }
            savePendingTasks()
        }

        // Create request based on task type
        let request: BGTaskRequest

        if isHeavyTask {
            let processingRequest = BGProcessingTaskRequest(identifier: identifier)
            processingRequest.requiresNetworkConnectivity = requiresNetwork
            processingRequest.requiresExternalPower = requiresExternalPower
            request = processingRequest
            NativeLogger.d("BGTaskSchedulerManager: Using BGProcessingTask for heavy task with identifier '\(identifier)'")
        } else {
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
    func cancelTask(taskId: String) {
        queue.sync {
            // FIX I1: Remove from array by ID.
            pendingTasks.removeAll(where: { $0.taskId == taskId })
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

        // FIX I2: Filter by isHeavyTask = true when popping for processing handler.
        guard let taskInfo = popNextPendingTask(isHeavy: true) else {
            NativeLogger.d("BGTaskSchedulerManager: No pending processing tasks")
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

        // FIX I2: Filter by isHeavyTask = false when popping for refresh handler.
        guard let taskInfo = popNextPendingTask(isHeavy: false) else {
            NativeLogger.d("BGTaskSchedulerManager: No pending refresh tasks")
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
    private func executeWorker(taskInfo: TaskInfo) async -> Bool {
        NativeLogger.d("BGTaskSchedulerManager: Executing worker '\(taskInfo.workerClassName)' for task '\(taskInfo.taskId)'")

        guard let worker = IosWorkerFactory.createWorker(className: taskInfo.workerClassName) else {
            NativeLogger.e("BGTaskSchedulerManager: unknown worker class '\(taskInfo.workerClassName)'")
            return false
        }
        activeWorker = worker

        do {
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
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("pending_tasks_v2.json")
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
            pendingTasks = try JSONDecoder().decode([TaskInfo].self, from: data)
            NativeLogger.d("BGTaskSchedulerManager: Loaded \(pendingTasks.count) pending tasks")
        } catch {
            NativeLogger.e("BGTaskSchedulerManager: failed to load pending tasks")
        }
    }

    /// Atomically pops the next pending task matching the required type.
    ///
    /// FIX I1: Preserves FIFO by picking the first task in the array.
    /// FIX I2: Filters by [isHeavy] to ensure tasks run in the correct BGTask slot.
    private func popNextPendingTask(isHeavy: Bool) -> TaskInfo? {
        return queue.sync {
            if !pendingTasksLoaded {
                loadPendingTasks()
                pendingTasksLoaded = true
            }
            guard let index = pendingTasks.firstIndex(where: { $0.isHeavyTask == isHeavy }) else {
                return nil
            }
            let taskInfo = pendingTasks.remove(at: index)
            savePendingTasks()
            return taskInfo
        }
    }

    // MARK: - Testing Support

    #if DEBUG
    func simulateTaskExecution(identifier: String = defaultTaskIdentifier) {
        NativeLogger.d("BGTaskSchedulerManager: Simulating task execution for '\(identifier)'")
    }
    #endif
}
