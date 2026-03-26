package dev.brewkits.native_workmanager.workers.utils

import kotlinx.coroutines.sync.Semaphore
import java.util.concurrent.ConcurrentHashMap

/**
 * Limits the number of concurrent HTTP downloads per host.
 *
 * When multiple HttpDownloadWorker tasks target the same host, they compete for a
 * per-host [Semaphore] so that no more than [maxConcurrentPerHost] downloads run
 * simultaneously against any single host. This prevents overwhelming a server and
 * avoids saturating the available bandwidth on metered connections.
 *
 * Usage:
 * ```kotlin
 * HostConcurrencyManager.withHostPermit("example.com") { downloadLogic() }
 * ```
 *
 * Note: Because [Semaphore] instances are created lazily and stored in a
 * [ConcurrentHashMap], changing [maxConcurrentPerHost] after the first download
 * has started does **not** resize already-created semaphores. New hosts will use
 * the updated value; existing hosts keep their original limit until the process
 * restarts. This is acceptable for typical plugin usage.
 */
object HostConcurrencyManager {
    private const val DEFAULT_MAX_PER_HOST = 2
    private val semaphores = ConcurrentHashMap<String, Semaphore>()

    var maxConcurrentPerHost: Int = DEFAULT_MAX_PER_HOST

    fun semaphoreFor(host: String): Semaphore =
        semaphores.getOrPut(host) { Semaphore(maxConcurrentPerHost) }

    suspend fun <T> withHostPermit(host: String, block: suspend () -> T): T {
        val sem = semaphoreFor(host)
        sem.acquire()
        try {
            return block()
        } finally {
            sem.release()
        }
    }
}
