import Foundation

/// Token-bucket bandwidth throttle for async byte streams.
///
/// Limits throughput to [maxBytesPerSecond] using a simple token-bucket algorithm.
/// Tokens refill continuously at the configured rate; reads block when the bucket
/// is empty and sleep for at most 100 ms per call to avoid starving the async runtime.
///
/// **Usage (iOS 15+):**
/// ```swift
/// let throttle = BandwidthThrottle(maxBytesPerSecond: 100_000) // 100 KB/s
/// for try await chunk in session.bytes(for: request).0 {
///     await throttle.consume(chunk.count)
///     fileHandle.write(Data(chunk))
/// }
/// ```
///
/// Thread-safety: implemented as a Swift `actor` — safe to call from concurrent tasks.
@available(iOS 15.0, *)
actor BandwidthThrottle {

    private let maxBytesPerSecond: Int64
    /// Current token balance (fractional bytes allowed).
    private var tokens: Double
    /// Monotonic timestamp of the last refill in nanoseconds.
    private var lastRefillNs: UInt64

    init(maxBytesPerSecond: Int64) {
        self.maxBytesPerSecond = maxBytesPerSecond
        self.tokens = Double(maxBytesPerSecond) // start bucket full
        self.lastRefillNs = DispatchTime.now().uptimeNanoseconds
    }

    /// Consume [count] tokens, sleeping until enough tokens are available.
    func consume(_ count: Int) async {
        guard count > 0 else { return }
        refill()
        let needed = Double(count) - tokens
        if needed > 0 {
            // Wait until we can satisfy the request.
            let waitSecs = needed / Double(maxBytesPerSecond)
            // Cap sleep between 1 ms and 100 ms to keep the loop responsive.
            let waitNs = UInt64(min(max(waitSecs * 1_000_000_000, 1_000_000), 100_000_000))
            try? await Task.sleep(nanoseconds: waitNs)
            refill()
        }
        tokens = max(0, tokens - Double(count))
    }

    // MARK: - Private

    private func refill() {
        let now = DispatchTime.now().uptimeNanoseconds
        let elapsedSecs = Double(now &- lastRefillNs) / 1_000_000_000.0
        let newTokens = elapsedSecs * Double(maxBytesPerSecond)
        // Cap at one second's worth (limits burst).
        tokens = min(tokens + newTokens, Double(maxBytesPerSecond))
        lastRefillNs = now
    }
}
