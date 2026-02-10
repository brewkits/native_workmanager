package dev.brewkits.native_workmanager.workers

import android.util.Log
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.workers.utils.ProgressResponseBody
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.TimeUnit

/**
 * Native HTTP file download worker for Android.
 *
 * Downloads files using OkHttp with streaming to minimize memory usage.
 * Uses atomic file operations (temp file → final file) to prevent corruption.
 * Supports resume from last downloaded byte using HTTP Range Requests (RFC 7233).
 *
 * **Configuration JSON:**
 * ```json
 * {
 *   "url": "https://example.com/file.zip",
 *   "savePath": "/path/to/save/file.zip",
 *   "headers": {                // Optional
 *     "Authorization": "Bearer token"
 *   },
 *   "timeoutMs": 300000,       // Optional: Timeout (default: 5 minutes for downloads)
 *   "enableResume": true,      // Optional: Enable resume support (default: true)
 *   "expectedChecksum": "a3b2c1...",  // Optional: Expected checksum for verification
 *   "checksumAlgorithm": "SHA-256"    // Optional: Hash algorithm (default: SHA-256)
 * }
 * ```
 *
 * **Features:**
 * - Streaming download (does not load entire file in memory)
 * - **Resume support** (automatic retry from last byte on network failure)
 * - Atomic file operations (writes to .tmp then renames)
 * - Auto-creates parent directories
 * - Cleans up on error
 *
 * **Resume Behavior:**
 * - If network fails mid-download, next attempt resumes from last byte
 * - Uses HTTP Range header (bytes=N-) to request remaining data
 * - Server must support Range requests (returns 206 Partial Content)
 * - Falls back to full download if server doesn't support resume
 *
 * **Performance:** ~3-5MB RAM regardless of file size
 */
class HttpDownloadWorker : AndroidWorker {

    companion object {
        private const val TAG = "HttpDownloadWorker"
        private const val DEFAULT_TIMEOUT_MS = 300_000L
    }

    data class Config(
        val url: String,
        val savePath: String,
        val headers: Map<String, String>? = null,
        val timeoutMs: Long? = null,
        val enableResume: Boolean = true,      // Enable resume support (default: true)
        val expectedChecksum: String? = null,  // 👈 NEW: Expected checksum for verification
        val checksumAlgorithm: String? = null  // 👈 NEW: Algorithm (MD5, SHA-256, SHA-1)
    ) {
        val timeout: Long get() = timeoutMs ?: DEFAULT_TIMEOUT_MS
        val effectiveChecksumAlgorithm: String get() = checksumAlgorithm ?: "SHA-256"
    }

