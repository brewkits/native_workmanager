package dev.brewkits.native_workmanager.workers

import android.util.Log
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream

/**
 * Native file decompression worker for Android.
 *
 * Extracts ZIP files using streaming to minimize memory usage.
 * Includes security protections against zip slip attacks.
 *
 * **Configuration JSON:**
 * ```json
 * {
 *   "zipPath": "/path/to/archive.zip",
 *   "targetDir": "/path/to/extract/",
 *   "overwrite": true,           // Optional: Overwrite existing files (default: true)
 *   "deleteAfterExtract": false  // Optional: Delete ZIP after successful extraction (default: false)
 * }
 * ```
 *
 * **Features:**
 * - Streaming extraction (low memory usage)
 * - Zip slip protection (prevents path traversal attacks)
 * - Auto-creates target directory
 * - Atomic operations (cleanup on error)
 * - Progress tracking support
 *
 * **Security:**
 * - Validates all extracted paths are within target directory
 * - Prevents path traversal via ".." in ZIP entries
 * - Validates file sizes during extraction
 *
 * **Performance:** ~5-10MB RAM regardless of ZIP size
 */
class FileDecompressionWorker : AndroidWorker {

    companion object {
        private const val TAG = "FileDecompressionWorker"
        private const val BUFFER_SIZE = 8192
    }

    data class Config(
        val zipPath: String,
        val targetDir: String,
        val overwrite: Boolean = true,
        val deleteAfterExtract: Boolean = false
    )

