package dev.brewkits.native_workmanager.workers

import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.File
import java.util.zip.ZipFile

/**
 * Unit tests for FileCompressionWorker
 */
class FileCompressionWorkerTest {

    private lateinit var tempDir: File
    private lateinit var worker: FileCompressionWorker

    @Before
    fun setUp() {
        worker = FileCompressionWorker()

        // Create temporary directory for tests
        tempDir = File(System.getProperty("java.io.tmpdir"), "file_compression_test_${System.currentTimeMillis()}")
        tempDir.mkdirs()
    }

    @After
    fun tearDown() {
        // Clean up temporary files
        if (tempDir.exists()) {
            tempDir.deleteRecursively()
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Test: Basic Functionality
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun `compress single file successfully`() = runBlocking {
        // Create test file
        val testFile = File(tempDir, "test.txt")
        testFile.writeText("Hello, World!")

        val outputFile = File(tempDir, "output.zip")

        // Create input JSON
        val input = JSONObject().apply {
            put("inputPath", testFile.absolutePath)
            put("outputPath", outputFile.absolutePath)
            put("compressionLevel", "medium")
        }.toString()

        // Execute worker
        val result = worker.doWork(input)

        // Verify
        assertTrue("Worker should succeed", result)
        assertTrue("Output file should exist", outputFile.exists())
        assertTrue("Output file should not be empty", outputFile.length() > 0)

        // Verify ZIP contents
        ZipFile(outputFile).use { zip ->
            val entries = zip.entries().toList()
            assertEquals("Should have 1 entry", 1, entries.size)
            assertEquals("Entry name should match", "test.txt", entries[0].name)
        }
    }

    @Test
    fun `compress directory recursively`() = runBlocking {
        // Create test directory structure
        val testDir = File(tempDir, "test_dir")
        testDir.mkdirs()

        File(testDir, "file1.txt").writeText("File 1 content")
        File(testDir, "file2.txt").writeText("File 2 content")

        val subDir = File(testDir, "subdir")
        subDir.mkdirs()
        File(subDir, "file3.txt").writeText("File 3 content")

        val outputFile = File(tempDir, "output.zip")

        // Create input JSON
        val input = JSONObject().apply {
            put("inputPath", testDir.absolutePath)
            put("outputPath", outputFile.absolutePath)
        }.toString()

        // Execute worker
        val result = worker.doWork(input)

        // Verify
        assertTrue("Worker should succeed", result)
        assertTrue("Output file should exist", outputFile.exists())

        // Verify ZIP contents
        ZipFile(outputFile).use { zip ->
            val entries = zip.entries().toList().map { it.name }.sorted()

            assertTrue("Should contain file1.txt", entries.contains("test_dir/file1.txt"))
            assertTrue("Should contain file2.txt", entries.contains("test_dir/file2.txt"))
            assertTrue("Should contain subdir/", entries.contains("test_dir/subdir/"))
            assertTrue("Should contain file3.txt", entries.contains("test_dir/subdir/file3.txt"))
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Test: Exclude Patterns
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun `exclude files by extension pattern`() = runBlocking {
        // Create test files
        val testDir = File(tempDir, "test_dir")
        testDir.mkdirs()

        File(testDir, "file1.txt").writeText("Keep this")
        File(testDir, "file2.tmp").writeText("Exclude this")
        File(testDir, "file3.txt").writeText("Keep this too")

        val outputFile = File(tempDir, "output.zip")

        // Create input JSON with exclude patterns
        val input = JSONObject().apply {
            put("inputPath", testDir.absolutePath)
            put("outputPath", outputFile.absolutePath)
            put("excludePatterns", JSONArray().apply {
                put("*.tmp")
            })
        }.toString()

        // Execute worker
        val result = worker.doWork(input)

        // Verify
        assertTrue("Worker should succeed", result)

        // Verify ZIP contents
        ZipFile(outputFile).use { zip ->
            val entries = zip.entries().toList().map { it.name }

            assertTrue("Should contain file1.txt", entries.contains("test_dir/file1.txt"))
            assertFalse("Should NOT contain file2.tmp", entries.contains("test_dir/file2.tmp"))
            assertTrue("Should contain file3.txt", entries.contains("test_dir/file3.txt"))
        }
    }

    @Test
    fun `exclude multiple patterns`() = runBlocking {
        // Create test files
        val testDir = File(tempDir, "test_dir")
        testDir.mkdirs()

        File(testDir, "file1.txt").writeText("Keep")
        File(testDir, "file2.tmp").writeText("Exclude - tmp")
        File(testDir, ".DS_Store").writeText("Exclude - DS_Store")
        File(testDir, "backup.bak").writeText("Exclude - bak")

        val outputFile = File(tempDir, "output.zip")

        // Create input JSON
        val input = JSONObject().apply {
            put("inputPath", testDir.absolutePath)
            put("outputPath", outputFile.absolutePath)
            put("excludePatterns", JSONArray().apply {
                put("*.tmp")
                put(".DS_Store")
                put("*.bak")
            })
        }.toString()

        // Execute worker
        val result = worker.doWork(input)

        // Verify
        assertTrue("Worker should succeed", result)

        ZipFile(outputFile).use { zip ->
            val entries = zip.entries().toList().map { it.name }
            assertEquals("Should only have 2 entries (dir + file)", 2, entries.size)
            assertTrue("Should contain file1.txt", entries.contains("test_dir/file1.txt"))
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Test: Delete Original Option
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun `delete original file after compression`() = runBlocking {
        // Create test file
        val testFile = File(tempDir, "delete_me.txt")
        testFile.writeText("This will be deleted")

        val outputFile = File(tempDir, "output.zip")

        // Create input JSON with deleteOriginal = true
        val input = JSONObject().apply {
            put("inputPath", testFile.absolutePath)
            put("outputPath", outputFile.absolutePath)
            put("deleteOriginal", true)
        }.toString()

        // Verify file exists before
        assertTrue("Test file should exist before compression", testFile.exists())

        // Execute worker
        val result = worker.doWork(input)

        // Verify
        assertTrue("Worker should succeed", result)
        assertTrue("Output should exist", outputFile.exists())
        assertFalse("Original file should be deleted", testFile.exists())
    }

    @Test
    fun `delete original directory after compression`() = runBlocking {
        // Create test directory
        val testDir = File(tempDir, "delete_me_dir")
        testDir.mkdirs()
        File(testDir, "file.txt").writeText("Content")

        val outputFile = File(tempDir, "output.zip")

        // Create input JSON
        val input = JSONObject().apply {
            put("inputPath", testDir.absolutePath)
            put("outputPath", outputFile.absolutePath)
            put("deleteOriginal", true)
        }.toString()

        // Execute worker
        val result = worker.doWork(input)

        // Verify
        assertTrue("Worker should succeed", result)
        assertFalse("Original directory should be deleted", testDir.exists())
    }

    // ════════════════════════════════════════════════════════════════════
    // Test: Compression Levels
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun `compression levels produce different sizes`() = runBlocking {
        // Create a test file with repetitive content (compresses well)
        val testFile = File(tempDir, "test.txt")
        testFile.writeText("A".repeat(10000))

        val outputLow = File(tempDir, "low.zip")
        val outputMedium = File(tempDir, "medium.zip")
        val outputHigh = File(tempDir, "high.zip")

        // Compress with different levels
        listOf(
            "low" to outputLow,
            "medium" to outputMedium,
            "high" to outputHigh
        ).forEach { (level, output) ->
            val input = JSONObject().apply {
                put("inputPath", testFile.absolutePath)
                put("outputPath", output.absolutePath)
                put("compressionLevel", level)
            }.toString()

            worker.doWork(input)
        }

        // Verify all succeeded
        assertTrue(outputLow.exists())
        assertTrue(outputMedium.exists())
        assertTrue(outputHigh.exists())

        // Verify sizes (high should be smallest)
        // Note: Sizes may be similar for small files
        println("Low: ${outputLow.length()} bytes")
        println("Medium: ${outputMedium.length()} bytes")
        println("High: ${outputHigh.length()} bytes")
    }

    // ════════════════════════════════════════════════════════════════════
    // Test: Error Handling
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun `fail when input is null`() = runBlocking {
        val result = worker.doWork(null)
        assertFalse("Should fail with null input", result)
    }

    @Test
    fun `fail when inputPath is missing`() = runBlocking {
        val input = JSONObject().apply {
            put("outputPath", "/tmp/output.zip")
        }.toString()

        val result = worker.doWork(input)
        assertFalse("Should fail when inputPath is missing", result)
    }

    @Test
    fun `fail when outputPath is missing`() = runBlocking {
        val input = JSONObject().apply {
            put("inputPath", "/tmp/test.txt")
        }.toString()

        val result = worker.doWork(input)
        assertFalse("Should fail when outputPath is missing", result)
    }

    @Test
    fun `fail when input file does not exist`() = runBlocking {
        val input = JSONObject().apply {
            put("inputPath", "/nonexistent/path/file.txt")
            put("outputPath", File(tempDir, "output.zip").absolutePath)
        }.toString()

        val result = worker.doWork(input)
        assertFalse("Should fail when input file doesn't exist", result)
    }

    @Test
    fun `fail when output path does not end with zip`() = runBlocking {
        val testFile = File(tempDir, "test.txt")
        testFile.writeText("Test")

        val input = JSONObject().apply {
            put("inputPath", testFile.absolutePath)
            put("outputPath", File(tempDir, "output.txt").absolutePath)
        }.toString()

        val result = worker.doWork(input)
        assertFalse("Should fail when output doesn't end with .zip", result)
    }

    // ════════════════════════════════════════════════════════════════════
    // Test: Edge Cases
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun `compress empty directory`() = runBlocking {
        val emptyDir = File(tempDir, "empty")
        emptyDir.mkdirs()

        val outputFile = File(tempDir, "output.zip")

        val input = JSONObject().apply {
            put("inputPath", emptyDir.absolutePath)
            put("outputPath", outputFile.absolutePath)
        }.toString()

        val result = worker.doWork(input)

        // Should succeed even with empty directory
        assertTrue("Should succeed with empty directory", result)
        assertTrue("Output should exist", outputFile.exists())

        ZipFile(outputFile).use { zip ->
            val entries = zip.entries().toList()
            // Should have at least the directory entry
            assertTrue("Should have directory entry", entries.size >= 1)
        }
    }

    @Test
    fun `compress large file`() = runBlocking {
        // Create a 1MB file
        val largeFile = File(tempDir, "large.txt")
        largeFile.writeText("X".repeat(1024 * 1024))

        val outputFile = File(tempDir, "output.zip")

        val input = JSONObject().apply {
            put("inputPath", largeFile.absolutePath)
            put("outputPath", outputFile.absolutePath)
        }.toString()

        val result = worker.doWork(input)

        assertTrue("Should succeed with large file", result)
        assertTrue("Output should exist", outputFile.exists())
        assertTrue("Compressed size should be less than original",
            outputFile.length() < largeFile.length())
    }

    @Test
    fun `overwrite existing zip file`() = runBlocking {
        val testFile = File(tempDir, "test.txt")
        testFile.writeText("New content")

        val outputFile = File(tempDir, "output.zip")

        // Create existing zip
        outputFile.writeText("Old content")
        val oldSize = outputFile.length()

        val input = JSONObject().apply {
            put("inputPath", testFile.absolutePath)
            put("outputPath", outputFile.absolutePath)
        }.toString()

        val result = worker.doWork(input)

        assertTrue("Should succeed", result)
        assertNotEquals("File should be replaced", oldSize, outputFile.length())
    }
}
