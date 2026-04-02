package dev.brewkits.native_workmanager

import android.content.Context
import dev.brewkits.kmpworkmanager.background.domain.ExistingPolicy
import dev.brewkits.kmpworkmanager.background.domain.TaskTrigger
import dev.brewkits.kmpworkmanager.background.domain.Constraints
import dev.brewkits.native_workmanager.store.RemoteTriggerStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

internal fun NativeWorkmanagerPlugin.handleRegisterRemoteTrigger(call: MethodCall, result: Result) {
    scope.launch {
        try {
            val source = call.argument<String>("source")
                ?: return@launch result.error("INVALID_ARGS", "source required", null)
            val ruleMap = call.argument<Map<String, Any?>>("rule")
                ?: return@launch result.error("INVALID_ARGS", "rule required", null)

            val payloadKey = ruleMap["payloadKey"] as? String
                ?: return@launch result.error("INVALID_ARGS", "payloadKey required", null)
            val workerMappings = ruleMap["workerMappings"] as? Map<String, Any?>
                ?: return@launch result.error("INVALID_ARGS", "workerMappings required", null)

            val mappingsJson = toJson(workerMappings)

            withContext(Dispatchers.IO) {
                remoteTriggerStore.upsert(
                    source = source,
                    payloadKey = payloadKey,
                    workerMappingsJson = mappingsJson
                )
            }

            NativeLogger.d("✅ Remote trigger registered for $source (key: $payloadKey)")
            result.success(null)
        } catch (e: Exception) {
            NativeLogger.e("❌ Register remote trigger error", e)
            result.error("REGISTER_REMOTE_TRIGGER_ERROR", e.message, null)
        }
    }
}

/**
 * Handle a remote message (FCM/APNs) and optionally trigger a native worker.
 *
 * This method is designed to be called from a native service (e.g. FirebaseMessagingService)
 * without requiring the Flutter Engine to be running.
 *
 * It looks up the registered rules for the given source, matches the payload,
 * performs template substitution, and enqueues a worker.
 */
fun NativeWorkmanagerPlugin.Companion.onRemoteMessage(context: Context, source: String, payload: Map<String, Any?>): Boolean {
    try {
        val store = RemoteTriggerStore(context)
        val record = store.getRule(source) ?: return false

        val triggerValue = payload[record.payloadKey]?.toString() ?: return false
        val mappings = JSONObject(record.workerMappingsJson)

        if (!mappings.has(triggerValue)) return false

        val mapping = mappings.getJSONObject(triggerValue)
        val workerClassName = mapping.getString("workerClassName")
        val workerConfigJson = mapping.optString("workerConfig", "{}")

        // Perform template substitution on workerConfigJson using values from payload
        val substitutedConfig = try {
            val json = JSONObject(workerConfigJson)
            substituteInJsonObject(json, payload)
            json.toString()
        } catch (e: Exception) {
            NativeLogger.e("❌ Error substituting templates in workerConfig", e)
            workerConfigJson
        }

        // Generate a unique taskId for this trigger
        val taskId = "remote_${triggerValue}_${UUID.randomUUID().toString().take(8)}"
        
        enqueueFromRemote(
            context = context,
            taskId = taskId,
            workerClassName = workerClassName,
            inputJson = substitutedConfig
        )

        NativeLogger.d("✅ Remote trigger matched '$triggerValue': Enqueued $workerClassName ($taskId)")
        return true
    } catch (e: Exception) {
        NativeLogger.e("❌ Error handling remote message", e)
        return false
    }
}

private fun substituteInJsonObject(json: JSONObject, values: Map<String, Any?>) {
    val keys = json.keys()
    while (keys.hasNext()) {
        val key = keys.next()
        when (val value = json.get(key)) {
            is String -> {
                if (value.contains("{{") && value.contains("}}")) {
                    json.put(key, substituteString(value, values))
                }
            }
            is JSONObject -> substituteInJsonObject(value, values)
            is JSONArray -> {
                for (i in 0 until value.length()) {
                    val item = value.get(i)
                    if (item is JSONObject) {
                        substituteInJsonObject(item, values)
                    } else if (item is String) {
                        if (item.contains("{{") && item.contains("}}")) {
                            value.put(i, substituteString(item, values))
                        }
                    }
                }
            }
        }
    }
}

private fun substituteString(template: String, values: Map<String, Any?>): String {
    var result = template
    values.forEach { (key, value) ->
        val placeholder = "{{$key}}"
        if (result.contains(placeholder)) {
            result = result.replace(placeholder, value?.toString() ?: "null")
        }
    }
    return result
}

private fun enqueueFromRemote(
    context: Context,
    taskId: String,
    workerClassName: String,
    inputJson: String
) {
    // Apply middleware before enqueuing so header injection / URL-pattern rules are honoured
    // even for remote-triggered tasks that bypass the Flutter/Dart enqueue path.
    val effectiveInputJson = NativeWorkmanagerPlugin.applyMiddleware(context, workerClassName, inputJson)

    val workerClass = dev.brewkits.kmpworkmanager.background.data.KmpWorker::class.java
    val dataBuilder = androidx.work.Data.Builder()
        .putString("workerClassName", workerClassName)
        .putString("inputJson", effectiveInputJson)

    val request = androidx.work.OneTimeWorkRequest.Builder(workerClass)
        .setInputData(dataBuilder.build())
        .addTag("native_wm_remote")
        .addTag(taskId)
        .addTag(workerClassName)
        .build()

    androidx.work.WorkManager.getInstance(context).enqueueUniqueWork(
        taskId,
        androidx.work.ExistingWorkPolicy.REPLACE,
        request
    )
}
