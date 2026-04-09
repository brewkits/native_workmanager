package dev.brewkits.native_workmanager.workers

import android.util.Log
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * Native WebSocket worker for Android.
 *
 * Connects to a WebSocket endpoint, sends a list of messages after the
 * connection is established, waits for a configured number of responses,
 * then performs a clean close.
 *
 * **Configuration JSON:**
 * ```json
 * {
 *   "url": "wss://api.example.com/ws",
 *   "messages": ["ping", "{\"type\":\"subscribe\",\"channel\":\"prices\"}"],
 *   "headers": {                           // Optional
 *     "Authorization": "Bearer token"
 *   },
 *   "timeoutSeconds": 30,                 // Optional (default: 30)
 *   "receiveMessages": 1,                 // Optional (default: 1)
 *   "storeResponseAt": "/data/.../ws.json", // Optional
 *   "pingIntervalSeconds": 10             // Optional
 * }
 * ```
 *
 * **Result data (success):**
 * ```json
 * {
 *   "connected": true,
 *   "messagesSent": 2,
 *   "messagesReceived": 1,
 *   "messages": ["pong"]
 * }
 * ```
 *
 * **Performance:** ~5-8 MB RAM. Keeps the connection open only as long as
 * needed (until [receiveMessages] responses arrive or timeout).
 */
class WebSocketWorker : AndroidWorker {

    companion object {
        private const val TAG = "WebSocketWorker"
        private const val DEFAULT_TIMEOUT_SECONDS = 30
        private const val DEFAULT_RECEIVE_MESSAGES = 1
        private const val WS_CLOSE_NORMAL = 1000
        private const val WS_CLOSE_GOING_AWAY = 1001
    }

    data class Config(
        val url: String,
        val messages: List<String>,
        val headers: Map<String, String>?,
        val timeoutSeconds: Int?,
        val receiveMessages: Int?,
        val storeResponseAt: String?,
        val pingIntervalSeconds: Int?,
    ) {
        val timeout: Int get() = timeoutSeconds ?: DEFAULT_TIMEOUT_SECONDS
        val expectedMessages: Int get() = (receiveMessages ?: DEFAULT_RECEIVE_MESSAGES).coerceAtLeast(0)
    }

