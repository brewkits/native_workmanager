import Foundation

/// Centralised logger for NativeWorkManager.
///
/// All diagnostic output is gated behind `enabled`. The flag is set to `true`
/// when the host app calls `initialize(debugMode: true)` **and** the build is
/// a debug build (checked via `#if DEBUG`).
struct NativeLogger {

    // MARK: - State

    /// Controlled by `NativeWorkmanagerPlugin.handleInitialize` via `debugMode`.
    static var enabled: Bool = false

    private static let prefix = "[NativeWorkManager]"

    // MARK: - API

    /// Debug log — silenced in production.
    static func d(_ message: String) {
        #if targetEnvironment(simulator)
        print("\(prefix) \(message)")
        #else
        guard enabled else { return }
        print("\(prefix) \(message)")
        #endif
    }

    /// Warning log — silenced in production.
    static func w(_ message: String) {
        #if targetEnvironment(simulator)
        print("\(prefix) ⚠️ \(message)")
        #else
        guard enabled else { return }
        print("\(prefix) ⚠️ \(message)")
        #endif
    }

    /// Error log — always emitted.
    ///
    /// Uses `NSLog` (not `print`) so it appears in the crash reporter stream.
    /// Do NOT include user-identifiable data (task IDs, file paths) in `message`.
    static func e(_ message: String) {
        NSLog("%@ ERROR: %@", prefix, message)
    }

    /// Logs a URL after redacting sensitive query parameters.
    /// FIX #05: Prevents sensitive tokens from leaking via Console.
    static func url(_ prefixStr: String, _ urlStr: String) {
        #if !targetEnvironment(simulator)
        guard enabled else { return }
        #endif
        
        guard var components = URLComponents(string: urlStr) else {
            d("\(prefixStr) [REDACTED URL]")
            return
        }
        
        let sensitiveKeys = ["token", "key", "auth", "secret", "apikey", "access_token"]
        if let queryItems = components.queryItems {
            components.queryItems = queryItems.map { item in
                if sensitiveKeys.contains(where: { item.name.lowercased().contains($0) }) {
                    return URLQueryItem(name: item.name, value: "[REDACTED]")
                }
                return item
            }
        }
        
        let sanitized = components.url?.absoluteString ?? "[REDACTED URL]"
        d("\(prefixStr) \(sanitized)")
    }
}
