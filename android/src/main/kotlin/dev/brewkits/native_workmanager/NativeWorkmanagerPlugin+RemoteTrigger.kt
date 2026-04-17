package dev.brewkits.native_workmanager

import android.content.Context
import dev.brewkits.native_workmanager.store.RemoteTriggerStore
import dev.brewkits.native_workmanager.utils.CommandProcessor
import dev.brewkits.native_workmanager.utils.MappingUtils
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

            val mappingsJson = MappingUtils.toJson(workerMappings)
            val secretKey = ruleMap["secretKey"] as? String

            withContext(Dispatchers.IO) {
                remoteTriggerStore.upsert(
                    source = source,
                    payloadKey = payloadKey,
                    workerMappingsJson = mappingsJson,
                    secretKey = secretKey
                )
            }

            NativeLogger.d("✅ Remote trigger registered for $source (key: $payloadKey, hmac: ${secretKey != null})")
            result.success(null)
        } catch (e: Exception) {
            NativeLogger.e("❌ Register remote trigger error", e)
            result.error("REGISTER_REMOTE_TRIGGER_ERROR", e.message, null)
        }
    }
}

/**
 * Handle a remote message (FCM/APNs) and optionally trigger a native worker.
 */
fun NativeWorkmanagerPlugin.Companion.onRemoteMessage(context: Context, source: String, payload: Map<String, Any?>): Boolean {
    try {
        val store = RemoteTriggerStore(context)
        val record = store.getRule(source) ?: return false

        // Phase 2: HMAC Verification
        if (record.secretKey != null) {
            val signature = payload["x-native-wm-signature"]?.toString()
            if (signature == null || !verifyHmac(payload, record.secretKey, signature)) {
                NativeLogger.w("⚠️ Remote trigger REJECTED: Invalid HMAC signature for $source")
                return false
            }
        }

        // Mode 1: Direct Command (Highest priority)
        val nativeWmCommand = payload["native_wm"] ?: (payload["data"] as? Map<*, *>)?.get("native_wm")
        
        if (nativeWmCommand != null) {
            NativeLogger.d("📡 Processing direct remote command (Native WM)")
            if (nativeWmCommand is Map<*, *>) {
                @Suppress("UNCHECKED_CAST")
                if (CommandProcessor.handleDirectRemoteCommand(context, nativeWmCommand as Map<String, Any?>)) {
                    return true
                }
            } else if (nativeWmCommand is String) {
                try {
                    val json = JSONObject(nativeWmCommand)
                    if (CommandProcessor.handleDirectRemoteCommand(context, CommandProcessor.jsonToMap(json))) {
                        return true
                    }
                } catch (_: Exception) {}
            }
        }

        // Mode 2: Rule-based Mapping
        val triggerValue = payload[record.payloadKey]?.toString() 
            ?: (payload["data"] as? Map<*, *>)?.get(record.payloadKey)?.toString()
            ?: return false
            
        NativeLogger.d("📡 Processing remote trigger: $source (mapped via ${record.payloadKey})")

        val mappings = JSONObject(record.workerMappingsJson)
        if (!mappings.has(triggerValue)) return false

        val mapping = mappings.getJSONObject(triggerValue)
        val workerClassName = mapping.getString("workerClassName")
        val workerConfigJson = mapping.optString("workerConfig", "{}")

        // Perform template substitution
        val substitutedConfig = try {
            val json = JSONObject(workerConfigJson)
            substituteInJsonObject(json, payload)
            json.toString()
        } catch (e: Exception) {
            NativeLogger.e("❌ Error substituting templates in workerConfig", e)
            workerConfigJson
        }

        val taskId = "remote_${triggerValue}_${UUID.randomUUID().toString().take(8)}"
        
        CommandProcessor.enqueueFromRemote(
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

private fun verifyHmac(payload: Map<String, Any?>, secretKey: String, signature: String): Boolean {
    try {
        val dataToSign = payload.toMutableMap().apply { remove("x-native-wm-signature") }
            .toSortedMap()
            .entries.joinToString("|") { entry ->
                val valueStr = when (val v = entry.value) {
                    null -> "null"
                    is Map<*, *>, is List<*> -> MappingUtils.toJson(v)
                    else -> v.toString()
                }
                "${entry.key}=$valueStr"
            }

        val keySpec = javax.crypto.spec.SecretKeySpec(secretKey.toByteArray(), "HmacSHA256")
        val mac = javax.crypto.Mac.getInstance("HmacSHA256")
        mac.init(keySpec)
        val hmacBytes = mac.doFinal(dataToSign.toByteArray())
        val computedSignature = hmacBytes.joinToString("") { "%02x".format(it) }
        
        return computedSignature.equals(signature, ignoreCase = true)
    } catch (e: Exception) {
        NativeLogger.e("HMAC Verification failed", e)
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
    (values["data"] as? Map<*, *>)?.forEach { (key, value) ->
        val placeholder = "{{$key}}"
        if (result.contains(placeholder)) {
            result = result.replace(placeholder, value?.toString() ?: "null")
        }
    }
    return result
}
