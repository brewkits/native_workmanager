package dev.brewkits.native_workmanager.workers.utils

import android.net.Uri
import android.util.Log
import java.io.File

/**
 * Security validation utilities for Android workers.
 *
 * Provides centralized security validation for:
 * - URL scheme validation (prevent file://, content://, etc.)
 * - File path validation (prevent path traversal)
 * - Safe logging (sanitize sensitive data)
 * - Request/response size limits
 */
object SecurityValidator {

    private const val TAG = "SecurityValidator"

    // MARK: - Constants

    /** Maximum allowed request body size (10MB) */
    const val MAX_REQUEST_BODY_SIZE = 10 * 1024 * 1024

    /** Maximum allowed response body size (50MB) */
    const val MAX_RESPONSE_BODY_SIZE = 50 * 1024 * 1024

    /** Maximum allowed file size for uploads/downloads (100MB) */
    const val MAX_FILE_SIZE = 100 * 1024 * 1024

    /** Maximum allowed compressed archive size (200MB) */
    const val MAX_ARCHIVE_SIZE = 200 * 1024 * 1024

    // MARK: - URL Validation

    /**
     * Validate that URL uses safe scheme (http/https only).
     *
     * @param urlString URL string to validate
     * @return true if URL is valid and safe, false otherwise
     */
    fun validateURL(urlString: String): Boolean {
        try {
            val uri = Uri.parse(urlString)

            // ✅ SECURITY: Check if scheme exists
            val scheme = uri.scheme?.lowercase()
            if (scheme.isNullOrEmpty()) {
                Log.e(TAG, "URL missing scheme")
                return false
            }

            // ✅ SECURITY: Only allow HTTP and HTTPS schemes
            val allowedSchemes = listOf("http", "https")
            if (scheme !in allowedSchemes) {
                Log.e(TAG, "Unsafe URL scheme '$scheme'. Only HTTP/HTTPS allowed.")
                return false
            }

            // ⚠️ Warning for non-HTTPS
            if (scheme == "http") {
                Log.w(TAG, "WARNING - Using HTTP (unencrypted). Consider HTTPS for security.")
            }

            return true
        } catch (e: Exception) {
            Log.e(TAG, "Invalid URL format: ${e.message}")
            return false
        }
    }

    // MARK: - File Path Validation

    /**
     * Validate file path is within app sandbox.
     *
     * Prevents path traversal attacks by ensuring the resolved path
     * stays within allowed app directories.
     *
     * @param path File path to validate
     * @param allowedDirs List of allowed directory paths
     * @return true if path is safe, false otherwise
     */
    fun validateFilePath(path: String, allowedDirs: List<File>): Boolean {
        try {
            // Convert to File and resolve canonical path (resolves symlinks and ..)
            val file = File(path)
            val canonicalPath = file.canonicalPath

            // ✅ SECURITY: Only allow paths within allowed directories
            for (allowedDir in allowedDirs) {
                if (canonicalPath.startsWith(allowedDir.canonicalPath)) {
                    return true
                }
            }

            Log.e(TAG, "File path '$canonicalPath' outside app sandbox")
            Log.e(TAG, "Allowed directories:")
            for (allowedDir in allowedDirs) {
                Log.e(TAG, "  - ${allowedDir.canonicalPath}")
            }

            return false
        } catch (e: Exception) {
            Log.e(TAG, "Cannot resolve file path: ${e.message}")
            return false
        }
    }

    // MARK: - Safe Logging

    /**
     * Sanitize URL for logging by redacting query parameters.
     *
     * Query parameters may contain sensitive data (tokens, passwords, etc.)
     * so we redact them before logging.
     *
     * @param urlString URL to sanitize
     * @return Sanitized URL string safe for logging
     */
    fun sanitizedURL(urlString: String): String {
        return try {
            val uri = Uri.parse(urlString)

            // ✅ SECURITY: Redact query parameters (may contain secrets)
            if (!uri.query.isNullOrEmpty()) {
                uri.buildUpon()
                    .clearQuery()
                    .appendQueryParameter("...", "[redacted]")
                    .build()
                    .toString()
            } else {
                urlString
            }
        } catch (e: Exception) {
            "[invalid URL]"
        }
    }

