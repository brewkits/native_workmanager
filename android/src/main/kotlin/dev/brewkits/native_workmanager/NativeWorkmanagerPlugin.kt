package dev.brewkits.native_workmanager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.WorkInfo
import androidx.work.WorkManager
import dev.brewkits.kmpworkmanager.background.domain.*
import dev.brewkits.native_workmanager.engine.FlutterEngineManager
import dev.brewkits.kmpworkmanager.background.data.NativeTaskScheduler
import dev.brewkits.native_workmanager.workers.utils.ProgressReporter
import dev.brewkits.kmpworkmanager.kmpWorkerModule
import dev.brewkits.kmpworkmanager.KmpWorkManagerConfig
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import org.koin.android.ext.koin.androidContext
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject
import org.koin.core.context.GlobalContext
import org.koin.core.context.startKoin

/**
 * Native WorkManager Flutter Plugin for Android.
 *
 * Uses kmpworkmanager v2.3.0 from Maven Central as the core engine.
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

    // Inject BackgroundTaskScheduler from kmpworkmanager via Koin
    private val scheduler: BackgroundTaskScheduler by inject()
    // TaskEventBus is an object singleton, accessed directly (not via Koin)

    // Tag storage: taskId -> tag mapping
    private val taskTags = mutableMapOf<String, String>()

    // Task status tracking: taskId -> status string
    private val taskStatuses = mutableMapOf<String, String>()

    // Debug mode flag
    private var debugMode = false

    // Task start times for debug mode
    private val taskStartTimes = mutableMapOf<String, Long>()

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
            // ✅ Pass context to factory so it can create DartCallbackWorker with context
            val kmpModule = kmpWorkerModule(
                SimpleAndroidWorkerFactory(context),
                KmpWorkManagerConfig() // Default config
            )

            if (GlobalContext.getOrNull() == null) {
                startKoin {
                    androidContext(context)
                    modules(kmpModule)
                }
            } else {
                GlobalContext.get().loadModules(listOf(kmpModule))
            }
            isKoinInitialized = true
            Log.d(TAG, "✅ Koin initialized with kmpworkmanager v2.3.0 from Maven Central")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to initialize Koin", e)
        }
    }

    private fun subscribeToProgressUpdates() {
        scope.launch {
            try {
                ProgressReporter.progressFlow.collect { update ->
                    progressSink?.success(update.toMap())
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in progress subscription", e)
            }
        }
    }

    private fun subscribeToTaskEvents() {
        scope.launch {
            try {
                // Access TaskEventBus object singleton directly (v2.3.0+ with outputData support)
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

                    // Always emit event to Dart (v2.3.0+: includes outputData)
                    eventSink?.success(mapOf(
                        "taskId" to event.taskName,  // Map taskName to taskId for Dart compatibility
                        "success" to event.success,
                        "message" to event.message,
                        "resultData" to event.outputData,  // ✅ Pass result data from worker
                        "timestamp" to System.currentTimeMillis()
                    ))
                }
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

                // Use kmpworkmanager v2.1.2 core API
                val scheduleResult = scheduler.enqueue(
                    id = taskId,
                    trigger = TaskTrigger.OneTime(initialDelayMs = 0),
                    workerClassName = workerClassName,
                    constraints = Constraints(),
                    inputJson = inputJson,
                    policy = ExistingPolicy.KEEP
                )

                when (scheduleResult) {
                    ScheduleResult.ACCEPTED -> {
                        taskStatuses[taskId] = "pending"
                        observeWorkCompletion(taskId)
                        Log.d(TAG, "✅ Task scheduled: $taskId")
                        result.success("SUCCESS")
                    }
                    ScheduleResult.REJECTED_OS_POLICY -> {
                        Log.w(TAG, "⚠️ Task rejected by OS policy: $taskId")
                        result.error("REJECTED", "Task rejected by OS policy", null)
                    }
                    ScheduleResult.THROTTLED -> {
                        Log.w(TAG, "⚠️ Task throttled: $taskId")
                        result.error("THROTTLED", "Task throttled by OS", null)
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
                // Clear all tag mappings
                taskTags.clear()
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

                // Convert first step to TaskRequest list for beginWith
                val firstStep = steps[0].map { taskData -> toTaskRequest(taskData) }
                var chain = scheduler.beginWith(firstStep)

                // Append remaining steps
                for (i in 1 until steps.size) {
                    val stepRequests = steps[i].map { taskData -> toTaskRequest(taskData) }
                    chain = chain.then(stepRequests)
                }

                chain.enqueue()

                Log.d(TAG, "✅ Chain scheduled: $chainName (${steps.size} steps)")
                result.success("SUCCESS")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Chain error", e)
                result.error("CHAIN_ERROR", e.message, null)
            }
        }
    }

    /**
     * Collect WorkManager's Flow for the given unique-work task.
     * TaskEventBus (kmpworkmanager) does not reliably emit on Android,
     * so we observe WorkInfo state directly via the ktx Flow API.
     */
    private fun observeWorkCompletion(taskId: String) {
        scope.launch {
            try {
                val workManager = WorkManager.getInstance(context)
                // first{} suspends until a terminal state appears, then unsubscribes
                val terminalInfos = workManager.getWorkInfosForUniqueWorkFlow(taskId).first { infos ->
                    infos.isNotEmpty() && infos.first().state in TERMINAL_STATES
                }
                val state = terminalInfos.first().state
                when (state) {
                    WorkInfo.State.SUCCEEDED -> {
                        if (taskStatuses[taskId] != "completed") {
                            taskStatuses[taskId] = "completed"
                            Log.d(TAG, "✅ WorkInfo SUCCEEDED: $taskId")
                            eventSink?.success(mapOf(
                                "taskId" to taskId,
                                "success" to true,
                                "message" to "Task completed",
                                "timestamp" to System.currentTimeMillis()
                            ))
                        }
                    }
                    WorkInfo.State.FAILED -> {
                        if (taskStatuses[taskId] != "failed") {
                            taskStatuses[taskId] = "failed"
                            Log.e(TAG, "❌ WorkInfo FAILED: $taskId")
                            eventSink?.success(mapOf(
                                "taskId" to taskId,
                                "success" to false,
                                "message" to "Task failed",
                                "timestamp" to System.currentTimeMillis()
                            ))
                        }
                    }
                    WorkInfo.State.CANCELLED -> {
                        taskStatuses[taskId] = "cancelled"
                        Log.d(TAG, "⚠️ WorkInfo CANCELLED: $taskId")
                    }
                    else -> {}
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to observe work completion for $taskId", e)
            }
        }
    }

    private fun toTaskRequest(taskData: Map<String, Any?>): TaskRequest {
        val workerClassName = taskData["workerClassName"] as? String ?: ""
        @Suppress("UNCHECKED_CAST")
        val workerConfig = taskData["workerConfig"] as? Map<String, Any?>
        val inputJson: String? = when {
            workerConfig == null -> null
            workerConfig["workerType"] == "custom" -> workerConfig["input"] as? String
            else -> toJson(workerConfig)
        }
        return TaskRequest(
            workerClassName = workerClassName,
            inputJson = inputJson,
            constraints = Constraints()
        )
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
        scope.cancel()
    }
}
