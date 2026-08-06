package dev.brewkits.native_workmanager.utils

import android.content.Context
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import dev.brewkits.kmpworkmanager.background.data.KmpHeavyWorker
import dev.brewkits.kmpworkmanager.background.data.KmpWorker
import dev.brewkits.kmpworkmanager.background.data.NativeTaskScheduler
import dev.brewkits.kmpworkmanager.background.domain.SystemConstraint
import dev.brewkits.native_workmanager.NativeLogger
import dev.brewkits.native_workmanager.applyMiddlewareInternal
import dev.brewkits.native_workmanager.store.ChainStore
import dev.brewkits.native_workmanager.store.TaskStore
import org.json.JSONObject
import java.util.*

object ChainHelper {

    /**
     * issue_57: steps are NOT all built/enqueued upfront via WorkManager's native
     * `.then()` chaining anymore. That approach freezes every step's `inputJson` into
     * `Data` before step 0 even runs, which left no point in time to substitute step N's
     * placeholders against step N-1's real output — the request was already immutable and
     * enqueued. Instead: persist every step's raw (unsanitized) task data up front, enqueue
     * only step 0 now, and enqueue each later step dynamically — see [buildAndEnqueueStep] —
     * once TaskEventBus reports the previous step's tasks have all completed
     * (NativeWorkmanagerPlugin+EventChannel.kt).
     */
    internal suspend fun enqueueChain(
        context: Context,
        taskStore: TaskStore,
        chainStore: ChainStore,
        chainName: String,
        steps: List<List<Map<String, Any?>>>,
        // (taskId, chainId) -> Unit. Takes chainId explicitly (rather than the caller reading
        // enqueueChain's return value) because this callback fires for step 0's tasks
        // synchronously *during* this call, before enqueueChain has returned anything to the
        // caller — see NativeWorkmanagerPlugin+Chain.kt's handleEnqueueChain.
        onObserveTaskId: ((String, String) -> Unit)? = null
    ): String {
        if (steps.isEmpty() || steps[0].isEmpty()) {
            throw IllegalArgumentException("Chain must have at least one task")
        }

        val chainId = "${chainName}_${UUID.randomUUID()}"
        val allTaskIds = mutableListOf<String>()

        // Persist every step's raw task data + a TaskStore visibility record for ALL steps
        // up front, whether or not they're enqueued yet. Nothing here talks to WorkManager.
        steps.forEachIndexed { stepIndex, parallelTasks ->
            parallelTasks.forEach { taskData ->
                val taskId = taskData["id"] as? String ?: UUID.randomUUID().toString()
                allTaskIds.add(taskId)

                val workerClassName = taskData["workerClassName"] as? String ?: ""
                @Suppress("UNCHECKED_CAST")
                val workerConfig = taskData["workerConfig"] as? Map<String, Any?>

                // task_data_json is the unsanitized source of truth used later to build this
                // step's WorkRequest dynamically (see buildAndEnqueueStep). Persist it before
                // TaskStore's sanitized copy so a crash between the two can't lose it.
                chainStore.addChainStep(
                    chainId, stepIndex, taskId, "pending",
                    taskDataJson = MappingUtils.toJson(taskData)
                )

                // Also persist a sanitized copy to TaskStore so allTasks() surfaces chain nodes.
                val inputJson = if (workerConfig != null) MappingUtils.toJson(workerConfig) else null
                taskStore.upsert(
                    taskId = taskId,
                    tag = chainName,
                    status = "pending",
                    workerClassName = workerClassName,
                    workerConfig = TaskStore.sanitizeConfig(inputJson)
                )
            }
        }

        // Persist chain header BEFORE enqueuing (so resume can find it even if killed immediately).
        chainStore.upsertChain(
            chainId = chainId,
            chainName = chainName,
            totalSteps = steps.size,
            status = "running"
        )

        // Enqueue only step 0 now. Steps 1..N are enqueued dynamically as each preceding
        // step completes (see advanceChainIfStepComplete in +EventChannel.kt).
        buildAndEnqueueStep(
            context = context,
            chainStore = chainStore,
            chainId = chainId,
            stepIndex = 0,
            substitutionData = emptyMap(),
            onObserveTaskId = onObserveTaskId?.let { cb -> { taskId: String -> cb(taskId, chainId) } },
        )

        NativeLogger.d("✅ Chain scheduled: $chainName/$chainId (${steps.size} steps), IDs: $allTaskIds")

        return chainId
    }

