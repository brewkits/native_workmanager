package dev.brewkits.native_workmanager

import android.app.NotificationManager
import android.content.Context
import androidx.core.app.NotificationCompat
import androidx.work.WorkInfo
import androidx.work.WorkManager
import dev.brewkits.native_workmanager.engine.TaskEventBus
import dev.brewkits.native_workmanager.notification.DownloadNotificationManager
import dev.brewkits.native_workmanager.utils.MappingUtils.toJson
import dev.brewkits.native_workmanager.workers.utils.ProgressReporter
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.takeWhile

// ── EventChannel: progress subscriptions, task-event subscriptions,
// ── work completion observation, and error-code derivation.
// ── Separated from NativeWorkmanagerPlugin.kt to reduce God Object complexity.

internal fun NativeWorkmanagerPlugin.subscribeToProgressUpdates() {
    progressJob?.cancel()
    progressJob = scope.launch {
        try {
            ProgressReporter.progressFlow.collect { update ->
                // Show download notification progress if enabled for this task
                val notifTitle = taskNotifTitles[update.taskId]
                if (notifTitle != null) {
                    DownloadNotificationManager.showProgress(
                        context = context,
                        taskId = update.taskId,
                        title = notifTitle,
                        progress = update.progress,
                        message = update.message,
                        filename = taskFilenames[update.taskId],
                        allowPause = taskAllowPause[update.taskId] ?: true
                    )
                }
                progressSink?.success(update.toMap())
            }
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e  // Re-throw so coroutine cancellation propagates normally
        } catch (e: Exception) {
            NativeLogger.e("Error in progress subscription", e)
        }
    }
}

internal fun NativeWorkmanagerPlugin.subscribeToTaskEvents() {
    eventJob?.cancel()
    eventJob = scope.launch {
        try {
            // Access TaskEventBus object singleton directly (v2.3.1+ with outputData support)
            TaskEventBus.events.collect { event ->
                // Show debug notification if enabled
                if (debugMode && isDebugBuild()) {
                    try {
                        val taskId = event.taskName
                        val startTime = taskStartTimes[taskId]
                        val executionTime = if (startTime != null) {
                            "${System.currentTimeMillis() - startTime}ms"
                        } else {
                            "N/A"
                        }

                        // Remove from tracking if task completed
                        if (event.success || !event.message.isNullOrEmpty()) {
                            taskStartTimes.remove(taskId)
                        }

                        val title = if (event.success) {
                            "✅ Task Completed: $taskId"
                        } else {
                            "❌ Task Failed: $taskId"
                        }

                        val text = buildString {
                            append("Execution time: $executionTime")
                            if (!event.message.isNullOrEmpty()) {
                                append("\n${event.message}")
                            }
                        }

                        val notification = NotificationCompat.Builder(context, NativeWorkmanagerPlugin.DEBUG_NOTIFICATION_CHANNEL_ID)
                            .setSmallIcon(android.R.drawable.ic_dialog_info)
                            .setContentTitle(title)
                            .setContentText(text)
                            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                            .setAutoCancel(true)
                            .setTimeoutAfter(NativeWorkmanagerPlugin.DEBUG_NOTIFICATION_TIMEOUT_MS)
                            .build()

                        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        notificationManager.notify(taskId.hashCode(), notification)
                    } catch (e: Exception) {
                        NativeLogger.e("Error showing debug notification", e)
                    }
                }

                val terminalStatus = if (event.success) "completed" else "failed"

                // Persist to SQLite BEFORE updating in-memory. If the process dies between the
                // two, SQLite is the durable record — on restart, Dart sees "pending" and can
                // decide to re-enqueue rather than silently believing the task completed.
                val resultJson = event.outputData?.let { toJson(it) }
                withContext(Dispatchers.IO) {
                    taskStore.updateStatus(
                        taskId = event.taskName,
                        status = terminalStatus,
                        resultData = resultJson
                    )
                }

                // Update in-memory status AFTER durable SQLite write.
                // taskBusSignals.complete() below is called after this, so observeWorkCompletion
                // always sees taskStatuses[taskId] == terminalStatus when it wakes up.
                taskStatuses[event.taskName] = terminalStatus

                // Capture duration before taskStartTimes cleanup (used by LoggingMiddleware).
                val taskDurationMs = taskStartTimes[event.taskName]?.let { System.currentTimeMillis() - it }

                // Show download completion/failure notification if enabled for this task
                val notifTitle = taskNotifTitles.remove(event.taskName)
                taskFilenames.remove(event.taskName)
                taskAllowPause.remove(event.taskName)
                taskStartTimes.remove(event.taskName)

                if (notifTitle != null) {
                    if (event.success) {
                        DownloadNotificationManager.showCompleted(
                            context = context,
                            taskId = event.taskName,
                            title = notifTitle,
                            fileName = null
                        )
                    } else {
                        DownloadNotificationManager.showFailed(
                            context = context,
                            taskId = event.taskName,
                            title = notifTitle,
                            error = event.message ?: "Download failed"
                        )
                    }
                }

                ProgressReporter.clearTask(event.taskName)

                // Signal any observeWorkCompletion waiter so it can skip the fallback path.
                taskBusSignals.remove(event.taskName)?.complete(Unit)

                NativeLogger.d("EventChannel: received event for ${event.taskName}, success=${event.success}, hasOutputData=${event.outputData != null}")

                // Always emit event to Dart (v2.3.1+: includes outputData)
                val eventMap = mutableMapOf<String, Any?>(
                    "taskId" to event.taskName,
                    "success" to event.success,
                    "message" to event.message,
                    "resultData" to event.outputData,
                    "timestamp" to System.currentTimeMillis()
                )
                if (!event.success) eventMap["errorCode"] = deriveErrorCode(event.message)
                eventSink?.success(eventMap)

                // Fire LoggingMiddleware POST (fire-and-forget, never blocks event emission).
                val taskRecord = withContext(Dispatchers.IO) { taskStore.getTask(event.taskName) }
                applyLoggingMiddleware(
                    taskId = event.taskName,
                    workerClassName = taskRecord?.workerClassName ?: event.taskName,
                    success = event.success,
                    message = event.message,
                    durationMs = taskDurationMs,
                    workerConfig = if (taskRecord != null) taskRecord.workerConfig else null
                )

                // Final cleanup of the terminal status after emission
                taskStatuses.remove(event.taskName)
            }
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e  // Re-throw so coroutine cancellation propagates normally
        } catch (e: Exception) {
            NativeLogger.e("Error in event subscription", e)
        }
    }
}

