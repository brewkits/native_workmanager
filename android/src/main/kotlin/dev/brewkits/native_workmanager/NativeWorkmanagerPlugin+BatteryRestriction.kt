package dev.brewkits.native_workmanager

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Battery-restriction diagnostics and remediation entry points.
 *
 * Background work on Android is deferred by Doze and App Standby, and an app can sit on a
 * system exemption list. Several OEMs run their own task killer on top of that list, which
 * is why a 15-minute periodic task can stretch to hours on a device that reports itself as
 * exempt.
 *
 * Everything here reports what the OS actually answers. Deliberately NOT done:
 *
 *  - **No per-manufacturer settings deep links.** The MIUI/Samsung/Huawei/Oppo "autostart"
 *    and "protected apps" screens are undocumented internal activities. They are renamed and
 *    removed between firmware builds, and launching a stale one throws or silently opens
 *    nothing. Shipping a table of them means shipping a table that rots on devices we cannot
 *    test. [handleBatteryRestriction] returns `Build.MANUFACTURER` verbatim instead, so the
 *    host app can word its own guidance.
 *  - **No `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` in this library's manifest.** It is a
 *    Play-policy restricted permission and a library manifest merges into every consumer
 *    app. Declaring it would expose apps that never call this API to a policy review they
 *    did not ask for — the same mistake that got the foreground-service permissions pulled
 *    out of this manifest (see AndroidManifest.xml and ManifestGuardTest). The host app
 *    declares it or gets [REQUEST_MISSING_PERMISSION] back.
 */
internal const val REQUEST_SHOWN = "shown"
internal const val REQUEST_ALREADY_EXEMPT = "alreadyExempt"
internal const val REQUEST_MISSING_PERMISSION = "missingPermission"
internal const val REQUEST_UNAVAILABLE = "unavailable"

/** The Play-policy restricted permission the HOST app must declare itself. */
internal const val IGNORE_BATTERY_PERMISSION =
    "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"

/**
 * Returns whether this package sits on Android's battery-optimization exemption list.
 *
 * Returns null when the platform cannot answer, so the Dart side can report "unknown"
 * rather than defaulting to a reassuring `false`.
 */
internal fun isIgnoringBatteryOptimizations(context: Context): Boolean? {
    return try {
        val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            ?: return null
        pm.isIgnoringBatteryOptimizations(context.packageName)
    } catch (e: Exception) {
        // Some OEM builds throw from this call rather than answering it.
        NativeLogger.w("isIgnoringBatteryOptimizations threw: ${e.message}")
        null
    }
}

/** Whether [intent] resolves to something on THIS device, rather than assuming it does. */
internal fun resolvesOnThisDevice(context: Context, intent: Intent): Boolean {
    return try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.resolveActivity(
                intent,
                PackageManager.ResolveInfoFlags.of(0L),
            ) != null
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.resolveActivity(intent, 0) != null
        }
    } catch (e: Exception) {
        NativeLogger.w("resolveActivity threw: ${e.message}")
        false
    }
}

/** The system battery-optimization list. Needs no permission. */
internal fun batteryOptimizationSettingsIntent(): Intent =
    Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

internal fun NativeWorkmanagerPlugin.handleBatteryRestriction(result: Result) {
    val exempt = isIgnoringBatteryOptimizations(context)
    val canOpen = resolvesOnThisDevice(context, batteryOptimizationSettingsIntent())

    result.success(
        mapOf(
            "isExempt" to exempt,
            // Verbatim and lowercased so the Dart side compares against a stable form.
            // Not mapped to an enum: an unknown manufacturer must stay reportable.
            "manufacturer" to Build.MANUFACTURER?.lowercase(),
            "canOpenSettings" to canOpen,
        ),
    )
}

internal fun NativeWorkmanagerPlugin.handleOpenBatteryOptimizationSettings(result: Result) {
    val intent = batteryOptimizationSettingsIntent()
    if (!resolvesOnThisDevice(context, intent)) {
        // No such screen on this device or work profile. Report it instead of throwing —
        // this is a best-effort remediation helper, not a critical path.
        NativeLogger.w("No activity handles ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS")
        return result.success(false)
    }
    return try {
        context.startActivity(intent)
        result.success(true)
    } catch (e: Exception) {
        NativeLogger.w("Failed to open battery optimization settings: ${e.message}")
        result.success(false)
    }
}

internal fun NativeWorkmanagerPlugin.handleRequestDisableBatteryOptimization(result: Result) {
    if (isIgnoringBatteryOptimizations(context) == true) {
        return result.success(REQUEST_ALREADY_EXEMPT)
    }

    // The host app must declare the permission itself — see the file header for why this
    // library will not. Checking the merged manifest gives a precise answer instead of
    // letting the OS throw an opaque SecurityException.
    if (!hostDeclaresIgnoreBatteryPermission(context)) {
        NativeLogger.w(
            "requestDisableBatteryOptimization() needs $IGNORE_BATTERY_PERMISSION in the " +
                "HOST app's AndroidManifest.xml. It is Play-policy restricted, so this " +
                "plugin does not declare it for you. Use " +
                "openBatteryOptimizationSettings() if you cannot justify the permission.",
        )
        return result.success(REQUEST_MISSING_PERMISSION)
    }

    @Suppress("BatteryLife") // Gated on the host app opting in; see file header.
    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
        .setData(Uri.parse("package:${context.packageName}"))
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    if (!resolvesOnThisDevice(context, intent)) {
        return result.success(REQUEST_UNAVAILABLE)
    }

    return try {
        context.startActivity(intent)
        result.success(REQUEST_SHOWN)
    } catch (e: Exception) {
        NativeLogger.w("Failed to request battery optimization exemption: ${e.message}")
        result.success(REQUEST_UNAVAILABLE)
    }
}

/** Whether the merged manifest declares the Play-restricted permission. */
internal fun hostDeclaresIgnoreBatteryPermission(context: Context): Boolean {
    return try {
        val info = context.packageManager.getPackageInfo(
            context.packageName,
            PackageManager.GET_PERMISSIONS,
        )
        info.requestedPermissions?.contains(IGNORE_BATTERY_PERMISSION) == true
    } catch (e: Exception) {
        NativeLogger.w("Could not read requested permissions: ${e.message}")
        false
    }
}