    /**
     * Build and enqueue every task in one chain step, substituting `{{taskId.outputKey}}`
     * placeholders in each task's raw config against [substitutionData] — the merged,
     * namespaced ("<taskId>.<key>") results of previously completed steps.
     *
     * Each task is enqueued via [WorkManager.enqueueUniqueWork] with [ExistingWorkPolicy.KEEP]
     * rather than a plain `enqueue()`, so re-driving this function for the same step on
     * process-restart resume is idempotent — WorkManager keeps the already-enqueued work
     * instead of scheduling a duplicate (issue_57 resume gap).
     *
     * Reads task data from [ChainStore]'s unsanitized `task_data_json` column, NOT
     * TaskStore — TaskStore's copy has secrets redacted for safe Dart-side display and must
     * never be used to rebuild a real WorkRequest.
     *
     * Returns the task IDs that were enqueued (empty if the step has no persisted records,
     * e.g. an out-of-range stepIndex).
     */
    internal fun buildAndEnqueueStep(
        context: Context,
        chainStore: ChainStore,
        chainId: String,
        stepIndex: Int,
        substitutionData: Map<String, Any?>,
        onObserveTaskId: ((String) -> Unit)? = null,
    ): List<String> {
        val stepRecords = chainStore.getStepsForChain(chainId).filter { it.stepIndex == stepIndex }
        if (stepRecords.isEmpty()) return emptyList()

        val workManager = WorkManager.getInstance(context)
        val enqueuedTaskIds = mutableListOf<String>()

        for (record in stepRecords) {
            val rawJson = record.taskDataJson ?: continue
            val taskData = CommandProcessor.jsonToMap(JSONObject(rawJson))

            @Suppress("UNCHECKED_CAST")
            val workerConfig = taskData["workerConfig"] as? Map<String, Any?>
            val effectiveTaskData = if (workerConfig != null && substitutionData.isNotEmpty()) {
                taskData.toMutableMap().apply {
                    put("workerConfig", substitutePlaceholders(workerConfig, substitutionData))
                }
            } else {
                taskData
            }

            val request = buildChainStepRequest(context, record.taskId, effectiveTaskData)
            workManager.enqueueUniqueWork(record.taskId, ExistingWorkPolicy.KEEP, request)
            enqueuedTaskIds.add(record.taskId)
            onObserveTaskId?.invoke(record.taskId)
        }

        return enqueuedTaskIds
    }

    /**
     * Recursively substitute `{{taskId.outputKey}}` placeholders in a task's raw config.
     * Mirrors iOS's `substitutePlaceholders`/`resolveConfigValue`
     * (NativeWorkmanagerPlugin+Execution.swift) so both platforms agree on semantics —
     * see issue #57.
     *
     * A config value that is a String consisting *entirely* of one placeholder (optionally
     * padded with whitespace) resolves to the original typed value from [data] — Int, Double,
     * Boolean, etc. — not a stringified one, so substitution can target numeric/bool config
     * fields (e.g. `cropRect.x`), not just String ones. A placeholder embedded in a larger
     * string (e.g. `"/tmp/{{downloader.id}}.zip"`) falls back to string interpolation, since
     * there's no single typed value to return for a partial match. An unresolved key leaves
     * the literal placeholder untouched.
     */
    internal fun substitutePlaceholders(config: Map<String, Any?>, data: Map<String, Any?>): Map<String, Any?> {
        val result = LinkedHashMap<String, Any?>(config)
        for ((key, value) in config) {
            result[key] = when (value) {
                is String -> resolveConfigValue(value, data)
                is Map<*, *> -> {
                    @Suppress("UNCHECKED_CAST")
                    substitutePlaceholders(value as Map<String, Any?>, data)
                }
                is List<*> -> value.map { item ->
                    if (item is Map<*, *>) {
                        @Suppress("UNCHECKED_CAST")
                        substitutePlaceholders(item as Map<String, Any?>, data)
                    } else {
                        item
                    }
                }
                else -> value
            }
        }
        return result
    }