internal fun NativeWorkmanagerPlugin.observeChainStepCompletion(taskId: String, chainId: String? = null) {
    scope.launch {
        try {
            val workManager = WorkManager.getInstance(context)
            workManager.getWorkInfosByTagFlow(taskId)
                .collect { infos ->
                    val workInfo = infos.firstOrNull { it.state in NativeWorkmanagerPlugin.TERMINAL_STATES }
                        ?: return@collect
                    if (taskStatuses[taskId] == "completed" || taskStatuses[taskId] == "failed") return@collect

                    when (workInfo.state) {
                        WorkInfo.State.SUCCEEDED -> {
                            taskStatuses[taskId] = "completed"
                            NativeLogger.d("✅ Chain step SUCCEEDED: $taskId")
                            if (chainId != null) {
                                withContext(Dispatchers.IO) {
                                    // issue_57: WorkInfo.outputData is always empty here —
                                    // BaseKmpWorker hands back a bare Result.success(). Real
                                    // output data (if any) was already written by
                                    // ChainResultCapturingWorker synchronously inside doWork(),
                                    // before this WorkInfo transition could even be observed.
                                    // Passing null is intentionally a no-op on that column —
                                    // updateStepStatus only touches result_json when non-null.
                                    chainStore.updateStepStatus(chainId, taskId, "completed")
                                    advanceChainIfStepComplete(chainId, taskId)
                                }
                            }
                            eventSink?.success(mapOf(
                                "taskId" to taskId,
                                "success" to true,
                                "message" to "Chain step completed",
                                "timestamp" to System.currentTimeMillis()
                            ))
                        }
                        WorkInfo.State.FAILED, WorkInfo.State.CANCELLED -> {
                            taskStatuses[taskId] = "failed"
                            NativeLogger.e("❌ Chain step FAILED/CANCELLED: $taskId (${workInfo.state})")
                            if (chainId != null) {
                                withContext(Dispatchers.IO) {
                                    chainStore.updateStepStatus(chainId, taskId, "failed")
                                    chainStore.updateChainStatus(chainId, "failed")
                                }
                            }
                            val chainMsg = "Chain step ${workInfo.state.name.lowercase()}"
                            eventSink?.success(mapOf(
                                "taskId" to taskId,
                                "success" to false,
                                "message" to chainMsg,
                                "errorCode" to deriveErrorCode(chainMsg),
                                "timestamp" to System.currentTimeMillis()
                            ))
                        }
                        else -> {}
                    }
                }
        } catch (e: kotlinx.coroutines.CancellationException) {
            // Always rethrow CancellationException so coroutine cancellation
            // propagates correctly. Catching it as Exception swallows scope cancellation
            // and prevents the coroutine from stopping when the plugin detaches.
            throw e
        } catch (e: Exception) {
            NativeLogger.e("Error observing chain step $taskId", e)
        }
    }
}

