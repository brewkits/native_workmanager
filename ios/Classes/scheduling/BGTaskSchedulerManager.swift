import Foundation
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

    /// Stores pending tasks (taskId -> task info)
    private var pendingTasks: [String: TaskInfo] = [:]
    private let queue = DispatchQueue(label: "dev.brewkits.bgtask_manager")

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

        print("BGTaskSchedulerManager: Handlers registered")
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
            let processingRequest = BGProcessingTaskRequest(identifier: BGTaskSchedulerManager.defaultTaskIdentifier)
            processingRequest.requiresNetworkConnectivity = requiresNetwork
            processingRequest.requiresExternalPower = requiresExternalPower
            request = processingRequest
            print("BGTaskSchedulerManager: Using BGProcessingTask for heavy task")
        } else {
            // Normal task: Use BGAppRefreshTask (30s limit, no constraints support)
            request = BGAppRefreshTaskRequest(identifier: BGTaskSchedulerManager.refreshTaskIdentifier)
            print("BGTaskSchedulerManager: Using BGAppRefreshTask for normal task")
        }

        request.earliestBeginDate = earliestBeginDate

        // Submit request
        do {
            try BGTaskScheduler.shared.submit(request)
            print("BGTaskSchedulerManager: Scheduled task '\(taskId)' with identifier '\(identifier)'")
            return true
        } catch {
            print("BGTaskSchedulerManager: Failed to schedule task: \(error)")
            return false
        }
    }

    /// Cancel a scheduled task.
    func cancelTask(taskId: String) {
        queue.sync {
            pendingTasks.removeValue(forKey: taskId)
            savePendingTasks()
        }

        // Note: BGTaskScheduler doesn't support canceling individual tasks
        // We can only cancel all tasks or let them expire
        print("BGTaskSchedulerManager: Cancelled task '\(taskId)'")
    }

    /// Cancel all scheduled tasks.
    func cancelAllTasks() {
        queue.sync {
            pendingTasks.removeAll()
            savePendingTasks()
        }

        BGTaskScheduler.shared.cancelAllTaskRequests()
        print("BGTaskSchedulerManager: Cancelled all tasks")
    }

    // MARK: - Task Execution

    /// Handle BGProcessingTask execution.
    private func handleBackgroundTask(_ task: BGProcessingTask) {
        print("BGTaskSchedulerManager: Processing task started")

        // Get task info from storage
        guard let taskInfo = loadNextPendingTask() else {
            print("BGTaskSchedulerManager: No pending tasks")
            task.setTaskCompleted(success: true)
            return
        }

        // Setup expiration handler
        // ✅ FIX: Use [weak self] to prevent retain cycle
        task.expirationHandler = { [weak self] in
            print("BGTaskSchedulerManager: Task expired")
            self?.onTaskComplete?(taskInfo.taskId, false, "Task expired")
        }

        // Execute worker
        Task {
            let success = await self.executeWorker(taskInfo: taskInfo)

            // Mark task complete
            task.setTaskCompleted(success: success)

            // Notify completion
            self.onTaskComplete?(
                taskInfo.taskId,
                success,
                success ? nil : "Worker execution failed"
            )

            // Reschedule if periodic
            // (In real implementation, check if task is periodic)
            // self.scheduleNextExecution(taskInfo)
        }
    }

    /// Handle BGAppRefreshTask execution.
    private func handleAppRefreshTask(_ task: BGAppRefreshTask) {
        print("BGTaskSchedulerManager: App refresh task started")

        // Similar to handleBackgroundTask but with stricter time limit (~30s)
        guard let taskInfo = loadNextPendingTask() else {
            task.setTaskCompleted(success: true)
            return
        }

        // ✅ FIX: Use [weak self] to prevent retain cycle
        task.expirationHandler = { [weak self] in
            print("BGTaskSchedulerManager: Refresh task expired")
            self?.onTaskComplete?(taskInfo.taskId, false, "Refresh expired")
        }

        Task {
            let success = await self.executeWorker(taskInfo: taskInfo)
            task.setTaskCompleted(success: success)
            self.onTaskComplete?(taskInfo.taskId, success, nil)
        }
    }

    /// Execute a worker with the given task info.
    private func executeWorker(taskInfo: TaskInfo) async -> Bool {
        print("BGTaskSchedulerManager: Executing worker '\(taskInfo.workerClassName)' for task '\(taskInfo.taskId)' with QoS: \(taskInfo.qos)")

        // Map QoS string to DispatchQoS
        let qos = mapQoS(taskInfo.qos)

        // Execute worker with specified QoS
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: qos).async {
                Task {
                    // Convert config to JSON string
                    guard let worker = IosWorkerFactory.createWorker(className: taskInfo.workerClassName) else {
                        print("BGTaskSchedulerManager: Unknown worker class: \(taskInfo.workerClassName)")
                        continuation.resume(returning: false)
                        return
                    }

                    do {
                        let configData = try JSONEncoder().encode(taskInfo.workerConfig)
                        let configJson = String(data: configData, encoding: .utf8)

                        let result = try await worker.doWork(input: configJson)
                        print("BGTaskSchedulerManager: Worker execution \(result.success ? "succeeded" : "failed")")

                        // Remove from pending tasks on success
                        if result.success {
                            self.queue.sync {
                                self.pendingTasks.removeValue(forKey: taskInfo.taskId)
                                self.savePendingTasks()
                            }
                        }

                        continuation.resume(returning: result.success)
                    } catch {
                        print("BGTaskSchedulerManager: Worker execution error: \(error)")
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    /// Map QoS string to DispatchQoS.QoSClass
    private func mapQoS(_ qosString: String) -> DispatchQoS.QoSClass {
        switch qosString.lowercased() {
        case "utility":
            return .utility
        case "background":
            return .background
        case "userinitiated":
            return .userInitiated
        case "userinteractive":
            return .userInteractive
        default:
            return .background
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
            print("BGTaskSchedulerManager: Failed to save pending tasks: \(error)")
        }
    }

    private func loadPendingTasks() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            pendingTasks = try JSONDecoder().decode([String: TaskInfo].self, from: data)
            print("BGTaskSchedulerManager: Loaded \(pendingTasks.count) pending tasks")
        } catch {
            print("BGTaskSchedulerManager: Failed to load pending tasks: \(error)")
        }
    }

    private func loadNextPendingTask() -> TaskInfo? {
        return queue.sync {
            loadPendingTasks()
            return pendingTasks.values.first
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
        print("BGTaskSchedulerManager: Simulating task execution for '\(identifier)'")
        // This is called via debugger commands
    }
    #endif
}
