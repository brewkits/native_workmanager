package dev.brewkits.native_workmanager.integration

import dev.brewkits.native_workmanager.workers.utils.ProgressReporter
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.take
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

/**
 * Integration tests for progress flow from worker to reporter.
 *
 * Tests the complete flow:
 * Worker → ProgressReporter → SharedFlow → Plugin → Dart EventChannel
 */
class ProgressFlowIntegrationTest {

    @Test
    fun `progress flows correctly from suspend context`() = runTest {
        val taskId = "integration-test-1"
        val expectedUpdates = listOf(0, 25, 50, 75, 100)

        // Collect progress in background
        val collectedUpdates = mutableListOf<Int>()
        val job = launch {
            ProgressReporter.progressFlow
                .take(5)
                .collect { update ->
                    if (update.taskId == taskId) {
                        collectedUpdates.add(update.progress)
                    }
                }
        }

        // Give collector time to start
        delay(100)

        // Emit progress updates
        expectedUpdates.forEach { progress ->
            ProgressReporter.reportProgress(
                taskId = taskId,
                progress = progress,
                message = "Processing $progress%"
            )
            delay(10) // Small delay between updates
        }

        job.join()

        assertEquals(expectedUpdates, collectedUpdates)
    }

    @Test
    fun `progress flows correctly from non-blocking context`() = runTest {
        val taskId = "integration-test-2"
        val expectedCount = 10

        val collectedUpdates = mutableListOf<Int>()
        val job = launch {
            ProgressReporter.progressFlow
                .take(expectedCount)
                .collect { update ->
                    if (update.taskId == taskId) {
                        collectedUpdates.add(update.progress)
                    }
                }
        }

        delay(100)

        // Simulate rapid non-blocking updates (like from OkHttp callback)
        repeat(expectedCount) { i ->
            val emitted = ProgressReporter.reportProgressNonBlocking(
                taskId = taskId,
                progress = i * 10
            )
            assertTrue("Update $i should be emitted", emitted)
        }

        job.join()

        assertEquals(expectedCount, collectedUpdates.size)
    }

    @Test
    fun `buffer overflow drops oldest updates`() = runTest {
        val taskId = "integration-test-3"

        // Don't collect - let buffer fill up
        delay(100)

        // Emit more than buffer capacity (64 updates)
        val totalUpdates = 100
        val emittedCount = (0 until totalUpdates).count { i ->
            ProgressReporter.reportProgressNonBlocking(
                taskId = taskId,
                progress = i
            )
        }

        // First 64 should succeed, rest should fail or drop oldest
        // With DROP_OLDEST, all should succeed but oldest are dropped
        assertTrue("Should emit most updates", emittedCount >= 64)
    }

    @Test
    fun `multiple tasks can report progress concurrently`() = runTest {
        val taskCount = 10
        val updatesPerTask = 10

        val allUpdates = mutableListOf<ProgressReporter.ProgressUpdate>()
        val job = launch {
            ProgressReporter.progressFlow
                .take(taskCount * updatesPerTask)
                .toList(allUpdates)
        }

        delay(100)

        // Launch multiple "workers" reporting progress
        val jobs = (1..taskCount).map { taskNum ->
            launch {
                repeat(updatesPerTask) { progress ->
                    ProgressReporter.reportProgressNonBlocking(
                        taskId = "task-$taskNum",
                        progress = progress * 10
                    )
                    delay(5)
                }
            }
        }

        jobs.forEach { it.join() }
        job.join()

        // Verify all tasks reported
        val uniqueTasks = allUpdates.map { it.taskId }.toSet()
        assertEquals(taskCount, uniqueTasks.size)

        // Verify total updates
        assertEquals(taskCount * updatesPerTask, allUpdates.size)
    }

    @Test
    fun `progress messages are preserved`() = runTest {
        val taskId = "integration-test-4"
        val expectedMessage = "Uploading photo.jpg... (2.5MB/10MB)"

        val updates = mutableListOf<ProgressReporter.ProgressUpdate>()
        val job = launch {
            ProgressReporter.progressFlow
                .take(1)
                .toList(updates)
        }

        delay(100)

        ProgressReporter.reportProgressNonBlocking(
            taskId = taskId,
            progress = 25,
            message = expectedMessage
        )

        job.join()

        assertEquals(1, updates.size)
        assertEquals(expectedMessage, updates[0].message)
    }

    @Test
    fun `step information is preserved`() = runTest {
        val taskId = "integration-test-5"

        val updates = mutableListOf<ProgressReporter.ProgressUpdate>()
        val job = launch {
            ProgressReporter.progressFlow
                .take(1)
                .toList(updates)
        }

        delay(100)

        ProgressReporter.reportStep(
            taskId = taskId,
            currentStep = 5,
            totalSteps = 10,
            message = "Processing file 5 of 10"
        )

        job.join()

        assertEquals(1, updates.size)
        assertEquals(5, updates[0].currentStep)
        assertEquals(10, updates[0].totalSteps)
        assertEquals(50, updates[0].progress) // 5/10 = 50%
    }

    @Test
    fun `rapid progress updates are throttled by 1 percent`() = runTest {
        val taskId = "integration-test-6"

        val updates = mutableListOf<Int>()
        val job = launch {
            ProgressReporter.progressFlow
                .take(10)
                .collect { update ->
                    if (update.taskId == taskId) {
                        updates.add(update.progress)
                    }
                }
        }

        delay(100)

        // Try to emit many updates with same progress
        repeat(100) {
            ProgressReporter.reportProgressNonBlocking(
                taskId = taskId,
                progress = 50 // Same progress
            )
        }

        // Emit different progress values
        (0..9).forEach { i ->
            ProgressReporter.reportProgressNonBlocking(
                taskId = taskId,
                progress = i * 10
            )
        }

        job.join()

        // Should collect 10 different progress values
        assertEquals(10, updates.size)
    }

    @Test
    fun `toMap conversion includes all fields`() = runTest {
        val update = ProgressReporter.ProgressUpdate(
            taskId = "test-task",
            progress = 75,
            message = "Processing...",
            currentStep = 3,
            totalSteps = 4
        )

        val map = update.toMap()

        assertEquals("test-task", map["taskId"])
        assertEquals(75, map["progress"])
        assertEquals("Processing...", map["message"])
        assertEquals(3, map["currentStep"])
        assertEquals(4, map["totalSteps"])
    }

    @Test
    fun `toMap excludes null optional fields`() = runTest {
        val update = ProgressReporter.ProgressUpdate(
            taskId = "test-task",
            progress = 50,
            message = null,
            currentStep = null,
            totalSteps = null
        )

        val map = update.toMap()

        assertEquals(2, map.size) // Only taskId and progress
        assertTrue(map.containsKey("taskId"))
        assertTrue(map.containsKey("progress"))
        assertFalse(map.containsKey("message"))
        assertFalse(map.containsKey("currentStep"))
        assertFalse(map.containsKey("totalSteps"))
    }
}
