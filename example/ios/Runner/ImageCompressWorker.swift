import Foundation
import UIKit

class ImageCompressWorker: IosWorker {
    func doWork(input: String?) async throws -> WorkerResult {
        // Parse JSON input
        guard let inputString = input,
              let data = inputString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inputPath = json["inputPath"] as? String,
              let outputPath = json["outputPath"] as? String else {
            throw WorkerError.invalidInput("Missing required input parameters")
        }

        let quality = json["quality"] as? Double ?? 0.85

        // Load image
        guard let image = UIImage(contentsOfFile: inputPath) else {
            throw WorkerError.processingFailed("Failed to load image from \(inputPath)")
        }

        // Compress
        guard let compressedData = image.jpegData(compressionQuality: quality) else {
            throw WorkerError.processingFailed("Failed to compress image")
        }

        // Save
        let outputURL = URL(fileURLWithPath: outputPath)
        do {
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try compressedData.write(to: outputURL)
        } catch {
            throw WorkerError.processingFailed("Failed to save compressed image: \(error.localizedDescription)")
        }

        return WorkerResult.success(data: "Compressed image saved to \(outputPath)")
    }
}
