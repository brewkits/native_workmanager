package dev.brewkits.native_workmanager

import android.content.Intent
import androidx.core.content.FileProvider
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import androidx.work.await
import dev.brewkits.kmpworkmanager.background.data.KmpHeavyWorker
import dev.brewkits.kmpworkmanager.background.data.KmpWorker
import dev.brewkits.kmpworkmanager.background.data.NativeTaskScheduler
import dev.brewkits.kmpworkmanager.background.domain.*
import dev.brewkits.native_workmanager.notification.DownloadNotificationManager
import dev.brewkits.native_workmanager.store.TaskStore.Companion.sanitizeConfig
import dev.brewkits.native_workmanager.utils.MappingUtils.toJson
import dev.brewkits.native_workmanager.workers.HttpDownloadWorker
import dev.brewkits.native_workmanager.workers.utils.HostConcurrencyManager
import dev.brewkits.native_workmanager.workers.utils.KeystorePasswordVault
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

// ── Enqueue/Cancel/Status handlers and low-level WorkManager helpers.
// ── Separated from NativeWorkmanagerPlugin.kt to reduce God Object complexity.

internal fun NativeWorkmanagerPlugin.handleOpenFile(call: MethodCall, result: Result) {
    try {
        val filePath = call.argument<String>("filePath")
            ?: return result.error("INVALID_ARGS", "filePath required", null)
        val mimeType = call.argument<String>("mimeType")

        val file = java.io.File(filePath)
        if (!file.exists()) {
            return result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
        }

        val uri = androidx.core.content.FileProvider.getUriForFile(
            context,
            "${context.packageName}.native_workmanager.provider",
            file
        )

        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType ?: getMimeTypeFromFile(filePath))
            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        context.startActivity(intent)
        result.success(null)
    } catch (e: Exception) {
        result.error("OPEN_FILE_ERROR", e.message, null)
    }
}

internal fun NativeWorkmanagerPlugin.getMimeTypeFromFile(filePath: String): String {
    val ext = filePath.substringAfterLast('.', "").lowercase()
    return android.webkit.MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
        ?: "*/*"
}

internal fun NativeWorkmanagerPlugin.handlePause(call: MethodCall, result: Result) {
    scope.launch {
        try {
            val taskId = call.argument<String>("taskId")
                ?: return@launch result.error("INVALID_ARGS", "taskId required", null)

            // WorkManager has no native pause; cancel the job (preserving the .tmp partial file)
            WorkManager.getInstance(context).cancelUniqueWork(taskId)

            // Update in-memory state
            taskStatuses[taskId] = "paused"

            // Persist paused state (IO dispatcher — SQLite must not run on Main)
            withContext(Dispatchers.IO) { taskStore.updateStatus(taskId = taskId, status = "paused") }

            // Dismiss any active progress notification
            if (taskNotifTitles.containsKey(taskId)) {
                DownloadNotificationManager.dismiss(context, taskId)
            }

            NativeLogger.d("Task '$taskId' paused")
            result.success(null)
        } catch (e: Exception) {
            result.error("PAUSE_ERROR", e.message, null)
        }
    }
}

internal fun NativeWorkmanagerPlugin.handleResume(call: MethodCall, result: Result) {
    scope.launch {
        try {
            val taskId = call.argument<String>("taskId")
                ?: return@launch result.error("INVALID_ARGS", "taskId required", null)

            // Look up the paused task from the store (IO dispatcher — SQLite must not run on Main)
            val record = withContext(Dispatchers.IO) { taskStore.getTask(taskId) }
                ?: return@launch result.error("NOT_FOUND", "Task '$taskId' not found in store", null)

            if (record.status != "paused") {
                return@launch result.error("INVALID_STATE", "Task '$taskId' is not paused (status: ${record.status})", null)
            }

            val workerClassName = record.workerClassName
            val inputJson = record.workerConfig
            val tag = record.tag

            // M-5: restore original constraints from the persisted JSON so the
            // resumed task respects requiresNetwork, requiresCharging, etc.
            @Suppress("UNCHECKED_CAST")
            val restoredConstraintsMap = record.constraintsJson?.let { json ->
                try {
                    val jObj = org.json.JSONObject(json)
                    jObj.keys().asSequence().associateWith { key ->
                        when (val v = jObj.get(key)) {
                            is Boolean -> v
                            is Int     -> v
                            is Long    -> v
                            is Double  -> v
                            else       -> v.toString()
                        }
                    } as Map<String, Any?>
                } catch (_: Exception) { null }
            }
            val constraints = parseConstraints(restoredConstraintsMap)

            // Re-enqueue with the same config and restored constraints
            enqueueOneTimeWorkDirect(
                taskId = taskId,
                workerClassName = workerClassName,
                inputJson = inputJson,
                tag = tag,
                constraints = constraints,
                delayMs = 0L,
                policy = ExistingPolicy.REPLACE
            )

            // Update status back to pending (IO dispatcher — SQLite must not run on Main)
            taskStatuses[taskId] = "pending"
            withContext(Dispatchers.IO) { taskStore.updateStatus(taskId = taskId, status = "pending") }
            observeWorkCompletion(taskId, false)

            NativeLogger.d("Task '$taskId' resumed")
            result.success(null)
        } catch (e: Exception) {
            result.error("RESUME_ERROR", e.message, null)
        }
    }
}

