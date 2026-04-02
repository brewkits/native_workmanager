import Foundation
import Photos

/// Worker that moves/copies a file from app-private storage to a shared location.
///
/// - `photos` / `video`: Saves to PHPhotoLibrary (requires `NSPhotoLibraryAddUsageDescription`
///   in the host app's Info.plist and runtime user permission).
/// - `downloads` / `music`: Copies to the app's `Documents` directory, which is
///   accessible via the iOS Files app.
///
/// **Configuration JSON:**
/// ```json
/// {
///   "sourcePath": "/private/var/.../Library/Caches/photo.jpg",
///   "storageType": "photos",    // downloads | photos | music | video
///   "fileName": "photo.jpg",    // Optional: override filename
///   "mimeType": "image/jpeg",   // Optional (currently unused on iOS, kept for parity)
///   "subDir": "MyApp"           // Optional: subdirectory (Documents mode only)
/// }
/// ```
class MoveToSharedStorageWorker: IosWorker {

    func doWork(input: String?) async throws -> WorkerResult {
        guard let input = input, !input.isEmpty,
              let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(message: "Invalid or missing input JSON")
        }

        guard let sourcePath = json["sourcePath"] as? String, !sourcePath.isEmpty else {
            return .failure(message: "sourcePath is required")
        }

        guard SecurityValidator.validateFilePath(sourcePath) else {
            return .failure(message: "Invalid or unsafe source path")
        }

        let sourceURL = URL(fileURLWithPath: sourcePath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            return .failure(message: "Source file not found: \(sourcePath)")
        }

        let storageType = (json["storageType"] as? String ?? "downloads").lowercased()
        // SEC-002: use safe optional cast instead of force cast (as!) which panics on nil
        let fileNameOverride = json["fileName"] as? String
        let fileName = (fileNameOverride?.isEmpty == false) ? fileNameOverride! : sourceURL.lastPathComponent
        let subDir = json["subDir"] as? String

        switch storageType {
        case "photos", "video":
            return await saveToPhotoLibrary(sourceURL: sourceURL, fileName: fileName)
        default:
            return saveToDocuments(sourceURL: sourceURL, fileName: fileName, subDir: subDir)
        }
    }

    // MARK: - PHPhotoLibrary (photos + video)

    private func saveToPhotoLibrary(sourceURL: URL, fileName: String) async -> WorkerResult {
        // Check / request authorization
        let status = await requestPhotoLibraryAccess()
        guard status == .authorized || status == .limited else {
            return .failure(message: "Photo Library access denied. Add NSPhotoLibraryAddUsageDescription to Info.plist and ensure user grants permission.")
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: sourceURL, options: nil)
            }) { success, error in
                if success {
                    print("MoveToSharedStorageWorker: Saved to Photo Library: \(fileName)")
                    continuation.resume(returning: .success(
                        message: "Saved to Photo Library",
                        data: ["fileName": fileName, "storageType": "photos"]
                    ))
                } else {
                    let msg = error?.localizedDescription ?? "Unknown error"
                    print("MoveToSharedStorageWorker: Photo Library error: \(msg)")
                    continuation.resume(returning: .failure(message: "Failed to save to Photo Library: \(msg)"))
                }
            }
        }
    }

    private func requestPhotoLibraryAccess() async -> PHAuthorizationStatus {
        if #available(iOS 14, *) {
            let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            if current == .authorized || current == .limited { return current }
            return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        } else {
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        }
    }

    // MARK: - Documents directory (downloads + music)

    private func saveToDocuments(sourceURL: URL, fileName: String, subDir: String?) -> WorkerResult {
        do {
            let docsURL = try FileManager.default.url(
                for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            )
            let destDir: URL
            if let sub = subDir, !sub.isEmpty {
                destDir = docsURL.appendingPathComponent(sub, isDirectory: true)
                try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            } else {
                destDir = docsURL
            }

            let destURL = destDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)

            print("MoveToSharedStorageWorker: Copied to Documents: \(destURL.path)")
            return .success(
                message: "Saved to Documents",
                data: ["filePath": destURL.path, "fileName": fileName, "storageType": "documents"]
            )
        } catch {
            print("MoveToSharedStorageWorker: Documents copy failed: \(error.localizedDescription)")
            return .failure(message: "Failed to copy to Documents: \(error.localizedDescription)")
        }
    }
}
