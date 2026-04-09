import Foundation
import PDFKit
import UIKit

/// Native PDF worker for iOS.
///
/// Supports three operations via PDFKit (iOS 11+):
/// - **merge**: Merge multiple PDFs into one.
/// - **compress**: Re-render each page at lower scale to reduce file size.
/// - **imagesToPdf**: Combine image files into a PDF (one image per page).
///
/// **Configuration JSON:**
/// ```json
/// { "operation": "merge", "inputPaths": ["/path/a.pdf", "/path/b.pdf"], "outputPath": "/path/out.pdf" }
/// { "operation": "compress", "inputPath": "/path/in.pdf", "outputPath": "/path/out.pdf", "quality": 80 }
/// { "operation": "imagesToPdf", "imagePaths": ["/path/img.jpg"], "outputPath": "/path/out.pdf", "pageSize": "A4", "margin": 0 }
/// ```
///
/// **Result data:**
/// ```json
/// { "outputPath": "...", "outputSize": 102400, "pageCount": 5 }
/// ```
class PdfWorker: IosWorker {

    // MARK: - Page size constants (PDF points: 1 pt = 1/72 inch)

    private static let a4Size      = CGSize(width: 595, height: 842)
    private static let letterSize  = CGSize(width: 612, height: 792)

    // MARK: - doWork

    func doWork(input: String?, env: KMPWorkManager.WorkerEnvironment) async throws -> WorkerResult {
        guard let input = input, !input.isEmpty else {
            return .failure(message: "Empty or null input")
        }
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(message: "Invalid JSON config")
        }

