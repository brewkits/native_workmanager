package dev.brewkits.native_workmanager

import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkContinuation
import androidx.work.WorkManager
import dev.brewkits.kmpworkmanager.background.data.KmpHeavyWorker
import dev.brewkits.kmpworkmanager.background.data.KmpWorker
import dev.brewkits.kmpworkmanager.background.data.NativeTaskScheduler
import dev.brewkits.kmpworkmanager.background.domain.*
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

internal fun NativeWorkmanagerPlugin.handleEnqueueGraph(call: MethodCall, result: Result) {
    scope.launch {
        try {
            val graphMap = call.argument<Map<String, Any?>>("graph")
                ?: return@launch result.error("INVALID_ARGS", "graph required", null)
            val graphId = graphMap["id"] as? String
                ?: return@launch result.error("INVALID_ARGS", "graph id required", null)
            @Suppress("UNCHECKED_CAST")
            val nodeMaps = graphMap["nodes"] as? List<Map<String, Any?>>
                ?: return@launch result.error("INVALID_ARGS", "nodes required", null)

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
                val constraints = parseConstraints(constraintsMap)
                
                nodeMap[nodeId] = nodeData

                val taskId = "${graphId}__$nodeId"
                val inputJson = if (workerConfig != null) {
                    val enrichedConfig = workerConfig.toMutableMap()
                    enrichedConfig["__taskId"] = taskId
                    val json = toJson(enrichedConfig)
                    // Apply middleware (Phase 2)
                    NativeWorkmanagerPlugin.applyMiddleware(context, workerClassName, json)
                } else null

                // Persist to store (same as regular enqueue)
                withContext(Dispatchers.IO) {
                    taskStore.upsert(
                        taskId = taskId,
                        tag = graphId, // Graph ID acts as a tag for all its nodes
                        status = "pending",
                        workerClassName = workerClassName,
                        workerConfig = dev.brewkits.native_workmanager.store.TaskStore.sanitizeConfig(inputJson)
                    )
                }

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
                        if (constraints.backoffPolicy == dev.brewkits.kmpworkmanager.background.domain.BackoffPolicy.LINEAR) 
                            androidx.work.BackoffPolicy.LINEAR 
                        else 
                            androidx.work.BackoffPolicy.EXPONENTIAL,
                        constraints.backoffDelayMs,
                        TimeUnit.MILLISECONDS
                    )
                    .build()

                nodeRequests[nodeId] = request
                
                // Use tag-based observation (observeChainStepCompletion) for graph nodes
                // since WorkContinuation nodes are NOT enqueued as unique work and cannot
                // be observed via getWorkInfosForUniqueWorkFlow.
                observeChainStepCompletion(taskId)
            }

            // 2. Detect cycles before building continuations — a cyclic DAG would cause
            //    infinite recursion and a StackOverflowError at runtime.
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
                    return@launch result.error("INVALID_GRAPH", "Cycle detected in task graph '$graphId'", null)
                }
            }

            // 3. Build the dependency graph using WorkContinuation.
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

            // 4. Enqueue all leaf nodes (terminal nodes of the DAG).
            // A leaf node is one that is NOT a dependency for any other node.
            val allDependencies = nodeMaps.flatMap { it["dependsOn"] as? List<String> ?: emptyList() }.toSet()
            val leafNodeIds = nodeMap.keys.filter { it !in allDependencies }

            for (leafId in leafNodeIds) {
                getContinuation(leafId).enqueue()
            }

            NativeLogger.d("✅ TaskGraph '$graphId' enqueued with ${leafNodeIds.size} terminal chains")
            result.success("ACCEPTED")
        } catch (e: Exception) {
            NativeLogger.e("❌ Enqueue graph error", e)
            result.error("ENQUEUE_GRAPH_ERROR", e.message, null)
        }
    }
}
