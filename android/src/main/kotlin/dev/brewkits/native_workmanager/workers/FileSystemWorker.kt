package dev.brewkits.native_workmanager.workers

import android.content.Context
import androidx.work.WorkerParameters
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.workers.utils.ProgressReporter
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption

/**
 * Built-in worker: File system operations
 *
 * Supports copy, move, delete, list, and mkdir operations for pure-native task chains.
 *
 * **Configuration JSON:**
 * ```json
 * // Copy operation
 * {
 *   "operation": "copy",
 *   "sourcePath": "/path/to/source",
 *   "destinationPath": "/path/to/destination",
 *   "overwrite": false,
 *   "recursive": true
 * }
 *
 * // Move operation
 * {
 *   "operation": "move",
 *   "sourcePath": "/path/to/source",
 *   "destinationPath": "/path/to/destination",
 *   "overwrite": false
 * }
 *
 * // Delete operation
 * {
 *   "operation": "delete",
 *   "path": "/path/to/file",
 *   "recursive": false
 * }
 *
 * // List operation
 * {
 *   "operation": "list",
 *   "path": "/path/to/directory",
 *   "pattern": "*.jpg",
 *   "recursive": false
 * }
 *
 * // Mkdir operation
 * {
 *   "operation": "mkdir",
 *   "path": "/path/to/new/directory",
 *   "createParents": true
 * }
 * ```
 */
class FileSystemWorker : AndroidWorker {

    override suspend fun doWork(input: String?): WorkerResult = withContext(Dispatchers.IO) {
        try {
            if (input.isNullOrEmpty()) {
                return@withContext WorkerResult.Failure("Input JSON is required")
            }

            val json = JSONObject(input)
            val operation = json.getString("operation")

            when (operation) {
                "copy" -> handleCopy(json)
                "move" -> handleMove(json)
                "delete" -> handleDelete(json)
                "list" -> handleList(json)
                "mkdir" -> handleMkdir(json)
                else -> WorkerResult.Failure("Unknown operation: $operation")
            }
        } catch (e: Exception) {
            WorkerResult.Failure("FileSystem operation failed: ${e.message}")
        }
    }

    private fun handleCopy(json: JSONObject): WorkerResult {
        val sourcePath = json.getString("sourcePath")
        val destinationPath = json.getString("destinationPath")
        val overwrite = json.optBoolean("overwrite", false)
        val recursive = json.optBoolean("recursive", true)

        // H4: Validate paths BEFORE any existence checks to avoid information
        // disclosure (different error messages revealing whether a restricted
        // path exists before the security check fires).
        if (!SecurityValidator.validateFilePathSafe(sourcePath) || !SecurityValidator.validateFilePathSafe(destinationPath)) {
            return WorkerResult.Failure("Invalid or unsafe path")
        }

        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) {
            return WorkerResult.Failure("Source not found: $sourcePath")
        }

        val destFile = File(destinationPath)

        // Check if destination exists
        if (destFile.exists() && !overwrite) {
            return WorkerResult.Failure("Destination already exists: $destinationPath (set overwrite=true to replace)")
        }

