package dev.brewkits.native_workmanager

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.PowerManager
import android.provider.Settings
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

/**
 * Unit coverage for the battery-restriction helpers.
 *
 * Robolectric is used rather than a device test because the interesting cases are the ones a
 * single physical device cannot produce: an app that HAS the Play-restricted permission and one
 * that does NOT, and a device where the settings Activity does not resolve. The device test in
 * `device_integration_test.dart` covers the real-hardware shape; this covers the branches.
 */
@RunWith(RobolectricTestRunner::class)
class BatteryRestrictionTest {

    private lateinit var context: Context

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
    }

    // ── isIgnoringBatteryOptimizations ─────────────────────────────────────────

    @Test
    fun `isIgnoringBatteryOptimizations reports the PowerManager answer`() {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        shadowOf(pm).setIgnoringBatteryOptimizations(context.packageName, true)

        assertEquals(true, isIgnoringBatteryOptimizations(context))

        shadowOf(pm).setIgnoringBatteryOptimizations(context.packageName, false)

        // Must report false, not null: the platform answered, the answer was "no".
        assertEquals(false, isIgnoringBatteryOptimizations(context))
    }

    // ── resolvesOnThisDevice ───────────────────────────────────────────────────

    @Test
    fun `resolvesOnThisDevice is false when nothing handles the intent`() {
        // Robolectric's default package manager resolves nothing unless told to, which is
        // exactly the "device has no such settings screen" case the API must survive.
        val unhandled = Intent("dev.brewkits.native_workmanager.NO_SUCH_ACTION")
        assertFalse(resolvesOnThisDevice(context, unhandled))
    }

    @Test
    fun `resolvesOnThisDevice is true once an activity claims the intent`() {
        val intent = batteryOptimizationSettingsIntent()
        shadowOf(context.packageManager).addActivityIfNotPresent(
            android.content.ComponentName("com.android.settings", "FakeBatterySettings"),
        )
        shadowOf(context.packageManager).addIntentFilterForActivity(
            android.content.ComponentName("com.android.settings", "FakeBatterySettings"),
            android.content.IntentFilter(
                Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS,
            ),
        )

        assertTrue(resolvesOnThisDevice(context, intent))
    }

    // ── hostDeclaresIgnoreBatteryPermission ────────────────────────────────────

    @Test
    fun `permission is reported absent when the host app does not declare it`() {
        // This is the default for the plugin's own test manifest, and the state every
        // consumer app is in unless it opts in. The plugin must NEVER declare it — see
        // ManifestGuardTest.
        assertFalse(hostDeclaresIgnoreBatteryPermission(context))
    }

    @Test
    fun `permission is reported present when the host app declares it`() {
        val info = context.packageManager.getPackageInfo(
            context.packageName,
            PackageManager.GET_PERMISSIONS,
        )
        info.requestedPermissions = arrayOf(IGNORE_BATTERY_PERMISSION)
        shadowOf(context.packageManager).installPackage(info)

        assertTrue(hostDeclaresIgnoreBatteryPermission(context))
    }

    // ── result-string contract ─────────────────────────────────────────────────

    @Test
    fun `result strings match exactly what the Dart side parses`() {
        // These four strings are a contract with the switch in
        // MethodChannelNativeWorkManager.requestDisableBatteryOptimization
        // (lib/src/method_channel.dart). If either side renames one, that switch falls to
        // "unavailable" and the Play-policy opt-in becomes undiagnosable at runtime — the
        // failure is silent, which is why it is pinned on both sides.
        assertEquals("shown", REQUEST_SHOWN)
        assertEquals("alreadyExempt", REQUEST_ALREADY_EXEMPT)
        assertEquals("missingPermission", REQUEST_MISSING_PERMISSION)
        assertEquals("unavailable", REQUEST_UNAVAILABLE)
    }

    @Test
    fun `the guarded permission constant is the Play-restricted one`() {
        assertEquals(
            "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
            IGNORE_BATTERY_PERMISSION,
        )
    }

    // ── settings intent shape ──────────────────────────────────────────────────

    @Test
    fun `settings intent uses the permissionless action and can start from a non-activity`() {
        val intent = batteryOptimizationSettingsIntent()

        // ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS opens the system list and needs no
        // permission. Using ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS here instead would
        // drag every caller into the Play-restricted path.
        assertEquals(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS, intent.action)

        // The plugin is not ActivityAware, so it starts from the application Context and
        // NEW_TASK is mandatory — without it startActivity throws at runtime.
        assertNotNull(intent.flags and Intent.FLAG_ACTIVITY_NEW_TASK)
        assertTrue((intent.flags and Intent.FLAG_ACTIVITY_NEW_TASK) != 0)
    }
}
