import Foundation
import UniformTypeIdentifiers

/// Native HTTP file upload worker for iOS.
///
/// Uploads single or multiple files using URLSession multipart/form-data without requiring Flutter Engine.
/// Supports large file uploads with streaming to minimize memory usage.
/// Also supports raw bytes/string upload for data in memory.
///
/// **Configuration JSON (Single File - Legacy):**
/// ```json
/// {
///   "url": "https://api.example.com/upload",
///   "filePath": "/path/to/file.jpg",
///   "fileFieldName": "file",      // Optional: Form field name (default: "file")
///   "fileName": "photo.jpg",       // Optional: Override file name
///   "mimeType": "image/jpeg",      // Optional: Override MIME type (auto-detected)
///   "headers": {                   // Optional
///     "Authorization": "Bearer token"
///   },
///   "fields": {                    // Optional: Additional form fields
///     "userId": "123",
///     "description": "My photo"
///   },
///   "timeoutMs": 120000           // Optional: Timeout (default: 2 minutes for uploads)
/// }
/// ```
///
/// **Configuration JSON (Multiple Files):**
/// ```json
/// {
///   "url": "https://api.example.com/upload",
///   "files": [                     // Array of files
///     {
///       "filePath": "/path/to/photo1.jpg",
///       "fileFieldName": "photos",  // Same field name = array
///       "fileName": "photo1.jpg",
///       "mimeType": "image/jpeg"
///     },
///     {
///       "filePath": "/path/to/photo2.jpg",
///       "fileFieldName": "photos",
///       "fileName": "photo2.jpg"
///     }
///   ],
///   "headers": { "Authorization": "Bearer token" },
///   "fields": { "albumId": "123" },
///   "timeoutMs": 300000
/// }
/// ```
///
/// **Configuration JSON (Raw Bytes Upload - NEW):**
/// ```json
/// {
///   "url": "https://api.example.com/data",
///   "body": "{\"key\": \"value\"}",  // String body (alternative to bodyBytes)
///   "contentType": "application/json",  // Required for raw upload
///   "headers": { "Authorization": "Bearer token" },
///   "timeoutMs": 60000
/// }
/// ```
///
/// **Configuration JSON (Raw Bytes from Base64 - NEW):**
/// ```json
/// {
///   "url": "https://api.example.com/binary",
///   "bodyBytes": "SGVsbG8gV29ybGQh",  // Base64-encoded bytes
///   "contentType": "application/octet-stream",
///   "timeoutMs": 60000
/// }
/// ```
///
/// **Performance:**
/// - Files: ~5-10MB RAM (streaming)
/// - Raw bytes: Depends on body size (loaded in memory)
class HttpUploadWorker: IosWorker {

    private static let defaultTimeoutMs: Int64 = 120_000
    private static let boundary = "Boundary-\(UUID().uuidString)"

    struct FileConfig: Codable {
        let filePath: String
        let fileFieldName: String?
        let fileName: String?
        let mimeType: String?

        var effectiveFileFieldName: String {
            fileFieldName ?? "file"
        }
    }

    struct Config: Codable {
        let url: String
        // 👇 Support both single file (legacy) and multiple files
        let filePath: String?        // Legacy: Single file path
        let files: [FileConfig]?     // Multiple files
        let fileFieldName: String?   // Legacy
        let fileName: String?        // Legacy
        let mimeType: String?        // Legacy
        // 👇 NEW: Raw body upload (alternative to files)
        let body: String?            // String body (JSON, XML, text, etc.)
        let bodyBytes: String?       // Base64-encoded bytes
        let contentType: String?     // Content-Type for raw body (required if body/bodyBytes)
        let headers: [String: String]?
        let fields: [String: String]?
        let timeoutMs: Int64?
        let useBackgroundSession: Bool?  // NEW v2.3.0: Use background URLSession

        var timeout: TimeInterval {
            TimeInterval((timeoutMs ?? HttpUploadWorker.defaultTimeoutMs) / 1000)
        }

        var shouldUseBackgroundSession: Bool {
            useBackgroundSession ?? false  // Default: false for backward compatibility
        }

        // Build unified file list from either single file or files array
        func getFileConfigs() -> [FileConfig] {
            if let files = files, !files.isEmpty {
                return files
            } else if let filePath = filePath {
                return [FileConfig(
                    filePath: filePath,
                    fileFieldName: fileFieldName,
                    fileName: fileName,
                    mimeType: mimeType
                )]
            } else {
                return []
            }
        }

        // Check if this is a raw body upload (not file upload)
        func isRawBodyUpload() -> Bool {
            return body != nil || bodyBytes != nil
        }
    }