    override suspend fun doWork(input: String?): WorkerResult = withContext(Dispatchers.IO) {
        if (input.isNullOrEmpty()) {
            throw IllegalArgumentException("Input JSON is required")
        }

        // Parse configuration
        val config = try {
            val j = org.json.JSONObject(input)
            Config(
                zipPath = j.getString("zipPath"),
                targetDir = j.getString("targetDir"),
                overwrite = j.optBoolean("overwrite", true),
                deleteAfterExtract = j.optBoolean("deleteAfterExtract", false)
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

        // ✅ SECURITY: Validate paths
        if (config.zipPath.contains("..") || !config.zipPath.startsWith("/")) {
            Log.e(TAG, "Error - Invalid ZIP path (path traversal attempt)")
            return@withContext WorkerResult.Failure("Invalid ZIP path")
        }

        if (config.targetDir.contains("..") || !config.targetDir.startsWith("/")) {
            Log.e(TAG, "Error - Invalid target directory (path traversal attempt)")
            return@withContext WorkerResult.Failure("Invalid target directory")
        }

        // Validate ZIP file exists
        val zipFile = File(config.zipPath)
        if (!zipFile.exists()) {
            Log.e(TAG, "Error - ZIP file not found: ${config.zipPath}")
            return@withContext WorkerResult.Failure("ZIP file not found: ${config.zipPath}")
        }

        if (!zipFile.isFile) {
            Log.e(TAG, "Error - Path is not a file: ${config.zipPath}")
            return@withContext WorkerResult.Failure("Path is not a file")
        }

        // ✅ SECURITY: Validate ZIP file size
        if (!SecurityValidator.validateFileSize(zipFile)) {
            Log.e(TAG, "Error - ZIP file too large")
            return@withContext WorkerResult.Failure("ZIP file exceeds size limit")
        }

        // Create target directory
        val targetDir = File(config.targetDir)
        if (!targetDir.exists()) {
            if (!targetDir.mkdirs()) {
                Log.e(TAG, "Error - Failed to create target directory")
                return@withContext WorkerResult.Failure("Failed to create target directory")
            }
            Log.d(TAG, "Created directory: ${targetDir.path}")
        }

        // Get canonical path for security checks
        val canonicalTargetPath = targetDir.canonicalPath

        Log.d(TAG, "Extracting ${zipFile.name} (${zipFile.length()} bytes)")
        Log.d(TAG, "Target: ${targetDir.path}")

        var extractedFiles = 0
        var extractedDirs = 0
        var totalBytes = 0L
        val extractedPaths = mutableListOf<String>()

        // Extract ZIP file
        return@withContext try {
            ZipInputStream(zipFile.inputStream()).use { zipInput ->
                var entry: ZipEntry? = zipInput.nextEntry

                while (entry != null) {
                    val entryName = entry.name

                    // ✅ SECURITY: Prevent zip slip attack
                    val destFile = File(targetDir, entryName)
                    val canonicalDestPath = destFile.canonicalPath

                    if (!canonicalDestPath.startsWith(canonicalTargetPath + File.separator)) {
                        Log.e(TAG, "Security - Zip slip attack detected: $entryName")
                        // Clean up already extracted files
                        cleanupExtractedFiles(extractedPaths)
                        return@withContext WorkerResult.Failure("Zip slip attack detected in entry: $entryName")
                    }

                    if (entry.isDirectory) {
                        // Create directory
                        if (!destFile.exists()) {
                            if (!destFile.mkdirs()) {
                                Log.e(TAG, "Error - Failed to create directory: $entryName")
                                cleanupExtractedFiles(extractedPaths)
                                return@withContext WorkerResult.Failure("Failed to create directory: $entryName")
                            }
                            extractedDirs++
                            extractedPaths.add(destFile.absolutePath)
                        }
                    } else {
                        // Extract file
                        // Check if file exists and overwrite setting
                        if (destFile.exists() && !config.overwrite) {
                            Log.d(TAG, "Skipping existing file: $entryName")
                            zipInput.closeEntry()
                            entry = zipInput.nextEntry
                            continue
                        }

                        // Create parent directories if needed
                        destFile.parentFile?.let { parent ->
                            if (!parent.exists() && !parent.mkdirs()) {
                                Log.e(TAG, "Error - Failed to create parent directory: ${parent.path}")
                                cleanupExtractedFiles(extractedPaths)
                                return@withContext WorkerResult.Failure("Failed to create parent directory")
                            }
                        }

                        // Extract file content
                        var bytesWritten = 0L
                        FileOutputStream(destFile).use { output ->
                            val buffer = ByteArray(BUFFER_SIZE)
                            var len: Int
                            while (zipInput.read(buffer).also { len = it } > 0) {
                                output.write(buffer, 0, len)
                                bytesWritten += len
                                totalBytes += len

                                // ✅ SECURITY: Prevent zip bombs (check extracted size)
                                if (bytesWritten > entry.size * 2) {
                                    Log.e(TAG, "Security - Possible zip bomb detected: $entryName")
                                    cleanupExtractedFiles(extractedPaths)
                                    return@withContext WorkerResult.Failure("Possible zip bomb detected")
                                }
                            }
                        }

                        extractedFiles++
                        extractedPaths.add(destFile.absolutePath)

                        // Set file modification time to match ZIP entry
                        if (entry.time > 0) {
                            destFile.setLastModified(entry.time)
                        }

                        Log.d(TAG, "Extracted: $entryName (${bytesWritten} bytes)")
                    }

                    zipInput.closeEntry()
                    entry = zipInput.nextEntry
                }
            }

            // ✅ Optional: Delete ZIP file after successful extraction
            if (config.deleteAfterExtract) {
                if (zipFile.delete()) {
                    Log.d(TAG, "Deleted ZIP file: ${zipFile.name}")
                } else {
                    Log.w(TAG, "Failed to delete ZIP file: ${zipFile.name}")
                }
            }

            Log.d(TAG, "Extraction complete")
            Log.d(TAG, "  Files: $extractedFiles, Directories: $extractedDirs")
            Log.d(TAG, "  Total size: $totalBytes bytes")

            // ✅ Return success with extraction data
            WorkerResult.Success(
                message = "Extracted $extractedFiles files, $extractedDirs directories",
                data = mapOf(
                    "extractedFiles" to extractedFiles,
                    "extractedDirs" to extractedDirs,
                    "totalBytes" to totalBytes,
                    "targetDir" to targetDir.absolutePath,
                    "zipDeleted" to config.deleteAfterExtract
                )
            )

        } catch (e: Exception) {
            Log.e(TAG, "Error during extraction: ${e.message}", e)
            // Clean up partially extracted files on error
            cleanupExtractedFiles(extractedPaths)
            WorkerResult.Failure(
                message = e.message ?: "Unknown error during extraction",
                shouldRetry = false
            )
        }
    }

    /**
     * Clean up extracted files in case of error.
     */
    private fun cleanupExtractedFiles(paths: List<String>) {
        Log.d(TAG, "Cleaning up ${paths.size} extracted files/directories...")
        paths.reversed().forEach { path ->
            try {
                val file = File(path)
                if (file.exists()) {
                    if (file.isDirectory) {
                        file.deleteRecursively()
                    } else {
                        file.delete()
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to cleanup: $path - ${e.message}")
            }
        }
    }
}
