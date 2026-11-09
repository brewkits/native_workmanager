package dev.brewkits.native_workmanager.engine

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

/**
 * Issue #95: an engine-startup timeout used to surface as TimeoutCancellationException — a
 * CancellationException — which every layer above rethrows on purpose, so WorkManager saw a
 * cancelled run (isStopped=false, stopReason=NOT_STOPPED) instead of a failure it could retry.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class EngineStartupTimeoutTest {

    @Test
    fun issue_95_startup_timeout_is_a_failure_not_a_cancellation() = runTest {
        val never = CompletableDeferred<Unit>()
        val result = async {
            runCatching { FlutterEngineManager.awaitDartReady(never, timeoutMs = 10_000L) }
        }
        advanceTimeBy(10_001L)
        runCurrent()
        val error = result.await().exceptionOrNull()
        assertTrue("expected a startup timeout, got $error", error is DartEngineStartupTimeoutException)
        assertFalse("must not be a CancellationException", error is CancellationException)
        assertTrue(error!!.message!!.contains("10000ms"))
    }

    @Test
    fun issue_95_ready_signal_before_timeout_returns_normally() = runTest {
        val ready = CompletableDeferred<Unit>()
        val result = async { FlutterEngineManager.awaitDartReady(ready, timeoutMs = 10_000L) }
        advanceTimeBy(5_000L)
        ready.complete(Unit)
        result.await()
    }

    @Test
    fun issue_95_real_cancellation_still_propagates_as_cancellation() = runTest {
        val never = CompletableDeferred<Unit>()
        val result = async {
            runCatching { FlutterEngineManager.awaitDartReady(never, timeoutMs = 10_000L) }
        }
        runCurrent()
        result.cancel()
        // The waiting coroutine was cancelled from outside: it must NOT be converted into a
        // startup-timeout failure.
        val outcome = runCatching { result.await() }.exceptionOrNull()
        assertTrue("expected cancellation, got $outcome", outcome is CancellationException)
    }
}
