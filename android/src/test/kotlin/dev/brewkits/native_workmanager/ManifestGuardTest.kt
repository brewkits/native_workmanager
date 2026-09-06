package dev.brewkits.native_workmanager

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression test for the FGS manifest fix (mirrors kmpworkmanager's
 * `ManifestGuardTest`, upstream issue #64).
 *
 * `android/src/main/AndroidManifest.xml` used to unconditionally declare
 * `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_DATA_SYNC` and a hardcoded
 * `foregroundServiceType` override on `SystemForegroundService`. Because this is a
 * *library* manifest, both got merged into every consumer app's final APK regardless
 * of whether that app ever used `isHeavyTask` / `ForegroundNativeWorker` — Google Play
 * flags apps carrying foreground-service permissions they never exercise, so apps that
 * only used e.g. `httpDownload` were getting rejected for something they didn't need.
 *
 * These must stay consumer-app opt-in (see `doc/ANDROID_SETUP.md`) — this test fails
 * loudly if either sneaks back into the library manifest.
 */
class ManifestGuardTest {

    @Test
    fun `library manifest does not declare foreground-service permissions unconditionally`() {
        val manifestFile = File("src/main/AndroidManifest.xml")
        val actualFile = if (manifestFile.exists()) {
            manifestFile
        } else {
            // Fallback for when the test is run from the repo root instead of android/.
            File("android/src/main/AndroidManifest.xml")
        }

        assertTrue(
            "Could not find AndroidManifest.xml at ${actualFile.absolutePath}",
            actualFile.exists(),
        )

        val manifestContent = actualFile.readText()

        val sensitivePermissions = listOf(
            "android.permission.FOREGROUND_SERVICE",
            "android.permission.FOREGROUND_SERVICE_DATA_SYNC",
            "android.permission.FOREGROUND_SERVICE_CAMERA",
            "android.permission.FOREGROUND_SERVICE_LOCATION",
            "android.permission.FOREGROUND_SERVICE_MEDIA_PROCESSING",
        )

        sensitivePermissions.forEach { permission ->
            assertFalse(
                "Library AndroidManifest.xml MUST NOT declare $permission unconditionally. " +
                    "This must be opt-in in the CONSUMER app's manifest (see doc/ANDROID_SETUP.md) " +
                    "to avoid Play Store rejection for apps that never use isHeavyTask.",
                manifestContent.contains(permission),
            )
        }

        assertFalse(
            "Library AndroidManifest.xml MUST NOT declare a default foregroundServiceType — " +
                "this must be declared by the consumer app to match what it actually uses.",
            manifestContent.contains("android:foregroundServiceType="),
        )
    }

    /**
     * Same rule, different permission.
     *
     * `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` is what
     * `NativeWorkManager.requestDisableBatteryOptimization()` needs, and Google Play
     * restricts it to a short list of app categories. Declaring it in this *library*
     * manifest would merge it into every consumer app — including the ones that only ever
     * call `openBatteryOptimizationSettings()`, or never touch the battery API at all —
     * and drag them into a policy review they did not ask for. That is precisely the FGS
     * mistake above, so it is guarded the same way.
     *
     * The host app declares it, or the plugin returns `missingPermission`. See
     * `NativeWorkmanagerPlugin+BatteryRestriction.kt`.
     */
    @Test
    fun `library manifest does not declare the Play-restricted battery permission`() {
        val manifestFile = File("src/main/AndroidManifest.xml")
        val actualFile = if (manifestFile.exists()) {
            manifestFile
        } else {
            File("android/src/main/AndroidManifest.xml")
        }

        assertTrue(
            "Could not find AndroidManifest.xml at ${actualFile.absolutePath}",
            actualFile.exists(),
        )

        assertFalse(
            "Library AndroidManifest.xml MUST NOT declare " +
                "REQUEST_IGNORE_BATTERY_OPTIMIZATIONS. It is Play-policy restricted and a " +
                "library manifest merges into EVERY consumer app. Apps that need the " +
                "direct dialog declare it themselves; the plugin reports " +
                "missingPermission otherwise.",
            actualFile.readText().contains("REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"),
        )
    }
}
