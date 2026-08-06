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
}