internal fun NativeWorkmanagerPlugin.handleAllTasks(result: Result) {
    scope.launch {
        try {
            val maps = withContext(Dispatchers.IO) {
                taskStore.getAllTasks()
                    .filter { it.tag != "__native_wm_internal__" } // exclude internal cleanup worker
                    .map { record ->
                        with(taskStore) { record.toFlutterMap() }
                    }
            }
            result.success(maps)
        } catch (e: Exception) {
            result.error("ALL_TASKS_ERROR", e.message, null)
        }
    }
}

internal fun NativeWorkmanagerPlugin.handleGetServerFilename(call: MethodCall, result: Result) {
    scope.launch {
        try {
            val url = call.argument<String>("url")
                ?: return@launch result.error("INVALID_ARGS", "url required", null)
            val headers = call.argument<Map<String, String>>("headers")
            val timeoutMs = call.argument<Int>("timeoutMs")?.toLong() ?: 30_000L

            if (!SecurityValidator.validateURL(url)) {
                return@launch result.error("INVALID_URL", "Invalid or unsafe URL", null)
            }

            val filename = kotlinx.coroutines.withContext(Dispatchers.IO) {
                // L-5: Use shared plugin-level OkHttpClient (singleton) instead of
                // creating a new one per call. Per-call clients leak connection pools.
                // For custom timeout, build a derived client with newBuilder() which
                // reuses the underlying dispatcher and connection pool.
                val client = NativeWorkmanagerPlugin.sharedHttpClient.newBuilder()
                    .connectTimeout(timeoutMs, java.util.concurrent.TimeUnit.MILLISECONDS)
                    .readTimeout(timeoutMs, java.util.concurrent.TimeUnit.MILLISECONDS)
                    .build()

                val requestBuilder = okhttp3.Request.Builder().url(url).head()
                headers?.forEach { (k, v) -> requestBuilder.addHeader(k, v) }

                client.newCall(requestBuilder.build()).execute().use { resp ->
                    HttpDownloadWorker().parseFilenameFromContentDisposition(
                        resp.header("Content-Disposition")
                    )
                }
            }
            result.success(filename)
        } catch (e: Exception) {
            result.error("GET_FILENAME_ERROR", e.message, null)
        }
    }
}