/**
 * After a chain step's task reaches SUCCEEDED, check whether every task in that step has
 * now completed; if so, enqueue the next step — substituting `{{taskId.outputKey}}`
 * placeholders against the merged, namespaced ("<taskId>.<key>") output of the step that
 * just finished — or mark the whole chain "completed" if it was the last step. issue_57.
 *
 * A no-op if the chain isn't in "running" state (e.g. cancelled) or if sibling parallel
 * tasks in the same step haven't finished yet — this function re-fires once per completed
 * task, so the "advance" branch only actually runs once, on whichever task finishes last.
 */
internal suspend fun NativeWorkmanagerPlugin.advanceChainIfStepComplete(chainId: String, completedTaskId: String) {
    val chain = chainStore.getChain(chainId) ?: return
    if (chain.status != "running") return

    val steps = chainStore.getStepsForChain(chainId)
    val completedStep = steps.find { it.taskId == completedTaskId } ?: return
    val stepIndex = completedStep.stepIndex
    val stepTasks = steps.filter { it.stepIndex == stepIndex }

    if (stepTasks.any { it.status == "failed" }) return // FAILED branch already marks the chain
    if (stepTasks.any { it.status != "completed" }) return // still waiting on sibling parallel tasks

    val nextStepIndex = stepIndex + 1
    if (nextStepIndex >= chain.totalSteps) {
        chainStore.updateChainStatus(chainId, "completed", currentStep = nextStepIndex)
        NativeLogger.d("✅ Chain completed: $chainId")
        return
    }

    chainStore.updateChainStatus(chainId, "running", currentStep = nextStepIndex)
    val enqueued = dev.brewkits.native_workmanager.utils.ChainHelper.buildAndEnqueueStep(
        context = context,
        chainStore = chainStore,
        chainId = chainId,
        stepIndex = nextStepIndex,
        substitutionData = substitutionDataFromStep(chainId, stepIndex),
        onObserveTaskId = { taskId -> taskStatuses[taskId] = "pending" },
    )
    enqueued.forEach { taskId -> observeChainStepCompletion(taskId, chainId) }
}

/**
 * Merge one completed step's per-task `result_json` into a single map, namespaced
 * `"<taskId>.<key>"` — the same key space iOS's `mergeStepResult` produces, so a chain
 * built once behaves identically on both platforms. This is the substitution data available
 * to the step that follows [stepIndex]. Returns an empty map if [stepIndex] is out of range
 * (e.g. step 0 has no predecessor) or has no persisted results.
 */
internal fun NativeWorkmanagerPlugin.substitutionDataFromStep(chainId: String, stepIndex: Int): Map<String, Any?> {
    if (stepIndex < 0) return emptyMap()
    val stepTasks = chainStore.getStepsForChain(chainId).filter { it.stepIndex == stepIndex }
    val merged = mutableMapOf<String, Any?>()
    for (task in stepTasks) {
        val json = task.resultJson ?: continue
        val map = try {
            dev.brewkits.native_workmanager.utils.CommandProcessor.jsonToMap(org.json.JSONObject(json))
        } catch (e: Exception) {
            NativeLogger.e("substitutionDataFromStep: failed to parse result_json for '${task.taskId}'", e)
            null
        }
        map?.forEach { (key, value) -> merged["${task.taskId}.$key"] = value }
    }
    return merged
}

/**
 * Collect WorkManager's Flow for the given unique-work task.
 * TaskEventBus (kmpworkmanager) does not reliably emit on Android,
 * so we observe WorkInfo state directly via the ktx Flow API.
 *
 * One-time tasks: wait for the first terminal state (SUCCEEDED/FAILED/CANCELLED).
 * Periodic tasks: collect continuously, emitting an event on each execution cycle,
 * and stop only when the task is CANCELLED.
 */