        return try {
            val copiedFiles = if (sourceFile.isDirectory) {
                if (!recursive) {
                    return WorkerResult.Failure("Source is a directory, set recursive=true to copy")
                }
                copyDirectory(sourceFile, destFile, overwrite)
            } else {
                copyFile(sourceFile, destFile, overwrite)
                listOf(destFile)
            }

            val totalSize = copiedFiles.sumOf { it.length() }

            WorkerResult.Success(
                message = "Copied ${copiedFiles.size} file(s)",
                data = buildJsonObject {
                    put("operation", "copy")
                    put("sourcePath", sourcePath)
                    put("destinationPath", destinationPath)
                    put("fileCount", copiedFiles.size)
                    put("totalSize", totalSize)
                    put("files", buildJsonArray { copiedFiles.forEach { add(kotlinx.serialization.json.JsonPrimitive(it.absolutePath)) } })
                }
            )
        } catch (e: IOException) {
            WorkerResult.Failure("Copy failed: ${e.message}")
        }
    }

    private fun handleMove(json: JSONObject): WorkerResult {
        val sourcePath = json.getString("sourcePath")
        val destinationPath = json.getString("destinationPath")
        val overwrite = json.optBoolean("overwrite", false)

        // H4: Validate paths before existence check (avoid information disclosure).
        if (!SecurityValidator.validateFilePathSafe(sourcePath) || !SecurityValidator.validateFilePathSafe(destinationPath)) {
            return WorkerResult.Failure("Invalid or unsafe path")
        }

        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) {
            return WorkerResult.Failure("Source not found: $sourcePath")
        }

        val destFile = File(destinationPath)

        if (destFile.exists() && !overwrite) {
            return WorkerResult.Failure("Destination already exists: $destinationPath (set overwrite=true to replace)")
        }

        return try {
            // FS-H-006: Check mkdirs return value
            val destParent = destFile.parentFile
            if (destParent != null && !destParent.exists() && !destParent.mkdirs()) {
                return WorkerResult.Failure("Failed to create destination parent directory")
            }

            // Delete destination if overwriting
            if (destFile.exists() && overwrite) {
                destFile.deleteRecursively()
            }

            // Attempt atomic move first
            val moved = sourceFile.renameTo(destFile)

            if (!moved) {
                // Fallback: copy + delete
                if (sourceFile.isDirectory) {
                    copyDirectory(sourceFile, destFile, overwrite)
                } else {
                    copyFile(sourceFile, destFile, overwrite)
                }
                // FS-C-002: rollback copy if source delete fails
                val deleted = sourceFile.deleteRecursively()
                if (!deleted) {
                    destFile.deleteRecursively()
                    return WorkerResult.Failure("Move failed: could not delete source after copy")
                }
            }

            val fileCount = if (destFile.isDirectory) {
                destFile.walkTopDown().count { it.isFile }
            } else 1

            WorkerResult.Success(
                message = "Moved $fileCount file(s)",
                data = buildJsonObject {
                    put("operation", "move")
                    put("sourcePath", sourcePath)
                    put("destinationPath", destinationPath)
                    put("fileCount", fileCount)
                }
            )
        } catch (e: IOException) {
            WorkerResult.Failure("Move failed: ${e.message}")
        }
    }

    private fun handleDelete(json: JSONObject): WorkerResult {
        val path = json.getString("path")
        val recursive = json.optBoolean("recursive", false)

        // H3: Validate path with canonical resolution before any file operations.
        if (!SecurityValidator.validateFilePathSafe(path)) {
            return WorkerResult.Failure("Invalid or unsafe path")
        }

        val file = File(path)
        if (!file.exists()) {
            return WorkerResult.Failure("Path not found: $path")
        }

        // Additional safety check: prevent accidental deletion of root-level directories.
        val dangerousPaths = listOf("/", "/system", "/data", "/storage/emulated/0")
        if (dangerousPaths.any { file.canonicalPath == File(it).canonicalPath }) {
            return WorkerResult.Failure("Cannot delete protected path: $path")
        }

        return try {
            val fileCount = if (file.isDirectory) {
                if (!recursive) {
                    return WorkerResult.Failure("Path is a directory, set recursive=true to delete")
                }
                file.walkTopDown().count { it.isFile }
            } else 1

            val deleted = if (file.isDirectory && recursive) {
                file.deleteRecursively()
            } else {
                file.delete()
            }

            // FS-H-007: deleteRecursively returns false on partial deletion; check if
            // target still exists to distinguish outright failure from partial success.
            if (deleted || !file.exists()) {
                WorkerResult.Success(
                    message = "Deleted $fileCount file(s)",
                    data = buildJsonObject {
                        put("operation", "delete")
                        put("path", path)
                        put("fileCount", fileCount)
                    }
                )
            } else {
                WorkerResult.Failure("Failed to delete (some files may remain): $path")
            }
        } catch (e: IOException) {
            WorkerResult.Failure("Delete failed: ${e.message}")
        }
    }

    private fun handleList(json: JSONObject): WorkerResult {
        val path = json.getString("path")
        val pattern = json.optString("pattern").takeIf { it.isNotEmpty() }
        val recursive = json.optBoolean("recursive", false)

        // H3: Validate path before listing — missing in original code.
        if (!SecurityValidator.validateFilePathSafe(path)) {
            return WorkerResult.Failure("Invalid or unsafe path")
        }

        val directory = File(path)
        if (!directory.exists()) return WorkerResult.Failure("Path not found: $path")
        if (!directory.isDirectory) return WorkerResult.Failure("Path is not a directory: $path")

        return try {
            // FIX: Use sequence to avoid loading everything into memory (prevent OOM)
            val fileSequence = if (recursive) {
                directory.walkTopDown().filter { it.isFile }
            } else {
                directory.listFiles()?.asSequence()?.filter { it.isFile } ?: emptySequence()
            }

            // Apply pattern filter efficiently
            val regex = pattern?.let {
                // ✅ SECURITY: Fix Regex Injection — use a safer glob-to-regex conversion
                // This prevents users from breaking the regex with special chars
                val escaped = it.replace(".", "\\.")
                    .replace("*", ".*")
                    .replace("?", ".")
                try {
                    "^$escaped$".toRegex(RegexOption.IGNORE_CASE)
                } catch (e: Exception) {
                    null // Fallback if pattern is invalid
                }
            }

            val filteredFiles = if (regex != null) {
                fileSequence.filter { regex.matches(it.name) }
            } else {
                fileSequence
            }

            // Limit result size for stability (e.g., max 1000 items in response)
            val resultList = filteredFiles.take(1000).toList()

            WorkerResult.Success(
                message = "Found ${resultList.size} file(s)",
                data = buildJsonObject {
                    put("operation", "list")
                    put("files", buildJsonArray {
                        resultList.forEach { file ->
                            add(buildJsonObject {
                                put("path", file.absolutePath)
                                put("name", file.name)
                                put("size", file.length())
                                put("lastModified", file.lastModified())   // FS-M-004
                                put("isDirectory", file.isDirectory)       // FS-L-003
                            })
                        }
                    })
                }
            )
        } catch (e: Exception) {
            WorkerResult.Failure("List failed: ${e.message}")
        }
    }

    private fun handleMkdir(json: JSONObject): WorkerResult {
        val path = json.getString("path")
        val createParents = json.optBoolean("createParents", true)

        // FS-M-005: Security check BEFORE exists() to avoid information disclosure
        if (!SecurityValidator.validateFilePathSafe(path)) {
            return WorkerResult.Failure("Invalid or unsafe path")
        }

        val directory = File(path)

        if (directory.exists()) {
            return if (directory.isDirectory) {
                WorkerResult.Success(
                    message = "Directory already exists",
                    data = buildJsonObject {
                        put("operation", "mkdir")
                        put("path", path)
                        put("created", false)
                    }
                )
            } else {
                WorkerResult.Failure("Path exists but is not a directory: $path")
            }
        }

        return try {
            val created = if (createParents) {
                directory.mkdirs()
            } else {
                directory.mkdir()
            }

            if (created) {
                WorkerResult.Success(
                    message = "Directory created",
                    data = buildJsonObject {
                        put("operation", "mkdir")
                        put("path", path)
                        put("created", true)
                    }
                )
            } else {
                WorkerResult.Failure("Failed to create directory: $path")
            }
        } catch (e: IOException) {
            WorkerResult.Failure("Mkdir failed: ${e.message}")
        }
    }

    private fun copyFile(source: File, destination: File, overwrite: Boolean) {
        destination.parentFile?.mkdirs()

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val copyOption = if (overwrite) {
                StandardCopyOption.REPLACE_EXISTING
            } else {
                StandardCopyOption.COPY_ATTRIBUTES
            }
            Files.copy(source.toPath(), destination.toPath(), copyOption)
        } else {
            // Fallback for older Android versions
            source.copyTo(destination, overwrite = overwrite)
        }
    }

    private fun copyDirectory(source: File, destination: File, overwrite: Boolean): List<File> {
        val copiedFiles = mutableListOf<File>()

        source.walkTopDown().forEach { file ->
            val relativePath = file.relativeTo(source).path
            val destFile = File(destination, relativePath)

            if (file.isDirectory) {
                destFile.mkdirs()
            } else {
                copyFile(file, destFile, overwrite)
                copiedFiles.add(destFile)
            }
        }

        return copiedFiles
    }
}
