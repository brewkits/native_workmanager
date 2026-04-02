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
///
/// When a worker receives a 401 Unauthorized response, it can use this
/// configuration to attempt to refresh the access token before retrying
/// the original request.
struct TokenRefreshConfig: Codable {
    /// The URL to call for token refresh.
    let url: String

    /// Optional headers for the refresh request (e.g., Refresh-Token).
    let headers: [String: String]?

    /// HTTP method for the refresh request (default: POST).
    let method: String?

    /// The key in the response JSON to extract the new token from (default: "access_token").
    let responseKey: String?

    /// The header name to set the new token in for the retry request (default: "Authorization").
    let tokenHeaderName: String?

    /// The prefix for the token value (e.g., "Bearer ").
    let tokenPrefix: String?

    /// Static helper to create a config from a Dictionary (parsed from Worker JSON).
    static func from(_ dict: [String: Any]?) -> TokenRefreshConfig? {
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

    /// Effective HTTP method (defaults to POST).
    var effectiveMethod: String { method ?? "POST" }

    /// Effective response key (defaults to "access_token").
    var effectiveResponseKey: String { responseKey ?? "access_token" }

    /// Effective token header name (defaults to "Authorization").
    var effectiveTokenHeaderName: String { tokenHeaderName ?? "Authorization" }

    /// Effective token prefix (defaults to empty string).
    var effectiveTokenPrefix: String { tokenPrefix ?? "" }
}

// MARK: - Auth Token Manager

/// Thread-safe manager for refreshing authentication tokens in background workers.
///
/// Uses Swift Concurrency's `actor` model to ensure that multiple parallel
/// download chunks or concurrent workers do not attempt to refresh the token
/// simultaneously (prevents the "Thundering Herd" problem).
@available(iOS 13.0, *)
actor AuthTokenManager {

    static let shared = AuthTokenManager()

    private init() {}

    private var ongoingRefreshTask: Task<String?, Never>?
    private var cachedNewToken: String?

    func refreshToken(config: TokenRefreshConfig, currentSession: URLSession) async -> String? {
        if let token = cachedNewToken {
            return token
        }

        if let task = ongoingRefreshTask {
            return await task.value
        }

        let refreshTask = Task<String?, Never> {
            do {
                print("AuthTokenManager: Starting token refresh request to \(config.url)")

                var request = URLRequest(url: URL(string: config.url)!)
                request.httpMethod = config.effectiveMethod

                if let headers = config.headers {
                    for (key, value) in headers {
                        request.setValue(value, forHTTPHeaderField: key)
                    }
                }

                let (data, response) = try await currentSession.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode) else {
                    return nil
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
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

    func invalidateCachedToken() {
        cachedNewToken = nil
    }
}
