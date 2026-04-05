import Foundation
import Flutter

extension NativeWorkmanagerPlugin {

    internal func handleRegisterMiddleware(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let type = args["type"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "type required", details: nil))
            return
        }

        guard let configData = try? JSONSerialization.data(withJSONObject: args),
              let configJson = String(data: configData, encoding: .utf8) else {
            result(FlutterError(code: "SERIALIZATION_ERROR", message: "Failed to serialize middleware config", details: nil))
            return
        }

        if #available(iOS 13.0, *) {
            MiddlewareStore.shared.add(type: type, configJson: configJson)
        }

        NativeLogger.d("🛡️ Registering middleware: \(type)")
        result(nil)
    }

    /// Applies registered middleware to a worker configuration.
    public static func applyMiddleware(workerClassName: String, config: [String: Any]) -> [String: Any] {
        if #available(iOS 13.0, *) {
            let middlewares = MiddlewareStore.shared.getAll()
            if middlewares.isEmpty { return config }

            var resultConfig = config
            var modified = false

            for mw in middlewares {
                guard let mwData = mw.configJson.data(using: .utf8),
                      let mwConfig = try? JSONSerialization.jsonObject(with: mwData) as? [String: Any] else {
                    continue
                }

                switch mw.type {
                case "header":
                    if applyHeaderMiddleware(workerConfig: &resultConfig, mwConfig: mwConfig) {
                        modified = true
                    }
                case "remoteConfig":
                    if applyRemoteConfigMiddleware(workerConfig: &resultConfig, mwConfig: mwConfig, workerClassName: workerClassName) {
                        modified = true
                    }
                case "logging":
                    // LoggingMiddleware fires post-execution via applyLoggingMiddleware().
                    // It does not modify worker config — skip here.
                    break
                default:
                    break
                }
            }

            return modified ? resultConfig : config
        }
        return config
    }

    private static func applyRemoteConfigMiddleware(
        workerConfig: inout [String: Any],
        mwConfig: [String: Any],
        workerClassName: String
    ) -> Bool {
        if let targetType = mwConfig["workerType"] as? String, !targetType.isEmpty {
            guard workerClassName.range(of: targetType, options: .caseInsensitive) != nil else {
                return false
            }
        }
        guard let values = mwConfig["values"] as? [String: Any], !values.isEmpty else {
            return false
        }
        for (key, value) in values {
            workerConfig[key] = value
        }
        return true
    }

    /// Fire-and-forget HTTP POST for LoggingMiddleware.
    ///
    /// Called after each task completes (success or failure). Finds all registered
    /// LoggingMiddleware records and POSTs task execution metadata to each logUrl.
    /// Errors are logged but never propagated — logging must never affect worker results.
    public static func applyLoggingMiddleware(
        taskId: String,
        workerClassName: String,
        success: Bool,
        message: String?,
        durationMs: Int64?
    ) {
        guard #available(iOS 13.0, *) else { return }
        let middlewares = MiddlewareStore.shared.getAll().filter { $0.type == "logging" }
        guard !middlewares.isEmpty else { return }

        Task.detached(priority: .utility) {
            for mw in middlewares {
                guard let mwData = mw.configJson.data(using: .utf8),
                      let mwConfig = try? JSONSerialization.jsonObject(with: mwData) as? [String: Any],
                      let logUrl = mwConfig["logUrl"] as? String, !logUrl.isEmpty,
                      let url = URL(string: logUrl) else { continue }

                var payload: [String: Any] = [
                    "taskId": taskId,
                    "workerClassName": workerClassName,
                    "success": success,
                    "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
                ]
                if let d = durationMs { payload["durationMs"] = d }
                if let m = message, !m.isEmpty { payload["message"] = m }

                guard let body = try? JSONSerialization.data(withJSONObject: payload) else { continue }

                var request = URLRequest(url: url, timeoutInterval: 5)
                request.httpMethod = "POST"
                request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                request.httpBody = body

                do {
                    _ = try await URLSession.shared.data(for: request)
                } catch {
                    print("LoggingMiddleware: Failed to POST to \(logUrl) for task '\(taskId)': \(error)")
                }
            }
        }
    }

    private static func applyHeaderMiddleware(workerConfig: inout [String: Any], mwConfig: [String: Any]) -> Bool {
        guard let url = workerConfig["url"] as? String else { return false }

        if let pattern = mwConfig["urlPattern"] as? String {
            let regex = try? NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: url.utf16.count)
            if regex?.firstMatch(in: url, options: [], range: range) == nil {
                return false
            }
        }

        // Accept [String: Any] so numeric/boolean header values are not silently dropped
        guard let headersToAdd = mwConfig["headers"] as? [String: Any] else { return false }
        var workerHeaders = workerConfig["headers"] as? [String: Any] ?? [:]

        for (key, value) in headersToAdd {
            workerHeaders[key] = value
        }

        workerConfig["headers"] = workerHeaders
        return true
    }
}
