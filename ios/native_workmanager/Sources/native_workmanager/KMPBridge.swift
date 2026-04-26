import Foundation
import KMPWorkManager
import CommonCrypto

/// Swift bridge to KMP WorkManager framework
/// Phase 2: Direct NativeTaskScheduler initialization (simplified approach)
public class KMPBridge {

    public static let shared = KMPBridge()

    private var isInitialized = false
    private var scheduler: BackgroundTaskScheduler?

    private init() {}

    /// Initialize KMP WorkManager with direct NativeTaskScheduler.
    public func initialize(diskSpaceBufferMB: Int = 20) {
        guard !isInitialized else {
            NativeLogger.d("KMPBridge: Already initialized")
            return
        }

        let bufferBytes = Int64(diskSpaceBufferMB) * 1024 * 1024
        let storageConfig = IosFileStorageConfig(
            diskSpaceBufferBytes: bufferBytes,
            deletedMarkerMaxAgeMs: 7 * 24 * 60 * 60 * 1000,
            isTestMode: nil,
            fileCoordinationTimeoutMs: 30000
        )
        let fileStorage = IosFileStorage(config: storageConfig, baseDirectory: nil)
        
        scheduler = NativeTaskScheduler(
            additionalPermittedTaskIds: [],
            diskSpaceBufferBytes: bufferBytes,
            fileStorage: fileStorage
        )

        isInitialized = true
        NativeLogger.d("KMPBridge: Initialized with NativeTaskScheduler from kmpworkmanager v2.4.1")
    }

    public func reinitialize(diskSpaceBufferMB: Int) {
        let bufferBytes = Int64(diskSpaceBufferMB) * 1024 * 1024
        let storageConfig = IosFileStorageConfig(
            diskSpaceBufferBytes: bufferBytes,
            deletedMarkerMaxAgeMs: 7 * 24 * 60 * 60 * 1000,
            isTestMode: nil,
            fileCoordinationTimeoutMs: 30000
        )
        let fileStorage = IosFileStorage(config: storageConfig, baseDirectory: nil)
        
        scheduler = NativeTaskScheduler(
            additionalPermittedTaskIds: [],
            diskSpaceBufferBytes: bufferBytes,
            fileStorage: fileStorage
        )
        NativeLogger.d("KMPBridge: scheduler recreated with diskSpaceBuffer=\(diskSpaceBufferMB)MB")
    }

    public func isReady() -> Bool {
        return isInitialized && scheduler != nil
    }

    /// Returns the underlying scheduler.
    ///
    /// - Important: Returns `nil` if `initialize()` has not been called first.
    ///   Callers **must** check for nil; a silent nil return means no task will
    ///   be scheduled and there will be no error — tasks are silently dropped.
    public func getScheduler() -> BackgroundTaskScheduler? {
        if !isInitialized || scheduler == nil {
            NativeLogger.e(
                "KMPBridge: getScheduler() called before initialize(). " +
                "Call KMPBridge.shared.initialize() during plugin setup."
            )
        }
        return scheduler
    }

    public func getTaskEventBus() -> TaskEventBus {
        return TaskEventBus.shared
    }
}

// MARK: - Auth Refresh Models

public struct TokenRefreshConfig: Codable {
    public let url: String
    public let headers: [String: String]?
    public let method: String?
    public let body: [String: AnyCodable]?
    public let responseKey: String?
    public let tokenHeaderName: String?
    public let tokenPrefix: String?

