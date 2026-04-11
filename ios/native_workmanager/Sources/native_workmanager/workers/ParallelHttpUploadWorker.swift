import Foundation
import KMPWorkManager
import UniformTypeIdentifiers

/// Parallel multi-file HTTP upload worker for iOS.
///
/// Uploads each file as a **separate** concurrent multipart request using
/// Swift `TaskGroup`, with a per-host concurrency limit via
/// `HostConcurrencyManager`. Each file is retried independently up to
/// `maxRetries` times on 5xx / network errors.
///
/// **Configuration JSON:**
/// ```json
/// {
///   "url": "https://api.example.com/photos",
///   "files": [
///     { "filePath": "/...", "fieldName": "file", "fileName": "img.jpg", "mimeType": "image/jpeg" }
///   ],
///   "headers": { "Authorization": "Bearer token" },
///   "fields":  { "albumId": "42" },
///   "maxConcurrent": 3,
///   "maxRetries": 1,
///   "timeoutMs": 300000
/// }
/// ```
class ParallelHttpUploadWorker: IosWorker {

    private static let defaultTimeoutMs: Int64 = 300_000

    // MARK: - Config types

    struct FileSpec: Codable {
        let filePath: String
        let fieldName: String?
        let fileName: String?
        let mimeType: String?

        var effectiveFieldName: String { fieldName ?? "file" }
    }

    struct Config: Codable {
        let url: String
        let files: [FileSpec]
        let headers: [String: String]?
        let fields: [String: String]?
        let maxConcurrent: Int?
        let maxRetries: Int?
        let timeoutMs: Int64?

        var effectiveMaxConcurrent: Int { max(1, min(maxConcurrent ?? 3, 16)) }
        var effectiveMaxRetries: Int    { max(0, min(maxRetries ?? 1, 5)) }
        var timeout: TimeInterval {
            TimeInterval((timeoutMs ?? ParallelHttpUploadWorker.defaultTimeoutMs) / 1000)
        }
    }

    // Internal fully-resolved file descriptor (not Codable, used only at runtime).
    private struct ResolvedFile {
        let fileURL: URL
        let resolvedName: String
        let resolvedMime: String
        let fieldName: String
        let size: Int64
    }

    // MARK: - doWork

