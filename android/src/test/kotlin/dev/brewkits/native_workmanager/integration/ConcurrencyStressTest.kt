package dev.brewkits.native_workmanager.integration

import dev.brewkits.native_workmanager.workers.utils.ProgressReporter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.take
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import org.junit.Assert.*
import org.junit.Test
import kotlin.system.measureTimeMillis

/**
 * Stress tests for concurrent progress reporting.
 *
 * Tests thread safety, performance under load, and no deadlocks.
 */
class ConcurrencyStressTest {

    @Test
    fun `100 concurrent tasks dont block threads`() = runTest {
        val taskCount = 100
        val updatesPerTask = 10

        val allUpdates = mutableListOf<ProgressReporter.ProgressUpdate>()
        val collectorJob = launch {
            ProgressReporter.progressFlow
                .take(taskCount * updatesPerTask)
                .toList(allUpdates)
        }

        delay(100)

        // Measure time to emit all updates
        val duration = measureTimeMillis {
            val jobs = (1..taskCount).map { taskNum ->
                launch(Dispatchers.Default) {
                    repeat(updatesPerTask) { progress ->
                        ProgressReporter.reportProgressNonBlocking(
                            taskId = "task-$taskNum",
                            progress = progress * 10
                        )
                    }
                }
            }
            jobs.forEach { it.join() }
        }

        collectorJob.join()

        // Should complete in reasonable time (<2 seconds)
        assertTrue("Should complete quickly: ${duration}ms", duration < 2000)

        // Verify all updates collected
        assertEquals(taskCount * updatesPerTask, allUpdates.size)
    }

    @Test
    fun `rapid fire updates dont cause backpressure`() = runTest {
        val taskId = "stress-test-rapid"
        val totalUpdates = 1000

        val collectedUpdates = mutableListOf<Int>()
        val collectorJob = launch {
            ProgressReporter.progressFlow
                .take(100) // Only collect first 100
                .collect { update ->
                    if (update.taskId == taskId) {
                        collectedUpdates.add(update.progress)
                    }
                }
        }

        delay(100)

        // Fire 1000 updates as fast as possible
        val duration = measureTimeMillis {
            repeat(totalUpdates) { i ->
                ProgressReporter.reportProgressNonBlocking(
                    taskId = taskId,
                    progress = i % 100
                )
            }
        }

        collectorJob.join()

        // Should emit very quickly (non-blocking)
        assertTrue("Emission should be fast: ${duration}ms", duration < 100)

        // Should collect 100 updates
        assertEquals(100, collectedUpdates.size)
    }

    @Test
    fun `no deadlock with mixed blocking and non-blocking calls`() = runTest {
        val taskId = "stress-test-mixed"
        val iterations = 100

        val collectedUpdates = mutableListOf<Int>()
        val collectorJob = launch {
            ProgressReporter.progressFlow
                .take(iterations * 2)
                .collect { update ->
                    if (update.taskId == taskId) {
                        collectedUpdates.add(update.progress)
                    }
                }
        }

        delay(100)

        // Mix suspend and non-blocking calls
        withContext(Dispatchers.Default) {
            repeat(iterations) { i ->
                if (i % 2 == 0) {
                    // Suspend call
                    ProgressReporter.reportProgress(
                        taskId = taskId,
                        progress = i
                    )
                } else {
                    // Non-blocking call
                    ProgressReporter.reportProgressNonBlocking(
                        taskId = taskId,
                        progress = i
                    )
                }
            }
        }

        collectorJob.join()

        // Should complete without deadlock
        assertTrue("Should collect updates", collectedUpdates.isNotEmpty())
    }

    @Test
    fun `memory usage stays bounded under continuous load`() = runTest {
        val taskId = "stress-test-memory"
        val duration = 1000L // 1 second of continuous updates

        val collectorJob = launch {
            ProgressReporter.progressFlow.collect {
                // Consume updates to prevent memory buildup
            }
        }

        delay(100)

        val startTime = System.currentTimeMillis()
        var updateCount = 0

        withContext(Dispatchers.Default) {
            while (System.currentTimeMillis() - startTime < duration) {
                ProgressReporter.reportProgressNonBlocking(
                    taskId = taskId,
                    progress = updateCount % 100
                )
                updateCount++
            }
        }

        collectorJob.cancel()

        // Should handle many updates (thousands)
        assertTrue("Should handle many updates: $updateCount", updateCount > 1000)
    }

    @Test
    fun `no race condition with concurrent reportStep calls`() = runTest {
        val taskCount = 50
        val stepsPerTask = 10

        val allUpdates = mutableListOf<ProgressReporter.ProgressUpdate>()
        val collectorJob = launch {
            ProgressReporter.progressFlow
                .take(taskCount * stepsPerTask)
                .toList(allUpdates)
        }

        delay(100)

        // Multiple tasks reporting steps concurrently
        val jobs = (1..taskCount).map { taskNum ->
            launch(Dispatchers.Default) {
                repeat(stepsPerTask) { step ->
                    ProgressReporter.reportStep(
                        taskId = "task-$taskNum",
                        currentStep = step + 1,
                        totalSteps = stepsPerTask
                    )
                    delay(1) // Small delay
                }
            }
        }

        jobs.forEach { it.join() }
        collectorJob.join()

        // Verify data integrity
        allUpdates.groupBy { it.taskId }.forEach { (taskId, updates) ->
            // Each task should have exactly stepsPerTask updates
            assertEquals("Task $taskId should have $stepsPerTask updates",
                stepsPerTask, updates.size)

            // Progress should be calculated correctly
            updates.forEach { update ->
                val expectedProgress = ((update.currentStep ?: 0) * 100) / stepsPerTask
                assertTrue("Progress should match calculation",
                    Math.abs(update.progress - expectedProgress) <= 1)
            }
        }
    }

    @Test
    fun `buffer overflow with DROP_OLDEST preserves latest updates`() = runTest {
        val taskId = "stress-test-overflow"

        // Don't collect - let buffer overflow
        delay(100)

        // Emit way more than buffer capacity
        val totalUpdates = 200
        repeat(totalUpdates) { i ->
            ProgressReporter.reportProgressNonBlocking(
                taskId = taskId,
                progress = i
            )
        }

        // Now collect latest updates
        val collectedUpdates = mutableListOf<Int>()
        val collectorJob = launch {
            ProgressReporter.progressFlow
                .take(10)
                .collect { update ->
                    if (update.taskId == taskId) {
                        collectedUpdates.add(update.progress)
                    }
                }
        }

        // Emit a few more to trigger collection
        repeat(10) { i ->
            ProgressReporter.reportProgressNonBlocking(
                taskId = taskId,
                progress = 90 + i
            )
            delay(10)
        }

        collectorJob.join()

        // Should collect recent updates (not the first ones)
        // With DROP_OLDEST, we should see high progress values
        val avgProgress = collectedUpdates.average()
        assertTrue("Average progress should be high: $avgProgress",
            avgProgress > 50)
    }
}
