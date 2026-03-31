import Foundation
import CryptoKit

/// Parallel chunked HTTP download worker for iOS.
///
/// Splits a single download into [numChunks] parallel byte-range requests
/// (HTTP `Range` header, RFC 7233), streams each chunk to a `.partN` temp
/// file concurrently using Swift `TaskGroup`, then concatenates them into
/// the final destination atomically.
///
/// **Automatic fallback:** If the server does not return
/// `Accept-Ranges: bytes` or a valid `Content-Length`, the worker falls back
/// to a single sequential download (identical to HttpDownloadWorker).
///
/// **Resume:** Each `.partN` file persists across retries. Already-complete
/// parts are skipped automatically on re-execution.
class ParallelHttpDownloadWorker: IosWorker {

    private static let defaultTimeoutMs: Int64 = 600_000

    struct Config: Codable {
        let url: String
        let savePath: String
        let numChunks: Int?
        let headers: [String: String]?
        let timeoutMs: Int64?
        let expectedChecksum: String?
        let checksumAlgorithm: String?
        let skipExisting: Bool?

        var effectiveNumChunks: Int { max(1, min(numChunks ?? 4, 16)) }
        var timeout: TimeInterval {
            TimeInterval((timeoutMs ?? ParallelHttpDownloadWorker.defaultTimeoutMs) / 1000)
        }
        var effectiveChecksumAlgorithm: String { checksumAlgorithm ?? "SHA-256" }
    }