    public static func from(_ dict: [String: Any]?) -> TokenRefreshConfig? {
        guard let dict = dict,
              let url = dict["url"] as? String else {
            return nil
        }

        var decodedBody: [String: AnyCodable]? = nil
        if let bodyDict = dict["body"] as? [String: Any] {
            decodedBody = bodyDict.mapValues { AnyCodable($0) }
        }

        return TokenRefreshConfig(
            url: url,
            headers: dict["headers"] as? [String: String],
            method: dict["method"] as? String,
            body: decodedBody,
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

@available(iOS 13.0, *)
public actor AuthTokenManager {
    public static let shared = AuthTokenManager()
    private init() {}
    private var ongoingRefreshTask: Task<String?, Never>?
    private var cachedNewToken: String?

    /// Refreshes the auth token, deduplicating concurrent refresh requests.
    public func refreshToken(config: TokenRefreshConfig, currentSession: URLSession) async -> String? {
        if let token = cachedNewToken { return token }
        if let task = ongoingRefreshTask { return await task.value }

        let refreshTask = Task<String?, Never> {
            do {
                guard let url = URL(string: config.url) else { return nil }
                var request = URLRequest(url: url)
                request.httpMethod = config.effectiveMethod
                config.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

                if let body = config.body {
                    let jsonData = try JSONEncoder().encode(body)
                    request.httpBody = jsonData
                    if request.value(forHTTPHeaderField: "Content-Type") == nil {
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    }
                }

                let (data, response) = try await currentSession.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return nil
                }
                
                // Support nested keys (e.g. "auth.token")
                let keyParts = config.effectiveResponseKey.split(separator: ".")
                var current: Any? = json
                for part in keyParts {
                    if let dict = current as? [String: Any] {
                        current = dict[String(part)]
                    } else {
                        current = nil
                        break
                    }
                }
                
                return current as? String
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

// MARK: - Security Helpers

public struct CertificatePinningConfig {
    public let pins: [String: [String]]

    public static func from(_ dict: [String: Any]?) -> CertificatePinningConfig? {
        guard let dict = dict,
              let pins = dict["pins"] as? [String: [String]], !pins.isEmpty else {
            return nil
        }
        return CertificatePinningConfig(pins: pins)
    }
}

public func makeURLSession(pinningConfig: CertificatePinningConfig?, timeoutInterval: TimeInterval) -> URLSession {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = timeoutInterval
    configuration.timeoutIntervalForResource = timeoutInterval
    
    if let config = pinningConfig {
        let delegate = PinningDelegate(config: config)
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    } else {
        return URLSession(configuration: configuration)
    }
}

public class PinningDelegate: NSObject, URLSessionDelegate {
    private let config: CertificatePinningConfig

    public init(config: CertificatePinningConfig) {
        self.config = config
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host
        var allowedHashes: [String]?
        for (pattern, hashes) in config.pins {
            // SC-H-004: proper wildcard matching — "*.example.com" must not match "notexample.com"
            let matched: Bool
            if pattern.hasPrefix("*.") {
                let domain = String(pattern.dropFirst(2))  // "example.com"
                matched = host == domain || host.hasSuffix(".\(domain)")
            } else {
                matched = host == pattern
            }
            if matched {
                allowedHashes = hashes
                break
            }
        }

        guard let pins = allowedHashes else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if validate(serverTrust: serverTrust, against: pins) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            NativeLogger.e("[NativeWorkManager] SSL Pinning failed")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private func validate(serverTrust: SecTrust, against pins: [String]) -> Bool {
        if #available(iOS 12.0, *) {
            var error: CFError?
            guard SecTrustEvaluateWithError(serverTrust, &error) else { return false }
        } else {
            var result: SecTrustResultType = .invalid
            SecTrustEvaluate(serverTrust, &result)
            guard result == .proceed || result == .unspecified else { return false }
        }

        // SC-H-005: use non-deprecated SecTrustCopyKey (iOS 14+), fall back to
        // SecTrustCopyPublicKey (deprecated in iOS 15) — never force-unwrap.
        let serverPublicKey: SecKey?
        if #available(iOS 14.0, *) {
            serverPublicKey = SecTrustCopyKey(serverTrust)
        } else {
            serverPublicKey = SecTrustCopyPublicKey(serverTrust)
        }

        guard let publicKey = serverPublicKey,
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return false
        }

        let keyHash = sha256(data: publicKeyData).base64EncodedString()
        // SC-M-004: timing-safe comparison — avoid short-circuit string equality
        return pins.contains { timingSafeEqual($0, keyHash) }
    }

    /// Constant-time string comparison to prevent timing side-channel on cert pin matching.
    private func timingSafeEqual(_ a: String, _ b: String) -> Bool {
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)
        guard aBytes.count == bBytes.count else { return false }
        var diff: UInt8 = 0
        for (x, y) in zip(aBytes, bBytes) { diff |= x ^ y }
        return diff == 0
    }

    private func sha256(data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }
}
