package dev.brewkits.native_workmanager.workers

import android.content.Context
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerEnvironment
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.NativeLogger
import dev.brewkits.native_workmanager.store.ChainStore
import org.json.JSONObject

/**
 * Decorator SimpleAndroidWorkerFactory wraps every worker it creates in.
 *
 * issue_57: `BaseKmpWorker` (kmpworkmanager core) hands control back to WorkManager via a
 * bare `Result.success()`, so `WorkInfo.outputData` is always empty — there is no
 * WorkManager-native channel carrying a chain step's real output data forward to the next
 * step. This decorator captures it a different way: after the delegate worker returns, if
 * the result carries data AND the task belongs to a chain (identified by the `__taskId`
 * that [dev.brewkits.native_workmanager.utils.ChainHelper] injects into the input JSON),
 * the raw output is written straight into [ChainStore] — synchronously, before `doWork()`
 * returns, so the write always completes while the process is provably still alive. No
 * dependency on any event bus's timing or on WorkManager's Data-size limits.
 *
 * A no-op for standalone (non-chain) tasks and for any input without `__taskId`.
 */
internal class ChainResultCapturingWorker(
    private val delegate: AndroidWorker,
    private val context: Context,
) : AndroidWorker {

    override suspend fun doWork(input: String?, env: WorkerEnvironment): WorkerResult {
        val result = delegate.doWork(input, env)

        val data = (result as? WorkerResult.Success)?.data
        if (data == null || input == null) return result

        val taskId = extractTaskId(input) ?: return result
        try {
            val chainStore = ChainStore(context)
            val chainId = chainStore.getChainForTaskId(taskId)?.chainId ?: return result
            chainStore.updateStepStatus(chainId, taskId, "completed", data.toString())
        } catch (e: Exception) {
            NativeLogger.e("ChainResultCapturingWorker: failed to persist output for '$taskId'", e)
        }

        return result
    }

    private fun extractTaskId(input: String): String? = try {
        JSONObject(input).optString("__taskId").takeIf { it.isNotEmpty() }
    } catch (_: Exception) {
        null
    }
}
