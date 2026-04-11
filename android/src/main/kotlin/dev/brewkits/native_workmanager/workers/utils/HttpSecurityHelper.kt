package dev.brewkits.native_workmanager.workers.utils

import android.util.Log
import okhttp3.CertificatePinner
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaType
import org.json.JSONObject

object HttpSecurityHelper {
    private const val TAG = "HttpSecurityHelper"

    val sharedClient: OkHttpClient by lazy { OkHttpClient() }

    data class TokenRefreshConfig(
        val url: String,
        val method: String = "POST",
        val headers: Map<String, String>? = null,
        val body: Map<String, Any>? = null,
        val responseKey: String = "access_token",
        val tokenHeaderName: String = "Authorization",
        val tokenPrefix: String = "Bearer "
    ) {
        companion object {
            fun fromMap(map: JSONObject?): TokenRefreshConfig? {
                if (map == null) return null
                return try {
                    TokenRefreshConfig(
                        url = map.getString("url"),
                        method = map.optString("method", "POST"),
                        headers = parseStringMap(map.optJSONObject("headers")),
                        body = parseAnyMap(map.optJSONObject("body")),
                        responseKey = map.optString("responseKey", "access_token"),
                        tokenHeaderName = map.optString("tokenHeaderName", "Authorization"),
                        tokenPrefix = map.optString("tokenPrefix", "Bearer ")
                    )
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to parse TokenRefreshConfig: ${e.message}")
                    null
                }
            }

            private fun parseStringMap(obj: JSONObject?): Map<String, String>? {
                if (obj == null) return null
                val map = mutableMapOf<String, String>()
                obj.keys().forEach { key -> map[key] = obj.getString(key) }
                return map
            }

            private fun parseAnyMap(obj: JSONObject?): Map<String, Any>? {
                if (obj == null) return null
                val map = mutableMapOf<String, Any>()
                obj.keys().forEach { key -> map[key] = obj.get(key) }
                return map
            }
        }
    }

    data class CertificatePinningConfig(
        val pins: Map<String, List<String>>
    ) {
        companion object {
            fun fromMap(map: JSONObject?): CertificatePinningConfig? {
                if (map == null) return null
                val pins = mutableMapOf<String, List<String>>()
                try {
                    val pinsObj = map.getJSONObject("pins")
                    pinsObj.keys().forEach { key ->
                        val hashArray = pinsObj.getJSONArray(key)
                        val hashes = mutableListOf<String>()
                        for (i in 0 until hashArray.length()) {
                            hashes.add(hashArray.getString(i))
                        }
                        pins[key] = hashes
                    }
                    if (pins.isEmpty()) return null
                    return CertificatePinningConfig(pins)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to parse CertificatePinningConfig: ${e.message}")
                    return null
                }
            }
        }
    }

    fun attemptTokenRefresh(client: OkHttpClient, config: TokenRefreshConfig): String? {
        try {
            Log.d(TAG, "Attempting token refresh at ${config.url}")
            val builder = Request.Builder().url(config.url)
            
            // Add headers
            config.headers?.forEach { (k, v) -> builder.header(k, v) }
            
            // Add body if needed
            val requestBody = if (config.body != null) {
                JSONObject(config.body).toString().toRequestBody("application/json".toMediaType())
            } else if (config.method.uppercase() in listOf("POST", "PUT", "PATCH")) {
                ByteArray(0).toRequestBody(null)
            } else {
                null
            }
            
            val request = builder.method(config.method.uppercase(), requestBody).build()

            client.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    val bodyString = response.body?.string()
                    if (bodyString != null) {
                        val json = JSONObject(bodyString)
                        
                        // Support nested keys (e.g. "json.access_token")
                        val keyParts = config.responseKey.split(".")
                        var current: Any? = json
                        for (part in keyParts) {
                            if (current is JSONObject) {
                                current = current.opt(part)
                            } else {
                                current = null
                                break
                            }
                        }
                        
                        val newToken = current?.toString()
                        if (!newToken.isNullOrEmpty()) {
                            Log.d(TAG, "Token refresh successful")
                            return newToken
                        }
                    }
                } else {
                    Log.e(TAG, "Token refresh failed with HTTP ${response.code}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Token refresh exception: ${e.message}")
        }
        return null
    }

    fun OkHttpClient.Builder.applyCertificatePinning(url: String, config: CertificatePinningConfig?): OkHttpClient.Builder {
        if (config == null || config.pins.isEmpty()) return this
        val pinnerBuilder = CertificatePinner.Builder()
        for ((pattern, hashes) in config.pins) {
            for (hash in hashes) {
                val normalizedHash = if (hash.startsWith("sha256/") || hash.startsWith("sha1/")) {
                    hash
                } else {
                    "sha256/$hash"
                }
                pinnerBuilder.add(pattern, normalizedHash)
            }
        }
        this.certificatePinner(pinnerBuilder.build())
        Log.d(TAG, "Applied certificate pinning for ${config.pins.size} domains")
        return this
    }
}
