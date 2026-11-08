import Foundation

/// Issue #84: one admission limit across plugin instances and execution paths.
/// Reconfiguration preserves active permits. Cancellation removes queued waiters.
actor ConcurrencyLimiter {
    static let preferenceKey = "native_workmanager.maxConcurrentTasks"
    static let defaultLimit = 4

    /// The limit persisted by the last `initialize()`, or the default. This is what a process
    /// started cold by the OS (BGTask, no Dart `initialize()` yet) will use.
    static func persistedLimit(defaults: UserDefaults = .standard) -> Int {
        guard let value = defaults.object(forKey: preferenceKey) as? Int, value > 0 else { return defaultLimit }
        return value
    }

    static let shared = ConcurrencyLimiter(max: persistedLimit())

    private var max: Int
    private var running = 0
    private var waiting: [(UUID, CheckedContinuation<Void, Error>)] = []

    init(max: Int) { self.max = Swift.max(1, max) }

    func configure(max: Int, persist: Bool = false, defaults: UserDefaults = .standard) {
        precondition(max > 0)
        self.max = max
        if persist { defaults.set(max, forKey: Self.preferenceKey) }
        drain()
    }

    func acquire() async throws {
        let id = UUID()
        try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                waiting.append((id, continuation))
                drain()
            }
        }, onCancel: {
            Task { await self.cancelWaiter(id) }
        })
        // A release may grant a slot just before cancellation reaches the actor.
        if Task.isCancelled {
            release()
            throw CancellationError()
        }
    }

    func release() {
        precondition(running > 0)
        running -= 1
        drain()
    }

    private func cancelWaiter(_ id: UUID) {
        guard let index = waiting.firstIndex(where: { $0.0 == id }) else { return }
        waiting.remove(at: index).1.resume(throwing: CancellationError())
    }

    private func drain() {
        while running < max && !waiting.isEmpty {
            running += 1
            waiting.removeFirst().1.resume()
        }
    }
}
