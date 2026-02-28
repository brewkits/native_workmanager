package dev.brewkits.native_workmanager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkInfo
import androidx.work.WorkManager
import dev.brewkits.kmpworkmanager.background.data.KmpHeavyWorker
import dev.brewkits.kmpworkmanager.background.data.KmpWorker
import dev.brewkits.kmpworkmanager.background.domain.*
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import dev.brewkits.native_workmanager.engine.FlutterEngineManager
import dev.brewkits.kmpworkmanager.background.data.NativeTaskScheduler
import dev.brewkits.native_workmanager.workers.utils.ProgressReporter
import dev.brewkits.kmpworkmanager.kmpWorkerModule
import dev.brewkits.kmpworkmanager.KmpWorkManagerConfig
import dev.brewkits.kmpworkmanager.KmpWorkManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.takeWhile
import kotlinx.coroutines.launch
import org.koin.android.ext.koin.androidContext
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject
import org.koin.core.context.GlobalContext
import org.koin.core.context.startKoin

/**
 * Native WorkManager Flutter Plugin for Android.
 *
 * Uses kmpworkmanager v2.3.3 from Maven Central as the core engine.
 * This ensures compatibility with Pro/Enterprise versions.
 */
class NativeWorkmanagerPlugin : FlutterPlugin, MethodCallHandler, KoinComponent {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var progressChannel: EventChannel
    private lateinit var context: Context

    private var eventSink: EventChannel.EventSink? = null
    private var progressSink: EventChannel.EventSink? = null
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    // Track subscription jobs so old ones are cancelled on re-subscribe
    private var eventJob: Job? = null
    private var progressJob: Job? = null

    // Inject BackgroundTaskScheduler from kmpworkmanager via Koin
    private val scheduler: BackgroundTaskScheduler by inject()
    // TaskEventBus is an object singleton, accessed directly (not via Koin)

    // Tag storage: taskId -> tag mapping (ConcurrentHashMap for thread safety across coroutines)
    private val taskTags = ConcurrentHashMap<String, String>()

    // Task status tracking: taskId -> status string (ConcurrentHashMap for thread safety)
    private val taskStatuses = ConcurrentHashMap<String, String>()

    // Debug mode flag
    private var debugMode = false

    // Task start times for debug mode (ConcurrentHashMap for thread safety)
    private val taskStartTimes = ConcurrentHashMap<String, Long>()

