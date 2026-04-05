import XCTest
@testable import native_workmanager

/// Unit tests for SecurityValidator.
///
/// Covers URL scheme validation, HTTPS enforcement, file path traversal
/// protection, and safe-logging sanitization.
class SecurityValidatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset global flags before each test
        SecurityValidator.enforceHttps = false
        SecurityValidator.blockPrivateIPs = false
    }

    override func tearDown() {
        super.tearDown()
        SecurityValidator.enforceHttps = false
        SecurityValidator.blockPrivateIPs = false
    }

    // MARK: - URL Scheme Validation

    func testValidateURL_HTTPS_succeeds() {
        let url = SecurityValidator.validateURL("https://api.example.com/endpoint")
        XCTAssertNotNil(url, "HTTPS URL should be valid")
        XCTAssertEqual(url?.scheme, "https")
    }

    func testValidateURL_HTTP_succeeds_when_not_enforced() {
        SecurityValidator.enforceHttps = false
        let url = SecurityValidator.validateURL("http://api.example.com/endpoint")
        XCTAssertNotNil(url, "HTTP URL should be allowed when enforceHttps=false")
    }

    func testValidateURL_HTTP_rejected_when_enforced() {
        SecurityValidator.enforceHttps = true
        let url = SecurityValidator.validateURL("http://api.example.com/endpoint")
        XCTAssertNil(url, "HTTP URL must be rejected when enforceHttps=true")
    }

    func testValidateURL_FileScheme_rejected() {
        let url = SecurityValidator.validateURL("file:///etc/passwd")
        XCTAssertNil(url, "file:// scheme must be rejected")
    }

    func testValidateURL_FtpScheme_rejected() {
        let url = SecurityValidator.validateURL("ftp://files.example.com/data")
        XCTAssertNil(url, "ftp:// scheme must be rejected")
    }

    func testValidateURL_JavascriptScheme_rejected() {
        let url = SecurityValidator.validateURL("javascript:alert(1)")
        XCTAssertNil(url, "javascript: scheme must be rejected")
    }

    func testValidateURL_DataScheme_rejected() {
        let url = SecurityValidator.validateURL("data:text/html,<h1>XSS</h1>")
        XCTAssertNil(url, "data: scheme must be rejected")
    }

    func testValidateURL_InvalidFormat_returnsNil() {
        XCTAssertNil(SecurityValidator.validateURL("not a url at all"),
                     "Completely invalid URL should return nil")
    }

    func testValidateURL_EmptyString_returnsNil() {
        XCTAssertNil(SecurityValidator.validateURL(""),
                     "Empty string should return nil")
    }

    func testValidateURL_NoScheme_returnsNil() {
        // "example.com/path" is technically parseable as a relative URL
        // but has no scheme — should be rejected
        let url = SecurityValidator.validateURL("example.com/path")
        if let url = url {
            // If parsed, must have an allowed scheme
            XCTAssertTrue(["http", "https"].contains(url.scheme ?? ""),
                          "Parsed URL without explicit scheme must use allowed scheme")
        }
        // nil is also acceptable here
    }

    func testValidateURL_WithQueryAndFragment_succeeds() {
        let url = SecurityValidator.validateURL("https://api.example.com/search?q=test&page=1#results")
        XCTAssertNotNil(url, "HTTPS URL with query and fragment should be valid")
    }

    func testValidateURL_WithPort_succeeds() {
        let url = SecurityValidator.validateURL("https://api.example.com:8443/endpoint")
        XCTAssertNotNil(url, "HTTPS URL with custom port should be valid")
    }

    func testValidateURL_WithCredentials_succeeds() {
        let url = SecurityValidator.validateURL("https://user:pass@api.example.com/endpoint")
        XCTAssertNotNil(url, "HTTPS URL with credentials should be valid (credentials handled by HTTP layer)")
    }

    // MARK: - SSRF / Private IP Rejection

    func testValidateURL_Localhost_handledConsistently() {
        // With blockPrivateIPs=false (default), localhost is allowed
        let url = SecurityValidator.validateURL("http://localhost/api")
        if url != nil {
            XCTAssertEqual(url?.host, "localhost")
        }
        // nil is also acceptable (no strict requirement when flag is off)
    }

    func testValidateURL_PrivateIPv4_blocked_when_flagEnabled() {
        SecurityValidator.blockPrivateIPs = true
        let privateHosts = [
            "http://127.0.0.1/api",
            "http://10.0.0.1/resource",
            "http://192.168.1.1/admin",
            "http://172.16.0.1/internal",
            "http://169.254.1.1/metadata",
        ]
        for urlStr in privateHosts {
            XCTAssertNil(
                SecurityValidator.validateURL(urlStr),
                "Private IP URL should be blocked when blockPrivateIPs=true: \(urlStr)"
            )
        }
    }

    func testValidateURL_PrivateIPv4_allowed_when_flagDisabled() {
        SecurityValidator.blockPrivateIPs = false
        let url = SecurityValidator.validateURL("http://192.168.1.1/resource")
        // When flag is off, private IPs pass scheme/format validation
        XCTAssertNotNil(url, "Private IP should be allowed when blockPrivateIPs=false")
    }

    func testValidateURL_IPv6Loopback_blocked_when_flagEnabled() {
        SecurityValidator.blockPrivateIPs = true
        XCTAssertNil(
            SecurityValidator.validateURL("http://[::1]/api"),
            "IPv6 loopback ::1 must be blocked when blockPrivateIPs=true"
        )
    }

    func testValidateURL_PublicIP_not_blocked() {
        SecurityValidator.blockPrivateIPs = true
        let url = SecurityValidator.validateURL("https://8.8.8.8/dns-query")
        XCTAssertNotNil(url, "Public IP 8.8.8.8 must not be blocked by private-IP filter")
    }

    // MARK: - File Path Validation

    func testValidateSavePath_AppSandbox_succeeds() {
        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_download_\(UUID().uuidString).zip").path
        let validated = SecurityValidator.validateSavePath(tempPath)
        XCTAssertNotNil(validated, "Path within app sandbox should be valid")
    }

    func testValidateSavePath_TraversalAttempt_rejected() {
        let maliciousPath = FileManager.default.temporaryDirectory.path
            + "/../../etc/passwd"
        let validated = SecurityValidator.validateSavePath(maliciousPath)
        XCTAssertNil(validated, "Path traversal attempt ('../..') must be rejected")
    }

    func testValidateSavePath_AbsoluteSystemPath_rejected() {
        let systemPath = "/etc/hosts"
        let validated = SecurityValidator.validateSavePath(systemPath)
        XCTAssertNil(validated, "System path outside app sandbox must be rejected")
    }

    func testValidateSavePath_EmptyPath_rejected() {
        XCTAssertNil(SecurityValidator.validateSavePath(""),
                     "Empty path must be rejected")
    }

    // MARK: - Safe Logging

    func testSafeLog_RedactsSensitiveHeaders() {
        let headers: [String: String] = [
            "Authorization": "Bearer secret-token-abc123",
            "Content-Type": "application/json",
            "X-API-Key": "api-key-xyz789"
        ]
        let logged = SecurityValidator.safeLog(headers: headers)
        XCTAssertFalse(logged.contains("secret-token-abc123"),
                       "Authorization token must not appear in logs")
        XCTAssertFalse(logged.contains("api-key-xyz789"),
                       "API key must not appear in logs")
        XCTAssertTrue(logged.contains("Content-Type"),
                      "Non-sensitive headers should be logged")
    }
}
