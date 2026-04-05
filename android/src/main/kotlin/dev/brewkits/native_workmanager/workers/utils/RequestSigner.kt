package dev.brewkits.native_workmanager.workers.utils

import android.util.Log
import okhttp3.Request
import okio.Buffer
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * HMAC-SHA256 request signer for HTTP workers.
 *
 * Signs outgoing OkHttp [Request] instances with an HMAC-SHA256 digest
 * computed over a canonical message:
 *
 * ```
 * METHOD\n
 * URL\n
 * BODY\n          ← only when signBody=true and the request has a body
 * TIMESTAMP       ← only when includeTimestamp=true (Unix ms)
 * ```
 *
 * The signature is added as [headerName] (default `X-Signature`), and the
 * timestamp (if enabled) as `X-Timestamp`.
 *
 * Usage:
 * ```kotlin
 * val signed = RequestSigner.sign(
 *     request = request,
 *     secretKey = config.requestSigning.secretKey,
 *     headerName = config.requestSigning.headerName,
 *     signaturePrefix = config.requestSigning.signaturePrefix,
 *     includeTimestamp = config.requestSigning.includeTimestamp,
 *     signBody = config.requestSigning.signBody,
 * )
 * ```
 */
object RequestSigner {

    private const val TAG = "RequestSigner"
    private const val HMAC_ALGORITHM = "HmacSHA256"

    data class Config(
        val secretKey: String,
        val headerName: String = "X-Signature",
        val signaturePrefix: String = "",
        val includeTimestamp: Boolean = true,
        val signBody: Boolean = true,
    )

    /**
     * Sign [request] and return a new [Request] with signature headers added.
     *
     * The original request is not modified.
     */
    fun sign(request: Request, config: Config): Request {
        val timestamp = if (config.includeTimestamp) System.currentTimeMillis().toString() else null

        // Read the request body without consuming it (OkHttp bodies can only be read once).
        val bodyString: String? = if (config.signBody && request.body != null) {
            try {
                val buf = Buffer()
                request.body!!.writeTo(buf)
                buf.readUtf8()
            } catch (e: Exception) {
                Log.w(TAG, "Could not read request body for signing: ${e.message}")
                null
            }
        } else null

        val message = buildCanonicalMessage(
            method    = request.method,
            url       = request.url.toString(),
            body      = bodyString,
            timestamp = timestamp,
        )

        val signature = try {
            hmacSha256(message, config.secretKey)
        } catch (e: Exception) {
            Log.e(TAG, "HMAC signing failed: ${e.message}", e)
            return request  // Return unsigned request rather than crashing
        }

        val builder = request.newBuilder()
            .header(config.headerName, "${config.signaturePrefix}$signature")

        if (timestamp != null) builder.header("X-Timestamp", timestamp)

        Log.d(TAG, "Request signed — header=${config.headerName}, ts=$timestamp")
        return builder.build()
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun buildCanonicalMessage(
        method: String,
        url: String,
        body: String?,
        timestamp: String?,
    ): String = buildString {
        append(method.uppercase()); append("\n")
        append(url);                append("\n")
        if (!body.isNullOrEmpty()) { append(body); append("\n") }
        if (timestamp != null)      append(timestamp)
    }

    private fun hmacSha256(message: String, key: String): String {
        val mac = Mac.getInstance(HMAC_ALGORITHM)
        mac.init(SecretKeySpec(key.toByteArray(Charsets.UTF_8), HMAC_ALGORITHM))
        val digest = mac.doFinal(message.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }

    /**
     * Parse a [RequestSigning] config from a JSON map.
     *
     * Returns null if the map is missing or [secretKey] is blank.
     */
    fun fromMap(map: org.json.JSONObject?): Config? {
        if (map == null) return null
        val key = map.optString("secretKey", "")
        if (key.isBlank()) return null
        return Config(
            secretKey        = key,
            headerName       = map.optString("headerName",       "X-Signature"),
            signaturePrefix  = map.optString("signaturePrefix",  ""),
            includeTimestamp = map.optBoolean("includeTimestamp", true),
            signBody         = map.optBoolean("signBody",         true),
        )
    }
}
