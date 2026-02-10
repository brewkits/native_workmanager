package dev.brewkits.native_workmanager.workers

import android.util.Log
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.workers.utils.ProgressReporter
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicInteger
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/**
 * Built-in worker: File compression (ZIP format)
 *
 * Compresses files or directories into ZIP archives in the background.
 * Perfect for log file archiving, backup preparation, or reducing upload sizes.
 *
 * Usage from Dart:
 * ```dart
 * await NativeWorkManager.enqueue(
 *   taskId: 'compress-logs',
 *   trigger: TaskTrigger.oneTime(),
 *   worker: NativeWorker.fileCompress(
 *     inputPath: '/app/logs/',
 *     outputPath: '/app/archive/logs_2026-02-05.zip',
 *     level: CompressionLevel.high,
 *     deleteOriginal: true,
 *   ),
 * );
 * ```
 *
 * Input JSON schema:
 * {
 *   "inputPath": "/path/to/file/or/directory",     // Required
 *   "outputPath": "/path/to/output.zip",           // Required
 *   "compressionLevel": "medium",                  // Optional: low, medium, high
 *   "excludePatterns": ["*.tmp", ".DS_Store"],     // Optional: exclude patterns
 *   "deleteOriginal": false,                       // Optional: delete source after compression
 * }
 */
class FileCompressionWorker : AndroidWorker {
    companion object {
        private const val TAG = "FileCompressionWorker"
        private const val BUFFER_SIZE = 8192

        // Compression levels mapped to Java constants
        private const val COMPRESSION_LOW = 3
        private const val COMPRESSION_MEDIUM = 6
        private const val COMPRESSION_HIGH = 9
    }

