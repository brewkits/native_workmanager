package dev.brewkits.native_workmanager.workers.utils

import okhttp3.MediaType
import okhttp3.RequestBody
import okio.Buffer
import okio.BufferedSink
import okio.ForwardingSink
import okio.Sink
import okio.buffer

/**
 * RequestBody wrapper that reports upload progress.
 *
 * Wraps any RequestBody and intercepts write operations to track
 * and report upload progress via ProgressReporter.
 *
 * Usage:
 * ```kotlin
 * val progressBody = ProgressRequestBody(
 *     requestBody = originalBody,
 *     taskId = "upload-task",
 *     fileName = "photo.jpg"
 * )
 * ```
 */
class ProgressRequestBody(
    private val requestBody: RequestBody,
    private val taskId: String?,
    private val fileName: String = "file"
) : RequestBody() {

    override fun contentType(): MediaType? = requestBody.contentType()

    override fun contentLength(): Long = requestBody.contentLength()

    override fun writeTo(sink: BufferedSink) {
        val contentLength = contentLength()

        if (taskId == null || contentLength <= 0) {
            // No progress tracking - write directly
            requestBody.writeTo(sink)
            return
        }

        // Report initial progress (non-blocking)
        ProgressReporter.reportProgressNonBlocking(
            taskId = taskId,
            progress = 0,
            message = "Uploading $fileName..."
        )

        // Wrap sink with progress tracking
        val progressSink = ProgressSink(
            delegate = sink,
            totalBytes = contentLength,
            taskId = taskId,
            fileName = fileName
        )
        val bufferedSink = progressSink.buffer()

        // Write with progress tracking
        requestBody.writeTo(bufferedSink)
        bufferedSink.flush()

        // Report completion (non-blocking)
        ProgressReporter.reportProgressNonBlocking(
            taskId = taskId,
            progress = 100,
            message = "Upload complete"
        )
    }

    /**
     * Sink wrapper that tracks bytes written and reports progress.
     */
    private class ProgressSink(
        delegate: Sink,
        private val totalBytes: Long,
        private val taskId: String,
        private val fileName: String
    ) : ForwardingSink(delegate) {

        private var bytesWritten = 0L
        private var lastReportedProgress = 0

        override fun write(source: Buffer, byteCount: Long) {
            super.write(source, byteCount)

            bytesWritten += byteCount

            // Calculate progress
            val progress = if (totalBytes > 0) {
                ((bytesWritten.toFloat() / totalBytes.toFloat()) * 100).toInt()
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
                    message = "Uploading $fileName... (${formatBytes(bytesWritten)}/${formatBytes(totalBytes)})"
                )
            }
        }

        private fun formatBytes(bytes: Long): String = ByteFormatUtils.formatBytesCompact(bytes)
    }
}
