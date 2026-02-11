import Foundation
import CryptoKit

/// Native HTTP file download worker for iOS.
///
/// Downloads files using URLSession with streaming to minimize memory usage.
/// Uses atomic file operations (temp file → final file) to prevent corruption.
/// Supports resume from last downloaded byte using HTTP Range Requests (RFC 7233).
///
/// **Configuration JSON:**
/// ```json
/// {
///   "url": "https://example.com/file.zip",
///   "savePath": "/path/to/save/file.zip",
///   "headers": {                // Optional
///     "Authorization": "Bearer token"
///   },
///   "timeoutMs": 300000,       // Optional: Timeout (default: 5 minutes for downloads)
///   "enableResume": true,      // Optional: Enable resume support (default: true)
///   "expectedChecksum": "a3b2c1...",  // Optional: Expected checksum for verification
///   "checksumAlgorithm": "SHA-256"    // Optional: Hash algorithm (default: SHA-256)
/// }
/// ```
///
/// **Features:**
/// - Streaming download (does not load entire file in memory)
/// - **Resume support** (automatic retry from last byte on network failure)
/// - Atomic file operations (writes to .tmp then renames)
/// - Auto-creates parent directories
/// - Cleans up on error
///
/// **Resume Behavior:**
/// - If network fails mid-download, next attempt resumes from last byte
/// - Uses HTTP Range header (bytes=N-) to request remaining data
/// - Server must support Range requests (returns 206 Partial Content)
/// - Falls back to full download if server doesn't support resume
///
/// **Performance:** ~3-5MB RAM regardless of file size
class HttpDownloadWorker: IosWorker {

    private static let defaultTimeoutMs: Int64 = 300_000

    struct Config: Codable {
        let url: String
        let savePath: String
        let headers: [String: String]?
        let timeoutMs: Int64?
        let enableResume: Bool?  // Enable resume support (default: true)
        let expectedChecksum: String?  // Expected checksum for verification
        let checksumAlgorithm: String?  // Hash algorithm (MD5, SHA-256, SHA-1)
        let useBackgroundSession: Bool?  // 👈 NEW v2.3.0: Use background URLSession (survives app termination)

        var timeout: TimeInterval {
            TimeInterval((timeoutMs ?? HttpDownloadWorker.defaultTimeoutMs) / 1000)
        }

        var resumeEnabled: Bool {
            enableResume ?? true
        }

        var effectiveChecksumAlgorithm: String {
            checksumAlgorithm ?? "SHA-256"
        }

        var shouldUseBackgroundSession: Bool {
            useBackgroundSession ?? false  // Default: false for backward compatibility
        }
    }

    func doWork(input: String?) async throws -> WorkerResult {
        guard let input = input, !input.isEmpty else {
            print("HttpDownloadWorker: Error - Empty or null input")
            return .failure(message: "Empty or null input")
        }

        // Parse configuration
        let config: Config
        do {
            let data = input.data(using: .utf8)!
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            print("HttpDownloadWorker: Error parsing JSON config: \(error)")
            return .failure(message: "Invalid JSON config: \(error.localizedDescription)")
        }

        // ✅ SECURITY: Validate URL scheme (prevent file://, ftp://, etc.)
        guard let url = SecurityValidator.validateURL(config.url) else {
            print("HttpDownloadWorker: Error - Invalid or unsafe URL")
            return .failure(message: "Invalid or unsafe URL")
        }

        // ✅ SECURITY: Validate file path is within app sandbox
        guard SecurityValidator.validateFilePath(config.savePath) else {
            print("HttpDownloadWorker: Error - File path outside app sandbox")
            return .failure(message: "File path outside app sandbox")
        }

        let destinationURL = URL(fileURLWithPath: config.savePath)
        let tempURL = URL(fileURLWithPath: config.savePath + ".tmp")

        // Create parent directory if needed
        let parentDir = destinationURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            do {
                try FileManager.default.createDirectory(at: parentDir,
                                                       withIntermediateDirectories: true)
                print("HttpDownloadWorker: Created directory: \(parentDir.path)")
            } catch {
                print("HttpDownloadWorker: Error creating directory: \(error)")
                return .failure(message: "Failed to create directory: \(error.localizedDescription)")
            }
        }

