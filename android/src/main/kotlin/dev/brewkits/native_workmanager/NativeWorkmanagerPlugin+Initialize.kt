package dev.brewkits.native_workmanager

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import dev.brewkits.kmpworkmanager.background.data.KmpWorker
import dev.brewkits.native_workmanager.engine.FlutterEngineManager
import dev.brewkits.native_workmanager.workers.DbCleanupWorker
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.launch
import java.util.concurrent.TimeUnit

// ── Plugin initialization, debug-mode setup, and cold-start persistence.
// ── Separated from NativeWorkmanagerPlugin.kt to reduce God Object complexity.

private const val DEBUG_NOTIFICATION_CHANNEL_NAME = "Background Task Debug"

/**
 * Handle the `initialize` MethodChannel call from Dart.
 *
 * **Cold-start persistence**: When the Dart side calls `NativeWorkManager.initialize()`,
 * this function persists the `callbackHandle` to SharedPreferences so that WorkManager
 * can restore it after the process is killed and restarted.
 *
 * The SharedPreferences key is [NativeWorkmanagerPlugin.CALLBACK_HANDLE_KEY] under the
 * namespace [NativeWorkmanagerPlugin.SHARED_PREFS_NAME]. The host app's `Application.onCreate()`
 * should read this value and call `FlutterEngineManager.setCallbackHandle()` to enable
 * Dart workers to run after a killed-app restart. See `doc/ANDROID_SETUP.md` for details.
 */
internal fun NativeWorkmanagerPlugin.handleInitialize(call: MethodCall, result: Result) {
    try {
        val callbackHandle = call.argument<Long>("callbackHandle")
        if (callbackHandle != null) {
            FlutterEngineManager.setCallbackHandle(callbackHandle)

            // ✅ COLD-START PERSISTENCE: Persist to SharedPreferences so WorkManager can
            // restore the handle when the process is killed and restarted.
            // The host app's Application.onCreate() should read this and call
            // FlutterEngineManager.setCallbackHandle() to re-arm the Dart engine.
            context.getSharedPreferences(NativeWorkmanagerPlugin.SHARED_PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putLong(NativeWorkmanagerPlugin.CALLBACK_HANDLE_KEY, callbackHandle)
                .apply()

            NativeLogger.d("✅ callbackHandle persisted (cold-start support enabled)")
        } else {
            NativeLogger.d("callbackHandle is null — no Dart workers registered")
        }

        debugMode = call.argument<Boolean>("debugMode") ?: false
        NativeLogger.enabled = debugMode && isDebugBuild()
        if (NativeLogger.enabled) {
            NativeLogger.d("✅ Debug mode enabled - notifications will show for all task events")
            createDebugNotificationChannel()
        }

        val maxConcurrentTasks = call.argument<Int>("maxConcurrentTasks")
            ?: NativeWorkmanagerPlugin.DEFAULT_MAX_CONCURRENT_TASKS
        NativeLogger.d("maxConcurrentTasks=$maxConcurrentTasks (WorkManager thread-pool managed)")

        val enforceHttps = call.argument<Boolean>("enforceHttps") ?: false
        SecurityValidator.enforceHttps = enforceHttps
        NativeLogger.d("enforceHttps=$enforceHttps")

        val blockPrivateIPs = call.argument<Boolean>("blockPrivateIPs") ?: false
        SecurityValidator.blockPrivateIPs = blockPrivateIPs
        NativeLogger.d("blockPrivateIPs=$blockPrivateIPs")

        val cleanupAfterDays = call.argument<Int>("cleanupAfterDays") ?: 30
        if (cleanupAfterDays > 0) {
            ioScope.launch {
                val thresholdMs = cleanupAfterDays.toLong() * 24 * 60 * 60 * 1000L
                taskStore.deleteCompleted(olderThanMs = thresholdMs)
                NativeLogger.d("Auto-cleanup: pruned task records older than ${cleanupAfterDays}d")
            }
        }

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
 */
internal fun NativeWorkmanagerPlugin.scheduleWeeklyDbCleanup() {
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

/** Returns true if this is a debuggable build (not a production release). */
internal fun NativeWorkmanagerPlugin.isDebugBuild(): Boolean {
    return try {
        (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
    } catch (e: Exception) {
        false
    }
}

/** Create the notification channel used for debug task-completion banners. */
internal fun NativeWorkmanagerPlugin.createDebugNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val channel = NotificationChannel(
            NativeWorkmanagerPlugin.DEBUG_NOTIFICATION_CHANNEL_ID,
            DEBUG_NOTIFICATION_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Shows debug notifications for background task events"
            setShowBadge(false)
        }
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(channel)
    }
}