internal fun NativeWorkmanagerPlugin.handleEnqueue(call: MethodCall, result: Result) {
    scope.launch {
        try {
            val taskId = call.argument<String>("taskId")
                ?: return@launch result.error("INVALID_ARGS", "taskId required", null)
            val workerClassName = call.argument<String>("workerClassName")
                ?: return@launch result.error("INVALID_ARGS", "workerClassName required", null)
            val workerConfig = call.argument<Map<String, Any?>?>("workerConfig")
            // Custom workers carry a pre-encoded "input" JSON string;
            // built-in workers need the entire workerConfig serialised as their input.
            // Inject taskId into all worker configs for progress reporting
            val inputJson: String? = when {
                workerConfig == null -> null
                workerConfig["workerType"] == "custom" -> workerConfig["input"] as? String
                else -> {
                    // Inject taskId into worker config for progress reporting
                    val enrichedConfig = workerConfig.toMutableMap()
                    enrichedConfig["__taskId"] = taskId
                    // intercept password for crypto workers — replace with vault key
                    // so the password is never written to the unencrypted WorkManager Room DB.
                    if (enrichedConfig["workerType"] == "crypto") {
                        val password = enrichedConfig["password"] as? String
                        if (!password.isNullOrEmpty()) {
                            val vaultKey = KeystorePasswordVault.store(password)
                            enrichedConfig.remove("password")
                            enrichedConfig["passwordKey"] = vaultKey
                        }
                    }
                    toJson(enrichedConfig)
                }
            }
            val tag = call.argument<String>("tag")

            // Store tag if provided
            if (tag != null) {
                taskTags[taskId] = tag
                NativeLogger.d("Stored tag '$tag' for task '$taskId'")
            }

            // constraintsMap must be declared before constraintsJson so both the persistence
            // block below and parseConstraints() share the same parsed value.
            @Suppress("UNCHECKED_CAST")
            val constraintsMap = call.argument<Map<String, Any?>>("constraints")

            // Store task in persistent SQLite store (IO dispatcher — SQLite must not run on Main).
            // Store the FULL (unsanitized) inputJson so that handleResume() can re-enqueue with
            // original auth headers, cookies, and tokens intact.  toFlutterMap() does NOT include
            // workerConfig, so sensitive fields are never sent to the Dart layer.
            // Also persist constraintsJson so resume() can restore original constraints.
            val constraintsJson = constraintsMap?.let { toJson(it) }
            withContext(Dispatchers.IO) {
                taskStore.upsert(
                    taskId = taskId,
                    tag = tag,
                    status = "pending",
                    workerClassName = workerClassName,
                    workerConfig = inputJson,
                    constraintsJson = constraintsJson
                )
            }

            // If showNotification requested, store the title, allowPause, and filename for progress/completion hooks
            if (workerConfig?.get("showNotification") == true) {
                val url = workerConfig["url"] as? String
                val title = (workerConfig["notificationTitle"] as? String)
                    ?: url?.substringAfterLast('/')?.takeIf { it.isNotBlank() }
                    ?: taskId
                taskNotifTitles[taskId] = title
                taskAllowPause[taskId] = workerConfig["allowPause"] as? Boolean ?: true
                val filename = url?.substringAfterLast('/')?.takeIf { it.isNotBlank() }
                    ?: (workerConfig["savePath"] as? String)?.substringAfterLast('/')?.takeIf { it.isNotBlank() }
                if (filename != null) taskFilenames[taskId] = filename

                // Also populate ProgressReporter for automatic native-side updates
                dev.brewkits.native_workmanager.workers.utils.ProgressReporter.taskNotifTitles[taskId] = title
                dev.brewkits.native_workmanager.workers.utils.ProgressReporter.taskAllowPause[taskId] = taskAllowPause[taskId] ?: true
                if (filename != null) dev.brewkits.native_workmanager.workers.utils.ProgressReporter.taskFilenames[taskId] = filename
            }

            // Parse trigger from method call arguments
            @Suppress("UNCHECKED_CAST")
            val triggerMap = call.argument<Map<String, Any?>>("trigger")
            val triggerType = triggerMap?.get("type") as? String ?: "oneTime"
            val trigger: TaskTrigger = when (triggerType) {
                "periodic" -> {
                    val intervalMs = (triggerMap?.get("intervalMs") as? Number)?.toLong() ?: 900_000L
                    val flexMs = (triggerMap?.get("flexMs") as? Number)?.toLong()
                    val initialDelayMs = (triggerMap?.get("initialDelayMs") as? Number)?.toLong() ?: 0L
                    TaskTrigger.Periodic(
                        intervalMs = intervalMs,
                        flexMs = flexMs,
                        initialDelayMs = initialDelayMs
                    )
                }
                "exact" -> {
                    val scheduledTimeMs = (triggerMap?.get("scheduledTimeMs") as? Number)?.toLong()
                        ?: System.currentTimeMillis()
                    TaskTrigger.Exact(atEpochMillis = scheduledTimeMs)
                }
                "windowed" -> {
                    val earliestMs = (triggerMap?.get("earliestMs") as? Number)?.toLong() ?: 0L
                    val latestMs = (triggerMap?.get("latestMs") as? Number)?.toLong() ?: 0L
                    TaskTrigger.Windowed(earliest = earliestMs, latest = latestMs)
                }
                "contentUri" -> {
                    val uriString = triggerMap?.get("uriString") as? String ?: ""
                    val triggerForDescendants = triggerMap?.get("triggerForDescendants") as? Boolean ?: false
                    @OptIn(AndroidOnly::class)
                    TaskTrigger.ContentUri(uriString = uriString, triggerForDescendants = triggerForDescendants)
                }
                // Battery/idle/storage variants removed in kmpworkmanager 2.3.7 — use OneTime
                // with the corresponding SystemConstraint added via parseConstraints instead.
                "batteryOkay" -> TaskTrigger.OneTime()
                "batteryLow" -> TaskTrigger.OneTime()
                "deviceIdle" -> TaskTrigger.OneTime()
                "storageLow" -> TaskTrigger.OneTime()
                else -> {
                    val initialDelayMs = (triggerMap?.get("initialDelayMs") as? Number)?.toLong() ?: 0L
                    TaskTrigger.OneTime(initialDelayMs = initialDelayMs)
                }
            }

            // Parse existing policy from method call arguments
            val existingPolicyStr = call.argument<String>("existingPolicy") ?: "replace"
            val policy = when (existingPolicyStr.lowercase()) {
                "replace" -> ExistingPolicy.REPLACE
                else -> ExistingPolicy.KEEP
            }

            // constraintsMap already declared above (before SQLite upsert — C-001 fix).
            val constraints = parseConstraints(constraintsMap)

            // Fix: WorkManager 2.10+ rejects expedited work (all kmpworkmanager OneTime tasks)
            // for ANY non-network/non-storage constraints, AND rejects expedited+initialDelay.
            // Bypass kmpworkmanager for ALL OneTime tasks: schedule directly via WorkManager
            // without setExpedited(). KmpWorker/KmpHeavyWorker still handle task dispatch.
            if (trigger is TaskTrigger.OneTime) {
                val delayMs = trigger.initialDelayMs
                // Check if expedited mode is requested for download workers (Task 6 / UIDT)
                val isDownloadWorker = workerClassName.contains("HttpDownloadWorker") ||
                    workerClassName.contains("ParallelHttpDownloadWorker")
                val isExpedited = isDownloadWorker &&
                    (workerConfig?.get("expedited") == true || workerConfig?.get("priority") == "high")
                NativeLogger.d("Scheduling '$taskId': OneTime(delay=${delayMs}ms, expedited=$isExpedited) → direct WorkManager")
                enqueueOneTimeWorkDirect(taskId, workerClassName, inputJson, tag, constraints, delayMs, policy, isExpedited)
                taskStatuses[taskId] = "pending"
                observeWorkCompletion(taskId, false)
                result.success("ACCEPTED")
                return@launch
            }

            val isPeriodic = trigger is TaskTrigger.Periodic
            NativeLogger.d("Scheduling '$taskId': trigger=$triggerType, policy=$existingPolicyStr, heavy=${constraints.isHeavyTask}")

            val scheduleResult = scheduler.enqueue(
                id = taskId,
                trigger = trigger,
                workerClassName = workerClassName,
                constraints = constraints,
                inputJson = inputJson,
                policy = policy
            )

            when (scheduleResult) {
                ScheduleResult.ACCEPTED -> {
                    taskStatuses[taskId] = "pending"
                    observeWorkCompletion(taskId, isPeriodic)
                    NativeLogger.d("✅ Task scheduled: $taskId")
                    result.success("ACCEPTED")
                }
                ScheduleResult.REJECTED_OS_POLICY -> {
                    NativeLogger.w("⚠️ Task rejected by OS policy: $taskId")
                    result.success("REJECTED_OS_POLICY")
                }
                ScheduleResult.THROTTLED -> {
                    NativeLogger.w("⚠️ Task throttled: $taskId")
                    result.success("THROTTLED")
                }
                ScheduleResult.DEADLINE_ALREADY_PASSED -> {
                    NativeLogger.w("⚠️ Task deadline already passed: $taskId")
                    result.success("DEADLINE_ALREADY_PASSED")
                }
            }
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e  // Re-throw so coroutine cancellation propagates normally
        } catch (e: Exception) {
            NativeLogger.e("❌ Enqueue error", e)
            result.error("ENQUEUE_ERROR", e.message, null)
        }
    }
}

