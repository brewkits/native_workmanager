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

    /// Issue #75: per-task stop notifiers, keyed by taskId.
    ///
    /// Registered by whichever execution path is actually running the callback
    /// (main channel vs headless engine), because only that path knows which
    /// channel to notify on. Hanging this off the registry means every existing
    /// `markCancelled` call site — explicit cancel, cancelByTag, cancelAll,
    /// notification-driven cancel, BGTask expiration — fires the notification
    /// for free, instead of seven sites each having to remember to.
    private var stopNotifiers: [String: (Int64?) -> Void] = [:]

    /// Register the stop notifier for a running DartWorker execution (issue #75).
    ///
    /// `cancelGraceMs` is handed to the notifier rather than stored here: the
    /// Dart API owns that value and the registry has no business defaulting it.
    func registerStopNotifier(
        _ taskId: String,
        cancelGraceMs: Int64?,
        notifier: @escaping (Int64?) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }
        stopNotifiers[taskId] = { _ in notifier(cancelGraceMs) }
    }

    /// Drop a task's stop notifier once its execution has finished (issue #75).
    func clearStopNotifier(_ taskId: String) {
        lock.lock()
        defer { lock.unlock() }
        stopNotifiers.removeValue(forKey: taskId)
    }

    /// Record that `taskId` has been cancelled/stopped.
    ///
    /// Issue #75: also fires that task's stop notifier, exactly once — the
    /// notifier is removed as it is taken, so a `cancelAll` that sweeps the same
    /// taskId twice, or an explicit cancel racing a BGTask expiration, cannot
    /// notify the Dart handler twice.
    func markCancelled(_ taskId: String) {
        lock.lock()
        cancelled.insert(taskId)
        let notifier = stopNotifiers.removeValue(forKey: taskId)
        lock.unlock()

        // Called outside the lock on purpose: the notifier hops to the main
        // queue and awaits a Dart round-trip, and holding an NSLock across that
        // would deadlock anything else touching the registry meanwhile —
        // including the isTaskCancelled() poll this whole feature exists to serve.
        notifier?(nil)
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
        stopNotifiers.removeValue(forKey: taskId)
    }
}
