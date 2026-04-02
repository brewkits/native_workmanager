import Foundation
import CommonCrypto

/// Configuration for certificate pinning in HTTP workers.
public struct CertificatePinningConfig {
    /// Mapping of hostname patterns to lists of allowed SHA-256 hashes (base64).
    public let pins: [String: [String]]

    /// Static helper to create a config from a Dictionary (parsed from Worker JSON).
    public static func from(_ dict: [String: Any]?) -> CertificatePinningConfig? {
        guard let dict = dict,
              let pins = dict["pins"] as? [String: [String]], !pins.isEmpty else {
            return nil
        }
        return CertificatePinningConfig(pins: pins)
    }
}

/// Helper function to create a URLSession with optional certificate pinning.
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

/// Delegate to handle SSL certificate pinning.
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

