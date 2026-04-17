package dev.brewkits.native_workmanager.utils

import android.content.Context
import androidx.work.*
import dev.brewkits.native_workmanager.NativeLogger
import dev.brewkits.native_workmanager.applyMiddleware
import dev.brewkits.native_workmanager.OfflineQueueProcessor
import dev.brewkits.native_workmanager.store.ChainStore
import dev.brewkits.native_workmanager.store.OfflineQueueStore
import dev.brewkits.native_workmanager.store.TaskStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.util.*

/**
 * Central processor for background commands (from Push or MethodChannel).
 */
object CommandProcessor {

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    fun handleDirectRemoteCommand(context: Context, command: Map<String, Any?>): Boolean {
        val action = command["action"] as? String ?: return false
        val data = command["data"] as? Map<String, Any?> ?: return false

        NativeLogger.d("📡 Processing direct command: $action")

        return try {
            when (action) {
                "enqueue_task" -> {
                    val taskId = data["taskId"] as? String ?: UUID.randomUUID().toString()
                    val workerClassName = data["workerClassName"] as? String ?: return false
                    @Suppress("UNCHECKED_CAST")
                    val workerConfig = data["workerConfig"] as? Map<String, Any?>
                    val json = if (workerConfig != null) MappingUtils.toJson(workerConfig) else "{}"
                    
                    enqueueFromRemote(context, taskId, workerClassName, json)
                    true
                }
                "enqueue_chain" -> {
                    val store = TaskStore(context)
                    val cStore = ChainStore(context)
                    val chainName = data["name"] as? String ?: "remote_chain_${System.currentTimeMillis()}"
                    @Suppress("UNCHECKED_CAST")
                    val steps = data["steps"] as? List<List<Map<String, Any?>>> ?: emptyList()

                    if (steps.isEmpty()) {
                        NativeLogger.w("⚠️ Command 'enqueue_chain' REJECTED: Steps list is empty")
                        return false
                    }

                    scope.launch {
                        try {
                            ChainHelper.enqueueChain(
                                context = context,
                                taskStore = store,
                                chainStore = cStore,
                                chainName = chainName,
                                steps = steps,
                                onObserveTaskId = null
                            )
                        } catch (e: Exception) {
                            NativeLogger.e("❌ Error enqueuing chain command", e)
                        }
                    }
                    true
                }
                "enqueue_graph" -> {
                    val store = TaskStore(context)
                    scope.launch {
                        try {
                            GraphHelper.enqueueGraph(
                                context = context,
                                taskStore = store,
                                graphMap = data,
                                onObserveTaskId = { }
                            )
                        } catch (e: Exception) {
                            NativeLogger.e("❌ Error enqueuing graph command", e)
                        }
                    }
                    true
                }
                "offline_queue_enqueue" -> {
                    val queueId = data["queueId"] as? String ?: "default"
                    @Suppress("UNCHECKED_CAST")
                    val entry = data["entry"] as? Map<String, Any?> ?: return false
                    @Suppress("UNCHECKED_CAST")
                    val workerConfig = (entry["workerConfig"] as? Map<String, Any?>)?.let { MappingUtils.toJson(it) }
                    @Suppress("UNCHECKED_CAST")
                    val retryPolicy = (entry["retryPolicy"] as? Map<String, Any?>)?.let { MappingUtils.toJson(it) }
                    val store = OfflineQueueStore(context)
                    store.enqueue(
                        queueId = queueId,
                        taskId = entry["taskId"] as? String ?: UUID.randomUUID().toString(),
                        workerClassName = entry["workerClassName"] as? String ?: return false,
                        workerConfig = workerConfig,
                        retryPolicy = retryPolicy,
                    )
                    scheduleOfflineQueueProcessor(context)
                    true
                }
                else -> false
            }
        } catch (e: Exception) {
            NativeLogger.e("❌ Error in CommandProcessor", e)
            false
        }
    }

    fun enqueueFromRemote(
        context: Context,
        taskId: String,
        workerClassName: String,
        inputJson: String
    ) {
        val effectiveInputJson = applyMiddleware(context, workerClassName, inputJson)

        val workerClass = dev.brewkits.kmpworkmanager.background.data.KmpWorker::class.java
        val dataBuilder = Data.Builder()
            .putString("workerClassName", workerClassName)
            .putString("inputJson", effectiveInputJson)

        val request = OneTimeWorkRequest.Builder(workerClass)
            .setInputData(dataBuilder.build())
            .addTag("native_wm_remote")
            .addTag(taskId)
            .addTag(workerClassName)
            .build()

        WorkManager.getInstance(context).enqueueUniqueWork(
            taskId,
            ExistingWorkPolicy.REPLACE,
            request
        )
    }

    fun scheduleOfflineQueueProcessor(context: Context) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val request = OneTimeWorkRequest.Builder(OfflineQueueProcessor::class.java)
            .setConstraints(constraints)
            .addTag("offline_queue_processor")
            .build()

        WorkManager.getInstance(context).enqueueUniqueWork(
            "offline_queue_processor",
            ExistingWorkPolicy.KEEP,
            request
        )
    }

    fun jsonToMap(json: JSONObject): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = json.get(key)
            map[key] = when (value) {
                is JSONObject -> jsonToMap(value)
                is JSONArray -> (0 until value.length()).map { i ->
                    val item = value.get(i)
                    if (item is JSONObject) jsonToMap(item) else item
                }
                JSONObject.NULL -> null
                else -> value
            }
        }
        return map
    }
}
