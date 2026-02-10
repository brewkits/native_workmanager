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

    // MARK: - Request Size Validation

    /// Maximum allowed request body size (10MB).
    static let maxRequestBodySize = 10 * 1024 * 1024

    /// Maximum allowed response body size (50MB).
    static let maxResponseBodySize = 50 * 1024 * 1024

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
}
