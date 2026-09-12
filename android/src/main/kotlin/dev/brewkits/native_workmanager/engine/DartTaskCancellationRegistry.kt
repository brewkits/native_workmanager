package dev.brewkits.native_workmanager.engine

import java.util.concurrent.ConcurrentHashMap

/**
 * Tracks which DartWorker *executions* have been cancelled, so a Dart
 * callback running in the headless [FlutterEngineManager] engine can ask
 * `NativeWorkManager.isTaskCancelled(taskId)` (issue #66) and get a real
 * answer instead of always `false`.
 *
 * Keyed by **executionId**, not by the app-level `taskId` (issue #72). A
 * single `taskId` can have more than one execution alive at once — most
 * notably `ExistingWorkPolicy.REPLACE` cancels the running WorkRequest for
 * a unique work name and immediately starts a new one under the *same*
 * `taskId`. A bare `Set<String>` keyed on `taskId` cannot tell those two
 * executions apart: the outgoing (should-stay-cancelled) instance and the
 * incoming (legitimate, not cancelled) instance would read and clear each
 * other's mark. `executionId` is minted fresh per `doWork()` invocation
 * (see `DartCallbackWorker`), so REPLACE generations never collide.
 *
 * Marked from [FlutterEngineManager.executeDartCallback] the moment the
 * coroutine backing `doWork()` observes external cancellation (WorkManager
 * stopping the worker). This is **cooperative only**: marking an execution
 * here does not interrupt whatever the Dart isolate is currently
 * `await`-ing — it only lets a polling callback see the request and return
 * early.
 */
object DartTaskCancellationRegistry {

    // executionId -> taskId. The value is only needed for isCancelledByTaskId's
    // coarse fallback lookup (callers with no executionId in scope).
    private val cancelled: MutableMap<String, String> = ConcurrentHashMap()

    /** Record that the execution identified by [executionId] (of [taskId]) has been cancelled/stopped. */
    fun markCancelled(executionId: String, taskId: String) {
        cancelled[executionId] = taskId
    }

    /** Whether the specific execution [executionId] has been marked cancelled. Precise — use this whenever an executionId is available. */
    fun isCancelled(executionId: String): Boolean = cancelled.containsKey(executionId)

    /**
     * Whether ANY currently-marked execution belongs to [taskId]. Coarse
     * fallback for callers that have no executionId in scope (e.g. a
     * DartWorker callback invoked outside the callback-dispatcher's Zone).
     * Do not use this when an executionId is available — it cannot
     * distinguish REPLACE generations of the same taskId.
     */
    fun isCancelledByTaskId(taskId: String): Boolean = cancelled.containsValue(taskId)

    /**
     * Remove [executionId]'s entry once its execution has finished,
     * successfully or not — otherwise every cancelled execution leaks in
     * this map forever. Keyed by executionId only, so clearing one
     * execution's entry can never clobber a different execution (past or
     * future) of the same taskId.
     */
    fun clear(executionId: String) {
        cancelled.remove(executionId)
    }
}
