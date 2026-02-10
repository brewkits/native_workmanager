import Foundation
import UIKit

class ImageCompressWorker: IosWorker {
    func doWork(input: String?) async throws -> Bool {
        // Parse JSON input
        guard let inputString = input,
              let data = inputString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inputPath = json["inputPath"] as? String,
              let outputPath = json["outputPath"] as? String else {
            return false
        }

        let quality = json["quality"] as? Double ?? 0.85

        // Load image
        guard let image = UIImage(contentsOfFile: inputPath) else {
            return false
        }

        // Compress
        guard let compressedData = image.jpegData(compressionQuality: quality) else {
            return false
        }

        // Save
        let outputURL = URL(fileURLWithPath: outputPath)
        try? FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try compressedData.write(to: outputURL)

        return true
    }
}