    override suspend fun doWork(input: String?): WorkerResult {
        return try {
            Log.d(TAG, "Starting file compression...")

            // ════════════════════════════════════════════════════════════
            // STEP 1: Parse and validate input
            // ════════════════════════════════════════════════════════════
            if (input.isNullOrEmpty()) {
                Log.e(TAG, "Input is null or empty")
                return WorkerResult.Failure("Input is null or empty")
            }

            val config = JSONObject(input)
            val taskId = config.optString("__taskId", null) // Injected by plugin for progress reporting
            val inputPath = config.optString("inputPath", "")
            val outputPath = config.optString("outputPath", "")
            val compressionLevel = config.optString("compressionLevel", "medium")
            val deleteOriginal = config.optBoolean("deleteOriginal", false)

            // Parse exclude patterns
            val excludePatterns = mutableListOf<String>()
            if (config.has("excludePatterns")) {
                val patternsArray = config.getJSONArray("excludePatterns")
                for (i in 0 until patternsArray.length()) {
                    excludePatterns.add(patternsArray.getString(i))
                }
            }

            // ════════════════════════════════════════════════════════════
            // STEP 2: Validate required parameters
            // ════════════════════════════════════════════════════════════
            if (inputPath.isEmpty()) {
                Log.e(TAG, "Missing required parameter: inputPath")
                return WorkerResult.Failure("Missing required parameter: inputPath")
            }

            if (outputPath.isEmpty()) {
                Log.e(TAG, "Missing required parameter: outputPath")
                return WorkerResult.Failure("Missing required parameter: outputPath")
            }

            // Check input exists
            val inputFile = File(inputPath)
            if (!inputFile.exists()) {
                Log.e(TAG, "Input file/directory does not exist: $inputPath")
                return WorkerResult.Failure("Input file/directory does not exist: $inputPath")
            }

            // Check output path is valid
            if (!outputPath.endsWith(".zip", ignoreCase = true)) {
                Log.e(TAG, "Output path must end with .zip: $outputPath")
                return WorkerResult.Failure("Output path must end with .zip: $outputPath")
            }

            // ════════════════════════════════════════════════════════════
            // STEP 3: Create output directory if needed
            // ════════════════════════════════════════════════════════════
            val outputFile = File(outputPath)
            outputFile.parentFile?.mkdirs()

            // Delete existing output file if exists
            if (outputFile.exists()) {
                Log.d(TAG, "Removing existing output file: $outputPath")
                outputFile.delete()
            }

            // ════════════════════════════════════════════════════════════
            // STEP 4: Map compression level
            // ════════════════════════════════════════════════════════════
            val zipCompressionLevel = when (compressionLevel.lowercase()) {
                "low" -> COMPRESSION_LOW
                "high" -> COMPRESSION_HIGH
                else -> COMPRESSION_MEDIUM // Default
            }

            Log.d(TAG, "Compression level: $compressionLevel ($zipCompressionLevel)")

            // ════════════════════════════════════════════════════════════
            // STEP 5: Count total files for progress tracking
            // ════════════════════════════════════════════════════════════
            val totalFiles = countFiles(inputFile, excludePatterns)

            // ✅ FIX #3: Use AtomicInteger to prevent memory leak in recursive calls
            val filesProcessed = AtomicInteger(0)

            // Report initial progress
            if (taskId != null) {
                runBlocking {
                    ProgressReporter.reportProgress(
                        taskId = taskId,
                        progress = 0,
                        message = "Starting compression...",
                        currentStep = 0,
                        totalSteps = totalFiles
                    )
                }
            }

            // ════════════════════════════════════════════════════════════
            // STEP 6: Compress files with progress reporting
            // ════════════════════════════════════════════════════════════
            var filesCompressed = 0
            var totalBytes = 0L

            ZipOutputStream(FileOutputStream(outputFile)).use { zipOut ->
                zipOut.setLevel(zipCompressionLevel)

                if (inputFile.isDirectory) {
                    // Compress directory recursively with progress
                    filesCompressed = compressDirectory(
                        zipOut = zipOut,
                        directory = inputFile,
                        basePath = inputFile.name,
                        excludePatterns = excludePatterns,
                        taskId = taskId,
                        totalFiles = totalFiles,
                        filesProcessedCounter = filesProcessed  // ✅ Pass AtomicInteger
                    )
                } else {
                    // Compress single file
                    if (!shouldExclude(inputFile.name, excludePatterns)) {
                        compressFile(zipOut, inputFile, inputFile.name)
                        filesCompressed = 1
                        filesProcessed.set(1)

                        // Report progress
                        if (taskId != null) {
                            runBlocking {
                                ProgressReporter.reportProgress(
                                    taskId = taskId,
                                    progress = 100,
                                    message = "Compression complete",
                                    currentStep = 1,
                                    totalSteps = 1
                                )
                            }
                        }
                    }
                }

                zipOut.finish()
            }

            // Report final progress
            if (taskId != null) {
                runBlocking {
                    ProgressReporter.reportProgress(
                        taskId = taskId,
                        progress = 100,
                        message = "Compression complete",
                        currentStep = filesProcessed.get(),
                        totalSteps = totalFiles
                    )
                }
            }

            // ════════════════════════════════════════════════════════════
            // STEP 6: Verify output
            // ════════════════════════════════════════════════════════════
            if (!outputFile.exists() || outputFile.length() == 0L) {
                Log.e(TAG, "Compression failed: output file is empty or missing")
                return WorkerResult.Failure("Compression failed: output file is empty or missing")
            }

            // ✅ SECURITY: Validate archive size (prevent creating huge archives)
            if (!SecurityValidator.validateArchiveSize(outputFile)) {
                Log.e(TAG, "Error - Compressed archive exceeds size limit")
                outputFile.delete() // Clean up
                return WorkerResult.Failure("Compressed archive exceeds size limit")
            }

            val originalSize = calculateSize(inputFile)
            val compressedSize = outputFile.length()
            val compressionRatio = (compressedSize.toFloat() / originalSize.toFloat() * 100).toInt()

            Log.d(TAG, "Compression successful:")
            Log.d(TAG, "  Files: $filesCompressed")
            Log.d(TAG, "  Original: ${formatBytes(originalSize)}")
            Log.d(TAG, "  Compressed: ${formatBytes(compressedSize)}")
            Log.d(TAG, "  Ratio: $compressionRatio%")

            // ════════════════════════════════════════════════════════════
            // STEP 7: Delete original if requested
            // ════════════════════════════════════════════════════════════
            if (deleteOriginal) {
                Log.d(TAG, "Deleting original: $inputPath")
                if (inputFile.isDirectory) {
                    inputFile.deleteRecursively()
                } else {
                    inputFile.delete()
                }
            }

            // ✅ Return success with compression data
            WorkerResult.Success(
                message = "Compressed $filesCompressed files ($compressionRatio% ratio)",
                data = mapOf(
                    "filesCompressed" to filesCompressed,
                    "originalSize" to originalSize,
                    "compressedSize" to compressedSize,
                    "compressionRatio" to compressionRatio,
                    "outputPath" to outputPath
                )
            )

        } catch (e: Exception) {
            Log.e(TAG, "File compression failed", e)
            return WorkerResult.Failure(
                message = e.message ?: "Unknown error",
                shouldRetry = true
            )
        }
    }

