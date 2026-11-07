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

    // Waiters must be admitted in arrival order, even when the limit is raised or a
    // newcomer arrives while others are parked (no barging / starvation).
    @Test fun issue_84_waiters_are_admitted_fifo() = runTest {
        val limiter = TaskConcurrencyLimiter(1)
        val holder = launch { limiter.withPermit { awaitCancellation() } }
        runCurrent()
        val order = mutableListOf<Int>()
        val waiters = (1..6).map { id ->
            launch { limiter.withPermit { order += id; delay(10) } }.also { runCurrent() }
        }
        // A newcomer arriving after a release must not jump the queue.
        holder.cancelAndJoin()
        val newcomer = launch { limiter.withPermit { order += 99 } }
        runCurrent()
        (waiters + newcomer).joinAll()
        assertEquals(listOf(1, 2, 3, 4, 5, 6, 99), order)
    }

    // A waiter that was granted a slot and cancelled before running must hand it back.
    @Test fun issue_84_granted_then_cancelled_waiter_releases_slot() = runTest {
        val limiter = TaskConcurrencyLimiter(1)
        val holder = launch { limiter.withPermit { awaitCancellation() } }
        runCurrent()
        val doomed = launch { limiter.withPermit { fail("must not run") } }
        runCurrent()
        // Grant and cancel in the same dispatcher turn.
        holder.cancel()
        doomed.cancel()
        runCurrent()
        joinAll(holder, doomed)
        assertEquals(7, withTimeout(1_000) { limiter.withPermit { 7 } })
    }
}