        let operation = json["operation"] as? String ?? ""
        switch operation {
        case "merge":       return try mergePdfs(json: json)
        case "compress":    return try compressPdf(json: json)
        case "imagesToPdf": return try imagesToPdf(json: json)
        default:
            return .failure(message: "Unknown PDF operation: '\(operation)'")
        }
    }

    // MARK: - merge

    private func mergePdfs(json: [String: Any]) throws -> WorkerResult {
        guard let inputPaths = json["inputPaths"] as? [String], !inputPaths.isEmpty else {
            return .failure(message: "'inputPaths' array is required for merge")
        }
        guard let outputPath = json["outputPath"] as? String, !outputPath.isEmpty else {
            return .failure(message: "'outputPath' is required")
        }

        for inputPath in inputPaths {
            guard SecurityValidator.validateFilePath(inputPath) else {
                return .failure(message: "Invalid or unsafe input path")
            }
        }
        guard SecurityValidator.validateFilePath(outputPath) else {
            return .failure(message: "Invalid or unsafe output path")
        }

        let outputDoc = PDFDocument()
        var pageIndex = 0

        for inputPath in inputPaths {
            let url = URL(fileURLWithPath: inputPath).resolvingSymlinksInPath()
            guard let inputDoc = PDFDocument(url: url) else {
                return .failure(message: "Cannot open PDF: \(inputPath)")
            }
            for i in 0 ..< inputDoc.pageCount {
                guard let page = inputDoc.page(at: i) else { continue }
                outputDoc.insert(page, at: pageIndex)
                pageIndex += 1
            }
        }

        let outputURL = URL(fileURLWithPath: outputPath).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard outputDoc.write(to: outputURL) else {
            return .failure(message: "Failed to write merged PDF to \(outputPath)")
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputPath)[.size] as? Int) ?? 0
        NativeLogger.d("PdfWorker: merge complete — \(pageIndex) pages → \(outputPath)")
        return .success(
            message: "PDF merge complete",
            data: ["outputPath": outputPath, "outputSize": fileSize, "pageCount": pageIndex]
        )
    }

    // MARK: - compress

    private func compressPdf(json: [String: Any]) throws -> WorkerResult {
        guard let inputPath = json["inputPath"] as? String, !inputPath.isEmpty else {
            return .failure(message: "'inputPath' is required for compress")
        }
        guard let outputPath = json["outputPath"] as? String, !outputPath.isEmpty else {
            return .failure(message: "'outputPath' is required")
        }

        guard SecurityValidator.validateFilePath(inputPath) else {
            return .failure(message: "Invalid or unsafe input path")
        }
        guard SecurityValidator.validateFilePath(outputPath) else {
            return .failure(message: "Invalid or unsafe output path")
        }

        let quality = (json["quality"] as? Int ?? 80).clamped(to: 1...100)
        let scale = qualityToScale(quality)

        let inputURL = URL(fileURLWithPath: inputPath).resolvingSymlinksInPath()
        guard let inputDoc = PDFDocument(url: inputURL) else {
            return .failure(message: "Cannot open PDF: \(inputPath)")
        }

        let outputDoc = PDFDocument()

        for i in 0 ..< inputDoc.pageCount {
            guard let page = inputDoc.page(at: i) else { continue }

            let pageBounds = page.bounds(for: .mediaBox)
            // MEDIA-014: UIGraphicsBeginImageContextWithOptions crashes if either dimension
            // is zero or negative (corrupt PDF page). Skip such pages.
            guard pageBounds.width > 0, pageBounds.height > 0 else { continue }

            let renderSize = CGSize(
                width:  pageBounds.width  * scale,
                height: pageBounds.height * scale
            )

            UIGraphicsBeginImageContextWithOptions(renderSize, true, 1.0)
            defer { UIGraphicsEndImageContext() }

            guard let ctx = UIGraphicsGetCurrentContext() else { continue }

            // White background
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(origin: .zero, size: renderSize))

            // Scale context and render PDF page
            ctx.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: ctx)

            guard let rendered = UIGraphicsGetImageFromCurrentImageContext() else { continue }

            if let newPage = PDFPage(image: rendered) {
                outputDoc.insert(newPage, at: i)
            }
        }

        let outputURL = URL(fileURLWithPath: outputPath).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard outputDoc.write(to: outputURL) else {
            return .failure(message: "Failed to write compressed PDF to \(outputPath)")
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputPath)[.size] as? Int) ?? 0
        NativeLogger.d("PdfWorker: compress complete — quality=\(quality) scale=\(scale) pages=\(inputDoc.pageCount) → \(outputPath)")
        return .success(
            message: "PDF compress complete",
            data: ["outputPath": outputPath, "outputSize": fileSize, "pageCount": inputDoc.pageCount]
        )
    }

    // MARK: - imagesToPdf

    private func imagesToPdf(json: [String: Any]) throws -> WorkerResult {
        guard let imagePaths = json["imagePaths"] as? [String], !imagePaths.isEmpty else {
            return .failure(message: "'imagePaths' array is required for imagesToPdf")
        }
        guard let outputPath = json["outputPath"] as? String, !outputPath.isEmpty else {
            return .failure(message: "'outputPath' is required")
        }

        for imagePath in imagePaths {
            guard SecurityValidator.validateFilePath(imagePath) else {
                return .failure(message: "Invalid or unsafe input path")
            }
        }
        guard SecurityValidator.validateFilePath(outputPath) else {
            return .failure(message: "Invalid or unsafe output path")
        }

        // MEDIA-010: reject empty strings that slipped past the non-empty guard above.
        for imagePath in imagePaths {
            if imagePath.trimmingCharacters(in: .whitespaces).isEmpty {
                return .failure(message: "imagePaths contains an empty string")
            }
        }

        let pageSizeStr = json["pageSize"] as? String ?? "A4"
        // MEDIA-008: negative margin is nonsensical and would draw images outside the page.
        let margin = max(0, CGFloat(json["margin"] as? Int ?? 0))

        let outputDoc = PDFDocument()

        for (index, imagePath) in imagePaths.enumerated() {
            guard let image = UIImage(contentsOfFile: imagePath) else {
                return .failure(message: "Cannot load image: \(imagePath)")
            }

            let pageSize = resolvePageSize(pageSizeStr, imageSize: image.size)
            let drawArea = CGRect(
                x: margin,
                y: margin,
                width:  pageSize.width  - 2 * margin,
                height: pageSize.height - 2 * margin
            )

            // MEDIA-002: guard against corrupt images with zero dimensions.
            guard image.size.width > 0, image.size.height > 0 else { continue }

            // Scale image to fit draw area preserving aspect ratio
            let scaleX = drawArea.width  / image.size.width
            let scaleY = drawArea.height / image.size.height
            let scale  = min(scaleX, scaleY)
            let scaledW = image.size.width  * scale
            let scaledH = image.size.height * scale
            let imgRect = CGRect(
                x: drawArea.minX + (drawArea.width  - scaledW) / 2,
                y: drawArea.minY + (drawArea.height - scaledH) / 2,
                width:  scaledW,
                height: scaledH
            )

            UIGraphicsBeginImageContextWithOptions(pageSize, true, 1.0)
            defer { UIGraphicsEndImageContext() }

            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: pageSize))
            image.draw(in: imgRect)

            guard let pageImage = UIGraphicsGetImageFromCurrentImageContext(),
                  let pdfPage  = PDFPage(image: pageImage) else { continue }

            outputDoc.insert(pdfPage, at: index)
        }

        let outputURL = URL(fileURLWithPath: outputPath).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard outputDoc.write(to: outputURL) else {
            return .failure(message: "Failed to write PDF to \(outputPath)")
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputPath)[.size] as? Int) ?? 0
        NativeLogger.d("PdfWorker: imagesToPdf complete — \(imagePaths.count) pages → \(outputPath)")
        return .success(
            message: "imagesToPdf complete",
            data: ["outputPath": outputPath, "outputSize": fileSize, "pageCount": imagePaths.count]
        )
    }

    // MARK: - Helpers

    /// Maps quality (1–100) to a render scale factor.
    private func qualityToScale(_ quality: Int) -> CGFloat {
        switch quality {
        case 100...:    return 1.0
        case 80...:     return 0.75
        case 50...:     return 0.5
        default:        return 0.35
        }
    }

    /// Returns page dimensions in PDF points for the given preset.
    private func resolvePageSize(_ preset: String, imageSize: CGSize) -> CGSize {
        switch preset.uppercased() {
        case "A4":     return PdfWorker.a4Size
        case "LETTER": return PdfWorker.letterSize
        default:       return imageSize   // "auto" or unknown — use native image size
        }
    }
}

// MARK: - Comparable clamping helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