    /**
     * Count total files to compress (for progress tracking).
     */
    private fun countFiles(file: File, excludePatterns: List<String>): Int {
        if (shouldExclude(file.name, excludePatterns)) return 0

        return if (file.isDirectory) {
            file.listFiles()?.sumOf { countFiles(it, excludePatterns) } ?: 0
        } else {
            1
        }
    }

    /**
     * Compress a directory recursively with progress reporting.
     *
     * ✅ FIX #3: Uses AtomicInteger for thread-safe counter without memory leak.
     */
    private fun compressDirectory(
        zipOut: ZipOutputStream,
        directory: File,
        basePath: String,
        excludePatterns: List<String>,
        taskId: String?,
        totalFiles: Int,
        filesProcessedCounter: AtomicInteger
    ): Int {
        var count = 0

        directory.listFiles()?.forEach { file ->
            if (shouldExclude(file.name, excludePatterns)) {
                Log.d(TAG, "Excluding: ${file.name}")
                return@forEach
            }

            val entryName = if (basePath.isEmpty()) {
                file.name
            } else {
                "$basePath/${file.name}"
            }

            if (file.isDirectory) {
                // Add directory entry
                zipOut.putNextEntry(ZipEntry("$entryName/"))
                zipOut.closeEntry()

                // Recurse into subdirectory
                count += compressDirectory(
                    zipOut = zipOut,
                    directory = file,
                    basePath = entryName,
                    excludePatterns = excludePatterns,
                    taskId = taskId,
                    totalFiles = totalFiles,
                    filesProcessedCounter = filesProcessedCounter  // ✅ Pass same counter
                )
            } else {
                // Add file
                compressFile(zipOut, file, entryName)
                count++

                // ✅ FIX #3: Thread-safe increment without lambda capture
                val processed = filesProcessedCounter.incrementAndGet()

                // Report progress
                if (taskId != null && totalFiles > 0) {
                    val progress = ((processed.toFloat() / totalFiles.toFloat()) * 100).toInt()

                    runBlocking {
                        ProgressReporter.reportProgress(
                            taskId = taskId,
                            progress = progress,
                            message = "Compressing: ${file.name}",
                            currentStep = processed,
                            totalSteps = totalFiles
                        )
                    }
                }
            }
        }

        return count
    }

    /**
     * Compress a single file into the ZIP stream
     */
    private fun compressFile(zipOut: ZipOutputStream, file: File, entryName: String) {
        BufferedInputStream(FileInputStream(file), BUFFER_SIZE).use { bis ->
            val entry = ZipEntry(entryName)
            entry.time = file.lastModified()
            zipOut.putNextEntry(entry)

            val buffer = ByteArray(BUFFER_SIZE)
            var length: Int
            while (bis.read(buffer).also { length = it } != -1) {
                zipOut.write(buffer, 0, length)
            }

            zipOut.closeEntry()
        }
    }

    /**
     * Check if file should be excluded based on patterns
     */
    private fun shouldExclude(fileName: String, patterns: List<String>): Boolean {
        return patterns.any { pattern ->
            when {
                pattern.startsWith("*.") -> {
                    // Extension pattern: *.tmp
                    val extension = pattern.substring(1)
                    fileName.endsWith(extension, ignoreCase = true)
                }
                pattern.startsWith("*") -> {
                    // Suffix pattern: *backup
                    val suffix = pattern.substring(1)
                    fileName.endsWith(suffix, ignoreCase = true)
                }
                pattern.endsWith("*") -> {
                    // Prefix pattern: temp*
                    val prefix = pattern.substring(0, pattern.length - 1)
                    fileName.startsWith(prefix, ignoreCase = true)
                }
                else -> {
                    // Exact match
                    fileName.equals(pattern, ignoreCase = true)
                }
            }
        }
    }

    /**
     * Calculate total size of file or directory
     */
    private fun calculateSize(file: File): Long {
        return if (file.isDirectory) {
            file.walkTopDown().filter { it.isFile }.map { it.length() }.sum()
        } else {
            file.length()
        }
    }

    /**
     * Format bytes to human-readable string
     */
    private fun formatBytes(bytes: Long): String {
        return when {
            bytes < 1024 -> "$bytes B"
            bytes < 1024 * 1024 -> "${bytes / 1024} KB"
            bytes < 1024 * 1024 * 1024 -> "${bytes / (1024 * 1024)} MB"
            else -> "${bytes / (1024 * 1024 * 1024)} GB"
        }
    }
}
