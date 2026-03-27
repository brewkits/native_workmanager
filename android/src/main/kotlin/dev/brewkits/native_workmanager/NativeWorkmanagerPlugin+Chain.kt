package dev.brewkits.native_workmanager

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

            if (steps.isEmpty() || steps[0].isEmpty()) {
                return@launch result.error("CHAIN_ERROR", "Chain must have at least one task", null)
            }

            val chainId = "${chainName}_${java.util.UUID.randomUUID()}"
            val workManager = WorkManager.getInstance(context)
            val allTaskIds = mutableListOf<String>()

            // Build OneTimeWorkRequest for each step tagged with its task ID.
            val stepWorkRequests: List<List<OneTimeWorkRequest>> = steps.mapIndexed { stepIndex, parallelTasks ->
                @Suppress("UNCHECKED_CAST")
                (parallelTasks as List<Map<String, Any?>>).map { taskData ->
                    val taskId = taskData["id"] as? String ?: java.util.UUID.randomUUID().toString()
                    allTaskIds.add(taskId)
                    // Persist each step to ChainStore for resume and Dart visibility.
                    withContext(Dispatchers.IO) {
                        chainStore.addChainStep(chainId, stepIndex, taskId, "pending")
                    }
                    buildChainStepRequest(taskId, taskData)
                }
            }

            // Persist chain header BEFORE enqueuing (so resume can find it even if killed immediately).
            withContext(Dispatchers.IO) {
                chainStore.upsertChain(
                    chainId = chainId,
                    chainName = chainName,
                    totalSteps = steps.size,
                    status = "running"
                )
            }

            // Enqueue as a WorkManager chain.
            var continuation = workManager.beginWith(stepWorkRequests[0])
            for (i in 1 until stepWorkRequests.size) {
                continuation = continuation.then(stepWorkRequests[i])
            }
            continuation.enqueue()

            NativeLogger.d("✅ Chain scheduled: $chainName/$chainId (${steps.size} steps), IDs: $allTaskIds")

            // Observe each chain step by its task-ID tag and emit events on completion.
            for (taskId in allTaskIds) {
                taskStatuses[taskId] = "pending"
                observeChainStepCompletion(taskId, chainId = chainId)
            }

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
 * Build a OneTimeWorkRequest for a single chain step.
 * The task ID is added as a WorkManager tag so we can observe by tag later.
 */
internal fun NativeWorkmanagerPlugin.buildChainStepRequest(taskId: String, taskData: Map<String, Any?>): OneTimeWorkRequest {
    val workerClassName = taskData["workerClassName"] as? String ?: ""
    @Suppress("UNCHECKED_CAST")
    val workerConfig = taskData["workerConfig"] as? Map<String, Any?>
    // Custom workers (NativeWorker.custom) carry user data under "input" key as a
    // pre-encoded JSON string. Pass that directly so the custom worker receives its
    // own fields — matching handleEnqueue and iOS executeWorkerSync behaviour.
    // Built-in workers receive the full config enriched with __taskId for progress.
    val inputJson: String? = when {
        workerConfig == null -> null
        workerConfig["workerType"] == "custom" -> workerConfig["input"] as? String
        else -> {
            val enrichedConfig = workerConfig.toMutableMap()
            if (taskId.isNotEmpty()) enrichedConfig["__taskId"] = taskId
            toJson(enrichedConfig)
        }
    }
    @Suppress("UNCHECKED_CAST")
    val constraintsMap = taskData["constraints"] as? Map<String, Any?>
    val constraints = parseConstraints(constraintsMap)

    val dataBuilder = Data.Builder().putString("workerClassName", workerClassName)
    if (inputJson != null) dataBuilder.putString("inputJson", inputJson)

    val networkType = when {
        constraints.requiresUnmeteredNetwork -> NetworkType.UNMETERED
        constraints.requiresNetwork -> NetworkType.CONNECTED
        else -> NetworkType.NOT_REQUIRED
    }
    val wmConstraintsBuilder = androidx.work.Constraints.Builder()
        .setRequiredNetworkType(networkType)
        .setRequiresCharging(constraints.requiresCharging)
    val sysConstraints = constraints.systemConstraints ?: emptySet()
    if (sysConstraints.contains(SystemConstraint.DEVICE_IDLE)) wmConstraintsBuilder.setRequiresDeviceIdle(true)
    if (sysConstraints.contains(SystemConstraint.REQUIRE_BATTERY_NOT_LOW)) wmConstraintsBuilder.setRequiresBatteryNotLow(true)

    val workerClass = if (constraints.isHeavyTask) KmpHeavyWorker::class.java else KmpWorker::class.java
    return OneTimeWorkRequest.Builder(workerClass)
        .setConstraints(wmConstraintsBuilder.build())
        .setInputData(dataBuilder.build())
        .addTag(NativeTaskScheduler.TAG_KMP_TASK)
        .addTag("worker-$workerClassName")
        .addTag(taskId)         // Critical: allows observeChainStepCompletion to find this work
        .addTag(workerClassName)
        .build()
}

/**
 * Observe a single chain step by its task-ID tag and emit an event when it reaches a terminal state.
 * Uses getWorkInfosByTagFlow since chain steps are NOT unique work.
 * [chainId] is used to persist step status to ChainStore (null = legacy calls without persistence).
 */
