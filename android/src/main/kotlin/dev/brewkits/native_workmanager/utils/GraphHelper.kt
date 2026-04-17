package dev.brewkits.native_workmanager.utils

import android.content.Context
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkContinuation
import androidx.work.WorkManager
import dev.brewkits.kmpworkmanager.background.data.KmpHeavyWorker
import dev.brewkits.kmpworkmanager.background.data.KmpWorker
import dev.brewkits.kmpworkmanager.background.data.NativeTaskScheduler
import dev.brewkits.kmpworkmanager.background.domain.BackoffPolicy
import dev.brewkits.native_workmanager.NativeLogger
import dev.brewkits.native_workmanager.applyMiddleware
import dev.brewkits.native_workmanager.store.TaskStore
import dev.brewkits.native_workmanager.utils.MappingUtils.toJson
import dev.brewkits.native_workmanager.utils.MappingUtils.parseConstraints
import java.util.concurrent.TimeUnit

object GraphHelper {
    
    internal suspend fun enqueueGraph(
        context: Context,
        taskStore: TaskStore,
        graphMap: Map<String, Any?>,
        onObserveTaskId: (String) -> Unit
    ): String {
        val graphId = graphMap["id"] as? String ?: throw IllegalArgumentException("graph id required")
        @Suppress("UNCHECKED_CAST")
        val nodeMaps = graphMap["nodes"] as? List<Map<String, Any?>> ?: throw IllegalArgumentException("nodes required")

        NativeLogger.d("🕸️ Enqueuing native TaskGraph '$graphId' with ${nodeMaps.size} nodes")

        val workManager = WorkManager.getInstance(context)
        val nodeRequests = mutableMapOf<String, OneTimeWorkRequest>()
        val nodeMap = mutableMapOf<String, Map<String, Any?>>()
        
        // 1. Create all WorkRequests first
        for (nodeData in nodeMaps) {
            val nodeId = nodeData["id"] as String
            val workerClassName = nodeData["workerClassName"] as String
            val workerConfig = nodeData["workerConfig"] as? Map<String, Any?>
            val constraintsMap = nodeData["constraints"] as? Map<String, Any?>
            
            // Using MappingUtils for static access to parsing logic
            val constraints = MappingUtils.parseConstraints(constraintsMap)
            
            nodeMap[nodeId] = nodeData

            val taskId = "${graphId}__$nodeId"
            val inputJson = if (workerConfig != null) {
                val enrichedConfig = workerConfig.toMutableMap()
                enrichedConfig["__taskId"] = taskId
                val json = MappingUtils.toJson(enrichedConfig)
                // Apply middleware
                applyMiddleware(context, workerClassName, json)
            } else null

            // Persist to store
            taskStore.upsert(
                taskId = taskId,
                tag = graphId,
                status = "pending",
                workerClassName = workerClassName,
                workerConfig = TaskStore.sanitizeConfig(inputJson)
            )

            val workerClass = if (constraints.isHeavyTask) KmpHeavyWorker::class.java else KmpWorker::class.java
            val dataBuilder = androidx.work.Data.Builder()
                .putString("workerClassName", workerClassName)
            if (inputJson != null) dataBuilder.putString("inputJson", inputJson)

            val wmConstraints = androidx.work.Constraints.Builder()
                .setRequiredNetworkType(when {
                    constraints.requiresUnmeteredNetwork -> androidx.work.NetworkType.UNMETERED
                    constraints.requiresNetwork -> androidx.work.NetworkType.CONNECTED
                    else -> androidx.work.NetworkType.NOT_REQUIRED
                })
                .setRequiresCharging(constraints.requiresCharging)
                .build()

            val request = OneTimeWorkRequest.Builder(workerClass)
                .setConstraints(wmConstraints)
                .setInputData(dataBuilder.build())
                .addTag(NativeTaskScheduler.TAG_KMP_TASK)
                .addTag(graphId)
                .addTag(taskId)
                .addTag(workerClassName)
                .setBackoffCriteria(
                    if (constraints.backoffPolicy == BackoffPolicy.LINEAR) 
                        androidx.work.BackoffPolicy.LINEAR 
                    else 
                        androidx.work.BackoffPolicy.EXPONENTIAL,
                    constraints.backoffDelayMs,
                    TimeUnit.MILLISECONDS
                )
                .build()

            nodeRequests[nodeId] = request
            onObserveTaskId(taskId)
        }

        // 2. Detect cycles
        fun hasCycle(nodeId: String, visited: MutableSet<String>, stack: MutableSet<String>): Boolean {
            if (stack.contains(nodeId)) return true
            if (visited.contains(nodeId)) return false
            visited.add(nodeId)
            stack.add(nodeId)
            @Suppress("UNCHECKED_CAST")
            val deps = nodeMap[nodeId]?.get("dependsOn") as? List<String> ?: emptyList()
            for (dep in deps) {
                if (hasCycle(dep, visited, stack)) return true
            }
            stack.remove(nodeId)
            return false
        }
        val cycleVisited = mutableSetOf<String>()
        for (id in nodeMap.keys) {
            if (hasCycle(id, cycleVisited, mutableSetOf())) {
                throw IllegalStateException("Cycle detected in task graph '$graphId'")
            }
        }

        // 3. Build continuations
        val continuations = mutableMapOf<String, WorkContinuation>()

        fun getContinuation(nodeId: String): WorkContinuation {
            continuations[nodeId]?.let { return it }

            val nodeData = nodeMap[nodeId]!!
            @Suppress("UNCHECKED_CAST")
            val dependsOn = nodeData["dependsOn"] as? List<String> ?: emptyList()
            val request = nodeRequests[nodeId]!!

            val continuation = if (dependsOn.isEmpty()) {
                workManager.beginWith(request)
            } else {
                val parentContinuations = dependsOn.map { getContinuation(it) }
                if (parentContinuations.size == 1) {
                    parentContinuations[0].then(request)
                } else {
                    WorkContinuation.combine(parentContinuations).then(request)
                }
            }

            continuations[nodeId] = continuation
            return continuation
        }

        // 4. Enqueue leaf nodes
        val allDependencies = nodeMaps.flatMap { it["dependsOn"] as? List<String> ?: emptyList() }.toSet()
        val leafNodeIds = nodeMap.keys.filter { it !in allDependencies }

        for (leafId in leafNodeIds) {
            getContinuation(leafId).enqueue()
        }

        return graphId
    }
}
