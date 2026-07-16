package dev.brewkits.native_workmanager.utils

/**
 * Pure retry-ceiling math for workers that map [androidx.work.ListenableWorker.Result]
 * themselves instead of delegating to `kmpworkmanager`'s `BaseKmpWorker` (which already
 * enforces the ceiling). Currently only [dev.brewkits.native_workmanager.workers.ForegroundNativeWorker]
 * needs this — it bypasses `BaseKmpWorker`, so the same `N + 1` total-runs cap is applied here.
 *
 * `maxRetries = N` means at most `N + 1` runs (1 initial + N retries). `runAttemptCount` is
 * WorkManager's 0-based attempt index. `maxRetries < 0` means uncapped (retry forever).
 */
object RetryCeiling {

    /**
     * Whether a `Failure(shouldRetry=true)` should stop retrying. Exhausted once the 0-based
     * [runAttemptCount] reaches [maxRetries] (so N retries occupy attempts 0..N).
     */
    fun failureExhausted(runAttemptCount: Int, maxRetries: Int): Boolean =
        maxRetries in 0..runAttemptCount

    /**
     * Whether a `Retry` result should stop retrying. An explicit [attemptCap] (total runs) wins;
     * otherwise [maxRetries] provides a cap of `maxRetries + 1` total runs. Uncapped when both are
     * absent (`attemptCap == null` and `maxRetries < 0`).
     */
    fun retryExhausted(runAttemptCount: Int, attemptCap: Int?, maxRetries: Int): Boolean {
        val cap = attemptCap ?: if (maxRetries >= 0) maxRetries + 1 else null
        return cap != null && runAttemptCount + 1 >= cap
    }
}