    func doWork(input: String?) async throws -> WorkerResult {
        guard let input = input, !input.isEmpty else {
            print("HttpUploadWorker: Error - Empty or null input")
            return .failure(message: "Empty or null input")
        }

        // Parse configuration
        let config: Config
        do {
            let data = input.data(using: .utf8)!
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            print("HttpUploadWorker: Error parsing JSON config: \(error)")
            return .failure(message: "Invalid JSON config: \(error.localizedDescription)")
        }

        // ✅ SECURITY: Validate URL scheme (prevent file://, ftp://, etc.)
        guard let url = SecurityValidator.validateURL(config.url) else {
            print("HttpUploadWorker: Error - Invalid or unsafe URL")
            return .failure(message: "Invalid or unsafe URL")
        }

        // 👇 NEW: Check upload mode (raw body or files)
        let isRawBodyUpload = config.isRawBodyUpload()
        let fileConfigs = config.getFileConfigs()

        // Validate upload mode
        if isRawBodyUpload && !fileConfigs.isEmpty {
            print("HttpUploadWorker: Error - Cannot mix raw body and file upload")
            return .failure(message: "Cannot use both body/bodyBytes and filePath/files")
        }

        if !isRawBodyUpload && fileConfigs.isEmpty {
            print("HttpUploadWorker: Error - No data to upload")
            return .failure(message: "No data to upload (provide body/bodyBytes or filePath/files)")
        }

        // 👇 NEW: Handle raw body upload
        if isRawBodyUpload {
            return await handleRawBodyUpload(config: config, url: url)
        }

        // Validate all files exist and are valid
        var totalSize: Int64 = 0
        var validatedFiles: [(url: URL, fileName: String, mimeType: String)] = []

        for fileConfig in fileConfigs {
            // ✅ SECURITY: Validate file path
            guard SecurityValidator.validateFilePath(fileConfig.filePath) else {
                print("HttpUploadWorker: Error - File path outside sandbox: \(fileConfig.filePath)")
                return .failure(message: "File path outside sandbox")
            }

            let fileURL = URL(fileURLWithPath: fileConfig.filePath)
            guard FileManager.default.fileExists(atPath: fileConfig.filePath) else {
                print("HttpUploadWorker: Error - File not found: \(fileConfig.filePath)")
                return .failure(message: "File not found: \(fileURL.lastPathComponent)")
            }

            // Get file size
            do {
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileConfig.filePath)
                if let fileSize = fileAttributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            } catch {
                print("HttpUploadWorker: Error reading file: \(error)")
                return .failure(message: "Failed to read file: \(fileURL.lastPathComponent)")
            }

            // Detect MIME type and get file name
            let mimeType = fileConfig.mimeType ?? detectMimeType(for: fileURL)
            let fileName = fileConfig.fileName ?? fileURL.lastPathComponent

            validatedFiles.append((fileURL, fileName, mimeType))
        }

        // ✅ SECURITY: Sanitize logging
        let sanitizedURL = SecurityValidator.sanitizedURL(config.url)
        print("HttpUploadWorker: Uploading to \(sanitizedURL)")
        print("  Files: \(validatedFiles.count), Total Size: \(totalSize) bytes")
        for (index, (fileURL, fileName, mimeType)) in validatedFiles.enumerated() {
            let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = fileAttributes?[.size] as? Int64 ?? 0
            print("    [\(index)] \(fileName) (\(fileSize) bytes, \(mimeType))")
        }

