package dev.brewkits.native_workmanager.utils

import org.junit.Assert.*
import org.junit.Test

/**
 * issue_57: Unit tests for [ChainHelper.substitutePlaceholders] — the {{taskId.outputKey}}
 * chain-step placeholder resolution logic. Mirrors the Swift-side behavior in
 * NativeWorkmanagerPlugin+Execution.swift so both platforms agree on semantics.
 *
 * These are pure-function tests; the device integration test (issue_57_chain_placeholder_*
 * in device_integration_test.dart) is what proves the wiring around this actually runs.
 */
class ChainHelperSubstitutionTest {

    @Test
    fun `whole-match placeholder returns the original typed value, not a string`() {
        val config = mapOf("width" to "{{probe.width}}")
        val data = mapOf<String, Any?>("probe.width" to 1080)

        val result = ChainHelper.substitutePlaceholders(config, data)

        assertEquals(1080, result["width"])
        assertTrue(result["width"] is Int)
    }

    @Test
    fun `whole-match placeholder preserves Boolean and Double types too`() {
        val config = mapOf("flag" to "{{step.flag}}", "ratio" to "{{step.ratio}}")
        val data = mapOf<String, Any?>("step.flag" to true, "step.ratio" to 0.5)

        val result = ChainHelper.substitutePlaceholders(config, data)

        assertEquals(true, result["flag"])
        assertEquals(0.5, result["ratio"])
    }

    @Test
    fun `partial match interpolates into a larger string`() {
        val config = mapOf("zipPath" to "/tmp/{{downloader.id}}.zip")
        val data = mapOf<String, Any?>("downloader.id" to "abc123")

        val result = ChainHelper.substitutePlaceholders(config, data)

        assertEquals("/tmp/abc123.zip", result["zipPath"])
    }

    @Test
    fun `unresolved key leaves the literal placeholder untouched`() {
        val config = mapOf("zipPath" to "{{missing.key}}")

        val result = ChainHelper.substitutePlaceholders(config, emptyMap())

        assertEquals("{{missing.key}}", result["zipPath"])
    }

    @Test
    fun `unresolved key inside a partial match leaves that occurrence untouched`() {
        val config = mapOf("zipPath" to "/tmp/{{missing.key}}.zip")

        val result = ChainHelper.substitutePlaceholders(config, emptyMap())

        assertEquals("/tmp/{{missing.key}}.zip", result["zipPath"])
    }

    @Test
    fun `non-placeholder strings pass through unchanged`() {
        val config = mapOf("path" to "/tmp/plain.txt")

        val result = ChainHelper.substitutePlaceholders(config, mapOf("unused" to 1))

        assertEquals("/tmp/plain.txt", result["path"])
    }

    @Test
    fun `recurses into nested maps`() {
        val config = mapOf(
            "cropRect" to mapOf(
                "x" to "{{probe.x}}",
                "y" to 0,
                "width" to "{{probe.width}}"
            )
        )
        val data = mapOf<String, Any?>("probe.x" to 10, "probe.width" to 500)

        val result = ChainHelper.substitutePlaceholders(config, data)

        @Suppress("UNCHECKED_CAST")
        val cropRect = result["cropRect"] as Map<String, Any?>
        assertEquals(10, cropRect["x"])
        assertEquals(0, cropRect["y"]) // non-string value untouched
        assertEquals(500, cropRect["width"])
    }

    @Test
    fun `recurses into a list of maps`() {
        val config = mapOf(
            "items" to listOf(
                mapOf("id" to "{{step.a}}"),
                mapOf("id" to "{{step.b}}")
            )
        )
        val data = mapOf<String, Any?>("step.a" to "first", "step.b" to "second")

        val result = ChainHelper.substitutePlaceholders(config, data)

        @Suppress("UNCHECKED_CAST")
        val items = result["items"] as List<Map<String, Any?>>
        assertEquals("first", items[0]["id"])
        assertEquals("second", items[1]["id"])
    }

    @Test
    fun `whitespace padding around a whole-match placeholder is tolerated`() {
        val config = mapOf("width" to "  {{probe.width}}  ")
        val data = mapOf<String, Any?>("probe.width" to 42)

        val result = ChainHelper.substitutePlaceholders(config, data)

        assertEquals(42, result["width"])
    }

    @Test
    fun `int values are not accidentally treated as whole matches for unrelated fields`() {
        val config = mapOf("width" to 100, "label" to "static")

        val result = ChainHelper.substitutePlaceholders(config, mapOf("width" to 999))

        // Non-string config values are never touched by substitution, regardless of
        // whether a same-named key exists in the substitution data.
        assertEquals(100, result["width"])
        assertEquals("static", result["label"])
    }
}
