package dev.brewkits.native_workmanager.workers

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import android.webkit.MimeTypeMap
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.AppContextHolder
import dev.brewkits.native_workmanager.NativeLogger
import dev.brewkits.native_workmanager.workers.utils.AuthInterceptor
import dev.brewkits.native_workmanager.workers.utils.BandwidthThrottle
import dev.brewkits.native_workmanager.workers.utils.HostConcurrencyManager
import dev.brewkits.native_workmanager.workers.utils.HttpSecurityHelper
import dev.brewkits.native_workmanager.workers.utils.HttpSecurityHelper.applyCertificatePinning
import dev.brewkits.native_workmanager.workers.utils.ProgressReporter
import dev.brewkits.native_workmanager.workers.utils.ProgressResponseBody
import dev.brewkits.native_workmanager.workers.utils.RequestSigner
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.TimeUnit
import java.util.zip.ZipInputStream

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

        // HTTP status codes
        private const val HTTP_OK = 200
        private const val HTTP_PARTIAL_CONTENT = 206
        private const val HTTP_RANGE_NOT_SATISFIABLE = 416

        // HTTP header names
        private const val HTTP_HEADER_RANGE = "Range"
        private const val HTTP_HEADER_IF_RANGE = "If-Range"
        private const val HTTP_HEADER_ETAG = "ETag"
        private const val HTTP_HEADER_LAST_MODIFIED = "Last-Modified"
        private const val HTTP_HEADER_COOKIE = "Cookie"

        // File suffixes / sentinel names
        /** Sidecar file that stores the ETag/Last-Modified value for If-Range validation. */
        private const val ETAG_SIDECAR_SUFFIX = ".tmp.etag"
        /** Sentinel temp filename used in directory-mode downloads before the real filename is known. */
        private const val PENDING_TMP_FILENAME = "__pending__.tmp"

        // Defaults
        private const val DEFAULT_CHECKSUM_ALGORITHM = "SHA-256"
        private const val DEFAULT_AUTH_HEADER_TEMPLATE = "Bearer {accessToken}"
    }

    data class Config(
        val url: String,
        val savePath: String,
        val headers: Map<String, String>? = null,
        val timeoutMs: Long? = null,
        val enableResume: Boolean = true,
        val expectedChecksum: String? = null,
        val checksumAlgorithm: String? = null,
        val skipExisting: Boolean = false,
        val allowPause: Boolean = false,
        val onDuplicate: String = "overwrite",   // "overwrite", "rename", "skip"
        val moveToPublicDownloads: Boolean = false,
        val saveToGallery: Boolean = false,
        val extractAfterDownload: Boolean = false,
        val extractPath: String? = null,
        val deleteArchiveAfterExtract: Boolean = false,
        val cookies: Map<String, String>? = null,
        val authToken: String? = null,
        val authHeaderTemplate: String = DEFAULT_AUTH_HEADER_TEMPLATE,
        val bandwidthLimitBytesPerSecond: Long? = null,
        val requestSigningConfig: RequestSigner.Config? = null,
        val certificatePinningConfig: HttpSecurityHelper.CertificatePinningConfig? = null,
        val tokenRefreshConfig: HttpSecurityHelper.TokenRefreshConfig? = null,
    ) {
        val timeout: Long get() = timeoutMs ?: DEFAULT_TIMEOUT_MS
        val effectiveChecksumAlgorithm: String get() = checksumAlgorithm ?: DEFAULT_CHECKSUM_ALGORITHM
        /** True when savePath is a directory (ends with `/`). Filename is resolved from server response. */
        val isDirectory: Boolean get() = savePath.endsWith("/")
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
                expectedChecksum = if (j.has("expectedChecksum")) j.getString("expectedChecksum") else null,
                checksumAlgorithm = if (j.has("checksumAlgorithm")) j.getString("checksumAlgorithm") else null,
                skipExisting = j.optBoolean("skipExisting", false),
                allowPause = j.optBoolean("allowPause", false),
                onDuplicate = j.optString("onDuplicate", "overwrite"),
                moveToPublicDownloads = j.optBoolean("moveToPublicDownloads", false),
                saveToGallery = j.optBoolean("saveToGallery", false),
                extractAfterDownload = j.optBoolean("extractAfterDownload", false),
                extractPath = if (j.has("extractPath")) j.getString("extractPath") else null,
                deleteArchiveAfterExtract = j.optBoolean("deleteArchiveAfterExtract", false),
                cookies = parseStringMap(j.optJSONObject("cookies")),
                authToken = if (j.has("authToken")) j.getString("authToken") else null,
                authHeaderTemplate = j.optString("authHeaderTemplate", DEFAULT_AUTH_HEADER_TEMPLATE),
                bandwidthLimitBytesPerSecond = if (j.has("bandwidthLimitBytesPerSecond")) j.getLong("bandwidthLimitBytesPerSecond") else null,
                requestSigningConfig = RequestSigner.fromMap(j.optJSONObject("requestSigning")),
                certificatePinningConfig = HttpSecurityHelper.CertificatePinningConfig.fromMap(j.optJSONObject("certificatePinning")),
                tokenRefreshConfig = HttpSecurityHelper.TokenRefreshConfig.fromMap(j.optJSONObject("tokenRefresh")),
            )
        } catch (e: Exception) {
            throw IllegalArgumentException("Invalid config JSON: ${e.message}", e)
        }

        // Skip download if destination already exists and skipExisting is enabled
        // (only for non-directory paths where we already know the final filename)
        if (config.skipExisting && !config.isDirectory && File(config.savePath).exists()) {
            Log.d(TAG, "skipExisting=true and file already exists — skipping download")
            return@withContext WorkerResult.Success(
                message = "File already exists, download skipped",
                data = buildJsonObject {
                    put("filePath", config.savePath)
                    put("fileName", File(config.savePath).name)
                    put("fileSize", File(config.savePath).length())
                    put("skipped", true)
                }
            )
        }

        // onDuplicate: handle before download starts for known (non-directory) savePaths
        if (!config.isDirectory && File(config.savePath).exists()) {
            when (config.onDuplicate) {
                "skip" -> {
                    Log.d(TAG, "onDuplicate=skip and file already exists — skipping download")
                    return@withContext WorkerResult.Success(
                        message = "File already exists, download skipped",
                        data = buildJsonObject {
                            put("filePath", config.savePath)
                            put("fileName", File(config.savePath).name)
                            put("fileSize", File(config.savePath).length())
                            put("skipped", true)
                        }
                    )
                }
                "rename" -> {
                    // Rename logic is applied later to destinationFile; just note the intent
                    Log.d(TAG, "onDuplicate=rename — will find next available filename")
                }
                // "overwrite" is the default (current behaviour — delete existing)
            }
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

        // FIX H1: Use canonical-path validation instead of the weak contains("..")
        // string check. File.canonicalPath resolves symlinks and ".." at the OS level,
        // defeating URL-encoded paths and symlink-based escapes.
        if (!SecurityValidator.validateFilePathSafe(config.savePath)) {
            Log.e(TAG, "Error - Invalid or unsafe save path")
            return@withContext WorkerResult.Failure("Invalid or unsafe save path")
        }

        // When savePath is a directory, we need to resolve the filename from the server response.
        // Use a sentinel temp file in the directory until we know the real filename.
        // L-003 FIX: ETag sidecar is derived from sentinelTempFile path (per-file) rather than
        // from config.savePath (directory level). Multiple downloads to the same directory no
        // longer share a single ETag file.
        val sentinelTempFile = if (config.isDirectory) File(config.savePath + PENDING_TMP_FILENAME) else File(config.savePath + ".tmp")

        // For directory mode, destinationFile is resolved after the response headers arrive.
        // For now, set a placeholder that will be replaced below.
        var destinationFile = if (config.isDirectory) File(config.savePath + "download") else File(config.savePath)
        var tempFile = sentinelTempFile

        // Create directory (or parent directory) if needed
        val parentDir = if (config.isDirectory) File(config.savePath) else File(config.savePath).parentFile
        if (parentDir != null && !parentDir.exists()) {
            if (!parentDir.mkdirs()) {
                Log.e(TAG, "Error - Failed to create parent directory: ${parentDir.path}")
                return@withContext WorkerResult.Failure("Failed to create parent directory: ${parentDir.path}")
            }
            Log.d(TAG, "Created directory: ${parentDir.path}")
        }

        // ✅ SECURITY: Sanitize URL for logging
        NativeLogger.d("Downloading: ${config.url}")
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

        // Build HTTP client — derives from sharedClient to reuse ConnectionPool
        val clientBuilder = HttpSecurityHelper.sharedClient.newBuilder()
            .connectTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .readTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .writeTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .applyCertificatePinning(config.url, config.certificatePinningConfig)
        if (config.authToken != null) {
            clientBuilder.addInterceptor(AuthInterceptor(config.authToken, config.authHeaderTemplate))
        }
        val client = clientBuilder.build()

        // Build request
        val requestBuilder = Request.Builder()
            .url(config.url)
            .get()

        // 👇 NEW: Add Range header if resuming
        if (existingBytes > 0) {
            requestBuilder.addHeader(HTTP_HEADER_RANGE, "bytes=$existingBytes-")
            // If-Range: tell server to only honour the Range if the file hasn't changed.
            // Prevents silently appending bytes from a different file version (CDN rotation).
            // L-003 FIX: Use tempFile path (per-file) for the ETag sidecar, not savePath (may be a directory).
            val etagSidecar = java.io.File(tempFile.path + ETAG_SIDECAR_SUFFIX)
            if (etagSidecar.exists()) {
                val stored = etagSidecar.readText().trim()
                if (stored.isNotBlank()) requestBuilder.addHeader(HTTP_HEADER_IF_RANGE, stored)
            }
            Log.d(TAG, "Resuming download from byte $existingBytes")
        }

        // Add custom headers
        config.headers?.forEach { (key, value) ->
            requestBuilder.addHeader(key, value)
        }

        // Add cookies header
        if (!config.cookies.isNullOrEmpty()) {
            val cookieHeader = config.cookies.entries.joinToString("; ") { "${it.key}=${it.value}" }
            requestBuilder.addHeader(HTTP_HEADER_COOKIE, cookieHeader)
        }

        // Apply HMAC-SHA256 request signing if configured
        val request = config.requestSigningConfig
            ?.let { RequestSigner.sign(requestBuilder.build(), it) }
            ?: requestBuilder.build()

        // Execute download (with per-host concurrency limit)
        val host = try { java.net.URL(config.url).host } catch (_: Exception) { config.url }
        return@withContext HostConcurrencyManager.withHostPermit(host) downloadBlock@{
        try {
            client.newCall(request).execute().use { response ->
                val statusCode = response.code

                // 👇 NEW: Handle both full content (200) and partial content (206)
                val isPartialContent = statusCode == HTTP_PARTIAL_CONTENT
                val isFullContent = statusCode in HTTP_OK..299
                val isResumingDownload = existingBytes > 0 && isPartialContent

                if (statusCode == HTTP_RANGE_NOT_SATISFIABLE) {
                    // Resume position exceeds file size — .tmp is stale/corrupt. Delete and signal retry.
                    // shouldRetry=true: next execution will find no .tmp file and start fresh.
                    Log.w(TAG, "Server returned 416 Range Not Satisfiable — deleting stale .tmp")
                    tempFile.delete()
                    java.io.File(tempFile.path + ETAG_SIDECAR_SUFFIX).delete()
                    return@downloadBlock WorkerResult.Failure(
                        "Resume position invalid (file may have changed on server). Retry to restart download.",
                        shouldRetry = true
                    )
                }

                if (!isPartialContent && !isFullContent) {
                    Log.e(TAG, "Failed - Status $statusCode")
                    // 401 + token refresh: attempt refresh and retry once
                    if (statusCode == 401 && config.tokenRefreshConfig != null) {
                        val newToken = HttpSecurityHelper.attemptTokenRefresh(client, config.tokenRefreshConfig)
                        if (newToken != null) {
                            val retryRequest = request.newBuilder()
                                .header(config.tokenRefreshConfig.tokenHeaderName,
                                        "${config.tokenRefreshConfig.tokenPrefix}$newToken")
                                .build()
                            return@downloadBlock try {
                                client.newCall(retryRequest).execute().use { retryResponse ->
                                    val retryStatus = retryResponse.code
                                    if (retryStatus in 200..299) {
                                        WorkerResult.Failure(
                                            "Token refreshed but download retry not supported in single pass — re-enqueue",
                                            shouldRetry = true
                                        )
                                    } else {
                                        WorkerResult.Failure("HTTP $retryStatus (after token refresh)", shouldRetry = retryStatus >= 500)
                                    }
                                }
                            } catch (retryEx: Exception) {
                                WorkerResult.Failure(message = retryEx.message ?: "Retry failed", shouldRetry = true)
                            }
                        }
                    }
                    return@downloadBlock WorkerResult.Failure("HTTP $statusCode", shouldRetry = statusCode >= 500)
                }

                // Log resume status
                if (isResumingDownload) {
                    Log.d(TAG, "Resume confirmed - Server sent 206 Partial Content")
                } else if (existingBytes > 0 && statusCode == HTTP_OK) {
                    Log.w(TAG, "Server doesn't support resume - Starting from beginning")
                    tempFile.delete()
                    java.io.File(tempFile.path + ETAG_SIDECAR_SUFFIX).delete()
                }

                // ✅ SECURITY: Validate content length (prevent downloading huge files)
                val responseBody = response.body
                if (responseBody == null) {
                    Log.e(TAG, "Error - No response body")
                    return@downloadBlock WorkerResult.Failure("No response body")
                }
                
                val contentLength = responseBody.contentLength()
                if (!SecurityValidator.validateContentLength(contentLength)) {
                    Log.e(TAG, "Error - Download size exceeds limit")
                    return@downloadBlock WorkerResult.Failure("Download size exceeds limit")
                }

                // ✅ SECURITY: Validate available disk space
                if (contentLength > 0) {
                    if (!SecurityValidator.hasEnoughDiskSpace(contentLength, destinationFile.parentFile ?: destinationFile)) {
                        Log.e(TAG, "Error - Insufficient disk space")
                        return@downloadBlock WorkerResult.Failure("Insufficient disk space")
                    }
                    Log.d(TAG, "Storage check passed")
                }

                // ✅ PROGRESS: Wrap response body for progress tracking
                // Apply bandwidth throttle (token-bucket, wraps the raw stream)
                val throttledBody = config.bandwidthLimitBytesPerSecond
                    ?.takeIf { it > 0L }
                    ?.let { BandwidthThrottle.wrap(responseBody, it) }
                    ?: responseBody

                val progressBody = ProgressResponseBody(
                    responseBody = throttledBody,
                    taskId = taskId,
                    fileName = destinationFile.name
                )

                val inputStream = progressBody.byteStream()

                // Capture content type and final URL
                val contentType = response.header("Content-Type")
                val finalUrl = response.request.url.toString()

                // 👇 Feature 4: Resolve filename from Content-Disposition or URL when savePath is a directory
                val serverSuggestedName: String? = parseFilenameFromContentDisposition(response.header("Content-Disposition"))
                if (config.isDirectory) {
                    val resolvedName = serverSuggestedName
                        ?: sanitizeFilename(response.request.url.pathSegments.lastOrNull { it.isNotEmpty() } ?: "download")
                    destinationFile = File(config.savePath + resolvedName)
                    Log.d(TAG, "Directory mode — resolved filename: $resolvedName")

                    // skipExisting check for directory mode (now we know the actual path)
                    if (config.skipExisting && destinationFile.exists()) {
                        Log.d(TAG, "skipExisting=true and file already exists — skipping download")
                        return@downloadBlock WorkerResult.Success(
                            message = "File already exists, download skipped",
                            data = buildJsonObject {
                                put("filePath", destinationFile.absolutePath)
                                put("fileName", destinationFile.name)
                                put("fileSize", destinationFile.length())
                                if (serverSuggestedName != null) put("serverSuggestedName", serverSuggestedName)
                                put("skipped", true)
                            }
                        )
                    }
                }

                // 👇 NEW: Stream to temp file (append if resuming, overwrite if starting fresh)
                try {
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
                } catch (e: Exception) {
                    // Do NOT delete tempFile here to allow future resume
                    throw e
                }

                val fileSize = tempFile.length()

                // Save ETag/Last-Modified for future If-Range validation
                if (existingBytes == 0L && isFullContent) {
                    val etag = response.header(HTTP_HEADER_ETAG) ?: response.header(HTTP_HEADER_LAST_MODIFIED)
                    if (etag != null) {
                        try { java.io.File(tempFile.path + ETAG_SIDECAR_SUFFIX).writeText(etag) } catch (_: Exception) {}
                    }
                }

                // 👇 NEW: Verify checksum if expected checksum is provided
                if (config.expectedChecksum != null) {
                    Log.d(TAG, "Verifying checksum with ${config.effectiveChecksumAlgorithm}...")
                    val actualChecksum = calculateChecksum(tempFile, config.effectiveChecksumAlgorithm, taskId)

                    if (!actualChecksum.equals(config.expectedChecksum, ignoreCase = true)) {
                        Log.e(TAG, "Checksum verification failed!")
                        tempFile.delete() // Delete corrupted file
                        return@downloadBlock WorkerResult.Failure(
                            "Checksum verification failed (expected: ${config.expectedChecksum}, actual: $actualChecksum)",
                            shouldRetry = true 
                        )
                    }

                    Log.d(TAG, "Checksum verified: $actualChecksum")
                }

                // onDuplicate=rename: find next available filename
                if (config.onDuplicate == "rename" && destinationFile.exists()) {
                    destinationFile = findNextAvailableFile(destinationFile)
                    Log.d(TAG, "onDuplicate=rename — using: ${destinationFile.name}")
                } else {
                    // Remove destination if exists (overwrite behaviour)
                    destinationFile.delete()
                }

                // Atomic rename from temp to final destination
                try {
                    java.nio.file.Files.move(
                        tempFile.toPath(),
                        destinationFile.toPath(),
                        java.nio.file.StandardCopyOption.REPLACE_EXISTING,
                        java.nio.file.StandardCopyOption.ATOMIC_MOVE
                    )
                } catch (_: java.nio.file.AtomicMoveNotSupportedException) {
                    tempFile.copyTo(destinationFile, overwrite = true)
                    tempFile.delete()
                } catch (e: Exception) {
                    tempFile.delete()
                    return@downloadBlock WorkerResult.Failure("Failed to rename file: ${e.message}")
                }

                // Clean up ETag sidecar after successful download
                java.io.File(tempFile.path + ETAG_SIDECAR_SUFFIX).delete()

                Log.d(TAG, "Success - Downloaded $fileSize bytes")

                // Post-processing: moveToPublicDownloads
                if (config.moveToPublicDownloads && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    try {
                        val ctx = AppContextHolder.appContext
                        val fileName = destinationFile.name
                        val mimeType = getMimeType(fileName) ?: "application/octet-stream"
                        val values = ContentValues().apply {
                            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                            put(MediaStore.Downloads.MIME_TYPE, mimeType)
                            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                        }
                        val uri = ctx.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                        if (uri != null) {
                            ctx.contentResolver.openOutputStream(uri)?.use { out ->
                                destinationFile.inputStream().use { it.copyTo(out) }
                            }
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "moveToPublicDownloads failed: ${e.message}")
                    }
                }

                // Post-processing: saveToGallery
                if (config.saveToGallery && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    try {
                        val ctx = AppContextHolder.appContext
                        val fileName = destinationFile.name
                        val ext = fileName.substringAfterLast('.', "").lowercase()
                        val isVideo = ext in setOf("mp4", "mkv", "avi", "mov", "webm", "flv", "3gp")
                        val isImage = ext in setOf("jpg", "jpeg", "png", "gif", "bmp", "webp", "heic", "heif")
                        val (collectionUri, mimeType) = when {
                            isImage -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI to (getMimeType(fileName) ?: "image/jpeg")
                            isVideo -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI to (getMimeType(fileName) ?: "video/mp4")
                            else -> null to null
                        }
                        if (collectionUri != null && mimeType != null) {
                            val values = ContentValues().apply {
                                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                                put(MediaStore.MediaColumns.RELATIVE_PATH, if (isImage) Environment.DIRECTORY_PICTURES else Environment.DIRECTORY_MOVIES)
                            }
                            val uri = ctx.contentResolver.insert(collectionUri, values)
                            if (uri != null) {
                                ctx.contentResolver.openOutputStream(uri)?.use { out ->
                                    destinationFile.inputStream().use { it.copyTo(out) }
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "saveToGallery failed: ${e.message}")
                    }
                }

                // Post-processing: extractAfterDownload
                if (config.extractAfterDownload) {
                    val ext = destinationFile.name.substringAfterLast('.', "").lowercase()
                    if (ext == "zip") {
                        try {
                            val targetDir = File(config.extractPath ?: destinationFile.parent ?: ".")
                            if (!targetDir.exists()) targetDir.mkdirs()
                            val canonicalTargetPath = targetDir.canonicalPath
                            
                            ZipInputStream(destinationFile.inputStream().buffered()).use { zis ->
                                var entry = zis.nextEntry
                                while (entry != null) {
                                    val entryFile = File(targetDir, entry.name)
                                    val canonicalEntryPath = entryFile.canonicalPath
                                    
                                    // ✅ FIXED: Robust ZipSlip protection using canonicalPath validation
                                    if (!canonicalEntryPath.startsWith(canonicalTargetPath + File.separator)) {
                                        Log.w(TAG, "Security - Preventing ZipSlip attack for entry: ${entry.name}")
                                        zis.closeEntry()
                                        entry = zis.nextEntry
                                        continue
                                    }
                                    
                                    if (entry.isDirectory) {
                                        entryFile.mkdirs()
                                    } else {
                                        entryFile.parentFile?.mkdirs()
                                        entryFile.outputStream().use { zis.copyTo(it) }
                                    }
                                    zis.closeEntry()
                                    entry = zis.nextEntry
                                }
                            }
                            Log.d(TAG, "Extracted zip successfully")
                            if (config.deleteArchiveAfterExtract) {
                                destinationFile.delete()
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "extractAfterDownload failed: ${e.message}")
                        }
                    }
                }

                // ✅ Return success
                WorkerResult.Success(
                    message = "Downloaded ${fileSize} bytes",
                    data = buildJsonObject {
                        put("filePath", destinationFile.absolutePath)
                        put("fileName", destinationFile.name)
                        put("fileSize", fileSize)
                        if (contentType != null) put("contentType", contentType)
                        put("finalUrl", finalUrl)
                        if (serverSuggestedName != null) put("serverSuggestedName", serverSuggestedName)
                    }
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error - ${e.message}", e)
            // Do NOT delete tempFile — preserve partial download so next retry can resume.
            // Only intentional failures (checksum mismatch, invalid path) clean up the temp file.
            WorkerResult.Failure(
                message = e.message ?: "Unknown error",
                shouldRetry = true
            )
        }
        } // end HostConcurrencyManager.withHostPermit
    }

    /** Find next available filename by appending _1, _2, … until a free slot is found.
     *  M-001 FIX: Capped at 10,000 iterations to prevent an unbounded loop when a directory
     *  already contains thousands of similarly-named files (e.g. photo_1.jpg … photo_50000.jpg).
     *  Falls back to a timestamp-suffixed name so the download always completes. */
    private fun findNextAvailableFile(file: File): File {
        val parent = file.parentFile ?: return file
        val nameWithoutExt = file.nameWithoutExtension
        val ext = file.extension.let { if (it.isEmpty()) "" else ".$it" }
        var counter = 1
        var candidate: File
        do {
            candidate = File(parent, "${nameWithoutExt}_$counter$ext")
            counter++
        } while (candidate.exists() && counter <= 10_000)
        // If we hit the cap, use a timestamp suffix to guarantee uniqueness.
        if (candidate.exists()) {
            candidate = File(parent, "${nameWithoutExt}_${System.currentTimeMillis()}$ext")
        }
        return candidate
    }

    /** Return MIME type for a filename based on its extension, or null if unknown. */
    private fun getMimeType(fileName: String): String? =
        MimeTypeMap.getSingleton().getMimeTypeFromExtension(
            fileName.substringAfterLast('.', "").lowercase()
        )

    /**
     * Parse filename from RFC 6266 Content-Disposition header.
     * Prefers `filename*=UTF-8''<encoded>` over `filename=<value>`.
     */
    internal fun parseFilenameFromContentDisposition(header: String?): String? {
        if (header.isNullOrBlank()) return null
        // Try filename* (RFC 5987 encoded) first
        val encodedMatch = Regex("""filename\*\s*=\s*UTF-8''([^;\s]+)""", RegexOption.IGNORE_CASE)
            .find(header)
        if (encodedMatch != null) {
            return try {
                java.net.URLDecoder.decode(encodedMatch.groupValues[1], "UTF-8")
                    .let { sanitizeFilename(it) }.takeIf { it.isNotEmpty() }
            } catch (_: Exception) { null }
        }
        // Fall back to plain filename=
        val plainMatch = Regex("""filename\s*=\s*(?:"([^"]+)"|([^;\s]+))""", RegexOption.IGNORE_CASE)
            .find(header)
        return plainMatch?.let {
            (it.groupValues[1].takeIf { s -> s.isNotEmpty() } ?: it.groupValues[2])
                .let { name -> sanitizeFilename(name) }.takeIf { s -> s.isNotEmpty() }
        }
    }

    /** Remove path separators and other unsafe characters from a filename. */
    internal fun sanitizeFilename(name: String): String =
        name.trim().replace(Regex("""[/\\:*?"<>|]"""), "_").trimStart('.')

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
     * @param taskId Task ID for progress reporting
     * @return Hexadecimal checksum string
     */
    private fun calculateChecksum(file: File, algorithm: String, taskId: String?): String {
        // CROSS-001: normalize short-form aliases ("SHA256") to JCE canonical names ("SHA-256")
        val jceAlgorithm = when (algorithm.uppercase().replace("-", "")) {
            "SHA256" -> "SHA-256"
            "SHA512" -> "SHA-512"
            "SHA1"   -> "SHA-1"
            else     -> algorithm
        }
        val digest = MessageDigest.getInstance(jceAlgorithm)
        val buffer = ByteArray(1024 * 1024) // 1MB buffer for faster hashing
        val totalSize = file.length()
        var readSoFar = 0L

        file.inputStream().use { input ->
            var bytesRead: Int
            while (input.read(buffer).also { bytesRead = it } != -1) {
                digest.update(buffer, 0, bytesRead)
                readSoFar += bytesRead
                
                // FIX #07: Report progress during checksum calculation for large files
                if (taskId != null && totalSize > 10 * 1024 * 1024) { // Only report if > 10MB
                    val pct = (readSoFar * 100 / totalSize).toInt()
                    ProgressReporter.reportProgressNonBlocking(
                        taskId = taskId,
                        progress = pct,
                        message = "Verifying checksum ($pct%)…"
                    )
                }
            }
        }

        // Convert byte array to hex string
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

}
