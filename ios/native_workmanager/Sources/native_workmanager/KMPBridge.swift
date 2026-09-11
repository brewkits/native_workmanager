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
            singleTaskExecutor: nil,
            chainExecutor: nil,
            fileStorage: fileStorage,
            scope: nil,
            forceWaitMigration: false
        )

        isInitialized = true
        NativeLogger.d("KMPBridge: Initialized with NativeTaskScheduler from kmpworkmanager v3.4.1")
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
            singleTaskExecutor: nil,
            chainExecutor: nil,
            fileStorage: fileStorage,
            scope: nil,
            forceWaitMigration: false
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
                guard let url = SecurityValidator.validateURL(config.url) else { return nil }
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
        // URLCache.shared is process-wide and independent of which URLSession serves a
        // request — a response cached from an earlier, correctly-pinned request to this
        // same URL would otherwise be replayed here without a new TLS handshake, so a
        // later request configured with a DIFFERENT (or wrong) pin could silently receive
        // that stale cached response instead of ever being checked against its own pin.
        // Confirmed empirically: device_integration_test.dart's "wrong pin rejects the
        // connection" case passed in isolation but failed when run right after the
        // "correct pin" case against the same URL, until this was added. A pinned
        // session's whole purpose is to verify the live connection every time.
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        let delegate = PinningDelegate(config: config)
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    } else {
        return URLSession(configuration: configuration)
    }
}

/// ASN.1 SubjectPublicKeyInfo headers, by key type.
///
/// `SecKeyCopyExternalRepresentation`/`SecTrustCopyKey` hand back the **raw key**, while a
/// `sha256/…` pin — the form OkHttp, TrustKit, openssl and every pin-generating tool emit,
/// and the same form this plugin's Android `HttpSecurityHelper.applyCertificatePinning`
/// expects — is the hash of the **full SubjectPublicKeyInfo**, which prefixes the key with
/// an AlgorithmIdentifier. Hashing the raw key (the previous implementation here) produces a
/// digest that matches no pin any standard tool would generate: verified empirically against
/// a real TLS handshake to www.example.com — the raw-key hash and the correct SPKI hash are
/// different values, and only the SPKI one matches the known-good openssl-verified reference.
///
/// These exact bytes are transcribed from kmpworkmanager's own `TlsPinning.ios.kt`
/// (`SPKI_HEADERS`), which verified them against openssl on a live server — not
/// re-derived independently, to avoid introducing a transcription error into
/// security-critical fixed bytes.
///
/// Covers RSA-2048/4096 and EC P-256/P-384, which cover TLS server certificates in practice.
/// Anything else is rejected outright (`nil`), never waved through: a pinning check that
/// silently accepts a key type it cannot verify is worse than no pinning, because the caller
/// believes they are protected.
private enum SpkiHeader {
    static let rsa2048: [UInt8] = [
        0x30, 0x53, 0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86,
        0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x42, 0x00,
    ]
    static let rsa4096: [UInt8] = [
        0x30, 0x82, 0x02, 0x22, 0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48,
        0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82,
        0x02, 0x0F, 0x00,
    ]
    /// EC P-256 raw key (uncompressed point, prefixed 0x04) is exactly 65 bytes.
    static let ecP256: [UInt8] = [
        0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D,
        0x02, 0x01, 0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01,
        0x07, 0x03, 0x42, 0x00,
    ]
    /// EC P-384 raw key is exactly 97 bytes.
    static let ecP384: [UInt8] = [
        0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D,
        0x02, 0x01, 0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00,
    ]
}

/// RSA raw-key byte counts vary slightly (leading zero-byte for sign, etc.), so these are
/// ranges rather than exact matches — the same ranges kmpworkmanager's `rsaHeaderFor` uses.
/// EC keys are fixed-length and matched exactly in `spkiHeader(forRawKeyByteCount:)`.
private func spkiHeader(forRawKeyByteCount count: Int) -> [UInt8]? {
    switch count {
    case 65: return SpkiHeader.ecP256
    case 97: return SpkiHeader.ecP384
    case 260...280: return SpkiHeader.rsa2048   // RSA-2048 (270 bytes as typically returned)
    case 515...535: return SpkiHeader.rsa4096   // RSA-4096 (526 bytes as typically returned)
    default: return nil
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
            // Proper wildcard matching: "*.example.com" must not match "notexample.com".
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

        // Deliberately NOT doing our own SecTrustEvaluateWithError + useCredential here.
        // That was this delegate's previous shape, and it is the wrong one twice over: it
        // replaces the system's chain validation with hand-written code — a bug there turns
        // a pin into a way to accept an expired or untrusted certificate as long as the key
        // matches — and a peer implementation of this exact feature (kmpworkmanager's own
        // TlsPinning.ios.kt) independently hit real handshake failures from that pattern on
        // its own test devices. Instead: only check whether the leaf's public key matches a
        // configured pin, and tell the system to run its OWN validation (performDefaultHandling)
        // either way. The pin becomes a strictly additional gate in front of normal validation,
        // and a bug in the key-matching code below cannot weaken it.
        switch matchesPin(serverTrust: serverTrust, pins: pins) {
        case .match, .notPinned:
            completionHandler(.performDefaultHandling, nil)
        case .mismatch, .unsupportedKey:
            // Loud on purpose. A pinning rejection looks like a network outage from the app's
            // side; without this the only symptom is requests to this host that never succeed.
            NativeLogger.e("[NativeWorkManager] TLS pinning rejected the connection to '\(host)' — " +
                "server key did not match any configured pin, or its key type is unsupported.")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private enum PinMatch { case notPinned, match, mismatch, unsupportedKey }

    private func matchesPin(serverTrust: SecTrust, pins: [String]) -> PinMatch {
        // Use non-deprecated SecTrustCopyKey (iOS 14+), fall back to
        // SecTrustCopyPublicKey (deprecated in iOS 15) — never force-unwrap.
        let serverPublicKey: SecKey?
        if #available(iOS 14.0, *) {
            serverPublicKey = SecTrustCopyKey(serverTrust)
        } else {
            serverPublicKey = SecTrustCopyPublicKey(serverTrust)
        }

        guard let publicKey = serverPublicKey,
              let rawKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return .unsupportedKey
        }

        guard let header = spkiHeader(forRawKeyByteCount: rawKeyData.count) else { return .unsupportedKey }

        var spki = Data(header)
        spki.append(rawKeyData)
        let computed = "sha256/" + sha256(data: spki).base64EncodedString()

        // Timing-safe comparison to avoid short-circuit string equality.
        return pins.contains { timingSafeEqual($0, computed) } ? .match : .mismatch
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
