package dev.brewkits.native_workmanager.workers

import android.util.Log
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.workers.utils.HttpSecurityHelper
import dev.brewkits.native_workmanager.workers.utils.HttpSecurityHelper.applyCertificatePinning
import dev.brewkits.native_workmanager.workers.utils.ProgressReporter
import dev.brewkits.native_workmanager.workers.utils.RequestSigner
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Parallel chunked HTTP download worker for Android.
 *
 * Splits a single download into [numChunks] parallel byte-range requests
 * (HTTP Range header, RFC 7233), streams each chunk to a `.partN` temp file,
 * then concatenates them into the final destination atomically.
 *
 * **Automatic fallback:** If the server does not respond with
 * `Accept-Ranges: bytes` or does not return a `Content-Length`, the worker
 * falls back to a normal sequential download (identical to HttpDownloadWorker).
 *
 * **Resume:** Each `.partN` file persists across retries. On re-execution
 * already-complete parts are skipped automatically.
 *
 * **Configuration JSON:**
 * ```json
 * {
 *   "url": "https://cdn.example.com/movie.mp4",
 *   "savePath": "/data/.../files/movie.mp4",
 *   "numChunks": 4,           // optional, default 4 (1–16)
 *   "headers": {},            // optional
 *   "timeoutMs": 600000,      // optional, default 10 min
 *   "expectedChecksum": "...",// optional
 *   "checksumAlgorithm": "SHA-256" // optional
 * }
 * ```
 */
class ParallelHttpDownloadWorker : AndroidWorker {

    companion object {
        private const val TAG = "ParallelHttpDownloadWorker"
        private const val DEFAULT_TIMEOUT_MS = 600_000L
        private const val DEFAULT_NUM_CHUNKS = 4
    }

    data class Config(
        val url: String,
        val savePath: String,
        val numChunks: Int = DEFAULT_NUM_CHUNKS,
        val headers: Map<String, String>? = null,
        val timeoutMs: Long = DEFAULT_TIMEOUT_MS,
        val expectedChecksum: String? = null,
        val checksumAlgorithm: String = "SHA-256",
        val skipExisting: Boolean = false,
        val requestSigningConfig: RequestSigner.Config? = null,
        val certificatePinningConfig: HttpSecurityHelper.CertificatePinningConfig? = null,
        val tokenRefreshConfig: HttpSecurityHelper.TokenRefreshConfig? = null,
    )

