package dev.brewkits.native_workmanager

import android.content.SharedPreferences
import org.json.JSONObject
import java.security.MessageDigest
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import kotlin.math.abs

/**
 * Remote Trigger signature scheme **v2** (collision-free canonical form + replay protection).
 *
 * The exact spec, plus a reference signer, lives in `doc/examples/remote_trigger_sign_v2.py`;
 * `RemoteTriggerSignatureTest` and the Swift counterpart share one test vector with it.
 * v1 (`key=value|key=value`, no timestamp) is still accepted and flagged as deprecated.
 */
internal object RemoteTriggerSignature {
    const val SIGNATURE_KEY = "x-native-wm-signature"
    const val TIMESTAMP_KEY = "x-native-wm-timestamp"
    const val NONCE_KEY = "x-native-wm-nonce"
    const val V2_PREFIX = "v2="
    const val MAX_SKEW_SECONDS = 300L

    @Volatile private var sharedStore: NonceStore? = null

    /** One store per process, so two concurrent pushes carrying the same nonce cannot both pass. */
    fun sharedNonceStore(prefs: SharedPreferences): NonceStore =
        sharedStore ?: synchronized(this) { sharedStore ?: NonceStore(prefs).also { sharedStore = it } }

    /** An unsigned `native_wm` command is refused only when the rule opted in and has no secret. */
    fun shouldRejectUnsignedCommand(hasSecret: Boolean, hasNativeWmCommand: Boolean, rejectFlag: Boolean): Boolean =
        !hasSecret && hasNativeWmCommand && rejectFlag

    enum class Verdict { VALID_V2, VALID_LEGACY, INVALID, STALE, REPLAYED }

    fun verify(
        payload: Map<String, Any?>,
        secretKey: String,
        nowMs: Long,
        nonces: NonceStore,
        legacyVerifier: (String) -> Boolean,
    ): Verdict {
        val signature = payload[SIGNATURE_KEY]?.toString() ?: return Verdict.INVALID
        if (!signature.startsWith(V2_PREFIX)) {
            return if (legacyVerifier(signature)) Verdict.VALID_LEGACY else Verdict.INVALID
        }
        val provided = hexToBytes(signature.removePrefix(V2_PREFIX)) ?: return Verdict.INVALID
        // The signature is checked FIRST: only authentic messages may touch the nonce store
        // (otherwise anyone could fill it with junk nonces).
        val expected = hmac(secretKey, canonicalV2(payload))
        if (!MessageDigest.isEqual(expected, provided)) return Verdict.INVALID

        val tsSeconds = payload[TIMESTAMP_KEY]?.toString()?.toLongOrNull() ?: return Verdict.INVALID
        val nonce = payload[NONCE_KEY]?.toString()?.takeIf { it.isNotEmpty() } ?: return Verdict.INVALID
        if (abs(nowMs / 1000 - tsSeconds) > MAX_SKEW_SECONDS) return Verdict.STALE
        return if (nonces.checkAndRecord(nonce, nowMs)) Verdict.VALID_V2 else Verdict.REPLAYED
    }

    fun canonicalV2(payload: Map<String, Any?>): String {
        val entries = payload.keys.filter { it != SIGNATURE_KEY }
            .sortedWith { a, b -> compareUtf8(a, b) }
            .map { key ->
                val value = scalar(payload[key])
                "${key.toByteArray(Charsets.UTF_8).size}:$key${value.toByteArray(Charsets.UTF_8).size}:$value"
            }
        return "NWM2\n" + entries.joinToString("\n")
    }

    fun signV2Hex(payload: Map<String, Any?>, secretKey: String): String =
        hmac(secretKey, canonicalV2(payload)).joinToString("") { "%02x".format(it) }

