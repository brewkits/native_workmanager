package dev.brewkits.native_workmanager.concurrency

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive

/** Process-wide task admission, not a thread-pool limit. Waiting never blocks a thread.
 * Waiters are admitted strictly FIFO (a newcomer never barges past parked waiters).
 * Reconfiguration retains active permits; lowering the limit drains existing work first.
 */
internal class TaskConcurrencyLimiter(max: Int = 4) {
    private val lock = Any()
    private var limit = max.also { require(it > 0) }
    private var running = 0
    private val waiters = ArrayDeque<CompletableDeferred<Unit>>()

    fun configure(max: Int) = synchronized(lock) {
        require(max > 0)
        limit = max
        grantLocked()
    }

    // Caller must hold [lock]. Every grant counts the permit before waking the waiter.
    private fun grantLocked() {
        while (running < limit && waiters.isNotEmpty()) {
            running++
            waiters.removeFirst().complete(Unit)
        }
    }

    private fun release() = synchronized(lock) {
        running--
        grantLocked()
    }

    private suspend fun acquire() {
        currentCoroutineContext().ensureActive()
        val waiter = synchronized(lock) {
            if (waiters.isEmpty() && running < limit) {
                running++
                return
            }
            CompletableDeferred<Unit>().also { waiters.addLast(it) }
        }
        try {
            waiter.await()
        } catch (e: CancellationException) {
            // Still queued: just leave. Already granted (permit counted, but we are being
            // cancelled before running): hand the slot back so it is not leaked.
            val stillQueued = synchronized(lock) { waiters.remove(waiter) }
            if (!stillQueued) release()
            throw e
        }
    }

    suspend fun <T> withPermit(block: suspend () -> T): T {
        acquire()
        try {
            currentCoroutineContext().ensureActive()
            return block()
        } finally {
            release()
        }
    }
}
