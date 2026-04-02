package dev.brewkits.native_workmanager

import android.content.Context
import dev.brewkits.native_workmanager.store.MiddlewareStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject

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
 */
fun NativeWorkmanagerPlugin.Companion.applyMiddleware(context: Context, workerClassName: String, configJson: String): String {
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
                // Add more middleware types here
            }
        }

        return if (modified) config.toString() else configJson
    } catch (e: Exception) {
        NativeLogger.e("❌ Error applying middleware", e)
        return configJson
    }
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
