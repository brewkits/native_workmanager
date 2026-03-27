import XCTest
import CryptoKit
@testable import native_workmanager

/// Unit tests for RequestSigner.
///
/// Verifies HMAC-SHA256 signing, config parsing, header injection,
/// timestamp inclusion, and body-signing semantics.
@available(iOS 13.0, *)
class RequestSignerTests: XCTestCase {

    // MARK: - Config Parsing

    func testConfig_fromDict_minimal() {
        let dict: [String: Any] = ["secretKey": "my-secret"]
        let config = RequestSigner.Config.from(dict)
        XCTAssertNotNil(config, "Config with secretKey should parse successfully")
        XCTAssertEqual(config?.secretKey, "my-secret")
        XCTAssertEqual(config?.headerName, "X-Signature", "Default headerName should be X-Signature")
        XCTAssertTrue(config?.includeTimestamp ?? false, "includeTimestamp should default to true")
        XCTAssertTrue(config?.signBody ?? false, "signBody should default to true")
    }

    func testConfig_fromDict_full() {
        let dict: [String: Any] = [
            "secretKey": "test-key",
            "headerName": "X-Custom-Sig",
            "signaturePrefix": "v1=",
            "includeTimestamp": false,
            "signBody": false
        ]
        let config = RequestSigner.Config.from(dict)
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.headerName, "X-Custom-Sig")
        XCTAssertEqual(config?.signaturePrefix, "v1=")
        XCTAssertFalse(config?.includeTimestamp ?? true)
        XCTAssertFalse(config?.signBody ?? true)
    }

    func testConfig_fromDict_emptySecretKey_returnsNil() {
        let dict: [String: Any] = ["secretKey": ""]
        XCTAssertNil(RequestSigner.Config.from(dict),
                     "Empty secretKey must return nil — no silent unsigned requests")
    }

    func testConfig_fromDict_missingSecretKey_returnsNil() {
        let dict: [String: Any] = ["headerName": "X-Signature"]
        XCTAssertNil(RequestSigner.Config.from(dict),
                     "Missing secretKey must return nil")
    }

    func testConfig_fromNil_returnsNil() {
        XCTAssertNil(RequestSigner.Config.from(nil),
                     "nil dict must return nil")
    }

    // MARK: - Signature Header Injection

    func testSign_addsSignatureHeader() throws {
        var request = URLRequest(url: URL(string: "https://api.example.com/endpoint")!)
        request.httpMethod = "GET"

        let config = RequestSigner.Config(secretKey: "test-secret-key")
        RequestSigner.sign(request: &request, config: config)

        XCTAssertNotNil(request.value(forHTTPHeaderField: "X-Signature"),
                        "X-Signature header must be present after signing")
    }

    func testSign_customHeaderName() throws {
        var request = URLRequest(url: URL(string: "https://api.example.com/data")!)
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)

        let config = RequestSigner.Config(
            secretKey: "my-key",
            headerName: "X-HMAC-Signature"
        )
        RequestSigner.sign(request: &request, config: config)

        XCTAssertNotNil(request.value(forHTTPHeaderField: "X-HMAC-Signature"),
                        "Custom header name must be used")
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Signature"),
                     "Default header name must NOT be set when custom name is specified")
    }

    func testSign_withPrefix() throws {
        var request = URLRequest(url: URL(string: "https://api.example.com/")!)
        request.httpMethod = "GET"

        let config = RequestSigner.Config(
            secretKey: "key",
            signaturePrefix: "sha256="
        )
        RequestSigner.sign(request: &request, config: config)

        let sig = request.value(forHTTPHeaderField: "X-Signature") ?? ""
        XCTAssertTrue(sig.hasPrefix("sha256="),
                      "Signature value must start with the configured prefix")
    }

    func testSign_includesTimestampHeader() throws {
        var request = URLRequest(url: URL(string: "https://api.example.com/")!)
        request.httpMethod = "GET"

        let config = RequestSigner.Config(secretKey: "key", includeTimestamp: true)
        RequestSigner.sign(request: &request, config: config)

        let ts = request.value(forHTTPHeaderField: "X-Timestamp")
        XCTAssertNotNil(ts, "X-Timestamp header must be present when includeTimestamp=true")

        let tsValue = Int64(ts ?? "0") ?? 0
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        XCTAssertTrue(abs(tsValue - now) < 5_000,
                      "Timestamp must be within 5 seconds of now")
    }

    func testSign_withoutTimestamp_noTimestampHeader() throws {
        var request = URLRequest(url: URL(string: "https://api.example.com/")!)
        request.httpMethod = "GET"

        let config = RequestSigner.Config(secretKey: "key", includeTimestamp: false)
        RequestSigner.sign(request: &request, config: config)

        XCTAssertNil(request.value(forHTTPHeaderField: "X-Timestamp"),
                     "X-Timestamp must NOT be set when includeTimestamp=false")
    }

    // MARK: - Signature Determinism

    func testSign_sameSeedProducesSameSignature() throws {
        let url = URL(string: "https://api.example.com/data")!
        let body = Data("payload".utf8)

        var req1 = URLRequest(url: url)
        req1.httpMethod = "POST"
        req1.httpBody = body

        var req2 = URLRequest(url: url)
        req2.httpMethod = "POST"
        req2.httpBody = body

        // Use a fixed timestamp by not including it — ensures determinism
        let config = RequestSigner.Config(
            secretKey: "deterministic-key",
            includeTimestamp: false
        )

        RequestSigner.sign(request: &req1, config: config)
        RequestSigner.sign(request: &req2, config: config)

        XCTAssertEqual(
            req1.value(forHTTPHeaderField: "X-Signature"),
            req2.value(forHTTPHeaderField: "X-Signature"),
            "Identical inputs (no timestamp) must produce identical HMAC signatures"
        )
    }

    func testSign_differentPayloads_differentSignatures() throws {
        let url = URL(string: "https://api.example.com/data")!

        var req1 = URLRequest(url: url)
        req1.httpMethod = "POST"
        req1.httpBody = Data("payload-A".utf8)

        var req2 = URLRequest(url: url)
        req2.httpMethod = "POST"
        req2.httpBody = Data("payload-B".utf8)

        let config = RequestSigner.Config(secretKey: "key", includeTimestamp: false)
        RequestSigner.sign(request: &req1, config: config)
        RequestSigner.sign(request: &req2, config: config)

        XCTAssertNotEqual(
            req1.value(forHTTPHeaderField: "X-Signature"),
            req2.value(forHTTPHeaderField: "X-Signature"),
            "Different bodies must produce different HMAC signatures"
        )
    }

    func testSign_differentSecrets_differentSignatures() throws {
        let url = URL(string: "https://api.example.com/")!

        var req1 = URLRequest(url: url)
        req1.httpMethod = "GET"

        var req2 = URLRequest(url: url)
        req2.httpMethod = "GET"

        let config1 = RequestSigner.Config(secretKey: "secret-A", includeTimestamp: false)
        let config2 = RequestSigner.Config(secretKey: "secret-B", includeTimestamp: false)

        RequestSigner.sign(request: &req1, config: config1)
        RequestSigner.sign(request: &req2, config: config2)

        XCTAssertNotEqual(
            req1.value(forHTTPHeaderField: "X-Signature"),
            req2.value(forHTTPHeaderField: "X-Signature"),
            "Different secrets must produce different signatures"
        )
    }

    func testSign_signatureIsValidHex() throws {
        var request = URLRequest(url: URL(string: "https://api.example.com/")!)
        request.httpMethod = "GET"

        let config = RequestSigner.Config(secretKey: "hex-test-key", includeTimestamp: false)
        RequestSigner.sign(request: &request, config: config)

        let sig = request.value(forHTTPHeaderField: "X-Signature") ?? ""
        let hexChars = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        XCTAssertTrue(sig.unicodeScalars.allSatisfy { hexChars.contains($0) },
                      "HMAC-SHA256 hex digest must contain only hex characters")
        XCTAssertEqual(sig.count, 64,
                       "HMAC-SHA256 hex digest must be exactly 64 characters")
    }

    // MARK: - Without Body Signing

    func testSign_withoutBodySigning_bodyChangesDoNotAffectSignature() throws {
        let url = URL(string: "https://api.example.com/")!

        var req1 = URLRequest(url: url)
        req1.httpMethod = "POST"
        req1.httpBody = Data("payload-A".utf8)

        var req2 = URLRequest(url: url)
        req2.httpMethod = "POST"
        req2.httpBody = Data("payload-B".utf8)

        let config = RequestSigner.Config(
            secretKey: "key",
            includeTimestamp: false,
            signBody: false
        )
        RequestSigner.sign(request: &req1, config: config)
        RequestSigner.sign(request: &req2, config: config)

        XCTAssertEqual(
            req1.value(forHTTPHeaderField: "X-Signature"),
            req2.value(forHTTPHeaderField: "X-Signature"),
            "When signBody=false, different bodies must produce the same signature"
        )
    }
}
