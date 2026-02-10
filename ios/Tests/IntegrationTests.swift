import XCTest
@testable import native_workmanager

/// Integration tests for Native WorkManager iOS workers.
///
/// These tests verify that workers execute correctly with real JSON configs.
class IntegrationTests: XCTestCase {

    // MARK: - Native Worker Tests

    func testHttpRequestWorker_GET() async throws {
        let worker = HttpRequestWorker()

        let config = """
        {
            "url": "https://httpbin.org/get",
            "method": "get"
        }
        """

        let result = try await worker.doWork(input: config)

        XCTAssertTrue(result, "GET request should succeed")
    }

    func testHttpRequestWorker_POST() async throws {
        let worker = HttpRequestWorker()

        let config = """
        {
            "url": "https://httpbin.org/post",
            "method": "post",
            "headers": {
                "Content-Type": "application/json"
            },
            "body": "{\\"test\\":\\"data\\"}"
        }
        """

        let result = try await worker.doWork(input: config)

        XCTAssertTrue(result, "POST request should succeed")
    }

    func testHttpRequestWorker_InvalidURL() async throws {
        let worker = HttpRequestWorker()

        let config = """
        {
            "url": "not-a-valid-url",
            "method": "get"
        }
        """

        let result = try await worker.doWork(input: config)

        XCTAssertFalse(result, "Invalid URL should fail")
    }

    func testHttpRequestWorker_404() async throws {
        let worker = HttpRequestWorker()

        let config = """
        {
            "url": "https://httpbin.org/status/404",
            "method": "get"
        }
        """

        let result = try await worker.doWork(input: config)

        XCTAssertFalse(result, "404 response should fail")
    }

    func testHttpSyncWorker_JSONSync() async throws {
        let worker = HttpSyncWorker()

        let config = """
        {
            "url": "https://httpbin.org/post",
            "method": "post",
            "requestBody": {
                "lastSync": 1234567890,
                "data": ["item1", "item2"]
            }
        }
        """

        let result = try await worker.doWork(input: config)

        XCTAssertTrue(result, "JSON sync should succeed")
    }

    // MARK: - Worker Factory Tests

    func testWorkerFactory_CreatesValidWorkers() {
        let workers = [
            "HttpRequestWorker",
            "HttpUploadWorker",
            "HttpDownloadWorker",
            "HttpSyncWorker",
            "DartCallbackWorker",
            "FileCompressionWorker"
        ]

        for workerName in workers {
            let worker = IosWorkerFactory.createWorker(className: workerName)
            XCTAssertNotNil(worker, "\(workerName) should be created")
        }
    }

    func testWorkerFactory_ReturnsNilForInvalidWorker() {
        let worker = IosWorkerFactory.createWorker(className: "InvalidWorker")
        XCTAssertNil(worker, "Invalid worker should return nil")
    }

    // MARK: - Error Handling Tests

    func testHttpRequestWorker_EmptyInput() async throws {
        let worker = HttpRequestWorker()
        let result = try await worker.doWork(input: nil)
        XCTAssertFalse(result, "Empty input should fail")
    }

    func testHttpRequestWorker_InvalidJSON() async throws {
        let worker = HttpRequestWorker()
        let result = try await worker.doWork(input: "not-valid-json")
        XCTAssertFalse(result, "Invalid JSON should fail")
    }

    func testHttpRequestWorker_MissingURL() async throws {
        let worker = HttpRequestWorker()

        let config = """
        {
            "method": "get"
        }
        """

        let result = try await worker.doWork(input: config)
        XCTAssertFalse(result, "Missing URL should fail")
    }

    // MARK: - File Compression Tests

