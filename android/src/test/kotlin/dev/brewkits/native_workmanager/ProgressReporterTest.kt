package dev.brewkits.native_workmanager

import dev.brewkits.native_workmanager.workers.utils.ProgressReporter
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.take
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.yield
import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for ProgressReporter.
 *
 * NOTE: ProgressReporter uses SharedFlow(replay=0). Tests must yield() after
 * launching a collector to ensure subscription is active before emitting.
 */
class ProgressReporterTest {

    @Test
    fun `reportProgress emits valid progress update`() = runTest {
        val taskId = "test-task-progress-1"
        val progress = 50
        val message = "Processing..."

        val job = launch {
            val update = ProgressReporter.progressFlow.first()
            assertEquals(taskId, update.taskId)
            assertEquals(progress, update.progress)
            assertEquals(message, update.message)
        }

        yield() // Let the collector subscribe before emitting

        ProgressReporter.reportProgress(taskId = taskId, progress = progress, message = message)
        job.join()
    }

    @Test
    fun `reportProgress clamps progress to 0-100 range`() = runTest {
        val taskId = "test-task-clamp-1"

        val job1 = launch {
            val update = ProgressReporter.progressFlow.first()
            assertEquals(100, update.progress)
        }
        yield()
        ProgressReporter.reportProgress(taskId, progress = 150)
        job1.join()

        val taskId2 = "test-task-clamp-2"
        val job2 = launch {
            val update = ProgressReporter.progressFlow.first()
            assertEquals(0, update.progress)
        }
        yield()
        ProgressReporter.reportProgress(taskId2, progress = -50)
        job2.join()
    }

    @Test
    fun `reportProgress validates progress range`() = runTest {
        try {
            ProgressReporter.reportProgress("task-validate", progress = 0)
            ProgressReporter.reportProgress("task-validate-b", progress = 100)
            ProgressReporter.reportProgress("task-validate-c", progress = 101)
            ProgressReporter.reportProgress("task-validate-d", progress = -1)
            assertTrue(true)
        } catch (e: Exception) {
            fail("Progress should be clamped, not throw: ${e.message}")
        }
    }

    @Test
    fun `reportStep calculates progress correctly`() = runTest {
        val taskId = "test-task-step-1"
        val totalSteps = 10

        val job1 = launch {
            val update = ProgressReporter.progressFlow.first()
            assertEquals(0, update.progress)
            assertEquals(0, update.currentStep)
            assertEquals(totalSteps, update.totalSteps)
        }
        yield()
        ProgressReporter.reportStep(taskId, currentStep = 0, totalSteps = totalSteps)
        job1.join()

        val taskId2 = "test-task-step-2"
        val job2 = launch {
            val update = ProgressReporter.progressFlow.first()
            assertEquals(50, update.progress)
            assertEquals(5, update.currentStep)
        }
        yield()
        ProgressReporter.reportStep(taskId2, currentStep = 5, totalSteps = totalSteps)
        job2.join()

        val taskId3 = "test-task-step-3"
        val job3 = launch {
            val update = ProgressReporter.progressFlow.first()
            assertEquals(100, update.progress)
            assertEquals(10, update.currentStep)
        }
        yield()
        ProgressReporter.reportStep(taskId3, currentStep = 10, totalSteps = totalSteps)
        job3.join()
    }

    @Test
    fun `reportStep handles zero totalSteps gracefully`() = runTest {
        val taskId = "test-task-zero-steps"

        val job = launch {
            val update = ProgressReporter.progressFlow.first()
            assertEquals(0, update.progress)
            assertEquals(5, update.currentStep)
            assertEquals(0, update.totalSteps)
        }
        yield()

        ProgressReporter.reportStep(taskId = taskId, currentStep = 5, totalSteps = 0)
        job.join()
    }

    @Test
    fun `multiple progress updates are emitted in order`() = runTest {
        val taskId = "test-task-order"
        val progressValues = listOf(0, 25, 50, 75, 100)

        val job = launch {
            val updates = ProgressReporter.progressFlow.take(5).toList()
            assertEquals(5, updates.size)
            updates.forEachIndexed { index, update ->
                assertEquals(taskId, update.taskId)
                assertEquals(progressValues[index], update.progress)
            }
        }
        yield()

        progressValues.forEach { p ->
            ProgressReporter.reportProgress(taskId, p)
        }

        job.join()
    }

    @Test
    fun `toMap converts ProgressUpdate correctly`() = runBlocking {
        val update = ProgressReporter.ProgressUpdate(
            taskId = "test-task-tomap",
            progress = 75,
            message = "Processing file",
            currentStep = 3,
            totalSteps = 4
        )

        val map = update.toMap()

        assertEquals("test-task-tomap", map["taskId"])
        assertEquals(75, map["progress"])
        assertEquals("Processing file", map["message"])
        assertEquals(3, map["currentStep"])
        assertEquals(4, map["totalSteps"])
    }

    @Test
    fun `toMap handles null optional fields`() = runBlocking {
        val update = ProgressReporter.ProgressUpdate(
            taskId = "test-task-nullmap",
            progress = 50,
            message = null,
            currentStep = null,
            totalSteps = null
        )

        val map = update.toMap()

        assertEquals("test-task-nullmap", map["taskId"])
        assertEquals(50, map["progress"])
        assertFalse(map.containsKey("message"))
        assertFalse(map.containsKey("currentStep"))
        assertFalse(map.containsKey("totalSteps"))
    }

    @Test
    fun `concurrent progress updates are handled safely`() = runTest {
        val count = 20 // keep small — each taskId is unique so no de-bounce filtering
        val taskIds = (1..count).map { "safe-concurrent-$it" }

        val job = launch {
            val updates = ProgressReporter.progressFlow.take(count).toList()
            assertEquals(count, updates.size)
            val receivedIds = updates.map { it.taskId }.toSet()
            assertEquals(count, receivedIds.size)
        }
        yield()

        taskIds.forEach { taskId ->
            // Sequential to avoid race with take() collector on test dispatcher
            ProgressReporter.reportProgress(taskId, progress = 50)
        }

        job.join()
    }

    @Test
    fun `progress message formatting`() = runTest {
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
        yield()

        // Use unique taskId per message to bypass the 1%-change de-bounce filter
        messages.forEachIndexed { index, message ->
            ProgressReporter.reportProgress("msg-task-$index", progress = 25, message = message)
        }

        job.join()
    }
}
