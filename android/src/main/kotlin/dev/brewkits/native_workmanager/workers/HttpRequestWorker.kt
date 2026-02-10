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

/**
 * Native HTTP request worker for Android.
 *
 * Executes HTTP requests using OkHttp without requiring Flutter Engine.
 * Supports GET, POST, PUT, DELETE, PATCH methods with custom headers and body.
 * Supports regex-based response validation to detect API errors in 200 responses.
 *
 * **Configuration JSON:**
 * ```json
 * {
 *   "url": "https://api.example.com/endpoint",
 *   "method": "post",           // Optional: "get", "post", "put", "delete", "patch" (default: "get")
 *   "headers": {                // Optional
 *     "Authorization": "Bearer token",
 *     "Content-Type": "application/json"
 *   },
 *   "body": "{\"key\":\"value\"}", // Optional: Request body
 *   "timeoutMs": 30000          // Optional: Timeout in milliseconds (default: 30s)
 * }
 * ```
 *
 * **Configuration JSON (With Response Validation - NEW):**
 * ```json
 * {
 *   "url": "https://api.example.com/endpoint",
 *   "method": "post",
 *   "body": "{\"action\":\"login\"}",
 *   "successPattern": "\"status\"\\s*:\\s*\"success\"",  // Regex pattern for success
 *   "failurePattern": "\"status\"\\s*:\\s*\"error\""     // Regex pattern for failure
 * }
 * ```
 *
 * **Validation Behavior:**
 * - If `failurePattern` matches, task fails even with HTTP 200
 * - If `successPattern` provided and doesn't match, task fails even with HTTP 200
 * - Patterns are checked in order: failurePattern → successPattern
 *
 * **Performance:** ~2-3MB RAM, <50ms cold start
 */
class HttpRequestWorker : AndroidWorker {

    companion object {
        private const val TAG = "HttpRequestWorker"
        private const val DEFAULT_TIMEOUT_MS = 30_000L

    }

    data class Config(
        val url: String,
        val method: String? = null,
        val headers: Map<String, String>? = null,
        val body: String? = null,
        val timeoutMs: Long? = null,
        // 👇 NEW: Response validation patterns
        val successPattern: String? = null,  // Regex pattern that response must match to be success
        val failurePattern: String? = null   // Regex pattern that indicates failure (overrides 200)
    ) {
        val httpMethod: String get() = (method ?: "get").uppercase()
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
                body = if (j.has("body") && !j.isNull("body")) j.getString("body") else null,
                timeoutMs = if (j.has("timeoutMs")) j.getLong("timeoutMs") else null,
                // 👇 NEW: Response validation
                successPattern = if (j.has("successPattern") && !j.isNull("successPattern")) j.getString("successPattern") else null,
                failurePattern = if (j.has("failurePattern") && !j.isNull("failurePattern")) j.getString("failurePattern") else null
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

        // Build request
        val requestBuilder = Request.Builder()
            .url(config.url)
            .method(
                config.httpMethod,
                when {
                    config.body != null -> {
                        val bodyBytes = config.body.toByteArray(Charsets.UTF_8)

                        // ✅ SECURITY: Validate request body size
                        if (!SecurityValidator.validateRequestSize(bodyBytes)) {
                            Log.e(TAG, "Error - Request body too large")
                            return@withContext WorkerResult.Failure("Request body too large")
                        }

                        val contentType = config.headers?.get("Content-Type")
                            ?: "application/json"
                        bodyBytes.toRequestBody(contentType.toMediaType())
                    }
                    config.httpMethod in listOf("POST", "PUT", "PATCH") -> {
                        // Empty body for POST/PUT/PATCH if no body provided
                        ByteArray(0).toRequestBody(null)
                    }
                    else -> null
                }
            )

        // Add headers
        config.headers?.forEach { (key, value) ->
            requestBuilder.addHeader(key, value)
        }

        val request = requestBuilder.build()

        // Execute request
        return@withContext try {
            client.newCall(request).execute().use { response ->
                val responseBody = response.body?.bytes() ?: ByteArray(0)

                // ✅ SECURITY: Validate response body size
                if (!SecurityValidator.validateResponseSize(responseBody)) {
                    Log.e(TAG, "Error - Response body too large")
                    return@withContext WorkerResult.Failure("Response body too large")
                }

                val statusCode = response.code
                val success = statusCode in 200..299
                val bodyString = responseBody.toString(Charsets.UTF_8)

                // Collect response headers
                val headers = mutableMapOf<String, String>()
                response.headers.forEach { (name, value) ->
                    headers[name] = value
                }

                if (success) {
                    // 👇 NEW: Validate response body against patterns (even if HTTP 200)
                    val validationError = validateResponse(bodyString, config)
                    if (validationError != null) {
                        Log.e(TAG, "Validation failed - $validationError")
                        Log.e(TAG, "Response body: ${SecurityValidator.truncateForLogging(bodyString, 200)}")
                        return@withContext WorkerResult.Failure(
                            message = "Response validation failed: $validationError",
                            shouldRetry = false  // Don't retry validation failures
                        )
                    }

                    Log.d(TAG, "Success - Status $statusCode, Body size: ${responseBody.size} bytes")

                    // ✅ Return success with response data
                    WorkerResult.Success(
                        message = "HTTP $statusCode",
                        data = mapOf(
                            "statusCode" to statusCode,
                            "body" to bodyString,
                            "headers" to headers,
                            "contentLength" to responseBody.size
                        )
                    )
                } else {
                    // ✅ SECURITY: Truncate error body for logging
                    val truncatedError = SecurityValidator.truncateForLogging(bodyString, 200)
                    Log.e(TAG, "Failed - Status $statusCode")
                    Log.e(TAG, "Error body: $truncatedError")

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

    /**
     * Validate response body against configured patterns.
     *
     * @param responseBody The response body to validate
     * @param config Configuration with validation patterns
     * @return Error message if validation fails, null if validation passes
     */
    private fun validateResponse(responseBody: String, config: Config): String? {
        // Check failure pattern first (highest priority)
        if (config.failurePattern != null) {
            try {
                val failureRegex = Regex(config.failurePattern, RegexOption.IGNORE_CASE)
                if (failureRegex.containsMatchIn(responseBody)) {
                    Log.d(TAG, "Response matched failure pattern: ${config.failurePattern}")
                    return "Response matches failure pattern"
                }
            } catch (e: Exception) {
                Log.e(TAG, "Invalid failure pattern regex: ${e.message}")
                return "Invalid failure pattern regex: ${e.message}"
            }
        }

        // Check success pattern (if provided)
        if (config.successPattern != null) {
            try {
                val successRegex = Regex(config.successPattern, RegexOption.IGNORE_CASE)
                if (!successRegex.containsMatchIn(responseBody)) {
                    Log.d(TAG, "Response did not match success pattern: ${config.successPattern}")
                    return "Response does not match success pattern"
                }
            } catch (e: Exception) {
                Log.e(TAG, "Invalid success pattern regex: ${e.message}")
                return "Invalid success pattern regex: ${e.message}"
            }
        }

        // Validation passed
        return null
    }

    private fun parseStringMap(obj: org.json.JSONObject?): Map<String, String>? {
        if (obj == null) return null
        val map = mutableMapOf<String, String>()
        obj.keys().forEach { key -> map[key] = obj.getString(key) }
        return map
    }
}
