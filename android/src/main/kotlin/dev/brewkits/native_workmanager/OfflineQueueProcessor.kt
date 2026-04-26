package dev.brewkits.native_workmanager

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import dev.brewkits.kmpworkmanager.background.data.KmpWorker
import dev.brewkits.native_workmanager.store.OfflineQueueStore
import dev.brewkits.native_workmanager.utils.CommandProcessor.scheduleOfflineQueueProcessor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

/**
 * Background worker that processes the offline queue when network is available.
 */
class OfflineQueueProcessor(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            val store = OfflineQueueStore(applicationContext)
            var entries = store.getNextEntries(limit = 20)

            if (entries.isEmpty()) {
                return@withContext Result.success()
            }

            NativeLogger.d("🔄 OfflineQueueProcessor: Processing ${entries.size} entries")

            for (entry in entries) {
                try {
                    enqueueEntry(applicationContext, entry)
                    store.deleteEntry(entry.id)
                    NativeLogger.d("✅ OfflineQueueProcessor: Task ${entry.taskId} moved to WorkManager")
                } catch (e: Exception) {
                    // Enqueue failures (bad format, oversized payload) are not transient —
                    // retrying the same entry indefinitely would cause an infinite loop that
                    // drains the battery. Discard and move on.
                    NativeLogger.e("❌ OfflineQueueProcessor: Discarding unrecoverable entry ${entry.taskId}", e)
                    store.deleteEntry(entry.id)
                }
            }

            // Check if there's more
            entries = store.getNextEntries(limit = 1)
            if (entries.isNotEmpty()) {
                // Re-schedule to continue processing
                scheduleOfflineQueueProcessor(applicationContext)
            }

            Result.success()
        } catch (e: Exception) {
            NativeLogger.e("❌ OfflineQueueProcessor error", e)
            Result.retry()
        }
    }

    private fun enqueueEntry(context: Context, entry: OfflineQueueStore.QueueRecord) {
        // Build a OneTimeWorkRequest for the actual worker
        val workerClass = KmpWorker::class.java
        
        val dataBuilder = androidx.work.Data.Builder()
            .putString("workerClassName", entry.workerClassName)
        
        if (entry.workerConfig != null) {
            val payloadBytes = entry.workerConfig.toByteArray(Charsets.UTF_8)
            if (payloadBytes.size > 10 * 1024) {
                val spillFile = java.io.File(context.cacheDir, "wm_spill_${entry.taskId}.json")
                spillFile.writeText(entry.workerConfig, Charsets.UTF_8)
                dataBuilder.putString("inputJsonFile", spillFile.absolutePath)
            } else {
                dataBuilder.putString("inputJson", entry.workerConfig)
            }
        }

        // Parse retry policy to apply constraints
        val constraintsBuilder = androidx.work.Constraints.Builder()
        if (entry.retryPolicy != null) {
            val policy = JSONObject(entry.retryPolicy)
            if (policy.optBoolean("requiresNetwork", true)) {
                constraintsBuilder.setRequiredNetworkType(androidx.work.NetworkType.CONNECTED)
            }
            if (policy.optBoolean("requiresCharging", false)) {
                constraintsBuilder.setRequiresCharging(true)
            }
        }

        val request = androidx.work.OneTimeWorkRequest.Builder(workerClass)
            .setConstraints(constraintsBuilder.build())
            .setInputData(dataBuilder.build())
            .addTag("offline_queue_item")
            .addTag(entry.taskId)
            .addTag(entry.workerClassName)
            .build()

        androidx.work.WorkManager.getInstance(context).enqueueUniqueWork(
            entry.taskId,
            androidx.work.ExistingWorkPolicy.REPLACE,
            request
        )
    }
}
