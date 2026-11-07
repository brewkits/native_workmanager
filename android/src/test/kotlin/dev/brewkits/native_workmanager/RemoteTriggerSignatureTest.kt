package dev.brewkits.native_workmanager

import dev.brewkits.native_workmanager.RemoteTriggerSignature.NonceStore
import dev.brewkits.native_workmanager.RemoteTriggerSignature.Verdict
import org.junit.Assert.*
import org.junit.Test

class RemoteTriggerSignatureTest {
    private val secret = "s3cret"
    private val now = 1_700_000_000_000L

    // Shared with doc/examples/remote_trigger_sign_v2.py and the Swift test. Keep in sync.
    private fun vector(): MutableMap<String, Any?> = mutableMapOf(
        "type" to "download_update",
        "url" to "https://x.test/a?b=c|d",
        "note" to "a=b|c",
        "nested" to mapOf("z" to 1, "a" to listOf(1, "x/y", "é\n")),
        "flag" to true,
        "count" to 7,
        "nothing" to null,
        "x-native-wm-timestamp" to "1700000000",
        "x-native-wm-nonce" to "nonce-0001",
    )
    private val vectorHex = "dca042f1afdc1ff83ef350f17e83b78a59175ed8d5b032ca0fdb54eb47ab8f0e"

    private fun signed(mutate: MutableMap<String, Any?>.() -> Unit = {}): Map<String, Any?> {
        val p = vector().apply(mutate)
        p["x-native-wm-signature"] = "v2=" + RemoteTriggerSignature.signV2Hex(p, secret)
        return p
    }

    private fun check(p: Map<String, Any?>, store: NonceStore = NonceStore(), at: Long = now) =
        RemoteTriggerSignature.verify(p, secret, at, store) { false }

    @Test fun v2_matches_cross_platform_reference_vector() {
        assertEquals(vectorHex, RemoteTriggerSignature.signV2Hex(vector(), secret))
        assertEquals(Verdict.VALID_V2, check(signed()))
    }

    @Test fun v2_separator_characters_in_values_cannot_collide() {
        // v1 joined "k=v|k=v": these two different payloads produced the same string.
        val a = mapOf<String, Any?>("a" to "1|b=2", "z" to "3")
        val b = mapOf<String, Any?>("a" to "1", "b" to "2|z=3")
        assertNotEquals(RemoteTriggerSignature.canonicalV2(a), RemoteTriggerSignature.canonicalV2(b))
        assertNotEquals(
            RemoteTriggerSignature.signV2Hex(a, secret), RemoteTriggerSignature.signV2Hex(b, secret))
    }

    @Test fun v2_tampering_is_rejected() {
        val p = signed().toMutableMap().apply { put("url", "https://evil.test/") }
        assertEquals(Verdict.INVALID, check(p))
    }

    @Test fun v2_replay_of_the_same_message_is_rejected() {
        val store = NonceStore()
        val p = signed()
        assertEquals(Verdict.VALID_V2, check(p, store))
        assertEquals(Verdict.REPLAYED, check(p, store, now + 1_000))
    }

    @Test fun v2_stale_and_future_timestamps_are_rejected() {
        val p = signed()
        assertEquals(Verdict.STALE, check(p, at = now + 301_000))
        assertEquals(Verdict.STALE, check(p, at = now - 301_000))
        assertEquals(Verdict.VALID_V2, check(p, at = now + 299_000))
    }

    @Test fun v2_missing_timestamp_or_nonce_is_rejected() {
        assertEquals(Verdict.INVALID, check(signed { remove("x-native-wm-nonce") }))
        assertEquals(Verdict.INVALID, check(signed { remove("x-native-wm-timestamp") }))
    }

    @Test fun invalid_signature_does_not_consume_the_nonce() {
        val store = NonceStore()
        val forged = signed().toMutableMap().apply { put("x-native-wm-signature", "v2=" + "00".repeat(32)) }
        assertEquals(Verdict.INVALID, check(forged, store))
        assertEquals(Verdict.VALID_V2, check(signed(), store))
    }

    @Test fun malformed_signatures_are_rejected_not_thrown() {
        for (sig in listOf("v2=", "v2=zz", "v2=abc", "")) {
            val p = vector().apply { put("x-native-wm-signature", sig) }
            assertEquals(Verdict.INVALID, check(p))
        }
        assertEquals(Verdict.INVALID, check(vector()))
    }

    @Test fun legacy_signature_is_delegated_to_the_v1_verifier() {
        val p = vector().apply { put("x-native-wm-signature", "deadbeef") }
        assertEquals(Verdict.VALID_LEGACY,
            RemoteTriggerSignature.verify(p, secret, now, NonceStore()) { it == "deadbeef" })
        assertEquals(Verdict.INVALID,
            RemoteTriggerSignature.verify(p, secret, now, NonceStore()) { false })
    }

    @Test fun nonce_store_forgets_after_window_and_stays_bounded() {
        val store = NonceStore()
        assertTrue(store.checkAndRecord("n", now))
        assertFalse(store.checkAndRecord("n", now + 1))
        assertTrue(store.checkAndRecord("n", now + 2 * 300_000L + 1))
        repeat(2500) { assertTrue(store.checkAndRecord("bulk$it", now + it)) }
    }
}