internal fun NativeWorkmanagerPlugin.observeWorkCompletion(taskId: String, isPeriodic: Boolean = false) {
    scope.launch {
        try {
            val workManager = WorkManager.getInstance(context)

            if (isPeriodic) {
                // For periodic tasks: emit an event after each execution cycle.
                // Use takeWhile to keep collecting until the task is cancelled.
                //
                // IMPORTANT: PeriodicWorkRequest never reaches SUCCEEDED state.
                // Its state cycle is: ENQUEUED → RUNNING → ENQUEUED → RUNNING → ...
                // One cycle completion is detected by the RUNNING → ENQUEUED transition.
                var lastState: WorkInfo.State? = null
                workManager.getWorkInfosForUniqueWorkFlow(taskId)
                    .takeWhile { infos ->
                        infos.isEmpty() || infos.first().state != WorkInfo.State.CANCELLED
                    }
                    .collect { infos ->
                        if (infos.isEmpty()) return@collect
                        val state = infos.first().state
                        if (state == lastState) return@collect
                        val previousState = lastState
                        lastState = state

                        when (state) {
                            WorkInfo.State.RUNNING -> {
                                // Task started a new execution cycle — emit lifecycle event
                                taskStatuses[taskId] = "running"
                                eventSink?.success(mapOf(
                                    "taskId" to taskId,
                                    "isStarted" to true,
                                    "workerType" to "",
                                    "timestamp" to System.currentTimeMillis()
                                ))
                            }
                            WorkInfo.State.ENQUEUED -> {
                                if (previousState == WorkInfo.State.RUNNING) {
                                    // Do NOT emit success here. WorkInfo.State transitions
                                    // RUNNING→ENQUEUED regardless of whether the worker returned
                                    // Success or Failure (WorkManager retries periodic tasks).
                                    // Emitting success here would falsely report success when the
                                    // worker actually failed. TaskEventBus (subscribeToTaskEvents)
                                    // is the authoritative source for per-cycle results — it already
                                    // emits the correct success/failure event from the worker's output.
                                    taskStatuses[taskId] = "pending"
                                    NativeLogger.d("Periodic task cycle: RUNNING→ENQUEUED for $taskId (result from TaskEventBus)")
                                } else {
                                    // Initial enqueue or re-enqueue after backoff
                                    if (taskStatuses[taskId] == "running") taskStatuses[taskId] = "pending"
                                }
                            }
                            WorkInfo.State.FAILED -> {
                                // Permanent failure (very rare for PeriodicWorkRequest;
                                // normally WorkManager retries automatically via backoff).
                                if (taskStatuses[taskId] != "failed") {
                                    taskStatuses[taskId] = "failed"
                                    NativeLogger.e("❌ Periodic task failed permanently: $taskId")
                                    eventSink?.success(mapOf(
                                        "taskId" to taskId,
                                        "success" to false,
                                        "message" to "Task failed",
                                        "errorCode" to "WORKER_EXCEPTION",
                                        "timestamp" to System.currentTimeMillis()
                                    ))
                                }
                            }
                            else -> { /* other states — no action */ }
                        }
                    }
                // Flow ended because the task was CANCELLED (takeWhile returned false)
                taskStatuses[taskId] = "cancelled"
                NativeLogger.d("⚠️ Periodic task cancelled: $taskId")
            } else {
                // One-time task: emit "started" lifecycle event when RUNNING is detected,
                // then observe until terminal state.
                // The started watcher runs concurrently and stops as soon as the task
                // reaches any terminal state (including RUNNING→terminal in one step).
                scope.launch {
                    try {
                        workManager.getWorkInfosForUniqueWorkFlow(taskId)
                            .takeWhile { infos ->
                                infos.isEmpty() || infos.first().state !in NativeWorkmanagerPlugin.TERMINAL_STATES
                            }
                            .collect { infos ->
                                if (infos.firstOrNull()?.state == WorkInfo.State.RUNNING &&
                                    taskStatuses[taskId] != "running") {
                                    taskStatuses[taskId] = "running"
                                    withContext(Dispatchers.IO) {
                                        taskStore.updateStatus(taskId, "running")
                                    }
                                    eventSink?.success(mapOf(
                                        "taskId" to taskId,
                                        "isStarted" to true,
                                        "workerType" to "",
                                        "timestamp" to System.currentTimeMillis()
                                    ))
                                }
                            }
                    } catch (e: kotlinx.coroutines.CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        NativeLogger.e("Error watching start state for $taskId", e)
                    }
                }
                // With ExistingWorkPolicy.REPLACE, WorkManager briefly emits CANCELLED
                // for the old task before ENQUEUED appears for the new task.
                // We retry once if CANCELLED is immediately followed by a new task.
                var retries = 0
                while (retries <= 1) {
                    val terminalInfos = workManager.getWorkInfosForUniqueWorkFlow(taskId).first { infos ->
                        infos.isNotEmpty() && infos.first().state in NativeWorkmanagerPlugin.TERMINAL_STATES
                    }
                    val workInfo = terminalInfos.first()
                    val state = workInfo.state
                    // Extract output data from WorkInfo (set by KmpWorker/KmpHeavyWorker)
                    val outputDataMap = workInfo.outputData.keyValueMap
                        .let { if (it.isEmpty()) null else it }
                    when (state) {
                        WorkInfo.State.SUCCEEDED -> {
                            // Wait for TaskEventBus to signal (it carries richer outputData).
                            // computeIfAbsent is atomic — creates deferred if not yet signalled,
                            // then suspends. If TaskEventBus already fired, await() returns at once.
                            // withTimeoutOrNull caps the wait at 2 s for edge cases.
                            val wasSignalled = withTimeoutOrNull(2_000L) {
                                taskBusSignals.computeIfAbsent(taskId) { CompletableDeferred() }.await()
                                true
                            } ?: false

                            taskBusSignals.remove(taskId)

                            // If TaskEventBus already handled the event, skip the fallback emission.
                            // This prevents duplicate success/failure events being sent to Dart.
                            if (wasSignalled) {
                                NativeLogger.d("TaskEventBus already handled $taskId - skipping WorkInfo fallback")
                                break
                            }

                            if (taskStatuses[taskId] != "completed") {
                                taskStatuses[taskId] = "completed"
                                withContext(Dispatchers.IO) {
                                    val resultJson = outputDataMap?.let { toJson(it) }
                                    taskStore.updateStatus(
                                        taskId = taskId,
                                        status = "completed",
                                        resultData = resultJson
                                    )
                                }
                                NativeLogger.d("✅ WorkInfo SUCCEEDED (fallback): $taskId")
                                eventSink?.success(mapOf(
                                    "taskId" to taskId,
                                    "success" to true,
                                    "message" to "Task completed",
                                    "resultData" to outputDataMap,
                                    "timestamp" to System.currentTimeMillis()
                                ))
                            }
                            break
                        }
                        WorkInfo.State.FAILED -> {
                            // Same deferred-signal pattern for FAILED.
                            val wasSignalled = withTimeoutOrNull(2_000L) {
                                taskBusSignals.computeIfAbsent(taskId) { CompletableDeferred() }.await()
                                true
                            } ?: false

                            taskBusSignals.remove(taskId)

                            if (wasSignalled) {
                                NativeLogger.d("TaskEventBus already handled $taskId - skipping WorkInfo fallback")
                                break
                            }

                            if (taskStatuses[taskId] != "failed") {
                                taskStatuses[taskId] = "failed"
                                withContext(Dispatchers.IO) {
                                    val resultJson = outputDataMap?.let { toJson(it) }
                                    taskStore.updateStatus(
                                        taskId = taskId,
                                        status = "failed",
                                        resultData = resultJson
                                    )
                                }
                                NativeLogger.e("❌ WorkInfo FAILED (fallback): $taskId")
                                eventSink?.success(mapOf(
                                    "taskId" to taskId,
                                    "success" to false,
                                    "message" to "Task failed",
                                    "errorCode" to "WORKER_EXCEPTION",
                                    "resultData" to outputDataMap,
                                    "timestamp" to System.currentTimeMillis()
                                ))
                            }
                            break
                        }
                        WorkInfo.State.CANCELLED -> {
                            // Short structural wait for REPLACE-policy detection (not bus-related).
                            kotlinx.coroutines.delay(500L)
                            val recheck = workManager.getWorkInfosForUniqueWorkFlow(taskId).first()
                            if (retries == 0 && recheck.isNotEmpty() &&
                                recheck.first().state !in NativeWorkmanagerPlugin.TERMINAL_STATES) {
                                // New task is alive — this was a REPLACE cancellation, retry.
                                NativeLogger.d("🔄 REPLACE detected, retrying observation: $taskId")
                                retries++
                                continue
                            }
                            taskStatuses[taskId] = "cancelled"
                            withContext(Dispatchers.IO) {
                                taskStore.updateStatus(taskId, "cancelled")
                            }
                            NativeLogger.d("⚠️ WorkInfo CANCELLED: $taskId")
                            break
                        }
                        else -> break
                    }
                }
            }
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e  // Re-throw so coroutine cancellation propagates normally
        } catch (e: Exception) {
            NativeLogger.e("❌ Failed to observe work completion for $taskId", e)
        }
    }
}

