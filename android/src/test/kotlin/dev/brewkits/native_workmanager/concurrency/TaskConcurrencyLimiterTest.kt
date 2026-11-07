package dev.brewkits.native_workmanager.concurrency

import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class TaskConcurrencyLimiterTest {
    @Test fun issue_84_limits_suspended_workers_not_just_threads() = runTest {
        for (limit in listOf(1, 2, 4)) {
            val limiter = TaskConcurrencyLimiter(limit)
            var running = 0
            var peak = 0
            val jobs = (1..20).map {
                launch {
                    limiter.withPermit {
                        running++
                        peak = maxOf(peak, running)
                        delay(100)
                        running--
                    }
                }
            }
            jobs.joinAll()
            assertEquals(limit, peak)
            assertEquals(0, running)
        }
    }

    @Test fun issue_84_cancellation_and_failure_return_permits() = runTest {
        val limiter = TaskConcurrencyLimiter(1)
        val holder = launch { limiter.withPermit { awaitCancellation() } }
        runCurrent()
        var cancelledWaiterRan = false
        val waiter = launch { limiter.withPermit { cancelledWaiterRan = true } }
        runCurrent()
        waiter.cancelAndJoin()
        holder.cancelAndJoin()
        assertFalse(cancelledWaiterRan)
        try {
            limiter.withPermit { throw IllegalStateException("worker failure") }
        } catch (_: IllegalStateException) { }
        assertEquals(42, limiter.withPermit { 42 })
    }

    @Test fun issue_84_resize_preserves_active_permits_and_wakes_waiters() = runTest {
        val limiter = TaskConcurrencyLimiter(2)
        val a = launch { limiter.withPermit { awaitCancellation() } }
        val b = launch { limiter.withPermit { awaitCancellation() } }
        runCurrent()
        limiter.configure(1)
        var admitted = false
        val c = launch { limiter.withPermit { admitted = true; awaitCancellation() } }
        runCurrent()
        a.cancelAndJoin()
        runCurrent()
        assertFalse(admitted)
        b.cancelAndJoin()
        runCurrent()
        assertTrue(admitted)
        var secondAdmitted = false
        val d = launch { limiter.withPermit { secondAdmitted = true } }
        runCurrent()
        assertFalse(secondAdmitted)
        limiter.configure(2)
        d.join()
        assertTrue(secondAdmitted)
        c.cancelAndJoin()
    }
}