    func doWork(input: String?) async throws -> WorkerResult {
        guard let input = input, !input.isEmpty else {
            return .failure(message: "Empty or null input")
        }
        guard let data = input.data(using: .utf8) else {
            return .failure(message: "Invalid input encoding")
        }

        let config: Config
        do {
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            return .failure(message: "Invalid JSON config: \(error.localizedDescription)")
        }

        guard let url = SecurityValidator.validateURL(config.url) else {
            return .failure(message: "Invalid or unsafe URL")
        }
        guard SecurityValidator.validateFilePath(config.savePath) else {
            return .failure(message: "File path outside app sandbox")
        }

        let taskId: String? = {
            guard let d = input.data(using: .utf8),
                  let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let id = j["__taskId"] as? String else { return nil }
            return id
        }()

        let destinationURL = URL(fileURLWithPath: config.savePath)
        let parentDir = destinationURL.deletingLastPathComponent()

        if !FileManager.default.fileExists(atPath: parentDir.path) {
            do {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            } catch {
                return .failure(message: "Failed to create directory: \(error.localizedDescription)")
            }
        }

        // Skip download if destination already exists and skipExisting is enabled
        if (config.skipExisting ?? false) && FileManager.default.fileExists(atPath: config.savePath) {
            print("ParallelHttpDownloadWorker: skipExisting=true and file already exists — skipping")
            let size = (try? FileManager.default.attributesOfItem(atPath: config.savePath))?[.size] as? Int64 ?? 0
            return .success(
                message: "File already exists, download skipped",
                data: ["filePath": config.savePath, "fileSize": size, "skipped": true]
            )
        }

        // Extract security configs from raw JSON (not Codable)
        let rawDict = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
        let pinningConfig = CertificatePinningConfig.from(rawDict?["certificatePinning"] as? [String: Any])
        let tokenRefreshConfig = TokenRefreshConfig.from(rawDict?["tokenRefresh"] as? [String: Any])
        let signingConfig = RequestSigner.Config.from(rawDict?["requestSigning"] as? [String: Any])

        let session = makeURLSession(pinningConfig: pinningConfig, timeoutInterval: config.timeout)

        // ── Step 1: HEAD request ──────────────────────────────────────────────
        var headRequest = URLRequest(url: url)
        headRequest.httpMethod = "HEAD"
        config.headers?.forEach { headRequest.setValue($1, forHTTPHeaderField: $0) }
        if let sc = signingConfig { RequestSigner.sign(request: &headRequest, config: sc) }

        let (contentLength, acceptsRanges): (Int64, Bool) = await {
            do {
                let (_, response) = try await session.data(for: headRequest)
                guard let http = response as? HTTPURLResponse else { return (-1, false) }
                let cl = Int64(http.value(forHTTPHeaderField: "Content-Length") ?? "") ?? -1
                let ar = http.value(forHTTPHeaderField: "Accept-Ranges")?.lowercased() == "bytes"
                return (cl, ar)
            } catch {
                print("ParallelHttpDownloadWorker: HEAD failed, fallback: \(error.localizedDescription)")
                return (-1, false)
            }
        }()

        // ── Step 2: Fallback if server does not support range requests ────────
        if !acceptsRanges || contentLength <= 0 {
            print("ParallelHttpDownloadWorker: No range support or unknown size — sequential fallback")
            return await downloadSequential(
                session: session, url: url, config: config,
                destinationURL: destinationURL, taskId: taskId,
                signingConfig: signingConfig,
                tokenRefreshConfig: tokenRefreshConfig
            )
        }

        print("ParallelHttpDownloadWorker: Content-Length=\(contentLength)  chunks=\(config.effectiveNumChunks)")

        // ── Step 3: Compute byte ranges ───────────────────────────────────────
        let numChunks = config.effectiveNumChunks
        let chunkSize = contentLength / Int64(numChunks)
        let ranges: [(Int64, Int64)] = (0 ..< numChunks).map { i in
            let start = Int64(i) * chunkSize
            let end = i == numChunks - 1 ? contentLength - 1 : start + chunkSize - 1
            return (start, end)
        }

        // ── Step 4: Check disk space ──────────────────────────────────────────
        if !SecurityValidator.hasEnoughDiskSpace(requiredBytes: contentLength, targetURL: destinationURL) {
            return .failure(message: "Insufficient disk space")
        }

        // ── Step 5: Download chunks in parallel ───────────────────────────────
        let totalBytes = contentLength
        let downloadedAtomic = AtomicInt64(0)
        let tracker = ProgressTracker()

        reportProgress(taskId: taskId, progress: 0,
                       message: "Starting parallel download (\(numChunks) chunks)...",
                       bytesDownloaded: 0, totalBytes: totalBytes)

        let chunkResults: [Bool] = await withTaskGroup(of: Bool.self) { group in
            for i in 0 ..< numChunks {
                group.addTask {
                    await self.downloadChunk(
                        index: i, range: ranges[i],
                        url: url, config: config, session: session,
                        taskId: taskId, totalBytes: totalBytes,
                        downloadedAtomic: downloadedAtomic,
                        tracker: tracker,
                        signingConfig: signingConfig,
                        tokenRefreshConfig: tokenRefreshConfig
                    )
                }
            }
            var results: [Bool] = []
            for await r in group { results.append(r) }
            return results
        }

        // ── Step 6: Check all chunks succeeded ───────────────────────────────
        guard chunkResults.allSatisfy({ $0 }) else {
            return .failure(message: "One or more chunks failed — partial files retained for retry")
        }

        // ── Step 7: Merge parts → temp file ──────────────────────────────────
        let tempURL = URL(fileURLWithPath: config.savePath + ".tmp")
        print("ParallelHttpDownloadWorker: Merging \(numChunks) chunks")

        do {
            // Resolve symlinks before writing (iOS /var → /private/var)
            let resolvedParent = destinationURL.deletingLastPathComponent().resolvingSymlinksInPath()
            let resolvedTemp = resolvedParent.appendingPathComponent(tempURL.lastPathComponent)

            try? FileManager.default.removeItem(at: resolvedTemp)
            FileManager.default.createFile(atPath: resolvedTemp.path, contents: nil)

            guard let outHandle = try? FileHandle(forWritingTo: resolvedTemp) else {
                return .failure(message: "Cannot open temp file for writing")
            }
            defer { try? outHandle.close() }

            for i in 0 ..< numChunks {
                let partURL = URL(fileURLWithPath: "\(config.savePath).part\(i)")
                guard let inHandle = try? FileHandle(forReadingFrom: partURL) else {
                    return .failure(message: "Cannot open part \(i) for reading")
                }
                defer { try? inHandle.close() }
                let bufSize = 65_536
                while true {
                    let chunk = inHandle.readData(ofLength: bufSize)
                    if chunk.isEmpty { break }
                    outHandle.write(chunk)
                }
                try? FileManager.default.removeItem(at: partURL)
            }

            // ── Step 8: Checksum ───────────────────────────────────────────
            if let expected = config.expectedChecksum {
                print("ParallelHttpDownloadWorker: Verifying checksum (\(config.effectiveChecksumAlgorithm))...")
                guard let actual = calculateChecksum(fileURL: resolvedTemp, algorithm: config.effectiveChecksumAlgorithm) else {
                    try? FileManager.default.removeItem(at: resolvedTemp)
                    return .failure(message: "Failed to calculate checksum")
                }
                if actual.caseInsensitiveCompare(expected) != .orderedSame {
                    try? FileManager.default.removeItem(at: resolvedTemp)
                    return .failure(message: "Checksum mismatch (expected: \(expected), actual: \(actual))")
                }
                print("ParallelHttpDownloadWorker: Checksum OK: \(actual)")
            }

            // ── Step 9: Atomic rename ──────────────────────────────────────
            let resolvedDest = resolvedParent.appendingPathComponent(destinationURL.lastPathComponent)
            try? FileManager.default.removeItem(at: resolvedDest)
            try FileManager.default.moveItem(at: resolvedTemp, to: resolvedDest)

            let finalSize = (try? FileManager.default.attributesOfItem(atPath: resolvedDest.path))?[.size] as? Int64 ?? 0
            reportProgress(taskId: taskId, progress: 100, message: "Download complete",
                           bytesDownloaded: finalSize, totalBytes: totalBytes)
            print("ParallelHttpDownloadWorker: Success — \(finalSize) bytes at \(config.savePath)")

            return .success(
                message: "Downloaded \(finalSize) bytes (\(numChunks) parallel chunks)",
                data: [
                    "filePath": resolvedDest.path,
                    "fileName": destinationURL.lastPathComponent,
                    "fileSize": finalSize,
                    "numChunks": numChunks,
                    "parallelDownload": true
                ]
            )
        } catch {
            return .failure(message: "Merge failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Single chunk download

    private func downloadChunk(
        index: Int,
        range: (Int64, Int64),
        url: URL,
        config: Config,
        session: URLSession,
        taskId: String?,
        totalBytes: Int64,
        downloadedAtomic: AtomicInt64,
        tracker: ProgressTracker,
        signingConfig: RequestSigner.Config? = nil,
        tokenRefreshConfig: TokenRefreshConfig? = nil
    ) async -> Bool {
        let partURL = URL(fileURLWithPath: "\(config.savePath).part\(index)")
        let (rangeStart, rangeEnd) = range
        let expectedSize = rangeEnd - rangeStart + 1

        // Resume: skip if already complete
        let existingSize = (try? FileManager.default.attributesOfItem(atPath: partURL.path))?[.size] as? Int64 ?? 0
        if existingSize >= expectedSize {
            print("ParallelHttpDownloadWorker: Chunk \(index) already complete, skipping")
            downloadedAtomic.add(existingSize)
            return true
        }

        let resumeFrom = rangeStart + existingSize
        var request = URLRequest(url: url)
        request.setValue("bytes=\(resumeFrom)-\(rangeEnd)", forHTTPHeaderField: "Range")
        config.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        if let sc = signingConfig { RequestSigner.sign(request: &request, config: sc) }

        print("ParallelHttpDownloadWorker: Chunk \(index) — bytes=\(resumeFrom)-\(rangeEnd)")

        do {
            var (data, response) = try await session.data(for: request)
            // Handle 401 with token refresh
            if let http = response as? HTTPURLResponse, http.statusCode == 401,
               let trCfg = tokenRefreshConfig {
                if let newToken = await attemptTokenRefresh(config: trCfg, currentSession: session) {
                    var retryRequest = URLRequest(url: url)
                    retryRequest.setValue("bytes=\(resumeFrom)-\(rangeEnd)", forHTTPHeaderField: "Range")
                    retryRequest.setValue("\(trCfg.tokenPrefix)\(newToken)",
                                         forHTTPHeaderField: trCfg.tokenHeaderName)
                    config.headers?.forEach { retryRequest.setValue($1, forHTTPHeaderField: $0) }
                    if let sc = signingConfig { RequestSigner.sign(request: &retryRequest, config: sc) }
                    (data, response) = try await session.data(for: retryRequest)
                }
            }
            guard let http = response as? HTTPURLResponse,
                  (200 ..< 300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("ParallelHttpDownloadWorker: Chunk \(index) HTTP \(code)")
                return false
            }

            // Append to part file
            if existingSize > 0 {
                guard let handle = try? FileHandle(forWritingTo: partURL) else { return false }
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? FileManager.default.removeItem(at: partURL)
                try data.write(to: partURL, options: .atomic)
            }

            let added = downloadedAtomic.add(Int64(data.count))
            if totalBytes > 0, let taskId = taskId {
                let pct = Int(min(99, (Double(added) / Double(totalBytes)) * 100))
                let (speed, etaMs) = tracker.update(
                    bytesAdded: Int64(data.count),
                    totalDownloaded: added,
                    totalBytes: totalBytes
                )
                reportProgress(
                    taskId: taskId, progress: pct,
                    message: "Downloading... \(formatBytes(added))/\(formatBytes(totalBytes))",
                    bytesDownloaded: added, totalBytes: totalBytes,
                    networkSpeed: speed, timeRemainingMs: etaMs
                )
            }
            print("ParallelHttpDownloadWorker: Chunk \(index) done (\(data.count) bytes)")
            return true
        } catch {
            print("ParallelHttpDownloadWorker: Chunk \(index) error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Sequential fallback

    private func downloadSequential(
        session: URLSession,
        url: URL,
        config: Config,
        destinationURL: URL,
        taskId: String?,
        signingConfig: RequestSigner.Config? = nil,
        tokenRefreshConfig: TokenRefreshConfig? = nil
    ) async -> WorkerResult {
        let tempURL = URL(fileURLWithPath: config.savePath + ".tmp")
        let existingBytes: Int64 = {
            guard FileManager.default.fileExists(atPath: tempURL.path),
                  let attr = try? FileManager.default.attributesOfItem(atPath: tempURL.path),
                  let size = attr[.size] as? Int64, size > 0 else { return 0 }
            return size
        }()

        var request = URLRequest(url: url)
        if existingBytes > 0 { request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range") }
        config.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        if let sc = signingConfig { RequestSigner.sign(request: &request, config: sc) }

        do {
            var (data, response) = try await session.data(for: request)
            // Handle 401 with token refresh
            if let http = response as? HTTPURLResponse, http.statusCode == 401,
               let trCfg = tokenRefreshConfig {
                if let newToken = await attemptTokenRefresh(config: trCfg, currentSession: session) {
                    var retryRequest = URLRequest(url: url)
                    if existingBytes > 0 { retryRequest.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range") }
                    retryRequest.setValue("\(trCfg.tokenPrefix)\(newToken)",
                                         forHTTPHeaderField: trCfg.tokenHeaderName)
                    config.headers?.forEach { retryRequest.setValue($1, forHTTPHeaderField: $0) }
                    if let sc = signingConfig { RequestSigner.sign(request: &retryRequest, config: sc) }
                    (data, response) = try await session.data(for: retryRequest)
                }
            }
            guard let http = response as? HTTPURLResponse,
                  (200 ..< 300).contains(http.statusCode) else {
                return .failure(message: "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }

            if existingBytes > 0 && http.statusCode == 206,
               let handle = try? FileHandle(forWritingTo: tempURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? FileManager.default.removeItem(at: tempURL)
                try data.write(to: tempURL, options: .atomic)
            }

            if let expected = config.expectedChecksum {
                guard let actual = calculateChecksum(fileURL: tempURL, algorithm: config.effectiveChecksumAlgorithm) else {
                    try? FileManager.default.removeItem(at: tempURL)
                    return .failure(message: "Failed to calculate checksum")
                }
                if actual.caseInsensitiveCompare(expected) != .orderedSame {
                    try? FileManager.default.removeItem(at: tempURL)
                    return .failure(message: "Checksum mismatch (expected: \(expected), actual: \(actual))")
                }
            }

            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            let finalSize = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path))?[.size] as? Int64 ?? 0
            reportProgress(taskId: taskId, progress: 100, message: "Download complete",
                           bytesDownloaded: finalSize, totalBytes: finalSize)

            return .success(
                message: "Downloaded \(finalSize) bytes (sequential fallback)",
                data: [
                    "filePath": destinationURL.path,
                    "fileName": destinationURL.lastPathComponent,
                    "fileSize": finalSize,
                    "numChunks": 1,
                    "parallelDownload": false
                ]
            )
        } catch {
            return .failure(message: error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func reportProgress(
        taskId: String?,
        progress: Int,
        message: String?,
        bytesDownloaded: Int64? = nil,
        totalBytes: Int64? = nil,
        networkSpeed: Double? = nil,
        timeRemainingMs: Int64? = nil
    ) {
        guard let taskId = taskId else { return }
        if BackgroundSessionManager.shared.richProgressDelegate != nil {
            var dict: [String: Any] = ["taskId": taskId, "progress": progress]
            if let msg = message { dict["message"] = msg }
            if let bd = bytesDownloaded { dict["bytesDownloaded"] = bd }
            if let tb = totalBytes { dict["totalBytes"] = tb }
            if let ns = networkSpeed { dict["networkSpeed"] = ns }
            if let tr = timeRemainingMs { dict["timeRemainingMs"] = tr }
            BackgroundSessionManager.shared.richProgressDelegate?(taskId, dict)
        } else {
            BackgroundSessionManager.shared.progressDelegate?(taskId, Double(progress))
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        switch bytes {
        case 1_073_741_824...: return String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
        case 1_048_576...:     return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        case 1_024...:         return String(format: "%.1f KB", Double(bytes) / 1_024)
        default:               return "\(bytes) B"
        }
    }

    private func calculateChecksum(fileURL: URL, algorithm: String) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return nil }
        defer { try? handle.close() }
        let bufSize = 8192
        let upper = algorithm.uppercased()

        guard #available(iOS 13.0, *) else { return nil }

        switch upper {
        case "MD5":
            var h = Insecure.MD5()
            while autoreleasepool(invoking: {
                let d = handle.readData(ofLength: bufSize); if d.isEmpty { return false }
                h.update(data: d); return true
            }) {}
            return h.finalize().map { String(format: "%02x", $0) }.joined()
        case "SHA-1", "SHA1":
            var h = Insecure.SHA1()
            while autoreleasepool(invoking: {
                let d = handle.readData(ofLength: bufSize); if d.isEmpty { return false }
                h.update(data: d); return true
            }) {}
            return h.finalize().map { String(format: "%02x", $0) }.joined()
        case "SHA-256", "SHA256":
            var h = SHA256()
            while autoreleasepool(invoking: {
                let d = handle.readData(ofLength: bufSize); if d.isEmpty { return false }
                h.update(data: d); return true
            }) {}
            return h.finalize().map { String(format: "%02x", $0) }.joined()
        case "SHA-512", "SHA512":
            var h = SHA512()
            while autoreleasepool(invoking: {
                let d = handle.readData(ofLength: bufSize); if d.isEmpty { return false }
                h.update(data: d); return true
            }) {}
            return h.finalize().map { String(format: "%02x", $0) }.joined()
        default:
            print("ParallelHttpDownloadWorker: Unsupported algorithm: \(algorithm)")
            return nil
        }
    }
}

// MARK: - Thread-safe speed tracker

/// Tracks aggregate download speed across concurrent chunks using an EMA (α=0.3).
private final class ProgressTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var windowStart = Date()
    private var windowBytes: Int64 = 0
    private var smoothedBps: Double = 0

    /// Record `bytesAdded` bytes just downloaded. Returns (speed, etaMs) pair.
    func update(bytesAdded: Int64, totalDownloaded: Int64, totalBytes: Int64) -> (Double?, Int64?) {
        lock.lock(); defer { lock.unlock() }
        windowBytes += bytesAdded
        let elapsed = Date().timeIntervalSince(windowStart)
        if elapsed >= 0.5 {
            let instant = Double(windowBytes) / elapsed
            smoothedBps = smoothedBps == 0 ? instant : 0.3 * instant + 0.7 * smoothedBps
            windowStart = Date()
            windowBytes = 0
        }
        guard smoothedBps > 0 else { return (nil, nil) }
        let remaining = totalBytes - totalDownloaded
        let eta: Int64? = remaining > 0 ? Int64(Double(remaining) / smoothedBps * 1000) : 0
        return (smoothedBps, eta)
    }
}

// MARK: - Thread-safe Int64 counter

/// Minimal thread-safe counter for aggregating chunk download bytes.
private final class AtomicInt64: @unchecked Sendable {
    private var value: Int64
    private let lock = NSLock()

    init(_ initial: Int64 = 0) { value = initial }

    /// Adds `delta` and returns the new total.
    @discardableResult
    func add(_ delta: Int64) -> Int64 {
        lock.lock(); defer { lock.unlock() }
        value += delta
        return value
    }

    var current: Int64 {
        lock.lock(); defer { lock.unlock() }
        return value
    }
}
