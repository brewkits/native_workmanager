import Foundation
import KMPWorkManager

/// Swift bridge to KMP WorkManager framework
/// Phase 2: Direct NativeTaskScheduler initialization (simplified approach)
class KMPBridge {

    static let shared = KMPBridge()

    private var isInitialized = false
    private var scheduler: BackgroundTaskScheduler?

    private init() {}

    /// Initialize KMP WorkManager with direct NativeTaskScheduler
    /// This approach avoids Koin complexity and directly instantiates the scheduler
    func initialize() {
        guard !isInitialized else {
            print("✅ KMPBridge: Already initialized")
            return
        }

        // Create NativeTaskScheduler directly
        // additionalPermittedTaskIds is empty - Info.plist is the primary source
        scheduler = NativeTaskScheduler(additionalPermittedTaskIds: [])

        isInitialized = true
        print("✅ KMPBridge: Initialized with NativeTaskScheduler from kmpworkmanager v2.3.0")
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

/// Phase 2 Implementation Notes:
/// - Uses kmpworkmanager v2.3.0 (WorkerResult API, Chain IDs, UX improvements)
/// - Direct NativeTaskScheduler instantiation (no Koin from Swift side)
/// - iOS task IDs are read from Info.plist automatically
/// - Simpler and more reliable than Koin DI from Swift
