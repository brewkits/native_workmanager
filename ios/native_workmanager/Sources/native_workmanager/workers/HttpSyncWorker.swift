import Foundation
import KMPWorkManager

/// Native HTTP sync worker for iOS.
///
/// Optimized for JSON request/response synchronization scenarios.
/// Automatically sets Content-Type to application/json.
///
/// **Configuration JSON:**
/// ```json
/// {
///   "url": "https://api.example.com/sync",
///   "method": "post",           // Optional: "get", "post", "put" (default: "post")
///   "headers": {                // Optional
///     "Authorization": "Bearer token"
///   },
///   "requestBody": {            // Optional: JSON object to send
///     "lastSync": 1234567890,
///     "data": [...]
///   },
///   "timeoutMs": 60000         // Optional: Timeout (default: 1 minute)
/// }
/// ```
class HttpSyncWorker: IosWorker {

    private static let defaultTimeoutMs: Int64 = 60_000

    struct Config: Codable {
        let url: String
        let method: String?
        let headers: [String: String]?
        let requestBody: String? // JSON string (pre-encoded by Dart via jsonEncode)
        let timeoutMs: Int64?

        var httpMethod: String {
            (method ?? "post").uppercased()
        }

        var timeout: TimeInterval {
            TimeInterval((timeoutMs ?? HttpSyncWorker.defaultTimeoutMs) / 1000)
        }
    }

    func doWork(input: String?, env: KMPWorkManager.WorkerEnvironment) async throws -> WorkerResult {
        guard let input = input, !input.isEmpty else {
            NSLog("[NativeWorkManager] HttpSyncWorker: Error - Empty or null input")
            return .failure(message: "Empty or null input")
        }

        // Parse configuration
        guard let data = input.data(using: .utf8) else {
            NSLog("[NativeWorkManager] HttpSyncWorker: Error - Invalid UTF-8 encoding")
            return .failure(message: "Invalid input encoding")
        }

        let config: Config
        do {
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            NSLog("[NativeWorkManager] HttpSyncWorker: Error parsing JSON config: \(error)")
            return .failure(message: "Invalid JSON config: \(error.localizedDescription)")
        }

        // Parse request signing & token refresh from raw dict
        let rawDict = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
        let signingConfig = RequestSigner.Config.from(rawDict?["requestSigning"] as? [String: Any])
        let tokenRefreshConfig = TokenRefreshConfig.from(rawDict?["tokenRefresh"] as? [String: Any])

        // Validate URL scheme (prevent file://, ftp://, etc.)
        guard let url = SecurityValidator.validateURL(config.url) else {
            NSLog("[NativeWorkManager] HttpSyncWorker: Error - Invalid or unsafe URL")
            return .failure(message: "Invalid or unsafe URL")
        }

        // Build request helper
        func buildRequest(url: URL, config: Config, signingConfig: RequestSigner.Config?, newToken: String? = nil, trConfig: TokenRefreshConfig? = nil) -> URLRequest {
            var request = URLRequest(url: url)
            request.httpMethod = config.httpMethod
            request.timeoutInterval = config.timeout
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Add custom headers
            if let headers = config.headers {
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            
            // Apply new token if refreshed
            if let token = newToken, let tr = trConfig {
                request.setValue("\(tr.effectiveTokenPrefix)\(token)", forHTTPHeaderField: tr.effectiveTokenHeaderName)
            }

            // Add request body if present (requestBody is a JSON string from Dart)
            if let requestBody = config.requestBody, !requestBody.isEmpty {
                if let bodyData = requestBody.data(using: .utf8) {
                    request.httpBody = bodyData
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
        NSLog("[NativeWorkManager] HttpSyncWorker: \(config.httpMethod) \(sanitizedURL)")

        // Execute request
        do {
            var (data, response) = try await URLSession.shared.data(for: request)

            guard var httpResponse = response as? HTTPURLResponse else {
                NSLog("[NativeWorkManager] HttpSyncWorker: Error - Invalid response type")
                return .failure(message: "Invalid response type")
            }
            
            // Handle 401 with Token Refresh
            if httpResponse.statusCode == 401, let tr = tokenRefreshConfig {
                NSLog("[NativeWorkManager] HttpSyncWorker: Received 401 — Attempting token refresh...")
                await AuthTokenManager.shared.invalidateCachedToken()
                if let newToken = await AuthTokenManager.shared.refreshToken(config: tr, currentSession: URLSession.shared) {
                    NSLog("[NativeWorkManager] HttpSyncWorker: Token refresh successful — retrying request...")
                    request = buildRequest(url: url, config: config, signingConfig: signingConfig, newToken: newToken, trConfig: tr)
                    (data, response) = try await URLSession.shared.data(for: request)
                    if let newHttpResponse = response as? HTTPURLResponse {
                        httpResponse = newHttpResponse
                    }
                } else {
                    NSLog("[NativeWorkManager] HttpSyncWorker: Token refresh failed")
                }
            }

            // Validate response body size
            guard SecurityValidator.validateResponseSize(data) else {
                NSLog("[NativeWorkManager] HttpSyncWorker: Error - Response body too large")
                return .failure(message: "Response body too large")
            }

            let statusCode = httpResponse.statusCode
            let success = (200..<300).contains(statusCode)
            let bodySize = data.count
            let responseBody = String(data: data, encoding: .utf8) ?? ""

            if success {
                NSLog("[NativeWorkManager] HttpSyncWorker: Success - Status \(statusCode), Body size: \(bodySize) bytes")
                return .success(
                    message: "HTTP \(statusCode) - \(bodySize) bytes",
                    data: [
                        "statusCode": statusCode,
                        "body": responseBody,
                        "headers": httpResponse.allHeaderFields as Any
                    ]
                )
            } else {
                let truncatedError = SecurityValidator.truncateForLogging(responseBody, maxLength: 200)
                NSLog("[NativeWorkManager] HttpSyncWorker: Failed - Status \(statusCode)")
                NSLog("[NativeWorkManager] HttpSyncWorker: Error: \(truncatedError)")
                return .failure(message: "HTTP \(statusCode)")
            }
        } catch {
            NSLog("[NativeWorkManager] HttpSyncWorker: Error - \(error.localizedDescription)")
            return .failure(message: error.localizedDescription)
        }
    }
}
