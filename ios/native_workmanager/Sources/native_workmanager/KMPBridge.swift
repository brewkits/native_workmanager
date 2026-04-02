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

// MARK: - Auth Refresh Models

/// Configuration for automatic token refresh in background workers.
public struct TokenRefreshConfig: Codable {
    public let url: String
    public let headers: [String: String]?
    public let method: String?
    public let responseKey: String?
    public let tokenHeaderName: String?
    public let tokenPrefix: String?

    public static func from(_ dict: [String: Any]?) -> TokenRefreshConfig? {
        guard let dict = dict,
              let url = dict["url"] as? String else {
            return nil
        }

        return TokenRefreshConfig(
            url: url,
            headers: dict["headers"] as? [String: String],
            method: dict["method"] as? String,
            responseKey: dict["responseKey"] as? String,
            tokenHeaderName: dict["tokenHeaderName"] as? String,
            tokenPrefix: dict["tokenPrefix"] as? String
        )
    }

    public var effectiveMethod: String { method ?? "POST" }
    public var effectiveResponseKey: String { responseKey ?? "access_token" }
    public var effectiveTokenHeaderName: String { tokenHeaderName ?? "Authorization" }
    public var effectiveTokenPrefix: String { tokenPrefix ?? "" }
}

// MARK: - Auth Token Manager

@available(iOS 13.0, *)
public actor AuthTokenManager {
    public static let shared = AuthTokenManager()
    private init() {}
    private var ongoingRefreshTask: Task<String?, Never>?
    private var cachedNewToken: String?

    public func refreshToken(config: TokenRefreshConfig, currentSession: URLSession) async -> String? {
        if let token = cachedNewToken { return token }
        if let task = ongoingRefreshTask { return await task.value }

        let refreshTask = Task<String?, Never> {
            do {
                var request = URLRequest(url: URL(string: config.url)!)
                request.httpMethod = config.effectiveMethod
                config.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

                let (data, response) = try await currentSession.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let newToken = json[config.effectiveResponseKey] as? String else {
                    return nil
                }
                return newToken
            } catch {
                return nil
            }
        }

        ongoingRefreshTask = refreshTask
        let result = await refreshTask.value
        ongoingRefreshTask = nil
        if let token = result { cachedNewToken = token }
        return result
    }

    public func invalidateCachedToken() {
        cachedNewToken = nil
    }
}
