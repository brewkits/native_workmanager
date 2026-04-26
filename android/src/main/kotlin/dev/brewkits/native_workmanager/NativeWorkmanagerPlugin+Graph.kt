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

            val graphId = dev.brewkits.native_workmanager.utils.GraphHelper.enqueueGraph(
                context = context,
                taskStore = taskStore,
                graphMap = graphMap,
                onObserveTaskId = { taskId -> observeChainStepCompletion(taskId) }
            )

            NativeLogger.d("✅ TaskGraph '$graphId' enqueued via GraphHelper")
            result.success("ACCEPTED")
        } catch (e: Exception) {
            NativeLogger.e("❌ Enqueue graph error", e)
            result.error("ENQUEUE_GRAPH_ERROR", e.message, null)
        }
    }
}
