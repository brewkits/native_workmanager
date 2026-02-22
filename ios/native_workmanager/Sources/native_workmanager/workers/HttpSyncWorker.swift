import Foundation

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
///
/// **Use Cases:**
/// - Periodic data synchronization
/// - API sync endpoints
/// - JSON-based communication
///
/// **Performance:** ~3-5MB RAM, optimized for JSON
class HttpSyncWorker: IosWorker {

    private static let defaultTimeoutMs: Int64 = 60_000

    struct Config: Codable {
        let url: String
        let method: String?
        let headers: [String: String]?
        let requestBody: [String: AnyCodable]? // Allow any JSON structure
        let timeoutMs: Int64?

        var httpMethod: String {
            (method ?? "post").uppercased()
        }

        var timeout: TimeInterval {
            TimeInterval((timeoutMs ?? HttpSyncWorker.defaultTimeoutMs) / 1000)
        }
    }

    func doWork(input: String?) async throws -> WorkerResult {
        guard let input = input, !input.isEmpty else {
            print("HttpSyncWorker: Error - Empty or null input")
            return .failure(message: "Empty or null input")
        }

        // Parse configuration
        guard let data = input.data(using: .utf8) else {
            print("HttpSyncWorker: Error - Invalid UTF-8 encoding")
            return .failure(message: "Invalid input encoding")
        }

        let config: Config
        do {
            config = try JSONDecoder().decode(Config.self, from: data)
        } catch {
            print("HttpSyncWorker: Error parsing JSON config: \(error)")
            return .failure(message: "Invalid JSON config: \(error.localizedDescription)")
        }

        // ✅ SECURITY: Validate URL scheme (prevent file://, ftp://, etc.)
        guard let url = SecurityValidator.validateURL(config.url) else {
            print("HttpSyncWorker: Error - Invalid or unsafe URL")
            return .failure(message: "Invalid or unsafe URL")
        }

        // ✅ SECURITY: Sanitize URL for logging (redact query params)
        let sanitizedURL = SecurityValidator.sanitizedURL(config.url)
        print("HttpSyncWorker: \(config.httpMethod) \(sanitizedURL)")

        // Build request
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

        // Add request body if present
        if let requestBody = config.requestBody {
            do {
                let bodyData = try JSONEncoder().encode(requestBody)

                // ✅ SECURITY: Validate request body size
                guard SecurityValidator.validateRequestSize(bodyData) else {
                    print("HttpSyncWorker: Error - Request body too large")
                    return .failure(message: "Request body too large")
                }

                request.httpBody = bodyData
                print("HttpSyncWorker: Request body size: \(bodyData.count) bytes")
            } catch {
                print("HttpSyncWorker: Error encoding request body: \(error)")
                return .failure(message: "Failed to encode request body: \(error.localizedDescription)")
            }
        }

        // Execute request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("HttpSyncWorker: Error - Invalid response type")
                return .failure(message: "Invalid response type")
            }

            // ✅ SECURITY: Validate response body size
            guard SecurityValidator.validateResponseSize(data) else {
                print("HttpSyncWorker: Error - Response body too large")
                return .failure(message: "Response body too large")
            }

            let statusCode = httpResponse.statusCode
            let success = (200..<300).contains(statusCode)
            let bodySize = data.count
            let responseBody = String(data: data, encoding: .utf8) ?? ""

            if success {
                // Try to parse response as JSON for logging
                if let json = try? JSONSerialization.jsonObject(with: data),
                   let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    // ✅ SECURITY: Truncate response for logging
                    let truncatedResponse = SecurityValidator.truncateForLogging(jsonString, maxLength: 500)
                    print("HttpSyncWorker: Success - Status \(statusCode)")
                    print("HttpSyncWorker: Response JSON:\n\(truncatedResponse)")
                } else {
                    print("HttpSyncWorker: Success - Status \(statusCode), Body size: \(bodySize) bytes")
                }
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
                print("HttpSyncWorker: Failed - Status \(statusCode)")
                print("HttpSyncWorker: Error: \(truncatedError)")
                return .failure(message: "HTTP \(statusCode)")
            }
        } catch {
            print("HttpSyncWorker: Error - \(error.localizedDescription)")
            return .failure(message: error.localizedDescription)
        }
    }
}
