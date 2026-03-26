import CryptoKit
import Foundation

/// HMAC-SHA256 request signer for HTTP workers.
///
/// Signs outgoing `URLRequest` instances in-place with an HMAC-SHA256 digest
/// computed over a canonical message:
///
/// ```
/// METHOD\n
/// URL\n
/// BODY\n          ← only when signBody=true and the request has a body
/// TIMESTAMP       ← only when includeTimestamp=true (Unix ms)
/// ```
///
/// The signature is added as `headerName` (default `X-Signature`), and the
/// timestamp (if enabled) as `X-Timestamp`.
///
/// Usage:
/// ```swift
/// RequestSigner.sign(
///     request: &request,
///     config: signingConfig
/// )
/// ```
@available(iOS 13.0, *)
enum RequestSigner {

    struct Config {
        let secretKey: String
        let headerName: String
        let signaturePrefix: String
        let includeTimestamp: Bool
        let signBody: Bool

        init(
            secretKey: String,
            headerName: String       = "X-Signature",
            signaturePrefix: String  = "",
            includeTimestamp: Bool   = true,
            signBody: Bool           = true
        ) {
            self.secretKey        = secretKey
            self.headerName       = headerName
            self.signaturePrefix  = signaturePrefix
            self.includeTimestamp = includeTimestamp
            self.signBody         = signBody
        }

        /// Parse from a JSON dict (from Dart's `RequestSigning.toMap()`).
        static func from(_ dict: [String: Any]?) -> Config? {
            guard let dict = dict,
                  let key = dict["secretKey"] as? String, !key.isEmpty else {
                return nil
            }
            return Config(
                secretKey:        key,
                headerName:       dict["headerName"]      as? String ?? "X-Signature",
                signaturePrefix:  dict["signaturePrefix"] as? String ?? "",
                includeTimestamp: dict["includeTimestamp"] as? Bool  ?? true,
                signBody:         dict["signBody"]         as? Bool  ?? true
            )
        }
    }

    // MARK: - Public API

    /// Mutates [request] by adding the HMAC-SHA256 signature header (and optional timestamp).
    static func sign(request: inout URLRequest, config: Config) {
        let timestamp = config.includeTimestamp
            ? String(Int64(Date().timeIntervalSince1970 * 1000))
            : nil

        let bodyString: String? = config.signBody
            ? (request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
            : nil

        let message = canonicalMessage(
            method:    request.httpMethod ?? "GET",
            url:       request.url?.absoluteString ?? "",
            body:      bodyString,
            timestamp: timestamp
        )

        guard let signature = hmacSHA256(message: message, key: config.secretKey) else {
            print("RequestSigner: HMAC computation failed — request not signed")
            return
        }

        request.setValue("\(config.signaturePrefix)\(signature)", forHTTPHeaderField: config.headerName)
        if let ts = timestamp {
            request.setValue(ts, forHTTPHeaderField: "X-Timestamp")
        }

        print("RequestSigner: Signed — header=\(config.headerName) ts=\(timestamp ?? "none")")
    }

    // MARK: - Private helpers

    private static func canonicalMessage(
        method: String,
        url: String,
        body: String?,
        timestamp: String?
    ) -> String {
        var msg = "\(method.uppercased())\n\(url)\n"
        if let body = body, !body.isEmpty { msg += "\(body)\n" }
        if let ts = timestamp { msg += ts }
        return msg
    }

    private static func hmacSHA256(message: String, key: String) -> String? {
        let keyData = Data(key.utf8)
        let msgData = Data(message.utf8)
        let hmac = HMAC<SHA256>.authenticationCode(
            for: msgData,
            using: SymmetricKey(data: keyData)
        )
        return Data(hmac).map { String(format: "%02x", $0) }.joined()
    }
}
