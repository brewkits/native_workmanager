import Foundation
import KMPWorkManager
import Flutter

extension NativeWorkmanagerPlugin {

    internal func handleRegisterRemoteTrigger(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let source = args["source"] as? String,
              let ruleMap = args["rule"] as? [String: Any],
              let payloadKey = ruleMap["payloadKey"] as? String,
              let workerMappings = ruleMap["workerMappings"] as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
            return
        }

        guard let mappingsData = try? JSONSerialization.data(withJSONObject: workerMappings),
              let mappingsJson = String(data: mappingsData, encoding: .utf8) else {
            result(FlutterError(code: "SERIALIZATION_ERROR", message: "Failed to serialize worker mappings", details: nil))
            return
        }

        if #available(iOS 13.0, *) {
            RemoteTriggerStore.shared.upsert(
                source: source,
                payloadKey: payloadKey,
                workerMappingsJson: mappingsJson
            )
        }

        NativeLogger.d("✅ Remote trigger registered for \(source) (key: \(payloadKey))")
        result(nil)
    }

    /// Handle a remote notification and optionally trigger a native worker.
    ///
    /// Designed to be called from AppDelegate.didReceiveRemoteNotification without waking Flutter.
    @objc public static func onRemoteNotification(userInfo: [AnyHashable: Any],
                                                 completionHandler: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
        guard #available(iOS 13.0, *) else {
            completionHandler(.noData)
            return false
        }

        let source = "fcm" // Default source for remote notifications
        guard let record = RemoteTriggerStore.shared.getRule(source: source) else {
            completionHandler(.noData)
            return false
        }

        // userInfo can contain data in different formats depending on how it was sent
        // FCM usually puts data in the top level or under a 'data' key.
        let payload = userInfo as? [String: Any] ?? [:]
        
        // Try to find the trigger value
        var triggerValue: String?
        if let val = payload[record.payloadKey] {
            triggerValue = "\(val)"
        } else if let data = payload["data"] as? [String: Any], let val = data[record.payloadKey] {
            triggerValue = "\(val)"
        }

        guard let val = triggerValue else {
            completionHandler(.noData)
            return false
        }

        guard let mappingsData = record.workerMappingsJson.data(using: .utf8),
              let mappings = try? JSONSerialization.jsonObject(with: mappingsData) as? [String: Any],
              let mapping = mappings[val] as? [String: Any],
              let workerClassName = mapping["workerClassName"] as? String,
              let workerConfig = mapping["workerConfig"] as? [String: Any] else {
            completionHandler(.noData)
            return false
        }

        // Perform template substitution on workerConfig
        let substitutedConfig = substituteTemplates(in: workerConfig, with: payload)

        let taskId = "remote_\(val)_\(UUID().uuidString.prefix(8))"

        NativeLogger.d("✅ Remote trigger matched '\(val)': Executing \(workerClassName) (\(taskId))")

        // Execute the worker directly (iOS background execution)
        // Since we are in a static context, we need a way to execute without a plugin instance.
        // We can use a one-off execution helper.
        
        Task {
            let success = await executeWorkerStateless(
                taskId: taskId,
                workerClassName: workerClassName,
                workerConfig: substitutedConfig
            )
            completionHandler(success ? .newData : .failed)
        }

        return true
    }

    private static func substituteTemplates(in config: [String: Any], with values: [String: Any]) -> [String: Any] {
        var result = config
        for (key, value) in config {
            if let strValue = value as? String {
                result[key] = substituteString(strValue, with: values)
            } else if let dictValue = value as? [String: Any] {
                result[key] = substituteTemplates(in: dictValue, with: values)
            } else if let arrayValue = value as? [[String: Any]] {
                result[key] = arrayValue.map { substituteTemplates(in: $0, with: values) }
            }
        }
        return result
    }

    private static func substituteString(_ template: String, with values: [String: Any]) -> String {
        var result = template
        for (key, value) in values {
            let placeholder = "{{\(key)}}"
            if result.contains(placeholder) {
                result = result.replacingOccurrences(of: placeholder, with: "\(value)")
            }
        }
        // Also check inside 'data' if present (FCM pattern)
        if let data = values["data"] as? [String: Any] {
            for (key, value) in data {
                let placeholder = "{{\(key)}}"
                if result.contains(placeholder) {
                    result = result.replacingOccurrences(of: placeholder, with: "\(value)")
                }
            }
        }
        return result
    }

    private static func executeWorkerStateless(taskId: String,
                                              workerClassName: String,
                                              workerConfig: [String: Any]) async -> Bool {
        if workerClassName.contains("HttpDownloadWorker") {
            // BackgroundSessionManager handles network waiting and partial-file resume
            return await withCheckedContinuation { continuation in
                BackgroundSessionManager.shared.download(
                    taskId: taskId,
                    config: workerConfig
                ) { result in
                    switch result {
                    case .success: continuation.resume(returning: true)
                    case .failure: continuation.resume(returning: false)
                    }
                }
            }
        }

        // For all other worker types, use IosWorkerFactory directly.
        // Note: events cannot be emitted (Flutter may not be running), but the work is done.
        guard let worker = IosWorkerFactory.createWorker(className: workerClassName) else {
            NativeLogger.w("executeWorkerStateless: unknown worker class '\(workerClassName)'")
            return false
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: workerConfig),
              let inputJson = String(data: jsonData, encoding: .utf8) else {
            return false
        }

        do {
            let result = try await worker.doWork(input: inputJson, env: WorkerEnvironment(progressListener: nil, isCancelled: { KotlinBoolean(bool: false) }))
            return result.success
        } catch {
            NativeLogger.e("executeWorkerStateless '\(taskId)': \(error.localizedDescription)")
            return false
        }
    }
}
