import Foundation

/// Built-in worker: File system operations
///
/// Supports copy, move, delete, list, and mkdir operations for pure-native task chains.
///
/// **Configuration JSON:**
/// ```json
/// // Copy operation
/// {
///   "operation": "copy",
///   "sourcePath": "/path/to/source",
///   "destinationPath": "/path/to/destination",
///   "overwrite": false,
///   "recursive": true
/// }
///
/// // Move operation
/// {
///   "operation": "move",
///   "sourcePath": "/path/to/source",
///   "destinationPath": "/path/to/destination",
///   "overwrite": false
/// }
///
/// // Delete operation
/// {
///   "operation": "delete",
///   "path": "/path/to/file",
///   "recursive": false
/// }
///
/// // List operation
/// {
///   "operation": "list",
///   "path": "/path/to/directory",
///   "pattern": "*.jpg",
///   "recursive": false
/// }
///
/// // Mkdir operation
/// {
///   "operation": "mkdir",
///   "path": "/path/to/new/directory",
///   "createParents": true
/// }
/// ```
class FileSystemWorker: IosWorker {

    func doWork(input: String?) async throws -> WorkerResult {
        guard let input = input, !input.isEmpty else {
            return .failure(message: "Input JSON is required")
        }

        // Parse configuration
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let operation = json["operation"] as? String else {
            return .failure(message: "Invalid JSON configuration")
        }

        switch operation {
        case "copy":
            return handleCopy(json: json)
        case "move":
            return handleMove(json: json)
        case "delete":
            return handleDelete(json: json)
        case "list":
            return handleList(json: json)
        case "mkdir":
            return handleMkdir(json: json)
        default:
            return .failure(message: "Unknown operation: \(operation)")
        }
    }

    private func handleCopy(json: [String: Any]) -> WorkerResult {
        guard let sourcePath = json["sourcePath"] as? String,
              let destinationPath = json["destinationPath"] as? String else {
            return .failure(message: "Missing sourcePath or destinationPath")
        }

        let overwrite = json["overwrite"] as? Bool ?? false
        let recursive = json["recursive"] as? Bool ?? true

        // Security validation
        do {
            if !SecurityValidator.validateFilePath(sourcePath) {
                return .failure(message: "Invalid source path: \(sourcePath)")
            }
            if !SecurityValidator.validateFilePath(destinationPath) {
                return .failure(message: "Invalid destination path: \(destinationPath)")
            }
        } catch {
            return .failure(message: "Security validation failed: \(error.localizedDescription)")
        }

        let sourceURL = URL(fileURLWithPath: sourcePath)
        let destURL = URL(fileURLWithPath: destinationPath)
        let fileManager = FileManager.default

        // Check source exists
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return .failure(message: "Source not found: \(sourcePath)")
        }

        // Check destination
        if fileManager.fileExists(atPath: destURL.path) && !overwrite {
            return .failure(message: "Destination already exists: \(destinationPath) (set overwrite=true to replace)")
        }

        // Path traversal protection
        guard destURL.path.hasPrefix(destURL.deletingLastPathComponent().path) else {
            return .failure(message: "Path traversal detected in destination")
        }

        do {
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory)

            let copiedFiles: [URL]
            if isDirectory.boolValue {
                if !recursive {
                    return .failure(message: "Source is a directory, set recursive=true to copy")
                }
                copiedFiles = try copyDirectory(source: sourceURL, destination: destURL, overwrite: overwrite)
            } else {
                try copyFile(source: sourceURL, destination: destURL, overwrite: overwrite)
                copiedFiles = [destURL]
            }

            let totalSize = copiedFiles.reduce(Int64(0)) { sum, url in
                let attrs = try? fileManager.attributesOfItem(atPath: url.path)
                let size = attrs?[.size] as? Int64 ?? 0
                return sum + size
            }

