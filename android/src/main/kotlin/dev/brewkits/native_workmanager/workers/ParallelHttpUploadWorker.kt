package dev.brewkits.native_workmanager.workers

import android.util.Log
import android.webkit.MimeTypeMap
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.workers.utils.HostConcurrencyManager
import dev.brewkits.native_workmanager.workers.utils.ProgressReporter
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import okio.Buffer
import okio.ForwardingSink
import okio.buffer
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Parallel multi-file HTTP upload worker for Android.
 *
 * Uploads each file as a **separate** concurrent multipart request with a
 * per-host concurrency limit.  Each file is retried independently up to
 * [Config.maxRetries] times on 5xx / network errors.
 *
 * **Configuration JSON:**
 * ```json
 * {
 *   "url": "https://api.example.com/photos",
 *   "files": [
 *     { "filePath": "/...", "fieldName": "file", "fileName": "img.jpg", "mimeType": "image/jpeg" }
 *   ],
 *   "headers": { "Authorization": "Bearer token" },
 *   "fields":  { "albumId": "42" },
 *   "maxConcurrent": 3,
 *   "maxRetries": 1,
 *   "timeoutMs": 300000
 * }
 * ```
 */
class ParallelHttpUploadWorker : AndroidWorker {

    companion object {
        private const val TAG = "ParallelHttpUploadWorker"
        private const val DEFAULT_TIMEOUT_MS = 300_000L
        private const val DEFAULT_MAX_CONCURRENT = 3
        private const val DEFAULT_MAX_RETRIES = 1
    }

    data class FileSpec(
        val filePath: String,
        val fieldName: String = "file",
        val fileName: String? = null,
        val mimeType: String? = null,
    )

    data class Config(
        val url: String,
        val files: List<FileSpec>,
        val headers: Map<String, String>?,
        val fields: Map<String, String>?,
        val maxConcurrent: Int = DEFAULT_MAX_CONCURRENT,
        val maxRetries: Int = DEFAULT_MAX_RETRIES,
        val timeoutMs: Long = DEFAULT_TIMEOUT_MS,
    )

