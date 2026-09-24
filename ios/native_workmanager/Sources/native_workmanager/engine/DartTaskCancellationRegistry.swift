import Foundation

/// Tracks which DartWorker **executions** have been cancelled, so a Dart
/// callback running in either Flutter engine (the main isolate, or the
/// headless engine spun up by `FlutterEngineManager`) can ask
/// `NativeWorkManager.isTaskCancelled(taskId)` (issue #66) and get a real
/// answer instead of always `false`.
///
/// Keyed by **executionId**, not by the app-level `taskId` (issue #72,
/// ported from Android's `DartTaskCancellationRegistry.kt`). A single
/// `taskId` can have more than one execution alive at once: `handleEnqueue`'s
/// `existingPolicy: .replace` (the `enqueue()` default) now cancels the
/// outgoing execution and immediately starts a new one under the SAME
/// `taskId`. A bare `taskId`-keyed mark/clear cannot tell those two
/// executions apart — confirmed on a simulator (2026-09-23 lib/ audit):
/// without this, the new execution's own `clear` wiped the mark meant for the
/// outgoing one, and the outgoing one ran to full completion never having
/// noticed it should stop.
///
/// Marked from every place that cancels a running task —
/// `NativeWorkmanagerPlugin`'s `cancel`/`cancelAll`/`cancelByTag` handlers,
/// notification-driven cancel, `BGTaskSchedulerManager`'s expiration handler,
/// and `handleEnqueue`'s replace path — via the taskId-only `markCancelled`,
/// which resolves to whichever executionId is currently live for that taskId
/// (none of those call sites know a specific executionId; only
/// `executeDartWorkerViaMethodChannel`, which mints one per invocation, does).
/// Read from the `dev.brewkits/dart_worker_channel` handlers in both
/// `NativeWorkmanagerPlugin` (main isolate) and `FlutterEngineManager`
/// (headless isolate).
///
/// This is **cooperative only**: marking an execution here does not
/// interrupt whatever the Dart isolate is currently `await`-ing — it only
/// lets a polling callback see the request and return early.
final class DartTaskCancellationRegistry {
    static let shared = DartTaskCancellationRegistry()
    private init() {}

    private let lock = NSLock()

    /// executionId -> taskId. The value is only needed for the coarse
    /// taskId-only `isCancelled` fallback (callers with no executionId).
    private var cancelled: [String: String] = [:]

    /// taskId -> the executionId of whichever execution is currently "the"
    /// live one for that taskId. This is what a bare `markCancelled(taskId)`
    /// call (from every call site except `executeDartWorkerViaMethodChannel`
    /// itself, none of which know a specific executionId) actually targets.
    private var currentExecutionId: [String: String] = [:]

    /// Issue #75: per-task stop notifiers, keyed by taskId (not per-execution
    /// — a known, deliberately out-of-scope simplification; see the 2026-09-23
    /// lib/ audit notes. Two overlapping executions of one taskId could still
    /// clobber each other's notifier registration, same as before this file's
    /// issue #72 rework).
    ///
    /// Registered by whichever execution path is actually running the callback
    /// (main channel vs headless engine), because only that path knows which
    /// channel to notify on. Hanging this off the registry means every existing
    /// `markCancelled` call site — explicit cancel, cancelByTag, cancelAll,
    /// notification-driven cancel, BGTask expiration, replace — fires the
    /// notification for free, instead of each having to remember to.
    private var stopNotifiers: [String: (Int64?) -> Void] = [:]

    // MARK: - Per-execution lifecycle (issue #72)

    /// Record that `executionId` is now the live execution for `taskId`.
    ///
    /// Called from one of two places: (1) `executeDartWorkerViaMethodChannel`,
    /// right after minting an executionId for a fresh invocation it wasn't
    /// handed one for (chains, TaskGraph, BGTaskScheduler's periodic path,
    /// the offline queue), or (2) `replaceActiveTask` (2026-09-24), which
    /// mints and registers it synchronously — in the SAME barrier block that
    /// decides to replace whatever's currently running — for its two callers
    /// (`handleEnqueue`'s direct path, `handleResume`), so a
    /// `markCancelled(taskId)` racing in immediately after has something
    /// current to resolve to instead of a stale outgoing execution's id.
    /// Either way, this must run before the Dart callback starts polling.
    func beginExecution(_ executionId: String, taskId: String) {
        lock.lock()
        defer { lock.unlock() }
        currentExecutionId[taskId] = executionId
    }

    /// Drop `executionId`'s tracking once it has finished, successfully or
    /// not — otherwise every cancelled execution leaks in `cancelled` forever.
    ///
    /// Only clears `currentExecutionId[taskId]` (and `taskId`'s stop
    /// notifier) if it still points at THIS executionId. Without that guard,
    /// a slow-finishing outgoing execution's cleanup could run AFTER a
    /// replacing execution has already begun and wipe the newer execution's
    /// tracking and notifier out from under it.
    func endExecution(_ executionId: String, taskId: String) {
        lock.lock()
        cancelled.removeValue(forKey: executionId)
        if currentExecutionId[taskId] == executionId {
            currentExecutionId.removeValue(forKey: taskId)
            stopNotifiers.removeValue(forKey: taskId)
        }
        lock.unlock()
    }

    // MARK: - Stop notifiers (issue #75)

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

    // MARK: - Marking / reading cancellation

    /// Mark `taskId`'s CURRENT execution cancelled/stopped. Used by every
    /// cancellation source that only knows a taskId — `cancel`/`cancelAll`/
    /// `cancelByTag`, notification-driven cancel, and BGTask expiration.
    ///
    /// Issue #75: also fires that task's stop notifier, exactly once — the
    /// notifier is removed as it is taken, so sweeping the same taskId twice
    /// (e.g. an explicit cancel racing a BGTask expiration) cannot notify the
    /// Dart handler twice.
    func markCancelled(_ taskId: String) {
        lock.lock()
        let executionId = currentExecutionId[taskId] ?? taskId
        cancelled[executionId] = taskId
        let notifier = stopNotifiers.removeValue(forKey: taskId)
        lock.unlock()

        // Called outside the lock on purpose: the notifier hops to the main
        // queue and awaits a Dart round-trip, and holding an NSLock across that
        // would deadlock anything else touching the registry meanwhile —
        // including the isTaskCancelled() poll this whole feature exists to serve.
        notifier?(nil)
    }

    /// Whether the execution identified by `executionId` is cancelled.
    /// Precise — use this whenever an executionId is available (from
    /// `isTaskCancelled`'s Zone-bound `executionId` argument).
    func isCancelled(executionId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled[executionId] != nil
    }

    /// Coarse: whether `taskId`'s CURRENT execution is cancelled. Fallback
    /// for callers with no executionId in scope. Do not use this when an
    /// executionId is available — it cannot distinguish a replaced
    /// generation of the same taskId from its replacement.
    func isCancelled(_ taskId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let executionId = currentExecutionId[taskId] ?? taskId
        return cancelled[executionId] != nil
    }
}
