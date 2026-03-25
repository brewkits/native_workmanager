import Foundation

/// Centralised logger for NativeWorkManager.
///
/// All diagnostic output is gated behind `enabled`. The flag is set to `true`
/// when the host app calls `initialize(debugMode: true)` **and** the build is
/// a debug build (checked via `#if DEBUG`).
///
/// In production `enabled` stays `false`, preventing task metadata such as
/// task IDs, URLs, and file paths from appearing in the system log or
/// Console.app — a requirement for apps that handle sensitive user operations.
///
/// Error-level messages are always emitted because they represent unexpected
/// failures that engineers need to diagnose. Do NOT include user-identifiable
/// data (task IDs, file paths, URLs) in error message strings.
struct NativeLogger {

    // MARK: - State

    /// Controlled by `NativeWorkmanagerPlugin.handleInitialize` via `debugMode`.
    static var enabled: Bool = false

    private static let prefix = "[NativeWorkManager]"

    // MARK: - API

    /// Debug log — silenced in production.
    static func d(_ message: String) {
        guard enabled else { return }
        print("\(prefix) \(message)")
    }

    /// Warning log — silenced in production.
    static func w(_ message: String) {
        guard enabled else { return }
        print("\(prefix) ⚠️ \(message)")
    }

    /// Error log — always emitted.
    ///
    /// Uses `NSLog` (not `print`) so it appears in the crash reporter stream.
    /// Do NOT include user-identifiable data (task IDs, file paths) in `message`.
    static func e(_ message: String) {
        NSLog("%@ ERROR: %@", prefix, message)
    }
}
