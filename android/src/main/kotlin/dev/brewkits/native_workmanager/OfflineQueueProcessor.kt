package dev.brewkits.native_workmanager

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import dev.brewkits.kmpworkmanager.background.data.KmpWorker
import dev.brewkits.native_workmanager.store.OfflineQueueStore
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
                    // Try to enqueue each entry as a regular native work request
                    // We use enqueueOneTimeWorkDirect (copied logic or call helper)
                    enqueueEntry(applicationContext, entry)
                    
                    // If successfully enqueued to WorkManager, remove from offline queue
                    store.deleteEntry(entry.id)
                    NativeLogger.d("✅ OfflineQueueProcessor: Task ${entry.taskId} moved to WorkManager")
                } catch (e: Exception) {
                    NativeLogger.e("❌ OfflineQueueProcessor: Failed to move task ${entry.taskId}", e)
                    // Keep in queue for next run
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
            dataBuilder.putString("inputJson", entry.workerConfig)
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
