package dev.brewkits.native_workmanager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
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
import dev.brewkits.native_workmanager.workers.HttpDownloadWorker
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import dev.brewkits.kmpworkmanager.kmpWorkerModule
import dev.brewkits.kmpworkmanager.KmpWorkManagerConfig
import dev.brewkits.kmpworkmanager.KmpWorkManager
import dev.brewkits.native_workmanager.AppContextHolder
import dev.brewkits.native_workmanager.notification.DownloadNotificationManager
import dev.brewkits.native_workmanager.store.TaskStore
import dev.brewkits.native_workmanager.workers.utils.HostConcurrencyManager
import dev.brewkits.native_workmanager.workers.DbCleanupWorker
import android.content.Intent
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.takeWhile
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import okhttp3.OkHttpClient
import org.koin.android.ext.koin.androidContext
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject
import org.koin.core.context.GlobalContext
import org.koin.core.context.startKoin

/**
 * Native WorkManager Flutter Plugin for Android.
 *
 * Uses kmpworkmanager v2.3.7 from Maven Central as the core engine.
 * This ensures compatibility with Pro/Enterprise versions.
 */
class NativeWorkmanagerPlugin : FlutterPlugin, MethodCallHandler, KoinComponent,
    android.content.ComponentCallbacks2 {

    internal lateinit var methodChannel: MethodChannel
    internal lateinit var eventChannel: EventChannel
    internal lateinit var progressChannel: EventChannel
    internal lateinit var context: Context

    internal var eventSink: EventChannel.EventSink? = null
    internal var progressSink: EventChannel.EventSink? = null
    // Main scope: UI updates, event/progress emission, result callbacks to Flutter.
    internal val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    // IO scope: SQLite reads/writes, file I/O. Separate from Main to avoid blocking UI thread.
    internal val ioScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // Track subscription jobs so old ones are cancelled on re-subscribe
    internal var eventJob: Job? = null
    internal var progressJob: Job? = null

    // Inject BackgroundTaskScheduler from kmpworkmanager via Koin
    internal val scheduler: BackgroundTaskScheduler by inject()
    // TaskEventBus is an object singleton, accessed directly (not via Koin)

    // Tag storage: taskId -> tag mapping (ConcurrentHashMap for thread safety across coroutines)
    internal val taskTags = ConcurrentHashMap<String, String>()

    // Task status tracking: taskId -> status string (ConcurrentHashMap for thread safety)
    internal val taskStatuses = ConcurrentHashMap<String, String>()

    // Debug mode flag
    internal var debugMode = false

    // Task start times for debug mode (ConcurrentHashMap for thread safety)
    internal val taskStartTimes = ConcurrentHashMap<String, Long>()

    // Per-task signal: completed by subscribeToTaskEvents when TaskEventBus fires.
    // observeWorkCompletion awaits this instead of using delay(500L), so the WorkManager
    // fallback path resolves immediately when TaskEventBus fires and only blocks up to
    // 2 seconds if it doesn't (e.g. edge cases where the bus is silent).
    internal val taskBusSignals = ConcurrentHashMap<String, CompletableDeferred<Unit>>()

    // Persistent SQLite task store (initialized in onAttachedToEngine)
    internal lateinit var taskStore: TaskStore

    // Persistent SQLite chain state store (initialized in onAttachedToEngine)
    internal lateinit var chainStore: dev.brewkits.native_workmanager.store.ChainStore

    // Notification title per taskId for download notification feature
    internal val taskNotifTitles = ConcurrentHashMap<String, String>()

    // allowPause flag per taskId (for suppressing Pause button in notifications)
    internal val taskAllowPause = ConcurrentHashMap<String, Boolean>()

    // Filename per taskId (extracted from URL for notification template substitution)
    internal val taskFilenames = ConcurrentHashMap<String, String>()

    companion object {
        private const val TAG = "NativeWorkmanagerPlugin"
        private const val METHOD_CHANNEL = "dev.brewkits/native_workmanager"
        private const val EVENT_CHANNEL = "dev.brewkits/native_workmanager/events"
        private const val PROGRESS_CHANNEL = "dev.brewkits/native_workmanager/progress"
        internal const val DEBUG_NOTIFICATION_CHANNEL_ID = "native_workmanager_debug"
        private const val DEBUG_NOTIFICATION_CHANNEL_NAME = "Background Task Debug"
        /** Auto-dismiss timeout for debug task-completion notifications (ms). */
        internal const val DEBUG_NOTIFICATION_TIMEOUT_MS = 5_000L
        /** Default concurrent-task limit (mirrors iOS NWMDefaults.maxConcurrentTasks). */
        private const val DEFAULT_MAX_CONCURRENT_TASKS = 4
        private var isKoinInitialized = false
        internal val TERMINAL_STATES = setOf(
            WorkInfo.State.SUCCEEDED,
            WorkInfo.State.FAILED,
            WorkInfo.State.CANCELLED
        )
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        AppContextHolder.appContext = context

        // Register for system memory callbacks (onTrimMemory / onLowMemory).
        // Unregistered in onDetachedFromEngine to prevent leaks.
        context.registerComponentCallbacks(this)

        // Initialize persistent task store, chain store, and download notification channel
        taskStore = TaskStore(context)
        chainStore = dev.brewkits.native_workmanager.store.ChainStore(context)
        DownloadNotificationManager.createChannel(context)

        // Resume any incomplete chains that were in-progress when the app was killed.
        // WorkManager will re-execute the individual workers; this restores Dart-visible
        // chain metadata and re-attaches step observers.
        ioScope.launch { resumePendingChains() }

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
            NativeLogger.d("✅ Koin initialized with kmpworkmanager v2.3.7 from Maven Central")
        } catch (e: Exception) {
            NativeLogger.e("❌ Failed to initialize Koin", e)
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
            "pause" -> handlePause(call, result)
            "resume" -> handleResume(call, result)
            "allTasks" -> handleAllTasks(result)
            "getServerFilename" -> handleGetServerFilename(call, result)
            "openFile" -> handleOpenFile(call, result)
            "setMaxConcurrentPerHost" -> {
                val max = call.argument<Int>("max") ?: 2
                HostConcurrencyManager.maxConcurrentPerHost = max
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }


    private fun handleInitialize(call: MethodCall, result: Result) {
        try {
            // Forward callback dispatcher handle so DartCallbackWorker can boot a Flutter engine
            val callbackHandle = call.argument<Long>("callbackHandle")
            if (callbackHandle != null) {
                FlutterEngineManager.setCallbackHandle(callbackHandle)
            }

            // Extract debug mode flag and wire up the centralised logger.
            debugMode = call.argument<Boolean>("debugMode") ?: false
            NativeLogger.enabled = debugMode && isDebugBuild()

            if (NativeLogger.enabled) {
                NativeLogger.d("✅ Debug mode enabled - notifications will show for all task events")
                createDebugNotificationChannel()
            }

            // maxConcurrentTasks: Android WorkManager manages its own thread pool
            // (default ≈ min(CPU-1, 4) workers).  We accept the param so the Dart
            // API is symmetric with iOS, but no additional limiting is applied here.
            val maxConcurrentTasks = call.argument<Int>("maxConcurrentTasks") ?: DEFAULT_MAX_CONCURRENT_TASKS
            NativeLogger.d("maxConcurrentTasks=$maxConcurrentTasks (WorkManager thread-pool managed)")

            // HTTPS enforcement — propagate flag to SecurityValidator so all workers honour it.
            val enforceHttps = call.argument<Boolean>("enforceHttps") ?: false
            dev.brewkits.native_workmanager.workers.utils.SecurityValidator.enforceHttps = enforceHttps
            NativeLogger.d("enforceHttps=$enforceHttps")

            // SSRF protection — block requests to private/loopback IP literals.
            val blockPrivateIPs = call.argument<Boolean>("blockPrivateIPs") ?: false
            dev.brewkits.native_workmanager.workers.utils.SecurityValidator.blockPrivateIPs = blockPrivateIPs
            NativeLogger.d("blockPrivateIPs=$blockPrivateIPs")

            // Auto-cleanup: prune terminal-state records older than N days (prevents unbounded growth).
            val cleanupAfterDays = call.argument<Int>("cleanupAfterDays") ?: 30
            if (cleanupAfterDays > 0) {
                ioScope.launch {
                    val thresholdMs = cleanupAfterDays.toLong() * 24 * 60 * 60 * 1000L
                    taskStore.deleteCompleted(olderThanMs = thresholdMs)
                    NativeLogger.d("Auto-cleanup: pruned task records older than ${cleanupAfterDays}d")
                }
            }

            // Register weekly periodic DB cleanup via WorkManager (KEEP policy so re-init is idempotent).
            scheduleWeeklyDbCleanup()

            result.success(null)
        } catch (e: Exception) {
            NativeLogger.e("Initialize error", e)
            result.error("INITIALIZE_ERROR", e.message, null)
        }
    }

    /**
     * Enqueue a weekly WorkManager periodic job that prunes old SQLite task records.
     *
     * Uses [ExistingPeriodicWorkPolicy.KEEP] so that calling [initialize] multiple times
     * (e.g. hot-restart) does not reset the 7-day interval clock.
     * The job runs without network or charging constraints — it's pure local I/O.
     */
    private fun scheduleWeeklyDbCleanup() {
        val dataBuilder = Data.Builder()
            .putString("workerClassName", "DbCleanupWorker")
        val request = PeriodicWorkRequest.Builder(
            KmpWorker::class.java,
            7L, TimeUnit.DAYS
        )
            .setInputData(dataBuilder.build())
            .addTag("__native_wm_internal__")
            .addTag("DbCleanupWorker")
            .build()

        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            DbCleanupWorker.TASK_ID,
            ExistingPeriodicWorkPolicy.KEEP,
            request
        )
        NativeLogger.d("📅 Weekly DB cleanup scheduled (KEEP policy)")
    }

    internal fun isDebugBuild(): Boolean {
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
    internal fun toJson(value: Any?): String = buildJsonValue(value, 0)

    private fun buildJsonValue(value: Any?, depth: Int): String {
        // Guard against pathologically deep structures (e.g. circular-like graphs
        // via toString() or accidental self-referencing data).  Depth > 10 is
        // almost certainly a bug in the caller, not a legitimate payload.
        if (depth > 10) return "\"[MAX_DEPTH]\""
        return when (value) {
            null -> "null"
            is Boolean -> value.toString()
            is Number -> value.toString()
            is String -> org.json.JSONObject.quote(value)
            is Map<*, *> -> {
                val entries = value.entries.joinToString(",") { (k, v) ->
                    org.json.JSONObject.quote(k.toString()) + ":" + buildJsonValue(v, depth + 1)
                }
                "{$entries}"
            }
            is List<*> -> {
                val items = value.joinToString(",") { buildJsonValue(it, depth + 1) }
                "[$items]"
            }
            else -> org.json.JSONObject.quote(value.toString())
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context.unregisterComponentCallbacks(this)
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        progressChannel.setStreamHandler(null)
        eventSink = null
        progressSink = null
        // Cancel all pending bus-signal deferreds so their await() calls unblock.
        taskBusSignals.values.forEach { it.cancel() }
        taskBusSignals.clear()
        scope.cancel()
        ioScope.cancel()
        // FIX H2: Reset the static initialization flag so the next attach (e.g. hot restart)
        // goes through initializeKoin() again and re-loads modules into the Koin context.
        // Without this, a hot restart reuses the stale flag and skips module loading,
        // which can leave injected dependencies pointing at a dead context.
        isKoinInitialized = false
    }

    // ── ComponentCallbacks2 — low-memory response ─────────────────────────────

    /**
     * Dispose the Flutter background engine when the OS signals memory pressure.
     *
     * The engine consumes ~30-50 MB of RAM. Releasing it under memory pressure
     * prevents the process from being killed by the OOM killer. The engine is
     * re-created lazily the next time a DartWorker task is executed.
     *
     * Level thresholds (ascending severity):
     * - TRIM_MEMORY_RUNNING_CRITICAL (15): system about to kill background processes
     * - TRIM_MEMORY_UI_HIDDEN (20): UI no longer visible (good time to free caches)
     * - TRIM_MEMORY_BACKGROUND (40): process in LRU cache — dispose now
     * - TRIM_MEMORY_MODERATE (60): deeper in LRU — dispose now
     * - TRIM_MEMORY_COMPLETE (80): about to be killed — dispose now
     */
    override fun onTrimMemory(level: Int) {
        if (level >= android.content.ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL) {
            if (FlutterEngineManager.isEngineAlive()) {
                Log.d(TAG, "onTrimMemory(level=$level) — disposing Flutter engine to free RAM")
                ioScope.launch { FlutterEngineManager.dispose() }
            }
        }
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        // No-op — required by ComponentCallbacks2 interface.
    }

    override fun onLowMemory() {
        // onLowMemory is the older API (< API 14). Dispose engine here as well.
        if (FlutterEngineManager.isEngineAlive()) {
            Log.d(TAG, "onLowMemory() — disposing Flutter engine to free RAM")
            ioScope.launch { FlutterEngineManager.dispose() }
        }
    }
}
}
