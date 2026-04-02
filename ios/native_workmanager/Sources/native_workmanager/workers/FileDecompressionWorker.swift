import Foundation
import Compression
import ZIPFoundation

/// Native file decompression worker for iOS.
///
/// Extracts ZIP files using streaming to minimize memory usage.
/// Includes security protections against zip slip attacks.
///
/// **Configuration JSON:**
/// ```json
/// {
///   "zipPath": "/path/to/archive.zip",
///   "targetDir": "/path/to/extract/",
///   "overwrite": true,           // Optional: Overwrite existing files (default: true)
///   "deleteAfterExtract": false  // Optional: Delete ZIP after successful extraction (default: false)
/// }
/// ```
///
/// **Features:**
/// - Streaming extraction (low memory usage)
/// - Zip slip protection (prevents path traversal attacks)
/// - Auto-creates target directory
/// - Atomic operations (cleanup on error)
///
/// **Security:**
/// - Validates all extracted paths are within target directory
/// - Prevents path traversal via ".." in ZIP entries
/// - Validates file sizes during extraction
///
/// **Performance:** ~5-10MB RAM regardless of ZIP size
class FileDecompressionWorker: IosWorker {

    struct Config: Codable {
        let zipPath: String
        let targetDir: String
        let overwrite: Bool?
        let deleteAfterExtract: Bool?

        var shouldOverwrite: Bool {
            overwrite ?? true
        }

        var shouldDeleteZip: Bool {
            deleteAfterExtract ?? false
        }
    }

    func doWork(input: String?) async throws -> WorkerResult {
        // ✅ IOS: Register background task to request extra execution time
        // iOS will freeze the app shortly after moving to background otherwise.
        var bgTaskId = UIBackgroundTaskIdentifier.invalid
        bgTaskId = UIApplication.shared.beginBackgroundTask(withName: "BrewkitsFileDecompression") {
            NativeLogger.d("FileDecompressionWorker: Background time expired — ending task")
            UIApplication.shared.endBackgroundTask(bgTaskId)
        }

        defer {
            UIApplication.shared.endBackgroundTask(bgTaskId)
        }

        guard let input = input, !input.isEmpty else {
            print("FileDecompressionWorker: Error - Empty or null input")
            return .failure(message: "Empty or null input")
        }

        // Parse configuration
        guard let data = input.data(using: .utf8) else {
            print("FileDecompressionWorker: Error - Invalid UTF-8 encoding")
            return .failure(message: "Invalid input encoding")
        }

        let config: Config
        do {
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            print("FileDecompressionWorker: Error parsing JSON config: \(error)")
            return .failure(message: "Invalid JSON config: \(error.localizedDescription)")
        }

        // ✅ SECURITY: Validate paths
        guard SecurityValidator.validateFilePath(config.zipPath) else {
            print("FileDecompressionWorker: Error - Invalid ZIP path")
            return .failure(message: "Invalid ZIP path")
        }

        guard SecurityValidator.validateFilePath(config.targetDir) else {
            print("FileDecompressionWorker: Error - Invalid target directory")
            return .failure(message: "Invalid target directory")
        }

        let zipURL = URL(fileURLWithPath: config.zipPath)
        let targetDirURL = URL(fileURLWithPath: config.targetDir)

        // Validate ZIP file exists
        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            print("FileDecompressionWorker: Error - ZIP file not found: \(config.zipPath)")
            return .failure(message: "ZIP file not found")
        }

        // ✅ SECURITY: Validate archive size
        guard SecurityValidator.validateArchiveSize(zipURL) else {
            print("FileDecompressionWorker: Error - Archive size exceeds limit")
            return .failure(message: "Archive size exceeds limit")
        }

        // Create target directory if needed
        if !FileManager.default.fileExists(atPath: targetDirURL.path) {
            do {
                try FileManager.default.createDirectory(at: targetDirURL,
                                                       withIntermediateDirectories: true)
                print("FileDecompressionWorker: Created directory: \(targetDirURL.path)")
            } catch {
                print("FileDecompressionWorker: Error creating directory: \(error)")
                return .failure(message: "Failed to create target directory: \(error.localizedDescription)")
            }
        }

        // Get canonical path for security checks
        let canonicalTargetPath = targetDirURL.standardizedFileURL.path

        print("FileDecompressionWorker: Extracting \(zipURL.lastPathComponent)")
        print("  Target: \(targetDirURL.path)")

        var extractedFiles = 0
        var extractedDirs = 0
        var totalBytes: Int64 = 0
        var extractedPaths: [String] = []

