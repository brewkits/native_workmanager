package dev.brewkits.native_workmanager.workers

import android.util.Log
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Native HTTP sync worker for Android.
 *
 * Optimized for JSON request/response synchronization scenarios.
 * Automatically sets Content-Type to application/json.
 *
 * **Configuration JSON:**
 * ```json
 * {
 *   "url": "https://api.example.com/sync",
 *   "method": "post",           // Optional: "get", "post", "put" (default: "post")
 *   "headers": {                // Optional
 *     "Authorization": "Bearer token"
 *   },
 *   "requestBody": {            // Optional: JSON object to send
 *     "lastSync": 1234567890,
 *     "data": [...]
 *   },
 *   "timeoutMs": 60000         // Optional: Timeout (default: 1 minute)
 * }
 * ```
 *
 * **Use Cases:**
 * - Periodic data synchronization
 * - API sync endpoints
 * - JSON-based communication
 *
 * **Performance:** ~3-5MB RAM, optimized for JSON
 */
class HttpSyncWorker : AndroidWorker {

    companion object {
        private const val TAG = "HttpSyncWorker"
        private const val DEFAULT_TIMEOUT_MS = 60_000L
        private const val JSON_CONTENT_TYPE = "application/json"

    }

    data class Config(
        val url: String,
        val method: String? = null,
        val headers: Map<String, String>? = null,
        val requestBody: String? = null,
        val timeoutMs: Long? = null,
        val requestSigningConfig: dev.brewkits.native_workmanager.workers.utils.RequestSigner.Config? = null,
    ) {
        val httpMethod: String get() = (method ?: "post").uppercase()
        val timeout: Long get() = timeoutMs ?: DEFAULT_TIMEOUT_MS
    }

    override suspend fun doWork(input: String?): WorkerResult = withContext(Dispatchers.IO) {
        if (input.isNullOrEmpty()) {
            throw IllegalArgumentException("Input JSON is required")
        }

        // Parse configuration
        val config = try {
            val j = org.json.JSONObject(input)
            Config(
                url = j.getString("url"),
                method = if (j.has("method") && !j.isNull("method")) j.getString("method") else null,
                headers = parseStringMap(j.optJSONObject("headers")),
                requestBody = if (j.has("requestBody") && !j.isNull("requestBody")) j.get("requestBody").toString() else null,
                timeoutMs = if (j.has("timeoutMs")) j.getLong("timeoutMs") else null,
                requestSigningConfig = dev.brewkits.native_workmanager.workers.utils.RequestSigner.fromMap(j.optJSONObject("requestSigning")),
            )
        } catch (e: Exception) {
            throw IllegalArgumentException("Invalid config JSON: ${e.message}", e)
        }

        // ✅ SECURITY: Validate URL scheme (prevent file://, content://, etc.)
        if (!SecurityValidator.validateURL(config.url)) {
            Log.e(TAG, "Error - Invalid or unsafe URL")
            return@withContext WorkerResult.Failure("Invalid or unsafe URL")
        }

        // ✅ SECURITY: Sanitize URL for logging (redact query params)
        val sanitizedURL = SecurityValidator.sanitizedURL(config.url)
        Log.d(TAG, "${config.httpMethod} $sanitizedURL")

        // Build HTTP client with timeout
        val client = OkHttpClient.Builder()
            .connectTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .readTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .writeTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .build()

        // Encode request body
        val requestBody = if (config.requestBody != null) {
            // NET-009: validate that the body is valid JSON before sending with Content-Type: application/json.
            // A non-JSON body would be silently transmitted, confusing the server.
            try {
                org.json.JSONObject(config.requestBody)
            } catch (_: org.json.JSONException) {
                try {
                    org.json.JSONArray(config.requestBody)
                } catch (_: org.json.JSONException) {
                    Log.e(TAG, "requestBody is not valid JSON; refusing to send with Content-Type: application/json")
                    return@withContext WorkerResult.Failure("requestBody is not valid JSON")
                }
            }

            val bodyBytes = config.requestBody.toByteArray(Charsets.UTF_8)

            // ✅ SECURITY: Validate request body size
            if (!SecurityValidator.validateRequestSize(bodyBytes)) {
                Log.e(TAG, "Error - Request body too large")
                return@withContext WorkerResult.Failure("Request body too large")
            }

            Log.d(TAG, "Request body size: ${bodyBytes.size} bytes")
            bodyBytes.toRequestBody(JSON_CONTENT_TYPE.toMediaType())
        } else {
            if (config.httpMethod in listOf("POST", "PUT", "PATCH")) {
                ByteArray(0).toRequestBody(JSON_CONTENT_TYPE.toMediaType())
            } else {
                null
            }
        }

        // Build request. Use header() (not addHeader()) so custom Content-Type overrides the default.
        val requestBuilder = Request.Builder()
            .url(config.url)
            .method(config.httpMethod, requestBody)
            .header("Content-Type", JSON_CONTENT_TYPE)

        // Add custom headers; addHeader() accumulates while header() replaces — use addHeader for
        // all user headers so multiple values (e.g. multiple Accept entries) are preserved.
        config.headers?.forEach { (key, value) ->
            requestBuilder.header(key, value)
        }

        val request = config.requestSigningConfig
            ?.let { dev.brewkits.native_workmanager.workers.utils.RequestSigner.sign(requestBuilder.build(), it) }
            ?: requestBuilder.build()

        // Execute request
        return@withContext try {
            client.newCall(request).execute().use { response ->
                val responseBytes = response.body?.bytes() ?: ByteArray(0)

                // ✅ SECURITY: Validate response body size
                if (!SecurityValidator.validateResponseSize(responseBytes)) {
                    Log.e(TAG, "Error - Response body too large")
                    return@use WorkerResult.Failure("Response body too large")
                }

                val statusCode = response.code
                val success = statusCode in 200..299
                val responseString = responseBytes.toString(Charsets.UTF_8)

                // Collect response headers
                val headers = mutableMapOf<String, String>()
                response.headers.forEach { (name, value) ->
                    headers[name] = value
                }

                if (success) {
                    // ✅ SECURITY: Truncate response JSON for logging
                    val truncatedResponse = SecurityValidator.truncateForLogging(responseString, 500)
                    Log.d(TAG, "Success - Status $statusCode")
                    Log.d(TAG, "Response JSON:\n$truncatedResponse")

                    // ✅ Return success with response data
                    WorkerResult.Success(
                        message = "HTTP $statusCode",
                        data = buildJsonObject {
                            put("statusCode", statusCode)
                            put("body", responseString)
                        }
                    )
                } else {
                    // ✅ SECURITY: Truncate error body for logging
                    val truncatedError = SecurityValidator.truncateForLogging(responseString, 200)
                    Log.e(TAG, "Failed - Status $statusCode")
                    Log.e(TAG, "Error: $truncatedError")

                    WorkerResult.Failure(
                        message = "HTTP $statusCode: $truncatedError",
                        shouldRetry = statusCode >= 500
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error - ${e.message}", e)
            WorkerResult.Failure(
                message = e.message ?: "Unknown error",
                shouldRetry = true
            )
        }
    }

    private fun parseStringMap(obj: org.json.JSONObject?): Map<String, String>? {
        if (obj == null) return null
        val map = mutableMapOf<String, String>()
        // CRIT-003: use opt().toString() instead of getString() so non-string values
        // (numbers, booleans) are coerced safely instead of throwing JSONException.
        obj.keys().forEach { key -> map[key] = obj.opt(key)?.toString() ?: "" }
        return map
    }
}
