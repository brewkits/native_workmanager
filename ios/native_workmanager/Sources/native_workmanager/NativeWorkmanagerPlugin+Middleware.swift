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
                default:
                    break
                }
            }

            return modified ? resultConfig : config
        }
        return config
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
