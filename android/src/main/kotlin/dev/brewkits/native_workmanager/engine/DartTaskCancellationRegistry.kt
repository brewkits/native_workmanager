package dev.brewkits.native_workmanager.engine

import java.util.concurrent.ConcurrentHashMap

/**
 * Tracks which DartWorker task IDs have been cancelled, so a Dart callback
 * running in the headless [FlutterEngineManager] engine can ask
 * `NativeWorkManager.isTaskCancelled(taskId)` (issue #66) and get a real
 * answer instead of always `false`.
 *
 * Marked from [FlutterEngineManager.executeDartCallback] the moment the
 * coroutine backing `doWork()` observes external cancellation (WorkManager
 * stopping the worker). This is **cooperative only**: marking a taskId here
 * does not interrupt whatever the Dart isolate is currently `await`-ing —
 * it only lets a polling callback see the request and return early.
 */
object DartTaskCancellationRegistry {

    private val cancelled: MutableSet<String> = ConcurrentHashMap.newKeySet()

    /** Record that [taskId] has been cancelled/stopped. */
    fun markCancelled(taskId: String) {
        cancelled.add(taskId)
    }

    /** Whether [taskId] has been marked cancelled. */
    fun isCancelled(taskId: String): Boolean = cancelled.contains(taskId)

    /**
     * Remove [taskId]'s entry once its execution has finished, successfully
     * or not — otherwise every cancelled taskId leaks in this set forever.
     */
    fun clear(taskId: String) {
        cancelled.remove(taskId)
    }
}
