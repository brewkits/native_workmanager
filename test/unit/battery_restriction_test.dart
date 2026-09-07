import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Tests for the Android battery-restriction diagnostics.
///
/// These exercise the Dart consumer against a forwarded-args fixture rather than
/// only checking serialisation, per the Issue #30 rule: a `toMap` round trip does
/// not catch a bridge that stops forwarding a field. Every test here drives
/// `NativeWorkManager` through the real method channel with a mock handler, so it
/// fails if the channel name, the method name, or a map key changes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.brewkits/native_workmanager');

  /// Installs a handler returning [responses] keyed by method name, and records
  /// which methods were actually invoked.
  List<String> installHandler(Map<String, Object?> responses) {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call.method);
      if (call.method == 'initialize') return null;
      return responses[call.method];
    });
    return calls;
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('BatteryRestrictionReport model', () {
    test('fromMap reads every field the Android bridge sends', () {
      final report = BatteryRestrictionReport.fromMap(const {
        'isExempt': true,
        'manufacturer': 'xiaomi',
        'canOpenSettings': true,
      });

      expect(report.isExempt, isTrue);
      expect(report.manufacturer, equals('xiaomi'));
      expect(report.canOpenSettings, isTrue);
      expect(report.isSupported, isTrue);
    });

    test('a null isExempt means "no such concept", not "not exempt"', () {
      // This is the iOS shape. The distinction matters: an app must be able to
      // tell "we asked and the answer is no" from "there is nothing to ask".
      final report = BatteryRestrictionReport.fromMap(const {
        'isExempt': null,
        'manufacturer': null,
        'canOpenSettings': false,
      });

      expect(report.isExempt, isNull);
      expect(report.isSupported, isFalse);
      expect(report.isExempt, isNot(equals(false)));
    });

    test('canOpenSettings defaults to false when the platform omits it', () {
      final report =
          BatteryRestrictionReport.fromMap(const {'isExempt': false});
      expect(report.canOpenSettings, isFalse);
    });

    test('value equality holds', () {
      const a = BatteryRestrictionReport(
        isExempt: false,
        manufacturer: 'samsung',
        canOpenSettings: true,
      );
      const b = BatteryRestrictionReport(
        isExempt: false,
        manufacturer: 'samsung',
        canOpenSettings: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('batteryRestriction() over the channel', () {
    test('forwards the platform report unchanged', () async {
      final calls = installHandler({
        'batteryRestriction': <Object?, Object?>{
          'isExempt': false,
          'manufacturer': 'xiaomi',
          'canOpenSettings': true,
        },
      });

      final report = await NativeWorkManager.batteryRestriction();

      expect(calls, contains('batteryRestriction'));
      expect(report.isExempt, isFalse);
      expect(report.manufacturer, equals('xiaomi'));
      expect(report.canOpenSettings, isTrue);
    });

    test('is a pure diagnostic — callable without initialize()', () async {
      // Deliberate: an app checks this during startup to decide whether to
      // prompt, which can happen before initialize() completes. If this ever
      // starts throwing a "not initialized" error, that is a regression.
      installHandler({
        'batteryRestriction': <Object?, Object?>{'isExempt': true},
      });

      await expectLater(NativeWorkManager.batteryRestriction(), completes);
    });

    test('a platform that does not implement the call reports unsupported',
        () async {
      installHandler({'batteryRestriction': null});

      final report = await NativeWorkManager.batteryRestriction();

      // Must not throw at a diagnostics call site, and must not claim the app
      // is un-exempt when the platform simply never answered.
      expect(report.isSupported, isFalse);
      expect(report.isExempt, isNull);
    });
  });

  group('openBatteryOptimizationSettings()', () {
    test('returns what the platform reports', () async {
      final calls = installHandler({'openBatteryOptimizationSettings': true});

      expect(await NativeWorkManager.openBatteryOptimizationSettings(), isTrue);
      expect(calls, contains('openBatteryOptimizationSettings'));
    });

    test('a null platform answer is false, not an exception', () async {
      installHandler({'openBatteryOptimizationSettings': null});
      expect(
          await NativeWorkManager.openBatteryOptimizationSettings(), isFalse);
    });
  });

  group('requestDisableBatteryOptimization()', () {
    /// The exact strings the Android bridge sends. If either side renames one,
    /// the pair stops matching and this table fails.
    const cases = <String, BatteryOptimizationRequestResult>{
      'shown': BatteryOptimizationRequestResult.shown,
      'alreadyExempt': BatteryOptimizationRequestResult.alreadyExempt,
      'missingPermission': BatteryOptimizationRequestResult.missingPermission,
      'unavailable': BatteryOptimizationRequestResult.unavailable,
      'notSupported': BatteryOptimizationRequestResult.notSupported,
    };

    for (final entry in cases.entries) {
      test('maps "${entry.key}" to ${entry.value.name}', () async {
        installHandler({'requestDisableBatteryOptimization': entry.key});
        expect(
          await NativeWorkManager.requestDisableBatteryOptimization(),
          equals(entry.value),
        );
      });
    }

    test('an unrecognised platform value degrades to unavailable', () async {
      installHandler({'requestDisableBatteryOptimization': 'wat'});
      expect(
        await NativeWorkManager.requestDisableBatteryOptimization(),
        equals(BatteryOptimizationRequestResult.unavailable),
      );
    });

    test('missingPermission is distinct from unavailable', () async {
      // These mean different things to a caller: one is "fix your manifest",
      // the other is "this device cannot do it". Collapsing them would make the
      // Play-policy opt-in undiagnosable.
      expect(
        BatteryOptimizationRequestResult.missingPermission,
        isNot(equals(BatteryOptimizationRequestResult.unavailable)),
      );
    });
  });
}
