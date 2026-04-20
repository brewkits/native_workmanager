package dev.brewkits.native_workmanager

import android.content.Context
import dev.brewkits.native_workmanager.store.MiddlewareStore
import dev.brewkits.native_workmanager.utils.MappingUtils.toJson
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

internal fun NativeWorkmanagerPlugin.handleRegisterMiddleware(call: MethodCall, result: Result) {
    scope.launch {
        try {
            val type = call.argument<String>("type")
                ?: return@launch result.error("INVALID_ARGS", "type required", null)
            val configMap = call.arguments as Map<String, Any?>
            val configJson = toJson(configMap)

            NativeLogger.d("🛡️ Registering middleware: $type")

            withContext(Dispatchers.IO) {
                middlewareStore.add(type, configJson)
            }

            result.success(null)
        } catch (e: Exception) {
            NativeLogger.e("❌ Register middleware error", e)
            result.error("MIDDLEWARE_ERROR", e.message, null)
        }
    }
}

/**
 * Applies registered middleware to a worker configuration.
 *
 * This can be called from any worker before execution.
 * Internal top-level function so it can be imported from utils sub-packages.
 */
internal fun applyMiddlewareInternal(context: Context, workerClassName: String, configJson: String): String {
    try {
        val store = MiddlewareStore.getInstance(context)
        val middlewares = store.getAll()
        if (middlewares.isEmpty()) return configJson

        val config = JSONObject(configJson)
        var modified = false

        for (mw in middlewares) {
            val mwConfig = JSONObject(mw.configJson)
            when (mw.type) {
                "header" -> {
                    if (applyHeaderMiddleware(config, mwConfig)) {
                        modified = true
                    }
                }
                "remoteConfig" -> {
                    if (applyRemoteConfigMiddleware(config, mwConfig, workerClassName)) {
                        modified = true
                    }
                }
            }
        }

        return if (modified) config.toString() else configJson
    } catch (e: Exception) {
        NativeLogger.e("❌ Error applying middleware", e)
        return configJson
    }
}

/** Companion wrapper for callers that use [NativeWorkmanagerPlugin.applyMiddleware]. */
fun NativeWorkmanagerPlugin.Companion.applyMiddleware(
    context: Context,
    workerClassName: String,
    configJson: String,
): String = applyMiddlewareInternal(context, workerClassName, configJson)

private fun applyRemoteConfigMiddleware(
    workerConfig: JSONObject,
    mwConfig: JSONObject,
    workerClassName: String
): Boolean {
    val targetType = mwConfig.optString("workerType").takeIf { it.isNotEmpty() }
    if (targetType != null && !workerClassName.contains(targetType, ignoreCase = true)) {
        return false
    }
    val values = mwConfig.optJSONObject("values") ?: return false
    var modified = false
    val keys = values.keys()
    while (keys.hasNext()) {
        val key = keys.next()
        workerConfig.put(key, values.get(key))
        modified = true
    }
    return modified
}

private fun applyHeaderMiddleware(workerConfig: JSONObject, mwConfig: JSONObject): Boolean {
    val url = workerConfig.optString("url", null) ?: return false
    val pattern = mwConfig.optString("urlPattern", null)
    
    // Check if URL matches pattern (if provided)
    if (pattern != null && !Regex(pattern).containsMatchIn(url)) {
        return false
    }

    val headersToAdd = mwConfig.optJSONObject("headers") ?: return false
    val workerHeaders = workerConfig.optJSONObject("headers") ?: JSONObject().also { workerConfig.put("headers", it) }

    val keys = headersToAdd.keys()
    while (keys.hasNext()) {
        val key = keys.next()
        workerHeaders.put(key, headersToAdd.get(key))
    }

    return true
}

/**
 * Fire-and-forget HTTP POST for LoggingMiddleware.
 *
 * Called after each task completes (success or failure). Finds all registered
 * LoggingMiddleware records and POSTs task execution metadata to each logUrl.
 * Errors are logged but never propagated — logging must never affect worker results.
 */
internal fun NativeWorkmanagerPlugin.applyLoggingMiddleware(
    taskId: String,
    workerClassName: String,
    success: Boolean,
    message: String?,
    durationMs: Long?,
    workerConfig: String?
) {
    try {
        val middlewares = middlewareStore.getAll().filter { it.type == "logging" }
        if (middlewares.isEmpty()) return

        for (mw in middlewares) {
            val mwConfig = try { JSONObject(mw.configJson) } catch (_: Exception) { continue }
            val logUrl = mwConfig.optString("logUrl").takeIf { it.isNotEmpty() } ?: continue
            val includeConfig = mwConfig.optBoolean("includeConfig", false)

            scope.launch(Dispatchers.IO) {
                try {
                    val payload = JSONObject().apply {
                        put("taskId", taskId)
                        put("workerClassName", workerClassName)
                        put("success", success)
                        put("timestamp", System.currentTimeMillis())
                        if (durationMs != null) put("durationMs", durationMs)
                        if (!message.isNullOrEmpty()) put("message", message)
                        if (includeConfig && workerConfig != null) {
                            try { put("workerConfig", JSONObject(workerConfig)) } catch (_: Exception) {}
                        }
                    }
                    val conn = URL(logUrl).openConnection() as HttpURLConnection
                    try {
                        conn.requestMethod = "POST"
                        conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                        conn.doOutput = true
                        conn.connectTimeout = 5_000
                        conn.readTimeout = 5_000
                        conn.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
                        conn.responseCode // trigger the request
                    } finally {
                        conn.disconnect()
                    }
                } catch (e: Exception) {
                    NativeLogger.e("LoggingMiddleware: Failed to POST to $logUrl for task '$taskId'", e)
                }
            }
        }
    } catch (e: Exception) {
        NativeLogger.e("LoggingMiddleware: Unexpected error for task '$taskId'", e)
    }
}
