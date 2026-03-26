import Foundation

/// Per-host concurrency manager.
///
/// Limits the number of simultaneous downloads from the same host to avoid
/// saturating a single server or triggering rate limiting.
///
/// Uses `DispatchSemaphore` for broad iOS compatibility (iOS 12+).
/// The `maxPerHost` limit can be updated at any time via `updateMax(_:)`.
///
/// Usage:
/// ```swift
/// HostConcurrencyManager.shared.acquire(host: host)
/// defer { HostConcurrencyManager.shared.release(host: host) }
/// // ... perform download ...
/// ```
final class HostConcurrencyManager {

    static let shared = HostConcurrencyManager()

    // Protected by `lock`
    private var maxPerHost: Int = 2
    private var semaphores: [String: DispatchSemaphore] = [:]
    private let lock = NSLock()

    private init() {}

    // MARK: - Configuration

    /// Update the maximum concurrent downloads per host.
    /// Existing semaphores created with the old limit are NOT replaced (in-flight
    /// downloads continue unaffected); the new limit applies to semaphores created
    /// for hosts not yet seen.
    func updateMax(_ n: Int) {
        lock.lock()
        defer { lock.unlock() }
        maxPerHost = max(1, n)
    }

    // MARK: - Acquire / Release

    /// Block the calling thread until a permit for `host` is available.
    /// Call `release(host:)` when the download finishes.
    ///
    /// This is a **blocking** call — invoke it from a background queue/Task only,
    /// never from the main thread.
    func acquire(host: String) {
        let sem = semaphore(for: host)
        sem.wait()
    }

    /// Release a previously acquired permit for `host`.
    func release(host: String) {
        let sem = semaphore(for: host)
        sem.signal()
    }

    // MARK: - Private

    private func semaphore(for host: String) -> DispatchSemaphore {
        lock.lock()
        defer { lock.unlock() }
        if let existing = semaphores[host] { return existing }
        let sem = DispatchSemaphore(value: maxPerHost)
        semaphores[host] = sem
        return sem
    }
}
