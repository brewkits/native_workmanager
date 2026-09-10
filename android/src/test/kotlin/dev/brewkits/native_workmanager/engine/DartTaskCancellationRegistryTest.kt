package dev.brewkits.native_workmanager.engine

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Issue #66: https://github.com/brewkits/native_workmanager/discussions/66
 *
 * `DartTaskCancellationRegistry` is the Android half of the bridge that lets
 * `NativeWorkManager.isTaskCancelled(taskId)` — called from *inside* a
 * running DartWorker callback — see real cancellation state. Pure Kotlin, no
 * Android framework dependency, so no Robolectric needed here; the
 * native→Dart wiring itself (FlutterEngineManager.executeDartCallback marking
 * this registry on a real CoroutineWorker cancellation) is covered by the
 * `issue_66_*` device integration test, per the CLAUDE.md rule that a field
 * crossing Dart → native → Dart needs more than a unit test on one side.
 */
class DartTaskCancellationRegistryTest {

    @Test
    fun `unknown taskId is not cancelled`() {
        assertFalse(DartTaskCancellationRegistry.isCancelled("never-seen"))
    }

    @Test
    fun `markCancelled makes isCancelled true`() {
        val taskId = "t-${System.nanoTime()}"
        assertFalse(DartTaskCancellationRegistry.isCancelled(taskId))

        DartTaskCancellationRegistry.markCancelled(taskId)

        assertTrue(DartTaskCancellationRegistry.isCancelled(taskId))
    }

    @Test
    fun `clear removes the entry so isCancelled reverts to false`() {
        val taskId = "t-${System.nanoTime()}"
        DartTaskCancellationRegistry.markCancelled(taskId)
        assertTrue(DartTaskCancellationRegistry.isCancelled(taskId))

        DartTaskCancellationRegistry.clear(taskId)

        assertFalse(DartTaskCancellationRegistry.isCancelled(taskId))
    }

    @Test
    fun `clear on an entry that was never marked is a no-op, not a crash`() {
        val taskId = "t-${System.nanoTime()}"
        DartTaskCancellationRegistry.clear(taskId) // must not throw
        assertFalse(DartTaskCancellationRegistry.isCancelled(taskId))
    }

    @Test
    fun `taskIds are tracked independently`() {
        val a = "task-a-${System.nanoTime()}"
        val b = "task-b-${System.nanoTime()}"

        DartTaskCancellationRegistry.markCancelled(a)

        assertTrue(DartTaskCancellationRegistry.isCancelled(a))
        assertFalse(DartTaskCancellationRegistry.isCancelled(b))
    }

    @Test
    fun `concurrent markCancelled from many threads is observed for every taskId`() {
        // FlutterEngineManager.executeDartCallback marks this registry from a
        // coroutine that may run on a different thread than whatever is
        // polling isTaskCancelled() via the MethodChannel handler — this must
        // hold up under real concurrency, not just single-threaded calls.
        val taskIds = (0 until 200).map { "concurrent-$it-${System.nanoTime()}" }
        val pool = Executors.newFixedThreadPool(16)
        val latch = CountDownLatch(taskIds.size)

        taskIds.forEach { taskId ->
            pool.execute {
                DartTaskCancellationRegistry.markCancelled(taskId)
                latch.countDown()
            }
        }

        assertTrue("threads did not finish in time", latch.await(5, TimeUnit.SECONDS))
        pool.shutdown()

        taskIds.forEach { taskId ->
            assertTrue(
                "expected '$taskId' to be marked cancelled",
                DartTaskCancellationRegistry.isCancelled(taskId)
            )
        }

        // Cleanup so this test doesn't leak entries into other tests in the suite.
        taskIds.forEach { DartTaskCancellationRegistry.clear(it) }
    }
}
