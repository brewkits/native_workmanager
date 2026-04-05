package dev.brewkits.native_workmanager.workers.utils

import android.util.Log
import okhttp3.CertificatePinner
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

object HttpSecurityHelper {
    private const val TAG = "HttpSecurityHelper"

    val sharedClient: OkHttpClient by lazy { OkHttpClient() }

    data class TokenRefreshConfig(
        val url: String,
        val tokenHeaderName: String,
        val tokenPrefix: String,
        val refreshTokenKey: String,
        val refreshTokenValue: String,
        val responseTokenKey: String
    ) {
        companion object {
            fun fromMap(map: JSONObject?): TokenRefreshConfig? {
                if (map == null) return null
                return try {
                    TokenRefreshConfig(
                        url = map.getString("url"),
                        tokenHeaderName = map.getString("tokenHeaderName"),
                        tokenPrefix = map.optString("tokenPrefix", ""),
                        refreshTokenKey = map.getString("refreshTokenKey"),
                        refreshTokenValue = map.getString("refreshTokenValue"),
                        responseTokenKey = map.getString("responseTokenKey")
                    )
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to parse TokenRefreshConfig: ${e.message}")
                    null
                }
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
            val request = Request.Builder()
                .url(config.url)
                .header(config.tokenHeaderName, "${config.tokenPrefix}${config.refreshTokenValue}")
                .post(okhttp3.RequestBody.create(null, ByteArray(0))) // Empty POST
                .build()

            client.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    val bodyString = response.body?.string()
                    if (bodyString != null) {
                        val json = JSONObject(bodyString)
                        val newToken = json.optString(config.responseTokenKey, null)
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
                // SC-H-006: OkHttp CertificatePinner requires "sha256/" prefix.
                // Silently prepend it if the caller omitted it so the pinner does not
                // accept a raw base64 string and skip verification entirely.
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