    private fun hmac(secretKey: String, message: String): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(secretKey.toByteArray(Charsets.UTF_8), "HmacSHA256"))
        return mac.doFinal(message.toByteArray(Charsets.UTF_8))
    }

    private fun hexToBytes(hex: String): ByteArray? {
        if (hex.isEmpty() || hex.length % 2 != 0) return null
        val out = ByteArray(hex.length / 2)
        for (i in out.indices) {
            val hi = Character.digit(hex[2 * i], 16)
            val lo = Character.digit(hex[2 * i + 1], 16)
            if (hi < 0 || lo < 0) return null
            out[i] = ((hi shl 4) or lo).toByte()
        }
        return out
    }

    /** Byte-wise (unsigned) UTF-8 order, identical on every platform. */
    private fun compareUtf8(a: String, b: String): Int {
        val x = a.toByteArray(Charsets.UTF_8)
        val y = b.toByteArray(Charsets.UTF_8)
        for (i in 0 until minOf(x.size, y.size)) {
            val d = (x[i].toInt() and 0xFF) - (y[i].toInt() and 0xFF)
            if (d != 0) return d
        }
        return x.size - y.size
    }

    private fun scalar(v: Any?): String = when (v) {
        null -> "null"
        is String -> v
        is Map<*, *>, is List<*> -> json(v)
        else -> number(v) ?: v.toString()
    }

    private fun number(v: Any?): String? = when (v) {
        is Boolean -> v.toString()
        is Byte, is Short, is Int, is Long -> v.toString()
        is Float, is Double -> {
            val d = (v as Number).toDouble()
            if (d == Math.rint(d) && abs(d) < 1e15) d.toLong().toString() else d.toString()
        }
        else -> null
    }

    /** Compact JSON, keys in UTF-8 byte order, "/" unescaped, non-ASCII raw. */
    private fun json(v: Any?): String = when (v) {
        null -> "null"
        is String -> quote(v)
        is Map<*, *> -> v.entries
            .map { it.key.toString() to it.value }
            .sortedWith { a, b -> compareUtf8(a.first, b.first) }
            .joinToString(",", "{", "}") { quote(it.first) + ":" + json(it.second) }
        is List<*> -> v.joinToString(",", "[", "]") { json(it) }
        else -> number(v) ?: quote(v.toString())
    }

    private fun quote(s: String): String {
        val sb = StringBuilder("\"")
        for (c in s) when {
            c == '"' -> sb.append("\\\"")
            c == '\\' -> sb.append("\\\\")
            c == '\b' -> sb.append("\\b")
            c == '\u000C' -> sb.append("\\f")
            c == '\n' -> sb.append("\\n")
            c == '\r' -> sb.append("\\r")
            c == '\t' -> sb.append("\\t")
            c < ' ' -> sb.append("\\u%04x".format(c.code))
            else -> sb.append(c)
        }
        return sb.append('"').toString()
    }

    /**
     * Remembers accepted nonces for twice the skew window (survives process death when a
     * [SharedPreferences] is supplied). Bounded, so it cannot grow without limit.
     */
    class NonceStore(private val prefs: SharedPreferences? = null) {
        private val seen = LinkedHashMap<String, Long>()
        private var loaded = false

        @Synchronized
        fun checkAndRecord(nonce: String, nowMs: Long): Boolean {
            load()
            val cutoff = nowMs - 2 * MAX_SKEW_SECONDS * 1000
            seen.entries.removeAll { it.value < cutoff }
            if (seen.containsKey(nonce)) return false
            seen[nonce] = nowMs
            while (seen.size > MAX_ENTRIES) seen.remove(seen.keys.first())
            persist()
            return true
        }

        private fun load() {
            if (loaded) return
            loaded = true
            val raw = prefs?.getString(PREF_KEY, null) ?: return
            try {
                val o = JSONObject(raw)
                o.keys().forEach { seen[it] = o.getLong(it) }
            } catch (_: Exception) {
                // corrupt state: start clean rather than fail closed forever
            }
        }

        private fun persist() {
            val p = prefs ?: return
            val o = JSONObject()
            seen.forEach { (k, v) -> o.put(k, v) }
            p.edit().putString(PREF_KEY, o.toString()).apply()
        }

        companion object {
            private const val PREF_KEY = "remote_trigger_nonces_v1"
            private const val MAX_ENTRIES = 2000
        }
    }
}