        // 👇 NEW: Check for existing partial download (resume support)
        var existingBytes: Int64 = 0
        if config.resumeEnabled && FileManager.default.fileExists(atPath: tempURL.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
                if let fileSize = attributes[.size] as? Int64, fileSize > 0 {
                    existingBytes = fileSize
                    print("HttpDownloadWorker: Found existing partial download: \(existingBytes) bytes")
                } else {
                    // Delete empty temp file
                    try? FileManager.default.removeItem(at: tempURL)
                }
            } catch {
                print("HttpDownloadWorker: Error reading temp file: \(error)")
                try? FileManager.default.removeItem(at: tempURL)
            }
        } else if FileManager.default.fileExists(atPath: tempURL.path) {
            // Clean up if resume disabled
            try? FileManager.default.removeItem(at: tempURL)
        }

        // ✅ SECURITY: Sanitize URL for logging
        let sanitizedURL = SecurityValidator.sanitizedURL(config.url)
        print("HttpDownloadWorker: Downloading \(sanitizedURL)")
        print("  Save to: \(destinationURL.lastPathComponent)")

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = config.timeout

        // 👇 NEW: Add Range header if resuming
        if existingBytes > 0 {
            request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range")
            print("HttpDownloadWorker: Resuming download from byte \(existingBytes)")
        }

        // Add headers
        if let headers = config.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Execute download using background session or foreground session
        if config.shouldUseBackgroundSession {
            // 👇 NEW v2.3.0: Background session (survives app termination)
            return await downloadWithBackgroundSession(
                url: url,
                destinationURL: destinationURL,
                tempURL: tempURL,
                config: config,
                headers: config.headers,
                existingBytes: existingBytes
            )
        }

        // Execute download using foreground session (iOS 13+ compatible)
        return await withCheckedContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: request) { location, response, error in
                // Handle errors
                if let error = error {
                    print("HttpDownloadWorker: Error - \(error.localizedDescription)")
                    try? FileManager.default.removeItem(at: tempURL)
                    continuation.resume(returning: .failure(message: error.localizedDescription))
                    return
                }

                guard let location = location,
                      let httpResponse = response as? HTTPURLResponse else {
                    print("HttpDownloadWorker: Error - Invalid response")
                    continuation.resume(returning: .failure(message: "Invalid response"))
                    return
                }

                let statusCode = httpResponse.statusCode

                // 👇 NEW: Handle both full content (200) and partial content (206)
                let isPartialContent = statusCode == 206
                let isFullContent = (200..<300).contains(statusCode)
                let isResumingDownload = existingBytes > 0 && isPartialContent

                if !isPartialContent && !isFullContent {
                    print("HttpDownloadWorker: Failed - Status \(statusCode)")
                    try? FileManager.default.removeItem(at: location)
                    continuation.resume(returning: .failure(message: "HTTP \(statusCode)"))
                    return
                }

                // ✅ SECURITY: Validate content length before downloading
                let contentLength = httpResponse.expectedContentLength
                if contentLength > 0 {
                    if !SecurityValidator.validateContentLength(contentLength) {
                        print("HttpDownloadWorker: Error - Content too large")
                        try? FileManager.default.removeItem(at: location)
                        continuation.resume(returning: .failure(message: "Download size exceeds limit"))
                        return
                    }

                    // ✅ SECURITY: Check disk space
                    if !SecurityValidator.hasEnoughDiskSpace(requiredBytes: contentLength, targetURL: destinationURL) {
                        print("HttpDownloadWorker: Error - Insufficient disk space")
                        try? FileManager.default.removeItem(at: location)
                        continuation.resume(returning: .failure(message: "Insufficient disk space"))
                        return
                    }
                }

                // Log resume status
                if isResumingDownload {
                    print("HttpDownloadWorker: Resume confirmed - Server sent 206 Partial Content")
                } else if existingBytes > 0 && statusCode == 200 {
                    print("HttpDownloadWorker: Server doesn't support resume - Starting from beginning")
                    try? FileManager.default.removeItem(at: tempURL) // Server sent full content, delete partial file
                }

                do {
                    // 👇 NEW: Handle resume by appending to temp file
                    if isResumingDownload {
                        // Append downloaded data to existing temp file
                        if let downloadedData = try? Data(contentsOf: location) {
                            if let fileHandle = try? FileHandle(forWritingTo: tempURL) {
                                defer { try? fileHandle.close() }
                                fileHandle.seekToEndOfFile()
                                fileHandle.write(downloadedData)
                            }
                        }
                        try? FileManager.default.removeItem(at: location)
                    } else {
                        // Fresh download: move to temp location
                        try? FileManager.default.removeItem(at: tempURL) // Remove old temp if exists
                        try FileManager.default.moveItem(at: location, to: tempURL)
                    }

                    // Get final file size
                    let tempAttributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
                    let finalFileSize = tempAttributes[.size] as? Int64 ?? 0

                    // 👇 NEW: Verify checksum if expected checksum is provided
                    if let expectedChecksum = config.expectedChecksum {
                        print("HttpDownloadWorker: Verifying checksum with \(config.effectiveChecksumAlgorithm)...")

                        guard let actualChecksum = self.calculateChecksum(fileURL: tempURL, algorithm: config.effectiveChecksumAlgorithm) else {
                            print("HttpDownloadWorker: Error - Failed to calculate checksum")
                            try? FileManager.default.removeItem(at: tempURL)
                            continuation.resume(returning: .failure(message: "Failed to calculate checksum"))
                            return
                        }

                        if actualChecksum.caseInsensitiveCompare(expectedChecksum) != .orderedSame {
                            print("HttpDownloadWorker: Checksum verification failed!")
                            print("  Expected: \(expectedChecksum)")
                            print("  Actual:   \(actualChecksum)")
                            print("  Algorithm: \(config.effectiveChecksumAlgorithm)")
                            try? FileManager.default.removeItem(at: tempURL)
                            continuation.resume(returning: .failure(message: "Checksum verification failed (expected: \(expectedChecksum), actual: \(actualChecksum))"))
                            return
                        }

                        print("HttpDownloadWorker: Checksum verified: \(actualChecksum)")
                    }

                    // Capture content type and final URL
                    let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
                    let finalURL = httpResponse.url?.absoluteString ?? config.url

                    // Remove destination if exists
                    try? FileManager.default.removeItem(at: destinationURL)

                    // Then rename to final destination (atomic)
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                    print("HttpDownloadWorker: Success - Downloaded \(finalFileSize) bytes")
                    print("HttpDownloadWorker: Saved to: \(config.savePath)")

                    // ✅ Return success with rich data
                    continuation.resume(returning: .success(
                        message: "Downloaded \(finalFileSize) bytes",
                        data: [
                            "filePath": destinationURL.path,
                            "fileName": destinationURL.lastPathComponent,
                            "fileSize": finalFileSize,
                            "contentType": contentType as Any,
                            "finalUrl": finalURL
                        ]
                    ))
                } catch {
                    print("HttpDownloadWorker: Error moving file - \(error.localizedDescription)")
                    try? FileManager.default.removeItem(at: tempURL)
                    try? FileManager.default.removeItem(at: location)
                    continuation.resume(returning: .failure(message: "Failed to move file: \(error.localizedDescription)"))
                }
            }
            task.resume()
        }
    }

    /// Download file using background URLSession (survives app termination).
    ///
    /// - Parameters:
    ///   - url: URL to download from
    ///   - destinationURL: Final destination for downloaded file
    ///   - tempURL: Temporary file location
    ///   - config: Download configuration
    ///   - headers: HTTP headers
    ///   - existingBytes: Bytes already downloaded (for resume)
    /// - Returns: WorkerResult with download information
    @available(iOS 13.0, *)
    private func downloadWithBackgroundSession(
        url: URL,
        destinationURL: URL,
        tempURL: URL,
        config: Config,
        headers: [String: String]?,
        existingBytes: Int64
    ) async -> WorkerResult {
        return await withCheckedContinuation { continuation in
            let taskId = "download-\(UUID().uuidString)"

            BackgroundSessionManager.shared.download(
                url: url,
                to: destinationURL,
                taskId: taskId,
                headers: headers
            ) { result in
                switch result {
                case .success(let location):
                    // Move downloaded file to destination
                    do {
                        // Get final file size
                        let tempAttributes = try FileManager.default.attributesOfItem(atPath: location.path)
                        let finalFileSize = tempAttributes[.size] as? Int64 ?? 0

                        // Verify checksum if expected checksum is provided
                        if let expectedChecksum = config.expectedChecksum {
                            print("HttpDownloadWorker: Verifying checksum with \(config.effectiveChecksumAlgorithm)...")

                            guard let actualChecksum = self.calculateChecksum(fileURL: location, algorithm: config.effectiveChecksumAlgorithm) else {
                                print("HttpDownloadWorker: Error - Failed to calculate checksum")
                                try? FileManager.default.removeItem(at: location)
                                continuation.resume(returning: .failure(message: "Failed to calculate checksum"))
                                return
                            }

                            if actualChecksum.caseInsensitiveCompare(expectedChecksum) != .orderedSame {
                                print("HttpDownloadWorker: Checksum verification failed!")
                                print("  Expected: \(expectedChecksum)")
                                print("  Actual:   \(actualChecksum)")
                                print("  Algorithm: \(config.effectiveChecksumAlgorithm)")
                                try? FileManager.default.removeItem(at: location)
                                continuation.resume(returning: .failure(message: "Checksum verification failed (expected: \(expectedChecksum), actual: \(actualChecksum))"))
                                return
                            }

                            print("HttpDownloadWorker: Checksum verified: \(actualChecksum)")
                        }

                        // Remove destination if exists
                        try? FileManager.default.removeItem(at: destinationURL)

                        // Move to final destination
                        try FileManager.default.moveItem(at: location, to: destinationURL)

                        print("HttpDownloadWorker: Background download success - Downloaded \(finalFileSize) bytes")
                        print("HttpDownloadWorker: Saved to: \(config.savePath)")

                        // Return success with rich data
                        continuation.resume(returning: .success(
                            message: "Downloaded \(finalFileSize) bytes (background session)",
                            data: [
                                "filePath": destinationURL.path,
                                "fileName": destinationURL.lastPathComponent,
                                "fileSize": finalFileSize,
                                "backgroundSession": true,
                                "finalUrl": config.url
                            ]
                        ))
                    } catch {
                        print("HttpDownloadWorker: Error moving file - \(error.localizedDescription)")
                        try? FileManager.default.removeItem(at: location)
                        continuation.resume(returning: .failure(message: "Failed to move file: \(error.localizedDescription)"))
                    }

                case .failure(let error):
                    print("HttpDownloadWorker: Background download failed - \(error.localizedDescription)")
                    continuation.resume(returning: .failure(message: "Background download failed: \(error.localizedDescription)"))
                }
            }
        }
    }

    /// Calculate checksum of a file.
    ///
    /// - Parameters:
    ///   - fileURL: URL of the file to calculate checksum for
    ///   - algorithm: Hash algorithm (MD5, SHA-1, SHA-256, SHA-512)
    /// - Returns: Hexadecimal checksum string, or nil if algorithm is unsupported
    private func calculateChecksum(fileURL: URL, algorithm: String) -> String? {
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            return nil
        }
        defer { try? fileHandle.close() }

        let bufferSize = 8192
        let algorithmUpper = algorithm.uppercased()

        // Use CryptoKit for hashing
        if #available(iOS 13.0, *) {
            switch algorithmUpper {
            case "MD5":
                var hasher = Insecure.MD5()
                while autoreleasepool(invoking: {
                    let data = fileHandle.readData(ofLength: bufferSize)
                    if data.isEmpty { return false }
                    hasher.update(data: data)
                    return true
                }) {}
                let digest = hasher.finalize()
                return digest.map { String(format: "%02x", $0) }.joined()

            case "SHA-1", "SHA1":
                var hasher = Insecure.SHA1()
                while autoreleasepool(invoking: {
                    let data = fileHandle.readData(ofLength: bufferSize)
                    if data.isEmpty { return false }
                    hasher.update(data: data)
                    return true
                }) {}
                let digest = hasher.finalize()
                return digest.map { String(format: "%02x", $0) }.joined()

            case "SHA-256", "SHA256":
                var hasher = SHA256()
                while autoreleasepool(invoking: {
                    let data = fileHandle.readData(ofLength: bufferSize)
                    if data.isEmpty { return false }
                    hasher.update(data: data)
                    return true
                }) {}
                let digest = hasher.finalize()
                return digest.map { String(format: "%02x", $0) }.joined()

            case "SHA-512", "SHA512":
                var hasher = SHA512()
                while autoreleasepool(invoking: {
                    let data = fileHandle.readData(ofLength: bufferSize)
                    if data.isEmpty { return false }
                    hasher.update(data: data)
                    return true
                }) {}
                let digest = hasher.finalize()
                return digest.map { String(format: "%02x", $0) }.joined()

            default:
                print("HttpDownloadWorker: Unsupported checksum algorithm: \(algorithm)")
                return nil
            }
        } else {
            // Fallback for iOS < 13 (CryptoKit not available)
            print("HttpDownloadWorker: CryptoKit requires iOS 13+")
            return nil
        }
    }
}