            return .success(
                message: "Copied \(copiedFiles.count) file(s)",
                data: [
                    "operation": "copy",
                    "sourcePath": sourcePath,
                    "destinationPath": destinationPath,
                    "fileCount": copiedFiles.count,
                    "totalSize": totalSize,
                    "files": copiedFiles.map { $0.path }
                ]
            )
        } catch {
            return .failure(message: "Copy failed: \(error.localizedDescription)")
        }
    }

    private func handleMove(json: [String: Any]) -> WorkerResult {
        guard let sourcePath = json["sourcePath"] as? String,
              let destinationPath = json["destinationPath"] as? String else {
            return .failure(message: "Missing sourcePath or destinationPath")
        }

        let overwrite = json["overwrite"] as? Bool ?? false

        // Security validation
        do {
            if !SecurityValidator.validateFilePath(sourcePath) {
                return .failure(message: "Invalid source path: \(sourcePath)")
            }
            if !SecurityValidator.validateFilePath(destinationPath) {
                return .failure(message: "Invalid destination path: \(destinationPath)")
            }
        } catch {
            return .failure(message: "Security validation failed: \(error.localizedDescription)")
        }

        let sourceURL = URL(fileURLWithPath: sourcePath)
        let destURL = URL(fileURLWithPath: destinationPath)
        let fileManager = FileManager.default

        // Check source exists
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return .failure(message: "Source not found: \(sourcePath)")
        }

        // Check destination
        if fileManager.fileExists(atPath: destURL.path) && !overwrite {
            return .failure(message: "Destination already exists: \(destinationPath) (set overwrite=true to replace)")
        }

        // Path traversal protection
        guard destURL.path.hasPrefix(destURL.deletingLastPathComponent().path) else {
            return .failure(message: "Path traversal detected in destination")
        }

        do {
            // Create parent directory
            try fileManager.createDirectory(
                at: destURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            // Delete destination if overwriting
            if fileManager.fileExists(atPath: destURL.path) && overwrite {
                try fileManager.removeItem(at: destURL)
            }

            // Move file/directory
            try fileManager.moveItem(at: sourceURL, to: destURL)

            // Count files
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: destURL.path, isDirectory: &isDirectory)

            let fileCount: Int
            if isDirectory.boolValue {
                fileCount = try countFiles(in: destURL)
            } else {
                fileCount = 1
            }

            return .success(
                message: "Moved \(fileCount) file(s)",
                data: [
                    "operation": "move",
                    "sourcePath": sourcePath,
                    "destinationPath": destinationPath,
                    "fileCount": fileCount
                ]
            )
        } catch {
            return .failure(message: "Move failed: \(error.localizedDescription)")
        }
    }

    private func handleDelete(json: [String: Any]) -> WorkerResult {
        guard let path = json["path"] as? String else {
            return .failure(message: "Missing path")
        }

        let recursive = json["recursive"] as? Bool ?? false

        // Security validation
        do {
            if !SecurityValidator.validateFilePath(path) {
                return .failure(message: "Invalid path: \(path)")
            }
        } catch {
            return .failure(message: "Security validation failed: \(error.localizedDescription)")
        }

        let fileURL = URL(fileURLWithPath: path)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .failure(message: "Path not found: \(path)")
        }

        // Safety check: prevent accidental deletion of important directories
        let dangerousPaths = ["/", "/System", "/Library", "/usr", "/var"]
        for dangerousPath in dangerousPaths {
            if fileURL.path.hasPrefix(dangerousPath) && fileURL.path.count <= dangerousPath.count + 1 {
                return .failure(message: "Cannot delete protected path: \(path)")
            }
        }

        do {
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)

            let fileCount: Int
            if isDirectory.boolValue {
                if !recursive {
                    return .failure(message: "Path is a directory, set recursive=true to delete")
                }
                fileCount = try countFiles(in: fileURL)
            } else {
                fileCount = 1
            }

            try fileManager.removeItem(at: fileURL)

            return .success(
                message: "Deleted \(fileCount) file(s)",
                data: [
                    "operation": "delete",
                    "path": path,
                    "fileCount": fileCount
                ]
            )
        } catch {
            return .failure(message: "Delete failed: \(error.localizedDescription)")
        }
    }

    private func handleList(json: [String: Any]) -> WorkerResult {
        guard let path = json["path"] as? String else {
            return .failure(message: "Missing path")
        }

        let pattern = json["pattern"] as? String
        let recursive = json["recursive"] as? Bool ?? false

        // Security validation
        do {
            if !SecurityValidator.validateFilePath(path) {
                return .failure(message: "Invalid path: \(path)")
            }
        } catch {
            return .failure(message: "Security validation failed: \(error.localizedDescription)")
        }

        let dirURL = URL(fileURLWithPath: path)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: dirURL.path) else {
            return .failure(message: "Path not found: \(path)")
        }

        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: dirURL.path, isDirectory: &isDirectory)

        guard isDirectory.boolValue else {
            return .failure(message: "Path is not a directory: \(path)")
        }

        do {
            let files: [URL]
            if recursive {
                files = try listFilesRecursive(in: dirURL)
            } else {
                let contents = try fileManager.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil)
                files = contents.filter { url in
                    var isDir: ObjCBool = false
                    fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
                    return !isDir.boolValue
                }
            }

            // Apply pattern filter
            let filteredFiles = try filterFiles(files, pattern: pattern)

            // Build file info
            let fileInfos: [[String: Any]] = try filteredFiles.map { url in
                let attrs = try fileManager.attributesOfItem(atPath: url.path)
                return [
                    "path": url.path,
                    "name": url.lastPathComponent,
                    "size": attrs[.size] as? Int64 ?? 0,
                    "lastModified": (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0,
                    "isDirectory": false
                ]
            }

            let totalSize = fileInfos.reduce(Int64(0)) { sum, info in
                sum + (info["size"] as? Int64 ?? 0)
            }

            return .success(
                message: "Found \(filteredFiles.count) file(s)",
                data: [
                    "operation": "list",
                    "path": path,
                    "pattern": pattern ?? "",
                    "recursive": recursive,
                    "fileCount": filteredFiles.count,
                    "totalSize": totalSize,
                    "files": fileInfos
                ]
            )
        } catch {
            return .failure(message: "List failed: \(error.localizedDescription)")
        }
    }

    private func handleMkdir(json: [String: Any]) -> WorkerResult {
        guard let path = json["path"] as? String else {
            return .failure(message: "Missing path")
        }

        let createParents = json["createParents"] as? Bool ?? true

        // Security validation
        do {
            if !SecurityValidator.validateFilePath(path) {
                return .failure(message: "Invalid path: \(path)")
            }
        } catch {
            return .failure(message: "Security validation failed: \(error.localizedDescription)")
        }

        let dirURL = URL(fileURLWithPath: path)
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: dirURL.path) {
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: dirURL.path, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                return .success(
                    message: "Directory already exists",
                    data: [
                        "operation": "mkdir",
                        "path": path,
                        "created": false
                    ]
                )
            } else {
                return .failure(message: "Path exists but is not a directory: \(path)")
            }
        }

        // Path traversal protection
        guard dirURL.path.hasPrefix(dirURL.deletingLastPathComponent().path) else {
            return .failure(message: "Path traversal detected")
        }

        do {
            try fileManager.createDirectory(
                at: dirURL,
                withIntermediateDirectories: createParents
            )

            return .success(
                message: "Directory created",
                data: [
                    "operation": "mkdir",
                    "path": path,
                    "created": true
                ]
            )
        } catch {
            return .failure(message: "Mkdir failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Methods

    private func copyFile(source: URL, destination: URL, overwrite: Bool) throws {
        let fileManager = FileManager.default

        // Create parent directory
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Delete existing if overwriting
        if fileManager.fileExists(atPath: destination.path) && overwrite {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.copyItem(at: source, to: destination)
    }

    private func copyDirectory(source: URL, destination: URL, overwrite: Bool) throws -> [URL] {
        let fileManager = FileManager.default
        var copiedFiles: [URL] = []

        // Create destination directory
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        // Get contents
        guard let enumerator = fileManager.enumerator(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            throw NSError(domain: "FileSystemWorker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot enumerate directory"])
        }

        for case let fileURL as URL in enumerator {
            let relativePath = fileURL.path.replacingOccurrences(of: source.path + "/", with: "")
            let destURL = destination.appendingPathComponent(relativePath)

            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues.isDirectory == true {
                try fileManager.createDirectory(at: destURL, withIntermediateDirectories: true)
            } else {
                try copyFile(source: fileURL, destination: destURL, overwrite: overwrite)
                copiedFiles.append(destURL)
            }
        }

        return copiedFiles
    }

    private func countFiles(in directory: URL) throws -> Int {
        let fileManager = FileManager.default
        var count = 0

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues.isDirectory != true {
                count += 1
            }
        }

        return count
    }

    private func listFilesRecursive(in directory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        var files: [URL] = []

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues.isDirectory != true {
                files.append(fileURL)
            }
        }

        return files
    }

    private func filterFiles(_ files: [URL], pattern: String?) throws -> [URL] {
        guard let pattern = pattern, !pattern.isEmpty else {
            return files
        }

        // Convert glob pattern to regex
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")

        let regex = try NSRegularExpression(pattern: "^" + regexPattern + "$")

        return files.filter { url in
            let fileName = url.lastPathComponent
            let range = NSRange(fileName.startIndex..<fileName.endIndex, in: fileName)
            return regex.firstMatch(in: fileName, range: range) != nil
        }
    }
}