/** Delete leftover .tmp and .tmp.etag files for a cancelled/failed download task.
 *  Prevents GB-scale orphan files accumulating on disk — mirrors #516 fix. */
internal suspend fun NativeWorkmanagerPlugin.cleanupTempFilesForTask(taskId: String) {
    try {
        val record = withContext(Dispatchers.IO) { taskStore.getTask(taskId) } ?: return
        val config = record.workerConfig ?: return
        val savePath = try {
            org.json.JSONObject(config).optString("savePath").takeIf { it.isNotBlank() }
        } catch (_: Exception) { null } ?: return
        // ETag sidecar is stored next to the .tmp file (tempFile.path + .etag), which may be a
        // sentinel "__pending__.tmp.etag" in directory mode.  Delete both the savePath-relative
        // sentinel AND the savePath+suffix fallback to handle both naming conventions.
        val tempPath = if (savePath.endsWith("/")) savePath + "__pending__.tmp" else savePath + ".tmp"
        for (suffix in listOf(".tmp", ".tmp.etag")) {
            for (base in listOf(savePath, tempPath).distinct()) {
                val f = java.io.File(base + suffix)
                if (f.exists()) {
                    f.delete()
                    NativeLogger.d("Deleted orphan $suffix for cancelled task '$taskId'")
                }
            }
        }
    } catch (e: Exception) {
        NativeLogger.w("cleanupTempFilesForTask '$taskId': ${e.message}")
    }
}