    companion object {
        private const val TAG = "NativeWorkmanagerPlugin"
        private const val METHOD_CHANNEL = "dev.brewkits/native_workmanager"
        private const val EVENT_CHANNEL = "dev.brewkits/native_workmanager/events"
        private const val PROGRESS_CHANNEL = "dev.brewkits/native_workmanager/progress"
        private const val DEBUG_NOTIFICATION_CHANNEL_ID = "native_workmanager_debug"
        private const val DEBUG_NOTIFICATION_CHANNEL_NAME = "Background Task Debug"
        private var isKoinInitialized = false
        private val TERMINAL_STATES = setOf(
            WorkInfo.State.SUCCEEDED,
            WorkInfo.State.FAILED,
            WorkInfo.State.CANCELLED
        )
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        // Initialize Koin with kmpworkmanager
        initializeKoin(context)

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                subscribeToTaskEvents()
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        progressChannel = EventChannel(binding.binaryMessenger, PROGRESS_CHANNEL)
        progressChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                progressSink = events
                subscribeToProgressUpdates()
            }
            override fun onCancel(arguments: Any?) {
                progressSink = null
            }
        })
    }

    private fun initializeKoin(context: Context) {
        if (isKoinInitialized) return

        try {
            // ✅ Create a single factory instance shared between KmpWorkManager and Koin module
            val workerFactory = SimpleAndroidWorkerFactory(context)
            val config = KmpWorkManagerConfig()

            // ✅ Initialize KmpWorkManager BEFORE setting up Koin modules
            // This fixes "KmpWorkManager not initialized!" error when workers execute
            KmpWorkManager.initialize(
                context = context,
                workerFactory = workerFactory,
                config = config
            )

            // ✅ Reuse the same factory instance for the Koin module
            val kmpModule = kmpWorkerModule(workerFactory, config)

            if (GlobalContext.getOrNull() == null) {
                startKoin {
                    androidContext(context)
                    modules(kmpModule)
                }
            } else {
                GlobalContext.get().loadModules(listOf(kmpModule))
            }
            isKoinInitialized = true
            Log.d(TAG, "✅ Koin initialized with kmpworkmanager v2.3.3 from Maven Central")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to initialize Koin", e)
        }
    }

    private fun subscribeToProgressUpdates() {
        progressJob?.cancel()
        progressJob = scope.launch {
            try {
                ProgressReporter.progressFlow.collect { update ->
                    progressSink?.success(update.toMap())
                }
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e  // Re-throw so coroutine cancellation propagates normally
            } catch (e: Exception) {
                Log.e(TAG, "Error in progress subscription", e)
            }
        }
    }

    private fun subscribeToTaskEvents() {
        eventJob?.cancel()
        eventJob = scope.launch {
            try {
                // Access TaskEventBus object singleton directly (v2.3.1+ with outputData support)
                TaskEventBus.events.collect { event ->
                    // Show debug notification if enabled
                    if (debugMode && isDebugBuild()) {
                        try {
                            val taskId = event.taskName
                            val startTime = taskStartTimes[taskId]
                            val executionTime = if (startTime != null) {
                                "${System.currentTimeMillis() - startTime}ms"
                            } else {
                                "N/A"
                            }

                            // Remove from tracking if task completed
                            if (event.success || !event.message.isNullOrEmpty()) {
                                taskStartTimes.remove(taskId)
                            }

                            val title = if (event.success) {
                                "✅ Task Completed: $taskId"
                            } else {
                                "❌ Task Failed: $taskId"
                            }

                            val text = buildString {
                                append("Execution time: $executionTime")
                                if (!event.message.isNullOrEmpty()) {
                                    append("\n${event.message}")
                                }
                            }

                            val notification = NotificationCompat.Builder(context, DEBUG_NOTIFICATION_CHANNEL_ID)
                                .setSmallIcon(android.R.drawable.ic_dialog_info)
                                .setContentTitle(title)
                                .setContentText(text)
                                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                                .setAutoCancel(true)
                                .setTimeoutAfter(5000) // Auto-dismiss after 5 seconds
                                .build()

                            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            notificationManager.notify(taskId.hashCode(), notification)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error showing debug notification", e)
                        }
                    }

                    // Update in-memory status
                    taskStatuses[event.taskName] = if (event.success) "completed" else "failed"

                    // Always emit event to Dart (v2.3.1+: includes outputData)
                    eventSink?.success(mapOf(
                        "taskId" to event.taskName,  // Map taskName to taskId for Dart compatibility
                        "success" to event.success,
                        "message" to event.message,
                        "resultData" to event.outputData,  // ✅ Pass result data from worker
                        "timestamp" to System.currentTimeMillis()
                    ))
                }
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e  // Re-throw so coroutine cancellation propagates normally
            } catch (e: Exception) {
                Log.e(TAG, "Error in event subscription", e)
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> handleInitialize(call, result)
            "enqueue" -> handleEnqueue(call, result)
            "cancel" -> handleCancel(call, result)
            "cancelAll" -> handleCancelAll(result)
            "cancelByTag" -> handleCancelByTag(call, result)
            "getTasksByTag" -> handleGetTasksByTag(call, result)
            "getAllTags" -> handleGetAllTags(result)
            "enqueueChain" -> handleEnqueueChain(call, result)
            "getTaskStatus" -> handleGetTaskStatus(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleEnqueue(call: MethodCall, result: Result) {
        scope.launch {
            try {
                val taskId = call.argument<String>("taskId")
                    ?: return@launch result.error("INVALID_ARGS", "taskId required", null)
                val workerClassName = call.argument<String>("workerClassName")
                    ?: return@launch result.error("INVALID_ARGS", "workerClassName required", null)
                val workerConfig = call.argument<Map<String, Any?>?>("workerConfig")
                // Custom workers carry a pre-encoded "input" JSON string;
                // built-in workers need the entire workerConfig serialised as their input.
                // ✅ ENHANCEMENT: Inject taskId into all worker configs for progress reporting
                val inputJson: String? = when {
                    workerConfig == null -> null
                    workerConfig["workerType"] == "custom" -> workerConfig["input"] as? String
                    else -> {
                        // Inject taskId into worker config for progress reporting
                        val enrichedConfig = workerConfig.toMutableMap()
                        enrichedConfig["__taskId"] = taskId
                        toJson(enrichedConfig)
                    }
                }
                val tag = call.argument<String>("tag")

                // Store tag if provided
                if (tag != null) {
                    taskTags[taskId] = tag
                    Log.d(TAG, "Stored tag '$tag' for task '$taskId'")
                }

                // Parse trigger from method call arguments
                @Suppress("UNCHECKED_CAST")
                val triggerMap = call.argument<Map<String, Any?>>("trigger")
                val triggerType = triggerMap?.get("type") as? String ?: "oneTime"
                val trigger: TaskTrigger = when (triggerType) {
                    "periodic" -> {
                        val intervalMs = (triggerMap?.get("intervalMs") as? Number)?.toLong() ?: 900_000L
                        val flexMs = (triggerMap?.get("flexMs") as? Number)?.toLong()
                        TaskTrigger.Periodic(intervalMs = intervalMs, flexMs = flexMs)
                    }
                    "exact" -> {
                        val scheduledTimeMs = (triggerMap?.get("scheduledTimeMs") as? Number)?.toLong()
                            ?: System.currentTimeMillis()
                        TaskTrigger.Exact(atEpochMillis = scheduledTimeMs)
                    }
                    "windowed" -> {
                        val earliestMs = (triggerMap?.get("earliestMs") as? Number)?.toLong() ?: 0L
                        val latestMs = (triggerMap?.get("latestMs") as? Number)?.toLong() ?: 0L
                        TaskTrigger.Windowed(earliest = earliestMs, latest = latestMs)
                    }
                    "contentUri" -> {
                        val uriString = triggerMap?.get("uriString") as? String ?: ""
                        val triggerForDescendants = triggerMap?.get("triggerForDescendants") as? Boolean ?: false
                        TaskTrigger.ContentUri(uriString = uriString, triggerForDescendants = triggerForDescendants)
                    }
                    "batteryOkay" -> TaskTrigger.BatteryOkay
                    "batteryLow" -> TaskTrigger.BatteryLow
                    "deviceIdle" -> TaskTrigger.DeviceIdle
                    "storageLow" -> TaskTrigger.StorageLow
                    else -> {
                        val initialDelayMs = (triggerMap?.get("initialDelayMs") as? Number)?.toLong() ?: 0L
                        TaskTrigger.OneTime(initialDelayMs = initialDelayMs)
                    }
                }

                // Parse existing policy from method call arguments
                val existingPolicyStr = call.argument<String>("existingPolicy") ?: "replace"
                val policy = when (existingPolicyStr.lowercase()) {
                    "replace" -> ExistingPolicy.REPLACE
                    else -> ExistingPolicy.KEEP
                }

                @Suppress("UNCHECKED_CAST")
                val constraintsMap = call.argument<Map<String, Any?>>("constraints")
                val constraints = parseConstraints(constraintsMap)

                // Fix: WorkManager 2.10+ rejects expedited work (all kmpworkmanager OneTime tasks)
                // for ANY non-network/non-storage constraints, AND rejects expedited+initialDelay.
                // Bypass kmpworkmanager for ALL OneTime tasks: schedule directly via WorkManager
                // without setExpedited(). KmpWorker/KmpHeavyWorker still handle task dispatch.
                if (trigger is TaskTrigger.OneTime) {
                    val delayMs = trigger.initialDelayMs
                    Log.d(TAG, "Scheduling '$taskId': OneTime(delay=${delayMs}ms) → direct WorkManager (no expedited)")
                    enqueueOneTimeWorkDirect(taskId, workerClassName, inputJson, tag, constraints, delayMs, policy)
                    taskStatuses[taskId] = "pending"
                    observeWorkCompletion(taskId, false)
                    result.success("ACCEPTED")
                    return@launch
                }

                // Fix: kmpworkmanager scheduler.enqueue() silently creates a OneTimeWorkRequest
                // even when given a Periodic trigger — so the task runs once then never repeats.
                // Bypass kmpworkmanager for Periodic tasks and enqueue PeriodicWorkRequest directly.
                if (trigger is TaskTrigger.Periodic) {
                    val intervalMs = trigger.intervalMs
                    val flexMs = trigger.flexMs
                    Log.d(TAG, "Scheduling '$taskId': Periodic(interval=${intervalMs}ms, flex=${flexMs}ms) → direct WorkManager")
                    enqueuePeriodicWorkDirect(taskId, workerClassName, inputJson, tag, constraints, intervalMs, flexMs, policy)
                    taskStatuses[taskId] = "pending"
                    observeWorkCompletion(taskId, true)
                    result.success("ACCEPTED")
                    return@launch
                }

                val isPeriodic = trigger is TaskTrigger.Periodic
                Log.d(TAG, "Scheduling '$taskId': trigger=$triggerType, policy=$existingPolicyStr, heavy=${constraints.isHeavyTask}")

                val scheduleResult = scheduler.enqueue(
                    id = taskId,
                    trigger = trigger,
                    workerClassName = workerClassName,
                    constraints = constraints,
                    inputJson = inputJson,
                    policy = policy
                )

                when (scheduleResult) {
                    ScheduleResult.ACCEPTED -> {
                        taskStatuses[taskId] = "pending"
                        observeWorkCompletion(taskId, isPeriodic)
                        Log.d(TAG, "✅ Task scheduled: $taskId")
                        result.success("ACCEPTED")
                    }
                    ScheduleResult.REJECTED_OS_POLICY -> {
                        Log.w(TAG, "⚠️ Task rejected by OS policy: $taskId")
                        result.success("REJECTED_OS_POLICY")
                    }
                    ScheduleResult.THROTTLED -> {
                        Log.w(TAG, "⚠️ Task throttled: $taskId")
                        result.success("THROTTLED")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Enqueue error", e)
                result.error("ENQUEUE_ERROR", e.message, null)
            }
        }
    }

    private fun handleCancel(call: MethodCall, result: Result) {
        scope.launch {
            try {
                val taskId = call.argument<String>("taskId")
                    ?: return@launch result.error("INVALID_ARGS", "taskId required", null)

                scheduler.cancel(taskId)
                // Remove tag mapping
                taskTags.remove(taskId)
                result.success(null)
            } catch (e: Exception) {
                result.error("CANCEL_ERROR", e.message, null)
            }
        }
    }

    private fun handleCancelAll(result: Result) {
        scope.launch {
            try {
                scheduler.cancelAll()
                // Clear all tag mappings and status tracking
                taskTags.clear()
                taskStatuses.clear()
                result.success(null)
            } catch (e: Exception) {
                result.error("CANCEL_ERROR", e.message, null)
            }
        }
    }

    private fun handleCancelByTag(call: MethodCall, result: Result) {
        scope.launch {
            try {
                val tag = call.argument<String>("tag")
                    ?: return@launch result.error("INVALID_ARGS", "tag required", null)

                // Find all tasks with this tag
                val tasksToCancel = taskTags.filterValues { it == tag }.keys.toList()

                Log.d(TAG, "Canceling ${tasksToCancel.size} tasks with tag '$tag'")

                // Cancel each task
                tasksToCancel.forEach { taskId ->
                    try {
                        scheduler.cancel(taskId)
                        taskTags.remove(taskId)
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to cancel task $taskId: ${e.message}")
                    }
                }

                result.success(null)
            } catch (e: Exception) {
                result.error("CANCEL_ERROR", e.message, null)
            }
        }
    }

    private fun handleGetTasksByTag(call: MethodCall, result: Result) {
        try {
            val tag = call.argument<String>("tag")
                ?: return result.error("INVALID_ARGS", "tag required", null)

            // Find all tasks with this tag
            val tasks = taskTags.filterValues { it == tag }.keys.toList()
            result.success(tasks)
        } catch (e: Exception) {
            result.error("GET_TASKS_ERROR", e.message, null)
        }
    }

    private fun handleGetAllTags(result: Result) {
        try {
            // Get all unique tags
            val tags = taskTags.values.distinct()
            result.success(tags)
        } catch (e: Exception) {
            result.error("GET_TAGS_ERROR", e.message, null)
        }
    }

    private fun handleGetTaskStatus(call: MethodCall, result: Result) {
        try {
            val taskId = call.argument<String>("taskId")
                ?: return result.error("INVALID_ARGS", "taskId required", null)

            result.success(taskStatuses[taskId])
        } catch (e: Exception) {
            result.success(null)
        }
    }

    private fun handleEnqueueChain(call: MethodCall, result: Result) {
        scope.launch {
            try {
                val chainName = call.argument<String>("name") ?: "chain_${System.currentTimeMillis()}"
                @Suppress("UNCHECKED_CAST")
                val steps = call.argument<List<List<Map<String, Any?>>>>("steps") ?: emptyList()

                if (steps.isEmpty() || steps[0].isEmpty()) {
                    return@launch result.error("CHAIN_ERROR", "Chain must have at least one task", null)
                }

                val workManager = WorkManager.getInstance(context)
                val allTaskIds = mutableListOf<String>()

                // Build OneTimeWorkRequest for each step tagged with its task ID.
                // We bypass kmpworkmanager's chain API because TaskRequest has no 'id' parameter,
                // so we cannot add task-ID tags through it. Direct WorkManager gives us full control.
                val stepWorkRequests: List<List<OneTimeWorkRequest>> = steps.map { parallelTasks ->
                    @Suppress("UNCHECKED_CAST")
                    (parallelTasks as List<Map<String, Any?>>).map { taskData ->
                        val taskId = taskData["id"] as? String ?: java.util.UUID.randomUUID().toString()
                        allTaskIds.add(taskId)
                        buildChainStepRequest(taskId, taskData)
                    }
                }

                // Enqueue as a WorkManager chain.
                var continuation = workManager.beginWith(stepWorkRequests[0])
                for (i in 1 until stepWorkRequests.size) {
                    continuation = continuation.then(stepWorkRequests[i])
                }
                continuation.enqueue()

                Log.d(TAG, "✅ Chain scheduled: $chainName (${steps.size} steps), IDs: $allTaskIds")

                // Observe each chain step by its task-ID tag and emit events on completion.
                for (taskId in allTaskIds) {
                    taskStatuses[taskId] = "pending"
                    observeChainStepCompletion(taskId)
                }

                result.success("ACCEPTED")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Chain error", e)
                result.error("CHAIN_ERROR", e.message, null)
            }
        }
    }

    /**
     * Build a OneTimeWorkRequest for a single chain step.
     * The task ID is added as a WorkManager tag so we can observe by tag later.
     */
    private fun buildChainStepRequest(taskId: String, taskData: Map<String, Any?>): OneTimeWorkRequest {
        val workerClassName = taskData["workerClassName"] as? String ?: ""
        @Suppress("UNCHECKED_CAST")
        val workerConfig = taskData["workerConfig"] as? Map<String, Any?>
        val inputJson: String? = when {
            workerConfig == null -> null
            else -> {
                val enrichedConfig = workerConfig.toMutableMap()
                if (taskId.isNotEmpty()) enrichedConfig["__taskId"] = taskId
                toJson(enrichedConfig)
            }
        }
        @Suppress("UNCHECKED_CAST")
        val constraintsMap = taskData["constraints"] as? Map<String, Any?>
        val constraints = parseConstraints(constraintsMap)

        val dataBuilder = Data.Builder().putString("workerClassName", workerClassName)
        if (inputJson != null) dataBuilder.putString("inputJson", inputJson)

        val networkType = when {
            constraints.requiresUnmeteredNetwork -> NetworkType.UNMETERED
            constraints.requiresNetwork -> NetworkType.CONNECTED
            else -> NetworkType.NOT_REQUIRED
        }
        val wmConstraintsBuilder = androidx.work.Constraints.Builder()
            .setRequiredNetworkType(networkType)
            .setRequiresCharging(constraints.requiresCharging)
        val sysConstraints = constraints.systemConstraints ?: emptySet()
        if (sysConstraints.contains(SystemConstraint.DEVICE_IDLE)) wmConstraintsBuilder.setRequiresDeviceIdle(true)
        if (sysConstraints.contains(SystemConstraint.REQUIRE_BATTERY_NOT_LOW)) wmConstraintsBuilder.setRequiresBatteryNotLow(true)

        val workerClass = if (constraints.isHeavyTask) KmpHeavyWorker::class.java else KmpWorker::class.java
        return OneTimeWorkRequest.Builder(workerClass)
            .setConstraints(wmConstraintsBuilder.build())
            .setInputData(dataBuilder.build())
            .addTag(NativeTaskScheduler.TAG_KMP_TASK)
            .addTag("worker-$workerClassName")
            .addTag(taskId)         // Critical: allows observeChainStepCompletion to find this work
            .addTag(workerClassName)
            .build()
    }

    /**
     * Observe a single chain step by its task-ID tag and emit an event when it reaches a terminal state.
     * Uses getWorkInfosByTagFlow since chain steps are NOT unique work.
     */
    private fun observeChainStepCompletion(taskId: String) {
        scope.launch {
            try {
                val workManager = WorkManager.getInstance(context)
                workManager.getWorkInfosByTagFlow(taskId)
                    .collect { infos ->
                        val workInfo = infos.firstOrNull { it.state in TERMINAL_STATES }
                            ?: return@collect
                        if (taskStatuses[taskId] == "completed" || taskStatuses[taskId] == "failed") return@collect

                        when (workInfo.state) {
                            WorkInfo.State.SUCCEEDED -> {
                                taskStatuses[taskId] = "completed"
                                Log.d(TAG, "✅ Chain step SUCCEEDED: $taskId")
                                eventSink?.success(mapOf(
                                    "taskId" to taskId,
                                    "success" to true,
                                    "message" to "Chain step completed",
                                    "timestamp" to System.currentTimeMillis()
                                ))
                            }
                            WorkInfo.State.FAILED, WorkInfo.State.CANCELLED -> {
                                taskStatuses[taskId] = "failed"
                                Log.e(TAG, "❌ Chain step FAILED/CANCELLED: $taskId (${workInfo.state})")
                                eventSink?.success(mapOf(
                                    "taskId" to taskId,
                                    "success" to false,
                                    "message" to "Chain step ${workInfo.state.name.lowercase()}",
                                    "timestamp" to System.currentTimeMillis()
                                ))
                            }
                            else -> {}
                        }
                    }
            } catch (e: Exception) {
                Log.e(TAG, "Error observing chain step $taskId", e)
            }
        }
    }

    /**
     * Collect WorkManager's Flow for the given unique-work task.
     * TaskEventBus (kmpworkmanager) does not reliably emit on Android,
     * so we observe WorkInfo state directly via the ktx Flow API.
     *
     * One-time tasks: wait for the first terminal state (SUCCEEDED/FAILED/CANCELLED).
     * Periodic tasks: collect continuously, emitting an event on each execution cycle,
     * and stop only when the task is CANCELLED.
     */
    private fun observeWorkCompletion(taskId: String, isPeriodic: Boolean = false) {
        scope.launch {
            try {
                val workManager = WorkManager.getInstance(context)

                if (isPeriodic) {
                    // For periodic tasks: emit an event after each execution cycle.
                    // Use takeWhile to keep collecting until the task is cancelled.
                    //
                    // IMPORTANT: PeriodicWorkRequest never reaches SUCCEEDED state.
                    // Its state cycle is: ENQUEUED → RUNNING → ENQUEUED → RUNNING → ...
                    // One cycle completion is detected by the RUNNING → ENQUEUED transition.
                    var lastState: WorkInfo.State? = null
                    workManager.getWorkInfosForUniqueWorkFlow(taskId)
                        .takeWhile { infos ->
                            infos.isEmpty() || infos.first().state != WorkInfo.State.CANCELLED
                        }
                        .collect { infos ->
                            if (infos.isEmpty()) return@collect
                            val state = infos.first().state
                            if (state == lastState) return@collect
                            val previousState = lastState
                            lastState = state

                            when (state) {
                                WorkInfo.State.RUNNING -> {
                                    // Task started a new execution cycle
                                    taskStatuses[taskId] = "running"
                                }
                                WorkInfo.State.ENQUEUED -> {
                                    // RUNNING → ENQUEUED: one execution cycle just completed.
                                    // Any other → ENQUEUED is the initial schedule or re-queue after failure.
                                    if (previousState == WorkInfo.State.RUNNING) {
                                        taskStatuses[taskId] = "pending"
                                        Log.d(TAG, "✅ Periodic task cycle completed: $taskId")
                                        eventSink?.success(mapOf(
                                            "taskId" to taskId,
                                            "success" to true,
                                            "message" to "Task completed",
                                            "timestamp" to System.currentTimeMillis()
                                        ))
                                    } else {
                                        // Initial enqueue or re-enqueue after backoff
                                        if (taskStatuses[taskId] == "running") taskStatuses[taskId] = "pending"
                                    }
                                }
                                WorkInfo.State.FAILED -> {
                                    // Permanent failure (very rare for PeriodicWorkRequest;
                                    // normally WorkManager retries automatically via backoff).
                                    if (taskStatuses[taskId] != "failed") {
                                        taskStatuses[taskId] = "failed"
                                        Log.e(TAG, "❌ Periodic task failed permanently: $taskId")
                                        eventSink?.success(mapOf(
                                            "taskId" to taskId,
                                            "success" to false,
                                            "message" to "Task failed",
                                            "timestamp" to System.currentTimeMillis()
                                        ))
                                    }
                                }
                                else -> { /* other states — no action */ }
                            }
                        }
                    // Flow ended because the task was CANCELLED (takeWhile returned false)
                    taskStatuses[taskId] = "cancelled"
                    Log.d(TAG, "⚠️ Periodic task cancelled: $taskId")
                } else {
                    // One-time task: observe until terminal state.
                    // With ExistingWorkPolicy.REPLACE, WorkManager briefly emits CANCELLED
                    // for the old task before ENQUEUED appears for the new task.
                    // We retry once if CANCELLED is immediately followed by a new task.
                    var retries = 0
                    while (retries <= 1) {
                        val terminalInfos = workManager.getWorkInfosForUniqueWorkFlow(taskId).first { infos ->
                            infos.isNotEmpty() && infos.first().state in TERMINAL_STATES
                        }
                        val workInfo = terminalInfos.first()
                        val state = workInfo.state
                        // Extract output data from WorkInfo (set by KmpWorker/KmpHeavyWorker)
                        val outputDataMap = workInfo.outputData.keyValueMap
                            .let { if (it.isEmpty()) null else it }
                        when (state) {
                            WorkInfo.State.SUCCEEDED -> {
                                // Give TaskEventBus 500ms to fire first — it carries the real outputData.
                                // If it fires within this window it sets taskStatuses="completed" and
                                // emits the event; we then skip here to avoid a duplicate with null data.
                                kotlinx.coroutines.delay(500L)
                                if (taskStatuses[taskId] != "completed") {
                                    taskStatuses[taskId] = "completed"
                                    Log.d(TAG, "✅ WorkInfo SUCCEEDED (fallback): $taskId")
                                    eventSink?.success(mapOf(
                                        "taskId" to taskId,
                                        "success" to true,
                                        "message" to "Task completed",
                                        "resultData" to outputDataMap,
                                        "timestamp" to System.currentTimeMillis()
                                    ))
                                }
                                break
                            }
                            WorkInfo.State.FAILED -> {
                                // Same 500ms window for TaskEventBus to fire first.
                                kotlinx.coroutines.delay(500L)
                                if (taskStatuses[taskId] != "failed") {
                                    taskStatuses[taskId] = "failed"
                                    Log.e(TAG, "❌ WorkInfo FAILED (fallback): $taskId")
                                    eventSink?.success(mapOf(
                                        "taskId" to taskId,
                                        "success" to false,
                                        "message" to "Task failed",
                                        "resultData" to outputDataMap,
                                        "timestamp" to System.currentTimeMillis()
                                    ))
                                }
                                break
                            }
                            WorkInfo.State.CANCELLED -> {
                                // Wait briefly, then check if a new task appeared (REPLACE pattern).
                                kotlinx.coroutines.delay(500L)
                                val recheck = workManager.getWorkInfosForUniqueWorkFlow(taskId).first()
                                if (retries == 0 && recheck.isNotEmpty() &&
                                    recheck.first().state !in TERMINAL_STATES) {
                                    // New task is alive — this was a REPLACE cancellation, retry.
                                    Log.d(TAG, "🔄 REPLACE detected, retrying observation: $taskId")
                                    retries++
                                    continue
                                }
                                taskStatuses[taskId] = "cancelled"
                                Log.d(TAG, "⚠️ WorkInfo CANCELLED: $taskId")
                                break
                            }
                            else -> break
                        }
                    }
                }
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e  // Re-throw so coroutine cancellation propagates normally
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to observe work completion for $taskId", e)
            }
        }
    }

    private fun toTaskRequest(taskData: Map<String, Any?>): TaskRequest {
        val taskId = taskData["id"] as? String ?: ""
        val workerClassName = taskData["workerClassName"] as? String ?: ""
        @Suppress("UNCHECKED_CAST")
        val workerConfig = taskData["workerConfig"] as? Map<String, Any?>
        val inputJson: String? = when {
            workerConfig == null -> null
            workerConfig["workerType"] == "custom" -> workerConfig["input"] as? String
            else -> {
                // Inject __taskId so workers can report progress via ProgressReporter
                val enrichedConfig = workerConfig.toMutableMap()
                if (taskId.isNotEmpty()) enrichedConfig["__taskId"] = taskId
                toJson(enrichedConfig)
            }
        }
        @Suppress("UNCHECKED_CAST")
        val constraintsMap = taskData["constraints"] as? Map<String, Any?>
        return TaskRequest(
            workerClassName = workerClassName,
            inputJson = inputJson,
            constraints = parseConstraints(constraintsMap)
        )
    }

    /**
     * Parse kmpworkmanager [Constraints] from the Flutter method channel map.
     * Every field sent by Dart's [Constraints.toMap()] is honoured here.
     */
    @Suppress("UNCHECKED_CAST")
    private fun parseConstraints(map: Map<String, Any?>?): Constraints {
        if (map == null) return Constraints()

        val requiresNetwork = map["requiresNetwork"] as? Boolean ?: false
        val requiresUnmeteredNetwork = map["requiresUnmeteredNetwork"] as? Boolean ?: false
        val requiresCharging = map["requiresCharging"] as? Boolean ?: false
        val allowWhileIdle = map["allowWhileIdle"] as? Boolean ?: false
        val isHeavyTask = map["isHeavyTask"] as? Boolean ?: false
        val backoffDelayMs = (map["backoffDelayMs"] as? Number)?.toLong() ?: 30_000L

        val backoffPolicy = when ((map["backoffPolicy"] as? String)?.lowercase()) {
            "linear" -> BackoffPolicy.LINEAR
            else -> BackoffPolicy.EXPONENTIAL
        }

        val systemConstraintNames = map["systemConstraints"] as? List<*> ?: emptyList<Any>()
        val systemConstraints: MutableSet<SystemConstraint> = systemConstraintNames
            .filterIsInstance<String>()
            .mapNotNull { name ->
                when (name) {
                    "allowLowStorage" -> SystemConstraint.ALLOW_LOW_STORAGE
                    "allowLowBattery" -> SystemConstraint.ALLOW_LOW_BATTERY
                    "requireBatteryNotLow" -> SystemConstraint.REQUIRE_BATTERY_NOT_LOW
                    "deviceIdle" -> SystemConstraint.DEVICE_IDLE
                    else -> null
                }
            }.toMutableSet()

        // Merge legacy boolean flags into systemConstraints if not already covered
        if (map["requiresDeviceIdle"] as? Boolean == true) systemConstraints.add(SystemConstraint.DEVICE_IDLE)
        if (map["requiresBatteryNotLow"] as? Boolean == true) systemConstraints.add(SystemConstraint.REQUIRE_BATTERY_NOT_LOW)
        // requiresStorageNotLow has no direct SystemConstraint equivalent — intentionally skipped

        return Constraints(
            requiresNetwork = requiresNetwork,
            requiresUnmeteredNetwork = requiresUnmeteredNetwork,
            requiresCharging = requiresCharging,
            allowWhileIdle = allowWhileIdle,
            isHeavyTask = isHeavyTask,
            backoffPolicy = backoffPolicy,
            backoffDelayMs = backoffDelayMs,
            systemConstraints = systemConstraints
        )
    }

    /**
     * Schedules a OneTime task directly via WorkManager, bypassing kmpworkmanager.
     *
     * kmpworkmanager 2.3.3 always calls setExpedited() on OneTime work requests.
     * WorkManager 2.10+ rejects expedited work when:
     * - Combined with setInitialDelay() (any delay > 0), OR
     * - Combined with non-network/non-storage constraints (charging, battery, device-idle).
     * This method omits setExpedited() entirely so all constraint combinations are accepted.
     * KmpWorker and KmpHeavyWorker still handle task dispatch correctly.
     */
    private fun enqueueOneTimeWorkDirect(
        taskId: String,
        workerClassName: String,
        inputJson: String?,
        tag: String?,
        constraints: Constraints,
        delayMs: Long,
        policy: ExistingPolicy,
    ) {
        val workerClass = if (constraints.isHeavyTask) KmpHeavyWorker::class.java else KmpWorker::class.java

        val dataBuilder = Data.Builder().putString("workerClassName", workerClassName)
        if (inputJson != null) dataBuilder.putString("inputJson", inputJson)

        val networkType = when {
            constraints.requiresUnmeteredNetwork -> NetworkType.UNMETERED
            constraints.requiresNetwork -> NetworkType.CONNECTED
            else -> NetworkType.NOT_REQUIRED
        }
        val wmConstraintsBuilder = androidx.work.Constraints.Builder()
            .setRequiredNetworkType(networkType)
            .setRequiresCharging(constraints.requiresCharging)
        val sysConstraints = constraints.systemConstraints ?: emptySet()
        if (sysConstraints.contains(SystemConstraint.DEVICE_IDLE)) wmConstraintsBuilder.setRequiresDeviceIdle(true)
        if (sysConstraints.contains(SystemConstraint.REQUIRE_BATTERY_NOT_LOW)) wmConstraintsBuilder.setRequiresBatteryNotLow(true)

        val requestBuilder = OneTimeWorkRequest.Builder(workerClass)
            .setConstraints(wmConstraintsBuilder.build())
            .setInputData(dataBuilder.build())
            .addTag(NativeTaskScheduler.TAG_KMP_TASK)
            .addTag("worker-$workerClassName")
            .addTag(taskId)
            .addTag(workerClassName)
        if (delayMs > 0) requestBuilder.setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
        if (tag != null) requestBuilder.addTag(tag)

        val wmBackoffPolicy = when (constraints.backoffPolicy) {
            BackoffPolicy.LINEAR -> androidx.work.BackoffPolicy.LINEAR
            else -> androidx.work.BackoffPolicy.EXPONENTIAL
        }
        requestBuilder.setBackoffCriteria(wmBackoffPolicy, constraints.backoffDelayMs, TimeUnit.MILLISECONDS)

        val workPolicy = when (policy) {
            ExistingPolicy.REPLACE -> ExistingWorkPolicy.REPLACE
            else -> ExistingWorkPolicy.KEEP
        }
        val request = requestBuilder.build()
        Log.d(TAG, "📋 [DIAG] WorkRequest for '$taskId': networkType=$networkType, " +
            "requiresCharging=${constraints.requiresCharging}, " +
            "sysConstraints=$sysConstraints, " +
            "delayApplied=${delayMs > 0}, delayMs=$delayMs, " +
            "workerClass=${workerClass.simpleName}, " +
            "workerClassName=$workerClassName")
        WorkManager.getInstance(context).enqueueUniqueWork(taskId, workPolicy, request)
        Log.d(TAG, "✅ OneTime '$taskId' enqueued via direct WorkManager (delay=${delayMs}ms, heavy=${constraints.isHeavyTask}, policy=$workPolicy)")
    }

    /**
     * Schedules a Periodic task directly via WorkManager, bypassing kmpworkmanager.
     *
     * kmpworkmanager's BackgroundTaskScheduler.enqueue() creates a OneTimeWorkRequest even when
     * given a Periodic trigger — so the task runs once and never repeats.
     * This method creates a true PeriodicWorkRequest so WorkManager re-schedules it automatically.
     *
     * Note: WorkManager enforces a minimum repeat interval of 15 minutes (900,000 ms).
     * Shorter intervals are silently coerced up to 15 minutes by WorkManager.
     */
    private fun enqueuePeriodicWorkDirect(
        taskId: String,
        workerClassName: String,
        inputJson: String?,
        tag: String?,
        constraints: Constraints,
        intervalMs: Long,
        flexMs: Long?,
        policy: ExistingPolicy,
    ) {
        val workerClass = if (constraints.isHeavyTask) KmpHeavyWorker::class.java else KmpWorker::class.java

        val dataBuilder = Data.Builder().putString("workerClassName", workerClassName)
        if (inputJson != null) dataBuilder.putString("inputJson", inputJson)

        val networkType = when {
            constraints.requiresUnmeteredNetwork -> NetworkType.UNMETERED
            constraints.requiresNetwork -> NetworkType.CONNECTED
            else -> NetworkType.NOT_REQUIRED
        }
        val wmConstraintsBuilder = androidx.work.Constraints.Builder()
            .setRequiredNetworkType(networkType)
            .setRequiresCharging(constraints.requiresCharging)
        val sysConstraints = constraints.systemConstraints ?: emptySet()
        if (sysConstraints.contains(SystemConstraint.DEVICE_IDLE)) wmConstraintsBuilder.setRequiresDeviceIdle(true)
        if (sysConstraints.contains(SystemConstraint.REQUIRE_BATTERY_NOT_LOW)) wmConstraintsBuilder.setRequiresBatteryNotLow(true)

        // WorkManager minimum interval is 15 minutes; coerce silently to match WM behaviour
        val effectiveIntervalMs = intervalMs.coerceAtLeast(15 * 60 * 1000L)

        val requestBuilder = if (flexMs != null && flexMs > 0) {
            // Flex must be ≤ interval and ≥ 5 minutes per WorkManager constraints
            val effectiveFlexMs = flexMs.coerceIn(5 * 60 * 1000L, effectiveIntervalMs)
            PeriodicWorkRequest.Builder(
                workerClass,
                effectiveIntervalMs, TimeUnit.MILLISECONDS,
                effectiveFlexMs, TimeUnit.MILLISECONDS
            )
        } else {
            PeriodicWorkRequest.Builder(workerClass, effectiveIntervalMs, TimeUnit.MILLISECONDS)
        }

        requestBuilder
            .setConstraints(wmConstraintsBuilder.build())
            .setInputData(dataBuilder.build())
            .addTag(NativeTaskScheduler.TAG_KMP_TASK)
            .addTag("worker-$workerClassName")
            .addTag(taskId)
            .addTag(workerClassName)
        if (tag != null) requestBuilder.addTag(tag)

        val wmBackoffPolicy = when (constraints.backoffPolicy) {
            BackoffPolicy.LINEAR -> androidx.work.BackoffPolicy.LINEAR
            else -> androidx.work.BackoffPolicy.EXPONENTIAL
        }
        requestBuilder.setBackoffCriteria(wmBackoffPolicy, constraints.backoffDelayMs, TimeUnit.MILLISECONDS)

        // ExistingPeriodicWorkPolicy.REPLACE was deprecated in WorkManager 2.8.0;
        // CANCEL_AND_REENQUEUE is the correct replacement.
        val workPolicy = when (policy) {
            ExistingPolicy.REPLACE -> ExistingPeriodicWorkPolicy.CANCEL_AND_REENQUEUE
            else -> ExistingPeriodicWorkPolicy.KEEP
        }

        WorkManager.getInstance(context).enqueueUniquePeriodicWork(taskId, workPolicy, requestBuilder.build())
        Log.d(TAG, "✅ Periodic '$taskId' enqueued via direct WorkManager (interval=${effectiveIntervalMs}ms, flex=${flexMs}ms, policy=$workPolicy)")
    }

    private fun handleInitialize(call: MethodCall, result: Result) {
        try {
            // Forward callback dispatcher handle so DartCallbackWorker can boot a Flutter engine
            val callbackHandle = call.argument<Long>("callbackHandle")
            if (callbackHandle != null) {
                FlutterEngineManager.setCallbackHandle(callbackHandle)
            }

            // Extract debug mode flag
            debugMode = call.argument<Boolean>("debugMode") ?: false

            if (debugMode && isDebugBuild()) {
                Log.d(TAG, "✅ Debug mode enabled - notifications will show for all task events")
                createDebugNotificationChannel()
            }

            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Initialize error", e)
            result.error("INITIALIZE_ERROR", e.message, null)
        }
    }

    private fun isDebugBuild(): Boolean {
        return try {
            (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        } catch (e: Exception) {
            false
        }
    }

    private fun createDebugNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                DEBUG_NOTIFICATION_CHANNEL_ID,
                DEBUG_NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Shows debug notifications for background task events"
                setShowBadge(false)
            }

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    /** Recursively serialise a Flutter method-channel map to a JSON string.
     *  org.json.JSONObject(map) fails on nested LinkedHashMap / null values
     *  that Flutter's codec produces, so we build the tree manually. */
    private fun toJson(value: Any?): String = buildJsonValue(value)

    private fun buildJsonValue(value: Any?): String = when (value) {
        null -> "null"
        is Boolean -> value.toString()
        is Number -> value.toString()
        is String -> org.json.JSONObject.quote(value)
        is Map<*, *> -> {
            val entries = value.entries.joinToString(",") { (k, v) ->
                org.json.JSONObject.quote(k.toString()) + ":" + buildJsonValue(v)
            }
            "{$entries}"
        }
        is List<*> -> {
            val items = value.joinToString(",") { buildJsonValue(it) }
            "[$items]"
        }
        else -> org.json.JSONObject.quote(value.toString())
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        progressChannel.setStreamHandler(null)
        eventSink = null
        progressSink = null
        scope.cancel()
    }
}
