package dev.brewkits.native_workmanager

import android.util.Log

/**
 * Centralised logger for NativeWorkManager.
 *
 * All diagnostic output is gated behind [enabled]. The flag is set via
 * `debugMode` in `initialize()` and is only active in debug builds
 * (verified by [NativeWorkmanagerPlugin.isDebugBuild]).
 *
 * In production [enabled] stays `false`, preventing task metadata
 * such as task IDs, URLs, and file paths from appearing in Logcat — a
 * requirement for apps that handle sensitive user background operations.
 *
 * Error-level messages are always emitted because they represent unexpected
 * failures engineers need to diagnose. Do NOT include user-identifiable
 * data (task IDs, URLs, paths) in error message strings.
 */
internal object NativeLogger {

    private const val TAG = "NativeWorkManager"

    /**
     * Controlled by [NativeWorkmanagerPlugin.handleInitialize] via `debugMode`.
     * Volatile so changes are visible across threads immediately.
     */
    @Volatile
    var enabled: Boolean = false

    /** Debug log — silenced in production. */
    fun d(msg: String) {
        if (enabled) Log.d(TAG, msg)
    }

    /** Warning log — silenced in production. */
    fun w(msg: String) {
        if (enabled) Log.w(TAG, msg)
    }

    /**
     * Error log — always emitted.
     * Do NOT include user-identifiable data (task IDs, file paths) in [msg].
     */
    fun e(msg: String, t: Throwable? = null) {
        if (t != null) Log.e(TAG, msg, t) else Log.e(TAG, msg)
    }

    /** 
     * Logs a URL after redacting sensitive query parameters.
     * FIX #05: Prevents sensitive tokens from leaking via Logcat.
     */
    fun url(prefix: String, url: String) {
        if (!enabled) return
        val sanitized = try {
            val uri = android.net.Uri.parse(url)
            if (uri.query == null) url
            else {
                val builder = uri.buildUpon().clearQuery()
                val sensitiveKeys = setOf("token", "key", "auth", "secret", "apikey", "access_token")
                uri.queryParameterNames.forEach { key ->
                    val value = if (sensitiveKeys.any { key.contains(it, ignoreCase = true) }) "[REDACTED]"
                                else uri.getQueryParameter(key)
                    builder.appendQueryParameter(key, value)
                }
                builder.build().toString()
            }
        } catch (_: Exception) {
            "[REDACTED URL]"
        }
        d("$prefix $sanitized")
    }
}
