/// Battery-restriction diagnostics for background work.
///
/// Android lets the OS defer background work to save power. On stock Android
/// that is Doze plus App Standby Buckets, and an app can be placed on an
/// exemption list. Several OEMs (Xiaomi/MIUI/HyperOS, Samsung, Huawei, Oppo,
/// Vivo and others) layer their *own* task killer on top of that list, which is
/// why a periodic task can still be stretched from 15 minutes to many hours on
/// a device that reports itself as exempt.
///
/// This library reports only what the OS actually tells it. It does not try to
/// guess an OEM's behaviour — see [BatteryRestrictionReport.isExempt] for
/// exactly what the exemption flag does and does not cover.
library;

/// What the platform reports about background battery restrictions.
///
/// Obtained from `NativeWorkManager.batteryRestriction()`.
class BatteryRestrictionReport {
  /// Creates a report. Normally built by the plugin, not by application code —
  /// the constructor is public so tests and fakes can build one.
  const BatteryRestrictionReport({
    required this.isExempt,
    required this.manufacturer,
    required this.canOpenSettings,
  });

  /// Builds a report from the platform channel's response map.
  factory BatteryRestrictionReport.fromMap(Map<String, dynamic> map) {
    return BatteryRestrictionReport(
      isExempt: map['isExempt'] as bool?,
      manufacturer: map['manufacturer'] as String?,
      canOpenSettings: map['canOpenSettings'] as bool? ?? false,
    );
  }

  /// Whether the app is on Android's battery-optimization exemption list.
  ///
  /// `true` means `PowerManager.isIgnoringBatteryOptimizations()` returned true
  /// for this package. **It does not mean background work is guaranteed to run
  /// on time.** It reports one stock-Android list; an OEM layer can still defer
  /// or kill the task, and many devices report `true` while doing exactly that.
  /// Treat it as "one known obstacle is cleared", never as a guarantee.
  ///
  /// `null` means the question has no answer here. That covers two cases the
  /// caller should treat the same way — do not prompt the user:
  ///
  ///  * **iOS**, which has no exemption concept at all; background execution is
  ///    governed by BGTaskScheduler's own budget and there is nothing to request.
  ///  * **An Android device that would not answer** — a few OEM builds throw from
  ///    `PowerManager.isIgnoringBatteryOptimizations()` rather than returning.
  ///    Reporting `null` there is deliberate: defaulting to `false` would push
  ///    apps to prompt users about a setting the plugin could not actually read.
  ///
  /// Either way [isSupported] is `false`. What `null` never means is "not
  /// exempt" — that is reported as `false`.
  final bool? isExempt;

  /// The device manufacturer, lowercased, verbatim from `Build.MANUFACTURER`.
  ///
  /// Reported so an app can word its own guidance ("on your Xiaomi device,
  /// also enable Autostart"). This library deliberately does not ship
  /// per-manufacturer settings deep links: those intents are undocumented,
  /// vary by firmware build, and silently break. Passing the raw value up lets
  /// an app decide, and lets it be wrong in its own way rather than in ours.
  ///
  /// `null` on iOS.
  final String? manufacturer;

  /// Whether the system battery-optimization settings screen can actually be
  /// opened on this device.
  ///
  /// Resolved at runtime with `PackageManager.resolveActivity`, not assumed —
  /// some devices and work profiles have no such screen. When this is `false`,
  /// `NativeWorkManager.openBatteryOptimizationSettings()` will return `false`
  /// rather than throwing.
  ///
  /// Always `false` on iOS.
  final bool canOpenSettings;

  /// Whether an exemption state could be read at all.
  ///
  /// `false` whenever [isExempt] is `null` — on iOS, and on an Android device
  /// that would not answer. Do not prompt the user in either case.
  bool get isSupported => isExempt != null;

  @override
  String toString() => 'BatteryRestrictionReport(isExempt: $isExempt, '
      'manufacturer: $manufacturer, canOpenSettings: $canOpenSettings)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatteryRestrictionReport &&
          isExempt == other.isExempt &&
          manufacturer == other.manufacturer &&
          canOpenSettings == other.canOpenSettings;

  @override
  int get hashCode => Object.hash(isExempt, manufacturer, canOpenSettings);
}

/// Why a request to disable battery optimization did not open a dialog.
enum BatteryOptimizationRequestResult {
  /// The system dialog was shown. The user's answer is not reported back
  /// synchronously — re-read `NativeWorkManager.batteryRestriction()` after the
  /// app resumes to see whether the exemption was actually granted.
  shown,

  /// The app is already exempt, so no dialog was needed.
  alreadyExempt,

  /// The host app has not declared `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` in
  /// its own `AndroidManifest.xml`.
  ///
  /// This plugin deliberately does not declare that permission: it is a
  /// Play-policy restricted permission, and a library manifest merges into
  /// every consumer app whether or not it uses the feature. Declaring it would
  /// expose apps that never call this API to a policy review they did not ask
  /// for — the same mistake that got foreground-service permissions removed
  /// from this manifest. Declare it yourself if you need the direct dialog, and
  /// be ready to justify the use case to Google Play.
  missingPermission,

  /// No activity on this device could handle the request.
  unavailable,

  /// The platform has no battery-optimization concept (iOS).
  notSupported,
}
