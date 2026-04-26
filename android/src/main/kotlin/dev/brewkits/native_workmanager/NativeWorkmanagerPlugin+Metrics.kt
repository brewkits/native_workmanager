package dev.brewkits.native_workmanager

import dev.brewkits.native_workmanager.utils.CommandProcessor
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

// ── Metrics and offline-queue sync handlers. ─────────────────────────────────

/**
 * Returns aggregate metrics from the task store, chain store, and offline queue.
 */
internal fun NativeWorkmanagerPlugin.handleGetMetrics(result: Result) {
    ioScope.launch {
        try {
            val activeTasks = taskStore.getActiveTaskCount()
            val offlineQueueSize = offlineQueueStore.getQueueSize()
            val failedTasks = taskStore.getFailedTaskCount()
            val completedTasks = taskStore.getCompletedTaskCount()

            val activeChains = chainStore.getPendingChains()
            val dagNodes = mutableListOf<Map<String, Any?>>()

            activeChains.forEach { chain ->
                val steps = chainStore.getStepsForChain(chain.chainId)
                steps.forEach { step ->
                    dagNodes.add(
                        mapOf(
                            "id" to step.taskId,
                            "label" to step.taskId.take(8),
                            "status" to step.status,
                            "chainId" to chain.chainId,
                            "stepIndex" to step.stepIndex,
                        ),
                    )
                }
            }

            val metrics = mapOf(
                "activeTasks" to activeTasks,
                "offlineQueueSize" to offlineQueueSize,
                "failedTasks" to failedTasks,
                "completedTasks" to completedTasks,
                "dagNodes" to dagNodes,
            )

            withContext(Dispatchers.Main) {
                result.success(metrics)
            }
        } catch (e: Exception) {
            withContext(Dispatchers.Main) {
                result.error("METRICS_ERROR", e.message, null)
            }
        }
    }
}

/**
 * Triggers immediate offline-queue processing (fires the background processor).
 */
internal fun NativeWorkmanagerPlugin.handleSyncOfflineQueue(result: Result) {
    try {
        CommandProcessor.scheduleOfflineQueueProcessor(context)
        result.success(true)
    } catch (e: Exception) {
        result.error("SYNC_ERROR", e.message, null)
    }
}
