import Foundation

/// Native HTTP request worker for iOS.
///
/// Executes HTTP requests using URLSession without requiring Flutter Engine.
/// Supports GET, POST, PUT, DELETE, PATCH methods with custom headers and body.
/// Supports regex-based response validation to detect API errors in 200 responses.
///
/// **Configuration JSON:**
/// ```json
/// {
///   "url": "https://api.example.com/endpoint",
///   "method": "post",           // Optional: "get", "post", "put", "delete", "patch" (default: "get")
///   "headers": {                // Optional
///     "Authorization": "Bearer token",
///     "Content-Type": "application/json"
///   },
///   "body": "{\"key\":\"value\"}", // Optional: Request body
///   "timeoutMs": 30000          // Optional: Timeout in milliseconds (default: 30s)
/// }
/// ```
///
/// **Configuration JSON (With Response Validation - NEW):**
/// ```json
/// {
///   "url": "https://api.example.com/endpoint",
///   "method": "post",
///   "body": "{\"action\":\"login\"}",
///   "successPattern": "\"status\"\\s*:\\s*\"success\"",  // Regex pattern for success
///   "failurePattern": "\"status\"\\s*:\\s*\"error\""     // Regex pattern for failure
/// }
/// ```
///
/// **Validation Behavior:**
/// - If `failurePattern` matches, task fails even with HTTP 200
/// - If `successPattern` provided and doesn't match, task fails even with HTTP 200
/// - Patterns are checked in order: failurePattern → successPattern
///
/// **Performance:** ~2-3MB RAM, <50ms cold start
class HttpRequestWorker: IosWorker {

    private static let defaultTimeoutMs: Int64 = 30_000

    struct Config: Codable {
        let url: String
        let method: String?
        let headers: [String: String]?
        let body: String?
        let timeoutMs: Int64?
        // 👇 NEW: Response validation patterns
        let successPattern: String?  // Regex pattern that response must match to be success
        let failurePattern: String?  // Regex pattern that indicates failure (overrides 200)

        var httpMethod: String {
            (method ?? "get").uppercased()
        }

        var timeout: TimeInterval {
            TimeInterval((timeoutMs ?? HttpRequestWorker.defaultTimeoutMs) / 1000)
        }
    }

    func doWork(input: String?) async throws -> WorkerResult {
        guard let input = input, !input.isEmpty else {
            print("HttpRequestWorker: Error - Empty or null input")
            return .failure(message: "Empty or null input")
        }

        // Parse configuration
        let config: Config
        do {
            let data = input.data(using: .utf8)!
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            print("HttpRequestWorker: Error parsing JSON config: \(error)")
            return .failure(message: "Invalid JSON config: \(error.localizedDescription)")
        }

        // ✅ SECURITY: Validate URL scheme (prevent file://, ftp://, etc.)
        guard let url = SecurityValidator.validateURL(config.url) else {
            print("HttpRequestWorker: Error - Invalid or unsafe URL")
            return .failure(message: "Invalid or unsafe URL")
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = config.httpMethod
        request.timeoutInterval = config.timeout

        // Add headers
        if let headers = config.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Add body
        if let body = config.body, !body.isEmpty {
            guard let bodyData = body.data(using: .utf8) else {
                print("HttpRequestWorker: Error - Cannot encode body as UTF-8")
                return .failure(message: "Cannot encode body as UTF-8")
            }

            // ✅ SECURITY: Validate request body size
            guard SecurityValidator.validateRequestSize(bodyData) else {
                print("HttpRequestWorker: Error - Request body too large")
                return .failure(message: "Request body too large")
            }

            request.httpBody = bodyData

            // Set default Content-Type if not provided
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        // ✅ SECURITY: Sanitize URL for logging (redact query params)
        let sanitizedURL = SecurityValidator.sanitizedURL(config.url)
        print("HttpRequestWorker: \(config.httpMethod) \(sanitizedURL)")

        // Execute request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("HttpRequestWorker: Error - Invalid response type")
                return .failure(message: "Invalid response type")
            }

            // ✅ SECURITY: Validate response body size
            guard SecurityValidator.validateResponseSize(data) else {
                print("HttpRequestWorker: Error - Response body too large")
                return .failure(message: "Response body too large")
            }

            let statusCode = httpResponse.statusCode
            let success = (200..<300).contains(statusCode)
            let bodySize = data.count
            let responseBody = String(data: data, encoding: .utf8) ?? ""

            if success {
                // 👇 NEW: Validate response body against patterns (even if HTTP 200)
                if let validationError = validateResponse(responseBody: responseBody, config: config) {
                    print("HttpRequestWorker: Validation failed - \(validationError)")
                    print("HttpRequestWorker: Response body: \(SecurityValidator.truncateForLogging(responseBody, maxLength: 200))")
                    return .failure(message: "Response validation failed: \(validationError)")
                }

                print("HttpRequestWorker: Success - Status \(statusCode), Body size: \(bodySize) bytes")
                return .success(
                    message: "HTTP \(statusCode) - \(bodySize) bytes",
                    data: [
                        "statusCode": statusCode,
                        "body": responseBody,
                        "headers": httpResponse.allHeaderFields as Any,
                        "contentLength": bodySize
                    ]
                )
            } else {
                // ✅ SECURITY: Truncate error body for logging
                let truncatedError = SecurityValidator.truncateForLogging(responseBody, maxLength: 200)
                print("HttpRequestWorker: Failed - Status \(statusCode)")
                print("HttpRequestWorker: Error body: \(truncatedError)")
                return .failure(message: "HTTP \(statusCode)")
            }
        } catch {
            print("HttpRequestWorker: Error - \(error.localizedDescription)")
            return .failure(message: error.localizedDescription)
        }
    }

    /// Validate response body against configured patterns.
    ///
    /// - Parameters:
    ///   - responseBody: The response body to validate
    ///   - config: Configuration with validation patterns
    /// - Returns: Error message if validation fails, nil if validation passes
    private func validateResponse(responseBody: String, config: Config) -> String? {
        // Check failure pattern first (highest priority)
        if let failurePattern = config.failurePattern {
            do {
                let failureRegex = try NSRegularExpression(pattern: failurePattern, options: [.caseInsensitive])
                let range = NSRange(responseBody.startIndex..., in: responseBody)
                if failureRegex.firstMatch(in: responseBody, options: [], range: range) != nil {
                    print("HttpRequestWorker: Response matched failure pattern: \(failurePattern)")
                    return "Response matches failure pattern"
                }
            } catch {
                print("HttpRequestWorker: Invalid failure pattern regex: \(error.localizedDescription)")
                return "Invalid failure pattern regex: \(error.localizedDescription)"
            }
        }

        // Check success pattern (if provided)
        if let successPattern = config.successPattern {
            do {
                let successRegex = try NSRegularExpression(pattern: successPattern, options: [.caseInsensitive])
                let range = NSRange(responseBody.startIndex..., in: responseBody)
                if successRegex.firstMatch(in: responseBody, options: [], range: range) == nil {
                    print("HttpRequestWorker: Response did not match success pattern: \(successPattern)")
                    return "Response does not match success pattern"
                }
            } catch {
                print("HttpRequestWorker: Invalid success pattern regex: \(error.localizedDescription)")
                return "Invalid success pattern regex: \(error.localizedDescription)"
            }
        }

        // Validation passed
        return nil
    }
}