/**
 * Reconcile SQLite task rows with WorkManager after app restart.
 *
 * DartWorkers complete via WorkInfo but historically did not persist terminal
 * status when the observeWorkCompletion coroutine was lost on process death.
 */
internal suspend fun NativeWorkmanagerPlugin.syncTaskStoreWithWorkManager() {
    try {
        val wm = WorkManager.getInstance(context)
        val stale = withContext(Dispatchers.IO) {
            taskStore.getAllTasks().filter { it.status == "pending" || it.status == "running" }
        }
        for (record in stale) {
            val infos = try {
                wm.getWorkInfosForUniqueWorkFlow(record.taskId).first()
            } catch (_: Exception) {
                emptyList()
            }
            val info = infos.firstOrNull() ?: continue
            val syncedStatus = when (info.state) {
                WorkInfo.State.SUCCEEDED -> "completed"
                WorkInfo.State.FAILED -> "failed"
                WorkInfo.State.CANCELLED -> "cancelled"
                WorkInfo.State.RUNNING -> "running"
                else -> null
            } ?: continue

            if (syncedStatus == record.status) continue

            val resultJson = when (syncedStatus) {
                "completed", "failed" ->
                    info.outputData.keyValueMap.takeIf { it.isNotEmpty() }?.let { toJson(it) }
                else -> null
            }
            withContext(Dispatchers.IO) {
                taskStore.updateStatus(record.taskId, syncedStatus, resultJson)
            }
            taskStatuses[record.taskId] = syncedStatus
            NativeLogger.d("Synced task ${record.taskId}: ${record.status} -> $syncedStatus")
        }
    } catch (e: Exception) {
        NativeLogger.e("syncTaskStoreWithWorkManager failed", e)
    }
}

