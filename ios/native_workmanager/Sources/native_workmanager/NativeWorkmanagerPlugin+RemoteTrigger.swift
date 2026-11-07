import Foundation
import KMPWorkManager
import Flutter
import CryptoKit

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

        let secretKey = ruleMap["secretKey"] as? String

        if #available(iOS 13.0, *) {
            RemoteTriggerStore.shared.upsert(
                source: source,
                payloadKey: payloadKey,
                workerMappingsJson: mappingsJson,
                secretKey: secretKey
            )
        }

        NativeLogger.d("✅ Remote trigger registered for \(source) (key: \(payloadKey), hmac: \(secretKey != nil))")
        result(nil)
    }

    /// Handle a remote notification and optionally trigger a native worker.
    @objc public static func onRemoteNotification(userInfo: [AnyHashable: Any],
                                                 completionHandler: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
        guard #available(iOS 13.0, *) else {
            completionHandler(.noData)
            return false
        }

        let payload = userInfo as? [String: Any] ?? [:]
        let source = "fcm"
        
        guard let record = RemoteTriggerStore.shared.getRule(source: source) else {
            if let command = payload["native_wm"] {
                // No rule is registered, so there is no secret to verify against: this path is
                // unauthenticated (Android ignores such pushes). Kept for compatibility; loud on purpose.
                NativeLogger.w("⚠️ Executing UNAUTHENTICATED native_wm command (no remote-trigger rule/secretKey registered).")
                NativeLogger.d("📡 Processing direct command (Native WM)")
                Task {
                    let cmdMap = (command as? [String: Any]) ?? (try? JSONSerialization.jsonObject(with: (command as? String ?? "").data(using: .utf8) ?? Data()) as? [String: Any]) ?? [:]
                    let success = await CommandProcessor.handleDirectRemoteCommand(command: cmdMap)
                    completionHandler(success ? .newData : .failed)
                }
                return true
            }
            completionHandler(.noData)
            return false
        }

        // Phase 2: HMAC Verification
        if let secretKey = record.secretKey {
            let verdict = RemoteTriggerSignature.verify(
                payload: payload, secretKey: secretKey, now: Date(),
                nonces: RemoteTriggerSignature.sharedNonces
            ) { legacySignature in
                verifyHmac(payload: payload, secretKey: secretKey, signature: legacySignature)
            }
            switch verdict {
            case .validV2:
                break
            case .validLegacy:
                NativeLogger.w("⚠️ Remote trigger for \(source) used the DEPRECATED v1 signature (no timestamp/nonce, replayable). Switch your backend to v2.")
            default:
                NativeLogger.w("⚠️ Remote trigger REJECTED (\(verdict)): invalid signature for \(source)")
                completionHandler(.failed)
                return false
            }
        } else if payload["native_wm"] != nil {
            NativeLogger.w("⚠️ Unsigned remote command for \(source): no secretKey is set on this rule, so anyone who can deliver a push can run native_wm commands. Set RemoteTriggerRule.secretKey.")
        }

        // Mode 1: Direct Command (Highest priority)
        if let command = payload["native_wm"] {
            NativeLogger.d("📡 Processing direct command (Native WM)")
            Task {
                let cmdMap = (command as? [String: Any]) ?? (try? JSONSerialization.jsonObject(with: (command as? String ?? "").data(using: .utf8) ?? Data()) as? [String: Any]) ?? [:]
                let success = await CommandProcessor.handleDirectRemoteCommand(command: cmdMap)
                completionHandler(success ? .newData : .failed)
            }
            return true
        }

        // Mode 2: Rule-based Mapping
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

        NativeLogger.d("📡 Processing remote trigger: \(source) (mapped via \(record.payloadKey))")

        guard let mappingsData = record.workerMappingsJson.data(using: .utf8),
              let mappings = try? JSONSerialization.jsonObject(with: mappingsData) as? [String: Any],
              let mapping = mappings[val] as? [String: Any],
              let workerClassName = mapping["workerClassName"] as? String,
              let workerConfig = mapping["workerConfig"] as? [String: Any] else {
            completionHandler(.noData)
            return false
        }

        let substitutedConfig = CommandProcessor.substituteTemplates(in: workerConfig, with: payload)
        let taskId = "remote_\(val)_\(UUID().uuidString.prefix(8))"

        NativeLogger.d("✅ Remote trigger matched '\(val)': Executing \(workerClassName) (\(taskId))")

        Task {
            let success = await CommandProcessor.executeWorkerStateless(
                taskId: taskId,
                workerClassName: workerClassName,
                workerConfig: substitutedConfig
            )
            completionHandler(success ? .newData : .failed)
        }

        return true
    }

    private static func verifyHmac(payload: [String: Any], secretKey: String, signature: String) -> Bool {
        if #available(iOS 13.0, *) {
            let filteredKeys = payload.keys.filter { $0 != "x-native-wm-signature" }.sorted()
            let dataToSign = filteredKeys.map { key in
                let value = payload[key]
                let valueStr: String
                
                if let dict = value as? [String: Any] {
                    let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys, .fragmentsAllowed])
                    valueStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? "\(value ?? "null")"
                } else if let array = value as? [Any] {
                    let data = try? JSONSerialization.data(withJSONObject: array, options: [.sortedKeys, .fragmentsAllowed])
                    valueStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? "\(value ?? "null")"
                } else {
                    valueStr = "\(value ?? "null")"
                }
                return "\(key)=\(valueStr)"
            }.joined(separator: "|")
            
            guard let keyData = secretKey.data(using: .utf8),
                  let messageData = dataToSign.data(using: .utf8) else {
                return false
            }
            
            let key = SymmetricKey(data: keyData)

            // Constant-time verification. Swift's String `==` short-circuits on the
            // first mismatch, which can leak how many leading bytes matched (timing
            // side-channel). CryptoKit's isValidAuthenticationCode compares in
            // constant time. Decode the provided hex first so we compare raw bytes.
            guard let providedMac = Self.dataFromHexString(signature) else { return false }
            return HMAC<SHA256>.isValidAuthenticationCode(
                providedMac, authenticating: messageData, using: key)
        }
        return false
    }

    /// Decode a hex string to Data, or nil if it is malformed (odd length / non-hex).
    private static func dataFromHexString(_ hex: String) -> Data? {
        guard !hex.isEmpty, hex.count % 2 == 0 else { return nil }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }
}
