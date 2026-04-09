import Foundation
import UIKit

/// Errors thrown by ImageCompressWorker.
enum ImageCompressError: Error {
    case invalidInput(String)
    case processingFailed(String)
}

/// Demo custom native worker that compresses a JPEG image.
///
/// Shows how to register a custom worker with IosWorkerFactory from AppDelegate.swift.
///
/// Expected JSON input:
/// ```json
/// {
///   "inputPath": "/path/to/input.jpg",
///   "outputPath": "/path/to/output.jpg",
///   "quality": 0.85
/// }
/// ```
class ImageCompressWorker: IosWorker {
    func doWork(input: String?, env: WorkerEnvironment) async throws -> WorkerResult {
        // Parse JSON input
        guard let inputString = input,
              let data = inputString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inputPath = json["inputPath"] as? String,
              let outputPath = json["outputPath"] as? String else {
            throw ImageCompressError.invalidInput("Missing required input parameters: inputPath, outputPath")
        }

        let quality = (json["quality"] as? Double) ?? 0.85

        // Load image
        guard let image = UIImage(contentsOfFile: inputPath) else {
            throw ImageCompressError.processingFailed("Failed to load image from \(inputPath)")
        }

        // Compress
        guard let compressedData = image.jpegData(compressionQuality: quality) else {
            throw ImageCompressError.processingFailed("Failed to compress image")
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
            throw ImageCompressError.processingFailed("Failed to save compressed image: \(error.localizedDescription)")
        }

        let originalSize = (try? FileManager.default.attributesOfItem(atPath: inputPath)[.size] as? Int) ?? 0
        let compressedSize = compressedData.count

        return WorkerResult.success(
            message: "Compressed image saved to \(outputPath)",
            data: [
                "outputPath": outputPath,
                "originalSize": originalSize,
                "compressedSize": compressedSize,
            ]
        )
    }
}