    func doWork(input: String?, env: KMPWorkManager.WorkerEnvironment) async throws -> WorkerResult {
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

        let taskId: String? = {
            guard let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = j["__taskId"] as? String else { return nil }
            return id
        }()

        let host = url.host ?? config.url

        // ── Validate all files upfront ────────────────────────────────────────
        var resolvedFiles: [ResolvedFile] = []
        var totalBytes: Int64 = 0

        for spec in config.files {
            guard SecurityValidator.validateFilePath(spec.filePath) else {
                return .failure(message: "File path outside app sandbox: \(spec.filePath)")
            }
            guard FileManager.default.fileExists(atPath: spec.filePath) else {
                return .failure(message: "File not found: \(spec.filePath)")
            }
            let fileURL = URL(fileURLWithPath: spec.filePath)
            let attrs = try? FileManager.default.attributesOfItem(atPath: spec.filePath)
            let size = (attrs?[.size] as? Int64) ?? 0
            totalBytes += size
            let mime = spec.mimeType ?? detectMimeType(for: fileURL)
            let name = spec.fileName ?? fileURL.lastPathComponent
            resolvedFiles.append(ResolvedFile(
                fileURL: fileURL, resolvedName: name, resolvedMime: mime,
                fieldName: spec.effectiveFieldName, size: size
            ))
        }

        print("ParallelHttpUploadWorker: Uploading \(resolvedFiles.count) files to \(host)" +
              "  maxConcurrent=\(config.effectiveMaxConcurrent)  maxRetries=\(config.effectiveMaxRetries)")

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest  = config.timeout
        sessionConfig.timeoutIntervalForResource = config.timeout * 2
        let session = URLSession(configuration: sessionConfig)

        // ── Shared progress state (protected by NSLock) ───────────────────────
        let progressLock = NSLock()
        var totalUploaded: Int64 = 0
        var uploadedCount = 0

        if let taskId = taskId {
            ProgressReporter.shared.report(
                taskId: taskId, progress: 0,
                message: "Starting upload of \(resolvedFiles.count) files...",
                bytesDownloaded: 0, totalBytes: totalBytes
            )
        }

        // ── Upload all files concurrently via TaskGroup ───────────────────────
        var fileResults: [[String: Any]] = Array(repeating: [:], count: resolvedFiles.count)

        await withTaskGroup(of: (Int, [String: Any]).self) { group in
            for (i, rf) in resolvedFiles.enumerated() {
                group.addTask { [self] in
                    var attempt = 0
                    var lastError = "Unknown error"

                    while attempt <= config.effectiveMaxRetries {
                        if attempt > 0 {
                            print("ParallelHttpUploadWorker: Retry \(attempt)/\(config.effectiveMaxRetries) for \(rf.resolvedName)")
                        }

                        // Per-host concurrency gate (DispatchSemaphore.wait — OK on cooperative pool thread).
                        HostConcurrencyManager.shared.acquire(host: host)
                        let outcome = await self.uploadFile(
                            session: session,
                            url: url,
                            resolvedFile: rf,
                            headers: config.headers,
                            fields: config.fields,
                            onProgress: { bytes in
                                progressLock.lock()
                                totalUploaded += bytes
                                let uploaded = totalUploaded
                                let done = uploadedCount
                                progressLock.unlock()

                                if let taskId = taskId, totalBytes > 0 {
                                    let pct = Int(min(99, Double(uploaded) / Double(totalBytes) * 100))
                                    ProgressReporter.shared.report(
                                        taskId: taskId, progress: pct,
                                        message: "Uploading... \(done)/\(resolvedFiles.count) files complete",
                                        bytesDownloaded: uploaded, totalBytes: totalBytes
                                    )
                                }
                            }
                        )
                        HostConcurrencyManager.shared.release(host: host)

                        if outcome.success {
                            progressLock.lock()
                            uploadedCount += 1
                            let done = uploadedCount
                            progressLock.unlock()

                            print("ParallelHttpUploadWorker: [\(i)] \(rf.resolvedName) uploaded (\(done)/\(resolvedFiles.count))")

                            if let taskId = taskId {
                                let pct = Int(min(99, Double(done) / Double(resolvedFiles.count) * 100))
                                ProgressReporter.shared.report(
                                    taskId: taskId, progress: pct,
                                    message: "Uploaded \(done)/\(resolvedFiles.count) files"
                                )
                            }

                            return (i, [
                                "fileName": rf.resolvedName,
                                "filePath": rf.fileURL.path,
                                "fileSize": rf.size,
                                "success": true,
                                "statusCode": outcome.statusCode,
                                "responseBody": outcome.responseBody,
                            ])
                        }

                        lastError = outcome.errorMessage ?? "Upload failed"
                        if !outcome.shouldRetry { break }
                        attempt += 1
                    }

                    print("ParallelHttpUploadWorker: [\(i)] \(rf.resolvedName) failed after \(attempt) attempt(s): \(lastError)")
                    return (i, [
                        "fileName": rf.resolvedName,
                        "filePath": rf.fileURL.path,
                        "fileSize": rf.size,
                        "success": false,
                        "error": lastError,
                    ])
                }
            }

            for await (index, result) in group {
                fileResults[index] = result
            }
        }

        let succeeded = fileResults.filter { $0["success"] as? Bool == true }.count
        let failed = fileResults.count - succeeded

        if let taskId = taskId {
            ProgressReporter.shared.report(
                taskId: taskId, progress: 100,
                message: "Upload complete: \(succeeded)/\(fileResults.count) files",
                bytesDownloaded: totalBytes, totalBytes: totalBytes
            )
            ProgressReporter.shared.clearTask(taskId)
        }

        print("ParallelHttpUploadWorker: Done — \(succeeded) succeeded, \(failed) failed, \(totalBytes) bytes total")

        if succeeded == 0 {
            return .failure(message: "All \(fileResults.count) file uploads failed")
        }

        return .success(
            message: "Uploaded \(succeeded)/\(fileResults.count) files (\(totalBytes) bytes)",
            data: [
                "uploadedCount": succeeded,
                "failedCount":   failed,
                "totalBytes":    totalBytes,
                "fileResults":   fileResults,
            ]
        )
    }

