import Foundation

/// Protocol for iOS background workers.
///
/// Implements the same contract as AndroidWorker in the KMP library,
/// but adapted for Swift's async/await pattern.
///
/// v2.3.0+: Changed return type from Bool to WorkerResult to support returning data
///
/// Workers should be lightweight and stateless. All configuration
/// should be passed via the JSON input string.
protocol IosWorker {
    /// Execute the background work.
    ///
    /// v2.3.0+: Return type changed from Bool to WorkerResult
    ///
    /// - Parameter input: JSON configuration string for the worker
    /// - Returns: WorkerResult indicating success/failure with optional data and message
    /// - Throws: Can throw errors which will be caught and logged
    func doWork(input: String?) async throws -> WorkerResult
}

/// Factory for creating iOS workers by class name.
///
/// Supports custom worker registration via `registerWorker()`.
/// User workers are checked first, then falls back to built-in workers.
class IosWorkerFactory {

    /// User-registered worker factories: className -> factory closure
    private static var userWorkers: [String: () -> IosWorker] = [:]

    /// Register a custom worker factory.
    ///
    /// Call this in `AppDelegate.swift` before calling `NativeWorkManager.initialize()`.
    ///
    /// Example:
    /// ```swift
    /// IosWorkerFactory.registerWorker(className: "ImageCompressWorker") {
    ///     return ImageCompressWorker()
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - className: The worker class name (must match Dart side)
    ///   - factory: Closure that creates worker instance
    public static func registerWorker(className: String, factory: @escaping () -> IosWorker) {
        userWorkers[className] = factory
        print("IosWorkerFactory: Registered custom worker '\(className)'")
    }

    /// Unregister a custom worker.
    ///
    /// - Parameter className: The worker class name to unregister
    public static func unregisterWorker(className: String) {
        userWorkers.removeValue(forKey: className)
        print("IosWorkerFactory: Unregistered custom worker '\(className)'")
    }

    /// Create a worker instance by class name.
    ///
    /// Checks user-registered workers first, then falls back to built-in workers.
    ///
    /// - Parameter className: The worker class name (e.g., "HttpRequestWorker")
    /// - Returns: Worker instance, or nil if class not found
    static func createWorker(className: String) -> IosWorker? {
        // Try user-registered worker first
        if let factory = userWorkers[className] {
            return factory()
        }

        // Fallback to built-in workers
        switch className {
        case "HttpRequestWorker":
            return HttpRequestWorker()
        case "HttpUploadWorker":
            return HttpUploadWorker()
        case "HttpDownloadWorker":
            return HttpDownloadWorker()
        case "HttpSyncWorker":
            return HttpSyncWorker()
        case "DartCallbackWorker":
            return DartCallbackWorker.shared
        case "FileCompressionWorker":
            return FileCompressionWorker()
        case "FileDecompressionWorker":
            return FileDecompressionWorker()
        case "ImageProcessWorker":  // ⚠️ DO NOT REMOVE - Required for v1.0.0
            return ImageProcessWorker()
        case "CryptoWorker":
            return CryptoWorker()
        case "FileSystemWorker":  // ⚠️ DO NOT REMOVE - Required for v1.0.0
            return FileSystemWorker()
        default:
            print("IosWorkerFactory: Unknown worker class: \(className)")
            return nil
        }
    }
}