    private val WHOLE_PLACEHOLDER_REGEX = Regex("^\\s*\\{\\{([^}]+)\\}\\}\\s*$")
    private val PLACEHOLDER_REGEX = Regex("\\{\\{([^}]+)\\}\\}")

    private fun resolveConfigValue(text: String, data: Map<String, Any?>): Any? {
        val wholeMatch = WHOLE_PLACEHOLDER_REGEX.matchEntire(text)
        if (wholeMatch != null) {
            val key = wholeMatch.groupValues[1].trim()
            return data[key] ?: text
        }
        if (!text.contains("{{")) return text
        var result = text
        PLACEHOLDER_REGEX.findAll(text).toList().asReversed().forEach { match ->
            val key = match.groupValues[1].trim()
            data[key]?.let { result = result.replaceRange(match.range, it.toString()) }
        }
        return result
    }

    /**
     * Merge `__taskId` into a custom worker's pre-encoded input JSON string, so
     * [dev.brewkits.native_workmanager.workers.ChainResultCapturingWorker] can attribute its
     * output back to this chain step. Custom workers (`NativeWorker.custom()`) receive their
     * `input` as an already-serialized JSON string rather than going through the
     * `enrichedConfig["__taskId"] = taskId` path built-in workers use — without this, custom
     * workers in a chain would never get their output captured (issue_57). Mirrors iOS's
     * `NativeWorkmanagerPlugin.mergeTaskId`. Falls back to the original string if it isn't a
     * JSON object (can't carry the key).
     */
    private fun mergeTaskId(inputJson: String?, taskId: String): String? {
        val obj = if (inputJson.isNullOrEmpty() || inputJson == "null") {
            JSONObject()
        } else {
            try {
                JSONObject(inputJson)
            } catch (_: Exception) {
                return inputJson // non-object JSON (scalar/array) — cannot inject; keep as-is.
            }
        }
        obj.put("__taskId", taskId)
        return obj.toString()
    }

    private fun buildChainStepRequest(context: Context, taskId: String, taskData: Map<String, Any?>): OneTimeWorkRequest {
        val workerClassName = taskData["workerClassName"] as? String ?: ""
        @Suppress("UNCHECKED_CAST")
        val workerConfig = taskData["workerConfig"] as? Map<String, Any?>
        
        val inputJson: String? = when {
            workerConfig == null -> null
            workerConfig["workerType"] == "custom" -> mergeTaskId(workerConfig["input"] as? String, taskId)
            else -> {
                val enrichedConfig = workerConfig.toMutableMap()
                if (taskId.isNotEmpty()) enrichedConfig["__taskId"] = taskId
                val json = MappingUtils.toJson(enrichedConfig)
                // Apply middleware
                applyMiddlewareInternal(context, workerClassName, json)
            }
        }
        @Suppress("UNCHECKED_CAST")
        val constraintsMap = taskData["constraints"] as? Map<String, Any?>
        val constraints = MappingUtils.parseConstraints(constraintsMap)

        val dataBuilder = Data.Builder().putString("workerClassName", workerClassName)
        if (inputJson != null) dataBuilder.putString("inputJson", inputJson)
        // Retry ceiling for kmpworkmanager BaseKmpWorker (3.1.0+). -1 = uncapped.
        if (constraints.maxRetries >= 0) {
            dataBuilder.putInt(NativeTaskScheduler.KEY_MAX_RETRIES, constraints.maxRetries)
        }

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
