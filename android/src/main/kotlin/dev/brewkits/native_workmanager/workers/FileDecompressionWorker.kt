package dev.brewkits.native_workmanager.workers

import android.util.Log
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
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
        private const val MAX_ENTRY_COUNT = 10_000   // FS-M-002: zip with too many entries
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

        // FIX H1: Use canonical-path validation (replaces bypassable contains("..") check)
        if (!SecurityValidator.validateFilePathSafe(config.zipPath)) {
            Log.e(TAG, "Error - Invalid or unsafe ZIP path")
            return@withContext WorkerResult.Failure("Invalid ZIP path")
        }

        if (!SecurityValidator.validateFilePathSafe(config.targetDir)) {
            Log.e(TAG, "Error - Invalid or unsafe target directory")
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
                var entryCount = 0   // FS-M-002: entry count guard

                while (entry != null) {
                    // FS-M-002: Prevent zip archives with excessive entry counts
                    entryCount++
                    if (entryCount > MAX_ENTRY_COUNT) {
                        Log.e(TAG, "Security - Entry count exceeded limit ($MAX_ENTRY_COUNT)")
                        cleanupExtractedFiles(extractedPaths)
                        return@withContext WorkerResult.Failure("Archive entry count exceeds limit ($MAX_ENTRY_COUNT)")
                    }

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

                                // ✅ SECURITY: Robust Zip Bomb Protection
                                // Check 1: Absolute Total Size Limit (2GB)
                                if (totalBytes > 2L * 1024 * 1024 * 1024) {
                                    Log.e(TAG, "Security - Total extracted size exceeded limit (2GB)")
                                    cleanupExtractedFiles(extractedPaths)
                                    destFile.delete()  // FS-H-003: delete partial current file
                                    return@withContext WorkerResult.Failure("Total extracted size too large (Zip Bomb protection)")
                                }

                                // Check 2: Dynamic Compression Ratio (Max 100:1)
                                if (entry.size > 0 && bytesWritten > entry.size * 100) {
                                    Log.e(TAG, "Security - Suspicious compression ratio detected (>100:1) for: $entryName")
                                    cleanupExtractedFiles(extractedPaths)
                                    destFile.delete()  // FS-H-003: delete partial current file
                                    return@withContext WorkerResult.Failure("Suspicious compression ratio (Zip Bomb protection)")
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
                data = buildJsonObject {
                    put("extractedFiles", extractedFiles)
                    put("extractedDirs", extractedDirs)
                    put("totalBytes", totalBytes)
                    put("targetDir", targetDir.absolutePath)
                    put("zipDeleted", config.deleteAfterExtract)
                }
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
