package dev.brewkits.native_workmanager.concurrency

import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first

/** Process-wide task admission, not a thread-pool limit. Waiting never blocks a thread.
 * Reconfiguration retains active permits; lowering the limit drains existing work first.
 */
internal class TaskConcurrencyLimiter(max: Int = 4) {
    private val lock = Any()
    private var limit = max.also { require(it > 0) }
    private var running = 0
    private val changes = MutableStateFlow(0L)

    fun configure(max: Int) = synchronized(lock) {
        require(max > 0)
        limit = max
        changes.value++
    }

    private suspend fun acquire() {
        while (true) {
            currentCoroutineContext().ensureActive()
            val revision = synchronized(lock) {
                if (running < limit) {
                    running++
                    return
                }
                changes.value
            }
            changes.first { it != revision }
        }
    }

    suspend fun <T> withPermit(block: suspend () -> T): T {
        acquire()
        try {
            currentCoroutineContext().ensureActive()
            return block()
        } finally {
            synchronized(lock) {
                running--
                changes.value++
            }
        }
    }
}
