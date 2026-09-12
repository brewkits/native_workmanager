package dev.brewkits.native_workmanager.engine

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Issue #66: https://github.com/brewkits/native_workmanager/discussions/66
 * Issue #72: https://github.com/brewkits/native_workmanager/issues/72
 *
 * `DartTaskCancellationRegistry` is the Android half of the bridge that lets
 * `NativeWorkManager.isTaskCancelled(taskId)` — called from *inside* a
 * running DartWorker callback — see real cancellation state. Pure Kotlin, no
 * Android framework dependency, so no Robolectric needed here; the
 * native→Dart wiring itself (FlutterEngineManager.executeDartCallback marking
 * this registry on a real CoroutineWorker cancellation) is covered by the
 * `issue_66_*`/`issue_72_*` device integration tests, per the CLAUDE.md rule
 * that a field crossing Dart → native → Dart needs more than a unit test on
 * one side.
 */
class DartTaskCancellationRegistryTest {

    @Test
    fun `unknown executionId is not cancelled`() {
        assertFalse(DartTaskCancellationRegistry.isCancelled("never-seen"))
    }

    @Test
    fun `unknown taskId is not cancelled by taskId`() {
        assertFalse(DartTaskCancellationRegistry.isCancelledByTaskId("never-seen"))
    }

    @Test
    fun `markCancelled makes isCancelled true for that executionId`() {
        val taskId = "t-${System.nanoTime()}"
        val executionId = "e-${System.nanoTime()}"
        assertFalse(DartTaskCancellationRegistry.isCancelled(executionId))

        DartTaskCancellationRegistry.markCancelled(executionId, taskId)

        assertTrue(DartTaskCancellationRegistry.isCancelled(executionId))
        assertTrue(DartTaskCancellationRegistry.isCancelledByTaskId(taskId))
    }

    @Test
    fun `clear removes the entry so isCancelled reverts to false`() {
        val taskId = "t-${System.nanoTime()}"
        val executionId = "e-${System.nanoTime()}"
        DartTaskCancellationRegistry.markCancelled(executionId, taskId)
        assertTrue(DartTaskCancellationRegistry.isCancelled(executionId))

        DartTaskCancellationRegistry.clear(executionId)

        assertFalse(DartTaskCancellationRegistry.isCancelled(executionId))
        assertFalse(DartTaskCancellationRegistry.isCancelledByTaskId(taskId))
    }

    @Test
    fun `clear on an entry that was never marked is a no-op, not a crash`() {
        val executionId = "e-${System.nanoTime()}"
        DartTaskCancellationRegistry.clear(executionId) // must not throw
        assertFalse(DartTaskCancellationRegistry.isCancelled(executionId))
    }

    @Test
    fun `executionIds are tracked independently`() {
        val taskId = "task-${System.nanoTime()}"
        val a = "exec-a-${System.nanoTime()}"
        val b = "exec-b-${System.nanoTime()}"

        DartTaskCancellationRegistry.markCancelled(a, taskId)

        assertTrue(DartTaskCancellationRegistry.isCancelled(a))
        assertFalse(DartTaskCancellationRegistry.isCancelled(b))
    }

    /**
     * Issue #72: the exact collision Rikoshu described in discussion #66.
     * `ExistingWorkPolicy.REPLACE` cancels the running WorkRequest for a
     * taskId and immediately starts a new one under the SAME taskId — two
     * executions, one taskId. Marking/clearing one execution must never be
     * observable through the other execution's own executionId.
     */
    @Test
    fun `issue_72 two executions of the same taskId do not clobber each other`() {
        val taskId = "shared-task-${System.nanoTime()}"
        val oldExecutionId = "old-exec-${System.nanoTime()}"
        val newExecutionId = "new-exec-${System.nanoTime()}"

        // Old (REPLACE'd) execution gets cancelled and marks itself.
        DartTaskCancellationRegistry.markCancelled(oldExecutionId, taskId)

        // New (legitimate replacement) execution starts and polls before the
        // old one's orphaned callback has finished (and thus before the old
        // entry is cleared) — it must NOT see the old execution's mark.
        assertFalse(
            "the new execution must not inherit the old execution's cancel mark",
            DartTaskCancellationRegistry.isCancelled(newExecutionId)
        )
        assertTrue(
            "the old execution's own mark must still be precisely observable",
            DartTaskCancellationRegistry.isCancelled(oldExecutionId)
        )

        // New execution finishes and clears itself — must not touch the old
        // execution's still-live mark (direction 1: the old zombie must
        // still be observably cancelled after this).
        DartTaskCancellationRegistry.clear(newExecutionId)
        assertTrue(
            "clearing the new execution must not clobber the old execution's mark",
            DartTaskCancellationRegistry.isCancelled(oldExecutionId)
        )

        // Old execution's orphaned callback finally finishes and clears
        // itself — must not affect a hypothetically still-running new one
        // (simulated here by re-marking newExecutionId and checking it survives).
        DartTaskCancellationRegistry.markCancelled(newExecutionId, taskId)
        DartTaskCancellationRegistry.clear(oldExecutionId)
        assertTrue(
            "clearing the old execution must not clobber the new execution's mark",
            DartTaskCancellationRegistry.isCancelled(newExecutionId)
        )

        DartTaskCancellationRegistry.clear(newExecutionId)
    }

    @Test
    fun `concurrent markCancelled from many threads is observed for every executionId`() {
        // FlutterEngineManager.executeDartCallback marks this registry from a
        // coroutine that may run on a different thread than whatever is
        // polling isTaskCancelled() via the MethodChannel handler — this must
        // hold up under real concurrency, not just single-threaded calls.
        val executionIds = (0 until 200).map { "concurrent-$it-${System.nanoTime()}" }
        val taskId = "concurrent-task-${System.nanoTime()}"
        val pool = Executors.newFixedThreadPool(16)
        val latch = CountDownLatch(executionIds.size)

        executionIds.forEach { executionId ->
            pool.execute {
                DartTaskCancellationRegistry.markCancelled(executionId, taskId)
                latch.countDown()
            }
        }

        assertTrue("threads did not finish in time", latch.await(5, TimeUnit.SECONDS))
        pool.shutdown()

        executionIds.forEach { executionId ->
            assertTrue(
                "expected '$executionId' to be marked cancelled",
                DartTaskCancellationRegistry.isCancelled(executionId)
            )
        }

        // Cleanup so this test doesn't leak entries into other tests in the suite.
        executionIds.forEach { DartTaskCancellationRegistry.clear(it) }
    }
}
