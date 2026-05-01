package dev.brewkits.native_workmanager.utils

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel.Result

/**
 * A wrapper for [Result] that ensures all callbacks are executed on the main UI thread.
 *
 * This prevents crashes like "Methods marked with @UiThread must be executed on the main thread."
 * which happen when a [Result] is invoked from a background coroutine dispatcher (e.g. Dispatchers.IO).
 */
class SafeResult(private val result: Result) : Result {
    private val handler = Handler(Looper.getMainLooper())

    override fun success(reply: Any?) {
        handler.post { result.success(reply) }
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        handler.post { result.error(errorCode, errorMessage, errorDetails) }
    }

    override fun notImplemented() {
        handler.post { result.notImplemented() }
    }
}
