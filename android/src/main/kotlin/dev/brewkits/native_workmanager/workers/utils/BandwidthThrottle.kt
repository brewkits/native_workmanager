package dev.brewkits.native_workmanager.workers.utils

import okhttp3.ResponseBody
import okhttp3.MediaType
import okio.Buffer
import okio.BufferedSource
import okio.ForwardingSource
import okio.Source
import okio.buffer

/**
 * Bandwidth-limited OkHttp [ResponseBody] wrapper.
 *
 * Throttles the read speed of a response body to [maxBytesPerSecond] bytes per
 * second using a simple token-bucket algorithm.  Call [wrap] to get a new
 * [ResponseBody] that transparently throttles reads:
 *
 * ```kotlin
 * val limitedBody = BandwidthThrottle.wrap(rawBody, maxBytesPerSecond = 100_000L) // 100 KB/s
 * ```
 *
 * Passing 0 or a negative value for [maxBytesPerSecond] returns the original
 * body unchanged.
 *
 * ## Algorithm — token bucket
 *
 * A sliding refill window adds `elapsed × rate` tokens every [read] call.
 * Tokens are capped at one second's worth (to bound bursts).  If the bucket is
 * empty the thread sleeps for the time needed to fill at least one token before
 * proceeding.  The sleep is capped at 100 ms per call so that other OkHttp
 * infrastructure (cancellation, connection keep-alive) is not starved.
 */
object BandwidthThrottle {

    /**
     * Wrap [body] so that reads proceed at most [maxBytesPerSecond] bytes/s.
     *
     * @param body              Original response body.
     * @param maxBytesPerSecond Throughput cap in bytes/s.  0 or negative = no limit.
     */
    fun wrap(body: ResponseBody, maxBytesPerSecond: Long): ResponseBody {
        if (maxBytesPerSecond <= 0L) return body
        val throttledSource = ThrottledSource(body.source(), maxBytesPerSecond)
        return object : ResponseBody() {
            override fun contentType(): MediaType?  = body.contentType()
            override fun contentLength(): Long      = body.contentLength()
            override fun source(): BufferedSource   = throttledSource.buffer()
        }
    }

    // ── Token-bucket Source ───────────────────────────────────────────────────

    internal class ThrottledSource(
        delegate: Source,
        private val maxBytesPerSecond: Long,
    ) : ForwardingSource(delegate) {

        // Token bucket state — NOT thread-safe (OkHttp reads on one thread at a time).
        private var tokenBalance: Double = maxBytesPerSecond.toDouble() // start full
        private var lastRefillNs: Long = System.nanoTime()

        override fun read(sink: Buffer, byteCount: Long): Long {
            refill()

            // Sleep until at least 1 token is available
            if (tokenBalance < 1.0) {
                val waitMs = ((1.0 - tokenBalance) / maxBytesPerSecond * 1000.0).toLong()
                    .coerceIn(1L, 100L)
                Thread.sleep(waitMs)
                refill()
            }

            // Only read as many bytes as the current token balance allows
            val allowed = byteCount.coerceAtMost(tokenBalance.toLong().coerceAtLeast(1L))
            val n = super.read(sink, allowed)
            if (n > 0) tokenBalance -= n.toDouble()
            return n
        }

        private fun refill() {
            val now = System.nanoTime()
            val elapsedSecs = (now - lastRefillNs).toDouble() / 1_000_000_000.0
            val newTokens = elapsedSecs * maxBytesPerSecond
            tokenBalance = (tokenBalance + newTokens)
                .coerceAtMost(maxBytesPerSecond.toDouble()) // cap burst at 1-second worth
            lastRefillNs = now
        }
    }
}