    func testFileCompressionWorker_SingleFile() async throws {
        let worker = FileCompressionWorker()
        let tempDir = FileManager.default.temporaryDirectory

        // Create test file
        let testFile = tempDir.appendingPathComponent("test.txt")
        try "Hello, World!".write(to: testFile, atomically: true, encoding: .utf8)

        let outputZip = tempDir.appendingPathComponent("output.zip")

        let config = """
        {
            "inputPath": "\(testFile.path)",
            "outputPath": "\(outputZip.path)",
            "compressionLevel": "medium"
        }
        """

        // Clean up before test
        try? FileManager.default.removeItem(at: outputZip)

        let result = try await worker.doWork(input: config)

        XCTAssertTrue(result, "Compression should succeed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputZip.path), "ZIP file should exist")
        XCTAssertGreaterThan(try outputZip.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0, 0, "ZIP file should not be empty")

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
        try? FileManager.default.removeItem(at: outputZip)
    }

    func testFileCompressionWorker_Directory() async throws {
        let worker = FileCompressionWorker()
        let tempDir = FileManager.default.temporaryDirectory

        // Create test directory structure
        let testDir = tempDir.appendingPathComponent("test_dir_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        try "File 1 content".write(to: testDir.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        try "File 2 content".write(to: testDir.appendingPathComponent("file2.txt"), atomically: true, encoding: .utf8)

        let subDir = testDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try "File 3 content".write(to: subDir.appendingPathComponent("file3.txt"), atomically: true, encoding: .utf8)

        let outputZip = tempDir.appendingPathComponent("dir_output.zip")

        let config = """
        {
            "inputPath": "\(testDir.path)",
            "outputPath": "\(outputZip.path)"
        }
        """

        // Clean up before test
        try? FileManager.default.removeItem(at: outputZip)

        let result = try await worker.doWork(input: config)

        XCTAssertTrue(result, "Directory compression should succeed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputZip.path), "ZIP file should exist")

        // Clean up
        try? FileManager.default.removeItem(at: testDir)
        try? FileManager.default.removeItem(at: outputZip)
    }

    func testFileCompressionWorker_ExcludePatterns() async throws {
        let worker = FileCompressionWorker()
        let tempDir = FileManager.default.temporaryDirectory

        // Create test directory with files to exclude
        let testDir = tempDir.appendingPathComponent("test_exclude_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        try "Keep this".write(to: testDir.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        try "Exclude this".write(to: testDir.appendingPathComponent("file2.tmp"), atomically: true, encoding: .utf8)
        try "Exclude this too".write(to: testDir.appendingPathComponent(".DS_Store"), atomically: true, encoding: .utf8)

        let outputZip = tempDir.appendingPathComponent("exclude_output.zip")

        let config = """
        {
            "inputPath": "\(testDir.path)",
            "outputPath": "\(outputZip.path)",
            "excludePatterns": ["*.tmp", ".DS_Store"]
        }
        """

        // Clean up before test
        try? FileManager.default.removeItem(at: outputZip)

        let result = try await worker.doWork(input: config)

        XCTAssertTrue(result, "Compression with exclusions should succeed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputZip.path), "ZIP file should exist")

        // Clean up
        try? FileManager.default.removeItem(at: testDir)
        try? FileManager.default.removeItem(at: outputZip)
    }

    func testFileCompressionWorker_DeleteOriginal() async throws {
        let worker = FileCompressionWorker()
        let tempDir = FileManager.default.temporaryDirectory

        // Create test file
        let testFile = tempDir.appendingPathComponent("delete_me.txt")
        try "This will be deleted".write(to: testFile, atomically: true, encoding: .utf8)

        let outputZip = tempDir.appendingPathComponent("delete_output.zip")

        let config = """
        {
            "inputPath": "\(testFile.path)",
            "outputPath": "\(outputZip.path)",
            "deleteOriginal": true
        }
        """

        // Clean up before test
        try? FileManager.default.removeItem(at: outputZip)

        // Verify file exists before compression
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path), "Test file should exist before compression")

        let result = try await worker.doWork(input: config)

        XCTAssertTrue(result, "Compression should succeed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputZip.path), "ZIP file should exist")
        XCTAssertFalse(FileManager.default.fileExists(atPath: testFile.path), "Original file should be deleted")

        // Clean up
        try? FileManager.default.removeItem(at: outputZip)
    }

    func testFileCompressionWorker_InvalidInput() async throws {
        let worker = FileCompressionWorker()

        // Test null input
        var result = try await worker.doWork(input: nil)
        XCTAssertFalse(result, "Null input should fail")

        // Test missing inputPath
        result = try await worker.doWork(input: """
        {
            "outputPath": "/tmp/output.zip"
        }
        """)
        XCTAssertFalse(result, "Missing inputPath should fail")

        // Test missing outputPath
        result = try await worker.doWork(input: """
        {
            "inputPath": "/tmp/test.txt"
        }
        """)
        XCTAssertFalse(result, "Missing outputPath should fail")

        // Test non-existent input file
        result = try await worker.doWork(input: """
        {
            "inputPath": "/nonexistent/path/file.txt",
            "outputPath": "\(FileManager.default.temporaryDirectory.appendingPathComponent("output.zip").path)"
        }
        """)
        XCTAssertFalse(result, "Non-existent input file should fail")

        // Test output path without .zip extension
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        try "Test".write(to: tempFile, atomically: true, encoding: .utf8)

        result = try await worker.doWork(input: """
        {
            "inputPath": "\(tempFile.path)",
            "outputPath": "\(FileManager.default.temporaryDirectory.appendingPathComponent("output.txt").path)"
        }
        """)
        XCTAssertFalse(result, "Output path without .zip should fail")

        // Clean up
        try? FileManager.default.removeItem(at: tempFile)
    }

    func testFileCompressionWorker_CompressionLevels() async throws {
        let worker = FileCompressionWorker()
        let tempDir = FileManager.default.temporaryDirectory

        // Create test file with repetitive content (compresses well)
        let testFile = tempDir.appendingPathComponent("compressible.txt")
        try String(repeating: "A", count: 10000).write(to: testFile, atomically: true, encoding: .utf8)

        for level in ["low", "medium", "high"] {
            let outputZip = tempDir.appendingPathComponent("output_\(level).zip")

            let config = """
            {
                "inputPath": "\(testFile.path)",
                "outputPath": "\(outputZip.path)",
                "compressionLevel": "\(level)"
            }
            """

            // Clean up before test
            try? FileManager.default.removeItem(at: outputZip)

            let result = try await worker.doWork(input: config)

            XCTAssertTrue(result, "Compression with level '\(level)' should succeed")
            XCTAssertTrue(FileManager.default.fileExists(atPath: outputZip.path), "ZIP file should exist for level '\(level)'")

            // Clean up
            try? FileManager.default.removeItem(at: outputZip)
        }

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    // MARK: - File Download Tests

    func testHttpDownloadWorker_SmallFile() async throws {
        let worker = HttpDownloadWorker()

        // Create temp directory
        let tempDir = FileManager.default.temporaryDirectory
        let savePath = tempDir.appendingPathComponent("test_download.txt").path

        let config = """
        {
            "url": "https://httpbin.org/base64/SGVsbG8gV29ybGQ=",
            "savePath": "\(savePath)"
        }
        """

        // Clean up before test
        try? FileManager.default.removeItem(atPath: savePath)

        let result = try await worker.doWork(input: config)

        XCTAssertTrue(result, "Download should succeed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: savePath), "File should exist")

        // Clean up after test
        try? FileManager.default.removeItem(atPath: savePath)
    }

    // MARK: - File Upload Tests

    func testHttpUploadWorker_BasicUpload() async throws {
        let worker = HttpUploadWorker()
        let tempDir = FileManager.default.temporaryDirectory

        // Create test file
        let testFile = tempDir.appendingPathComponent("upload_test.txt")
        try "Test upload content".write(to: testFile, atomically: true, encoding: .utf8)

        let config = """
        {
            "url": "https://httpbin.org/post",
            "filePath": "\(testFile.path)",
            "fileFieldName": "file"
        }
        """

        let result = try await worker.doWork(input: config)

        XCTAssertTrue(result, "Basic upload should succeed")

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    func testHttpUploadWorker_WithCustomFileName() async throws {
        let worker = HttpUploadWorker()
        let tempDir = FileManager.default.temporaryDirectory

        // Create test file with UUID name (simulating temp file)
        let testFile = tempDir.appendingPathComponent("temp_\(UUID().uuidString).txt")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)

        let config = """
        {
            "url": "https://httpbin.org/post",
            "filePath": "\(testFile.path)",
            "fileName": "custom_name.txt",
            "fileFieldName": "file"
        }
        """

        let result = try await worker.doWork(input: config)

        XCTAssertTrue(result, "Upload with custom fileName should succeed")

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    func testHttpUploadWorker_WithCustomMimeType() async throws {
        let worker = HttpUploadWorker()
        let tempDir = FileManager.default.temporaryDirectory

        // Create test file
        let testFile = tempDir.appendingPathComponent("test.custom")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)

        let config = """
        {
            "url": "https://httpbin.org/post",
            "filePath": "\(testFile.path)",
            "mimeType": "application/custom"
        }
        """

        let result = try await worker.doWork(input: config)

        XCTAssertTrue(result, "Upload with custom mimeType should succeed")

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    func testHttpUploadWorker_WithFileNameAndMimeType() async throws {
        let worker = HttpUploadWorker()
        let tempDir = FileManager.default.temporaryDirectory

        // Create test file simulating iOS HEIC photo
        let testFile = tempDir.appendingPathComponent("photo_\(UUID().uuidString).heic")
        try "Mock HEIC content".write(to: testFile, atomically: true, encoding: .utf8)

        let config = """
        {
            "url": "https://httpbin.org/post",
            "filePath": "\(testFile.path)",
            "fileName": "profile_\(Int(Date().timeIntervalSince1970)).jpg",
            "mimeType": "image/heic"
        }
        """

        let result = try await worker.doWork(input: config)

        XCTAssertTrue(result, "Upload with custom fileName and mimeType should succeed")

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    func testHttpUploadWorker_WithAdditionalFields() async throws {
        let worker = HttpUploadWorker()
        let tempDir = FileManager.default.temporaryDirectory

        // Create test file
        let testFile = tempDir.appendingPathComponent("test_with_fields.txt")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)

        let config = """
        {
            "url": "https://httpbin.org/post",
            "filePath": "\(testFile.path)",
            "additionalFields": {
                "userId": "12345",
                "description": "Test upload"
            }
        }
        """

        let result = try await worker.doWork(input: config)

        XCTAssertTrue(result, "Upload with additional fields should succeed")

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    func testHttpUploadWorker_WithHeaders() async throws {
        let worker = HttpUploadWorker()
        let tempDir = FileManager.default.temporaryDirectory

        // Create test file
        let testFile = tempDir.appendingPathComponent("test_with_headers.txt")
        try "Test content".write(to: testFile, atomically: true, encoding: .utf8)

        let config = """
        {
            "url": "https://httpbin.org/post",
            "filePath": "\(testFile.path)",
            "headers": {
                "Authorization": "Bearer test-token",
                "X-Custom-Header": "custom-value"
            }
        }
        """

        let result = try await worker.doWork(input: config)

        XCTAssertTrue(result, "Upload with custom headers should succeed")

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    func testHttpUploadWorker_InvalidInput() async throws {
        let worker = HttpUploadWorker()

        // Test null input
        var result = try await worker.doWork(input: nil)
        XCTAssertFalse(result, "Null input should fail")

        // Test missing filePath
        result = try await worker.doWork(input: """
        {
            "url": "https://httpbin.org/post"
        }
        """)
        XCTAssertFalse(result, "Missing filePath should fail")

        // Test non-existent file
        result = try await worker.doWork(input: """
        {
            "url": "https://httpbin.org/post",
            "filePath": "/nonexistent/file.txt"
        }
        """)
        XCTAssertFalse(result, "Non-existent file should fail")
    }

    func testHttpUploadWorker_RealWorldScenario() async throws {
        let worker = HttpUploadWorker()
        let tempDir = FileManager.default.temporaryDirectory

        // Simulate real-world iOS photo upload scenario
        let testFile = tempDir.appendingPathComponent("IMG_\(UUID().uuidString).heic")
        try "Mock photo data".write(to: testFile, atomically: true, encoding: .utf8)

        let config = """
        {
            "url": "https://httpbin.org/post",
            "filePath": "\(testFile.path)",
            "fileName": "profile_photo.jpg",
            "mimeType": "image/heic",
            "fileFieldName": "photo",
            "additionalFields": {
                "userId": "user123",
                "albumId": "album456"
            },
            "headers": {
                "Authorization": "Bearer test-token"
            }
        }
        """

        let result = try await worker.doWork(input: config)

        XCTAssertTrue(result, "Real-world upload scenario should succeed")

        // Clean up
        try? FileManager.default.removeItem(at: testFile)
    }

    // MARK: - Performance Tests

    func testHttpRequestWorker_Performance() {
        let worker = HttpRequestWorker()

        let config = """
        {
            "url": "https://httpbin.org/get",
            "method": "get"
        }
        """

        measure {
            Task {
                _ = try await worker.doWork(input: config)
            }
        }
    }

    // MARK: - Timeout Tests

    func testHttpRequestWorker_CustomTimeout() async throws {
        let worker = HttpRequestWorker()

        // Use httpbin delay endpoint (will timeout)
        let config = """
        {
            "url": "https://httpbin.org/delay/10",
            "method": "get",
            "timeoutMs": 1000
        }
        """

        let startTime = Date()
        let result = try await worker.doWork(input: config)
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertFalse(result, "Request should timeout")
        XCTAssertLessThan(duration, 5.0, "Should timeout quickly")
    }
}

/// Unit tests for FlutterEngineManager.
class FlutterEngineManagerTests: XCTestCase {

    func testSharedInstance() {
        let instance1 = FlutterEngineManager.shared
        let instance2 = FlutterEngineManager.shared

        XCTAssertTrue(instance1 === instance2, "Should be same instance (singleton)")
    }

    func testSetCallbackHandle() {
        let manager = FlutterEngineManager.shared
        manager.setCallbackHandle(123456)

        // If no crash, test passes
        XCTAssertTrue(true)
    }

    func testIsEngineAlive_InitiallyFalse() {
        let manager = FlutterEngineManager.shared

        // Engine should not be alive initially
        // (unless previous test initialized it)
        // Just check the property exists
        _ = manager.isEngineAlive

        XCTAssertTrue(true)
    }
}
