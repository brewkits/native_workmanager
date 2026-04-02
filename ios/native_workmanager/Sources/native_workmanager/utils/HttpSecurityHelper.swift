import Foundation
import CommonCrypto

/// Configuration for certificate pinning in HTTP workers.
struct CertificatePinningConfig {
    /// Mapping of hostname patterns to lists of allowed SHA-256 hashes (base64).
    let pins: [String: [String]]

    /// Static helper to create a config from a Dictionary (parsed from Worker JSON).
    static func from(_ dict: [String: Any]?) -> CertificatePinningConfig? {
        guard let dict = dict,
              let pins = dict["pins"] as? [String: [String]], !pins.isEmpty else {
            return nil
        }
        return CertificatePinningConfig(pins: pins)
    }
}

/// Helper function to create a URLSession with optional certificate pinning.
func makeURLSession(pinningConfig: CertificatePinningConfig?, timeoutInterval: TimeInterval) -> URLSession {
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

/// Delegate to handle SSL certificate pinning.
class PinningDelegate: NSObject, URLSessionDelegate {
    private let config: CertificatePinningConfig

    init(config: CertificatePinningConfig) {
        self.config = config
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host
        
        // Find pins for this host (simple exact match or pattern match could be improved)
        var allowedHashes: [String]?
        for (pattern, hashes) in config.pins {
            if host.hasSuffix(pattern.replacingOccurrences(of: "*.", with: "")) {
                allowedHashes = hashes
                break
            }
        }

        guard let pins = allowedHashes else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Perform pinning check
        if validate(serverTrust: serverTrust, against: pins) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            print("[NativeWorkManager] ❌ SSL Pinning failed for host: \(host)")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private func validate(serverTrust: SecTrust, against pins: [String]) -> Bool {
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            return false
        }

        guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            return false
        }

        let serverPublicKeyData = SecCertificateCopyKey(certificate).flatMap { 
            SecKeyCopyExternalRepresentation($0, nil) 
        } as Data?

        guard let publicKeyData = serverPublicKeyData else {
            return false
        }

        let keyHash = sha256(data: publicKeyData).base64EncodedString()
        return pins.contains(keyHash)
    }

    private func sha256(data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
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

