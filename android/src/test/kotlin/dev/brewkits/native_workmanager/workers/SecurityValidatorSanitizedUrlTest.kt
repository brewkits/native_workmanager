package dev.brewkits.native_workmanager.workers

import dev.brewkits.native_workmanager.workers.utils.SecurityValidator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Regression tests for [SecurityValidator.sanitizedURL].
 *
 * It redacted query parameters but never touched RFC 3986 UserInfo, so a URL carrying
 * its credentials in the authority (`https://user:pass@host/...` — still common for
 * internal services and S3-style pre-signed endpoints) printed the password verbatim
 * into logs, and into persisted `WorkerResult` failure messages via `TaskCompletionEvent`.
 * Found while reviewing kmpworkmanager 3.5.0's identical fix to its own (unrelated,
 * no shared code) `SecurityValidator.sanitizedURL`.
 *
 * `sanitizedURL` calls `android.net.Uri.parse()` internally — Robolectric is required
 * for that to resolve to a real implementation instead of the SDK stub jar's `Stub!`
 * exception (same reason `NativeWorkManagerInitializerTest` needs it).
 */
@RunWith(RobolectricTestRunner::class)
class SecurityValidatorSanitizedUrlTest {

    @Test
    fun `UserInfo credentials are redacted`() {
        val sanitized = SecurityValidator.sanitizedURL("https://admin:secret123@api.example.com/data")
        assertFalse("password must not appear in sanitized output", sanitized.contains("secret123"))
        assertFalse("username must not appear in sanitized output", sanitized.contains("admin"))
        assertTrue(sanitized.contains("[REDACTED]@"))
        assertTrue(sanitized.contains("api.example.com/data"))
    }

    @Test
    fun `UserInfo and query are both redacted together`() {
        val sanitized = SecurityValidator.sanitizedURL(
            "https://admin:secret123@api.example.com/data?token=abc123",
        )
        assertFalse(sanitized.contains("secret123"))
        assertFalse(sanitized.contains("abc123"))
        assertTrue(sanitized.contains("[REDACTED]@"))
    }

    @Test
    fun `port and path survive UserInfo redaction`() {
        val sanitized = SecurityValidator.sanitizedURL(
            "https://user:pass@api.example.com:8080/path/to/resource",
        )
        assertFalse(sanitized.contains("user:pass"))
        assertTrue(sanitized.contains("api.example.com:8080/path/to/resource"))
    }

    @Test
    fun `URL with no credentials is unchanged`() {
        val url = "https://api.example.com/data"
        assertEquals(url, SecurityValidator.sanitizedURL(url))
    }

    @Test
    fun `URL with only query params still redacts the query as before`() {
        val sanitized = SecurityValidator.sanitizedURL("https://api.example.com/data?token=abc123")
        assertFalse(sanitized.contains("abc123"))
        assertTrue(sanitized.contains("api.example.com/data"))
    }

    @Test
    fun `an at-sign inside the path (not the authority) is left alone`() {
        // No "://...@" before the first "/" — the "@" here is just path content.
        val url = "https://api.example.com/users/@handle"
        assertEquals(url, SecurityValidator.sanitizedURL(url))
    }

    @Test
    fun `empty string does not crash and has nothing to redact`() {
        // Uri.parse("") does not throw (verified against the real Robolectric-shadowed
        // implementation, not assumed) — it's a valid empty-path Uri with no authority and
        // no query, so redactUserInfo's early return (no "://") and the no-query branch both
        // apply and this comes back unchanged. Pre-existing behavior, unrelated to this fix.
        assertEquals("", SecurityValidator.sanitizedURL(""))
    }
}
