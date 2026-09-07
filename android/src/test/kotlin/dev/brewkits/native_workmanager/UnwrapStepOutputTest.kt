package dev.brewkits.native_workmanager

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Covers the fix that finally makes `worker_results.dart` return data on Android.
 *
 * kmpworkmanager 3.4.0's InputMerger change serialises a worker's
 * `WorkerResult.Success.data` into WorkManager's output `Data` under one `kmp_step_output`
 * key, as a JSON string, so the next chain step can merge it. But `WorkInfo.outputData` is
 * also what this plugin forwards to Dart as `TaskEvent.resultData`, so without flattening,
 * every `CryptoResult.from(...)` / `ImageResult.from(...)` helper saw a map whose only key
 * was `kmp_step_output` and produced all-null fields.
 *
 * Measured on a Pixel 6 Pro:
 *   - kmpworkmanager 3.3.1: `resultData` arrived as **null** — the helpers never worked.
 *   - 3.4.1 without this fix: `{kmp_step_output: "{\"hash\":\"2cf2…\"}"}` — data present,
 *     but unreadable through the public API.
 *   - 3.4.1 with this fix: `{hash: 2cf2…, algorithm: SHA-256, …}`.
 */
class UnwrapStepOutputTest {

    @Test
    fun `flattens the step-output envelope into top-level keys`() {
        val raw = mapOf<String, Any?>(
            "kmp_step_output" to
                """{"hash":"2cf24dba","algorithm":"SHA-256","fileSize":5}""",
        )

        val out = unwrapStepOutput(raw)

        assertEquals("2cf24dba", out["hash"])
        assertEquals("SHA-256", out["algorithm"])
        assertEquals(5, out["fileSize"])
        assertTrue(
            "the envelope key must not survive into what Dart receives",
            !out.containsKey("kmp_step_output"),
        )
    }

    @Test
    fun `a map without the envelope is returned untouched`() {
        // A worker that writes its own output keys directly must keep them.
        val raw = mapOf<String, Any?>("progress" to 42, "path" to "/tmp/a")

        val out = unwrapStepOutput(raw)

        assertEquals(raw, out)
    }

    @Test
    fun `sibling keys are preserved alongside the decoded payload`() {
        val raw = mapOf<String, Any?>(
            "attempt" to 2,
            "kmp_step_output" to """{"hash":"abc"}""",
        )

        val out = unwrapStepOutput(raw)

        assertEquals(2, out["attempt"])
        assertEquals("abc", out["hash"])
    }

    @Test
    fun `JSON null decodes to a Kotlin null rather than the JSONObject sentinel`() {
        // org.json represents null as JSONObject.NULL, which would cross the method
        // channel as an opaque object and break `as String?` casts on the Dart side.
        val raw = mapOf<String, Any?>("kmp_step_output" to """{"outputPath":null}""")

        val out = unwrapStepOutput(raw)

        assertTrue(out.containsKey("outputPath"))
        assertNull(out["outputPath"])
    }

    @Test
    fun `malformed payload degrades to the raw map instead of throwing`() {
        // This runs on a SUCCESS path — a worker that genuinely succeeded must never be
        // reported as failed because its output could not be parsed.
        val raw = mapOf<String, Any?>("kmp_step_output" to "not json {{{")

        val out = unwrapStepOutput(raw)

        assertEquals(raw, out)
    }

    @Test
    fun `a non-string envelope value is left alone`() {
        val raw = mapOf<String, Any?>("kmp_step_output" to 12345)

        assertEquals(raw, unwrapStepOutput(raw))
    }

    @Test
    fun `an empty map stays empty`() {
        assertTrue(unwrapStepOutput(emptyMap()).isEmpty())
    }

    // ── issue #62 ─────────────────────────────────────────────────────────────
    //
    // The output of this function goes straight onto the EventChannel, and
    // Flutter's StandardMessageCodec can only encode plain types. Handing it an
    // org.json value threw
    //   IllegalArgumentException: Unsupported value: [...] of type 'org.json.JSONArray'
    // from inside eventSink.success(), which lost the WHOLE completion event —
    // the task ran, wrote its result, and looked to the app like it never
    // finished. These assert the decoded tree is codec-safe all the way down.

    @Test
    fun `nested arrays decode to a Kotlin List, not a JSONArray`() {
        val raw = mapOf<String, Any?>(
            "kmp_step_output" to
                """{"operation":"copy","files":["/tmp/a.txt","/tmp/b.txt"]}""",
        )

        val out = unwrapStepOutput(raw)

        assertTrue(
            "a JSONArray here is unencodable and destroys the event — see issue #62",
            out["files"] is List<*>,
        )
        assertEquals(listOf("/tmp/a.txt", "/tmp/b.txt"), out["files"])
    }

    @Test
    fun `nested objects decode to a Kotlin Map, not a JSONObject`() {
        val raw = mapOf<String, Any?>(
            "kmp_step_output" to """{"files":[{"path":"/tmp/a.txt","size":5}]}""",
        )

        val out = unwrapStepOutput(raw)
        val files = out["files"] as List<*>

        assertTrue(files[0] is Map<*, *>)
        assertEquals("/tmp/a.txt", (files[0] as Map<*, *>)["path"])
    }

    @Test
    fun `every decoded value is a type the Flutter codec accepts`() {
        val raw = mapOf<String, Any?>(
            "kmp_step_output" to """{"s":"x","i":1,"b":true,"n":null,
                "arr":[1,2],"obj":{"k":"v"}}""",
        )

        fun assertCodecSafe(value: Any?) {
            when (value) {
                null, is String, is Boolean, is Int, is Long, is Double -> Unit
                is List<*> -> value.forEach { assertCodecSafe(it) }
                is Map<*, *> -> value.values.forEach { assertCodecSafe(it) }
                else -> throw AssertionError(
                    "StandardMessageCodec cannot encode ${value::class.java.name}",
                )
            }
        }

        unwrapStepOutput(raw).values.forEach { assertCodecSafe(it) }
    }

    // ── decodeResultData: the plugin's own TaskEventBus path ──────────────────

    @Test
    fun `decodeResultData turns the JSON string into a Map`() {
        // That bus carries outputData as a JSON *string*, and Dart reads
        // `map['resultData'] is Map ? … : null` — so an undecoded string was
        // silently dropped and events on this path arrived with resultData null.
        val out = decodeResultData("""{"operation":"copy","fileCount":1}""")

        assertEquals("copy", out?.get("operation"))
        assertEquals(1, out?.get("fileCount"))
    }

    @Test
    fun `decodeResultData returns null for null, blank and malformed input`() {
        // Never throw on a completion path: a task that succeeded must not be
        // reported as failed because its payload could not be parsed.
        assertNull(decodeResultData(null))
        assertNull(decodeResultData(""))
        assertNull(decodeResultData("   "))
        assertNull(decodeResultData("not json {{{"))
    }

    @Test
    fun `the envelope key matches kmpworkmanager's constant`() {
        // NativeTaskScheduler.KEY_STEP_OUTPUT upstream. A rename there silently reverts
        // this fix — resultData would go back to carrying the envelope — so it is pinned.
        assertEquals("kmp_step_output", KEY_STEP_OUTPUT)
    }
}
