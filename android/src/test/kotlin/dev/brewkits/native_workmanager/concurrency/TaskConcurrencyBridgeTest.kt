package dev.brewkits.native_workmanager.concurrency

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import dev.brewkits.native_workmanager.*
import dev.brewkits.kmpworkmanager.background.domain.*
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
@OptIn(ExperimentalCoroutinesApi::class)
class TaskConcurrencyBridgeTest {
    @Test fun issue_84_initialize_configures_all_factory_instances_and_persists_limit() = runTest {
        val context = ApplicationProvider.getApplicationContext<Context>()
        NativeWorkManagerInitializer().create(context)
        val plugin = NativeWorkmanagerPlugin().also { it.context = context }
        val result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.handleInitialize(MethodCall("initialize", mapOf(
            "maxConcurrentTasks" to 1, "cleanupAfterDays" to 0
        )), result)
        Mockito.verify(result).success(null)
        assertEquals(1, context.getSharedPreferences(NativeWorkmanagerPlugin.SHARED_PREFS_NAME, 0)
            .getInt("max_concurrent_tasks", -1))

        var running = 0
        var peak = 0
        var completed = 0
        SimpleAndroidWorkerFactory.registerWorker("issue84") {
            object : AndroidWorker {
                override suspend fun doWork(input: String?, env: WorkerEnvironment): WorkerResult {
                    running++
                    peak = maxOf(peak, running)
                    delay(100)
                    running--
                    completed++
                    return WorkerResult.Success()
                }
            }
        }
        try {
            (1..8).map {
                // New factories must share, rather than reset, the admission pool.
                val worker = SimpleAndroidWorkerFactory(context).createWorker("issue84")!!
                launch { worker.doWork(null, WorkerEnvironment()) }
            }.joinAll()
            assertEquals(8, completed)
            assertEquals(1, peak)
        } finally {
            SimpleAndroidWorkerFactory.unregisterWorker("issue84")
            TaskConcurrency.configure(context, 4)
        }
    }
}