    override suspend fun doWork(input: String?, env: dev.brewkits.kmpworkmanager.background.domain.WorkerEnvironment): WorkerResult = withContext(Dispatchers.IO) {
        if (input.isNullOrEmpty()) {
            throw IllegalArgumentException("Input JSON is required")
        }

        // Parse configuration
        val config = try {
            val j = org.json.JSONObject(input)
            val messages = mutableListOf<String>()
            if (j.has("messages") && !j.isNull("messages")) {
                val arr = j.getJSONArray("messages")
                for (i in 0 until arr.length()) messages.add(arr.getString(i))
            }
            Config(
                url = j.getString("url"),
                messages = messages,
                headers = parseStringMap(j.optJSONObject("headers")),
                timeoutSeconds = if (j.has("timeoutSeconds")) j.getInt("timeoutSeconds") else null,
                receiveMessages = if (j.has("receiveMessages")) j.getInt("receiveMessages") else null,
                storeResponseAt = if (j.has("storeResponseAt") && !j.isNull("storeResponseAt")) j.getString("storeResponseAt") else null,
                pingIntervalSeconds = if (j.has("pingIntervalSeconds") && !j.isNull("pingIntervalSeconds")) j.getInt("pingIntervalSeconds") else null,
            )
        } catch (e: Exception) {
            throw IllegalArgumentException("Invalid config JSON: ${e.message}", e)
        }

        // ✅ SECURITY: Validate WebSocket URL (ws:// and wss:// only)
        if (!validateWebSocketURL(config.url)) {
            Log.e(TAG, "Error - Invalid or unsafe WebSocket URL")
            return@withContext WorkerResult.Failure("Invalid or unsafe WebSocket URL")
        }

        // ✅ SECURITY: Validate output path
        config.storeResponseAt?.let { path ->
            if (!SecurityValidator.validateFilePathSafe(path)) {
                Log.e(TAG, "Error - Unsafe storeResponseAt: $path")
                return@withContext WorkerResult.Failure("Unsafe storeResponseAt")
            }
        }

        val sanitizedURL = config.url.replaceFirst(Regex("^wss?://[^?#]*"), "<ws>")
        Log.d(TAG, "Connecting to ${sanitizedURL}, expect ${config.expectedMessages} message(s), timeout=${config.timeout}s")

        // Synchronisation primitives
        val receivedMessages = mutableListOf<String>()
        val receiveLatch = CountDownLatch(config.expectedMessages.coerceAtLeast(1))
        val errorMessage = arrayOfNulls<String>(1)
        val connected = AtomicBoolean(false)
        val messagesSent = AtomicInteger(0)
        val closedCleanly = AtomicBoolean(false)

        // Build OkHttp client
        val client = OkHttpClient.Builder()
            .connectTimeout(config.timeout.toLong(), TimeUnit.SECONDS)
            .readTimeout(config.timeout.toLong(), TimeUnit.SECONDS)
            .writeTimeout(config.timeout.toLong(), TimeUnit.SECONDS)
            .build()

        // Build upgrade request
        val requestBuilder = Request.Builder().url(config.url)
        config.headers?.forEach { (key, value) -> requestBuilder.header(key, value) }
        val request = requestBuilder.build()

        val listener = object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                connected.set(true)
                Log.d(TAG, "Connected (HTTP ${response.code})")

                // Send all queued messages in order
                for (msg in config.messages) {
                    webSocket.send(msg)
                    messagesSent.incrementAndGet()
                    Log.d(TAG, "Sent: ${SecurityValidator.truncateForLogging(msg, 200)}")
                }

                // If no messages are expected, count down immediately so the
                // latch-wait below proceeds without blocking.
                if (config.expectedMessages == 0) {
                    receiveLatch.countDown()
                }
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                Log.d(TAG, "Received: ${SecurityValidator.truncateForLogging(text, 200)}")
                synchronized(receivedMessages) {
                    if (receivedMessages.size < config.expectedMessages) {
                        receivedMessages.add(text)
                        receiveLatch.countDown()
                    }
                }
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "Server closing: $code $reason")
                webSocket.close(WS_CLOSE_NORMAL, null)
                closedCleanly.set(true)
                // Unblock latch if we haven't received all expected messages
                while (receiveLatch.count > 0) receiveLatch.countDown()
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "Closed: $code $reason")
                closedCleanly.set(true)
                while (receiveLatch.count > 0) receiveLatch.countDown()
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "Failure: ${t.message}")
                errorMessage[0] = t.message
                while (receiveLatch.count > 0) receiveLatch.countDown()
            }
        }

        val webSocket = client.newWebSocket(request, listener)

        // LEAK-002: declare timedOut before try so it is visible after the finally block.
        // The try/finally guarantees close() on ALL exit paths including coroutine cancellation.
        var timedOut = false
        try {
            // Optional: send periodic pings in a separate coroutine launched in this
            // withContext(Dispatchers.IO) scope so it is automatically cancelled when
            // the outer coroutine is cancelled.
            // NET-010: use a short-polling delay instead of a single long delay so that
            // coroutine cancellation is observed promptly (old code could wait up to 30 s
            // for the delay to expire before honouring cancellation).
            val pingJob: Job? = if (config.pingIntervalSeconds != null && config.pingIntervalSeconds > 0) {
                val tickMs = 200L
                val intervalMs = config.pingIntervalSeconds * 1000L
                launch(Dispatchers.IO) {
                    var elapsed = 0L
                    while (isActive) {
                        delay(tickMs)
                        elapsed += tickMs
                        if (elapsed >= intervalMs) {
                            elapsed = 0L
                            // Note: OkHttp's public API has no sendPing(); sending an empty binary
                            // frame acts as a keepalive. It is NOT a WebSocket PING control frame.
                            if (!webSocket.send(ByteString.EMPTY)) break
                            Log.d(TAG, "Ping sent")
                        }
                    }
                }
            } else null

            // Wait for the expected messages (or timeout)
            timedOut = !receiveLatch.await(config.timeout.toLong(), TimeUnit.SECONDS)

            pingJob?.cancel()
        } finally {
            // Close WebSocket on ALL exit paths including coroutine cancellation.
            if (!closedCleanly.get()) {
                webSocket.close(WS_CLOSE_GOING_AWAY, "Worker finished")
            }
        }

        // Give the close frame time to flush (shared dispatcher — shutdown() not safe to call).
        kotlinx.coroutines.delay(250)

        // Build result
        if (!connected.get()) {
            val err = errorMessage[0] ?: "Connection failed"
            Log.e(TAG, "Could not connect: $err")
            return@withContext WorkerResult.Failure(
                message = err,
                shouldRetry = true
            )
        }

        if (errorMessage[0] != null && receivedMessages.size < config.expectedMessages) {
            Log.e(TAG, "WebSocket error: ${errorMessage[0]}")
            return@withContext WorkerResult.Failure(
                message = errorMessage[0]!!,
                shouldRetry = true
            )
        }

        if (timedOut) {
            Log.w(TAG, "Timed out waiting for ${config.expectedMessages} message(s); got ${receivedMessages.size}")
            // Treat partial receipt as a soft failure so the task can be retried.
            return@withContext WorkerResult.Failure(
                message = "Timeout: received ${receivedMessages.size}/${config.expectedMessages} messages",
                shouldRetry = true
            )
        }

        Log.d(TAG, "Done — sent=${messagesSent.get()}, received=${receivedMessages.size}")

        // ── Persist received messages ─────────────────────────────────────────
        config.storeResponseAt?.let { path ->
            try {
                val file = File(path)
                file.parentFile?.mkdirs()
                // NET-020: build the JSON array in a single pass instead of concatenating
                // per-element JSONArray strings (which was O(n²) for many/large messages).
                val jsonArray = org.json.JSONArray(receivedMessages).toString()
                file.writeText(jsonArray, Charsets.UTF_8)
                Log.d(TAG, "Responses stored at '$path'")
            } catch (e: Exception) {
                Log.w(TAG, "Cannot write responses to '$path': ${e.message}")
            }
        }

        WorkerResult.Success(
            message = "WebSocket: sent=${messagesSent.get()}, received=${receivedMessages.size}",
            data = buildJsonObject {
                put("connected", true)
                put("messagesSent", messagesSent.get())
                put("messagesReceived", receivedMessages.size)
                // Include received messages as a JSON array string to avoid
                // complex nested structures in the result map.
                put("messages", org.json.JSONArray(receivedMessages).toString())
            }
        )
    }

    /**
     * Validate that the URL uses the ws:// or wss:// scheme.
     * Also applies the SecurityValidator's private-IP block when enabled.
     */
    private fun validateWebSocketURL(urlString: String): Boolean {
        return try {
            val uri = android.net.Uri.parse(urlString)
            val scheme = uri.scheme?.lowercase()
            if (scheme != "ws" && scheme != "wss") {
                Log.e(TAG, "Unsafe WebSocket URL scheme '$scheme'. Only ws/wss allowed.")
                return false
            }
            if (scheme == "ws") {
                Log.w(TAG, "WARNING - Using unencrypted WebSocket (ws://). Consider wss:// for security.")
            }
            if (SecurityValidator.blockPrivateIPs) {
                val host = uri.host ?: ""
                // Reuse the SecurityValidator's HTTP URL validation as a proxy.
                // We temporarily build an HTTP equivalent URL to leverage the
                // existing private-IP detection logic.
                val httpEquiv = urlString.replaceFirst(Regex("^wss?://"), "https://")
                if (!SecurityValidator.validateURL(httpEquiv)) {
                    Log.e(TAG, "WebSocket request blocked — private IP detected (blockPrivateIPs=true)")
                    return false
                }
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Invalid WebSocket URL format: ${e.message}")
            false
        }
    }

    private fun parseStringMap(obj: org.json.JSONObject?): Map<String, String>? {
        if (obj == null) return null
        val map = mutableMapOf<String, String>()
        obj.keys().forEach { key -> map[key] = obj.getString(key) }
        return map
    }
}
