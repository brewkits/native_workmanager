import Foundation
import KMPWorkManager

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
        // Response validation patterns
        let successPattern: String?  // Regex pattern that response must match to be success
        let failurePattern: String?  // Regex pattern that indicates failure (overrides 200)

        var httpMethod: String {
            (method ?? "get").uppercased()
        }

        var timeout: TimeInterval {
            TimeInterval((timeoutMs ?? HttpRequestWorker.defaultTimeoutMs) / 1000)
        }
    }

    func doWork(input: String?, env: KMPWorkManager.WorkerEnvironment) async throws -> WorkerResult {
        guard let input = input, !input.isEmpty else {
            NSLog("[NativeWorkManager] HttpRequestWorker: Error - Empty or null input")
            return .failure(message: "Empty or null input")
        }

        // Parse configuration
        // Parse configuration
        guard let data = input.data(using: .utf8) else {
            NSLog("[NativeWorkManager] HttpRequestWorker: Error - Invalid UTF-8 encoding")
            return .failure(message: "Invalid input encoding")
        }

        let config: Config
        do {
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            NSLog("[NativeWorkManager] HttpRequestWorker: Error parsing JSON config: \(error)")
            return .failure(message: "Invalid JSON config: \(error.localizedDescription)")
        }

        // Parse request signing config from raw dict (not Codable — parsed separately)
        let rawDict = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
        let signingConfig = RequestSigner.Config.from(rawDict?["requestSigning"] as? [String: Any])
        
        // Token refresh config
        let tokenRefreshConfig = TokenRefreshConfig.from(rawDict?["tokenRefresh"] as? [String: Any])

        // Validate URL scheme (prevent file://, ftp://, etc.)
        guard let url = SecurityValidator.validateURL(config.url) else {
            NSLog("[NativeWorkManager] HttpRequestWorker: Error - Invalid or unsafe URL")
            return .failure(message: "Invalid or unsafe URL")
        }

        // Build request
        func buildRequest(url: URL, config: Config, signingConfig: RequestSigner.Config?, newToken: String? = nil, trConfig: TokenRefreshConfig? = nil) -> URLRequest {
            var request = URLRequest(url: url)
            request.httpMethod = config.httpMethod
            request.timeoutInterval = config.timeout

            // Add headers
            if let headers = config.headers {
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            
            // Apply new token if refreshed
            if let token = newToken, let tr = trConfig {
                request.setValue("\(tr.effectiveTokenPrefix)\(token)", forHTTPHeaderField: tr.effectiveTokenHeaderName)
            }

            // Add body
            if let body = config.body, !body.isEmpty {
                if let bodyData = body.data(using: .utf8) {
                    request.httpBody = bodyData
                    if request.value(forHTTPHeaderField: "Content-Type") == nil {
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    }
                }
            }

            // Apply HMAC-SHA256 request signing if configured
            if var sc = signingConfig {
                RequestSigner.sign(request: &request, config: sc)
            }
            
            return request
        }

        var request = buildRequest(url: url, config: config, signingConfig: signingConfig)

        // Sanitize URL for logging (redact query params)
        let sanitizedURL = SecurityValidator.sanitizedURL(config.url)
        NSLog("[NativeWorkManager] HttpRequestWorker: \(config.httpMethod) \(sanitizedURL)")

        // Execute request
        do {
            NSLog("[NativeWorkManager] HttpRequestWorker: Starting network request for \(config.url)...")
            
            // Use a separate Task for the network call to avoid potential async/await state issues
            var (data, response) = try await Task {
                return try await URLSession.shared.data(for: request)
            }.value
            
            NSLog("[NativeWorkManager] HttpRequestWorker: Request finished, data length: \(data.count)")

            guard var httpResponse = response as? HTTPURLResponse else {
                NSLog("[NativeWorkManager] HttpRequestWorker: Error - Invalid response type")
                return .failure(message: "Invalid response type")
            }
            
            // Handle 401 with Token Refresh
            if httpResponse.statusCode == 401, let tr = tokenRefreshConfig {
                NSLog("[NativeWorkManager] HttpRequestWorker: Received 401 — Attempting token refresh...")
                await AuthTokenManager.shared.invalidateCachedToken()
                if let newToken = await AuthTokenManager.shared.refreshToken(config: tr, currentSession: URLSession.shared) {
                    NSLog("[NativeWorkManager] HttpRequestWorker: Token refresh successful — retrying request...")
                    request = buildRequest(url: url, config: config, signingConfig: signingConfig, newToken: newToken, trConfig: tr)
                    (data, response) = try await URLSession.shared.data(for: request)
                    if let newHttpResponse = response as? HTTPURLResponse {
                        httpResponse = newHttpResponse
                    }
                } else {
                    NSLog("[NativeWorkManager] HttpRequestWorker: Token refresh failed")
                }
            }

            // Validate response body size
            guard SecurityValidator.validateResponseSize(data) else {
                NSLog("[NativeWorkManager] HttpRequestWorker: Error - Response body too large")
                return .failure(message: "Response body too large")
            }

            let statusCode = httpResponse.statusCode
            let success = (200..<300).contains(statusCode)
            let bodySize = data.count
            let responseBody = String(data: data, encoding: .utf8) ?? ""

            if success {
                // Validate response body against patterns (even if HTTP 200)
                if let validationError = validateResponse(responseBody: responseBody, config: config) {
                    NSLog("[NativeWorkManager] HttpRequestWorker: Validation failed - \(validationError)")
                    NSLog("[NativeWorkManager] HttpRequestWorker: Response body: \(SecurityValidator.truncateForLogging(responseBody, maxLength: 200))")
                    return .failure(message: "Response validation failed: \(validationError)")
                }

                NSLog("[NativeWorkManager] HttpRequestWorker: Success - Status \(statusCode), Body size: \(bodySize) bytes")
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
                // Truncate error body for logging
                let truncatedError = SecurityValidator.truncateForLogging(responseBody, maxLength: 200)
                NSLog("[NativeWorkManager] HttpRequestWorker: Failed - Status \(statusCode)")
                NSLog("[NativeWorkManager] HttpRequestWorker: Error body: \(truncatedError)")
                return .failure(message: "HTTP \(statusCode)")
            }
        } catch {
            NSLog("[NativeWorkManager] HttpRequestWorker: Error - \(error.localizedDescription)")
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
                    NSLog("[NativeWorkManager] HttpRequestWorker: Response matched failure pattern: \(failurePattern)")
                    return "Response matches failure pattern"
                }
            } catch {
                NSLog("[NativeWorkManager] HttpRequestWorker: Invalid failure pattern regex: \(error.localizedDescription)")
                return "Invalid failure pattern regex: \(error.localizedDescription)"
            }
        }

        // Check success pattern (if provided)
        if let successPattern = config.successPattern {
            do {
                let successRegex = try NSRegularExpression(pattern: successPattern, options: [.caseInsensitive])
                let range = NSRange(responseBody.startIndex..., in: responseBody)
                if successRegex.firstMatch(in: responseBody, options: [], range: range) == nil {
                    NSLog("[NativeWorkManager] HttpRequestWorker: Response did not match success pattern: \(successPattern)")
                    return "Response does not match success pattern"
                }
            } catch {
                NSLog("[NativeWorkManager] HttpRequestWorker: Invalid success pattern regex: \(error.localizedDescription)")
                return "Invalid success pattern regex: \(error.localizedDescription)"
            }
        }

        // Validation passed
        return nil
    }
}
