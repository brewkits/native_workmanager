package dev.brewkits.native_workmanager.utils

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * issue_46: maxRetries must be forwarded from the Dart constraints map onto the KMP
 * [dev.brewkits.kmpworkmanager.background.domain.Constraints] so kmpworkmanager 3.1.0+
 * (BaseKmpWorker / NativeTaskScheduler) can cap Failure(shouldRetry=true)/Retry at N+1 runs.
 *
 * This is the wiring guard demanded by the Issue #30 rule: it fails if parseConstraints stops
 * forwarding maxRetries — a serialization round-trip alone would not catch a dropped bridge value.
 */
class MappingUtilsMaxRetriesTest {

    @Test
    fun `maxRetries is forwarded onto Constraints`() {
        val constraints = MappingUtils.parseConstraints(mapOf("maxRetries" to 5))
        assertEquals(5, constraints.maxRetries)
    }

    @Test
    fun `maxRetries zero is preserved (no-retry contract)`() {
        val constraints = MappingUtils.parseConstraints(mapOf("maxRetries" to 0))
        assertEquals(0, constraints.maxRetries)
    }

    @Test
    fun `absent maxRetries defaults to -1 (uncapped, matches Kotlin default)`() {
        val constraints = MappingUtils.parseConstraints(mapOf("requiresNetwork" to true))
        assertEquals(-1, constraints.maxRetries)
    }

    @Test
    fun `null map yields default Constraints (uncapped)`() {
        val constraints = MappingUtils.parseConstraints(null)
        assertEquals(-1, constraints.maxRetries)
    }

    @Test
    fun `negative maxRetries is coerced to -1 (not below the uncapped sentinel)`() {
        val constraints = MappingUtils.parseConstraints(mapOf("maxRetries" to -9))
        assertEquals(-1, constraints.maxRetries)
    }

    @Test
    fun `maxRetries arriving as Long (MethodChannel) is honored`() {
        val constraints = MappingUtils.parseConstraints(mapOf("maxRetries" to 3L))
        assertEquals(3, constraints.maxRetries)
    }
}
