package dev.brewkits.native_workmanager.utils

import android.content.Context
import androidx.work.Data
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import dev.brewkits.kmpworkmanager.background.data.KmpHeavyWorker
import dev.brewkits.kmpworkmanager.background.data.KmpWorker
import dev.brewkits.kmpworkmanager.background.data.NativeTaskScheduler
import dev.brewkits.kmpworkmanager.background.domain.SystemConstraint
import dev.brewkits.native_workmanager.NativeLogger
import dev.brewkits.native_workmanager.applyMiddleware
import dev.brewkits.native_workmanager.store.ChainStore
import dev.brewkits.native_workmanager.store.TaskStore
import java.util.*

object ChainHelper {

    internal suspend fun enqueueChain(
        context: Context,
        taskStore: TaskStore,
        chainStore: ChainStore,
        chainName: String,
        steps: List<List<Map<String, Any?>>>,
        onObserveTaskId: ((String) -> Unit)? = null
    ): String {
        if (steps.isEmpty() || steps[0].isEmpty()) {
            throw IllegalArgumentException("Chain must have at least one task")
        }

        val chainId = "${chainName}_${UUID.randomUUID()}"
        val workManager = WorkManager.getInstance(context)
        val allTaskIds = mutableListOf<String>()

        // Build OneTimeWorkRequest for each step tagged with its task ID.
        val stepWorkRequests: List<List<OneTimeWorkRequest>> = steps.mapIndexed { stepIndex, parallelTasks ->
            parallelTasks.map { taskData ->
                val taskId = taskData["id"] as? String ?: UUID.randomUUID().toString()
                allTaskIds.add(taskId)
                
                val workerClassName = taskData["workerClassName"] as? String ?: ""
                @Suppress("UNCHECKED_CAST")
                val workerConfig = taskData["workerConfig"] as? Map<String, Any?>
                
                // Persist each step to ChainStore for resume and Dart visibility.
                chainStore.addChainStep(chainId, stepIndex, taskId, "pending")
                
                // Also persist to TaskStore so allTasks() surfaces chain nodes
                val inputJson = if (workerConfig != null) MappingUtils.toJson(workerConfig) else null
                taskStore.upsert(
                    taskId = taskId,
                    tag = chainName,
                    status = "pending",
                    workerClassName = workerClassName,
                    workerConfig = TaskStore.sanitizeConfig(inputJson)
                )
                
                buildChainStepRequest(context, taskId, taskData)
            }
        }

        // Persist chain header BEFORE enqueuing (so resume can find it even if killed immediately).
        chainStore.upsertChain(
            chainId = chainId,
            chainName = chainName,
            totalSteps = steps.size,
            status = "running"
        )

        // Enqueue as a WorkManager chain.
        var continuation = workManager.beginWith(stepWorkRequests[0])
        for (i in 1 until stepWorkRequests.size) {
            continuation = continuation.then(stepWorkRequests[i])
        }
        continuation.enqueue()

        NativeLogger.d("✅ Chain scheduled: $chainName/$chainId (${steps.size} steps), IDs: $allTaskIds")

        if (onObserveTaskId != null) {
            for (taskId in allTaskIds) {
                onObserveTaskId(taskId)
            }
        }

        return chainId
    }

    private fun buildChainStepRequest(context: Context, taskId: String, taskData: Map<String, Any?>): OneTimeWorkRequest {
        val workerClassName = taskData["workerClassName"] as? String ?: ""
        @Suppress("UNCHECKED_CAST")
        val workerConfig = taskData["workerConfig"] as? Map<String, Any?>
        
        val inputJson: String? = when {
            workerConfig == null -> null
            workerConfig["workerType"] == "custom" -> workerConfig["input"] as? String
            else -> {
                val enrichedConfig = workerConfig.toMutableMap()
                if (taskId.isNotEmpty()) enrichedConfig["__taskId"] = taskId
                val json = MappingUtils.toJson(enrichedConfig)
                // Apply middleware
                applyMiddleware(context, workerClassName, json)
            }
        }
        @Suppress("UNCHECKED_CAST")
        val constraintsMap = taskData["constraints"] as? Map<String, Any?>
        val constraints = MappingUtils.parseConstraints(constraintsMap)

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
            .addTag(taskId)
            .addTag(workerClassName)
            .build()
    }
}
