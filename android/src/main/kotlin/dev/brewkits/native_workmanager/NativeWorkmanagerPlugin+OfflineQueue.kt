package dev.brewkits.native_workmanager

import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import dev.brewkits.native_workmanager.store.OfflineQueueStore
import dev.brewkits.native_workmanager.utils.MappingUtils.toJson
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

internal fun NativeWorkmanagerPlugin.handleOfflineQueueEnqueue(call: MethodCall, result: Result) {
    scope.launch {
        try {
            val queueId = call.argument<String>("queueId")
                ?: return@launch result.error("INVALID_ARGS", "queueId required", null)
            val entryMap = call.argument<Map<String, Any?>>("entry")
                ?: return@launch result.error("INVALID_ARGS", "entry required", null)

            val taskId = entryMap["taskId"] as String
            val workerClassName = entryMap["workerClassName"] as String
            val workerConfig = entryMap["workerConfig"] as? Map<String, Any?>
            val retryPolicyMap = entryMap["retryPolicy"] as? Map<String, Any?>

            val configJson = if (workerConfig != null) toJson(workerConfig) else null
            val retryPolicyJson = if (retryPolicyMap != null) toJson(retryPolicyMap) else null

            NativeLogger.d("📥 Enqueuing to native OfflineQueue '$queueId': $taskId")

            withContext(Dispatchers.IO) {
                offlineQueueStore.enqueue(
                    queueId = queueId,
                    taskId = taskId,
                    workerClassName = workerClassName,
                    workerConfig = configJson,
                    retryPolicy = retryPolicyJson
                )
            }

            // Schedule the processor to run when network is available
            dev.brewkits.native_workmanager.utils.CommandProcessor.scheduleOfflineQueueProcessor(context)

            result.success(null)
        } catch (e: Exception) {
            NativeLogger.e("❌ Offline queue enqueue error", e)
            result.error("OFFLINE_QUEUE_ERROR", e.message, null)
        }
    }
}
