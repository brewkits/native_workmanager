package dev.brewkits.native_workmanager.workers

import android.content.Context
import androidx.work.WorkerParameters
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult
import dev.brewkits.native_workmanager.workers.utils.ProgressReporter
import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
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

        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) {
            return WorkerResult.Failure("Source not found: $sourcePath")
        }

        val destFile = File(destinationPath)

        // Check if destination exists
        if (destFile.exists() && !overwrite) {
            return WorkerResult.Failure("Destination already exists: $destinationPath (set overwrite=true to replace)")
        }

        // Path traversal protection
        if (!destFile.canonicalPath.startsWith(destFile.parentFile?.canonicalPath ?: "")) {
            return WorkerResult.Failure("Path traversal detected in destination")
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
                data = mapOf(
                    "operation" to "copy",
                    "sourcePath" to sourcePath,
                    "destinationPath" to destinationPath,
                    "fileCount" to copiedFiles.size,
                    "totalSize" to totalSize,
                    "files" to copiedFiles.map { it.absolutePath }
                )
            )
        } catch (e: IOException) {
            WorkerResult.Failure("Copy failed: ${e.message}")
        }
    }

    private fun handleMove(json: JSONObject): WorkerResult {
        val sourcePath = json.getString("sourcePath")
        val destinationPath = json.getString("destinationPath")
        val overwrite = json.optBoolean("overwrite", false)

        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) {
            return WorkerResult.Failure("Source not found: $sourcePath")
        }

        val destFile = File(destinationPath)

        if (destFile.exists() && !overwrite) {
            return WorkerResult.Failure("Destination already exists: $destinationPath (set overwrite=true to replace)")
        }

        // Path traversal protection
        if (!destFile.canonicalPath.startsWith(destFile.parentFile?.canonicalPath ?: "")) {
            return WorkerResult.Failure("Path traversal detected in destination")
        }

        return try {
            // Create parent directory if needed
            destFile.parentFile?.mkdirs()

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
                sourceFile.deleteRecursively()
            }

            val fileCount = if (destFile.isDirectory) {
                destFile.walkTopDown().count { it.isFile }
            } else 1

            WorkerResult.Success(
                message = "Moved $fileCount file(s)",
                data = mapOf(
                    "operation" to "move",
                    "sourcePath" to sourcePath,
                    "destinationPath" to destinationPath,
                    "fileCount" to fileCount
                )
            )
        } catch (e: IOException) {
            WorkerResult.Failure("Move failed: ${e.message}")
        }
    }

    private fun handleDelete(json: JSONObject): WorkerResult {
        val path = json.getString("path")
        val recursive = json.optBoolean("recursive", false)

        val file = File(path)
        if (!file.exists()) {
            return WorkerResult.Failure("Path not found: $path")
        }

        // Safety check: prevent accidental deletion of important directories
        val dangerousPaths = listOf("/", "/system", "/data", "/storage/emulated/0")
        if (dangerousPaths.any { file.absolutePath.startsWith(it) && file.absolutePath.length <= it.length + 1 }) {
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

            if (deleted) {
                WorkerResult.Success(
                    message = "Deleted $fileCount file(s)",
                    data = mapOf(
                        "operation" to "delete",
                        "path" to path,
                        "fileCount" to fileCount
                    )
                )
            } else {
                WorkerResult.Failure("Failed to delete: $path")
            }
        } catch (e: IOException) {
            WorkerResult.Failure("Delete failed: ${e.message}")
        }
    }

    private fun handleList(json: JSONObject): WorkerResult {
        val path = json.getString("path")
        val pattern = json.optString("pattern").takeIf { it.isNotEmpty() }
        val recursive = json.optBoolean("recursive", false)

        val directory = File(path)
        if (!directory.exists()) {
            return WorkerResult.Failure("Path not found: $path")
        }

        if (!directory.isDirectory) {
            return WorkerResult.Failure("Path is not a directory: $path")
        }

        return try {
            val files = if (recursive) {
                directory.walkTopDown()
                    .filter { it.isFile }
                    .toList()
            } else {
                directory.listFiles()?.filter { it.isFile } ?: emptyList()
            }

            // Apply pattern filter if specified
            val filteredFiles = if (pattern != null) {
                val regex = pattern
                    .replace(".", "\\.")
                    .replace("*", ".*")
                    .replace("?", ".")
                    .toRegex()

                files.filter { regex.matches(it.name) }
            } else {
                files
            }

            val fileInfos = filteredFiles.map { file ->
                mapOf(
                    "path" to file.absolutePath,
                    "name" to file.name,
                    "size" to file.length(),
                    "lastModified" to file.lastModified(),
                    "isDirectory" to file.isDirectory
                )
            }

            WorkerResult.Success(
                message = "Found ${filteredFiles.size} file(s)",
                data = mapOf(
                    "operation" to "list",
                    "path" to path,
                    "pattern" to (pattern ?: ""),
                    "recursive" to recursive,
                    "fileCount" to filteredFiles.size,
                    "totalSize" to filteredFiles.sumOf { it.length() },
                    "files" to fileInfos
                )
            )
        } catch (e: Exception) {
            WorkerResult.Failure("List failed: ${e.message}")
        }
    }

    private fun handleMkdir(json: JSONObject): WorkerResult {
        val path = json.getString("path")
        val createParents = json.optBoolean("createParents", true)

        val directory = File(path)

        if (directory.exists()) {
            return if (directory.isDirectory) {
                WorkerResult.Success(
                    message = "Directory already exists",
                    data = mapOf(
                        "operation" to "mkdir",
                        "path" to path,
                        "created" to false
                    )
                )
            } else {
                WorkerResult.Failure("Path exists but is not a directory: $path")
            }
        }

        // Path traversal protection
        if (!directory.canonicalPath.startsWith(directory.parentFile?.canonicalPath ?: "")) {
            return WorkerResult.Failure("Path traversal detected")
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
                    data = mapOf(
                        "operation" to "mkdir",
                        "path" to path,
                        "created" to true
                    )
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
