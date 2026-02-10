package dev.brewkits.native_workmanager.workers

import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Before
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Unit tests for HttpRequestWorker.
 *
 * These tests verify:
 * - Successful HTTP requests (GET, POST, PUT, DELETE, PATCH)
 * - Failed HTTP requests (4xx, 5xx errors)
 * - Network errors
 * - JSON parsing
 * - Custom headers and body
 */
class HttpRequestWorkerTest {

    private lateinit var mockWebServer: MockWebServer
    private lateinit var worker: HttpRequestWorker

    @Before
    fun setup() {
        mockWebServer = MockWebServer()
        mockWebServer.start()
        worker = HttpRequestWorker()
    }

    @After
    fun tearDown() {
        mockWebServer.shutdown()
    }

    @Test
    fun `test successful GET request`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(200).setBody("Success"))

        val config = """
            {
                "url": "${mockWebServer.url("/")}",
                "method": "get"
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertTrue(result, "GET request should succeed")

        val recordedRequest = mockWebServer.takeRequest()
        assertEquals("GET", recordedRequest.method)
    }

    @Test
    fun `test successful POST request with body`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(201).setBody("Created"))

        val config = """
            {
                "url": "${mockWebServer.url("/api/data")}",
                "method": "post",
                "body": "{\"name\":\"test\",\"value\":123}",
                "headers": {
                    "Authorization": "Bearer token123",
                    "Custom-Header": "value"
                }
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertTrue(result, "POST request should succeed")

        val recordedRequest = mockWebServer.takeRequest()
        assertEquals("POST", recordedRequest.method)
        assertEquals("Bearer token123", recordedRequest.getHeader("Authorization"))
        assertEquals("value", recordedRequest.getHeader("Custom-Header"))
        assertTrue(recordedRequest.body.readUtf8().contains("\"name\":\"test\""))
    }

    @Test
    fun `test failed HTTP request (404)`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(404).setBody("Not Found"))

        val config = """
            {
                "url": "${mockWebServer.url("/notfound")}",
                "method": "get"
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertFalse(result, "404 request should fail")
    }

    @Test
    fun `test failed HTTP request (500)`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(500).setBody("Internal Server Error"))

        val config = """
            {
                "url": "${mockWebServer.url("/error")}",
                "method": "get"
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertFalse(result, "500 request should fail")
    }

    @Test
    fun `test PUT request`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(200).setBody("Updated"))

        val config = """
            {
                "url": "${mockWebServer.url("/api/resource/1")}",
                "method": "put",
                "body": "{\"status\":\"active\"}"
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertTrue(result, "PUT request should succeed")

        val recordedRequest = mockWebServer.takeRequest()
        assertEquals("PUT", recordedRequest.method)
        assertTrue(recordedRequest.body.readUtf8().contains("active"))
    }

    @Test
    fun `test DELETE request`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(204)) // No Content

        val config = """
            {
                "url": "${mockWebServer.url("/api/resource/1")}",
                "method": "delete"
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertTrue(result, "DELETE request should succeed")

        val recordedRequest = mockWebServer.takeRequest()
        assertEquals("DELETE", recordedRequest.method)
    }

    @Test
    fun `test PATCH request`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(200).setBody("Patched"))

        val config = """
            {
                "url": "${mockWebServer.url("/api/resource/1")}",
                "method": "patch",
                "body": "{\"field\":\"newValue\"}"
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertTrue(result, "PATCH request should succeed")

        val recordedRequest = mockWebServer.takeRequest()
        assertEquals("PATCH", recordedRequest.method)
    }

    @Test
    fun `test custom timeout`() = runBlocking {
        // Arrange
        mockWebServer.enqueue(MockResponse().setResponseCode(200).setBody("OK"))

        val config = """
            {
                "url": "${mockWebServer.url("/")}",
                "method": "get",
                "timeoutMs": 5000
            }
        """.trimIndent()

        // Act
        val result = worker.doWork(config)

        // Assert
        assertTrue(result, "Request with custom timeout should succeed")
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
}
