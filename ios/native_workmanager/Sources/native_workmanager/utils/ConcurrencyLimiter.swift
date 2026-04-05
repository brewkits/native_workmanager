import Foundation

/// Limits the number of concurrently-executing async worker tasks.
///
/// When many tasks are enqueued at once, running them all in parallel can
/// saturate the device's network connection and starve foreground HTTP
/// requests. `ConcurrencyLimiter` caps simultaneous execution to `max`
/// slots; excess tasks are queued internally and started as slots free up.
///
/// Configured via `NativeWorkManager.initialize(maxConcurrentTasks:)`.
/// Default is **4** — enough for good throughput while leaving bandwidth
/// for foreground traffic.
///
/// Usage:
/// ```swift
/// let limiter = ConcurrencyLimiter(max: 4)
///
/// // At the start of executeWorkerSync:
/// await limiter.acquire()
///
/// // After the worker finishes (all exit paths):
/// await limiter.release()
/// ```
actor ConcurrencyLimiter {

    // MARK: - State

    private let max: Int
    private var running: Int = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    // MARK: - Init

    init(max: Int) {
        self.max = Swift.max(1, max) // guard against 0 or negative
    }

    // MARK: - API

    /// Suspend the caller until a concurrency slot is available, then claim it.
    func acquire() async {
        if running < max {
            running += 1
            return
        }
        // No slot free — park the caller until release() wakes us.
        await withCheckedContinuation { continuation in
            waiting.append(continuation)
        }
    }

    /// Release the caller's slot. Wakes the next queued task, if any.
    func release() {
        if let next = waiting.first {
            waiting.removeFirst()
            // The resumed task inherits the slot — do not decrement running.
            next.resume()
        } else {
            running -= 1
        }
    }
}
