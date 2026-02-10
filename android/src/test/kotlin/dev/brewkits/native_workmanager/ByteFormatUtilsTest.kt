package dev.brewkits.native_workmanager

import dev.brewkits.native_workmanager.workers.utils.ByteFormatUtils
import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for ByteFormatUtils.
 */
class ByteFormatUtilsTest {

    @Test
    fun `formatBytes handles small values correctly`() {
        assertEquals("0B", ByteFormatUtils.formatBytes(0))
        assertEquals("1B", ByteFormatUtils.formatBytes(1))
        assertEquals("999B", ByteFormatUtils.formatBytes(999))
    }

    @Test
    fun `formatBytes handles KB range`() {
        assertEquals("1.0KB", ByteFormatUtils.formatBytes(1000))
        assertEquals("1.5KB", ByteFormatUtils.formatBytes(1500))
        assertEquals("999.9KB", ByteFormatUtils.formatBytes(999_900))
    }

    @Test
    fun `formatBytes handles MB range`() {
        assertEquals("1.0MB", ByteFormatUtils.formatBytes(1_000_000))
        assertEquals("2.5MB", ByteFormatUtils.formatBytes(2_500_000))
        assertEquals("100.5MB", ByteFormatUtils.formatBytes(100_500_000))
    }

    @Test
    fun `formatBytes handles GB range`() {
        assertEquals("1.0GB", ByteFormatUtils.formatBytes(1_000_000_000))
        assertEquals("2.5GB", ByteFormatUtils.formatBytes(2_500_000_000))
        assertEquals("10.3GB", ByteFormatUtils.formatBytes(10_300_000_000))
    }

    @Test
    fun `formatBytes handles TB range`() {
        assertEquals("1.00TB", ByteFormatUtils.formatBytes(1_000_000_000_000))
        assertEquals("2.50TB", ByteFormatUtils.formatBytes(2_500_000_000_000))
    }

    @Test
    fun `formatBytesIEC handles binary units`() {
        assertEquals("1.0KiB", ByteFormatUtils.formatBytesIEC(1024))
        assertEquals("1.0MiB", ByteFormatUtils.formatBytesIEC(1024 * 1024))
        assertEquals("1.0GiB", ByteFormatUtils.formatBytesIEC(1024L * 1024 * 1024))
    }

    @Test
    fun `formatBytesCompact removes unnecessary decimals`() {
        assertEquals("1KB", ByteFormatUtils.formatBytesCompact(1500))
        assertEquals("2MB", ByteFormatUtils.formatBytesCompact(2_500_000))
        assertEquals("1.5GB", ByteFormatUtils.formatBytesCompact(1_500_000_000))
    }

    @Test
    fun `parseBytes handles decimal units`() {
        assertEquals(2_500_000L, ByteFormatUtils.parseBytes("2.5MB"))
        assertEquals(10_000_000_000L, ByteFormatUtils.parseBytes("10GB"))
        assertEquals(1000L, ByteFormatUtils.parseBytes("1KB"))
    }

    @Test
    fun `parseBytes handles binary units`() {
        assertEquals(1024L, ByteFormatUtils.parseBytes("1KiB"))
        assertEquals(1024L * 1024, ByteFormatUtils.parseBytes("1MiB"))
        assertEquals(1024L * 1024 * 1024, ByteFormatUtils.parseBytes("1GiB"))
    }

    @Test
    fun `parseBytes handles whitespace`() {
        assertEquals(1000L, ByteFormatUtils.parseBytes("  1 KB  "))
        assertEquals(2_500_000L, ByteFormatUtils.parseBytes("2.5 MB"))
    }

    @Test
    fun `parseBytes handles case insensitivity`() {
        assertEquals(1000L, ByteFormatUtils.parseBytes("1kb"))
        assertEquals(1000L, ByteFormatUtils.parseBytes("1KB"))
        assertEquals(1024L, ByteFormatUtils.parseBytes("1kib"))
        assertEquals(1024L, ByteFormatUtils.parseBytes("1KiB"))
    }

    @Test
    fun `parseBytes returns null for invalid input`() {
        assertNull(ByteFormatUtils.parseBytes("invalid"))
        assertNull(ByteFormatUtils.parseBytes(""))
        assertNull(ByteFormatUtils.parseBytes("MB"))
        assertNull(ByteFormatUtils.parseBytes("10XB"))
    }

    @Test
    fun `round trip conversion preserves value`() {
        val original = 2_500_000L
        val formatted = ByteFormatUtils.formatBytes(original)
        val parsed = ByteFormatUtils.parseBytes(formatted)

        // Allow small rounding error due to decimal conversion
        assertNotNull(parsed)
        assertTrue(Math.abs(original - parsed!!) < 100_000)
    }
}