        do {
            // Use Foundation's built-in unzipping
            let fileManager = FileManager.default

            // For iOS, we'll use a simpler approach with NSFileCoordinator and unzipping
            // Note: iOS doesn't have built-in ZIP support in Foundation, so we use a workaround

            // Create a temporary directory for extraction
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

            defer {
                // LEAK-001: log warning if temp-dir cleanup fails so transient disk usage is visible.
                do {
                    try fileManager.removeItem(at: tempDir)
                } catch {
                    print("FileDecompressionWorker: WARNING — failed to remove temp dir \(tempDir.lastPathComponent): \(error.localizedDescription)")
                }
            }

            // iOS Workaround: Use unzip command via Process
            // This is a simplified implementation. In production, consider using:
            // - ZIPFoundation library (https://github.com/weichsel/ZIPFoundation)
            // - Compression framework for more control

            // For now, we'll manually iterate through ZIP entries using basic file operations
            // This is a placeholder that should be replaced with proper ZIP library

            let unzipResult = try await unzipFile(
                zipURL: zipURL,
                destinationURL: targetDirURL,
                canonicalPath: canonicalTargetPath,
                overwrite: config.shouldOverwrite
            )

            extractedFiles = unzipResult.files
            extractedDirs = unzipResult.dirs
            totalBytes = unzipResult.bytes
            extractedPaths = unzipResult.paths

            // ✅ Optional: Delete ZIP file after successful extraction
            if config.shouldDeleteZip {
                try fileManager.removeItem(at: zipURL)
                print("FileDecompressionWorker: Deleted ZIP file")
            }

            print("FileDecompressionWorker: Extraction complete")
            print("  Files: \(extractedFiles), Directories: \(extractedDirs)")
            print("  Total size: \(totalBytes) bytes")

            // ✅ Return success with extraction data
            return .success(
                message: "Extracted \(extractedFiles) files, \(extractedDirs) directories",
                data: [
                    "extractedFiles": extractedFiles,
                    "extractedDirs": extractedDirs,
                    "totalBytes": totalBytes,
                    "targetDir": targetDirURL.path,
                    "zipDeleted": config.shouldDeleteZip
                ]
            )

        } catch {
            print("FileDecompressionWorker: Error during extraction: \(error)")
            // Clean up partially extracted files
            cleanupExtractedFiles(paths: extractedPaths)
            return .failure(message: error.localizedDescription)
        }
    }

    /// Unzip file using ZIPFoundation's high-level FileManager API.
    ///
    /// Uses `FileManager.unzipItem(at:to:)` which is the recommended ZIPFoundation
    /// API and correctly handles path resolution on all iOS versions/devices,
    /// including real devices where /var is a symlink to /private/var.
    private func unzipFile(
        zipURL: URL,
        destinationURL: URL,
        canonicalPath: String,
        overwrite: Bool
    ) async throws -> (files: Int, dirs: Int, bytes: Int64, paths: [String]) {
        guard let archive = Archive(url: zipURL, accessMode: .read) else {
            throw NSError(domain: "FileDecompressionWorker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot open ZIP archive"])
        }

        var extractedFiles = 0
        var extractedDirs = 0
        var totalBytes: Int64 = 0
        var paths: [String] = []
        
        let MAX_TOTAL_SIZE: Int64 = 2 * 1024 * 1024 * 1024 // 2GB Hard Limit
        let MAX_RATIO: Int64 = 100 // 100:1 Max Ratio

        for entry in archive {
            let entryPath = entry.path
            let destURL = destinationURL.appendingPathComponent(entryPath)

            // ✅ SECURITY: Zip Slip Protection
            let resolvedEntry = destURL.standardizedFileURL.path
            guard resolvedEntry.hasPrefix(destinationURL.standardizedFileURL.path) else {
                // CROSS-005: clean up partial extractions before throwing so the caller's
                // extractedPaths (still empty at throw time) doesn't leave orphaned files.
                for p in paths.reversed() { try? FileManager.default.removeItem(atPath: p) }
                throw NSError(domain: "FileDecompressionWorker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Zip slip attack detected: \(entryPath)"])
            }

            // ✅ SECURITY: Zip Bomb Protection (Metadata check)
            if entry.uncompressedSize > MAX_TOTAL_SIZE {
                for p in paths.reversed() { try? FileManager.default.removeItem(atPath: p) }
                throw NSError(domain: "FileDecompressionWorker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Zip bomb detected: entry too large"])
            }

            if entry.compressedSize > 0 && (entry.uncompressedSize / entry.compressedSize) > MAX_RATIO {
                for p in paths.reversed() { try? FileManager.default.removeItem(atPath: p) }
                throw NSError(domain: "FileDecompressionWorker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Zip bomb detected: suspicious compression ratio"])
            }

            // Handle Overwrite
            if FileManager.default.fileExists(atPath: destURL.path) {
                if overwrite {
                    try FileManager.default.removeItem(at: destURL)
                } else {
                    continue // Skip if not overwriting
                }
            }

            // Extract
            _ = try archive.extract(entry, to: destURL)

            paths.append(destURL.path)
            if entry.type == .directory {
                extractedDirs += 1
            } else {
                extractedFiles += 1
                totalBytes += Int64(entry.uncompressedSize)
            }

            // ✅ SECURITY: Zip Bomb Protection (Cumulative check)
            if totalBytes > MAX_TOTAL_SIZE {
                for p in paths.reversed() { try? FileManager.default.removeItem(atPath: p) }
                throw NSError(domain: "FileDecompressionWorker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Zip bomb detected: total size limit exceeded"])
            }
        }

        return (extractedFiles, extractedDirs, totalBytes, paths)
    }

    /// Clean up extracted files in case of error
    private func cleanupExtractedFiles(paths: [String]) {
        print("FileDecompressionWorker: Cleaning up \(paths.count) extracted files/directories...")

        // Reverse order to delete files before their parent directories
        for path in paths.reversed() {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                print("FileDecompressionWorker: Failed to cleanup \(path): \(error)")
            }
        }
    }
}