/**
 * Derive a structured error-code string from a worker failure message.
 *
 * The returned value is the canonical raw string understood by
 * Dart's [NativeWorkManagerError.fromString()].  Pattern-matching on the
 * human-readable message is intentional: the kmpworkmanager library does
 * not expose a typed error-code in WorkerResult.Failure, so we infer it
 * from the message text set by each worker.
 */
internal fun NativeWorkmanagerPlugin.deriveErrorCode(message: String?): String {
    if (message == null) return "UNKNOWN"
    return when {
        message.startsWith("HTTP 4") -> "HTTP_CLIENT_ERROR"
        message.startsWith("HTTP 5") -> "HTTP_SERVER_ERROR"
        message.contains("timeout", ignoreCase = true) -> "TIMEOUT"
        message.contains("network", ignoreCase = true) ||
        message.contains("connect", ignoreCase = true) ||
        message.contains("socket", ignoreCase = true) ||
        message.contains("unreachable", ignoreCase = true) -> "NETWORK_ERROR"
        message.contains("disk space", ignoreCase = true) ||
        message.contains("insufficient", ignoreCase = true) ||
        message.contains("no space", ignoreCase = true) -> "INSUFFICIENT_STORAGE"
        message.contains("not found", ignoreCase = true) ||
        message.contains("no such file", ignoreCase = true) ||
        message.contains("does not exist", ignoreCase = true) -> "FILE_NOT_FOUND"
        message.contains("unsafe", ignoreCase = true) ||
        message.contains("ssrf", ignoreCase = true) ||
        message.contains("security", ignoreCase = true) -> "SECURITY_VIOLATION"
        message.contains("cancel", ignoreCase = true) -> "CANCELLED"
        else -> "WORKER_EXCEPTION"
    }
}

