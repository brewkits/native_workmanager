import Foundation
import CryptoKit
import Photos

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

    // Timeout default lives in HttpConstants.downloadTimeoutMs
    
    private var currentDownloadTask: URLSessionDownloadTask?
    private var isStopped: Bool = false

    func stop() {
        isStopped = true
        currentDownloadTask?.cancel()
        print("HttpDownloadWorker: Stop signal received, download cancelled.")
    }

    struct Config: Codable {
        let url: String
        let savePath: String
        let headers: [String: String]?
        let timeoutMs: Int64?
        let enableResume: Bool?
        let expectedChecksum: String?
        let checksumAlgorithm: String?
        let useBackgroundSession: Bool?
        let skipExisting: Bool?

        // Sprint 1 - Feature 5: Advanced file handling
        let onDuplicate: String?              // "overwrite" (default) | "rename" | "skip"
        let moveToPublicDownloads: Bool?      // Copy to iOS Downloads folder after download
        let saveToGallery: Bool?              // Save image/video to Photos library after download
        let extractAfterDownload: Bool?       // Extract archive after download
        let extractPath: String?              // Destination directory for extraction
        let deleteArchiveAfterExtract: Bool?  // Delete archive after successful extraction

        // Sprint 3 - Cookie support
        let cookies: [String: String]?

        // Sprint 3 - Auth layer
        let authToken: String?
        let authHeaderTemplate: String?       // Default: "Bearer {accessToken}"

        // T3-6 - Bandwidth throttling (bytes/s; nil = no limit)
        let bandwidthLimitBytesPerSecond: Int64?

        var timeout: TimeInterval {
            TimeInterval((timeoutMs ?? HttpConstants.downloadTimeoutMs) / 1000)
        }

        var resumeEnabled: Bool {
            enableResume ?? true
        }

        var effectiveChecksumAlgorithm: String {
            checksumAlgorithm ?? HttpConstants.defaultChecksumAlgorithm
        }

        var shouldUseBackgroundSession: Bool { useBackgroundSession ?? false }
        var shouldSkipExisting: Bool { skipExisting ?? false }
        /// True when savePath is a directory (ends with `/`). Filename is resolved from server response.
        var isDirectory: Bool { savePath.hasSuffix("/") }

        var effectiveOnDuplicate: String { onDuplicate ?? "overwrite" }
        var effectiveMoveToPublicDownloads: Bool { moveToPublicDownloads ?? false }
        var effectiveSaveToGallery: Bool { saveToGallery ?? false }
        var effectiveExtractAfterDownload: Bool { extractAfterDownload ?? false }
        var effectiveDeleteArchiveAfterExtract: Bool { deleteArchiveAfterExtract ?? false }
        var effectiveAuthHeaderTemplate: String { authHeaderTemplate ?? HttpConstants.defaultAuthHeaderTemplate }
    }

    func doWork(input: String?) async throws -> WorkerResult {
        guard let input = input, !input.isEmpty else {
            print("HttpDownloadWorker: Error - Empty or null input")
            return .failure(message: "Empty or null input")
        }

        // Parse configuration
        guard let data = input.data(using: .utf8) else {
            print("HttpDownloadWorker: Error - Invalid UTF-8 encoding")
            return .failure(message: "Invalid input encoding")
        }

        // Extract __taskId injected by the plugin for progress reporting.
        // Parsed from raw JSON so the Config struct stays Codable-clean
        // (same pattern as Android's HttpDownloadWorker).
        let taskIdForProgress: String? = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
            .flatMap { $0["__taskId"] as? String }

        let config: Config
        do {
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            print("HttpDownloadWorker: Error parsing JSON config: \(error)")
            return .failure(message: "Invalid JSON config: \(error.localizedDescription)")
        }

        // Skip download if destination already exists and skipExisting is enabled
        // (only for non-directory paths where we already know the final filename)
        if config.shouldSkipExisting && !config.isDirectory && FileManager.default.fileExists(atPath: config.savePath) {
            print("HttpDownloadWorker: skipExisting=true and file already exists — skipping")
            let size = (try? FileManager.default.attributesOfItem(atPath: config.savePath))?[.size] as? Int64 ?? 0
            return .success(
                message: "File already exists, download skipped",
                data: ["filePath": config.savePath, "fileSize": size, "skipped": true]
            )
        }

        // onDuplicate: pre-download check for known (non-directory) paths
        if !config.isDirectory {
            let duplicate = config.effectiveOnDuplicate
            if duplicate == "skip" && FileManager.default.fileExists(atPath: config.savePath) {
                print("HttpDownloadWorker: onDuplicate=skip and file exists — skipping")
                let size = (try? FileManager.default.attributesOfItem(atPath: config.savePath))?[.size] as? Int64 ?? 0
                return .success(
                    message: "File already exists, download skipped (onDuplicate=skip)",
                    data: ["filePath": config.savePath, "fileSize": size, "skipped": true]
                )
            } else if duplicate == "overwrite" {
                // Remove existing file so the download can overwrite it (existing behaviour)
                if FileManager.default.fileExists(atPath: config.savePath) {
                    try? FileManager.default.removeItem(atPath: config.savePath)
                }
            }
            // "rename" is handled when the file is moved to its final destination (see resolveDestination)
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

        // For directory mode, destination is resolved after response headers arrive.
        // Use a sentinel temp path until the real filename is known.
        var destinationURL = URL(fileURLWithPath: config.isDirectory
            ? config.savePath + "download"
            : config.savePath)
        // NET-021: use URL-hash sentinel in directory mode so concurrent downloads
        // to the same directory don't overwrite each other's partial data.
        var tempURL = URL(fileURLWithPath: config.isDirectory
            ? config.savePath + directoryModeTempFilename(for: config.url)
            : config.savePath + ".tmp")

        // Create directory (or parent directory) if needed
        let parentDir = config.isDirectory
            ? URL(fileURLWithPath: config.savePath)
            : destinationURL.deletingLastPathComponent()
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

        // M-06: Re-resolve symlinks now that the directory exists.
        // On physical devices /var is a symlink to /private/var; resolvingSymlinksInPath()
        // only resolves the chain when the path actually exists. If we skip this step the
        // sandbox-path checks in SecurityValidator silently fail and the temp file is written
        // to the wrong (unresolved) path.
        destinationURL = destinationURL.resolvingSymlinksInPath()
        tempURL = tempURL.resolvingSymlinksInPath()

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
            request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: HttpConstants.headerRange)
            // If-Range: only honour the Range if the file hasn't changed on the server.
            // NET-003: Store ETag sidecar alongside tempURL (not savePath) so that directory-mode
            // concurrent downloads to the same folder don't overwrite each other's sidecar.
            let etagSidecar = URL(fileURLWithPath: tempURL.path + HttpConstants.etagSidecarSuffix)
            if let stored = try? String(contentsOf: etagSidecar, encoding: .utf8), !stored.isEmpty {
                request.setValue(stored.trimmingCharacters(in: .whitespacesAndNewlines),
                                 forHTTPHeaderField: HttpConstants.headerIfRange)
            }
            print("HttpDownloadWorker: Resuming download from byte \(existingBytes)")
        }

        // Add custom headers
        if let headers = config.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Sprint 3: Cookie support
        if let cookies = config.cookies, !cookies.isEmpty {
            let cookieHeader = cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
            request.addValue(cookieHeader, forHTTPHeaderField: HttpConstants.headerCookie)
        }

        // Sprint 3: Auth layer
        if let authToken = config.authToken {
            let headerValue = config.effectiveAuthHeaderTemplate
                .replacingOccurrences(of: "{accessToken}", with: authToken)
            request.addValue(headerValue, forHTTPHeaderField: HttpConstants.headerAuthorization)
        }

        // T3-7: HMAC-SHA256 request signing
        let rawDictForSigning = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
        if let signingCfg = RequestSigner.Config.from(rawDictForSigning?["requestSigning"] as? [String: Any]) {
            RequestSigner.sign(request: &request, config: signingCfg)
        }

        // Sprint 2: per-host concurrency — block here until a permit is available.
        // The permit is released after the download completes (success, failure, or skip).
        let host = URL(string: config.url)?.host ?? config.url
        HostConcurrencyManager.shared.acquire(host: host)
        defer { HostConcurrencyManager.shared.release(host: host) }

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

        // T3-6: Throttled foreground download (iOS 15+) when bandwidth limit is configured
        if #available(iOS 15.0, *),
           let bwLimit = config.bandwidthLimitBytesPerSecond, bwLimit > 0 {
            return await throttledForegroundDownload(
                request: request,
                tempURL: tempURL,
                destinationURL: destinationURL,
                config: config,
                existingBytes: existingBytes,
                bandwidthLimit: bwLimit,
                taskIdForProgress: taskIdForProgress
            )
        } else if let bwLimit = config.bandwidthLimitBytesPerSecond, bwLimit > 0 {
            print("HttpDownloadWorker: bandwidth throttling requires iOS 15+, proceeding unthrottled")
        }

        // Execute download using foreground session (iOS 13+ compatible)
        return await withCheckedContinuation { continuation in
            // Declared before the task so the completion handler can capture it by reference,
            // keeping the KVO observer alive for the full duration of the download.
            var progressObserver: NSKeyValueObservation?

            let task = URLSession.shared.downloadTask(with: request) { [self] location, response, error in
                // Invalidate progress observer once the download finishes.
                progressObserver?.invalidate()
                progressObserver = nil
                
                // If stopped by expiration handler
                if self.isStopped {
                    try? FileManager.default.removeItem(at: tempURL)
                    continuation.resume(returning: .failure(message: "Task stopped by OS expiration"))
                    return
                }
                
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
                let isPartialContent = statusCode == HttpConstants.partialContent
                let isFullContent = (200..<300).contains(statusCode)
                let isResumingDownload = existingBytes > 0 && isPartialContent

                // 416 Range Not Satisfiable: our .tmp is stale (server file changed). Delete and signal retry.
                if statusCode == HttpConstants.rangeNotSatisfiable {
                    print("HttpDownloadWorker: 416 Range Not Satisfiable — deleting stale .tmp, restart on retry")
                    try? FileManager.default.removeItem(at: tempURL)
                    try? FileManager.default.removeItem(atPath: tempURL.path + HttpConstants.etagSidecarSuffix)
                    continuation.resume(returning: .failure(
                        message: "Resume position invalid (file may have changed). Retry to restart download."
                    ))
                    return
                }

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
                } else if existingBytes > 0 && statusCode == HttpConstants.httpOk {
                    print("HttpDownloadWorker: Server doesn't support resume - Starting from beginning")
                    try? FileManager.default.removeItem(at: tempURL)
                    try? FileManager.default.removeItem(atPath: tempURL.path + HttpConstants.etagSidecarSuffix)
                }

                // 👇 Feature 4: Resolve filename from Content-Disposition or URL when savePath is a directory
                let cdHeader = httpResponse.value(forHTTPHeaderField: "Content-Disposition")
                let serverSuggestedName: String? = self.parseFilenameFromContentDisposition(cdHeader)
                if config.isDirectory {
                    let resolvedName = serverSuggestedName
                        ?? self.sanitizeFilename(httpResponse.url?.lastPathComponent ?? "download")
                    let name = resolvedName.isEmpty ? "download" : resolvedName
                    destinationURL = URL(fileURLWithPath: config.savePath + name)
                    // LOGIC-001: keep tempURL as the sentinel file in directory mode so that partial
                    // download data is preserved across retries. Only destinationURL changes here;
                    // the final rename moves tempURL (sentinel) → destinationURL (resolved name).
                    print("HttpDownloadWorker: Directory mode — resolved filename: \(name)")

                    // skipExisting check for directory mode (now we know actual path)
                    if config.shouldSkipExisting && FileManager.default.fileExists(atPath: destinationURL.path) {
                        print("HttpDownloadWorker: skipExisting=true and resolved file exists — skipping")
                        let size = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path))?[.size] as? Int64 ?? 0
                        try? FileManager.default.removeItem(at: location)
                        var skipData: [String: Any] = ["filePath": destinationURL.path, "fileSize": size, "skipped": true]
                        if let n = serverSuggestedName { skipData["serverSuggestedName"] = n }
                        continuation.resume(returning: .success(message: "File already exists, download skipped", data: skipData))
                        return
                    }
                }

                do {
                    // 👇 NEW: Handle resume by appending to temp file
                    if isResumingDownload {
                        // Stream-append downloaded chunk to existing temp file.
                        // Avoids loading the entire chunk into RAM (OOM risk for large files).
                        do {
                            let chunkHandle = try FileHandle(forReadingFrom: location)
                            defer { do { try chunkHandle.close() } catch { print("HttpDownloadWorker: chunkHandle.close error: \(error)") } }
                            let destHandle = try FileHandle(forWritingTo: tempURL)
                            defer { do { try destHandle.close() } catch { print("HttpDownloadWorker: destHandle.close error: \(error)") } }
                            destHandle.seekToEndOfFile()
                            let bufferSize = HttpConstants.resumeChunkSize
                            if #available(iOS 13.4, *) {
                                // Use throwing API — guards against disk-full / memory-pressure ObjC exceptions
                                while true {
                                    guard let chunk = try chunkHandle.read(upToCount: bufferSize),
                                          !chunk.isEmpty else { break }
                                    try destHandle.write(contentsOf: chunk)
                                }
                            } else {
                                // Legacy ObjC bridge (iOS 13.0–13.3); rare ObjC exceptions not catchable in Swift
                                while true {
                                    let chunk = chunkHandle.readData(ofLength: bufferSize)
                                    if chunk.isEmpty { break }
                                    destHandle.write(chunk)
                                }
                            }
                        } catch {
                            try? FileManager.default.removeItem(at: location)
                            continuation.resume(returning: .failure(message: "Failed to append resumed chunk: \(error.localizedDescription)"))
                            return
                        }
                        try? FileManager.default.removeItem(at: location)
                    } else {
                        // Fresh download: move to temp location
                        try? FileManager.default.removeItem(at: tempURL) // Remove old temp if exists
                        try FileManager.default.moveItem(at: location, to: tempURL)
                        // Save ETag/Last-Modified for If-Range validation on future resume attempts
                        if !isResumingDownload {
                            let etag = httpResponse.value(forHTTPHeaderField: HttpConstants.headerETag)
                                ?? httpResponse.value(forHTTPHeaderField: HttpConstants.headerLastModified)
                            if let etag = etag {
                                try? etag.write(toFile: tempURL.path + HttpConstants.etagSidecarSuffix, atomically: true, encoding: .utf8)
                            }
                        }
                    }

                    // Get final file size
                    let tempAttributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
                    let finalFileSize = tempAttributes[.size] as? Int64 ?? 0

                    // 👇 NEW: Verify checksum if expected checksum is provided
                    if let expectedChecksum = config.expectedChecksum {
                        print("HttpDownloadWorker: Verifying checksum with \(config.effectiveChecksumAlgorithm)...")

                        guard let actualChecksum = self.calculateChecksum(fileURL: tempURL, algorithm: config.effectiveChecksumAlgorithm, taskId: taskIdForProgress) else {
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

                    // onDuplicate=rename: find a free filename before placing the file
                    if config.effectiveOnDuplicate == "rename" {
                        destinationURL = self.resolveRenamedURL(destinationURL)
                    } else {
                        // Remove destination if exists (overwrite path)
                        try? FileManager.default.removeItem(at: destinationURL)
                    }

                    // Then rename to final destination (atomic)
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                    // Clean up ETag sidecar after successful download
                    try? FileManager.default.removeItem(atPath: tempURL.path + HttpConstants.etagSidecarSuffix)

                    print("HttpDownloadWorker: Success - Downloaded \(finalFileSize) bytes")
                    print("HttpDownloadWorker: Saved to: \(destinationURL.path)")

                    // Post-download actions
                    self.performPostDownloadActions(config: config, filePath: destinationURL.path)

                    // ✅ Return success with rich data
                    var resultData: [String: Any] = [
                        "filePath": destinationURL.path,
                        "fileName": destinationURL.lastPathComponent,
                        "fileSize": finalFileSize,
                        "contentType": contentType as Any,
                        "finalUrl": finalURL
                    ]
                    if let name = serverSuggestedName { resultData["serverSuggestedName"] = name }
                    continuation.resume(returning: .success(
                        message: "Downloaded \(finalFileSize) bytes",
                        data: resultData
                    ))
                } catch {
                    print("HttpDownloadWorker: Error moving file - \(error.localizedDescription)")
                    try? FileManager.default.removeItem(at: tempURL)
                    try? FileManager.default.removeItem(at: location)
                    continuation.resume(returning: .failure(message: "Failed to move file: \(error.localizedDescription)"))
                }
            }
            // Track progress via KVO on URLSessionDownloadTask.progress (iOS 11+).
            // Mirrors Android's ProgressResponseBody: smoothed speed + ETA forwarded
            // to Flutter via ProgressReporter.
            if let reportTaskId = taskIdForProgress {
                let fileName = URL(fileURLWithPath: config.savePath).lastPathComponent
                let speedTracker = DownloadSpeedTracker()
                progressObserver = task.progress.observe(\.fractionCompleted, options: [.new]) { progress, _ in
                    guard progress.totalUnitCount > 0 else { return }
                    let pct = Int(progress.fractionCompleted * 100)
                    let downloaded = progress.completedUnitCount
                    let total = progress.totalUnitCount
                    let (speed, eta) = speedTracker.update(bytesNow: downloaded, totalBytes: total)
                    ProgressReporter.shared.report(
                        taskId: reportTaskId,
                        progress: pct,
                        message: "Downloading \(fileName)…",
                        bytesDownloaded: downloaded,
                        totalBytes: total,
                        networkSpeed: speed,
                        timeRemainingMs: eta
                    )
                }
            }

            task.resume()
        }
    }

    /// Download file using background URLSession (survives app termination).
    ///
    // MARK: - Throttled foreground download (iOS 15+)

    /// Streaming download with token-bucket bandwidth throttling.
    ///
    /// Uses `URLSession.bytes(for:)` to obtain an `AsyncBytes` stream so that
    /// each 64 KB chunk can be rate-limited before being written to disk.
    /// Falls back to the standard foreground path on iOS < 15 (caller's responsibility).
    @available(iOS 15.0, *)
    private func throttledForegroundDownload(
        request: URLRequest,
        tempURL: URL,
        destinationURL: URL,
        config: Config,
        existingBytes: Int64,
        bandwidthLimit: Int64,
        taskIdForProgress: String?
    ) async -> WorkerResult {
        let throttle = BandwidthThrottle(maxBytesPerSecond: bandwidthLimit)

        do {
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(message: "Invalid response")
            }

            let statusCode = httpResponse.statusCode

            if statusCode == HttpConstants.rangeNotSatisfiable {
                try? FileManager.default.removeItem(at: tempURL)
                try? FileManager.default.removeItem(atPath: tempURL.path + HttpConstants.etagSidecarSuffix)
                return .failure(message: "Resume position invalid (file may have changed). Retry to restart download.")
            }

            let isPartialContent = statusCode == HttpConstants.partialContent
            let isFullContent = (200..<300).contains(statusCode)
            guard isPartialContent || isFullContent else {
                return .failure(message: "HTTP \(statusCode)")
            }

            let contentLength = httpResponse.expectedContentLength
            if contentLength > 0, !SecurityValidator.validateContentLength(contentLength) {
                return .failure(message: "Download size exceeds limit")
            }

            // Prepare output file
            if !FileManager.default.fileExists(atPath: tempURL.path) {
                FileManager.default.createFile(atPath: tempURL.path, contents: nil)
            }
            let fileHandle = try FileHandle(forWritingTo: tempURL)
            defer { try? fileHandle.close() }
            if existingBytes > 0 && isPartialContent {
                try fileHandle.seekToEnd()
            }

            // Stream with 64 KB chunks and token-bucket throttling
            let chunkSize = 65_536
            var chunkBuffer = [UInt8]()
            chunkBuffer.reserveCapacity(chunkSize)
            var totalBytesWritten = existingBytes
            let totalExpected = contentLength > 0 ? (existingBytes + contentLength) : -1

            for try await byte in asyncBytes {
                chunkBuffer.append(byte)
                if chunkBuffer.count >= chunkSize {
                    let data = Data(chunkBuffer)
                    if #available(iOS 13.4, *) {
                        try fileHandle.write(contentsOf: data)
                    } else {
                        fileHandle.write(data)
                    }
                    await throttle.consume(chunkBuffer.count)
                    totalBytesWritten += Int64(chunkBuffer.count)
                    if let taskId = taskIdForProgress, totalExpected > 0 {
                        let pct = Int(Double(totalBytesWritten) / Double(totalExpected) * 100)
                        ProgressReporter.shared.report(
                            taskId: taskId,
                            progress: pct,
                            message: "Downloading \(destinationURL.lastPathComponent)…",
                            bytesDownloaded: totalBytesWritten,
                            totalBytes: totalExpected,
                            networkSpeed: nil,
                            timeRemainingMs: nil
                        )
                    }
                    chunkBuffer.removeAll(keepingCapacity: true)
                }
            }
            // Flush remaining bytes
            if !chunkBuffer.isEmpty {
                let data = Data(chunkBuffer)
                if #available(iOS 13.4, *) {
                    try fileHandle.write(contentsOf: data)
                } else {
                    fileHandle.write(data)
                }
                await throttle.consume(chunkBuffer.count)
                totalBytesWritten += Int64(chunkBuffer.count)
            }
            try fileHandle.close()

            // Save ETag for future resume attempts
            if !isPartialContent {
                let etag = httpResponse.value(forHTTPHeaderField: HttpConstants.headerETag)
                    ?? httpResponse.value(forHTTPHeaderField: HttpConstants.headerLastModified)
                if let etag = etag {
                    try? etag.write(toFile: tempURL.path + HttpConstants.etagSidecarSuffix, atomically: true, encoding: .utf8)
                }
            }

            // Checksum verification
            if let expectedChecksum = config.expectedChecksum {
                guard let actualChecksum = self.calculateChecksum(fileURL: tempURL, algorithm: config.effectiveChecksumAlgorithm, taskId: nil) else {
                    try? FileManager.default.removeItem(at: tempURL)
                    return .failure(message: "Failed to calculate checksum")
                }
                if actualChecksum.lowercased() != expectedChecksum.lowercased() {
                    try? FileManager.default.removeItem(at: tempURL)
                    return .failure(message: "Checksum verification failed (expected: \(expectedChecksum), actual: \(actualChecksum))")
                }
            }

            let finalFileSize = (try? FileManager.default.attributesOfItem(atPath: tempURL.path))?[.size] as? Int64 ?? 0
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
            let finalURL = httpResponse.url?.absoluteString ?? config.url

            // Resolve final destination (rename/overwrite)
            var finalDestination = destinationURL
            if config.effectiveOnDuplicate == "rename" {
                finalDestination = resolveRenamedURL(destinationURL)
            } else {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: finalDestination)
            try? FileManager.default.removeItem(atPath: tempURL.path + HttpConstants.etagSidecarSuffix)

            performPostDownloadActions(config: config, filePath: finalDestination.path)

            return .success(
                message: "Downloaded \(finalFileSize) bytes (throttled)",
                data: [
                    "filePath": finalDestination.path,
                    "fileName": finalDestination.lastPathComponent,
                    "fileSize": finalFileSize,
                    "contentType": contentType as Any,
                    "finalUrl": finalURL
                ]
            )
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return .failure(message: error.localizedDescription)
        }
    }

    // MARK: - Background session download

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

                            guard let actualChecksum = self.calculateChecksum(fileURL: location, algorithm: config.effectiveChecksumAlgorithm, taskId: nil) else {
                                print("HttpDownloadWorker: Error - Failed to calculate checksum")
                                try? FileManager.default.removeItem(at: location)
                                continuation.resume(returning: .failure(message: "Failed to calculate checksum"))
                                return
                            }

                            if actualChecksum.lowercased() != expectedChecksum.lowercased() {
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

    // MARK: - Post-download actions

    /// Resolve a free filename by appending _1, _2, … when `onDuplicate=rename`.
    /// M-001 FIX: Capped at 10,000 iterations to prevent an unbounded loop on directories
    /// that already contain thousands of similarly-named files.  Falls back to a timestamp
    /// suffix so the download always completes.
    func resolveRenamedURL(_ url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let dir = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var index = 1
        var candidate = url
        repeat {
            let newName = ext.isEmpty ? "\(base)_\(index)" : "\(base)_\(index).\(ext)"
            candidate = dir.appendingPathComponent(newName)
            index += 1
        } while FileManager.default.fileExists(atPath: candidate.path) && index <= 10_000
        if FileManager.default.fileExists(atPath: candidate.path) {
            let ts = Int64(Date().timeIntervalSince1970 * 1000)
            let fallbackName = ext.isEmpty ? "\(base)_\(ts)" : "\(base)_\(ts).\(ext)"
            candidate = dir.appendingPathComponent(fallbackName)
        }
        return candidate
    }

    /// Run optional post-download actions: saveToGallery, moveToPublicDownloads, extractAfterDownload.
    private func performPostDownloadActions(config: Config, filePath: String) {
        let fileURL = URL(fileURLWithPath: filePath)

        // saveToGallery: save image or video to the Photos library
        if config.effectiveSaveToGallery {
            let ext = fileURL.pathExtension.lowercased()
            if ["jpg", "jpeg", "png", "gif", "heic"].contains(ext) {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
                }, completionHandler: { success, error in
                    if let error = error {
                        print("HttpDownloadWorker: saveToGallery image error: \(error.localizedDescription)")
                    } else if success {
                        print("HttpDownloadWorker: Image saved to gallery")
                    }
                })
            } else if ["mp4", "mov", "m4v"].contains(ext) {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
                }, completionHandler: { success, error in
                    if let error = error {
                        print("HttpDownloadWorker: saveToGallery video error: \(error.localizedDescription)")
                    } else if success {
                        print("HttpDownloadWorker: Video saved to gallery")
                    }
                })
            }
        }

        // moveToPublicDownloads: copy to the iOS Downloads folder (visible in Files app)
        if config.effectiveMoveToPublicDownloads {
            if let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                let destURL = downloadsDir.appendingPathComponent(fileURL.lastPathComponent)
                do {
                    // Overwrite if already present
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.copyItem(at: fileURL, to: destURL)
                    print("HttpDownloadWorker: Copied to public Downloads: \(destURL.path)")
                } catch {
                    print("HttpDownloadWorker: moveToPublicDownloads error: \(error.localizedDescription)")
                }
            }
        }

        // extractAfterDownload: disabled in v1.1.0 for Zero Dependencies
        if config.effectiveExtractAfterDownload {
            print("HttpDownloadWorker: extractAfterDownload is disabled in v1.1.0 to achieve Zero Dependencies. Please use the Dart 'archive' package.")
        }
    }

    /// Calculate checksum of a file.
    ///
    /// - Parameters:
    ///   - fileURL: URL of the file to calculate checksum for
    ///   - algorithm: Hash algorithm (MD5, SHA-1, SHA-256, SHA-512)
    ///   - taskId: Task ID for progress reporting
    /// - Returns: Hexadecimal checksum string, or nil if algorithm is unsupported
    private func calculateChecksum(fileURL: URL, algorithm: String, taskId: String?) -> String? {
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            return nil
        }
        defer { try? fileHandle.close() }

        let bufferSize = 1024 * 1024 // 1MB buffer
        let algorithmUpper = algorithm.uppercased()
        
        let totalSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path))?[.size] as? Int64 ?? 0
        var readSoFar: Int64 = 0

        // Use CryptoKit for hashing
        if #available(iOS 13.0, *) {
            // Internal helper to update progress
            let reportProgress: (Int) -> Void = { pct in
                if let tid = taskId, totalSize > 10 * 1024 * 1024 {
                    ProgressReporter.shared.report(
                        taskId: tid,
                        progress: pct,
                        message: "Verifying checksum (\(pct)%)…",
                        bytesDownloaded: readSoFar,
                        totalBytes: totalSize
                    )
                }
            }

            switch algorithmUpper {
            case "MD5":
                var hasher = Insecure.MD5()
                while autoreleasepool(invoking: {
                    let data = fileHandle.readData(ofLength: bufferSize)
                    if data.isEmpty { return false }
                    hasher.update(data: data)
                    readSoFar += Int64(data.count)
                    reportProgress(Int(readSoFar * 100 / totalSize))
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
                    readSoFar += Int64(data.count)
                    reportProgress(Int(readSoFar * 100 / totalSize))
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
                    readSoFar += Int64(data.count)
                    reportProgress(Int(readSoFar * 100 / totalSize))
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
                    readSoFar += Int64(data.count)
                    reportProgress(Int(readSoFar * 100 / totalSize))
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

    /// Parse filename from RFC 6266 Content-Disposition header.
    /// Prefers `filename*=UTF-8''<encoded>` over `filename=<value>`.
    func parseFilenameFromContentDisposition(_ header: String?) -> String? {
        guard let header = header, !header.isEmpty else { return nil }
        // Try filename* (RFC 5987 encoded) first
        if let range = header.range(of: #"filename\*\s*=\s*UTF-8''([^;\s]+)"#,
                                    options: [.regularExpression, .caseInsensitive]) {
            let full = String(header[range])
            if let eqRange = full.range(of: "''") {
                let encoded = String(full[eqRange.upperBound...])
                if let decoded = encoded.removingPercentEncoding, !decoded.isEmpty {
                    return sanitizeFilename(decoded)
                }
            }
        }
        // Fall back to plain filename=
        if let range = header.range(of: #"filename\s*=\s*(?:"([^"]+)"|([^;\s]+))"#,
                                    options: [.regularExpression, .caseInsensitive]) {
            var name = String(header[range])
            // Strip the `filename=` prefix and quotes
            if let eqIdx = name.firstIndex(of: "=") {
                name = String(name[name.index(after: eqIdx)...])
                    .trimmingCharacters(in: .init(charactersIn: "\" "))
            }
            // CROSS-002: percent-decode the plain filename= value (e.g. "hello%20world.pdf" → "hello world.pdf")
            // to match Android's URLDecoder.decode() behaviour.
            let decoded = name.removingPercentEncoding ?? name
            let sanitized = sanitizeFilename(decoded)
            return sanitized.isEmpty ? nil : sanitized
        }
        return nil
    }

    /// Remove path separators and other unsafe characters from a filename.
    func sanitizeFilename(_ name: String) -> String {
        // NET-013: explicitly replace ".." to prevent any path-traversal confusion after
        // percent-decoding (e.g. an attacker-controlled Content-Disposition: filename*=UTF-8''..%2F..%2Fetc).
        name.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "..", with: "_", options: .literal)
            .replacingOccurrences(of: #"[/\\:*?"<>|]"#, with: "_", options: .regularExpression)
            .drop(while: { $0 == "." })
            .description
    }

    /// Returns a deterministic but URL-unique sentinel temp-filename for directory-mode downloads.
    ///
    /// NET-021: Using a fixed name like `__pending__.tmp` causes two concurrent downloads
    /// targeting the same directory to share the same temp file, corrupting both.
    /// A FNV-1a hash of the download URL is stable across retries (resume still works)
    /// and unique per URL.
    func directoryModeTempFilename(for url: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in url.utf8 { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
        return String(format: ".__dl_%016llx.tmp", hash)
    }
}

// MARK: - DownloadSpeedTracker

/// Tracks smoothed download speed and estimated time remaining.
///
/// Uses an exponential moving average (α = 0.3) — the same formula as Android's
/// `ProgressResponseBody` — so speed display is consistent on both platforms.
private final class DownloadSpeedTracker {

    private var lastBytes: Int64 = 0
    private var lastTime: TimeInterval = Date().timeIntervalSince1970
    private var smoothedSpeed: Double = 0   // bytes per second (EMA)

    /// Update with the latest byte count and return (smoothedSpeed, etaMs).
    ///
    /// Returns `(nil, nil)` when not enough time has elapsed for a reliable sample.
    func update(bytesNow: Int64, totalBytes: Int64) -> (speed: Double?, etaMs: Int64?) {
        let now = Date().timeIntervalSince1970
        let elapsed = now - lastTime
        guard elapsed >= 0.5 else { return (smoothedSpeed > 0 ? smoothedSpeed : nil, nil) }

        let instantSpeed = Double(bytesNow - lastBytes) / elapsed
        smoothedSpeed = smoothedSpeed == 0 ? instantSpeed : 0.3 * instantSpeed + 0.7 * smoothedSpeed
        lastBytes = bytesNow
        lastTime = now

        let eta: Int64? = smoothedSpeed > 0 && totalBytes > bytesNow
            ? Int64(Double(totalBytes - bytesNow) / smoothedSpeed * 1000)
            : nil

        return (smoothedSpeed, eta)
    }
}