    /**
     * Truncate string for safe logging.
     *
     * Limits log output to prevent excessive logging and potential
     * information disclosure.
     *
     * @param string String to truncate
     * @param maxLength Maximum length (default: 200)
     * @return Truncated string
     */
    fun truncateForLogging(string: String, maxLength: Int = 200): String {
        return if (string.length <= maxLength) {
            string
        } else {
            string.take(maxLength) + "... [truncated]"
        }
    }

    // MARK: - Size Validation

    /**
     * Validate request body size.
     *
     * @param data Request body data
     * @return true if size is acceptable, false if too large
     */
    fun validateRequestSize(data: ByteArray): Boolean {
        if (data.size > MAX_REQUEST_BODY_SIZE) {
            Log.e(TAG, "Request body too large (${data.size} bytes, max $MAX_REQUEST_BODY_SIZE)")
            return false
        }
        return true
    }

    /**
     * Validate response body size.
     *
     * @param data Response body data
     * @return true if size is acceptable, false if too large
     */
    fun validateResponseSize(data: ByteArray): Boolean {
        if (data.size > MAX_RESPONSE_BODY_SIZE) {
            Log.e(TAG, "Response body too large (${data.size} bytes, max $MAX_RESPONSE_BODY_SIZE)")
            return false
        }
        return true
    }

    // MARK: - File Size Validation

    /**
     * Validate file size before upload.
     *
     * Prevents OOM errors from uploading excessively large files.
     *
     * @param file File to validate
     * @return true if size is acceptable, false if too large
     */
    fun validateFileSize(file: File): Boolean {
        if (!file.exists()) {
            Log.e(TAG, "File does not exist: ${file.absolutePath}")
            return false
        }

        val fileSize = file.length()
        if (fileSize > MAX_FILE_SIZE) {
            val sizeMB = fileSize / 1024 / 1024
            val maxMB = MAX_FILE_SIZE / 1024 / 1024
            Log.e(TAG, "File too large: ${sizeMB}MB (max ${maxMB}MB)")
            return false
        }

        return true
    }

    /**
     * Validate content length before download.
     *
     * Prevents OOM/disk space errors from downloading huge files.
     *
     * @param contentLength Content-Length header value (-1 if unknown)
     * @return true if size is acceptable or unknown, false if too large
     */
    fun validateContentLength(contentLength: Long): Boolean {
        if (contentLength < 0) {
            // Unknown size - allow but warn
            Log.w(TAG, "Content-Length unknown - cannot pre-validate download size")
            return true
        }

        if (contentLength > MAX_FILE_SIZE) {
            val sizeMB = contentLength / 1024 / 1024
            val maxMB = MAX_FILE_SIZE / 1024 / 1024
            Log.e(TAG, "Download too large: ${sizeMB}MB (max ${maxMB}MB)")
            return false
        }

        return true
    }

    /**
     * Validate archive file size.
     *
     * Archives can be larger than regular files since they compress content.
     *
     * @param file Archive file to validate
     * @return true if size is acceptable, false if too large
     */
    fun validateArchiveSize(file: File): Boolean {
        if (!file.exists()) {
            Log.e(TAG, "Archive does not exist: ${file.absolutePath}")
            return false
        }

        val fileSize = file.length()
        if (fileSize > MAX_ARCHIVE_SIZE) {
            val sizeMB = fileSize / 1024 / 1024
            val maxMB = MAX_ARCHIVE_SIZE / 1024 / 1024
            Log.e(TAG, "Archive too large: ${sizeMB}MB (max ${maxMB}MB)")
            return false
        }

        return true
    }

    /**
     * Check available disk space before download.
     *
     * @param requiredBytes Bytes needed for download
     * @param targetDir Directory where file will be saved
     * @return true if enough space available, false otherwise
     */
    fun hasEnoughDiskSpace(requiredBytes: Long, targetDir: File): Boolean {
        try {
            val stat = android.os.StatFs(targetDir.absolutePath)
            val availableBytes = stat.availableBytes

            // Add 20% safety margin
            val requiredWithMargin = (requiredBytes * 1.2).toLong()

            if (availableBytes < requiredWithMargin) {
                val availableMB = availableBytes / 1024 / 1024
                val requiredMB = requiredWithMargin / 1024 / 1024
                Log.e(TAG, "Insufficient disk space: ${availableMB}MB available, ${requiredMB}MB needed")
                return false
            }

            return true
        } catch (e: Exception) {
            Log.e(TAG, "Cannot check disk space: ${e.message}")
            return true // Allow operation if check fails
        }
    }
}