    override suspend fun doWork(input: String?, env: dev.brewkits.kmpworkmanager.background.domain.WorkerEnvironment): WorkerResult = withContext(Dispatchers.IO) {
        if (input.isNullOrEmpty()) throw IllegalArgumentException("Input JSON is required")

        val config = parseConfig(input)
        val taskId = try { JSONObject(input).optString("__taskId", null) } catch (_: Exception) { null }

        if (!SecurityValidator.validateURL(config.url)) {
            return@withContext WorkerResult.Failure("Invalid or unsafe URL")
        }

        val host = java.net.URL(config.url).host

        // ── Validate all files upfront ────────────────────────────────────────
        val validatedFiles = mutableListOf<Triple<File, String, String>>() // (file, resolvedName, resolvedMime)
        var totalBytes = 0L
        for (spec in config.files) {
            if (!SecurityValidator.validateFilePathSafe(spec.filePath)) {
                return@withContext WorkerResult.Failure("Invalid file path: ${spec.filePath}")
            }
            val file = File(spec.filePath)
            if (!file.exists()) return@withContext WorkerResult.Failure("File not found: ${spec.filePath}")
            if (!SecurityValidator.validateFileSize(file)) {
                return@withContext WorkerResult.Failure("File size exceeds limit: ${file.name}")
            }
            totalBytes += file.length()
            val mime = spec.mimeType ?: detectMimeType(file)
            val name = spec.fileName ?: file.name
            validatedFiles.add(Triple(file, name, mime))
        }

        Log.d(TAG, "Uploading ${validatedFiles.size} files to ${SecurityValidator.sanitizedURL(config.url)}" +
            "  maxConcurrent=${config.maxConcurrent}  maxRetries=${config.maxRetries}")

        val client = OkHttpClient.Builder()
            .connectTimeout(config.timeoutMs, TimeUnit.MILLISECONDS)
            .readTimeout(config.timeoutMs, TimeUnit.MILLISECONDS)
            .writeTimeout(config.timeoutMs, TimeUnit.MILLISECONDS)
            .build()

        val totalUploaded = AtomicLong(0L)
        val uploadedCount = AtomicLong(0L)

        // Emit initial progress
        if (taskId != null) {
            ProgressReporter.reportProgressNonBlocking(
                taskId, 0, "Starting upload of ${validatedFiles.size} files..."
            )
        }

        // ── Launch all file uploads concurrently (per-host concurrency capped) ─
        val fileResults = config.files.indices.map { i ->
            async(Dispatchers.IO) {
                val (file, resolvedName, mime) = validatedFiles[i]
                val spec = config.files[i]
                var attempt = 0
                var lastError = "Unknown error"

                while (attempt <= config.maxRetries) {
                    if (attempt > 0) Log.d(TAG, "Retry $attempt/${config.maxRetries} for ${file.name}")

                    val result = HostConcurrencyManager.withHostPermit(host) {
                        uploadSingleFile(
                            client = client,
                            url = config.url,
                            file = file,
                            fieldName = spec.fieldName,
                            fileName = resolvedName,
                            mimeType = mime,
                            headers = config.headers,
                            fields = config.fields,
                            onProgress = { bytes ->
                                val uploaded = totalUploaded.addAndGet(bytes)
                                if (taskId != null && totalBytes > 0) {
                                    val done = uploadedCount.get()
                                    val pct = ((uploaded.toFloat() / totalBytes) * 100).toInt().coerceIn(0, 99)
                                    ProgressReporter.reportProgressNonBlocking(
                                        taskId, pct,
                                        "Uploading... $done/${validatedFiles.size} files complete"
                                    )
                                }
                            }
                        )
                    }

                    if (result.success) {
                        val done = uploadedCount.incrementAndGet()
                        Log.d(TAG, "[$i] ${file.name} uploaded ($done/${validatedFiles.size})")
                        if (taskId != null) {
                            val pct = ((done.toFloat() / validatedFiles.size) * 100).toInt().coerceIn(0, 99)
                            ProgressReporter.reportProgressNonBlocking(
                                taskId, pct,
                                "Uploaded $done/${validatedFiles.size} files"
                            )
                        }
                        return@async mapOf(
                            "fileName" to resolvedName,
                            "filePath" to file.absolutePath,
                            "fileSize" to file.length(),
                            "success" to true,
                            "statusCode" to result.statusCode,
                            "responseBody" to result.responseBody,
                        )
                    }

                    lastError = result.errorMessage ?: "Upload failed"
                    if (!result.shouldRetry) break
                    attempt++
                }

                Log.w(TAG, "[$i] ${file.name} failed after ${attempt} attempt(s): $lastError")
                mapOf(
                    "fileName" to resolvedName,
                    "filePath" to file.absolutePath,
                    "fileSize" to file.length(),
                    "success" to false,
                    "error" to lastError,
                )
            }
        }.awaitAll()

        val succeeded = fileResults.count { it["success"] == true }
        val failed = fileResults.size - succeeded
        val actualUploaded = totalUploaded.get()

        if (taskId != null) ProgressReporter.reportProgressNonBlocking(taskId, 100, "Upload complete: $succeeded/${fileResults.size} files")
        Log.d(TAG, "Done — $succeeded succeeded, $failed failed, $actualUploaded bytes total")

        if (succeeded == 0) {
            return@withContext WorkerResult.Failure(
                "All ${fileResults.size} file uploads failed",
                shouldRetry = true
            )
        }

        WorkerResult.Success(
            message = "Uploaded $succeeded/${fileResults.size} files ($actualUploaded bytes)",
            data = buildJsonObject {
                put("uploadedCount", succeeded)
                put("failedCount", failed)
                put("totalBytes", actualUploaded)
            }
        )
    }

    // ── Upload a single file, return upload outcome ───────────────────────────

    private data class UploadOutcome(
        val success: Boolean,
        val statusCode: Int = 0,
        val responseBody: String = "",
        val errorMessage: String? = null,
        val shouldRetry: Boolean = false,
    )

