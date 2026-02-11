import Foundation

/// Security validation utilities for workers.
///
/// Provides centralized security validation for:
/// - URL scheme validation (prevent file://, ftp://, etc.)
/// - File path validation (prevent path traversal)
/// - Safe logging (sanitize sensitive data)
enum SecurityValidator {

    // MARK: - URL Validation

    /// Validate that URL uses safe scheme (http/https only).
    ///
    /// - Parameter urlString: URL string to validate
    /// - Returns: Validated URL or nil if invalid/unsafe
    static func validateURL(_ urlString: String) -> URL? {
        guard let url = URL(string: urlString) else {
            print("SecurityValidator: Invalid URL format")
            return nil
        }

        // ✅ SECURITY: Only allow HTTP and HTTPS schemes
        guard let scheme = url.scheme?.lowercased() else {
            print("SecurityValidator: URL missing scheme")
            return nil
        }

        let allowedSchemes = ["http", "https"]
        guard allowedSchemes.contains(scheme) else {
            print("SecurityValidator: Unsafe URL scheme '\(scheme)'. Only HTTP/HTTPS allowed.")
            return nil
        }

        // ⚠️ Warning for non-HTTPS
        if scheme == "http" {
            print("SecurityValidator: WARNING - Using HTTP (unencrypted). Consider HTTPS for security.")
        }

        return url
    }

    // MARK: - File Path Validation

    /// Validate file path is within app sandbox.
    ///
    /// Prevents path traversal attacks by ensuring the resolved path
    /// stays within allowed app directories.
    ///
    /// - Parameter path: File path to validate
    /// - Returns: true if path is safe, false otherwise
    static func validateFilePath(_ path: String) -> Bool {
        // Convert to URL and resolve symlinks/relative paths
        let fileURL = URL(fileURLWithPath: path)

        guard let resolvedPath = try? fileURL.resolvingSymlinksInPath().path else {
            print("SecurityValidator: Cannot resolve file path")
            return false
        }

        // Get allowed directories (app sandbox)
        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first?.path

        let cachesDir = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first?.path

        let tempDir = NSTemporaryDirectory()

        // ✅ SECURITY: Only allow writes within app sandbox
        let allowedPaths = [documentsDir, cachesDir, tempDir].compactMap { $0 }

        for allowedPath in allowedPaths {
            if resolvedPath.hasPrefix(allowedPath) {
                return true
            }
        }

        print("SecurityValidator: File path '\(resolvedPath)' outside app sandbox")
        print("SecurityValidator: Allowed directories:")
        for allowedPath in allowedPaths {
            print("  - \(allowedPath)")
        }

        return false
    }

    // MARK: - Safe Logging

    /// Sanitize URL for logging by redacting query parameters.
    ///
    /// Query parameters may contain sensitive data (tokens, passwords, etc.)
    /// so we redact them before logging.
    ///
    /// - Parameter urlString: URL to sanitize
    /// - Returns: Sanitized URL string safe for logging
    static func sanitizedURL(_ urlString: String) -> String {
        guard var components = URLComponents(string: urlString) else {
            return "[invalid URL]"
        }

        // ✅ SECURITY: Redact query parameters (may contain secrets)
        if let queryItems = components.queryItems, !queryItems.isEmpty {
            components.queryItems = [URLQueryItem(name: "...", value: "[redacted]")]
        }

        return components.string ?? "[invalid URL]"
    }

    /// Truncate string for safe logging.
    ///
    /// Limits log output to prevent excessive logging and potential
    /// information disclosure.
    ///
    /// - Parameters:
    ///   - string: String to truncate
    ///   - maxLength: Maximum length (default: 200)
    /// - Returns: Truncated string
    static func truncateForLogging(_ string: String, maxLength: Int = 200) -> String {
        if string.count <= maxLength {
            return string
        }
        return String(string.prefix(maxLength)) + "... [truncated]"
    }

    // MARK: - File Size Limits

    /// Maximum allowed file size for uploads/downloads (100MB).
    static let maxFileSize: Int64 = 100 * 1024 * 1024

    /// Maximum allowed archive size (200MB).
    static let maxArchiveSize: Int64 = 200 * 1024 * 1024

    /// Maximum allowed request body size (10MB).
    static let maxRequestBodySize = 10 * 1024 * 1024

    /// Maximum allowed response body size (50MB).
    static let maxResponseBodySize = 50 * 1024 * 1024

    // MARK: - Request Size Validation

    /// Validate request body size.
    ///
    /// - Parameter data: Request body data
    /// - Returns: true if size is acceptable, false if too large
    static func validateRequestSize(_ data: Data) -> Bool {
        if data.count > maxRequestBodySize {
            print("SecurityValidator: Request body too large (\(data.count) bytes, max \(maxRequestBodySize))")
            return false
        }
        return true
    }

    /// Validate response body size.
    ///
    /// - Parameter data: Response body data
    /// - Returns: true if size is acceptable, false if too large
    static func validateResponseSize(_ data: Data) -> Bool {
        if data.count > maxResponseBodySize {
            print("SecurityValidator: Response body too large (\(data.count) bytes, max \(maxResponseBodySize))")
            return false
        }
        return true
    }

