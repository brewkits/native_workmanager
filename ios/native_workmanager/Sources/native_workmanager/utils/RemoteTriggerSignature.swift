import Foundation
import CryptoKit

/// Remote Trigger signature scheme **v2** (collision-free canonical form + replay protection).
///
/// Spec and reference signer: `doc/examples/remote_trigger_sign_v2.py`. The Kotlin twin is
/// `RemoteTriggerSignature.kt`; both are tested against the same vector. v1 is still accepted
/// (deprecated, replayable) via the `legacyVerifier` closure.
@available(iOS 13.0, macOS 10.15, *)
enum RemoteTriggerSignature {
    static let signatureKey = "x-native-wm-signature"
    static let timestampKey = "x-native-wm-timestamp"
    static let nonceKey = "x-native-wm-nonce"
    static let v2Prefix = "v2="
    static let maxSkewSeconds: Int64 = 300

    enum Verdict: Equatable { case validV2, validLegacy, invalid, stale, replayed }

    static let sharedNonces = NonceStore(defaults: .standard)

    static func verify(payload: [String: Any], secretKey: String, now: Date,
                       nonces: NonceStore,
                       legacyVerifier: (String) -> Bool) -> Verdict {
        guard let signature = payload[signatureKey] as? String else { return .invalid }
        guard signature.hasPrefix(v2Prefix) else {
            return legacyVerifier(signature) ? .validLegacy : .invalid
        }
        guard let provided = hexToData(String(signature.dropFirst(v2Prefix.count))) else { return .invalid }
        // Signature first: only authentic messages may touch the nonce store.
        guard HMAC<SHA256>.isValidAuthenticationCode(
            provided, authenticating: Data(canonicalV2(payload).utf8),
            using: SymmetricKey(data: Data(secretKey.utf8))) else { return .invalid }

        guard let ts = (payload[timestampKey] as? String).flatMap({ Int64($0) }) ?? (payload[timestampKey] as? NSNumber)?.int64Value,
              let nonce = payload[nonceKey] as? String, !nonce.isEmpty else { return .invalid }
        let nowSeconds = Int64(now.timeIntervalSince1970)
        if abs(nowSeconds - ts) > maxSkewSeconds { return .stale }
        return nonces.checkAndRecord(nonce, now: now) ? .validV2 : .replayed
    }

    static func canonicalV2(_ payload: [String: Any]) -> String {
        let keys = payload.keys.filter { $0 != signatureKey }.sorted { compareUtf8($0, $1) }
        let entries = keys.map { key -> String in
            let value = scalar(payload[key])
            return "\(key.utf8.count):\(key)\(value.utf8.count):\(value)"
        }
        return "NWM2\n" + entries.joined(separator: "\n")
    }

    static func signV2Hex(_ payload: [String: Any], secretKey: String) -> String {
        let mac = HMAC<SHA256>.authenticationCode(
            for: Data(canonicalV2(payload).utf8), using: SymmetricKey(data: Data(secretKey.utf8)))
        return mac.map { String(format: "%02x", $0) }.joined()
    }

    private static func hexToData(_ hex: String) -> Data? {
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

    /// Byte-wise (unsigned) UTF-8 order — Swift's String `<` is NOT that.
    private static func compareUtf8(_ a: String, _ b: String) -> Bool {
        a.utf8.lexicographicallyPrecedes(b.utf8)
    }

    private static func isBool(_ n: NSNumber) -> Bool { CFGetTypeID(n) == CFBooleanGetTypeID() }

    private static func number(_ n: NSNumber) -> String {
        if isBool(n) { return n.boolValue ? "true" : "false" }
        let d = n.doubleValue
        // Integral values (including those that arrive as Double) print as integers.
        if d == d.rounded(), abs(d) < 1e15 { return String(Int64(d)) }
        return "\(d)"
    }

    private static func scalar(_ v: Any?) -> String {
        switch v {
        case nil, is NSNull: return "null"
        case let s as String: return s
        case let n as NSNumber: return number(n)
        case let d as [String: Any]: return json(d)
        case let a as [Any]: return json(a)
        default: return "\(v!)"
        }
    }

    private static func json(_ v: Any?) -> String {
        switch v {
        case nil, is NSNull: return "null"
        case let s as String: return quote(s)
        case let n as NSNumber: return number(n)
        case let d as [String: Any]:
            let parts = d.keys.sorted { compareUtf8($0, $1) }.map { quote($0) + ":" + json(d[$0]) }
            return "{" + parts.joined(separator: ",") + "}"
        case let a as [Any]: return "[" + a.map { json($0) }.joined(separator: ",") + "]"
        default: return quote("\(v!)")
        }
    }

    private static func quote(_ s: String) -> String {
        var out = "\""
        for u in s.unicodeScalars {
            switch u {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if u.value < 0x20 { out += String(format: "\\u%04x", u.value) } else { out.unicodeScalars.append(u) }
            }
        }
        return out + "\""
    }

    /// Remembers accepted nonces for twice the skew window; persisted so a replay cannot
    /// simply wait for the app to be killed. Bounded.
    final class NonceStore {
        private static let key = "native_workmanager.remoteTriggerNonces.v1"
        private static let maxEntries = 2000
        private let lock = NSLock()
        private let defaults: UserDefaults?
        private var seen: [String: Double] = [:]
        private var loaded = false

        init(defaults: UserDefaults? = nil) { self.defaults = defaults }

        func checkAndRecord(_ nonce: String, now: Date) -> Bool {
            lock.lock(); defer { lock.unlock() }
            if !loaded {
                loaded = true
                seen = (defaults?.dictionary(forKey: Self.key) as? [String: Double]) ?? [:]
            }
            let nowS = now.timeIntervalSince1970
            let cutoff = nowS - Double(2 * RemoteTriggerSignature.maxSkewSeconds)
            seen = seen.filter { $0.value >= cutoff }
            if seen[nonce] != nil { return false }
            seen[nonce] = nowS
            if seen.count > Self.maxEntries {
                for (k, _) in seen.sorted(by: { $0.value < $1.value }).prefix(seen.count - Self.maxEntries) { seen[k] = nil }
            }
            defaults?.set(seen, forKey: Self.key)
            return true
        }
    }
}
