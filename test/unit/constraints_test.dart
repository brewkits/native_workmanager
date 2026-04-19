import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('Constraints - Constructor', () {
    test('should create Constraints with default values', () {
      final constraints = Constraints();

      expect(constraints.requiresNetwork, isFalse);
      expect(constraints.requiresCharging, isFalse);
      expect(constraints.requiresBatteryNotLow, isFalse);
      expect(constraints.requiresStorageNotLow, isFalse);
      expect(constraints.requiresDeviceIdle, isFalse);
    });

    test('should create Constraints with requiresNetwork', () {
      final constraints = Constraints(requiresNetwork: true);

      expect(constraints.requiresNetwork, isTrue);
      expect(constraints.requiresCharging, isFalse);
      expect(constraints.requiresBatteryNotLow, isFalse);
      expect(constraints.requiresStorageNotLow, isFalse);
      expect(constraints.requiresDeviceIdle, isFalse);
    });

    test('should create Constraints with requiresCharging', () {
      final constraints = Constraints(requiresCharging: true);

      expect(constraints.requiresNetwork, isFalse);
      expect(constraints.requiresCharging, isTrue);
      expect(constraints.requiresBatteryNotLow, isFalse);
      expect(constraints.requiresStorageNotLow, isFalse);
      expect(constraints.requiresDeviceIdle, isFalse);
    });

    test('should create Constraints with requiresBatteryNotLow', () {
      final constraints = Constraints(requiresBatteryNotLow: true);

      expect(constraints.requiresNetwork, isFalse);
      expect(constraints.requiresCharging, isFalse);
      expect(constraints.requiresBatteryNotLow, isTrue);
      expect(constraints.requiresStorageNotLow, isFalse);
      expect(constraints.requiresDeviceIdle, isFalse);
    });

    test('should create Constraints with requiresStorageNotLow', () {
      final constraints = Constraints(requiresStorageNotLow: true);

      expect(constraints.requiresNetwork, isFalse);
      expect(constraints.requiresCharging, isFalse);
      expect(constraints.requiresBatteryNotLow, isFalse);
      expect(constraints.requiresStorageNotLow, isTrue);
      expect(constraints.requiresDeviceIdle, isFalse);
    });

    test('should create Constraints with requiresDeviceIdle', () {
      final constraints = Constraints(requiresDeviceIdle: true);

      expect(constraints.requiresNetwork, isFalse);
      expect(constraints.requiresCharging, isFalse);
      expect(constraints.requiresBatteryNotLow, isFalse);
      expect(constraints.requiresStorageNotLow, isFalse);
      expect(constraints.requiresDeviceIdle, isTrue);
    });

    test('should create Constraints with multiple requirements', () {
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        requiresBatteryNotLow: true,
      );

      expect(constraints.requiresNetwork, isTrue);
      expect(constraints.requiresCharging, isTrue);
      expect(constraints.requiresBatteryNotLow, isTrue);
      expect(constraints.requiresStorageNotLow, isFalse);
      expect(constraints.requiresDeviceIdle, isFalse);
    });

    test('should create Constraints with all requirements', () {
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
        requiresDeviceIdle: true,
      );

      expect(constraints.requiresNetwork, isTrue);
      expect(constraints.requiresCharging, isTrue);
      expect(constraints.requiresBatteryNotLow, isTrue);
      expect(constraints.requiresStorageNotLow, isTrue);
      expect(constraints.requiresDeviceIdle, isTrue);
    });
  });

  group('Constraints - Serialization', () {
    test('should serialize default constraints to map', () {
      final constraints = Constraints();
      final map = constraints.toMap();

      expect(map['requiresNetwork'], isFalse);
      expect(map['requiresCharging'], isFalse);
      expect(map['requiresBatteryNotLow'], isFalse);
      expect(map['requiresStorageNotLow'], isFalse);
      expect(map['requiresDeviceIdle'], isFalse);
    });

    test('should serialize constraints with requiresNetwork to map', () {
      final constraints = Constraints(requiresNetwork: true);
      final map = constraints.toMap();

      expect(map['requiresNetwork'], isTrue);
      expect(map['requiresCharging'], isFalse);
    });

    test('should serialize constraints with multiple requirements to map', () {
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        requiresBatteryNotLow: true,
      );
      final map = constraints.toMap();

      expect(map['requiresNetwork'], isTrue);
      expect(map['requiresCharging'], isTrue);
      expect(map['requiresBatteryNotLow'], isTrue);
      expect(map['requiresStorageNotLow'], isFalse);
      expect(map['requiresDeviceIdle'], isFalse);
    });

    test('should serialize constraints with all requirements to map', () {
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
        requiresDeviceIdle: true,
      );
      final map = constraints.toMap();

      expect(map['requiresNetwork'], isTrue);
      expect(map['requiresCharging'], isTrue);
      expect(map['requiresBatteryNotLow'], isTrue);
      expect(map['requiresStorageNotLow'], isTrue);
      expect(map['requiresDeviceIdle'], isTrue);
    });
  });

  group('Constraints - Edge Cases & Mixed Configurations', () {
    test('should combine boolean flags and systemConstraints', () {
      final constraints = Constraints(
        requiresNetwork: true,
        systemConstraints: {SystemConstraint.deviceIdle},
      );
      expect(constraints.requiresNetwork, isTrue);
      expect(
        constraints.systemConstraints,
        contains(SystemConstraint.deviceIdle),
      );
    });

    test('should handle bgTaskType override regardless of isHeavyTask', () {
      final constraints = Constraints(
        isHeavyTask: true,
        bgTaskType: BGTaskType.appRefresh,
      );
      expect(constraints.isHeavyTask, isTrue);
      expect(constraints.bgTaskType, BGTaskType.appRefresh);

      final map = constraints.toMap();
      expect(map['bgTaskType'], 'appRefresh');
    });

    test('should allow conflicting network constraints (WiFi vs Any)', () {
      // requiresUnmeteredNetwork implies WiFi, requiresNetwork is Any.
      // Setting both is redundant but should be allowed.
      final constraints = Constraints(
        requiresNetwork: false,
        requiresUnmeteredNetwork: true,
      );
      expect(constraints.requiresNetwork, isFalse);
      expect(constraints.requiresUnmeteredNetwork, isTrue);
    });
  });

  group('Constraints - Use Cases', () {
    test('should create constraints for background sync (network required)',
        () {
      final constraints = Constraints(requiresNetwork: true);

      expect(constraints.requiresNetwork, isTrue);
      final map = constraints.toMap();
      expect(map['requiresNetwork'], isTrue);
    });

    test('should create constraints for large download (network + charging)',
        () {
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
      );

      expect(constraints.requiresNetwork, isTrue);
      expect(constraints.requiresCharging, isTrue);
    });

    test('should create constraints for backup (charging + storage + idle)',
        () {
      final constraints = Constraints(
        requiresCharging: true,
        requiresStorageNotLow: true,
        requiresDeviceIdle: true,
      );

      expect(constraints.requiresCharging, isTrue);
      expect(constraints.requiresStorageNotLow, isTrue);
      expect(constraints.requiresDeviceIdle, isTrue);
    });

    test('should create constraints for media processing (charging + battery)',
        () {
      final constraints = Constraints(
        requiresCharging: true,
        requiresBatteryNotLow: true,
      );

      expect(constraints.requiresCharging, isTrue);
      expect(constraints.requiresBatteryNotLow, isTrue);
    });

    test('should create constraints for critical task (no constraints)', () {
      final constraints = Constraints();

      expect(constraints.requiresNetwork, isFalse);
      expect(constraints.requiresCharging, isFalse);
      expect(constraints.requiresBatteryNotLow, isFalse);
      expect(constraints.requiresStorageNotLow, isFalse);
      expect(constraints.requiresDeviceIdle, isFalse);
    });

    test('should create constraints for night maintenance (all requirements)',
        () {
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
        requiresDeviceIdle: true,
      );

      expect(constraints.requiresNetwork, isTrue);
      expect(constraints.requiresCharging, isTrue);
      expect(constraints.requiresBatteryNotLow, isTrue);
      expect(constraints.requiresStorageNotLow, isTrue);
      expect(constraints.requiresDeviceIdle, isTrue);
    });
  });

  group('Constraints - Edge Cases', () {
    test('should handle constraints with explicit false values', () {
      final constraints = Constraints(
        requiresNetwork: false,
        requiresCharging: false,
        requiresBatteryNotLow: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
      );

      expect(constraints.requiresNetwork, isFalse);
      expect(constraints.requiresCharging, isFalse);
      expect(constraints.requiresBatteryNotLow, isFalse);
      expect(constraints.requiresStorageNotLow, isFalse);
      expect(constraints.requiresDeviceIdle, isFalse);
    });

    test('should handle mixed true/false values', () {
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: false,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: false,
        requiresDeviceIdle: true,
      );

      expect(constraints.requiresNetwork, isTrue);
      expect(constraints.requiresCharging, isFalse);
      expect(constraints.requiresBatteryNotLow, isTrue);
      expect(constraints.requiresStorageNotLow, isFalse);
      expect(constraints.requiresDeviceIdle, isTrue);
    });

    test('should create multiple independent constraint instances', () {
      final constraints1 = Constraints(requiresNetwork: true);
      final constraints2 = Constraints(requiresCharging: true);
      final constraints3 = Constraints(requiresDeviceIdle: true);

      expect(constraints1.requiresNetwork, isTrue);
      expect(constraints1.requiresCharging, isFalse);

      expect(constraints2.requiresNetwork, isFalse);
      expect(constraints2.requiresCharging, isTrue);

      expect(constraints3.requiresNetwork, isFalse);
      expect(constraints3.requiresDeviceIdle, isTrue);
    });

    test('should serialize and deserialize consistently', () {
      final original = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        requiresBatteryNotLow: true,
      );

      final map = original.toMap();
      final reconstructed = Constraints(
        requiresNetwork: map['requiresNetwork'] as bool,
        requiresCharging: map['requiresCharging'] as bool,
        requiresBatteryNotLow: map['requiresBatteryNotLow'] as bool,
        requiresStorageNotLow: map['requiresStorageNotLow'] as bool,
        requiresDeviceIdle: map['requiresDeviceIdle'] as bool,
      );

      expect(reconstructed.requiresNetwork, original.requiresNetwork);
      expect(reconstructed.requiresCharging, original.requiresCharging);
      expect(
          reconstructed.requiresBatteryNotLow, original.requiresBatteryNotLow);
      expect(
          reconstructed.requiresStorageNotLow, original.requiresStorageNotLow);
      expect(reconstructed.requiresDeviceIdle, original.requiresDeviceIdle);
    });
  });

  group('Constraints - Platform Compatibility', () {
    test('should create Android-compatible constraints (network + charging)',
        () {
      // Common Android WorkManager constraints
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
        requiresDeviceIdle: true,
      );

      final map = constraints.toMap();
      expect(map['requiresNetwork'], isTrue);
      expect(map['requiresCharging'], isTrue);
      expect(map['requiresBatteryNotLow'], isTrue);
      expect(map['requiresStorageNotLow'], isTrue);
      expect(map['requiresDeviceIdle'], isTrue);
    });

    test('should create iOS-compatible constraints (network)', () {
      // iOS BGTaskScheduler primarily uses network requirement
      final constraints = Constraints(requiresNetwork: true);

      final map = constraints.toMap();
      expect(map['requiresNetwork'], isTrue);
      expect(map['requiresCharging'], isFalse);
    });

    test('should handle constraints not supported on iOS gracefully', () {
      // iOS doesn't support all constraint types, but we should still serialize them
      final constraints = Constraints(
        requiresStorageNotLow: true,
        requiresDeviceIdle: true,
      );

      final map = constraints.toMap();
      expect(map['requiresStorageNotLow'], isTrue);
      expect(map['requiresDeviceIdle'], isTrue);
    });
  });

  group('Constraints - Common Patterns', () {
    test('should create constraints for quick background task', () {
      // No constraints = run as soon as possible
      final constraints = Constraints();

      expect(constraints.requiresNetwork, isFalse);
      expect(constraints.requiresCharging, isFalse);
    });

    test('should create constraints for network-dependent task', () {
      final constraints = Constraints(requiresNetwork: true);

      expect(constraints.requiresNetwork, isTrue);
    });

    test('should create constraints for battery-intensive task', () {
      final constraints = Constraints(
        requiresCharging: true,
        requiresBatteryNotLow: true,
      );

      expect(constraints.requiresCharging, isTrue);
      expect(constraints.requiresBatteryNotLow, isTrue);
    });

    test('should create constraints for opportunistic background work', () {
      // Wait for ideal conditions
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        requiresDeviceIdle: true,
      );

      expect(constraints.requiresNetwork, isTrue);
      expect(constraints.requiresCharging, isTrue);
      expect(constraints.requiresDeviceIdle, isTrue);
    });

    test('should create constraints for data sync', () {
      final constraints = Constraints(
        requiresNetwork: true,
        requiresBatteryNotLow: true,
      );

      expect(constraints.requiresNetwork, isTrue);
      expect(constraints.requiresBatteryNotLow, isTrue);
    });

    test('should create constraints for file backup', () {
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        requiresStorageNotLow: true,
      );

      expect(constraints.requiresNetwork, isTrue);
      expect(constraints.requiresCharging, isTrue);
      expect(constraints.requiresStorageNotLow, isTrue);
    });

    test('should create constraints for media upload', () {
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
      );

      expect(constraints.requiresNetwork, isTrue);
      expect(constraints.requiresCharging, isTrue);
    });

    test('should create constraints for database cleanup', () {
      final constraints = Constraints(
        requiresDeviceIdle: true,
        requiresStorageNotLow: true,
      );

      expect(constraints.requiresDeviceIdle, isTrue);
      expect(constraints.requiresStorageNotLow, isTrue);
    });
  });

  group('Constraints - Validation Logic', () {
    test('should allow no constraints for immediate execution', () {
      final constraints = Constraints();
      final map = constraints.toMap();

      // All false = no constraints = immediate execution
      expect(map['requiresNetwork'], isFalse);
      expect(map['requiresCharging'], isFalse);
      expect(map['requiresBatteryNotLow'], isFalse);
      expect(map['requiresStorageNotLow'], isFalse);
      expect(map['requiresDeviceIdle'], isFalse);
    });

    test('should allow single constraint', () {
      final constraints = Constraints(requiresNetwork: true);
      final map = constraints.toMap();

      expect(map.values.where((value) => value == true).length, 1);
    });

    test('should allow multiple constraints', () {
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        requiresBatteryNotLow: true,
      );
      final map = constraints.toMap();

      expect(map.values.where((value) => value == true).length, 3);
    });

    test('should allow all constraints simultaneously', () {
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
        requiresDeviceIdle: true,
      );
      final map = constraints.toMap();

      expect(map.values.where((value) => value == true).length, 5);
    });
  });

  group('Constraints - Realistic Scenarios', () {
    test('scenario: photo backup to cloud', () {
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        requiresBatteryNotLow: true,
      );

      final map = constraints.toMap();
      expect(map['requiresNetwork'], isTrue);
      expect(map['requiresCharging'], isTrue);
      expect(map['requiresBatteryNotLow'], isTrue);
    });

    test('scenario: fetch news articles', () {
      final constraints = Constraints(requiresNetwork: true);

      final map = constraints.toMap();
      expect(map['requiresNetwork'], isTrue);
    });

    test('scenario: local database maintenance', () {
      final constraints = Constraints(
        requiresDeviceIdle: true,
        requiresStorageNotLow: true,
      );

      final map = constraints.toMap();
      expect(map['requiresDeviceIdle'], isTrue);
      expect(map['requiresStorageNotLow'], isTrue);
    });

    test('scenario: critical notification check', () {
      // No constraints - must run ASAP
      final constraints = Constraints();

      final map = constraints.toMap();
      expect(map['requiresNetwork'], isFalse);
      expect(map['requiresCharging'], isFalse);
      expect(map['requiresBatteryNotLow'], isFalse);
      expect(map['requiresStorageNotLow'], isFalse);
      expect(map['requiresDeviceIdle'], isFalse);
    });

    test('scenario: overnight full sync', () {
      final constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
        requiresDeviceIdle: true,
      );

      final map = constraints.toMap();
      expect(map['requiresNetwork'], isTrue);
      expect(map['requiresCharging'], isTrue);
      expect(map['requiresBatteryNotLow'], isTrue);
      expect(map['requiresStorageNotLow'], isTrue);
      expect(map['requiresDeviceIdle'], isTrue);
    });

    test('scenario: video processing', () {
      final constraints = Constraints(
        requiresCharging: true,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
      );

      final map = constraints.toMap();
      expect(map['requiresCharging'], isTrue);
      expect(map['requiresBatteryNotLow'], isTrue);
      expect(map['requiresStorageNotLow'], isTrue);
    });

    test('scenario: quick API call', () {
      final constraints = Constraints(requiresNetwork: true);

      final map = constraints.toMap();
      expect(map['requiresNetwork'], isTrue);
      expect(map['requiresCharging'], isFalse);
      expect(map['requiresDeviceIdle'], isFalse);
    });

    test('scenario: analytics upload', () {
      final constraints = Constraints(
        requiresNetwork: true,
        requiresBatteryNotLow: true,
      );

      final map = constraints.toMap();
      expect(map['requiresNetwork'], isTrue);
      expect(map['requiresBatteryNotLow'], isTrue);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Tests covering bug-fixed fields: systemConstraints, bgTaskType,
  // foregroundServiceType — previously missing from operator== and hashCode.
  // ────────────────────────────────────────────────────────────────────────────

  group('Constraints - Equality (operator==)', () {
    test('identical values are equal', () {
      final a = Constraints(requiresNetwork: true);
      final b = Constraints(requiresNetwork: true);
      expect(a, equals(b));
    });

    test('different basic fields are not equal', () {
      final a = Constraints(requiresNetwork: true);
      final b = Constraints(requiresNetwork: false);
      expect(a, isNot(equals(b)));
    });

    test('systemConstraints: same set is equal', () {
      final a = Constraints(systemConstraints: {SystemConstraint.deviceIdle});
      final b = Constraints(systemConstraints: {SystemConstraint.deviceIdle});
      expect(a, equals(b));
    });

    test('systemConstraints: different sets are not equal', () {
      final a = Constraints(systemConstraints: {SystemConstraint.deviceIdle});
      final b =
          Constraints(systemConstraints: {SystemConstraint.allowLowBattery});
      expect(a, isNot(equals(b)));
    });

    test('systemConstraints: empty vs non-empty is not equal', () {
      final a = Constraints();
      final b = Constraints(systemConstraints: {SystemConstraint.deviceIdle});
      expect(a, isNot(equals(b)));
    });

    test('systemConstraints: order-independent set equality', () {
      final a = Constraints(systemConstraints: {
        SystemConstraint.deviceIdle,
        SystemConstraint.allowLowStorage,
      });
      final b = Constraints(systemConstraints: {
        SystemConstraint.allowLowStorage,
        SystemConstraint.deviceIdle,
      });
      expect(a, equals(b));
    });

    test('bgTaskType: same value is equal', () {
      final a = Constraints(bgTaskType: BGTaskType.appRefresh);
      final b = Constraints(bgTaskType: BGTaskType.appRefresh);
      expect(a, equals(b));
    });

    test('bgTaskType: different values are not equal', () {
      final a = Constraints(bgTaskType: BGTaskType.appRefresh);
      final b = Constraints(bgTaskType: BGTaskType.processing);
      expect(a, isNot(equals(b)));
    });

    test('bgTaskType: null vs non-null is not equal', () {
      final a = Constraints();
      final b = Constraints(bgTaskType: BGTaskType.appRefresh);
      expect(a, isNot(equals(b)));
    });

    test('foregroundServiceType: same value is equal', () {
      final a =
          Constraints(foregroundServiceType: ForegroundServiceType.dataSync);
      final b =
          Constraints(foregroundServiceType: ForegroundServiceType.dataSync);
      expect(a, equals(b));
    });

    test('foregroundServiceType: different values are not equal', () {
      final a =
          Constraints(foregroundServiceType: ForegroundServiceType.dataSync);
      final b =
          Constraints(foregroundServiceType: ForegroundServiceType.location);
      expect(a, isNot(equals(b)));
    });

    test('foregroundServiceType: null vs non-null is not equal', () {
      final a = Constraints();
      final b =
          Constraints(foregroundServiceType: ForegroundServiceType.camera);
      expect(a, isNot(equals(b)));
    });

    test('all three new fields equal simultaneously', () {
      final a = Constraints(
        systemConstraints: {SystemConstraint.deviceIdle},
        bgTaskType: BGTaskType.processing,
        foregroundServiceType: ForegroundServiceType.location,
      );
      final b = Constraints(
        systemConstraints: {SystemConstraint.deviceIdle},
        bgTaskType: BGTaskType.processing,
        foregroundServiceType: ForegroundServiceType.location,
      );
      expect(a, equals(b));
    });
  });

  group('Constraints - hashCode', () {
    test('equal objects have same hashCode', () {
      final a = Constraints(requiresNetwork: true);
      final b = Constraints(requiresNetwork: true);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('systemConstraints affects hashCode', () {
      final withConstraint = Constraints(
        systemConstraints: {SystemConstraint.deviceIdle},
      );
      final withoutConstraint = Constraints();
      expect(
          withConstraint.hashCode, isNot(equals(withoutConstraint.hashCode)));
    });

    test('bgTaskType affects hashCode', () {
      final withType = Constraints(bgTaskType: BGTaskType.processing);
      final withoutType = Constraints();
      expect(withType.hashCode, isNot(equals(withoutType.hashCode)));
    });

    test('foregroundServiceType affects hashCode', () {
      final withType = Constraints(
        foregroundServiceType: ForegroundServiceType.location,
      );
      final withoutType = Constraints();
      expect(withType.hashCode, isNot(equals(withoutType.hashCode)));
    });

    test('can be used as Map key (hashCode + == consistent)', () {
      final c1 = Constraints(
        requiresNetwork: true,
        systemConstraints: {SystemConstraint.deviceIdle},
        bgTaskType: BGTaskType.appRefresh,
        foregroundServiceType: ForegroundServiceType.dataSync,
      );
      final c2 = Constraints(
        requiresNetwork: true,
        systemConstraints: {SystemConstraint.deviceIdle},
        bgTaskType: BGTaskType.appRefresh,
        foregroundServiceType: ForegroundServiceType.dataSync,
      );

      final map = {c1: 'value'};
      expect(map[c2], 'value');
    });
  });

  group('Constraints - systemConstraints serialization', () {
    test('empty systemConstraints serializes to empty list', () {
      final c = Constraints();
      final map = c.toMap();
      expect(map['systemConstraints'], isEmpty);
    });

    test('single systemConstraint serializes by name', () {
      final c = Constraints(systemConstraints: {SystemConstraint.deviceIdle});
      final map = c.toMap();
      expect(map['systemConstraints'], ['deviceIdle']);
    });

    test('multiple systemConstraints serialize correctly', () {
      final c = Constraints(systemConstraints: {
        SystemConstraint.allowLowStorage,
        SystemConstraint.allowLowBattery,
      });
      final list = c.toMap()['systemConstraints'] as List;
      expect(list, containsAll(['allowLowStorage', 'allowLowBattery']));
      expect(list.length, 2);
    });

    test('all SystemConstraint values serialize by their enum name', () {
      for (final constraint in SystemConstraint.values) {
        final c = Constraints(systemConstraints: {constraint});
        final list = c.toMap()['systemConstraints'] as List;
        expect(list, [constraint.name]);
      }
    });
  });

  group('Constraints - bgTaskType serialization', () {
    test('null bgTaskType serializes to null', () {
      final c = Constraints();
      expect(c.toMap()['bgTaskType'], isNull);
    });

    test('appRefresh bgTaskType serializes as "appRefresh"', () {
      final c = Constraints(bgTaskType: BGTaskType.appRefresh);
      expect(c.toMap()['bgTaskType'], 'appRefresh');
    });

    test('processing bgTaskType serializes as "processing"', () {
      final c = Constraints(bgTaskType: BGTaskType.processing);
      expect(c.toMap()['bgTaskType'], 'processing');
    });

    test('all BGTaskType values serialize by their enum name', () {
      for (final type in BGTaskType.values) {
        final c = Constraints(bgTaskType: type);
        expect(c.toMap()['bgTaskType'], type.name);
      }
    });
  });

  group('Constraints - foregroundServiceType serialization', () {
    test('null foregroundServiceType serializes to null', () {
      final c = Constraints();
      expect(c.toMap()['foregroundServiceType'], isNull);
    });

    test('dataSync foregroundServiceType serializes as "dataSync"', () {
      final c =
          Constraints(foregroundServiceType: ForegroundServiceType.dataSync);
      expect(c.toMap()['foregroundServiceType'], 'dataSync');
    });

    test('all ForegroundServiceType values serialize by their enum name', () {
      for (final type in ForegroundServiceType.values) {
        final c = Constraints(foregroundServiceType: type);
        expect(c.toMap()['foregroundServiceType'], type.name);
      }
    });
  });

  group('Constraints - fromMap round-trip for new fields', () {
    test('round-trips systemConstraints', () {
      final original = Constraints(systemConstraints: {
        SystemConstraint.deviceIdle,
        SystemConstraint.allowLowBattery,
      });
      final restored = Constraints.fromMap(original.toMap());
      expect(restored.systemConstraints, original.systemConstraints);
      expect(restored, original);
    });

    test('round-trips empty systemConstraints', () {
      final original = Constraints();
      final restored = Constraints.fromMap(original.toMap());
      expect(restored.systemConstraints, isEmpty);
    });

    test('round-trips bgTaskType appRefresh', () {
      final original = Constraints(bgTaskType: BGTaskType.appRefresh);
      final restored = Constraints.fromMap(original.toMap());
      expect(restored.bgTaskType, BGTaskType.appRefresh);
      expect(restored, original);
    });

    test('round-trips bgTaskType processing', () {
      final original = Constraints(bgTaskType: BGTaskType.processing);
      final restored = Constraints.fromMap(original.toMap());
      expect(restored.bgTaskType, BGTaskType.processing);
      expect(restored, original);
    });

    test('round-trips null bgTaskType', () {
      final original = Constraints();
      final restored = Constraints.fromMap(original.toMap());
      expect(restored.bgTaskType, isNull);
    });

    test('round-trips foregroundServiceType location', () {
      final original = Constraints(
        foregroundServiceType: ForegroundServiceType.location,
      );
      final restored = Constraints.fromMap(original.toMap());
      expect(restored.foregroundServiceType, ForegroundServiceType.location);
      expect(restored, original);
    });

    test('round-trips null foregroundServiceType', () {
      final original = Constraints();
      final restored = Constraints.fromMap(original.toMap());
      expect(restored.foregroundServiceType, isNull);
    });

    test('round-trips all three new fields together', () {
      final original = Constraints(
        systemConstraints: {SystemConstraint.requireBatteryNotLow},
        bgTaskType: BGTaskType.processing,
        foregroundServiceType: ForegroundServiceType.camera,
      );
      final restored = Constraints.fromMap(original.toMap());
      expect(restored, original);
    });
  });

  group('Constraints - copyWith for new fields', () {
    test('copyWith systemConstraints replaces set', () {
      final original = Constraints();
      final updated = original.copyWith(
        systemConstraints: {SystemConstraint.deviceIdle},
      );
      expect(updated.systemConstraints, {SystemConstraint.deviceIdle});
      expect(original.systemConstraints, isEmpty); // original unchanged
    });

    test('copyWith bgTaskType changes type', () {
      final original = Constraints();
      final updated = original.copyWith(bgTaskType: BGTaskType.processing);
      expect(updated.bgTaskType, BGTaskType.processing);
      expect(original.bgTaskType, isNull); // original unchanged
    });

    test('copyWith foregroundServiceType changes type', () {
      final original = Constraints();
      final updated = original.copyWith(
        foregroundServiceType: ForegroundServiceType.camera,
      );
      expect(updated.foregroundServiceType, ForegroundServiceType.camera);
      expect(original.foregroundServiceType, isNull); // original unchanged
    });

    test('copyWith preserves unmodified fields', () {
      final original = Constraints(
        requiresNetwork: true,
        systemConstraints: {SystemConstraint.deviceIdle},
        bgTaskType: BGTaskType.appRefresh,
        foregroundServiceType: ForegroundServiceType.dataSync,
      );
      final updated = original.copyWith(requiresCharging: true);
      expect(updated.requiresNetwork, isTrue);
      expect(updated.requiresCharging, isTrue);
      expect(updated.systemConstraints, {SystemConstraint.deviceIdle});
      expect(updated.bgTaskType, BGTaskType.appRefresh);
      expect(updated.foregroundServiceType, ForegroundServiceType.dataSync);
    });
  });
}
