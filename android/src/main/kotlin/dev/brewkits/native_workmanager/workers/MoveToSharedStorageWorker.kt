package dev.brewkits.native_workmanager.workers

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Worker that moves/copies a file from app-private storage to a shared public location.
 *
 * On Android API 29+ uses MediaStore. On API 28– uses the legacy
 * Environment.getExternalStoragePublicDirectory() API.
 *
 * **Configuration JSON:**
 * ```json
 * {
 *   "sourcePath": "/data/user/0/com.example/cache/photo.jpg",
 *   "storageType": "photos",    // downloads | photos | music | video
 *   "fileName": "photo.jpg",    // Optional: override filename
 *   "mimeType": "image/jpeg",   // Optional: MIME hint for MediaStore
 *   "subDir": "MyApp"           // Optional: subdirectory within the collection
 * }
 * ```
 */
class MoveToSharedStorageWorker(private val context: Context) : AndroidWorker {

    companion object {
        private const val TAG = "MoveToSharedStorageWorker"
    }

    data class Config(
        val sourcePath: String,
        val storageType: String,    // "downloads" | "photos" | "music" | "video"
        val fileName: String,
        val mimeType: String,
        val subDir: String?
    )

    override suspend fun doWork(input: String?): WorkerResult = withContext(Dispatchers.IO) {
        if (input.isNullOrEmpty()) {
            return@withContext WorkerResult.Failure("Input JSON is required")
        }

        val config = try {
            val j = org.json.JSONObject(input)
            val sourcePath = j.getString("sourcePath")
            val storageType = j.optString("storageType", "downloads").lowercase()
            val sourceFile = File(sourcePath)
            val defaultName = sourceFile.name.takeIf { it.isNotEmpty() } ?: "file"
            Config(
                sourcePath = sourcePath,
                storageType = storageType,
                fileName = j.optString("fileName", defaultName).takeIf { it.isNotEmpty() } ?: defaultName,
                mimeType = j.optString("mimeType", "").ifEmpty { guessMimeType(sourceFile.extension) },
                subDir = if (j.has("subDir")) j.optString("subDir").ifEmpty { null } else null
            )
        } catch (e: Exception) {
            return@withContext WorkerResult.Failure("Invalid config: ${e.message}")
        }

        val sourceFile = File(config.sourcePath)
        if (!sourceFile.exists()) {
            return@withContext WorkerResult.Failure("Source file not found: ${config.sourcePath}")
        }

        if (!SecurityValidator.validateFilePathSafe(config.sourcePath)) {
            return@withContext WorkerResult.Failure("Invalid or unsafe source path")
        }

        return@withContext if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            moveViaMediaStore(config, sourceFile)
        } else {
            moveLegacy(config, sourceFile)
        }
    }

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.Q)
    private fun moveViaMediaStore(config: Config, sourceFile: File): WorkerResult {
        val collection: Uri = when (config.storageType) {
            "photos" -> MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            "music" -> MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            "video" -> MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            else -> MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }

        val relativePath = buildRelativePath(config.storageType, config.subDir)

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, config.fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, config.mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val resolver = context.contentResolver
        val itemUri = resolver.insert(collection, values)
            ?: return WorkerResult.Failure("MediaStore.insert returned null")

        return try {
            // MEDIA-013: openOutputStream can return null (e.g. permission denied after insert).
            val outputStream = resolver.openOutputStream(itemUri)
                ?: run {
                    resolver.delete(itemUri, null, null)
                    return WorkerResult.Failure("MediaStore.openOutputStream returned null")
                }
            outputStream.use { output ->
                sourceFile.inputStream().use { it.copyTo(output) }
            }

            // Mark as complete
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(itemUri, values, null, null)

            Log.d(TAG, "MediaStore insert success: $itemUri")
            WorkerResult.Success(
                message = "Saved to shared storage",
                data = buildJsonObject {
                    put("uri", itemUri.toString())
                    put("fileName", config.fileName)
                    put("storageType", config.storageType)
                    if (config.mimeType != null) put("mimeType", config.mimeType)
                }
            )
        } catch (e: Exception) {
            resolver.delete(itemUri, null, null)
            Log.e(TAG, "MediaStore write failed: ${e.message}", e)
            WorkerResult.Failure("Failed to write to shared storage: ${e.message}")
        }
    }

    @Suppress("DEPRECATION")
    private fun moveLegacy(config: Config, sourceFile: File): WorkerResult {
        val publicDir = when (config.storageType) {
            "photos" -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            "music" -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC)
            "video" -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
            else -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        }

        val subDirCreated = config.subDir != null
        val destDir = if (config.subDir != null) File(publicDir, config.subDir) else publicDir
        if (!destDir.exists() && !destDir.mkdirs()) {
            return WorkerResult.Failure("Failed to create destination directory: ${destDir.path}")
        }

        val destFile = File(destDir, config.fileName)
        return try {
            sourceFile.copyTo(destFile, overwrite = true)
            Log.d(TAG, "Legacy copy success: ${destFile.absolutePath}")
            WorkerResult.Success(
                message = "Saved to shared storage (legacy)",
                data = buildJsonObject {
                    put("filePath", destFile.absolutePath)
                    put("fileName", config.fileName)
                    put("storageType", config.storageType)
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "Legacy copy failed: ${e.message}", e)
            // NET-017: clean up the directory we may have created so we don't leave
            // orphaned empty directories if copyTo() fails.
            if (subDirCreated && destDir.exists() && destDir.listFiles()?.isEmpty() == true) {
                destDir.delete()
                Log.d(TAG, "Cleaned up empty directory: ${destDir.path}")
            }
            WorkerResult.Failure("Failed to copy file: ${e.message}")
        }
    }

    private fun buildRelativePath(storageType: String, subDir: String?): String {
        val base = when (storageType) {
            "photos" -> Environment.DIRECTORY_PICTURES
            "music" -> Environment.DIRECTORY_MUSIC
            "video" -> Environment.DIRECTORY_MOVIES
            else -> Environment.DIRECTORY_DOWNLOADS
        }
        return if (subDir != null) "$base/$subDir/" else "$base/"
    }

    private fun guessMimeType(extension: String): String = when (extension.lowercase()) {
        "jpg", "jpeg" -> "image/jpeg"
        "png" -> "image/png"
        "gif" -> "image/gif"
        "webp" -> "image/webp"
        "heic", "heif" -> "image/heic"
        "mp4" -> "video/mp4"
        "mov" -> "video/quicktime"
        "avi" -> "video/avi"
        "mp3" -> "audio/mpeg"
        "aac" -> "audio/aac"
        "wav" -> "audio/wav"
        "pdf" -> "application/pdf"
        "zip" -> "application/zip"
        else -> "application/octet-stream"
    }
}
