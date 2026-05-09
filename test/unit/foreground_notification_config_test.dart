import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('ForegroundNotificationConfig - Rigorous Unit Tests', () {
    test('Constructor: should enforce default values for optional parameters',
        () {
      const config = ForegroundNotificationConfig(
        title: 'Title',
        body: 'Body',
      );

      expect(config.showCancelButton, isTrue, reason: 'Default should be true');
      expect(config.cancelText, 'Cancel', reason: 'Default should be "Cancel"');
      expect(config.iconName, isNull);
      expect(config.colorHex, isNull);
    });

    test('Serialization: toMap/fromMap should be perfectly symmetric', () {
      const original = ForegroundNotificationConfig(
        title: 'Custom Title',
        body: 'Custom Body',
        iconName: 'ic_launcher',
        colorHex: '#FF0000',
        showCancelButton: false,
        cancelText: 'Stop Task',
      );

      final map = original.toMap();
      final restored = ForegroundNotificationConfig.fromMap(map);

      expect(restored, equals(original));
      expect(restored.title, original.title);
      expect(restored.body, original.body);
      expect(restored.iconName, original.iconName);
      expect(restored.colorHex, original.colorHex);
      expect(restored.showCancelButton, original.showCancelButton);
      expect(restored.cancelText, original.cancelText);
    });

    test(
        'Resiliency: fromMap should handle partial or malformed maps without crashing',
        () {
      // Case 1: Minimal map
      final minMap = {'title': 'T', 'body': 'B'};
      final config1 = ForegroundNotificationConfig.fromMap(minMap);
      expect(config1.title, 'T');
      expect(config1.showCancelButton, isTrue); // Should fallback to default

      // Case 2: Map with extra/unknown keys (forward compatibility)
      final extraMap = {
        'title': 'T',
        'body': 'B',
        'unknown_key': 123,
      };
      final config2 = ForegroundNotificationConfig.fromMap(extraMap);
      expect(config2.title, 'T');

      // Case 3: Map with nulls where non-nulls expected (defensive check)
      final nullMap = {
        'title': 'T',
        'body': 'B',
        'showCancelButton': null,
        'cancelText': null,
      };
      final config3 = ForegroundNotificationConfig.fromMap(nullMap);
      expect(config3.showCancelButton, isTrue,
          reason: 'Null in map should trigger default');
      expect(config3.cancelText, 'Cancel');
    });

    test('Equality: should differentiate even small changes', () {
      const base = ForegroundNotificationConfig(title: 'A', body: 'B');

      expect(base,
          equals(const ForegroundNotificationConfig(title: 'A', body: 'B')));
      expect(
          base,
          isNot(equals(
              const ForegroundNotificationConfig(title: 'A ', body: 'B'))));
      expect(
          base,
          isNot(equals(const ForegroundNotificationConfig(
              title: 'A', body: 'B', showCancelButton: false))));
    });
  });

  group('Constraints Integration - Rigorous Regression Tests', () {
    test('Backward Compatibility: fromMap MUST handle absence of FGS config',
        () {
      final legacyMap = {
        'requiresNetwork': true,
        'isHeavyTask': true,
        'qos': 'default',
        // 'foregroundNotificationConfig' is missing
      };

      // This test ensures that when an older version of the app (or persisted task)
      // is loaded, it doesn't crash or behave unexpectedly.
      final constraints = Constraints.fromMap(legacyMap);

      expect(constraints.requiresNetwork, isTrue);
      expect(constraints.foregroundNotificationConfig, isNull);
    });

    test('Data Integrity: toMap should NOT include null fgsConfig key', () {
      final constraints = Constraints(requiresNetwork: true);
      final map = constraints.toMap();

      expect(map.containsKey('foregroundNotificationConfig'), isFalse,
          reason: 'Map should be lean and not contain null keys for FGS');
    });

    test(
        'Identity: copyWith should preserve FGS config when changing other fields',
        () {
      const fgs = ForegroundNotificationConfig(title: 'T', body: 'B');
      final original = Constraints(
        requiresNetwork: false,
        foregroundNotificationConfig: fgs,
      );

      final updated = original.copyWith(requiresNetwork: true);

      expect(updated.requiresNetwork, isTrue);
      expect(updated.foregroundNotificationConfig, equals(fgs),
          reason: 'FGS config should be carried over during copyWith');
    });

    test('Identity: copyWith should allow updating only the FGS config', () {
      final original = Constraints(requiresNetwork: true);
      const newFgs = ForegroundNotificationConfig(title: 'New', body: 'New');

      final updated = original.copyWith(foregroundNotificationConfig: newFgs);

      expect(updated.requiresNetwork, isTrue);
      expect(updated.foregroundNotificationConfig, equals(newFgs));
    });

    test('Full Cycle: Dart -> Map -> Dart parity', () {
      const fgs = ForegroundNotificationConfig(
        title: 'Lifecycle Test',
        body: 'Testing full path',
        colorHex: '#AABBCC',
      );
      final original = Constraints(
        requiresCharging: true,
        foregroundNotificationConfig: fgs,
        backoffDelayMs: 5000,
      );

      final map = original.toMap();
      final restored = Constraints.fromMap(map);

      expect(restored, equals(original));
      expect(restored.foregroundNotificationConfig, isNotNull);
      expect(restored.foregroundNotificationConfig!.colorHex, '#AABBCC');
    });
  });
}
