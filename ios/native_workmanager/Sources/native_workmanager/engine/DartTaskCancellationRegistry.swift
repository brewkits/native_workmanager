import Foundation

/// Tracks which DartWorker task IDs have been cancelled, so a Dart callback
/// running in either Flutter engine (the main isolate, or the headless
/// engine spun up by `FlutterEngineManager`) can ask
/// `NativeWorkManager.isTaskCancelled(taskId)` (issue #66) and get a real
/// answer instead of always `false`.
///
/// Marked from every place that cancels a running task —
/// `NativeWorkmanagerPlugin`'s `cancel`/`cancelAll`/`cancelByTag` handlers,
/// notification-driven cancel, and `BGTaskSchedulerManager`'s expiration
/// handler. Read from the `dev.brewkits/dart_worker_channel` handlers in
/// both `NativeWorkmanagerPlugin` (main isolate) and `FlutterEngineManager`
/// (headless isolate).
///
/// This is **cooperative only**: marking a taskId here does not interrupt
/// whatever the Dart isolate is currently `await`-ing — it only lets a
/// polling callback see the request and return early.
final class DartTaskCancellationRegistry {
    static let shared = DartTaskCancellationRegistry()
    private init() {}

    private let lock = NSLock()
    private var cancelled: Set<String> = []

    /// Record that `taskId` has been cancelled/stopped.
    func markCancelled(_ taskId: String) {
        lock.lock()
        defer { lock.unlock() }
        cancelled.insert(taskId)
    }

    /// Whether `taskId` has been marked cancelled.
    func isCancelled(_ taskId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled.contains(taskId)
    }

    /// Remove `taskId`'s entry once its execution has finished, successfully
    /// or not — otherwise every cancelled taskId leaks in this set forever.
    func clear(_ taskId: String) {
        lock.lock()
        defer { lock.unlock() }
        cancelled.remove(taskId)
    }
}
