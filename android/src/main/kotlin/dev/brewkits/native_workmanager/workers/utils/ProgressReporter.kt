package dev.brewkits.native_workmanager.workers.utils

import android.util.Log
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * Progress reporter for native workers.
 *
 * Allows workers to report progress updates that will be emitted to Dart
 * via the progress EventChannel.
 */
object ProgressReporter {
    private const val TAG = "ProgressReporter"

    private var context: android.content.Context? = null
    private var taskStore: dev.brewkits.native_workmanager.store.TaskStore? = null

    // Configuration for automatic notifications (populated by plugin)
    val taskNotifTitles = java.util.concurrent.ConcurrentHashMap<String, String>()
    val taskFilenames = java.util.concurrent.ConcurrentHashMap<String, String>()
    val taskAllowPause = java.util.concurrent.ConcurrentHashMap<String, Boolean>()

    internal fun initialize(context: android.content.Context, taskStore: dev.brewkits.native_workmanager.store.TaskStore) {
        this.context = context.applicationContext
        this.taskStore = taskStore
    }

    data class ProgressUpdate(
        val taskId: String,
        val progress: Int,
        val message: String? = null,
        val currentStep: Int? = null,
        val totalSteps: Int? = null,
        val bytesDownloaded: Long? = null,
        val totalBytes: Long? = null,
        val networkSpeed: Double? = null,   // bytes per second
        val timeRemainingMs: Long? = null   // milliseconds
    ) {
        fun toMap(): Map<String, Any?> = buildMap {
            put("taskId", taskId)
            put("progress", progress)
            if (message != null) put("message", message)
            if (currentStep != null) put("currentStep", currentStep)
            if (totalSteps != null) put("totalSteps", totalSteps)
            if (bytesDownloaded != null) put("bytesDownloaded", bytesDownloaded)
            if (totalBytes != null) put("totalBytes", totalBytes)
            if (networkSpeed != null) put("networkSpeed", networkSpeed)
            if (timeRemainingMs != null) put("timeRemainingMs", timeRemainingMs)
        }

        fun toJson(): String {
            val obj = org.json.JSONObject()
            obj.put("taskId", taskId)
            obj.put("progress", progress)
            obj.put("message", message)
            obj.put("currentStep", currentStep)
            obj.put("totalSteps", totalSteps)
            obj.put("bytesDownloaded", bytesDownloaded)
            obj.put("totalBytes", totalBytes)
            obj.put("networkSpeed", networkSpeed)
            obj.put("timeRemainingMs", timeRemainingMs)
            return obj.toString()
        }
    }

    private const val PROGRESS_BUFFER_CAPACITY = 64
    private val lastEmittedUpdates = java.util.concurrent.ConcurrentHashMap<String, ProgressUpdate>()
    private val lastPersistedProgress = java.util.concurrent.ConcurrentHashMap<String, Int>()

    fun getRunningProgress(): Map<String, Map<String, Any?>> {
        return lastEmittedUpdates.mapValues { it.value.toMap() }
    }

    private val _progressFlow = MutableSharedFlow<ProgressUpdate>(
        replay = 1,
        extraBufferCapacity = PROGRESS_BUFFER_CAPACITY,
        onBufferOverflow = kotlinx.coroutines.channels.BufferOverflow.DROP_OLDEST
    )

    val progressFlow: SharedFlow<ProgressUpdate> = _progressFlow.asSharedFlow()

    suspend fun reportProgress(
        taskId: String,
        progress: Int,
        message: String? = null,
        currentStep: Int? = null,
        totalSteps: Int? = null
    ) {
        reportProgressNonBlocking(
            taskId = taskId,
            progress = progress,
            message = message,
            currentStep = currentStep,
            totalSteps = totalSteps
        )
    }

    fun reportProgressNonBlocking(
        taskId: String,
        progress: Int,
        message: String? = null,
        currentStep: Int? = null,
        totalSteps: Int? = null,
        bytesDownloaded: Long? = null,
        totalBytes: Long? = null,
        networkSpeed: Double? = null,
        timeRemainingMs: Long? = null
    ): Boolean {
        val clampedProgress = progress.coerceIn(0, 100)

        // 1 % throttle for emitting to Dart
        val lastUpdate = lastEmittedUpdates[taskId]
        if (lastUpdate != null && clampedProgress != 100 && kotlin.math.abs(clampedProgress - lastUpdate.progress) < 1) {
            return false
        }

        val update = ProgressUpdate(
            taskId = taskId,
            progress = clampedProgress,
            message = message,
            currentStep = currentStep,
            totalSteps = totalSteps,
            bytesDownloaded = bytesDownloaded,
            totalBytes = totalBytes,
            networkSpeed = networkSpeed,
            timeRemainingMs = timeRemainingMs
        )

        lastEmittedUpdates[taskId] = update

        // 1. Automatic Notifications
        context?.let { ctx ->
            taskNotifTitles[taskId]?.let { title ->
                dev.brewkits.native_workmanager.notification.DownloadNotificationManager.showProgress(
                    context = ctx,
                    taskId = taskId,
                    title = title,
                    progress = clampedProgress,
                    message = message,
                    filename = taskFilenames[taskId],
                    allowPause = taskAllowPause[taskId] ?: true
                )
            }
        }

        // 2. Persistent Progress (5% throttle)
        val lastPersisted = lastPersistedProgress[taskId]
        if (lastPersisted == null || clampedProgress == 100 || kotlin.math.abs(clampedProgress - lastPersisted) >= 5) {
            lastPersistedProgress[taskId] = clampedProgress
            taskStore?.updateProgress(taskId, update.toJson())
        }

        return try {
            val emitted = _progressFlow.tryEmit(update)
            if (emitted) {
                Log.d(TAG, "Progress: $taskId - $clampedProgress%${message?.let { " - $it" } ?: ""}")
            }
            emitted
        } catch (e: Exception) {
            Log.w(TAG, "Failed to emit progress: ${e.message}")
            false
        }
    }

    suspend fun reportStep(
        taskId: String,
        currentStep: Int,
        totalSteps: Int,
        message: String? = null
    ) {
        val progress = if (totalSteps > 0) {
            ((currentStep.toFloat() / totalSteps.toFloat()) * 100).toInt()
        } else {
            0
        }

        reportProgress(
            taskId = taskId,
            progress = progress,
            message = message,
            currentStep = currentStep,
            totalSteps = totalSteps
        )
    }

    fun clearTask(taskId: String) {
        lastEmittedUpdates.remove(taskId)
        lastPersistedProgress.remove(taskId)
        taskNotifTitles.remove(taskId)
        taskFilenames.remove(taskId)
        taskAllowPause.remove(taskId)
    }
}
