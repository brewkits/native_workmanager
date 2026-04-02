import Foundation
import KMPWorkManager

/// Swift bridge to KMP WorkManager framework
/// Phase 2: Direct NativeTaskScheduler initialization (simplified approach)
class KMPBridge {

    static let shared = KMPBridge()

    private var isInitialized = false
    private var scheduler: BackgroundTaskScheduler?

    private init() {}

    /// Initialize KMP WorkManager with direct NativeTaskScheduler.
    ///
    /// - Parameter diskSpaceBufferMB: Minimum free disk space (in MB) that must
    ///   remain after a download. Defaults to `diskSpaceBufferBytes` constant.
    ///   Injected from Flutter's `NativeWorkManager.initialize(diskSpaceBufferMB:)`.
    func initialize(diskSpaceBufferMB: Int = 20) {
        guard !isInitialized else {
            print("✅ KMPBridge: Already initialized")
            return
        }

        let bufferBytes = Int64(diskSpaceBufferMB) * 1024 * 1024

        // Create NativeTaskScheduler directly
        // additionalPermittedTaskIds is empty - Info.plist is the primary source
        scheduler = NativeTaskScheduler(additionalPermittedTaskIds: [],
                                        diskSpaceBufferBytes: bufferBytes)

        isInitialized = true
        print("✅ KMPBridge: Initialized with NativeTaskScheduler from kmpworkmanager v2.3.3")
    }

    /// Re-initialize the KMP scheduler with a new disk-space buffer.
    ///
    /// Called from `handleInitialize` when the Flutter app provides a custom
    /// `diskSpaceBufferMB` value. This recreates the `NativeTaskScheduler` so
    /// the new buffer takes effect without requiring a full app restart.
    ///
    /// BGTaskScheduler handlers are NOT re-registered here — they remain from
    /// the initial `initialize()` call in `register(with:)`.
    func reinitialize(diskSpaceBufferMB: Int) {
        let bufferBytes = Int64(diskSpaceBufferMB) * 1024 * 1024
        scheduler = NativeTaskScheduler(additionalPermittedTaskIds: [],
                                        diskSpaceBufferBytes: bufferBytes)
        NativeLogger.d("KMPBridge: scheduler recreated with diskSpaceBuffer=\(diskSpaceBufferMB)MB")
    }

    /// Check if KMP is initialized and scheduler is available
    func isReady() -> Bool {
        return isInitialized && scheduler != nil
    }

    /// Get the BackgroundTaskScheduler instance
    /// Returns nil if not initialized
    func getScheduler() -> BackgroundTaskScheduler? {
        return scheduler
    }

    /// New: Get the TaskEventBus instance
    func getTaskEventBus() -> TaskEventBus {
        return TaskEventBus.shared
    }
}
