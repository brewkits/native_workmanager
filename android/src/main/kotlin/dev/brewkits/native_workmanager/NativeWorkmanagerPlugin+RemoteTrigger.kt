package dev.brewkits.native_workmanager

import android.content.Context
import dev.brewkits.native_workmanager.store.RemoteTriggerStore
import dev.brewkits.native_workmanager.utils.CommandProcessor
import dev.brewkits.native_workmanager.utils.MappingUtils
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CancellationException
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
                remoteTriggerStore.setRejectUnsignedCommands(source, ruleMap["rejectUnsignedCommands"] == true)
            }

            NativeLogger.d("✅ Remote trigger registered for $source (key: $payloadKey, hmac: ${secretKey != null})")
            result.success(null)
        } catch (e: CancellationException) {
            throw e
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
            val prefs = context.getSharedPreferences(SHARED_PREFS_NAME, Context.MODE_PRIVATE)
            val verdict = RemoteTriggerSignature.verify(
                payload = payload,
                secretKey = record.secretKey,
                nowMs = System.currentTimeMillis(),
                nonces = RemoteTriggerSignature.sharedNonceStore(prefs),
            ) { legacySignature -> verifyHmac(payload, record.secretKey, legacySignature) }
            when (verdict) {
                RemoteTriggerSignature.Verdict.VALID_V2 -> Unit
                RemoteTriggerSignature.Verdict.VALID_LEGACY ->
                    NativeLogger.w("⚠️ Remote trigger for $source used the DEPRECATED v1 signature " +
                        "(no timestamp/nonce, replayable). Switch your backend to v2.")
                else -> {
                    NativeLogger.w("⚠️ Remote trigger REJECTED ($verdict): invalid signature for $source")
                    return false
                }
            }
        } else if (payload["native_wm"] != null || (payload["data"] as? Map<*, *>)?.get("native_wm") != null) {
            if (RemoteTriggerSignature.shouldRejectUnsignedCommand(false, true, store.rejectsUnsignedCommands(source))) {
                NativeLogger.w("⚠️ Unsigned native_wm command REJECTED for $source (rejectUnsignedCommands=true).")
                return false
            }
            NativeLogger.w("⚠️ Unsigned remote command for $source: no secretKey is set on this rule, so " +
                "anyone who can deliver a push can run native_wm commands. Set RemoteTriggerRule.secretKey.")
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

        // Constant-time comparison to avoid a timing side-channel on signature
        // verification. String.equals short-circuits on the first mismatch, which
        // can leak how many leading bytes matched. MessageDigest.isEqual compares
        // in constant time. Decode the provided hex first so we compare raw bytes.
        val providedBytes = hexStringToBytes(signature) ?: return false
        return java.security.MessageDigest.isEqual(hmacBytes, providedBytes)
    } catch (e: Exception) {
        NativeLogger.e("HMAC Verification failed", e)
        return false
    }
}

/** Decode a hex string to bytes, or null if it is malformed (odd length / non-hex). */
private fun hexStringToBytes(hex: String): ByteArray? {
    if (hex.isEmpty() || hex.length % 2 != 0) return null
    return try {
        ByteArray(hex.length / 2) { i ->
            val hi = Character.digit(hex[i * 2], 16)
            val lo = Character.digit(hex[i * 2 + 1], 16)
            if (hi < 0 || lo < 0) throw NumberFormatException("non-hex character")
            ((hi shl 4) or lo).toByte()
        }
    } catch (e: Exception) {
        null
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
