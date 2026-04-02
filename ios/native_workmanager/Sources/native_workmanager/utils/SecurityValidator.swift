import Foundation

/// Security validation utilities for workers.
///
/// Provides centralized security validation for:
/// - URL scheme validation (prevent file://, ftp://, etc.)
/// - File path validation (prevent path traversal)
/// - Safe logging (sanitize sensitive data)
enum SecurityValidator {

    // MARK: - Global enforcement flags

    /// When true, plain HTTP URLs are rejected globally across all workers.
    /// Set by handleInitialize() when the Dart caller passes enforceHttps=true.
    static var enforceHttps: Bool = false

    /// When true, HTTP workers block requests to private/loopback IP literals.
    /// Covers: 10.x, 172.16-31.x, 192.168.x, 127.x, 169.254.x (link-local),
    ///         ::1, fc00::/7 (ULA), and fe80::/10 (IPv6 link-local).
    /// Only parsed IP literals are checked — hostnames are NOT resolved.
    /// Set by handleInitialize() when the Dart caller passes blockPrivateIPs=true.
    static var blockPrivateIPs: Bool = false

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

        // Reject plain HTTP when global HTTPS enforcement is enabled.
        if scheme == "http" {
            if enforceHttps {
                print("SecurityValidator: Plain HTTP rejected — enforceHttps=true. Use an HTTPS URL.")
                return nil
            }
            print("SecurityValidator: WARNING - Using HTTP (unencrypted). Consider HTTPS for security.")
        }

        // SSRF protection: block requests to private/loopback IP literals.
        if blockPrivateIPs, let host = url.host, isPrivateIP(host) {
            print("SecurityValidator: Request blocked — '\(host)' is a private/loopback IP (blockPrivateIPs=true).")
            return nil
        }

