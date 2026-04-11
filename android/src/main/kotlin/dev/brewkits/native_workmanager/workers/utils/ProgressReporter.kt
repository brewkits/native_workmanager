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
 *
 * Usage from worker:
 * ```kotlin
 * ProgressReporter.reportProgress(
 *     taskId = "my-task",
 *     progress = 50,
 *     message = "Processing file 5 of 10",
 *     currentStep = 5,
 *     totalSteps = 10
 * )
 * ```
 */
object ProgressReporter {
    private const val TAG = "ProgressReporter"

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
        /**
         * Convert to map for Flutter EventChannel.
         */
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
    }

    /**
     * Progress update buffer capacity.
     *
     * Rationale:
     * - Average file operation = 100 progress updates
     * - Buffer allows ~1 second burst (64 updates)
     * - DROP_OLDEST strategy ensures latest progress always visible
     */
    private const val PROGRESS_BUFFER_CAPACITY = 64

    /**
     * Last emitted progress value per task.
     *
     * Guards against time-travel progress: URLSession / OkHttp callbacks can
     * fire in rapid bursts, and even 1% steps can flood the Flutter bridge
     * when downloading large files with small chunks.  By skipping updates
     * that are < 1% away from the last emitted value (except the final 100%)
     * we cut Flutter-bridge traffic by an order of magnitude on typical
     * large-file downloads without losing any meaningful UI resolution.
     */
    private val lastEmittedProgress = java.util.concurrent.ConcurrentHashMap<String, Int>()

    private val _progressFlow = MutableSharedFlow<ProgressUpdate>(
        replay = 0,
        extraBufferCapacity = PROGRESS_BUFFER_CAPACITY,
        onBufferOverflow = kotlinx.coroutines.channels.BufferOverflow.DROP_OLDEST  // FIX #2
    )

    /**
     * Flow of progress updates. Plugin should collect this and forward to Dart.
     */
    val progressFlow: SharedFlow<ProgressUpdate> = _progressFlow.asSharedFlow()

    /**
     * Report progress update (suspend version for coroutine contexts).
     *
     * @param taskId Task identifier
     * @param progress Progress percentage (0-100)
     * @param message Optional status message
     * @param currentStep Optional current step number
     * @param totalSteps Optional total steps count
     */
    suspend fun reportProgress(
        taskId: String,
        progress: Int,
        message: String? = null,
        currentStep: Int? = null,
        totalSteps: Int? = null
    ) {
        val clampedProgress = progress.coerceIn(0, 100)

        // Skip if the change is less than 1% (unless it is the final 100% sentinel).
        // Prevents flooding the Flutter bridge on fast-chunk downloads/uploads.
        val last = lastEmittedProgress[taskId]
        if (last != null && clampedProgress != 100 && kotlin.math.abs(clampedProgress - last) < 1) {
            return
        }
        lastEmittedProgress[taskId] = clampedProgress

        val update = ProgressUpdate(
            taskId = taskId,
            progress = clampedProgress,
            message = message,
            currentStep = currentStep,
            totalSteps = totalSteps
        )

        try {
            _progressFlow.emit(update)
            Log.d(TAG, "Progress: $taskId - $clampedProgress%${message?.let { " - $it" } ?: ""}")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to emit progress: ${e.message}")
        }
    }

    /**
     * Report progress update (non-blocking version for non-coroutine contexts).
     *
     * ✅ FIX #1: Use this from OkHttp callbacks to avoid blocking I/O threads.
     * This method uses tryEmit which never blocks the calling thread.
     *
     * @param taskId Task identifier
     * @param progress Progress percentage (0-100)
     * @param message Optional status message
     * @param currentStep Optional current step number
     * @param totalSteps Optional total steps count
     * @return true if progress was emitted, false if buffer is full
     */
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

        // Same 1% filter as the suspend variant.
        val last = lastEmittedProgress[taskId]
        if (last != null && clampedProgress != 100 && kotlin.math.abs(clampedProgress - last) < 1) {
            return false
        }
        lastEmittedProgress[taskId] = clampedProgress

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

        return try {
            val emitted = _progressFlow.tryEmit(update)
            if (emitted) {
                Log.d(TAG, "Progress: $taskId - $clampedProgress%${message?.let { " - $it" } ?: ""}")
            } else {
                Log.v(TAG, "Progress buffer full, dropped update for $taskId")
            }
            emitted
        } catch (e: Exception) {
            Log.w(TAG, "Failed to emit progress: ${e.message}")
            false
        }
    }

    /**
     * Report progress with step information.
     */
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
}