internal fun NativeWorkmanagerPlugin.handleCancel(call: MethodCall, result: Result) {
    scope.launch {
        try {
            val taskId = call.argument<String>("taskId")
                ?: return@launch result.error("INVALID_ARGS", "taskId required", null)

            // Use cancelAllWorkByTag instead of cancelUniqueWork so that both standalone
            // tasks (unique work) AND chain steps (non-unique work tagged with taskId) are
            // correctly cancelled. All tasks are tagged with their taskId via addTag(taskId).
            withContext(Dispatchers.IO) {
                WorkManager.getInstance(context).cancelAllWorkByTag(taskId).await()
                taskStore.updateStatus(taskId = taskId, status = "cancelled")
            }
            cleanupTempFilesForTask(taskId)
            // Remove tag mapping and update status
            taskTags.remove(taskId)
            taskStatuses[taskId] = "cancelled"
            // Dismiss any active progress notification
            taskNotifTitles.remove(taskId)?.let { DownloadNotificationManager.dismiss(context, taskId) }
            taskAllowPause.remove(taskId)
            taskFilenames.remove(taskId)
            dev.brewkits.native_workmanager.workers.utils.ProgressReporter.clearTask(taskId)
            result.success(null)
        } catch (e: Exception) {
            result.error("CANCEL_ERROR", e.message, null)
        }
    }
}

internal fun NativeWorkmanagerPlugin.handleCancelAll(result: Result) {
    scope.launch {
        try {
            withContext(Dispatchers.IO) {
                taskStore.getAllTasks().forEach { record ->
                    val config = record.workerConfig ?: return@forEach
                    val savePath = try {
                        org.json.JSONObject(config).optString("savePath").takeIf { it.isNotBlank() }
                    } catch (_: Exception) { null } ?: return@forEach
                    for (suffix in listOf(".tmp", ".tmp.etag")) {
                        val f = java.io.File(savePath + suffix)
                        if (f.exists()) f.delete()
                    }
                }
                WorkManager.getInstance(context)
                    .cancelAllWorkByTag(NativeTaskScheduler.TAG_KMP_TASK).await()
            }
            // Dismiss all active download notifications before clearing state
            taskNotifTitles.keys.forEach { DownloadNotificationManager.dismiss(context, it) }
            taskNotifTitles.clear()
            // Clear all tag mappings and status tracking
            taskTags.clear()
            taskStatuses.clear()
            taskAllowPause.clear()
            taskFilenames.clear()
            // Clear ProgressReporter for all tasks
            val allTaskIds = withContext(Dispatchers.IO) { taskStore.getAllTasks().map { it.taskId } }
            allTaskIds.forEach { dev.brewkits.native_workmanager.workers.utils.ProgressReporter.clearTask(it) }
            result.success(null)
        } catch (e: Exception) {
            result.error("CANCEL_ERROR", e.message, null)
        }
    }
}

