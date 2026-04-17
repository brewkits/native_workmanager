package dev.brewkits.native_workmanager

import androidx.work.Data
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import dev.brewkits.kmpworkmanager.background.data.KmpHeavyWorker
import dev.brewkits.kmpworkmanager.background.data.KmpWorker
import dev.brewkits.kmpworkmanager.background.data.NativeTaskScheduler
import dev.brewkits.kmpworkmanager.background.domain.*
import dev.brewkits.native_workmanager.store.TaskStore.Companion.sanitizeConfig
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

// ── Chain enqueue, resume and step-request construction.
// ── Separated from NativeWorkmanagerPlugin.kt to reduce God Object complexity.

internal fun NativeWorkmanagerPlugin.handleEnqueueChain(call: MethodCall, result: Result) {
    scope.launch {
        try {
            val chainName = call.argument<String>("name") ?: "chain_${System.currentTimeMillis()}"
            @Suppress("UNCHECKED_CAST")
            val steps = call.argument<List<List<Map<String, Any?>>>>("steps") ?: emptyList()

            dev.brewkits.native_workmanager.utils.ChainHelper.enqueueChain(
                context = context,
                taskStore = taskStore,
                chainStore = chainStore,
                chainName = chainName,
                steps = steps,
                onObserveTaskId = { taskId ->
                    taskStatuses[taskId] = "pending"
                    observeChainStepCompletion(taskId, chainId = null) // We pass null because ChainHelper already handled ChainStore persistence
                }
            )

            result.success("ACCEPTED")
        } catch (e: Exception) {
            NativeLogger.e("❌ Chain error", e)
            result.error("CHAIN_ERROR", e.message, null)
        }
    }
}

/**
 * Resume Dart-visible chain metadata for chains that were in-progress
 * when the app was killed.  WorkManager itself already re-executes the
 * individual workers; this layer re-attaches step observers and marks
 * chain status as running so allTasks() returns accurate data.
 */
internal suspend fun NativeWorkmanagerPlugin.resumePendingChains() {
    try {
        val pending = withContext(Dispatchers.IO) { chainStore.getPendingChains() }
        if (pending.isEmpty()) return
        NativeLogger.d("Resuming ${pending.size} pending chain(s) from ChainStore")
        for (chain in pending) {
            val steps = withContext(Dispatchers.IO) { chainStore.getStepsForChain(chain.chainId) }
            for (step in steps) {
                if (step.status !in listOf("completed", "failed")) {
                    taskStatuses[step.taskId] = step.status
                    observeChainStepCompletion(step.taskId, chainId = chain.chainId)
                }
            }
            NativeLogger.d("  Chain '${chain.chainName}' (${chain.chainId}): re-observing ${steps.size} steps")
        }
    } catch (e: Exception) {
        NativeLogger.e("resumePendingChains failed", e)
    }
}

/**
 * Observe a single chain step by its task-ID tag and emit an event when it reaches a terminal state.
 * Uses getWorkInfosByTagFlow since chain steps are NOT unique work.
 * [chainId] is used to persist step status to ChainStore (null = legacy calls without persistence).
 */
