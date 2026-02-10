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
     * Source wrapper that tracks bytes read and reports progress.
     */
    private class ProgressSource(
        delegate: Source,
        private val totalBytes: Long,
        private val taskId: String,
        private val fileName: String
    ) : ForwardingSource(delegate) {

        private var bytesRead = 0L
        private var lastReportedProgress = 0

        override fun read(sink: Buffer, byteCount: Long): Long {
            val bytesReadNow = super.read(sink, byteCount)

            if (bytesReadNow != -1L) {
                bytesRead += bytesReadNow

                // Calculate progress
                val progress = if (totalBytes > 0) {
                    ((bytesRead.toFloat() / totalBytes.toFloat()) * 100).toInt()
                } else {
                    0
                }

                // Only report if progress changed by at least 1%
                // This prevents excessive progress updates
                if (progress != lastReportedProgress) {
                    lastReportedProgress = progress

                    // ✅ FIX #1: Non-blocking progress reporting from I/O thread
                    ProgressReporter.reportProgressNonBlocking(
                        taskId = taskId,
                        progress = progress,
                        message = "Downloading $fileName... (${formatBytes(bytesRead)}/${formatBytes(totalBytes)})"
                    )
                }
            } else {
                // Download complete
                if (lastReportedProgress < 100) {
                    // ✅ FIX #1: Non-blocking completion report
                    ProgressReporter.reportProgressNonBlocking(
                        taskId = taskId,
                        progress = 100,
                        message = "Download complete"
                    )
                }
            }

            return bytesReadNow
        }

        private fun formatBytes(bytes: Long): String = ByteFormatUtils.formatBytesCompact(bytes)
    }
}
