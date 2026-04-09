package dev.brewkits.native_workmanager.workers

import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.AppContextHolder
import dev.brewkits.native_workmanager.NativeLogger
import dev.brewkits.native_workmanager.store.TaskStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Internal maintenance worker: periodic SQLite task-record cleanup.
 *
 * Deletes terminal-state records (completed / failed / cancelled) that are
 * older than [RETENTION_MS] (default 30 days) to prevent unbounded database
 * growth over the lifetime of the app.
 *
 * This worker is registered automatically at [NativeWorkManager.initialize] as a
 * weekly [androidx.work.PeriodicWorkRequest] using [ExistingPeriodicWorkPolicy.KEEP]
 * so that re-initialisation never resets the schedule.
 *
 * The worker is **not** exposed to Dart callers — it is purely internal to the
 * plugin and will never appear in [NativeWorkManager.getAllTasks] results.
 */
internal class DbCleanupWorker : AndroidWorker {

    companion object {
        /** Unique WorkManager task ID for the cleanup job. Internal, never exposed to Dart. */
        const val TASK_ID = "__native_wm_db_cleanup__"

        /** Records older than this threshold are eligible for deletion (30 days). */
        private const val RETENTION_MS = 30L * 24 * 60 * 60 * 1000L
    }

    override suspend fun doWork(input: String?, env: dev.brewkits.kmpworkmanager.background.domain.WorkerEnvironment): WorkerResult = withContext(Dispatchers.IO) {
        return@withContext try {
            val context = AppContextHolder.appContext
            val store = TaskStore(context)
            store.deleteCompleted(olderThanMs = RETENTION_MS)
            NativeLogger.d("🗑️ DbCleanupWorker: pruned task records older than 30 days")
            WorkerResult.Success()
        } catch (e: Exception) {
            NativeLogger.e("DbCleanupWorker error", e)
            // Don't fail permanently — WorkManager will retry on next schedule cycle.
            WorkerResult.Failure(e.message ?: "Retry", shouldRetry = true)
        }
    }
}
