package dev.brewkits.native_workmanager.workers.utils

/**
 * Utility functions for formatting byte sizes in human-readable format.
 *
 * Provides both decimal (KB, MB, GB) and binary (KiB, MiB, GiB) formatting.
 */
object ByteFormatUtils {

    /**
     * Format bytes using decimal units (1 KB = 1000 bytes).
     *
     * This is the standard SI (International System of Units) format
     * commonly used by storage manufacturers and network speeds.
     *
     * @param bytes Number of bytes to format
     * @return Human-readable string (e.g., "2.5MB", "10.3GB")
     *
     * @sample
     * ```kotlin
     * formatBytes(1500)         // "1.5KB"
     * formatBytes(2_500_000)    // "2.5MB"
     * formatBytes(1_000_000_000) // "1.0GB"
     * ```
     */
    fun formatBytes(bytes: Long): String {
        return when {
            bytes < 1000 -> "${bytes}B"
            bytes < 1000 * 1000 -> String.format("%.1fKB", bytes / 1000.0)
            bytes < 1000L * 1000 * 1000 -> String.format("%.1fMB", bytes / (1000.0 * 1000))
            bytes < 1000L * 1000 * 1000 * 1000 -> String.format("%.1fGB", bytes / (1000.0 * 1000 * 1000))
            else -> String.format("%.2fTB", bytes / (1000.0 * 1000 * 1000 * 1000))
        }
    }

    /**
     * Format bytes using binary units (1 KiB = 1024 bytes).
     *
     * This follows the IEC standard (IEC 60027-2) and is commonly
     * used by operating systems and file managers.
     *
     * @param bytes Number of bytes to format
     * @return Human-readable string (e.g., "2.5MiB", "10.3GiB")
     *
     * @sample
     * ```kotlin
     * formatBytesIEC(1536)          // "1.5KiB"
     * formatBytesIEC(2_621_440)     // "2.5MiB"
     * formatBytesIEC(1_073_741_824) // "1.0GiB"
     * ```
     */
    fun formatBytesIEC(bytes: Long): String {
        return when {
            bytes < 1024 -> "${bytes}B"
            bytes < 1024 * 1024 -> String.format("%.1fKiB", bytes / 1024.0)
            bytes < 1024L * 1024 * 1024 -> String.format("%.1fMiB", bytes / (1024.0 * 1024))
            bytes < 1024L * 1024 * 1024 * 1024 -> String.format("%.1fGiB", bytes / (1024.0 * 1024 * 1024))
            else -> String.format("%.2fTiB", bytes / (1024.0 * 1024 * 1024 * 1024))
        }
    }

    /**
     * Format bytes compactly for progress messages (no decimal places for small sizes).
     *
     * This is optimized for progress display where precision is less important
     * than readability.
     *
     * @param bytes Number of bytes to format
     * @return Compact human-readable string (e.g., "2MB", "10GB")
     *
     * @sample
     * ```kotlin
     * formatBytesCompact(1500)         // "1KB"   (no decimal)
     * formatBytesCompact(2_500_000)    // "2MB"   (no decimal)
     * formatBytesCompact(1_500_000_000) // "1.5GB" (decimal for GB+)
     * ```
     */
    fun formatBytesCompact(bytes: Long): String {
        return when {
            bytes < 1000 -> "${bytes}B"
            bytes < 1000 * 1000 -> "${bytes / 1000}KB"
            bytes < 1000L * 1000 * 1000 -> "${bytes / (1000 * 1000)}MB"
            else -> String.format("%.1fGB", bytes / (1000.0 * 1000 * 1000))
        }
    }

    /**
     * Parse human-readable byte string back to Long.
     *
     * Supports both decimal (KB, MB, GB) and binary (KiB, MiB, GiB) units.
     *
     * @param sizeString String to parse (e.g., "2.5MB", "10GB", "1.5GiB")
     * @return Number of bytes, or null if parsing fails
     *
     * @sample
     * ```kotlin
     * parseBytes("2.5MB")  // 2_500_000
     * parseBytes("10GB")   // 10_000_000_000
     * parseBytes("1.5GiB") // 1_610_612_736
     * parseBytes("invalid") // null
     * ```
     */
    fun parseBytes(sizeString: String): Long? {
        val regex = Regex("""^([\d.]+)\s*([KMGT]i?B?)$""", RegexOption.IGNORE_CASE)
        val matchResult = regex.matchEntire(sizeString.trim()) ?: return null

        val value = matchResult.groupValues[1].toDoubleOrNull() ?: return null
        val unit = matchResult.groupValues[2].uppercase()

        val multiplier = when (unit) {
            "B" -> 1L
            "KB" -> 1000L
            "MB" -> 1000L * 1000
            "GB" -> 1000L * 1000 * 1000
            "TB" -> 1000L * 1000 * 1000 * 1000
            "KIB" -> 1024L
            "MIB" -> 1024L * 1024
            "GIB" -> 1024L * 1024 * 1024
            "TIB" -> 1024L * 1024 * 1024 * 1024
            else -> return null
        }

        return (value * multiplier).toLong()
    }
}
