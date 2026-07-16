package dev.brewkits.native_workmanager.utils

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * issue_46: retry-ceiling math for ForegroundNativeWorker (which maps Result itself and so
 * cannot rely on kmpworkmanager BaseKmpWorker's cap). maxRetries=N → at most N+1 total runs.
 */
class RetryCeilingTest {

    // ── failureExhausted: N retries occupy attempts 0..N ──

    @Test
    fun `failure not exhausted before the cap`() {
        // maxRetries=2 → runs at attempt 0, 1, 2 allowed to retry until 2 reached
        assertFalse(RetryCeiling.failureExhausted(runAttemptCount = 0, maxRetries = 2))
        assertFalse(RetryCeiling.failureExhausted(runAttemptCount = 1, maxRetries = 2))
    }

    @Test
    fun `failure exhausted once runAttemptCount reaches maxRetries`() {
        assertTrue(RetryCeiling.failureExhausted(runAttemptCount = 2, maxRetries = 2))
        assertTrue(RetryCeiling.failureExhausted(runAttemptCount = 3, maxRetries = 2))
    }

    @Test
    fun `failure maxRetries zero never retries`() {
        assertTrue(RetryCeiling.failureExhausted(runAttemptCount = 0, maxRetries = 0))
    }

    @Test
    fun `failure negative maxRetries is uncapped`() {
        assertFalse(RetryCeiling.failureExhausted(runAttemptCount = 0, maxRetries = -1))
        assertFalse(RetryCeiling.failureExhausted(runAttemptCount = 99, maxRetries = -1))
    }

    // ── retryExhausted: explicit attemptCap (total runs) wins over maxRetries ──

    @Test
    fun `retry uses maxRetries plus one as the total-run cap`() {
        // maxRetries=2 → cap of 3 total runs: attempts 0,1 retry; attempt 2 is the last run
        assertFalse(RetryCeiling.retryExhausted(runAttemptCount = 0, attemptCap = null, maxRetries = 2))
        assertFalse(RetryCeiling.retryExhausted(runAttemptCount = 1, attemptCap = null, maxRetries = 2))
        assertTrue(RetryCeiling.retryExhausted(runAttemptCount = 2, attemptCap = null, maxRetries = 2))
    }

    @Test
    fun `retry explicit attemptCap overrides maxRetries`() {
        // attemptCap=5 total runs regardless of maxRetries=1
        assertFalse(RetryCeiling.retryExhausted(runAttemptCount = 3, attemptCap = 5, maxRetries = 1))
        assertTrue(RetryCeiling.retryExhausted(runAttemptCount = 4, attemptCap = 5, maxRetries = 1))
    }

    @Test
    fun `retry uncapped when no attemptCap and negative maxRetries`() {
        assertFalse(RetryCeiling.retryExhausted(runAttemptCount = 100, attemptCap = null, maxRetries = -1))
    }
}