    override suspend fun doWork(input: String?, env: dev.brewkits.kmpworkmanager.background.domain.WorkerEnvironment): WorkerResult = withContext(Dispatchers.IO) {
        if (input.isNullOrEmpty()) {
            throw IllegalArgumentException("Input JSON is required")
        }

        val config = try {
            val j = JSONObject(input)
            Config(
                url = j.getString("url"),
                savePath = j.getString("savePath"),
                numChunks = j.optInt("numChunks", DEFAULT_NUM_CHUNKS).coerceIn(1, 16),
                headers = parseStringMap(j.optJSONObject("headers")),
                timeoutMs = if (j.has("timeoutMs")) j.getLong("timeoutMs") else DEFAULT_TIMEOUT_MS,
                expectedChecksum = if (j.has("expectedChecksum")) j.getString("expectedChecksum") else null,
                checksumAlgorithm = j.optString("checksumAlgorithm", "SHA-256"),
                skipExisting = j.optBoolean("skipExisting", false),
                requestSigningConfig = RequestSigner.fromMap(j.optJSONObject("requestSigning")),
                certificatePinningConfig = HttpSecurityHelper.CertificatePinningConfig.fromMap(j.optJSONObject("certificatePinning")),
                tokenRefreshConfig = HttpSecurityHelper.TokenRefreshConfig.fromMap(j.optJSONObject("tokenRefresh")),
            )
        } catch (e: Exception) {
            throw IllegalArgumentException("Invalid config JSON: ${e.message}", e)
        }

        val destinationFile = File(config.savePath)

        // Skip download if destination already exists and skipExisting is enabled
        if (config.skipExisting && destinationFile.exists()) {
            Log.d(TAG, "skipExisting=true and file already exists — skipping download")
            return@withContext WorkerResult.Success(
                message = "File already exists, download skipped",
                data = buildJsonObject {
                    put("filePath", config.savePath)
                    put("skipped", true)
                }
            )
        }

        if (!SecurityValidator.validateURL(config.url)) {
            return@withContext WorkerResult.Failure("Invalid or unsafe URL")
        }
        if (!SecurityValidator.validateFilePathSafe(config.savePath)) {
            return@withContext WorkerResult.Failure("Invalid or unsafe save path")
        }

        val taskId = try { JSONObject(input).optString("__taskId", null) } catch (_: Exception) { null }

        // Ensure parent directory exists
        destinationFile.parentFile?.let { if (!it.exists()) it.mkdirs() }

        val client = HttpSecurityHelper.sharedClient.newBuilder()
            .connectTimeout(config.timeoutMs, TimeUnit.MILLISECONDS)
            .readTimeout(config.timeoutMs, TimeUnit.MILLISECONDS)
            .applyCertificatePinning(config.url, config.certificatePinningConfig)
            .build()

        // ── Step 1: HEAD request ──────────────────────────────────────────────
        val sanitizedUrl = SecurityValidator.sanitizedURL(config.url)
        Log.d(TAG, "HEAD $sanitizedUrl")

        val headRequestBuilder = Request.Builder().url(config.url).head().apply {
            config.headers?.forEach { (k, v) -> addHeader(k, v) }
        }
        val headRequest = config.requestSigningConfig
            ?.let { RequestSigner.sign(headRequestBuilder.build(), it) }
            ?: headRequestBuilder.build()

        val (contentLength, acceptsRanges) = try {
            client.newCall(headRequest).execute().use { r ->
                val cl = r.header("Content-Length")?.toLongOrNull() ?: -1L
                val ar = r.header("Accept-Ranges")?.equals("bytes", ignoreCase = true) == true
                Pair(cl, ar)
            }
        } catch (e: Exception) {
            Log.w(TAG, "HEAD failed, falling back to sequential: ${e.message}")
            Pair(-1L, false)
        }

        // ── Step 2: Fallback if server doesn't support range requests ─────────
        if (!acceptsRanges || contentLength <= 0) {
            Log.d(TAG, "Server does not support ranges or unknown size — sequential fallback")
            return@withContext downloadSequential(client, config, taskId, destinationFile)
        }

        Log.d(TAG, "Content-Length=$contentLength  Accept-Ranges=bytes  chunks=${config.numChunks}")

        // ── Step 3: Compute byte ranges ───────────────────────────────────────
        // CRIT-001: use explicit Long arithmetic throughout to prevent Int overflow
        // on files > 2 GB (Int.MAX_VALUE ≈ 2.1 GB).
        val numChunksL = config.numChunks.toLong()
        val chunkSize = contentLength / numChunksL
        val ranges = (0 until config.numChunks).map { i ->
            val start = i.toLong() * chunkSize
            val end = if (i == config.numChunks - 1) contentLength - 1L else start + chunkSize - 1L
            Pair(start, end)
        }

        // ── Step 4: Check disk space for total file ───────────────────────────
        if (!SecurityValidator.hasEnoughDiskSpace(contentLength, destinationFile.parentFile ?: destinationFile)) {
            return@withContext WorkerResult.Failure("Insufficient disk space")
        }

        // ── Step 5: Download chunks in parallel ───────────────────────────────
        val totalDownloaded = AtomicLong(0L)

        // Emit initial progress
        if (taskId != null) {
            ProgressReporter.reportProgressNonBlocking(taskId, 0, "Starting parallel download (${config.numChunks} chunks)...")
        }

        val chunkResults = (0 until config.numChunks).map { chunkIndex ->
            async(Dispatchers.IO) {
                val partFile = File("${config.savePath}.part$chunkIndex")
                val (rangeStart, rangeEnd) = ranges[chunkIndex]

                // Resume: skip if part is already complete
                val existingSize = if (partFile.exists()) partFile.length() else 0L
                val expectedChunkSize = rangeEnd - rangeStart + 1
                if (existingSize >= expectedChunkSize) {
                    Log.d(TAG, "Chunk $chunkIndex already complete ($existingSize bytes), skipping")
                    totalDownloaded.addAndGet(existingSize)
                    return@async true
                }

                // Adjust range if partial
                val resumeFrom = rangeStart + existingSize
                val rangeHeader = "bytes=$resumeFrom-$rangeEnd"
                Log.d(TAG, "Downloading chunk $chunkIndex: $rangeHeader")

                val reqBuilder = Request.Builder().url(config.url)
                    .addHeader("Range", rangeHeader)
                    .apply { config.headers?.forEach { (k, v) -> addHeader(k, v) } }
                val req = config.requestSigningConfig
                    ?.let { RequestSigner.sign(reqBuilder.build(), it) }
                    ?: reqBuilder.build()

                try {
                    client.newCall(req).execute().use { response ->
                        if (response.code !in 200..299) {
                            Log.e(TAG, "Chunk $chunkIndex failed: HTTP ${response.code}")
                            return@async false
                        }
                        val body = response.body ?: run {
                            Log.e(TAG, "Chunk $chunkIndex: empty body")
                            return@async false
                        }

                        val append = existingSize > 0
                        FileOutputStream(partFile, append).use { out ->
                            val buf = ByteArray(65_536)
                            body.byteStream().use { stream ->
                                var n: Int
                                while (stream.read(buf).also { n = it } != -1) {
                                    out.write(buf, 0, n)
                                    val downloaded = totalDownloaded.addAndGet(n.toLong())
                                    if (taskId != null) {
                                        val pct = ((downloaded.toFloat() / contentLength) * 100).toInt()
                                        ProgressReporter.reportProgressNonBlocking(
                                            taskId, pct,
                                            "Downloading... ${formatBytes(downloaded)}/${formatBytes(contentLength)}"
                                        )
                                    }
                                }
                            }
                        }
                        // NET-015: verify the downloaded chunk is the expected size.
                        // If the server returns fewer bytes than the range requested, the merged
                        // file will be silently truncated (checksum catches it only if configured).
                        val downloadedSize = partFile.length()
                        if (downloadedSize < expectedChunkSize) {
                            Log.e(TAG, "Chunk $chunkIndex truncated: expected $expectedChunkSize bytes, got $downloadedSize")
                            return@async false
                        }
                        Log.d(TAG, "Chunk $chunkIndex done: $downloadedSize bytes")
                        true
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Chunk $chunkIndex error: ${e.message}", e)
                    false
                }
            }
        }.awaitAll()

        // ── Step 6: Check all chunks succeeded ───────────────────────────────
        if (chunkResults.any { !it }) {
            return@withContext WorkerResult.Failure(
                "One or more chunks failed — partial files retained for retry",
                shouldRetry = true
            )
        }

        // ── Step 7: Merge parts → temp file ──────────────────────────────────
        val tempFile = File("${config.savePath}.tmp")
        Log.d(TAG, "Merging ${config.numChunks} chunks into ${tempFile.name}")

        try {
            FileOutputStream(tempFile).use { out ->
                for (i in 0 until config.numChunks) {
                    val partFile = File("${config.savePath}.part$i")
                    partFile.inputStream().use { it.copyTo(out) }
                }
            }
        } catch (e: Exception) {
            tempFile.delete()
            return@withContext WorkerResult.Failure("Failed to merge chunks: ${e.message}")
        }

        // Delete part files after successful merge
        for (i in 0 until config.numChunks) {
            File("${config.savePath}.part$i").delete()
        }

        // ── Step 8: Checksum verification ────────────────────────────────────
        if (config.expectedChecksum != null) {
            val supportedAlgorithms = setOf("MD5", "SHA-1", "SHA1", "SHA-256", "SHA256", "SHA-512", "SHA512")
            if (config.checksumAlgorithm.uppercase() !in supportedAlgorithms) {
                tempFile.delete()
                return@withContext WorkerResult.Failure(
                    "Unsupported checksum algorithm: '${config.checksumAlgorithm}'. " +
                    "Supported: ${supportedAlgorithms.joinToString()}",
                    shouldRetry = false
                )
            }
            Log.d(TAG, "Verifying checksum (${config.checksumAlgorithm})...")
            val actual = calculateChecksum(tempFile, config.checksumAlgorithm)
            if (!actual.equals(config.expectedChecksum, ignoreCase = true)) {
                tempFile.delete()
                return@withContext WorkerResult.Failure(
                    "Checksum mismatch (expected: ${config.expectedChecksum}, actual: $actual)",
                    shouldRetry = true
                )
            }
            Log.d(TAG, "Checksum OK: $actual")
        }

        // ── Step 9: Atomic rename ─────────────────────────────────────────────
        destinationFile.delete()
        try {
            java.nio.file.Files.move(
                tempFile.toPath(),
                destinationFile.toPath(),
                java.nio.file.StandardCopyOption.REPLACE_EXISTING,
                java.nio.file.StandardCopyOption.ATOMIC_MOVE
            )
        } catch (_: java.nio.file.AtomicMoveNotSupportedException) {
            // Atomic move not supported across filesystems — fall back to copy+delete
            tempFile.copyTo(destinationFile, overwrite = true)
            tempFile.delete()
        } catch (e: Exception) {
            tempFile.delete()
            return@withContext WorkerResult.Failure("Failed to rename file: ${e.message}")
        }

        val finalSize = destinationFile.length()
        if (taskId != null) ProgressReporter.reportProgressNonBlocking(taskId, 100, "Download complete")
        Log.d(TAG, "Success — $finalSize bytes saved to ${config.savePath}")

        WorkerResult.Success(
            message = "Downloaded $finalSize bytes (${config.numChunks} parallel chunks)",
            data = buildJsonObject {
                put("filePath", destinationFile.absolutePath)
                put("fileName", destinationFile.name)
                put("fileSize", finalSize)
                put("numChunks", config.numChunks)
                put("parallelDownload", true)
            }
        )
    }

    /**
     * Sequential fallback when the server does not support Range requests.
     */
    private suspend fun downloadSequential(
        client: OkHttpClient,
        config: Config,
        taskId: String?,
        destinationFile: File
    ): WorkerResult = withContext(Dispatchers.IO) {
        val tempFile = File("${config.savePath}.tmp")
        val existingBytes = if (config.numChunks > 0 && tempFile.exists()) tempFile.length() else 0L

        val reqBuilder = Request.Builder().url(config.url).apply {
            if (existingBytes > 0) addHeader("Range", "bytes=$existingBytes-")
            config.headers?.forEach { (k, v) -> addHeader(k, v) }
        }
        val req = config.requestSigningConfig
            ?.let { RequestSigner.sign(reqBuilder.build(), it) }
            ?: reqBuilder.build()

        try {
            client.newCall(req).execute().use { response ->
                if (response.code !in 200..299) {
                    return@withContext WorkerResult.Failure("HTTP ${response.code}", shouldRetry = response.code >= 500)
                }
                val body = response.body ?: return@withContext WorkerResult.Failure("No response body")
                val totalSize = body.contentLength()

                FileOutputStream(tempFile, existingBytes > 0 && response.code == 206).use { out ->
                    val buf = ByteArray(65_536)
                    var downloaded = existingBytes
                    body.byteStream().use { stream ->
                        var n: Int
                        while (stream.read(buf).also { n = it } != -1) {
                            out.write(buf, 0, n)
                            downloaded += n
                            // LOGIC-002: guard totalSize > 0 to avoid 0/0 when Content-Length is -1
                            val effectiveTotal = totalSize + existingBytes
                            if (taskId != null && effectiveTotal > 0) {
                                val pct = ((downloaded.toDouble() / effectiveTotal) * 100).toInt()
                                ProgressReporter.reportProgressNonBlocking(
                                    taskId, pct,
                                    "Downloading... ${formatBytes(downloaded)}/${formatBytes(totalSize + existingBytes)}"
                                )
                            }
                        }
                    }
                }

                if (config.expectedChecksum != null) {
                    val supportedAlgorithms = setOf("MD5", "SHA-1", "SHA1", "SHA-256", "SHA256", "SHA-512", "SHA512")
                    if (config.checksumAlgorithm.uppercase() !in supportedAlgorithms) {
                        tempFile.delete()
                        return@withContext WorkerResult.Failure(
                            "Unsupported checksum algorithm: '${config.checksumAlgorithm}'. " +
                            "Supported: ${supportedAlgorithms.joinToString()}",
                            shouldRetry = false
                        )
                    }
                    val actual = calculateChecksum(tempFile, config.checksumAlgorithm)
                    if (!actual.equals(config.expectedChecksum, ignoreCase = true)) {
                        tempFile.delete()
                        return@withContext WorkerResult.Failure(
                            "Checksum mismatch (expected: ${config.expectedChecksum}, actual: $actual)",
                            shouldRetry = true
                        )
                    }
                }

                destinationFile.delete()
                try {
                    java.nio.file.Files.move(
                        tempFile.toPath(),
                        destinationFile.toPath(),
                        java.nio.file.StandardCopyOption.REPLACE_EXISTING,
                        java.nio.file.StandardCopyOption.ATOMIC_MOVE
                    )
                } catch (_: java.nio.file.AtomicMoveNotSupportedException) {
                    // Atomic move not supported across filesystems — fall back to copy+delete
                    tempFile.copyTo(destinationFile, overwrite = true)
                    tempFile.delete()
                } catch (e: Exception) {
                    tempFile.delete()
                    return@withContext WorkerResult.Failure("Failed to rename file: ${e.message}")
                }

                if (taskId != null) ProgressReporter.reportProgressNonBlocking(taskId, 100, "Download complete")
                WorkerResult.Success(
                    message = "Downloaded ${destinationFile.length()} bytes (sequential fallback)",
                    data = buildJsonObject {
                        put("filePath", destinationFile.absolutePath)
                        put("fileName", destinationFile.name)
                        put("fileSize", destinationFile.length())
                        put("numChunks", 1)
                        put("parallelDownload", false)
                    }
                )
            }
        } catch (e: Exception) {
            WorkerResult.Failure(e.message ?: "Unknown error", shouldRetry = true)
        }
    }

    private fun calculateChecksum(file: File, algorithm: String): String {
        // CROSS-001: normalize short-form aliases to JCE canonical names
        val jceAlgorithm = when (algorithm.uppercase().replace("-", "")) {
            "SHA256" -> "SHA-256"
            "SHA512" -> "SHA-512"
            "SHA1"   -> "SHA-1"
            else     -> algorithm
        }
        val digest = MessageDigest.getInstance(jceAlgorithm)
        val buf = ByteArray(8192)
        file.inputStream().use { stream ->
            var n: Int
            while (stream.read(buf).also { n = it } != -1) digest.update(buf, 0, n)
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun parseStringMap(obj: org.json.JSONObject?): Map<String, String>? {
        if (obj == null) return null
        return obj.keys().asSequence().associateWith { obj.getString(it) }
    }

    private fun formatBytes(bytes: Long): String {
        return when {
            bytes >= 1_073_741_824L -> "%.1f GB".format(bytes / 1_073_741_824.0)
            bytes >= 1_048_576L -> "%.1f MB".format(bytes / 1_048_576.0)
            bytes >= 1_024L -> "%.1f KB".format(bytes / 1_024.0)
            else -> "$bytes B"
        }
    }
}
