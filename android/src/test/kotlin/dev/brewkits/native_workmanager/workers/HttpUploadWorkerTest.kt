package dev.brewkits.native_workmanager.workers

import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Before
import org.junit.Test
import java.io.File
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Unit tests for HttpUploadWorker.
 *
 * These tests verify:
 * - Successful file uploads
 * - Custom fileName parameter override
 * - Custom mimeType parameter override
 * - Additional form fields
 * - Custom headers
 * - Error handling (missing file, invalid config)
 */
class HttpUploadWorkerTest {

    private lateinit var mockWebServer: MockWebServer
    private lateinit var worker: HttpUploadWorker
    private lateinit var testFile: File

    @Before
    fun setup() {
        mockWebServer = MockWebServer()
        mockWebServer.start()
        worker = HttpUploadWorker()

        // Create a temporary test file
        testFile = File.createTempFile("test_upload", ".txt")
        testFile.writeText("Test file content for upload")
    }

    @After
    fun tearDown() {
        mockWebServer.shutdown()
        testFile.delete()
    }

    @Test
    fun `test basic file upload`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(200).setBody("Upload successful"))

        val config = """
            {
                "url": "${mockWebServer.url("/upload")}",
                "filePath": "${testFile.absolutePath}"
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertTrue(result, "Upload should succeed")

        val recordedRequest = mockWebServer.takeRequest()
        assertEquals("POST", recordedRequest.method)
        assertTrue(recordedRequest.body.readUtf8().contains("test_upload"))
    }

    @Test
    fun `test upload with custom fileName`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(200).setBody("Upload successful"))

        val config = """
            {
                "url": "${mockWebServer.url("/upload")}",
                "filePath": "${testFile.absolutePath}",
                "fileName": "custom_name.txt"
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertTrue(result, "Upload with custom fileName should succeed")

        val recordedRequest = mockWebServer.takeRequest()
        val requestBody = recordedRequest.body.readUtf8()
        assertTrue(requestBody.contains("custom_name.txt"), "Request should contain custom file name")
        assertFalse(requestBody.contains("test_upload"), "Request should NOT contain original file name")
    }

    @Test
    fun `test upload with custom mimeType`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(200).setBody("Upload successful"))

        val config = """
            {
                "url": "${mockWebServer.url("/upload")}",
                "filePath": "${testFile.absolutePath}",
                "mimeType": "application/custom"
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertTrue(result, "Upload with custom mimeType should succeed")

        val recordedRequest = mockWebServer.takeRequest()
        val contentType = recordedRequest.getHeader("Content-Type")
        assertTrue(contentType!!.contains("multipart/form-data"), "Should use multipart/form-data")
    }

    @Test
    fun `test upload with custom fileName and mimeType`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(201).setBody("Created"))

        val config = """
            {
                "url": "${mockWebServer.url("/upload")}",
                "filePath": "${testFile.absolutePath}",
                "fileName": "profile.jpg",
                "mimeType": "image/heic"
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertTrue(result, "Upload with custom fileName and mimeType should succeed")

        val recordedRequest = mockWebServer.takeRequest()
        val requestBody = recordedRequest.body.readUtf8()
        assertTrue(requestBody.contains("profile.jpg"), "Request should contain custom file name")
    }

    @Test
    fun `test upload with additional fields`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(200).setBody("Upload successful"))

        val config = """
            {
                "url": "${mockWebServer.url("/upload")}",
                "filePath": "${testFile.absolutePath}",
                "additionalFields": {
                    "userId": "12345",
                    "description": "Test upload"
                }
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertTrue(result, "Upload with additional fields should succeed")

        val recordedRequest = mockWebServer.takeRequest()
        val requestBody = recordedRequest.body.readUtf8()
        assertTrue(requestBody.contains("userId"), "Request should contain userId field")
        assertTrue(requestBody.contains("12345"), "Request should contain userId value")
        assertTrue(requestBody.contains("description"), "Request should contain description field")
    }

    @Test
    fun `test upload with custom headers`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(200).setBody("Upload successful"))

        val config = """
            {
                "url": "${mockWebServer.url("/upload")}",
                "filePath": "${testFile.absolutePath}",
                "headers": {
                    "Authorization": "Bearer token123",
                    "X-Custom-Header": "custom-value"
                }
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertTrue(result, "Upload with custom headers should succeed")

        val recordedRequest = mockWebServer.takeRequest()
        assertEquals("Bearer token123", recordedRequest.getHeader("Authorization"))
        assertEquals("custom-value", recordedRequest.getHeader("X-Custom-Header"))
    }

    @Test
    fun `test upload with custom fileFieldName`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(200).setBody("Upload successful"))

        val config = """
            {
                "url": "${mockWebServer.url("/upload")}",
                "filePath": "${testFile.absolutePath}",
                "fileFieldName": "avatar"
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertTrue(result, "Upload with custom fileFieldName should succeed")

        val recordedRequest = mockWebServer.takeRequest()
        val requestBody = recordedRequest.body.readUtf8()
        assertTrue(requestBody.contains("name=\"avatar\""), "Request should use custom field name")
    }

    @Test
    fun `test upload fails with 404`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(404).setBody("Not Found"))

        val config = """
            {
                "url": "${mockWebServer.url("/upload")}",
                "filePath": "${testFile.absolutePath}"
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertFalse(result, "Upload should fail with 404")
    }

    @Test
    fun `test upload fails with 500`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(500).setBody("Internal Server Error"))

        val config = """
            {
                "url": "${mockWebServer.url("/upload")}",
                "filePath": "${testFile.absolutePath}"
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertFalse(result, "Upload should fail with 500")
    }

    @Test
    fun `test upload fails with non-existent file`() = runBlocking {
        // Arrange
        val config = """
            {
                "url": "${mockWebServer.url("/upload")}",
                "filePath": "/nonexistent/file.txt"
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertFalse(result, "Upload should fail when file doesn't exist")
    }

    @Test
    fun `test upload fails with path traversal attempt`() = runBlocking {
        // Arrange
        val config = """
            {
                "url": "${mockWebServer.url("/upload")}",
                "filePath": "../../../etc/passwd"
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertFalse(result, "Upload should fail with path traversal attempt")
    }

    @Test
    fun `test invalid JSON config`() = runBlocking {
        // Arrange
        val invalidConfig = "{ this is not valid json }"

        // Act & Assert
        try {
            worker.doWork(invalidConfig)
            throw AssertionError("Should have thrown IllegalArgumentException")
        } catch (e: IllegalArgumentException) {
            assertTrue(e.message!!.contains("Invalid config JSON"))
        }
    }

    @Test
    fun `test empty input`() = runBlocking {
        // Act & Assert
        try {
            worker.doWork("")
            throw AssertionError("Should have thrown IllegalArgumentException")
        } catch (e: IllegalArgumentException) {
            assertTrue(e.message!!.contains("Input JSON is required"))
        }
    }

    @Test
    fun `test null input`() = runBlocking {
        // Act & Assert
        try {
            worker.doWork(null)
            throw AssertionError("Should have thrown IllegalArgumentException")
        } catch (e: IllegalArgumentException) {
            assertTrue(e.message!!.contains("Input JSON is required"))
        }
    }

    @Test
    fun `test upload with custom timeout`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(200).setBody("Upload successful"))

        val config = """
            {
                "url": "${mockWebServer.url("/upload")}",
                "filePath": "${testFile.absolutePath}",
                "timeoutMs": 5000
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertTrue(result, "Upload with custom timeout should succeed")
    }

    @Test
    fun `test real-world scenario - iOS HEIC upload with custom name`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(200).setBody("{\"photoId\":\"abc123\"}"))

        // Simulate iOS HEIC file with UUID name
        val config = """
            {
                "url": "${mockWebServer.url("/api/photos")}",
                "filePath": "${testFile.absolutePath}",
                "fileName": "profile_${System.currentTimeMillis()}.jpg",
                "mimeType": "image/heic",
                "fileFieldName": "photo",
                "additionalFields": {
                    "userId": "user123"
                },
                "headers": {
                    "Authorization": "Bearer test-token"
                }
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertTrue(result, "Real-world iOS HEIC upload should succeed")

        val recordedRequest = mockWebServer.takeRequest()
        assertEquals("Bearer test-token", recordedRequest.getHeader("Authorization"))
        val requestBody = recordedRequest.body.readUtf8()
        assertTrue(requestBody.contains("name=\"photo\""), "Should use custom field name")
        assertTrue(requestBody.contains("profile_"), "Should use custom file name")
        assertTrue(requestBody.contains("userId"), "Should include additional fields")
    }
}
