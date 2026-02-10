package dev.brewkits.native_workmanager.workers

import android.util.Log
import android.webkit.MimeTypeMap
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.workers.utils.ProgressRequestBody
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * Native HTTP file upload worker for Android.
 *
 * Uploads single or multiple files using OkHttp multipart/form-data without requiring Flutter Engine.
 * Supports large file uploads with streaming to minimize memory usage.
 * Also supports raw bytes/string upload for data in memory.
 *
 * **Configuration JSON (Single File - Legacy):**
 * ```json
 * {
 *   "url": "https://api.example.com/upload",
 *   "filePath": "/path/to/file.jpg",
 *   "fileFieldName": "file",      // Optional: Form field name (default: "file")
 *   "fileName": "photo.jpg",       // Optional: Override file name
 *   "mimeType": "image/jpeg",      // Optional: Override MIME type (auto-detected)
 *   "headers": {                   // Optional
 *     "Authorization": "Bearer token"
 *   },
 *   "fields": {                    // Optional: Additional form fields
 *     "userId": "123",
 *     "description": "My photo"
 *   },
 *   "timeoutMs": 120000           // Optional: Timeout (default: 2 minutes for uploads)
 * }
 * ```
 *
 * **Configuration JSON (Multiple Files):**
 * ```json
 * {
 *   "url": "https://api.example.com/upload",
 *   "files": [                     // Array of files
 *     {
 *       "filePath": "/path/to/photo1.jpg",
 *       "fileFieldName": "photos",  // Same field name = array
 *       "fileName": "photo1.jpg",
 *       "mimeType": "image/jpeg"
 *     },
 *     {
 *       "filePath": "/path/to/photo2.jpg",
 *       "fileFieldName": "photos",
 *       "fileName": "photo2.jpg"
 *     }
 *   ],
 *   "headers": { "Authorization": "Bearer token" },
 *   "fields": { "albumId": "123" },
 *   "timeoutMs": 300000
 * }
 * ```
 *
 * **Configuration JSON (Raw Bytes Upload - NEW):**
 * ```json
 * {
 *   "url": "https://api.example.com/data",
 *   "body": "{\"key\": \"value\"}",  // String body (alternative to bodyBytes)
 *   "contentType": "application/json",  // Required for raw upload
 *   "headers": { "Authorization": "Bearer token" },
 *   "timeoutMs": 60000
 * }
 * ```
 *
 * **Configuration JSON (Raw Bytes from Base64 - NEW):**
 * ```json
 * {
 *   "url": "https://api.example.com/binary",
 *   "bodyBytes": "SGVsbG8gV29ybGQh",  // Base64-encoded bytes
 *   "contentType": "application/octet-stream",
 *   "timeoutMs": 60000
 * }
 * ```
 *
 * **Performance:**
 * - Files: ~5-10MB RAM (streaming)
 * - Raw bytes: Depends on body size (loaded in memory)
 */
class HttpUploadWorker : AndroidWorker {

    companion object {
        private const val TAG = "HttpUploadWorker"
        private const val DEFAULT_TIMEOUT_MS = 120_000L
    }

    data class FileConfig(
        val filePath: String,
        val fileFieldName: String = "file",
        val fileName: String? = null,
        val mimeType: String? = null
    )

    data class Config(
        val url: String,
        // 👇 Support both single file (legacy) and multiple files
        val filePath: String? = null,        // Legacy: Single file path
        val files: List<FileConfig>? = null, // Multiple files
        val fileFieldName: String? = null,   // Legacy
        val fileName: String? = null,        // Legacy
        val mimeType: String? = null,        // Legacy
        // 👇 NEW: Raw body upload (alternative to files)
        val body: String? = null,            // String body (JSON, XML, text, etc.)
        val bodyBytes: String? = null,       // Base64-encoded bytes
        val contentType: String? = null,     // Content-Type for raw body (required if body/bodyBytes)
        val headers: Map<String, String>? = null,
        val fields: Map<String, String>? = null,
        val timeoutMs: Long? = null
    ) {
        val timeout: Long get() = timeoutMs ?: DEFAULT_TIMEOUT_MS

        // Build unified file list from either single file or files array
        fun getFileConfigs(): List<FileConfig> {
            return when {
                files != null && files.isNotEmpty() -> files
                filePath != null -> listOf(
                    FileConfig(
                        filePath = filePath,
                        fileFieldName = fileFieldName ?: "file",
                        fileName = fileName,
                        mimeType = mimeType
                    )
                )
                else -> emptyList()
            }
        }

        // Check if this is a raw body upload (not file upload)
        fun isRawBodyUpload(): Boolean = body != null || bodyBytes != null
    }