        return url
    }

    // MARK: - File Path Validation

    /// Validate a save path and return the canonical path on success, or nil if invalid.
    ///
    /// Convenience wrapper around `validateFilePath(_:)` that returns the resolved
    /// path string so callers can use the canonical path after validation.
    ///
    /// - Parameter path: File path to validate
    /// - Returns: Canonical (symlink-resolved) path string if valid, nil if invalid/unsafe
    static func validateSavePath(_ path: String) -> String? {
        guard !path.isEmpty else { return nil }
        guard validateFilePath(path) else { return nil }
        return resolvePathWithSymlinks(path)
    }

    /// Validate file path is within app sandbox.
    ///
    /// Prevents path traversal attacks by ensuring the resolved path
    /// stays within allowed app directories.
    ///
    /// - Parameter path: File path to validate
    /// - Returns: true if path is safe, false otherwise
    static func validateFilePath(_ path: String) -> Bool {
        // Convert to URL and resolve symlinks/relative paths.
        // NOTE: On real iOS devices, /var is a symlink to /private/var.
        // We must resolve symlinks on BOTH the input path AND the allowed paths.
        //
        // CRITICAL: resolvingSymlinksInPath() returns the URL *unchanged* when the
        // path does not exist on the filesystem (Apple-documented behaviour).
        // Output files (e.g. encrypted.dat, compressed.zip) don't exist yet, so
        // we resolve their parent directory (which does exist) and reconstruct.
        let resolvedPath = resolvePathWithSymlinks(path)

        // Get allowed directories (app sandbox) and resolve their symlinks too
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())

        let allowedURLs: [URL] = [documentsURL, cachesURL, tempURL].compactMap { $0 }

        // ✅ SECURITY: Only allow paths within app sandbox (resolve symlinks on both sides)
        for allowedURL in allowedURLs {
            let resolvedAllowed = allowedURL.resolvingSymlinksInPath().path
            if resolvedPath.hasPrefix(resolvedAllowed) {
                return true
            }
        }

        print("SecurityValidator: File path '\(resolvedPath)' outside app sandbox")
        print("SecurityValidator: Allowed directories:")
        for allowedURL in allowedURLs {
            print("  - \(allowedURL.resolvingSymlinksInPath().path)")
        }

        return false
    }

    /// Resolve symlinks in a path, including for paths that do not yet exist.
    ///
    /// `URL.resolvingSymlinksInPath()` is documented to return the URL unchanged
    /// when the path doesn't exist. For non-existent paths (e.g. output files)
    /// we walk up to the deepest existing ancestor, resolve symlinks there, then
    /// reconstruct the full path so the /var → /private/var mapping is applied.
    private static func resolvePathWithSymlinks(_ path: String) -> String {
        let fileManager = FileManager.default
        var url = URL(fileURLWithPath: path)

        // If the path exists, resolve directly — this is the common case.
        if fileManager.fileExists(atPath: url.path) {
            return url.resolvingSymlinksInPath().path
        }

        // Walk up the directory tree until we find an existing ancestor.
        var nonExistentTail: [String] = []
        while url.path != "/" {
            nonExistentTail.append(url.lastPathComponent)
            url = url.deletingLastPathComponent()
            if fileManager.fileExists(atPath: url.path) {
                break
            }
        }

        // Resolve symlinks on the existing ancestor.
        let resolvedBase = url.resolvingSymlinksInPath().path
        let tail = nonExistentTail.reversed().joined(separator: "/")

        if resolvedBase == "/" {
            return "/" + tail
        }
        return resolvedBase + "/" + tail
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

    /// Maximum allowed file size for uploads/downloads (500MB).
    static var maxFileSize: Int64 = 500 * 1024 * 1024

    /// Maximum allowed archive size (1GB).
    static var maxArchiveSize: Int64 = 1024 * 1024 * 1024

    /// Maximum allowed request body size (10MB).
    static var maxRequestBodySize: Int = 10 * 1024 * 1024

    /// Maximum allowed response body size (50MB).
    static var maxResponseBodySize: Int = 50 * 1024 * 1024

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
        // FIX M2 (improved): Use the deepest existing ancestor of targetURL so that
        // attributesOfFileSystem() works even when the destination file/dir doesn't exist yet
        // (a common case for downloads). Falls back to NSTemporaryDirectory if needed.
        var checkPath = NSTemporaryDirectory()
        if let url = targetURL {
            var probe = url
            while probe.path != "/" {
                if FileManager.default.fileExists(atPath: probe.path) {
                    checkPath = probe.path
                    break
                }
                probe = probe.deletingLastPathComponent()
            }
        }

        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: checkPath)
            guard let freeSpace = attributes[.systemFreeSize] as? Int64 else {
                print("SecurityValidator: Cannot determine free disk space at '\(checkPath)'")
                return true  // Cannot check — allow and let the OS report the actual error
            }

            // Add 20% safety margin (matches Android's formula — no artificial minimum
            // to avoid false failures for small downloads on storage-constrained devices)
            let requiredWithMargin = Int64(Double(requiredBytes) * 1.2)

            if freeSpace < requiredWithMargin {
                let availableMB = freeSpace / 1024 / 1024
                let requiredKB = requiredWithMargin / 1024
                print("SecurityValidator: Insufficient disk space: \(availableMB)MB available, \(requiredKB)KB needed")
                return false
            }

            return true
        } catch {
            // Cannot query disk space (older OS, unexpected path, permissions).
            // Log clearly and fail-open: the OS will raise a genuine error if the
            // write truly fails due to disk full (NSFileWriteOutOfSpaceError).
            print("SecurityValidator: Cannot check disk space at '\(checkPath)': \(error) — allowing operation (OS will surface actual disk-full errors)")
            return true
        }
    }

    // MARK: - Private IP Detection

    /// Returns true if `host` is a private/loopback IPv4 or IPv6 literal.
    ///
    /// Only IP literals are matched — hostnames are NOT resolved (no DNS lookup).
    /// Covers:
    ///   IPv4: 127.x, 10.x, 172.16-31.x, 192.168.x, 169.254.x (link-local)
    ///   IPv6: ::1, fc00::/7 (ULA), fe80::/10 (link-local)
    static func isPrivateIP(_ host: String) -> Bool {
        guard !host.isEmpty else { return false }
        // Strip IPv6 brackets: [::1] → ::1
        let h: String
        if host.hasPrefix("[") && host.hasSuffix("]") {
            h = String(host.dropFirst().dropLast())
        } else {
            h = host
        }
        // IPv6 loopback
        if h == "::1" { return true }
        // IPv6 ULA (fc00::/7 — first byte fc or fd) and link-local (fe80::/10)
        let lower = h.lowercased()
        if lower.hasPrefix("fc") || lower.hasPrefix("fd") || lower.hasPrefix("fe80") { return true }
        // IPv4 — split on "." and validate octets
        let parts = h.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4,
              let a = Int(parts[0]),
              let b = Int(parts[1]) else { return false }
        switch a {
        case 127: return true                    // 127.x loopback
        case 10:  return true                    // 10.x/8
        case 172: return b >= 16 && b <= 31      // 172.16-31.x/12
        case 192: return b == 168               // 192.168.x/16
        case 169: return b == 254               // 169.254.x link-local
        default:  return false
        }
    }

    // MARK: - Safe Header Logging

    /// Return a loggable representation of HTTP headers with sensitive values redacted.
    ///
    /// Sensitive header names (Authorization, X-API-Key, X-Auth-Token, Cookie,
    /// Set-Cookie, Proxy-Authorization) are replaced with `[redacted]`.
    /// Non-sensitive headers are included as-is.
    ///
    /// - Parameter headers: HTTP request or response headers
    /// - Returns: String summary safe for logging
    static func safeLog(headers: [String: String]) -> String {
        let sensitiveNames: Set<String> = [
            "authorization", "x-api-key", "x-auth-token",
            "cookie", "set-cookie", "proxy-authorization",
        ]
        let entries = headers.map { key, value -> String in
            if sensitiveNames.contains(key.lowercased()) {
                return "\(key): [redacted]"
            }
            return "\(key): \(value)"
        }
        return entries.sorted().joined(separator: ", ")
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

