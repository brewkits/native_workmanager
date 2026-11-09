package dev.brewkits.native_workmanager.concurrency

import android.content.Context
import dev.brewkits.native_workmanager.NativeWorkmanagerPlugin
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.WorkerEnvironment
import dev.brewkits.kmpworkmanager.background.domain.WorkerResult

internal object TaskConcurrency {
    private const val KEY = "max_concurrent_tasks"
    val limiter = TaskConcurrencyLimiter()
    private var restored = false

    // Every plugin factory calls this, including manual Configuration.Provider setups.
    @Synchronized fun restore(context: Context) {
        if (restored) return
        val prefs = context.getSharedPreferences(NativeWorkmanagerPlugin.SHARED_PREFS_NAME, Context.MODE_PRIVATE)
        limiter.configure(prefs.getInt(KEY, 4).coerceAtLeast(1))
        restored = true
    }

    @Synchronized fun configure(context: Context, max: Int) {
        require(max > 0) { "maxConcurrentTasks must be greater than zero" }
        context.getSharedPreferences(NativeWorkmanagerPlugin.SHARED_PREFS_NAME, Context.MODE_PRIVATE)
            .edit().putInt(KEY, max).apply()
        limiter.configure(max)
        restored = true
    }
}

internal class ConcurrencyLimitedWorker(
    private val delegate: AndroidWorker,
    private val onAdmitted: suspend () -> Unit = {}
) : AndroidWorker {
    override suspend fun doWork(input: String?, env: WorkerEnvironment): WorkerResult =
        TaskConcurrency.limiter.withPermit {
            onAdmitted()
            delegate.doWork(input, env)
        }
}
