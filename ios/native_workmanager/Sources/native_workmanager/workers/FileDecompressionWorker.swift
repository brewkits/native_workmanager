import Foundation

/// Native file decompression worker for iOS.
///
/// Extracts ZIP archives created with the STORED method (compression method 0).
/// Uses only Foundation — zero third-party dependencies.
class FileDecompressionWorker: IosWorker {

    func doWork(input: String?, env: WorkerEnvironment) async throws -> WorkerResult {
        guard let input,
              let data = input.data(using: .utf8),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let zipPath = config["zipPath"] as? String,
              let targetDir = config["targetDir"] as? String else {
            return .failure(message: "Invalid input: zipPath and targetDir required")
        }

        guard let zipData = try? Data(contentsOf: URL(fileURLWithPath: zipPath)) else {
            return .failure(message: "Cannot read ZIP file: \(zipPath)")
        }

        do {
            let count = try extractZip(zipData: zipData, targetDir: targetDir)
            let deleteAfter = config["deleteAfterExtract"] as? Bool ?? false
            if deleteAfter { try? FileManager.default.removeItem(atPath: zipPath) }
            return .success(data: ["filesExtracted": count])
        } catch {
            return .failure(message: "Extraction failed: \(error.localizedDescription)")
        }
    }

    // MARK: - ZIP extractor (supports STORED method only)

    private func extractZip(zipData: Data, targetDir: String) throws -> Int {
        let target = URL(fileURLWithPath: targetDir)
        let fm = FileManager.default
        try fm.createDirectory(at: target, withIntermediateDirectories: true)

        var offset = 0
        var count  = 0

        while offset + 30 <= zipData.count {
            // Local file header signature: PK\x03\x04
            guard zipData.readUInt32LE(at: offset) == 0x04034B50 else { break }

            let compressionMethod = zipData.readUInt16LE(at: offset + 8)
            let compressedSize    = Int(zipData.readUInt32LE(at: offset + 18))
            let uncompressedSize  = Int(zipData.readUInt32LE(at: offset + 22))
            let filenameLength    = Int(zipData.readUInt16LE(at: offset + 26))
            let extraLength       = Int(zipData.readUInt16LE(at: offset + 28))

            let filenameStart = offset + 30
            let dataStart     = filenameStart + filenameLength + extraLength

            guard filenameStart + filenameLength <= zipData.count,
                  dataStart + compressedSize <= zipData.count else { break }

            let filename = String(data: zipData[filenameStart..<filenameStart + filenameLength],
                                  encoding: .utf8) ?? "file"

            // Skip directory entries
            if !filename.hasSuffix("/") {
                guard compressionMethod == 0 else {
                    throw NSError(
                        domain: "FileDecompressionWorker", code: -1,
                        userInfo: [NSLocalizedDescriptionKey:
                            "Unsupported compression method \(compressionMethod) in '\(filename)'. Only STORED (0) is supported."]
                    )
                }

                let fileData = zipData[dataStart..<dataStart + uncompressedSize]
                let destURL  = target.appendingPathComponent(filename)
                try fm.createDirectory(at: destURL.deletingLastPathComponent(),
                                       withIntermediateDirectories: true)
                try fileData.write(to: destURL)
                count += 1
            }

            offset = dataStart + compressedSize
        }

        return count
    }
}

// MARK: - Data read helpers

private extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }
    func readUInt32LE(at offset: Int) -> UInt32 {
        UInt32(self[offset]) | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16) | (UInt32(self[offset + 3]) << 24)
    }
}