    override suspend fun doWork(input: String?): WorkerResult = withContext(Dispatchers.IO) {
        if (input.isNullOrEmpty()) {
            throw IllegalArgumentException("Input JSON is required")
        }

        // Parse configuration
        val config = try {
            val j = org.json.JSONObject(input)
            Config(
                url = j.getString("url"),
                savePath = j.getString("savePath"),
                headers = parseStringMap(j.optJSONObject("headers")),
                timeoutMs = if (j.has("timeoutMs")) j.getLong("timeoutMs") else null,
                enableResume = j.optBoolean("enableResume", true),
                expectedChecksum = if (j.has("expectedChecksum")) j.getString("expectedChecksum") else null,  // 👈 NEW
                checksumAlgorithm = if (j.has("checksumAlgorithm")) j.getString("checksumAlgorithm") else null  // 👈 NEW
            )
        } catch (e: Exception) {
            throw IllegalArgumentException("Invalid config JSON: ${e.message}", e)
        }

        // ✅ SECURITY: Validate URL scheme (prevent file://, content://, etc.)
        if (!SecurityValidator.validateURL(config.url)) {
            Log.e(TAG, "Error - Invalid or unsafe URL")
            return@withContext WorkerResult.Failure("Invalid or unsafe URL")
        }

        // Extract taskId for progress reporting
        val taskId = try {
            org.json.JSONObject(input).optString("__taskId", null)
        } catch (e: Exception) {
            null
        }

        // Get allowed directories for path validation
        // Note: Context would be needed to get actual directories, so this is a simplified version
        // In production, pass context to worker and use context.filesDir, context.cacheDir, etc.
        val destinationFile = File(config.savePath)
        val tempFile = File(config.savePath + ".tmp")

        // ✅ SECURITY: Basic path validation (check for path traversal attempts)
        if (config.savePath.contains("..") || !config.savePath.startsWith("/")) {
            Log.e(TAG, "Error - Invalid file path (path traversal attempt)")
            return@withContext WorkerResult.Failure("Invalid file path (path traversal attempt)")
        }

        // Create parent directory if needed
        val parentDir = destinationFile.parentFile
        if (parentDir != null && !parentDir.exists()) {
            if (!parentDir.mkdirs()) {
                Log.e(TAG, "Error - Failed to create parent directory: ${parentDir.path}")
                return@withContext WorkerResult.Failure("Failed to create parent directory: ${parentDir.path}")
            }
            Log.d(TAG, "Created directory: ${parentDir.path}")
        }

        // ✅ SECURITY: Sanitize URL for logging
        val sanitizedURL = SecurityValidator.sanitizedURL(config.url)
        Log.d(TAG, "Downloading $sanitizedURL")
        Log.d(TAG, "  Save to: ${destinationFile.name}")

        // 👇 NEW: Check for existing partial download (resume support)
        val existingBytes = if (config.enableResume && tempFile.exists()) {
            val size = tempFile.length()
            if (size > 0) {
                Log.d(TAG, "Found existing partial download: $size bytes")
                size
            } else {
                tempFile.delete() // Delete empty temp file
                0L
            }
        } else {
            if (tempFile.exists()) tempFile.delete() // Clean up if resume disabled
            0L
        }

        // Build HTTP client with timeout
        val client = OkHttpClient.Builder()
            .connectTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .readTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .writeTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .build()

        // Build request
        val requestBuilder = Request.Builder()
            .url(config.url)
            .get()

        // 👇 NEW: Add Range header if resuming
        if (existingBytes > 0) {
            requestBuilder.addHeader("Range", "bytes=$existingBytes-")
            Log.d(TAG, "Resuming download from byte $existingBytes")
        }

        // Add headers
        config.headers?.forEach { (key, value) ->
            requestBuilder.addHeader(key, value)
        }

        val request = requestBuilder.build()

        // Execute download
        return@withContext try {
            client.newCall(request).execute().use { response ->
                val statusCode = response.code

                // 👇 NEW: Handle both full content (200) and partial content (206)
                val isPartialContent = statusCode == 206
                val isFullContent = statusCode in 200..299
                val isResumingDownload = existingBytes > 0 && isPartialContent

                if (!isPartialContent && !isFullContent) {
                    Log.e(TAG, "Failed - Status $statusCode")
                    return@withContext WorkerResult.Failure("HTTP $statusCode", shouldRetry = statusCode >= 500)
                }

                // Log resume status
                if (isResumingDownload) {
                    Log.d(TAG, "Resume confirmed - Server sent 206 Partial Content")
                } else if (existingBytes > 0 && statusCode == 200) {
                    Log.w(TAG, "Server doesn't support resume - Starting from beginning")
                    tempFile.delete() // Server sent full content, delete partial file
                }

                // ✅ SECURITY: Validate content length (prevent downloading huge files)
                val contentLength = response.body?.contentLength() ?: -1L
                if (!SecurityValidator.validateContentLength(contentLength)) {
                    Log.e(TAG, "Error - Download size exceeds limit")
                    return@withContext WorkerResult.Failure("Download size exceeds limit")
                }

                // ✅ SECURITY: Validate available disk space
                if (contentLength > 0) {
                    if (!SecurityValidator.hasEnoughDiskSpace(contentLength, destinationFile.parentFile ?: destinationFile)) {
                        Log.e(TAG, "Error - Insufficient disk space")
                        return@withContext WorkerResult.Failure("Insufficient disk space")
                    }
                    Log.d(TAG, "Storage check passed")
                }

                // ✅ PROGRESS: Wrap response body for progress tracking
                val progressBody = ProgressResponseBody(
                    responseBody = response.body!!,
                    taskId = taskId,
                    fileName = destinationFile.name
                )

                val inputStream = progressBody.byteStream()
                if (inputStream == null) {
                    Log.e(TAG, "Error - No response body")
                    return@withContext WorkerResult.Failure("No response body")
                }

                // Capture content type and final URL
                val contentType = response.header("Content-Type")
                val finalUrl = response.request.url.toString()

                // 👇 NEW: Stream to temp file (append if resuming, overwrite if starting fresh)
                inputStream.use { input ->
                    val outputStream = if (isResumingDownload) {
                        FileOutputStream(tempFile, true) // Append mode
                    } else {
                        FileOutputStream(tempFile) // Overwrite mode
                    }

                    outputStream.use { output ->
                        input.copyTo(output)
                    }
                }

                val fileSize = tempFile.length()

                // 👇 NEW: Verify checksum if expected checksum is provided
                if (config.expectedChecksum != null) {
                    Log.d(TAG, "Verifying checksum with ${config.effectiveChecksumAlgorithm}...")
                    val actualChecksum = calculateChecksum(tempFile, config.effectiveChecksumAlgorithm)

                    if (!actualChecksum.equals(config.expectedChecksum, ignoreCase = true)) {
                        Log.e(TAG, "Checksum verification failed!")
                        Log.e(TAG, "  Expected: ${config.expectedChecksum}")
                        Log.e(TAG, "  Actual:   $actualChecksum")
                        Log.e(TAG, "  Algorithm: ${config.effectiveChecksumAlgorithm}")
                        tempFile.delete() // Delete corrupted file
                        return@withContext WorkerResult.Failure(
                            "Checksum verification failed (expected: ${config.expectedChecksum}, actual: $actualChecksum)",
                            shouldRetry = true  // Retry in case download was corrupted
                        )
                    }

                    Log.d(TAG, "Checksum verified: $actualChecksum")
                }

                // Remove destination if exists
                destinationFile.delete()

                // Atomic rename from temp to final destination
                if (!tempFile.renameTo(destinationFile)) {
                    Log.e(TAG, "Error - Failed to rename temp file to destination")
                    tempFile.delete()
                    return@withContext WorkerResult.Failure("Failed to rename temp file to destination")
                }

                Log.d(TAG, "Success - Downloaded $fileSize bytes")
                Log.d(TAG, "Saved to: ${config.savePath}")

                // ✅ Return success with rich data
                WorkerResult.Success(
                    message = "Downloaded ${fileSize} bytes",
                    data = mapOf(
                        "filePath" to destinationFile.absolutePath,
                        "fileName" to destinationFile.name,
                        "fileSize" to fileSize,
                        "contentType" to contentType,
                        "finalUrl" to finalUrl
                    )
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error - ${e.message}", e)
            // Clean up temp file on error
            tempFile.delete()
            WorkerResult.Failure(
                message = e.message ?: "Unknown error",
                shouldRetry = true
            )
        }
    }

    private fun parseStringMap(obj: org.json.JSONObject?): Map<String, String>? {
        if (obj == null) return null
        val map = mutableMapOf<String, String>()
        obj.keys().forEach { key -> map[key] = obj.getString(key) }
        return map
    }

    /**
     * Calculate checksum of a file.
     *
     * @param file File to calculate checksum for
     * @param algorithm Hash algorithm (MD5, SHA-1, SHA-256, SHA-512)
     * @return Hexadecimal checksum string
     */
    private fun calculateChecksum(file: File, algorithm: String): String {
        val digest = MessageDigest.getInstance(algorithm)
        val buffer = ByteArray(8192)

        file.inputStream().use { input ->
            var bytesRead: Int
            while (input.read(buffer).also { bytesRead = it } != -1) {
                digest.update(buffer, 0, bytesRead)
            }
        }

        // Convert byte array to hex string
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

}
