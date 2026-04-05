import Foundation

/// Native file compression worker for iOS.
///
/// Creates a ZIP archive using the STORED method (no compression),
/// relying solely on Foundation — zero third-party dependencies.
class FileCompressionWorker: IosWorker {

    func doWork(input: String?) async throws -> WorkerResult {
        guard let input,
              let data = input.data(using: .utf8),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inputPath = config["inputPath"] as? String,
              let outputPath = config["outputPath"] as? String else {
            return .failure(message: "Invalid input: inputPath and outputPath required")
        }

        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: inputPath)) else {
            return .failure(message: "Cannot read input file: \(inputPath)")
        }

        let filename = URL(fileURLWithPath: inputPath).lastPathComponent
        let zipData = createStoredZip(fileData: fileData, filename: filename)

        do {
            try zipData.write(to: URL(fileURLWithPath: outputPath))
            return .success(data: ["outputPath": outputPath, "size": zipData.count])
        } catch {
            return .failure(message: "Cannot write ZIP file: \(error.localizedDescription)")
        }
    }

    // MARK: - Minimal STORED ZIP writer

    private func createStoredZip(fileData: Data, filename: String) -> Data {
        var zip = Data()
        let filenameData = filename.data(using: .utf8) ?? Data()
        let crc   = crc32(fileData)
        let size  = UInt32(fileData.count)
        let fnLen = UInt16(filenameData.count)

        // ── Local file header ──────────────────────────────────────
        zip.appendUInt32LE(0x04034B50)  // Signature
        zip.appendUInt16LE(0x0014)      // Version needed (2.0)
        zip.appendUInt16LE(0x0000)      // General flags
        zip.appendUInt16LE(0x0000)      // Compression method: STORED
        zip.appendUInt16LE(0x0000)      // Last mod time
        zip.appendUInt16LE(0x0000)      // Last mod date
        zip.appendUInt32LE(crc)         // CRC-32
        zip.appendUInt32LE(size)        // Compressed size
        zip.appendUInt32LE(size)        // Uncompressed size
        zip.appendUInt16LE(fnLen)       // Filename length
        zip.appendUInt16LE(0x0000)      // Extra field length
        zip.append(filenameData)
        zip.append(fileData)

        // ── Central directory ──────────────────────────────────────
        let localHeaderOffset = UInt32(0)
        let centralStart      = UInt32(zip.count)

        zip.appendUInt32LE(0x02014B50)  // Signature
        zip.appendUInt16LE(0x003F)      // Version made by
        zip.appendUInt16LE(0x0014)      // Version needed
        zip.appendUInt16LE(0x0000)      // General flags
        zip.appendUInt16LE(0x0000)      // Compression method: STORED
        zip.appendUInt16LE(0x0000)      // Last mod time
        zip.appendUInt16LE(0x0000)      // Last mod date
        zip.appendUInt32LE(crc)
        zip.appendUInt32LE(size)
        zip.appendUInt32LE(size)
        zip.appendUInt16LE(fnLen)       // Filename length
        zip.appendUInt16LE(0x0000)      // Extra field length
        zip.appendUInt16LE(0x0000)      // File comment length
        zip.appendUInt16LE(0x0000)      // Disk number start
        zip.appendUInt16LE(0x0000)      // Internal attributes
        zip.appendUInt32LE(0x00000000)  // External attributes
        zip.appendUInt32LE(localHeaderOffset)
        zip.append(filenameData)

        let centralSize = UInt32(zip.count) - centralStart

        // ── End of central directory ───────────────────────────────
        zip.appendUInt32LE(0x06054B50)  // Signature
        zip.appendUInt16LE(0x0000)      // Disk number
        zip.appendUInt16LE(0x0000)      // Start disk
        zip.appendUInt16LE(0x0001)      // Entries on disk
        zip.appendUInt16LE(0x0001)      // Total entries
        zip.appendUInt32LE(centralSize)
        zip.appendUInt32LE(centralStart)
        zip.appendUInt16LE(0x0000)      // Comment length

        return zip
    }

    // MARK: - CRC-32 (IEEE 802.3 polynomial)

    private static let crcTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
            return c
        }
    }()

    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = (crc >> 8) ^ FileCompressionWorker.crcTable[Int((crc ^ UInt32(byte)) & 0xFF)]
        }
        return ~crc
    }
}

// MARK: - Data helpers

private extension Data {
    mutating func appendUInt16LE(_ v: UInt16) {
        var val = v.littleEndian; append(Data(bytes: &val, count: 2))
    }
    mutating func appendUInt32LE(_ v: UInt32) {
        var val = v.littleEndian; append(Data(bytes: &val, count: 4))
    }
}