    // MARK: - File Size Validation

    /// Validate file size before upload/download.
    ///
    /// - Parameter fileURL: URL of file to validate
    /// - Returns: true if file size is acceptable, false if too large or file doesn't exist
    static func validateFileSize(_ fileURL: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("SecurityValidator: File does not exist: \(fileURL.path)")
            return false
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard let fileSize = attributes[.size] as? Int64 else {
                print("SecurityValidator: Cannot determine file size")
                return false
            }

            if fileSize > maxFileSize {
                let sizeMB = fileSize / 1024 / 1024
                let maxMB = maxFileSize / 1024 / 1024
                print("SecurityValidator: File too large: \(sizeMB)MB (max \(maxMB)MB)")
                return false
            }

            return true
        } catch {
            print("SecurityValidator: Error reading file attributes: \(error)")
            return false
        }
    }

    /// Validate content length for downloads.
    ///
    /// - Parameter contentLength: Content-Length header value from HTTP response
    /// - Returns: true if size is acceptable, false if too large
    static func validateContentLength(_ contentLength: Int64) -> Bool {
        if contentLength < 0 {
            print("SecurityValidator: Content-Length unknown - cannot pre-validate download size")
            return true  // Allow with warning
        }

        if contentLength > maxFileSize {
            let sizeMB = contentLength / 1024 / 1024
            let maxMB = maxFileSize / 1024 / 1024
            print("SecurityValidator: Download too large: \(sizeMB)MB (max \(maxMB)MB)")
            return false
        }

        return true
    }

    /// Validate archive file size.
    ///
    /// - Parameter fileURL: URL of archive file to validate
    /// - Returns: true if archive size is acceptable, false if too large or file doesn't exist
    static func validateArchiveSize(_ fileURL: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("SecurityValidator: Archive does not exist: \(fileURL.path)")
            return false
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard let fileSize = attributes[.size] as? Int64 else {
                print("SecurityValidator: Cannot determine archive size")
                return false
            }

            if fileSize > maxArchiveSize {
                let sizeMB = fileSize / 1024 / 1024
                let maxMB = maxArchiveSize / 1024 / 1024
                print("SecurityValidator: Archive too large: \(sizeMB)MB (max \(maxMB)MB)")
                return false
            }

            return true
        } catch {
            print("SecurityValidator: Error reading archive attributes: \(error)")
            return false
        }
    }

    // MARK: - Disk Space Validation

    /// Check if there's enough disk space for a file operation.
    ///
    /// - Parameters:
    ///   - requiredBytes: Number of bytes required for the operation
    ///   - targetURL: Directory where file will be written (default: temp directory)
    /// - Returns: true if sufficient space available, false otherwise
    static func hasEnoughDiskSpace(requiredBytes: Int64, targetURL: URL? = nil) -> Bool {
        let targetPath = targetURL?.path ?? NSTemporaryDirectory()

        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: targetPath)
            guard let freeSpace = attributes[.systemFreeSize] as? Int64 else {
                print("SecurityValidator: Cannot determine free disk space")
                return true  // Fail-open: allow operation if check fails
            }

            // Add 20% safety margin + 50MB minimum free space
            let requiredWithMargin = Int64(Double(requiredBytes) * 1.2) + (50 * 1024 * 1024)

            if freeSpace < requiredWithMargin {
                let availableMB = freeSpace / 1024 / 1024
                let requiredMB = requiredWithMargin / 1024 / 1024
                print("SecurityValidator: Insufficient disk space: \(availableMB)MB available, \(requiredMB)MB needed")
                return false
            }

            return true
        } catch {
            print("SecurityValidator: Cannot check disk space: \(error)")
            return true  // Fail-open: allow operation if check fails
        }
    }

    // MARK: - Additional Field Validation

    /// Maximum number of additional form fields.
    static let maxAdditionalFields = 50

    /// Maximum size per form field value (1MB).
    static let maxFieldValueSize = 1024 * 1024

    /// Maximum total payload size (10MB).
    static let maxTotalPayloadSize = 10 * 1024 * 1024

    /// Validate additional form fields for upload.
    ///
    /// - Parameter fields: Dictionary of form field name to value
    /// - Returns: true if valid, false if too many fields or values too large
    static func validateAdditionalFields(_ fields: [String: String]) -> Bool {
        // Check field count
        if fields.count > maxAdditionalFields {
            print("SecurityValidator: Too many form fields: \(fields.count) (max \(maxAdditionalFields))")
            return false
        }

        var totalSize = 0

        // Check individual field sizes and total payload
        for (key, value) in fields {
            let valueSize = value.utf8.count

            if valueSize > maxFieldValueSize {
                let sizeMB = Double(valueSize) / 1024.0 / 1024.0
                print("SecurityValidator: Field '\(key)' too large: \(String(format: "%.2f", sizeMB))MB (max 1MB)")
                return false
            }

            totalSize += valueSize
        }

        // Check total payload size
        if totalSize > maxTotalPayloadSize {
            let sizeMB = Double(totalSize) / 1024.0 / 1024.0
            print("SecurityValidator: Total payload too large: \(String(format: "%.2f", sizeMB))MB (max 10MB)")
            return false
        }

        return true
    }
}

