package dev.brewkits.native_workmanager.concurrency

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.work.Data
import androidx.work.ForegroundUpdater
import androidx.work.WorkerParameters
import com.google.common.util.concurrent.SettableFuture
import dev.brewkits.kmpworkmanager.background.domain.*
import dev.brewkits.native_workmanager.NativeLogger
import dev.brewkits.native_workmanager.SimpleAndroidWorkerFactory
import dev.brewkits.native_workmanager.workers.ForegroundNativeWorker
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLog
import java.util.UUID
import kotlin.coroutines.EmptyCoroutineContext

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
@OptIn(ExperimentalCoroutinesApi::class)
class ForegroundAdmissionTest {
    private lateinit var context: Context
    private val events = mutableListOf<String>()

    @Before fun setup() {
        context = ApplicationProvider.getApplicationContext()
        TaskConcurrency.configure(context, 1)
        SimpleAndroidWorkerFactory.registerWorker("issue95") {
            object : AndroidWorker {
                override suspend fun doWork(input: String?, env: WorkerEnvironment): WorkerResult {
                    events += "callback:$input"
                    delay(100)
                    events += "complete:$input"
                    return WorkerResult.Success()
                }
            }
        }
    }

    @After fun cleanup() {
        SimpleAndroidWorkerFactory.unregisterWorker("issue95")
        TaskConcurrency.configure(context, 4)
    }

    private fun worker(name: String, promotion: SettableFuture<Void>? = null): ForegroundNativeWorker {
        val data = Data.Builder()
            .putString("workerClassName", "issue95").putString("taskId", name)
            .putString("inputJson", name)
            .putString("fgsConfigJson", "{\"showCancelButton\":false}").build()
        val updater = ForegroundUpdater { _, _, _ ->
            events += "promote:$name"
            promotion ?: SettableFuture.create<Void>().also { it.set(null) }
        }
        val params = WorkerParameters(
            UUID.randomUUID(), data, emptyList(), WorkerParameters.RuntimeExtras(),
            0, 0, java.util.concurrent.Executor { it.run() }, EmptyCoroutineContext,
            mock(androidx.work.impl.utils.taskexecutor.TaskExecutor::class.java),
            object : androidx.work.WorkerFactory() {
                override fun createWorker(context: Context, name: String, params: WorkerParameters):
                    androidx.work.ListenableWorker? = null
            },
            androidx.work.ProgressUpdater { _, _, _ -> SettableFuture.create<Void>().also { it.set(null) } },
            updater
        )
        return ForegroundNativeWorker(context, params)
    }

    @Test fun promotion_and_callbacks_share_one_permit() = runTest {
        val jobs = listOf(launch { worker("first").doWork() }, launch { worker("second").doWork() })
        runCurrent()
        assertEquals(listOf("promote:first", "callback:first"), events)
        jobs.joinAll()
        assertEquals(listOf("promote:first", "callback:first", "complete:first",
            "promote:second", "callback:second", "complete:second"), events)
    }

    @Test fun background_work_delays_foreground_promotion() = runTest {
        val background = SimpleAndroidWorkerFactory(context).createWorker("issue95")!!
        val first = launch { background.doWork("background", WorkerEnvironment()) }
        val foreground = launch { worker("foreground").doWork() }
        runCurrent()
        assertEquals(listOf("callback:background"), events)
        joinAll(first, foreground)
        assertEquals(listOf("callback:background", "complete:background",
            "promote:foreground", "callback:foreground", "complete:foreground"), events)
    }

    @Test fun rejected_promotion_preserves_background_fallback_and_releases_permit() = runTest {
        val rejected = SettableFuture.create<Void>().also {
            it.setException(IllegalStateException("Foreground start rejected"))
        }
        worker("first", rejected).doWork()
        worker("next").doWork()
        assertEquals(listOf("promote:first", "callback:first", "complete:first",
            "promote:next", "callback:next", "complete:next"), events)
    }

    @Test fun cancelled_waiter_never_promotes_and_active_cancellation_releases_permit() = runTest {
        val first = launch { worker("first").doWork() }
        val waiting = launch { worker("waiting").doWork() }
        runCurrent()
        waiting.cancelAndJoin()
        first.cancelAndJoin()
        worker("next").doWork()
        assertEquals(listOf("promote:first", "callback:first", "promote:next",
            "callback:next", "complete:next"), events)
        assertTrue(first.isCancelled)
        assertTrue(waiting.isCancelled)
    }

    @Test fun stopped_work_logs_reason_and_phase_and_propagates_cancellation() = runTest {
        val wasEnabled = NativeLogger.enabled
        NativeLogger.enabled = true
        try {
            val pending = SettableFuture.create<Void>()
            val stopped = worker("stopped", pending)
            val job = launch { stopped.doWork() }
            runCurrent()
            stopped.stop(7)
            job.cancelAndJoin()
            assertTrue(job.isCancelled)
            val log = ShadowLog.getLogs().map { it.msg }.first {
                it.contains("cancelled taskId=stopped")
            }
            assertTrue(log.contains("phase=foreground-promotion"))
            assertTrue(log.contains("isStopped=true stopReason=7"))
            assertEquals(listOf("promote:stopped"), events)
        } finally {
            NativeLogger.enabled = wasEnabled
        }
    }

    @Test fun cancellation_during_promotion_releases_permit_without_starting_callback() = runTest {
        val pending = SettableFuture.create<Void>()
        val first = launch { worker("first", pending).doWork() }
        runCurrent()
        first.cancelAndJoin()
        worker("next").doWork()
        assertEquals(listOf("promote:first", "promote:next", "callback:next", "complete:next"), events)
        assertTrue(first.isCancelled)
    }
}
