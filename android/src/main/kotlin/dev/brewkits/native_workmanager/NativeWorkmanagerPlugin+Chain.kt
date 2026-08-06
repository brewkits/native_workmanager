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
                onObserveTaskId = { taskId, chainId ->
                    taskStatuses[taskId] = "pending"
                    // issue_57: pass the real chainId (was `null`) so observeChainStepCompletion
                    // can persist step status/advance the chain on the live path, not only on
                    // resume. Previously chain_steps.status never left "pending" during live
                    // execution because this branch was skipped.
                    observeChainStepCompletion(taskId, chainId = chainId)
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
 * Resume chains that were in-progress when the app was killed.
 *
 * issue_57: under the dynamic per-step enqueue model (see ChainHelper.enqueueChain), only
 * [ChainStore.ChainRecord.currentStep] and earlier steps were ever actually handed to
 * WorkManager — later steps exist as "pending" rows in ChainStore but nothing enqueued them
 * yet. So only currentStep is re-driven here; re-observing a not-yet-reached step would just
 * watch a WorkInfo tag that will never appear until its turn comes.
 */
internal suspend fun NativeWorkmanagerPlugin.resumePendingChains() {
    try {
        val pending = withContext(Dispatchers.IO) { chainStore.getPendingChains() }
        if (pending.isEmpty()) return
        NativeLogger.d("Resuming ${pending.size} pending chain(s) from ChainStore")
        for (chain in pending) {
            withContext(Dispatchers.IO) { resumeChainAtCurrentStep(chain) }
        }
    } catch (e: Exception) {
        NativeLogger.e("resumePendingChains failed", e)
    }
}

/**
 * Three cases at [chain]'s currentStep:
 *  - Any task already "failed": the FAILED branch's chain-level status write didn't land
 *    before the process died — finish it now.
 *  - Every task already "completed": the app died in the narrow window between the last
 *    task finishing and [advanceChainIfStepComplete] running — catch up by re-driving it,
 *    rather than leaving the chain stuck forever.
 *  - Otherwise (still in flight, or the app died mid-enqueue of a parallel step so some
 *    tasks were never actually given to WorkManager): re-drive
 *    [ChainHelper.buildAndEnqueueStep] for this step. That's safe to call again even for
 *    tasks that already made it to WorkManager — it enqueues via `enqueueUniqueWork(...,
 *    KEEP)`, so already-enqueued work is left untouched and only genuinely-missed tasks get
 *    enqueued.
 */
private suspend fun NativeWorkmanagerPlugin.resumeChainAtCurrentStep(chain: dev.brewkits.native_workmanager.store.ChainStore.ChainRecord) {
    val stepTasks = chainStore.getStepsForChain(chain.chainId).filter { it.stepIndex == chain.currentStep }
    if (stepTasks.isEmpty()) {
        NativeLogger.w("resumeChainAtCurrentStep '${chain.chainId}': no step records at currentStep=${chain.currentStep}")
        return
    }

    if (stepTasks.any { it.status == "failed" }) {
        chainStore.updateChainStatus(chain.chainId, "failed")
        return
    }

    if (stepTasks.all { it.status == "completed" }) {
        advanceChainIfStepComplete(chain.chainId, stepTasks.first().taskId)
        return
    }

    val enqueued = dev.brewkits.native_workmanager.utils.ChainHelper.buildAndEnqueueStep(
        context = context,
        chainStore = chainStore,
        chainId = chain.chainId,
        stepIndex = chain.currentStep,
        // Recompute from the preceding step's persisted results rather than assume empty —
        // this step may include a task that was never actually enqueued (crash mid-loop in a
        // parallel step) and genuinely needs it. A no-op for tasks already enqueued: KEEP
        // leaves their original (already-substituted) request untouched.
        substitutionData = substitutionDataFromStep(chain.chainId, chain.currentStep - 1),
        onObserveTaskId = { taskId -> taskStatuses[taskId] = "pending" },
    )
    enqueued.forEach { taskId -> observeChainStepCompletion(taskId, chain.chainId) }
    NativeLogger.d("  Chain '${chain.chainName}' (${chain.chainId}): re-attached step ${chain.currentStep} (${enqueued.size} task id(s))")
}

/**
 * Observe a single chain step by its task-ID tag and emit an event when it reaches a terminal state.
 * Uses getWorkInfosByTagFlow keyed on the per-task tag, not getWorkInfosForUniqueWorkFlow —
 * even though each chain-step task IS now enqueued via enqueueUniqueWork(taskId, KEEP, ...)
 * for idempotent resume (see ChainHelper.buildAndEnqueueStep), tag-based lookup is what this
 * call site already keys everything else off of, and both resolve to the same single WorkInfo
 * for a chain-step taskId.
 * [chainId] is used to persist step status to ChainStore (null = legacy calls without persistence).
 */