    private fun uploadSingleFile(
        client: OkHttpClient,
        url: String,
        file: File,
        fieldName: String,
        fileName: String,
        mimeType: String,
        headers: Map<String, String>?,
        fields: Map<String, String>?,
        onProgress: (Long) -> Unit,
    ): UploadOutcome {
        return try {
            val multipartBuilder = MultipartBody.Builder().setType(MultipartBody.FORM)
            fields?.forEach { (k, v) -> multipartBuilder.addFormDataPart(k, v) }

            val fileBody = ProgressTrackingRequestBody(
                delegate = file.asRequestBody(mimeType.toMediaType()),
                onProgress = onProgress,
            )
            multipartBuilder.addFormDataPart(fieldName, fileName, fileBody)

            val reqBuilder = Request.Builder().url(url).post(multipartBuilder.build())
            headers?.forEach { (k, v) -> reqBuilder.addHeader(k, v) }

            client.newCall(reqBuilder.build()).execute().use { response ->
                val body = response.body?.bytes() ?: ByteArray(0)
                if (!SecurityValidator.validateResponseSize(body)) {
                    return UploadOutcome(success = false, errorMessage = "Response too large", shouldRetry = false)
                }
                val responseStr = body.toString(Charsets.UTF_8)
                val code = response.code
                if (code in 200..299) {
                    UploadOutcome(success = true, statusCode = code, responseBody = responseStr)
                } else {
                    UploadOutcome(
                        success = false,
                        statusCode = code,
                        errorMessage = "HTTP $code: ${SecurityValidator.truncateForLogging(responseStr, 200)}",
                        shouldRetry = code >= 500,
                    )
                }
            }
        } catch (e: Exception) {
            UploadOutcome(success = false, errorMessage = e.message, shouldRetry = true)
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun parseConfig(input: String): Config {
        val j = JSONObject(input)
        val filesArray: JSONArray = j.getJSONArray("files")
        val fileSpecs = (0 until filesArray.length()).map { i ->
            val f = filesArray.getJSONObject(i)
            FileSpec(
                filePath  = f.getString("filePath"),
                fieldName = f.optString("fieldName", "file"),
                fileName  = if (f.has("fileName")  && !f.isNull("fileName"))  f.getString("fileName")  else null,
                mimeType  = if (f.has("mimeType")  && !f.isNull("mimeType"))  f.getString("mimeType")  else null,
            )
        }
        return Config(
            url           = j.getString("url"),
            files         = fileSpecs,
            headers       = parseStringMap(j.optJSONObject("headers")),
            fields        = parseStringMap(j.optJSONObject("fields")),
            maxConcurrent = j.optInt("maxConcurrent", DEFAULT_MAX_CONCURRENT).coerceIn(1, 16),
            maxRetries    = j.optInt("maxRetries", DEFAULT_MAX_RETRIES).coerceIn(0, 5),
            timeoutMs     = if (j.has("timeoutMs")) j.getLong("timeoutMs") else DEFAULT_TIMEOUT_MS,
        )
    }

    private fun parseStringMap(obj: JSONObject?): Map<String, String>? {
        if (obj == null) return null
        return obj.keys().asSequence().associateWith { obj.getString(it) }
    }

    private fun detectMimeType(file: File): String =
        MimeTypeMap.getSingleton().getMimeTypeFromExtension(file.extension.lowercase())
            ?: "application/octet-stream"
}

// ── Progress-tracking OkHttp RequestBody wrapper ─────────────────────────────

private class ProgressTrackingRequestBody(
    private val delegate: okhttp3.RequestBody,
    private val onProgress: (Long) -> Unit,
) : okhttp3.RequestBody() {

    override fun contentType(): okhttp3.MediaType? = delegate.contentType()
    override fun contentLength(): Long = delegate.contentLength()

    override fun writeTo(sink: okio.BufferedSink) {
        val tracked = object : okio.ForwardingSink(sink) {
            override fun write(source: okio.Buffer, byteCount: Long) {
                super.write(source, byteCount)
                onProgress(byteCount)
            }
        }
        val bufferedSink = tracked.buffer()
        delegate.writeTo(bufferedSink)
        bufferedSink.flush()
    }
}
