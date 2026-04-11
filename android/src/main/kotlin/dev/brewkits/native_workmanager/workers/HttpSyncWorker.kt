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
        val tokenRefreshConfig: dev.brewkits.native_workmanager.workers.utils.HttpSecurityHelper.TokenRefreshConfig? = null,
    ) {
        val httpMethod: String get() = (method ?: "post").uppercase()
        val timeout: Long get() = timeoutMs ?: DEFAULT_TIMEOUT_MS
    }

    override suspend fun doWork(input: String?, env: dev.brewkits.kmpworkmanager.background.domain.WorkerEnvironment): WorkerResult = withContext(Dispatchers.IO) {
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
                tokenRefreshConfig = dev.brewkits.native_workmanager.workers.utils.HttpSecurityHelper.TokenRefreshConfig.fromMap(j.optJSONObject("tokenRefresh")),
            )
        } catch (e: Exception) {
            throw IllegalArgumentException("Invalid config JSON: ${e.message}", e)
        }

        // Validate URL scheme (prevent file://, content://, etc.)
        if (!SecurityValidator.validateURL(config.url)) {
            Log.e(TAG, "Error - Invalid or unsafe URL")
            return@withContext WorkerResult.Failure("Invalid or unsafe URL")
        }

        // Build HTTP client with timeout
        val client = OkHttpClient.Builder()
            .connectTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .readTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .writeTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .build()

        // Build request helper
        fun buildRequest(newToken: String? = null): Request {
            val sanitizedURL = SecurityValidator.sanitizedURL(config.url)
            Log.d(TAG, "${config.httpMethod} $sanitizedURL")

            val bodyData = config.requestBody?.toByteArray(Charsets.UTF_8)
            val requestBody = bodyData?.let {
                if (!SecurityValidator.validateRequestSize(it)) null
                else it.toRequestBody(JSON_CONTENT_TYPE.toMediaType())
            } ?: if (config.httpMethod in listOf("POST", "PUT", "PATCH")) {
                ByteArray(0).toRequestBody(JSON_CONTENT_TYPE.toMediaType())
            } else null

            val requestBuilder = Request.Builder()
                .url(config.url)
                .method(config.httpMethod, requestBody)
                .header("Content-Type", JSON_CONTENT_TYPE)

            config.headers?.forEach { (key, value) -> requestBuilder.header(key, value) }

            // Inject refreshed token
            newToken?.let { token ->
                config.tokenRefreshConfig?.let { tr ->
                    requestBuilder.header(tr.tokenHeaderName, "${tr.tokenPrefix}$token")
                }
            }

            return config.requestSigningConfig?.let { 
                dev.brewkits.native_workmanager.workers.utils.RequestSigner.sign(requestBuilder.build(), it) 
            } ?: requestBuilder.build()
        }

        // Execute request
        return@withContext try {
            var request = buildRequest()
            var response = client.newCall(request).execute()

            // Handle 401 with Token Refresh
            if (response.code == 401 && config.tokenRefreshConfig != null) {
                Log.d(TAG, "Received 401 — Attempting token refresh...")
                val newToken = dev.brewkits.native_workmanager.workers.utils.HttpSecurityHelper.attemptTokenRefresh(
                    client, config.tokenRefreshConfig
                )
                
                if (newToken != null) {
                    Log.d(TAG, "Token refresh successful — retrying request...")
                    response.close()
                    request = buildRequest(newToken)
                    response = client.newCall(request).execute()
                }
            }

            response.use { resp ->
                val responseBytes = resp.body?.bytes() ?: ByteArray(0)

                // Validate response body size
                if (!SecurityValidator.validateResponseSize(responseBytes)) {
                    Log.e(TAG, "Error - Response body too large")
                    return@use WorkerResult.Failure("Response body too large")
                }

                val statusCode = resp.code
                val success = statusCode in 200..299
                val responseString = responseBytes.toString(Charsets.UTF_8)

                if (success) {
                    Log.d(TAG, "Success - Status $statusCode")
                    WorkerResult.Success(
                        message = "HTTP $statusCode",
                        data = buildJsonObject {
                            put("statusCode", statusCode)
                            put("body", responseString)
                        }
                    )
                } else {
                    val truncatedError = SecurityValidator.truncateForLogging(responseString, 200)
                    Log.e(TAG, "Failed - Status $statusCode")
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
        obj.keys().forEach { key -> map[key] = obj.opt(key)?.toString() ?: "" }
        return map
    }
}