internal fun NativeWorkmanagerPlugin.handleCancelByTag(call: MethodCall, result: Result) {
    scope.launch {
        try {
            val tag = call.argument<String>("tag")
                ?: return@launch result.error("INVALID_ARGS", "tag required", null)

            // Merge in-memory and SQLite to find all tasks with this tag.
            val inMemoryIds = taskTags.filterValues { it == tag }.keys.toSet()
            val dbIds = withContext(Dispatchers.IO) {
                taskStore.getTasksByTag(tag).map { it.taskId }.toSet()
            }
            val tasksToCancel = (inMemoryIds + dbIds).toList()

            NativeLogger.d("Canceling ${tasksToCancel.size} tasks with tag '$tag'")

            // cancelAllWorkByTag is async; await result before returning to Dart.
            withContext(Dispatchers.IO) {
                WorkManager.getInstance(context).cancelAllWorkByTag(tag).await()
                tasksToCancel.forEach { taskId ->
                    taskStore.updateStatus(taskId = taskId, status = "cancelled")
                }
            }

            tasksToCancel.forEach { taskId ->
                cleanupTempFilesForTask(taskId)
                taskTags.remove(taskId)
                taskStatuses[taskId] = "cancelled"
                taskNotifTitles.remove(taskId)?.let { DownloadNotificationManager.dismiss(context, taskId) }
                taskAllowPause.remove(taskId)
                taskFilenames.remove(taskId)
                dev.brewkits.native_workmanager.workers.utils.ProgressReporter.clearTask(taskId)
            }

            result.success(null)
        } catch (e: Exception) {
            result.error("CANCEL_ERROR", e.message, null)
        }
    }
}

internal fun NativeWorkmanagerPlugin.handleGetTasksByTag(call: MethodCall, result: Result) {
    scope.launch {
        try {
            val tag = call.argument<String>("tag")
                ?: return@launch result.error("INVALID_ARGS", "tag required", null)

            // Merge in-memory (pending/running) and SQLite (persisted) tasks for this tag.
            // Filter out terminal-state tasks so cancelled/completed tasks don't appear.
            val terminalStatuses = setOf("cancelled", "completed", "failed")
            val inMemory = taskTags.filterValues { it == tag }.keys.toSet()
            val fromDb = withContext(Dispatchers.IO) {
                taskStore.getTasksByTag(tag)
                    .filter { it.status !in terminalStatuses }
                    .map { it.taskId }
                    .toSet()
            }
            result.success((inMemory + fromDb).toList())
        } catch (e: Exception) {
            result.error("GET_TASKS_ERROR", e.message, null)
        }
    }
}

internal fun NativeWorkmanagerPlugin.handleGetAllTags(result: Result) {
    scope.launch {
        try {
            // Merge in-memory and persisted tags (DB is the source of truth for completed tasks)
            val inMemoryTags = taskTags.values.toSet()
            val dbTags = withContext(Dispatchers.IO) {
                taskStore.getAllTasks().mapNotNull { it.tag }.toSet()
            }
            result.success((inMemoryTags + dbTags).toList())
        } catch (e: Exception) {
            result.error("GET_TAGS_ERROR", e.message, null)
        }
    }
}

internal fun NativeWorkmanagerPlugin.handleGetTaskStatus(call: MethodCall, result: Result) {
    scope.launch {
        try {
            val taskId = call.argument<String>("taskId")
                ?: return@launch result.error("INVALID_ARGS", "taskId required", null)

            // Check in-memory first; fall back to DB for completed/historical tasks
            val inMemory = taskStatuses[taskId]
            if (inMemory != null) {
                result.success(inMemory)
                return@launch
            }
            val fromDb = withContext(Dispatchers.IO) { taskStore.getTask(taskId)?.status }
            result.success(fromDb)
        } catch (e: Exception) {
            result.success(null)
        }
    }
}

