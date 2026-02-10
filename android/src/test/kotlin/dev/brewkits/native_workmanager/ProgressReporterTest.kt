package dev.brewkits.native_workmanager

import dev.brewkits.native_workmanager.workers.utils.ProgressReporter
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.take
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for ProgressReporter.
 *
 * Tests:
 * - Progress reporting with valid values
 * - Progress clamping (0-100)
 * - Message formatting
 * - Step-based progress calculation
 * - Flow emission and collection
 * - Thread safety
 */
class ProgressReporterTest {

    @Test
    fun `reportProgress emits valid progress update`() = runTest {
        val taskId = "test-task-1"
        val progress = 50
        val message = "Processing..."

        // Collect first emission
        val job = launch {
            val update = ProgressReporter.progressFlow.first()

            assertEquals(taskId, update.taskId)
            assertEquals(progress, update.progress)
            assertEquals(message, update.message)
        }

        // Emit progress
        ProgressReporter.reportProgress(
            taskId = taskId,
            progress = progress,
            message = message
        )

        job.join()
    }

    @Test
    fun `reportProgress clamps progress to 0-100 range`() = runTest {
        val taskId = "test-task-2"

        // Test over 100
        val job1 = launch {
            val update = ProgressReporter.progressFlow.first()
            assertEquals(100, update.progress)
        }
        ProgressReporter.reportProgress(taskId, progress = 150)
        job1.join()

        // Test under 0
        val job2 = launch {
            val update = ProgressReporter.progressFlow.first()
            assertEquals(0, update.progress)
        }
        ProgressReporter.reportProgress(taskId, progress = -50)
        job2.join()
    }

    @Test
    fun `reportProgress validates progress range`() = runTest {
        try {
            // This should work (boundary)
            ProgressReporter.reportProgress("task", progress = 0)
            ProgressReporter.reportProgress("task", progress = 100)

            // This should clamp but not throw
            ProgressReporter.reportProgress("task", progress = 101)
            ProgressReporter.reportProgress("task", progress = -1)

            // If we get here, clamping worked
            assertTrue(true)
        } catch (e: Exception) {
            fail("Progress should be clamped, not throw: ${e.message}")
        }
    }

    @Test
    fun `reportStep calculates progress correctly`() = runTest {
        val taskId = "test-task-3"
        val totalSteps = 10

        // Test 0%
        val job1 = launch {
            val update = ProgressReporter.progressFlow.first()
            assertEquals(0, update.progress)
            assertEquals(0, update.currentStep)
            assertEquals(totalSteps, update.totalSteps)
        }
        ProgressReporter.reportStep(taskId, currentStep = 0, totalSteps = totalSteps)
        job1.join()

        // Test 50%
        val job2 = launch {
            val update = ProgressReporter.progressFlow.first()
            assertEquals(50, update.progress)
            assertEquals(5, update.currentStep)
        }
        ProgressReporter.reportStep(taskId, currentStep = 5, totalSteps = totalSteps)
        job2.join()

        // Test 100%
        val job3 = launch {
            val update = ProgressReporter.progressFlow.first()
            assertEquals(100, update.progress)
            assertEquals(10, update.currentStep)
        }
        ProgressReporter.reportStep(taskId, currentStep = 10, totalSteps = totalSteps)
        job3.join()
    }

    @Test
    fun `reportStep handles zero totalSteps gracefully`() = runTest {
        val taskId = "test-task-4"

        val job = launch {
            val update = ProgressReporter.progressFlow.first()
            assertEquals(0, update.progress) // Should default to 0
            assertEquals(5, update.currentStep)
            assertEquals(0, update.totalSteps)
        }

        ProgressReporter.reportStep(
            taskId = taskId,
            currentStep = 5,
            totalSteps = 0 // Invalid but should handle gracefully
        )

        job.join()
    }

    @Test
    fun `multiple progress updates are emitted in order`() = runTest {
        val taskId = "test-task-5"
        val progressValues = listOf(0, 25, 50, 75, 100)

        val job = launch {
            val updates = ProgressReporter.progressFlow.take(5).toList()

            assertEquals(5, updates.size)
            updates.forEachIndexed { index, update ->
                assertEquals(taskId, update.taskId)
                assertEquals(progressValues[index], update.progress)
            }
        }

        // Emit multiple progress updates
        progressValues.forEach { progress ->
            ProgressReporter.reportProgress(taskId, progress)
        }

        job.join()
    }

    @Test
    fun `toMap converts ProgressUpdate correctly`() = runBlocking {
        val update = ProgressReporter.ProgressUpdate(
            taskId = "test-task-6",
            progress = 75,
            message = "Processing file",
            currentStep = 3,
            totalSteps = 4
        )

        val map = update.toMap()

        assertEquals("test-task-6", map["taskId"])
        assertEquals(75, map["progress"])
        assertEquals("Processing file", map["message"])
        assertEquals(3, map["currentStep"])
        assertEquals(4, map["totalSteps"])
    }

    @Test
    fun `toMap handles null optional fields`() = runBlocking {
        val update = ProgressReporter.ProgressUpdate(
            taskId = "test-task-7",
            progress = 50,
            message = null,
            currentStep = null,
            totalSteps = null
        )

        val map = update.toMap()

        assertEquals("test-task-7", map["taskId"])
        assertEquals(50, map["progress"])
        assertFalse(map.containsKey("message"))
        assertFalse(map.containsKey("currentStep"))
        assertFalse(map.containsKey("totalSteps"))
    }

    @Test
    fun `concurrent progress updates are handled safely`() = runTest {
        val taskIds = (1..100).map { "task-$it" }
        val expectedUpdates = 100

        val job = launch {
            val updates = ProgressReporter.progressFlow.take(expectedUpdates).toList()
            assertEquals(expectedUpdates, updates.size)

            // All task IDs should be present
            val receivedIds = updates.map { it.taskId }.toSet()
            assertEquals(expectedUpdates, receivedIds.size)
        }

        // Emit from multiple "concurrent" coroutines
        taskIds.forEach { taskId ->
            launch {
                ProgressReporter.reportProgress(taskId, progress = 50)
            }
        }

        job.join()
    }

    @Test
    fun `progress message formatting`() = runTest {
        val taskId = "test-task-8"
        val messages = listOf(
            "Starting...",
            "Processing file 1 of 10",
            "Uploading... (2.5MB/10MB)",
            "Complete"
        )

        val job = launch {
            val updates = ProgressReporter.progressFlow.take(messages.size).toList()

            updates.forEachIndexed { index, update ->
                assertEquals(messages[index], update.message)
            }
        }

        messages.forEach { message ->
            ProgressReporter.reportProgress(taskId, progress = 25, message = message)
        }

        job.join()
    }
}