    // MARK: - Upload a single file

    private struct UploadOutcome {
        let success: Bool
        let statusCode: Int
        let responseBody: String
        let errorMessage: String?
        let shouldRetry: Bool
    }

    private func uploadFile(
        session: URLSession,
        url: URL,
        resolvedFile rf: ResolvedFile,
        headers: [String: String]?,
        fields: [String: String]?,
        onProgress: @escaping (Int64) -> Void
    ) async -> UploadOutcome {
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        // Build multipart body (stream file to avoid loading it fully in memory)
        var bodyData = Data()

        fields?.forEach { key, value in
            bodyData.append("--\(boundary)\r\n".utf8Data)
            bodyData.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".utf8Data)
            bodyData.append("\(value)\r\n".utf8Data)
        }

        bodyData.append("--\(boundary)\r\n".utf8Data)
        bodyData.append("Content-Disposition: form-data; name=\"\(rf.fieldName)\"; filename=\"\(rf.resolvedName)\"\r\n".utf8Data)
        bodyData.append("Content-Type: \(rf.resolvedMime)\r\n\r\n".utf8Data)

        // Stream file content into body, reporting progress per chunk
        guard let fileStream = InputStream(url: rf.fileURL) else {
            return UploadOutcome(success: false, statusCode: 0, responseBody: "",
                                 errorMessage: "Cannot open file: \(rf.fileURL.path)", shouldRetry: false)
        }
        fileStream.open()
        let bufSize = 65_536
        var buf = [UInt8](repeating: 0, count: bufSize)
        while true {
            let n = fileStream.read(&buf, maxLength: bufSize)
            if n <= 0 { break }
            bodyData.append(contentsOf: buf[..<n])
            onProgress(Int64(n))
        }
        fileStream.close()

        bodyData.append("\r\n--\(boundary)--\r\n".utf8Data)
        request.httpBody = bodyData

        do {
            let (respData, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return UploadOutcome(success: false, statusCode: 0, responseBody: "",
                                     errorMessage: "Non-HTTP response", shouldRetry: true)
            }
            let code = http.statusCode
            let body = String(data: respData, encoding: .utf8) ?? ""
            if (200 ..< 300).contains(code) {
                return UploadOutcome(success: true, statusCode: code, responseBody: body,
                                     errorMessage: nil, shouldRetry: false)
            }
            return UploadOutcome(success: false, statusCode: code, responseBody: "",
                                 errorMessage: "HTTP \(code): \(String(body.prefix(200)))",
                                 shouldRetry: code >= 500)
        } catch {
            return UploadOutcome(success: false, statusCode: 0, responseBody: "",
                                 errorMessage: error.localizedDescription, shouldRetry: true)
        }
    }

    // MARK: - Helpers

    private func detectMimeType(for fileURL: URL) -> String {
        let ext = fileURL.pathExtension.lowercased()
        if #available(iOS 14.0, *) {
            if let utType = UTType(filenameExtension: ext),
               let mime = utType.preferredMIMEType {
                return mime
            }
        }
        let fallback: [String: String] = [
            "jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
            "gif": "image/gif",  "webp": "image/webp", "mp4": "video/mp4",
            "mov": "video/quicktime", "mp3": "audio/mpeg", "pdf": "application/pdf",
            "zip": "application/zip", "json": "application/json",
        ]
        return fallback[ext] ?? "application/octet-stream"
    }
}

// MARK: - String convenience

private extension String {
    var utf8Data: Data { data(using: .utf8) ?? Data() }
}
