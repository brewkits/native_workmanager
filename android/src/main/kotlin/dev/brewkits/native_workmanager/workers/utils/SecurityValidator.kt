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

    @Volatile
    var enforceHttps: Boolean = false

    @Volatile
    var blockPrivateIPs: Boolean = false

    // MARK: - Configurable Limits (Allow users to override these)
    @Volatile var maxRequestBodySize = 10 * 1024 * 1024L
    @Volatile var maxResponseBodySize = 50 * 1024 * 1024L
    @Volatile var maxFileSize = 500 * 1024 * 1024L // Increased to 500MB default
    @Volatile var maxArchiveSize = 1024 * 1024 * 1024L // Increased to 1GB default

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

            // Check if scheme exists
            val scheme = uri.scheme?.lowercase()
            if (scheme.isNullOrEmpty()) {
                Log.e(TAG, "URL missing scheme")
                return false
            }

            // Only allow HTTP and HTTPS schemes
            val allowedSchemes = listOf("http", "https")
            if (scheme !in allowedSchemes) {
                // FIX #06: Explicitly reject content:// and file:// schemes for URL-based workers
                // unless they are specifically designed to handle them.
                Log.e(TAG, "Unsafe URL scheme '$scheme'. Only HTTP/HTTPS allowed.")
                return false
            }

            // Reject plain HTTP when global HTTPS enforcement is enabled.
            if (scheme == "http") {
                if (enforceHttps) {
                    Log.e(TAG, "Plain HTTP rejected — enforceHttps=true. Use an HTTPS URL.")
                    return false
                }
                Log.w(TAG, "WARNING - Using HTTP (unencrypted). Consider HTTPS for security.")
            }

            // SSRF protection: block requests to private/loopback IP literals.
            if (blockPrivateIPs) {
                val host = uri.host ?: ""
                if (isPrivateIP(host)) {
                    Log.e(TAG, "Request blocked — '$host' is a private/loopback IP (blockPrivateIPs=true).")
                    return false
                }
            }

            return true
        } catch (e: Exception) {
            Log.e(TAG, "Invalid URL format: ${e.message}")
            return false
        }
    }

    // MARK: - File Path Validation

    /**
     * Validate a file path without requiring app context (no allowedDirs needed).
     *
     * Resolves the canonical path (handles ".." and symlinks) and blocks access
     * to restricted OS directories. Use this in workers that do not have a Context.
     * For stricter sandbox enforcement pass allowedDirs to [validateFilePath].
     *
     * FIX H1: Workers previously used `contains("..")` which is bypassable via
     * URL-encoded sequences or symlinks. This method uses File.canonicalPath which
     * the JVM resolves via the OS, defeating those bypasses.
     *
     * @param path File path to validate
     * @return true if path is safe, false otherwise
     */
    fun validateFilePathSafe(path: String): Boolean {
        try {
            if (path.isEmpty() || !path.startsWith("/")) {
                Log.e(TAG, "File path must be non-empty and absolute (start with /)")
                return false
            }
            val canonical = File(path).canonicalPath
            // Block read/write to OS-owned directories regardless of how the path
            // was constructed. This catches symlink escapes into system space.
            val blockedPrefixes = listOf("/proc", "/sys", "/etc", "/system", "/vendor", "/dev", "/root")
            for (blocked in blockedPrefixes) {
                if (canonical.startsWith(blocked)) {
                    Log.e(TAG, "File path '$canonical' points to restricted system directory '$blocked'")
                    return false
                }
            }
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Cannot resolve canonical path for '$path': ${e.message}")
            return false
        }
    }

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

            // Only allow paths within allowed directories
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

            // Redact query parameters (may contain secrets)
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
        if (data.size > maxRequestBodySize) {
            Log.e(TAG, "Request body too large (${data.size} bytes, max $maxRequestBodySize)")
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
        if (data.size > maxResponseBodySize) {
            Log.e(TAG, "Response body too large (${data.size} bytes, max $maxResponseBodySize)")
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
        if (fileSize > maxFileSize) {
            val sizeMB = fileSize / 1024 / 1024
            val maxMB = maxFileSize / 1024 / 1024
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

        if (contentLength > maxFileSize) {
            val sizeMB = contentLength / 1024 / 1024
            val maxMB = maxFileSize / 1024 / 1024
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
        if (fileSize > maxArchiveSize) {
            val sizeMB = fileSize / 1024 / 1024
            val maxMB = maxArchiveSize / 1024 / 1024
            Log.e(TAG, "Archive too large: ${sizeMB}MB (max ${maxMB}MB)")
            return false
        }

        return true
    }

    // MARK: - Private IP Detection

    /**
     * Returns true if [host] is a private/loopback IPv4 or IPv6 literal.
     *
     * Only IP literals are matched — hostnames are NOT resolved (no DNS lookup).
     * Covers:
     *   IPv4: 127.x, 10.x, 172.16-31.x, 192.168.x, 169.254.x (link-local)
     *   IPv6: ::1, fc00::/7 (ULA), fe80::/10 (link-local)
     */
    private fun isPrivateIP(host: String): Boolean {
        if (host.isEmpty()) return false
        // Strip IPv6 brackets: [::1] → ::1
        val h = if (host.startsWith("[") && host.endsWith("]")) host.drop(1).dropLast(1) else host
        // IPv6 loopback, ULA (fc00::/7), and link-local (fe80::/10)
        if (h == "::1") return true
        val lower = h.lowercase()
        if (lower.startsWith("fc") || lower.startsWith("fd") || lower.startsWith("fe80")) return true
        // IPv4 private ranges
        val ipv4Regex = Regex("""^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$""")
        val match = ipv4Regex.matchEntire(h) ?: return false
        val (a, b) = match.destructured.let { it.component1().toIntOrNull() to it.component2().toIntOrNull() }
        return when {
            a == null || b == null -> false
            a == 127 -> true                      // 127.x loopback
            a == 10 -> true                       // 10.x/8
            a == 172 && b in 16..31 -> true       // 172.16-31.x/12
            a == 192 && b == 168 -> true          // 192.168.x/16
            a == 169 && b == 254 -> true          // 169.254.x link-local
            else -> false
        }
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
            // FIX M2: Fail-closed on disk space check errors.
            // Previously this returned true (fail-open) meaning an exception (e.g.
            // permission denied, unmounted volume) silently bypassed the check and
            // could allow disk-filling operations to proceed unchecked.
            Log.e(TAG, "Cannot check disk space for '${targetDir.absolutePath}': ${e.message} — refusing operation")
            return false
        }
    }
}