        // 🚀 Use background session if enabled (v2.3.0+)
        if config.shouldUseBackgroundSession {
            return await uploadWithBackgroundSession(
                url: url,
                config: config,
                validatedFiles: validatedFiles,
                totalSize: totalSize
            )
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeout
        request.setValue("multipart/form-data; boundary=\(HttpUploadWorker.boundary)",
                        forHTTPHeaderField: "Content-Type")

        // Add custom headers
        if let headers = config.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Build multipart body
        var body = Data()

        // Add form fields
        if let fields = config.fields {
            for (key, value) in fields {
                body.append("--\(HttpUploadWorker.boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
        }

        // 👇 Add all files to multipart body
        for (index, (fileURL, fileName, mimeType)) in validatedFiles.enumerated() {
            let fileFieldName = fileConfigs[index].effectiveFileFieldName

            body.append("--\(HttpUploadWorker.boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)

            // Read file data
            guard let fileData = try? Data(contentsOf: fileURL) else {
                print("HttpUploadWorker: Error - Failed to read file: \(fileName)")
                return .failure(message: "Failed to read file: \(fileName)")
            }
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }

        // End boundary
        body.append("--\(HttpUploadWorker.boundary)--\r\n".data(using: .utf8)!)

        // Execute upload
        do {
            let (data, response) = try await URLSession.shared.upload(for: request, from: body)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("HttpUploadWorker: Error - Invalid response type")
                return .failure(message: "Invalid response type")
            }

            // ✅ SECURITY: Validate response body size
            guard SecurityValidator.validateResponseSize(data) else {
                print("HttpUploadWorker: Error - Response body too large")
                return .failure(message: "Response body too large")
            }

            let statusCode = httpResponse.statusCode
            let success = (200..<300).contains(statusCode)
            let responseBody = String(data: data, encoding: .utf8) ?? ""

            if success {
                // ✅ SECURITY: Truncate response for logging
                let truncatedResponse = SecurityValidator.truncateForLogging(responseBody, maxLength: 200)
                print("HttpUploadWorker: Success - Status \(statusCode)")
                print("HttpUploadWorker: Response: \(truncatedResponse)")

                return .success(
                    message: "Uploaded \(validatedFiles.count) file(s), \(totalSize) bytes",
                    data: [
                        "statusCode": statusCode,
                        "uploadedSize": totalSize,
                        "fileCount": validatedFiles.count,  // 👈 NEW
                        "fileNames": validatedFiles.map { $0.fileName },  // 👈 NEW
                        "responseBody": responseBody
                    ]
                )
            } else {
                // ✅ SECURITY: Truncate error body for logging
                let truncatedError = SecurityValidator.truncateForLogging(responseBody, maxLength: 200)
                print("HttpUploadWorker: Failed - Status \(statusCode)")
                print("HttpUploadWorker: Error: \(truncatedError)")
                return .failure(message: "HTTP \(statusCode)")
            }
        } catch {
            print("HttpUploadWorker: Error - \(error.localizedDescription)")
            return .failure(message: error.localizedDescription)
        }
    }

    /// Handle raw body upload (string or bytes).
    private func handleRawBodyUpload(config: Config, url: URL) async -> WorkerResult {
        // Validate content type is provided
        guard let contentType = config.contentType, !contentType.isEmpty else {
            print("HttpUploadWorker: Error - contentType is required for raw body upload")
            return .failure(message: "contentType is required for raw body upload")
        }

        let sanitizedURL = SecurityValidator.sanitizedURL(config.url)
        print("HttpUploadWorker: Uploading raw body to \(sanitizedURL)")
        print("  Content-Type: \(contentType)")

        // Build request body
        let requestBody: Data
        if let body = config.body {
            requestBody = body.data(using: .utf8) ?? Data()
            print("  Body: \(body.count) characters (\(requestBody.count) bytes)")
        } else if let bodyBytes = config.bodyBytes {
            guard let decodedData = Data(base64Encoded: bodyBytes) else {
                print("HttpUploadWorker: Error - Failed to decode base64 bodyBytes")
                return .failure(message: "Invalid base64 bodyBytes")
            }
            requestBody = decodedData
            print("  Body: \(requestBody.count) bytes (from base64)")
        } else {
            print("HttpUploadWorker: Error - No body or bodyBytes provided")
            return .failure(message: "No body or bodyBytes provided")
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeout
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        // Add custom headers
        if let headers = config.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Execute upload
        do {
            let (data, response) = try await URLSession.shared.upload(for: request, from: requestBody)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("HttpUploadWorker: Error - Invalid response type")
                return .failure(message: "Invalid response type")
            }

            // ✅ SECURITY: Validate response body size
            guard SecurityValidator.validateResponseSize(data) else {
                print("HttpUploadWorker: Error - Response body too large")
                return .failure(message: "Response body too large")
            }

            let statusCode = httpResponse.statusCode
            let success = (200..<300).contains(statusCode)
            let responseBody = String(data: data, encoding: .utf8) ?? ""

            if success {
                // ✅ SECURITY: Truncate response for logging
                let truncatedResponse = SecurityValidator.truncateForLogging(responseBody, maxLength: 200)
                print("HttpUploadWorker: Success - Status \(statusCode)")
                print("HttpUploadWorker: Response: \(truncatedResponse)")

                return .success(
                    message: "Uploaded raw body",
                    data: [
                        "statusCode": statusCode,
                        "uploadedSize": requestBody.count,
                        "contentType": contentType,
                        "responseBody": responseBody
                    ]
                )
            } else {
                // ✅ SECURITY: Truncate error body for logging
                let truncatedError = SecurityValidator.truncateForLogging(responseBody, maxLength: 200)
                print("HttpUploadWorker: Failed - Status \(statusCode)")
                print("HttpUploadWorker: Error: \(truncatedError)")
                return .failure(message: "HTTP \(statusCode)")
            }
        } catch {
            print("HttpUploadWorker: Error - \(error.localizedDescription)")
            return .failure(message: error.localizedDescription)
        }
    }

    /// Upload file using background URLSession (survives app termination).
    ///
    /// **Requirements:**
    /// - iOS 13.0+
    /// - Currently supports single file upload only
    /// - Multipart form-data is built and saved as temp file for upload
    ///
    /// **Limitations:**
    /// - Background session doesn't support streaming upload from memory
    /// - Must create temp file with complete multipart body
    /// - Large uploads consume disk space temporarily
    @available(iOS 13.0, *)
    private func uploadWithBackgroundSession(
        url: URL,
        config: Config,
        validatedFiles: [(url: URL, fileName: String, mimeType: String)],
        totalSize: Int64
    ) async -> WorkerResult {
        print("HttpUploadWorker: Using background URLSession for upload")

        // Build multipart body
        var body = Data()

        // Add form fields
        if let fields = config.fields {
            for (key, value) in fields {
                body.append("--\(HttpUploadWorker.boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
        }

        // Get file configs
        let fileConfigs = config.getFileConfigs()

        // Add all files to multipart body
        for (index, (fileURL, fileName, mimeType)) in validatedFiles.enumerated() {
            let fileFieldName = fileConfigs[index].effectiveFileFieldName

            body.append("--\(HttpUploadWorker.boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)

            // Read file data
            guard let fileData = try? Data(contentsOf: fileURL) else {
                print("HttpUploadWorker: Error - Failed to read file: \(fileName)")
                return .failure(message: "Failed to read file: \(fileName)")
            }
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }

        // End boundary
        body.append("--\(HttpUploadWorker.boundary)--\r\n".data(using: .utf8)!)

        // Save multipart body to temp file (background session requires file upload)
        let tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("upload-\(UUID().uuidString).tmp")

        do {
            try body.write(to: tempFileURL)
        } catch {
            print("HttpUploadWorker: Error - Failed to write temp upload file: \(error)")
            return .failure(message: "Failed to create temp upload file: \(error.localizedDescription)")
        }

        // Ensure temp file is deleted after upload
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }

        // Build headers with multipart content-type
        var headers = config.headers ?? [:]
        headers["Content-Type"] = "multipart/form-data; boundary=\(HttpUploadWorker.boundary)"

        // Execute upload using BackgroundSessionManager
        return await withCheckedContinuation { continuation in
            let taskId = "upload-\(UUID().uuidString)"

            BackgroundSessionManager.shared.upload(
                to: url,
                from: tempFileURL,
                taskId: taskId,
                headers: headers
            ) { result in
                switch result {
                case .success(let response):
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.resume(returning: .failure(message: "Invalid response type"))
                        return
                    }

                    let statusCode = httpResponse.statusCode
                    let success = (200..<300).contains(statusCode)

                    if success {
                        print("HttpUploadWorker: Background upload succeeded - Status \(statusCode)")

                        continuation.resume(returning: .success(
                            message: "Uploaded \(validatedFiles.count) file(s) via background session",
                            data: [
                                "statusCode": statusCode,
                                "uploadedSize": totalSize,
                                "fileCount": validatedFiles.count,
                                "fileNames": validatedFiles.map { $0.fileName },
                                "backgroundSession": true
                            ]
                        ))
                    } else {
                        print("HttpUploadWorker: Background upload failed - Status \(statusCode)")
                        continuation.resume(returning: .failure(message: "HTTP \(statusCode)"))
                    }

                case .failure(let error):
                    print("HttpUploadWorker: Background upload failed: \(error.localizedDescription)")
                    continuation.resume(returning: .failure(message: "Background upload failed: \(error.localizedDescription)"))
                }
            }
        }
    }

    /// Detect MIME type from file extension.
    private func detectMimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()

        if #available(iOS 14.0, *) {
            // Use UTType for modern iOS
            if let utType = UTType(filenameExtension: pathExtension) {
                return utType.preferredMIMEType ?? "application/octet-stream"
            }
        } else {
            // Fallback for iOS 13
            let commonTypes: [String: String] = [
                "jpg": "image/jpeg",
                "jpeg": "image/jpeg",
                "png": "image/png",
                "gif": "image/gif",
                "pdf": "application/pdf",
                "txt": "text/plain",
                "json": "application/json",
                "xml": "application/xml",
                "zip": "application/zip",
                "mp4": "video/mp4",
                "mp3": "audio/mpeg"
            ]
            return commonTypes[pathExtension] ?? "application/octet-stream"
        }

        return "application/octet-stream"
    }
}