    override suspend fun doWork(input: String?): WorkerResult = withContext(Dispatchers.IO) {
        if (input.isNullOrEmpty()) {
            throw IllegalArgumentException("Input JSON is required")
        }

        // Parse configuration
        val config = try {
            val j = org.json.JSONObject(input)

            // 👇 NEW: Parse files array if present
            val files = if (j.has("files") && !j.isNull("files")) {
                val filesArray = j.getJSONArray("files")
                (0 until filesArray.length()).map { i ->
                    val fileObj = filesArray.getJSONObject(i)
                    FileConfig(
                        filePath = fileObj.getString("filePath"),
                        fileFieldName = fileObj.optString("fileFieldName", "file"),
                        fileName = if (fileObj.has("fileName") && !fileObj.isNull("fileName")) fileObj.getString("fileName") else null,
                        mimeType = if (fileObj.has("mimeType") && !fileObj.isNull("mimeType")) fileObj.getString("mimeType") else null
                    )
                }
            } else null

            Config(
                url = j.getString("url"),
                // Legacy single file support
                filePath = if (j.has("filePath") && !j.isNull("filePath")) j.getString("filePath") else null,
                files = files,
                fileFieldName = if (j.has("fileFieldName") && !j.isNull("fileFieldName")) j.getString("fileFieldName") else null,
                fileName = if (j.has("fileName") && !j.isNull("fileName")) j.getString("fileName") else null,
                mimeType = if (j.has("mimeType") && !j.isNull("mimeType")) j.getString("mimeType") else null,
                // 👇 NEW: Raw body upload
                body = if (j.has("body") && !j.isNull("body")) j.getString("body") else null,
                bodyBytes = if (j.has("bodyBytes") && !j.isNull("bodyBytes")) j.getString("bodyBytes") else null,
                contentType = if (j.has("contentType") && !j.isNull("contentType")) j.getString("contentType") else null,
                headers = parseStringMap(j.optJSONObject("headers")),
                fields = parseStringMap(j.optJSONObject("additionalFields")),
                timeoutMs = if (j.has("timeoutMs")) j.getLong("timeoutMs") else null
            )
        } catch (e: Exception) {
            throw IllegalArgumentException("Invalid config JSON: ${e.message}", e)
        }

        // Extract taskId for progress reporting
        val taskId = try {
            org.json.JSONObject(input).optString("__taskId", null)
        } catch (e: Exception) {
            null
        }

        // ✅ SECURITY: Validate URL scheme (prevent file://, content://, etc.)
        if (!SecurityValidator.validateURL(config.url)) {
            Log.e(TAG, "Error - Invalid or unsafe URL")
            return@withContext WorkerResult.Failure("Invalid or unsafe URL")
        }

        // 👇 NEW: Check upload mode (raw body or files)
        val isRawBodyUpload = config.isRawBodyUpload()
        val fileConfigs = config.getFileConfigs()

        // Validate upload mode
        if (isRawBodyUpload && fileConfigs.isNotEmpty()) {
            Log.e(TAG, "Error - Cannot mix raw body and file upload")
            return@withContext WorkerResult.Failure("Cannot use both body/bodyBytes and filePath/files")
        }

        if (!isRawBodyUpload && fileConfigs.isEmpty()) {
            Log.e(TAG, "Error - No data to upload")
            return@withContext WorkerResult.Failure("No data to upload (provide body/bodyBytes or filePath/files)")
        }

        // 👇 NEW: Handle raw body upload
        if (isRawBodyUpload) {
            return@withContext handleRawBodyUpload(config, taskId)
        }

        // Validate all files exist and are valid
        var totalSize = 0L
        val validatedFiles = mutableListOf<Triple<File, String, String>>() // (File, fileName, mimeType)

        for (fileConfig in fileConfigs) {
            // ✅ SECURITY: Basic path validation
            if (fileConfig.filePath.contains("..") || !fileConfig.filePath.startsWith("/")) {
                Log.e(TAG, "Error - Invalid file path (path traversal attempt): ${fileConfig.filePath}")
                return@withContext WorkerResult.Failure("Invalid file path: ${fileConfig.filePath}")
            }

            val file = File(fileConfig.filePath)
            if (!file.exists()) {
                Log.e(TAG, "Error - File not found: ${fileConfig.filePath}")
                return@withContext WorkerResult.Failure("File not found: ${fileConfig.filePath}")
            }

            // ✅ SECURITY: Validate file size
            if (!SecurityValidator.validateFileSize(file)) {
                Log.e(TAG, "Error - File size exceeds upload limit: ${fileConfig.filePath}")
                return@withContext WorkerResult.Failure("File size exceeds limit: ${file.name}")
            }

            totalSize += file.length()

            // Detect MIME type and get file name
            val mimeType = fileConfig.mimeType ?: detectMimeType(file)
            val fileName = fileConfig.fileName ?: file.name

            validatedFiles.add(Triple(file, fileName, mimeType))
        }

        // ✅ SECURITY: Sanitize logging (don't log full paths)
        val sanitizedURL = SecurityValidator.sanitizedURL(config.url)
        Log.d(TAG, "Uploading to $sanitizedURL")
        Log.d(TAG, "  Files: ${validatedFiles.size}, Total Size: $totalSize bytes")
        validatedFiles.forEachIndexed { index, (file, fileName, mimeType) ->
            Log.d(TAG, "    [$index] $fileName (${file.length()} bytes, $mimeType)")
        }

        // Build HTTP client with timeout
        val client = OkHttpClient.Builder()
            .connectTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .readTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .writeTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .build()

        // Build multipart body
        val multipartBuilder = MultipartBody.Builder()
            .setType(MultipartBody.FORM)

        // Add form fields
        config.fields?.forEach { (key, value) ->
            multipartBuilder.addFormDataPart(key, value)
        }

        // 👇 NEW: Add all files to multipart body
        validatedFiles.forEachIndexed { index, (file, fileName, mimeType) ->
            val fileFieldName = fileConfigs[index].fileFieldName
            multipartBuilder.addFormDataPart(
                fileFieldName,
                fileName,
                file.asRequestBody(mimeType.toMediaType())
            )
        }

        val requestBody = multipartBuilder.build()

        // ✅ PROGRESS: Wrap request body for progress tracking
        val allFileNames = validatedFiles.joinToString(", ") { it.second }
        val progressRequestBody = ProgressRequestBody(
            requestBody = requestBody,
            taskId = taskId,
            fileName = allFileNames  // 👈 Show all file names in progress
        )

        // Build request
        val requestBuilder = Request.Builder()
            .url(config.url)
            .post(progressRequestBody)

        // Add headers
        config.headers?.forEach { (key, value) ->
            requestBuilder.addHeader(key, value)
        }

        val request = requestBuilder.build()

        // Execute upload
        return@withContext try {
            client.newCall(request).execute().use { response ->
                val responseBody = response.body?.bytes() ?: ByteArray(0)

                // ✅ SECURITY: Validate response body size
                if (!SecurityValidator.validateResponseSize(responseBody)) {
                    Log.e(TAG, "Error - Response body too large")
                    return@withContext WorkerResult.Failure("Response body too large")
                }

                val statusCode = response.code
                val success = statusCode in 200..299
                val responseString = responseBody.toString(Charsets.UTF_8)

                if (success) {
                    // ✅ SECURITY: Truncate response for logging
                    val truncatedResponse = SecurityValidator.truncateForLogging(responseString, 200)
                    Log.d(TAG, "Success - Status $statusCode")
                    Log.d(TAG, "Response: $truncatedResponse")

                    // ✅ Return success with upload data
                    WorkerResult.Success(
                        message = "Uploaded ${validatedFiles.size} file(s), $totalSize bytes",
                        data = mapOf(
                            "statusCode" to statusCode,
                            "uploadedSize" to totalSize,
                            "fileCount" to validatedFiles.size,  // 👈 NEW
                            "fileNames" to validatedFiles.map { it.second },  // 👈 NEW
                            "responseBody" to responseString
                        )
                    )
                } else {
                    // ✅ SECURITY: Truncate error body for logging
                    val truncatedError = SecurityValidator.truncateForLogging(responseString, 200)
                    Log.e(TAG, "Failed - Status $statusCode")
                    Log.e(TAG, "Error: $truncatedError")

                    WorkerResult.Failure(
                        message = "HTTP $statusCode: $truncatedError",
                        shouldRetry = statusCode >= 500
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error - ${e.message}", e)
            WorkerResult.Failure(
                message = e.message ?: "Unknown error",
                shouldRetry = true
            )
        }
    }

    /**
     * Handle raw body upload (string or bytes).
     */
    private suspend fun handleRawBodyUpload(config: Config, taskId: String?): WorkerResult = withContext(Dispatchers.IO) {
        // Validate content type is provided
        if (config.contentType.isNullOrEmpty()) {
            Log.e(TAG, "Error - contentType is required for raw body upload")
            return@withContext WorkerResult.Failure("contentType is required for raw body upload")
        }

        val sanitizedURL = SecurityValidator.sanitizedURL(config.url)
        Log.d(TAG, "Uploading raw body to $sanitizedURL")
        Log.d(TAG, "  Content-Type: ${config.contentType}")

        // Build request body
        val requestBody = when {
            config.body != null -> {
                val bodySize = config.body.toByteArray(Charsets.UTF_8).size
                Log.d(TAG, "  Body: ${config.body.length} characters ($bodySize bytes)")
                config.body.toRequestBody(config.contentType.toMediaType())
            }
            config.bodyBytes != null -> {
                try {
                    val decodedBytes = android.util.Base64.decode(config.bodyBytes, android.util.Base64.DEFAULT)
                    Log.d(TAG, "  Body: ${decodedBytes.size} bytes (from base64)")
                    decodedBytes.toRequestBody(config.contentType.toMediaType())
                } catch (e: Exception) {
                    Log.e(TAG, "Error - Failed to decode base64 bodyBytes: ${e.message}")
                    return@withContext WorkerResult.Failure("Invalid base64 bodyBytes: ${e.message}")
                }
            }
            else -> {
                Log.e(TAG, "Error - No body or bodyBytes provided")
                return@withContext WorkerResult.Failure("No body or bodyBytes provided")
            }
        }

        // ✅ PROGRESS: Wrap request body for progress tracking
        val progressRequestBody = ProgressRequestBody(
            requestBody = requestBody,
            taskId = taskId,
            fileName = "raw body"
        )

        // Build HTTP client with timeout
        val client = OkHttpClient.Builder()
            .connectTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .readTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .writeTimeout(config.timeout, TimeUnit.MILLISECONDS)
            .build()

        // Build request
        val requestBuilder = Request.Builder()
            .url(config.url)
            .post(progressRequestBody)

        // Add headers
        config.headers?.forEach { (key, value) ->
            requestBuilder.addHeader(key, value)
        }

        val request = requestBuilder.build()

        // Execute upload
        return@withContext try {
            client.newCall(request).execute().use { response ->
                val responseBody = response.body?.bytes() ?: ByteArray(0)

                // ✅ SECURITY: Validate response body size
                if (!SecurityValidator.validateResponseSize(responseBody)) {
                    Log.e(TAG, "Error - Response body too large")
                    return@withContext WorkerResult.Failure("Response body too large")
                }

                val statusCode = response.code
                val success = statusCode in 200..299
                val responseString = responseBody.toString(Charsets.UTF_8)

                if (success) {
                    // ✅ SECURITY: Truncate response for logging
                    val truncatedResponse = SecurityValidator.truncateForLogging(responseString, 200)
                    Log.d(TAG, "Success - Status $statusCode")
                    Log.d(TAG, "Response: $truncatedResponse")

                    WorkerResult.Success(
                        message = "Uploaded raw body",
                        data = mapOf(
                            "statusCode" to statusCode,
                            "uploadedSize" to requestBody.contentLength(),
                            "contentType" to config.contentType,
                            "responseBody" to responseString
                        )
                    )
                } else {
                    // ✅ SECURITY: Truncate error body for logging
                    val truncatedError = SecurityValidator.truncateForLogging(responseString, 200)
                    Log.e(TAG, "Failed - Status $statusCode")
                    Log.e(TAG, "Error: $truncatedError")

                    WorkerResult.Failure(
                        message = "HTTP $statusCode: $truncatedError",
                        shouldRetry = statusCode >= 500
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error - ${e.message}", e)
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
     * Detect MIME type from file extension.
     */
    private fun detectMimeType(file: File): String {
        val extension = file.extension.lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?: "application/octet-stream"
    }

}
