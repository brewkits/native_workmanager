package dev.brewkits.native_workmanager

import android.content.Context
import android.os.Build
import android.util.Log
import androidx.work.*
import dev.brewkits.kmpworkmanager.KmpWorkManager
import dev.brewkits.kmpworkmanager.KmpWorkManagerConfig
import dev.brewkits.kmpworkmanager.background.data.NativeTaskScheduler
import dev.brewkits.kmpworkmanager.background.domain.BackgroundTaskScheduler
import dev.brewkits.native_workmanager.engine.FlutterEngineManager
import dev.brewkits.native_workmanager.notification.DownloadNotificationManager
import dev.brewkits.native_workmanager.store.DatabaseHelper
import dev.brewkits.native_workmanager.store.TaskStore
import dev.brewkits.native_workmanager.workers.utils.HostConcurrencyManager
import dev.brewkits.native_workmanager.workers.utils.ProgressReporter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.withLock
import okhttp3.OkHttpClient
import java.util.concurrent.ConcurrentHashMap

/**
 * Native WorkManager Flutter Plugin for Android.
 *
 * Uses kmpworkmanager v2.3.9 from Maven Central as the core engine.
 */
class NativeWorkmanagerPlugin : FlutterPlugin, MethodCallHandler,
    android.content.ComponentCallbacks2 {

    internal lateinit var methodChannel: MethodChannel
    internal lateinit var eventChannel: EventChannel
    internal lateinit var progressChannel: EventChannel
    internal lateinit var systemErrorChannel: EventChannel
    internal lateinit var context: Context

    internal var eventSink: EventChannel.EventSink? = null
    internal var progressSink: EventChannel.EventSink? = null
    internal var systemErrorSink: EventChannel.EventSink? = null
    internal val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    internal val ioScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    internal var eventJob: Job? = null
    internal var progressJob: Job? = null

    internal lateinit var scheduler: BackgroundTaskScheduler

    internal val taskTags = ConcurrentHashMap<String, String>()
    internal val taskStatuses = ConcurrentHashMap<String, String>()
    internal var debugMode = false
    internal val taskStartTimes = ConcurrentHashMap<String, Long>()
    internal val taskBusSignals = ConcurrentHashMap<String, CompletableDeferred<Unit>>()

    internal lateinit var taskStore: TaskStore
    internal lateinit var chainStore: dev.brewkits.native_workmanager.store.ChainStore
    internal lateinit var remoteTriggerStore: dev.brewkits.native_workmanager.store.RemoteTriggerStore
    internal lateinit var offlineQueueStore: dev.brewkits.native_workmanager.store.OfflineQueueStore
    internal lateinit var middlewareStore: dev.brewkits.native_workmanager.store.MiddlewareStore

    private val engineMutex = kotlinx.coroutines.sync.Mutex()

    internal val taskNotifTitles = ConcurrentHashMap<String, String>()
    internal val taskAllowPause = ConcurrentHashMap<String, Boolean>()
    internal val taskFilenames = ConcurrentHashMap<String, String>()

    companion object {
        private const val TAG = "NativeWorkmanagerPlugin"
        private const val METHOD_CHANNEL = "dev.brewkits/native_workmanager"
        private const val EVENT_CHANNEL = "dev.brewkits/native_workmanager/events"
        private const val PROGRESS_CHANNEL = "dev.brewkits/native_workmanager/progress"
        private const val SYSTEM_ERROR_CHANNEL = "dev.brewkits/native_workmanager/system_errors"
        internal const val SHARED_PREFS_NAME = "dev.brewkits.native_workmanager"
        internal const val CALLBACK_HANDLE_KEY = "callback_handle"
        internal const val LAST_CLEANUP_KEY = "last_cleanup_timestamp"
        internal const val CLEANUP_INTERVAL_MS = 24 * 60 * 60 * 1000L // 24 hours

        internal const val DEBUG_NOTIFICATION_CHANNEL_ID = "native_workmanager_debug"
        internal const val DEBUG_NOTIFICATION_TIMEOUT_MS = 5_000L
        internal const val DEFAULT_MAX_CONCURRENT_TASKS = 4
        private var isSchedulerInitialized = false
        
        // SEC-001: Global instance for system error reporting from static context
        private var sharedPluginInstance: NativeWorkmanagerPlugin? = null

        internal val TERMINAL_STATES = setOf(
            WorkInfo.State.SUCCEEDED,
            WorkInfo.State.FAILED,
            WorkInfo.State.CANCELLED
        )

        internal val sharedHttpClient: OkHttpClient by lazy {
            OkHttpClient.Builder()
                .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                .followRedirects(true)
                .build()
        }

        fun emitSystemError(context: Context, code: String, message: String) {
            NativeLogger.e("🚨 SYSTEM ERROR [$code]: $message")
            sharedPluginInstance?.systemErrorSink?.success(mapOf(
                "code" to code,
                "message" to message,
                "timestamp" to System.currentTimeMillis()
            ))
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        AppContextHolder.appContext = context
        context.registerComponentCallbacks(this)
        sharedPluginInstance = this

        taskStore = TaskStore(context)
        val prefs = context.getSharedPreferences(SHARED_PREFS_NAME, Context.MODE_PRIVATE)

        // Throttled cleanup & State restoration
        ioScope.launch {
            try {
                val now = System.currentTimeMillis()
                val lastCleanup = prefs.getLong(LAST_CLEANUP_KEY, 0L)
                
                if (now - lastCleanup > CLEANUP_INTERVAL_MS) {
                    taskStore.recoverZombieTasks()
                    taskStore.deleteCompleted(olderThanMs = 604_800_000L)
                    prefs.edit().putLong(LAST_CLEANUP_KEY, now).apply()
                    NativeLogger.d("🧹 Throttled cleanup performed")
                }

                val allRecords = taskStore.getAllTasks()
                allRecords.forEach { record ->
                    taskStatuses[record.taskId] = record.status
                    record.tag?.let { taskTags[record.taskId] = it }
                }
                NativeLogger.d("🔋 Restored ${allRecords.size} task(s) from store")
            } catch (e: Exception) {
                NativeLogger.e("Failed to restore task state or perform cleanup", e)
                if (e is android.database.sqlite.SQLiteFullException) {
                    emitSystemError(context, "DISK_FULL", "Cannot perform startup cleanup: Disk full")
                }
            }
        }

        chainStore = dev.brewkits.native_workmanager.store.ChainStore(context)
        remoteTriggerStore = dev.brewkits.native_workmanager.store.RemoteTriggerStore(context)
        offlineQueueStore = dev.brewkits.native_workmanager.store.OfflineQueueStore(context)
        middlewareStore = dev.brewkits.native_workmanager.store.MiddlewareStore.getInstance(context)
        DownloadNotificationManager.createChannel(context)
        ProgressReporter.initialize(context, taskStore)

        ioScope.launch { resumePendingChains() }
        initializeScheduler(context)

        val savedHandle = prefs.getLong(CALLBACK_HANDLE_KEY, -1L)
        if (savedHandle != -1L) {
            FlutterEngineManager.setCallbackHandle(savedHandle)
        }

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                subscribeToTaskEvents()
            }
            override fun onCancel(arguments: Any?) {
                eventJob?.cancel()
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
                progressJob?.cancel()
                progressSink = null
            }
        })

        systemErrorChannel = EventChannel(binding.binaryMessenger, SYSTEM_ERROR_CHANNEL)
        systemErrorChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                systemErrorSink = events
            }
            override fun onCancel(arguments: Any?) {
                systemErrorSink = null
            }
        })
    }

    private fun initializeScheduler(context: Context) {
        if (isSchedulerInitialized) return
        try {
            val workerFactory = SimpleAndroidWorkerFactory(context)
            KmpWorkManager.initialize(context, workerFactory, KmpWorkManagerConfig())
            scheduler = NativeTaskScheduler(context)
            isSchedulerInitialized = true
        } catch (e: Exception) {
            NativeLogger.e("❌ Failed to initialize scheduler", e)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
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
                "getTaskRecord" -> handleGetTaskRecord(call, result)
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
                "registerRemoteTrigger" -> handleRegisterRemoteTrigger(call, result)
                "enqueueGraph" -> handleEnqueueGraph(call, result)
                "offlineQueueEnqueue" -> handleOfflineQueueEnqueue(call, result)
                "registerMiddleware" -> handleRegisterMiddleware(call, result)
                "getMetrics" -> handleGetMetrics(result)
                "syncOfflineQueue" -> handleSyncOfflineQueue(result)
                "getRunningProgress" -> {
                    result.success(ProgressReporter.getRunningProgress())
                }
                else -> result.notImplemented()
            }
        } catch (e: android.database.sqlite.SQLiteFullException) {
            NativeLogger.e("❌ Disk full during method call: ${call.method}")
            emitSystemError(context, "DISK_FULL", "Database operation failed: Disk full")
            result.error("DISK_FULL", "Operation failed because the device is out of storage", null)
        } catch (e: Exception) {
            result.error("PLUGIN_ERROR", e.message, null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context.unregisterComponentCallbacks(this)
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        progressChannel.setStreamHandler(null)
        systemErrorChannel.setStreamHandler(null)
        eventJob?.cancel()
        progressJob?.cancel()
        taskBusSignals.values.forEach { it.cancel() }
        taskBusSignals.clear()
        scope.cancel()
        ioScope.cancel()
        isSchedulerInitialized = false
        sharedPluginInstance = null
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {}

    override fun onLowMemory() {
        NativeLogger.w("⚠️ System Low Memory signal received")
        ioScope.launch {
            engineMutex.withLock {
                FlutterEngineManager.dispose()
            }
        }
    }

    override fun onTrimMemory(level: Int) {
        if (level >= android.content.ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL ||
            level >= android.content.ComponentCallbacks2.TRIM_MEMORY_MODERATE) {
            NativeLogger.w("⚠️ Trimming memory (level: $level)")
            if (ioScope.isActive) {
                ioScope.launch {
                    engineMutex.withLock {
                        try {
                            FlutterEngineManager.dispose()
                        } catch (e: Exception) {
                            if (e is CancellationException) throw e
                            Log.e(TAG, "Failed to dispose engine during onTrimMemory", e)
                        }
                    }
                }
            }
        }
    }
}