internal fun NativeWorkmanagerPlugin.handleGetTaskRecord(call: MethodCall, result: Result) {
    scope.launch {
        try {
            val taskId = call.argument<String>("taskId")
                ?: return@launch result.error("INVALID_ARGS", "taskId required", null)

            val record = withContext(Dispatchers.IO) { taskStore.getTask(taskId) }
            result.success(record?.let { with(taskStore) { it.toFlutterMap() } })
        } catch (e: Exception) {
            result.success(null)
        }
    }
}

internal fun NativeWorkmanagerPlugin.parseConstraints(map: Map<String, Any?>?): Constraints =
    dev.brewkits.native_workmanager.utils.MappingUtils.parseConstraints(map)

/**
 * Schedules a OneTime task directly via WorkManager, bypassing kmpworkmanager.
 *
 * kmpworkmanager 2.3.3 always calls setExpedited() on OneTime work requests.
 * WorkManager 2.10+ rejects expedited work when:
 * - Combined with setInitialDelay() (any delay > 0), OR
 * - Combined with non-network/non-storage constraints (charging, battery, device-idle).
 * This method omits setExpedited() entirely so all constraint combinations are accepted.
 * KmpWorker and KmpHeavyWorker still handle task dispatch correctly.
 */
internal fun NativeWorkmanagerPlugin.enqueueOneTimeWorkDirect(
    taskId: String,
    workerClassName: String,
    inputJson: String?,
    tag: String?,
    constraints: Constraints,
    delayMs: Long,
    policy: ExistingPolicy,
    expedited: Boolean = false,
) {
    val workerClass = if (constraints.isHeavyTask) KmpHeavyWorker::class.java else KmpWorker::class.java

    val dataBuilder = Data.Builder().putString("workerClassName", workerClassName)
    
    // Apply middleware to inputJson before enqueuing (Phase 2)
    val effectiveInputJson = if (inputJson != null) {
        NativeWorkmanagerPlugin.applyMiddleware(context, workerClassName, inputJson)
    } else inputJson
    
    if (effectiveInputJson != null) dataBuilder.putString("inputJson", effectiveInputJson)

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

    val requestBuilder = OneTimeWorkRequest.Builder(workerClass)
        .setConstraints(wmConstraintsBuilder.build())
        .setInputData(dataBuilder.build())
        .addTag(NativeTaskScheduler.TAG_KMP_TASK)
        .addTag("worker-$workerClassName")
        .addTag(taskId)
        .addTag(workerClassName)
    if (delayMs > 0) requestBuilder.setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
    if (tag != null) requestBuilder.addTag(tag)
    if (expedited && delayMs == 0L) {
        // setExpedited is only valid when there is no initial delay.
        // OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST ensures the task still
        // runs even when the app is out of expedited job quota.
        requestBuilder.setExpedited(androidx.work.OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
        NativeLogger.d("Expedited flag set for '$taskId' (UIDT / Android 14+ data-sync)")
    }

    val wmBackoffPolicy = when (constraints.backoffPolicy) {
        BackoffPolicy.LINEAR -> androidx.work.BackoffPolicy.LINEAR
        else -> androidx.work.BackoffPolicy.EXPONENTIAL
    }
    requestBuilder.setBackoffCriteria(wmBackoffPolicy, constraints.backoffDelayMs, TimeUnit.MILLISECONDS)

    val workPolicy = when (policy) {
        ExistingPolicy.REPLACE -> ExistingWorkPolicy.REPLACE
        else -> ExistingWorkPolicy.KEEP
    }
    val request = requestBuilder.build()
    NativeLogger.d("📋 [DIAG] WorkRequest for '$taskId': networkType=$networkType, " +
        "requiresCharging=${constraints.requiresCharging}, " +
        "sysConstraints=$sysConstraints, " +
        "delayApplied=${delayMs > 0}, delayMs=$delayMs, " +
        "workerClass=${workerClass.simpleName}, " +
        "workerClassName=$workerClassName")
    WorkManager.getInstance(context).enqueueUniqueWork(taskId, workPolicy, request)
    NativeLogger.d("✅ OneTime '$taskId' enqueued via direct WorkManager (delay=${delayMs}ms, heavy=${constraints.isHeavyTask}, policy=$workPolicy)")
}


