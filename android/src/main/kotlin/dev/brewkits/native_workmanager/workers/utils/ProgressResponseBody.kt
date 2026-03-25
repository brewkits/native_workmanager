package dev.brewkits.native_workmanager.workers.utils

import okhttp3.MediaType
import okhttp3.ResponseBody
import okio.Buffer
import okio.BufferedSource
import okio.ForwardingSource
import okio.Source
import okio.buffer

/**
 * ResponseBody wrapper that reports download progress.
 *
 * Wraps any ResponseBody and intercepts read operations to track
 * and report download progress via ProgressReporter.
 *
 * Usage:
 * ```kotlin
 * val progressBody = ProgressResponseBody(
 *     responseBody = originalBody,
 *     taskId = "download-task",
 *     fileName = "video.mp4"
 * )
 * ```
 */
class ProgressResponseBody(
    private val responseBody: ResponseBody,
    private val taskId: String?,
    private val fileName: String = "file"
) : ResponseBody() {

    private var bufferedSource: BufferedSource? = null

    override fun contentType(): MediaType? = responseBody.contentType()

    override fun contentLength(): Long = responseBody.contentLength()

    override fun source(): BufferedSource {
        if (bufferedSource == null) {
            bufferedSource = if (taskId != null && contentLength() > 0) {
                // Report initial progress (non-blocking)
                ProgressReporter.reportProgressNonBlocking(
                    taskId = taskId,
                    progress = 0,
                    message = "Downloading $fileName..."
                )

                // Wrap source with progress tracking
                ProgressSource(
                    delegate = responseBody.source(),
                    totalBytes = contentLength(),
                    taskId = taskId,
                    fileName = fileName
                ).buffer()
            } else {
                // No progress tracking
                responseBody.source()
            }
        }
        return bufferedSource!!
    }

    /**
     * Source wrapper that tracks bytes read, speed, and ETA, then reports rich progress.
     */
    private class ProgressSource(
        delegate: Source,
        private val totalBytes: Long,
        private val taskId: String,
        private val fileName: String
    ) : ForwardingSource(delegate) {

        private var bytesRead = 0L
        private var lastReportedProgress = 0

        // Speed calculation: sliding window over last ~2 seconds of I/O
        private var windowStart = System.nanoTime()
        private var windowBytes = 0L
        private var smoothedSpeedBps = 0.0  // exponential moving average

        override fun read(sink: Buffer, byteCount: Long): Long {
            val bytesReadNow = super.read(sink, byteCount)

            if (bytesReadNow != -1L) {
                bytesRead += bytesReadNow
                windowBytes += bytesReadNow

                // Update speed every ~500 ms to avoid per-chunk noise
                val nowNs = System.nanoTime()
                val elapsedMs = (nowNs - windowStart) / 1_000_000L
                if (elapsedMs >= 500) {
                    val instantBps = windowBytes.toDouble() / (elapsedMs / 1000.0)
                    // Exponential moving average (α = 0.3) for smooth display
                    smoothedSpeedBps = if (smoothedSpeedBps == 0.0) instantBps
                                       else 0.3 * instantBps + 0.7 * smoothedSpeedBps
                    windowStart = nowNs
                    windowBytes = 0L
                }

                val progress = if (totalBytes > 0) {
                    ((bytesRead.toFloat() / totalBytes.toFloat()) * 100).toInt()
                } else { 0 }

                if (progress != lastReportedProgress) {
                    lastReportedProgress = progress
                    val etaMs = if (smoothedSpeedBps > 0 && totalBytes > 0) {
                        ((totalBytes - bytesRead) / smoothedSpeedBps * 1000).toLong()
                    } else null

                    ProgressReporter.reportProgressNonBlocking(
                        taskId = taskId,
                        progress = progress,
                        message = "Downloading $fileName... " +
                            "(${formatBytes(bytesRead)}/${formatBytes(totalBytes)})",
                        bytesDownloaded = bytesRead,
                        totalBytes = totalBytes,
                        networkSpeed = if (smoothedSpeedBps > 0) smoothedSpeedBps else null,
                        timeRemainingMs = etaMs
                    )
                }
            } else {
                if (lastReportedProgress < 100) {
                    ProgressReporter.reportProgressNonBlocking(
                        taskId = taskId,
                        progress = 100,
                        message = "Download complete",
                        bytesDownloaded = bytesRead,
                        totalBytes = totalBytes
                    )
                }
            }

            return bytesReadNow
        }

        private fun formatBytes(bytes: Long): String = ByteFormatUtils.formatBytesCompact(bytes)
    }
}
