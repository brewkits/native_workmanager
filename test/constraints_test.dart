import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('Constraints -', () {
    group('Default Construction', () {
      test('creates with all defaults', () {
        const constraints = Constraints();

        expect(constraints.requiresNetwork, false);
        expect(constraints.requiresUnmeteredNetwork, false);
        expect(constraints.requiresCharging, false);
        expect(constraints.requiresDeviceIdle, false);
        expect(constraints.requiresBatteryNotLow, false);
        expect(constraints.requiresStorageNotLow, false);
        expect(constraints.allowWhileIdle, false);
        expect(constraints.isHeavyTask, false);
        expect(constraints.qos, QoS.background);
        expect(constraints.exactAlarmIOSBehavior,
            ExactAlarmIOSBehavior.showNotification);
        expect(constraints.backoffPolicy, BackoffPolicy.exponential);
        expect(constraints.backoffDelayMs, 30000);
        expect(constraints.systemConstraints, isEmpty);
        expect(constraints.bgTaskType, isNull);
        expect(constraints.foregroundServiceType, isNull);
      });

      test('creates with custom values', () {
        const constraints = Constraints(
          requiresNetwork: true,
          requiresCharging: true,
          isHeavyTask: true,
          qos: QoS.userInitiated,
          backoffDelayMs: 60000,
        );

        expect(constraints.requiresNetwork, true);
        expect(constraints.requiresCharging, true);
        expect(constraints.isHeavyTask, true);
        expect(constraints.qos, QoS.userInitiated);
        expect(constraints.backoffDelayMs, 60000);
      });
    });

    group('Static Presets', () {
      test('networkRequired preset', () {
        const constraints = Constraints.networkRequired;

        expect(constraints.requiresNetwork, true);
        expect(constraints.requiresCharging, false);
      });

      test('heavyTask preset', () {
        const constraints = Constraints.heavyTask;

        expect(constraints.requiresUnmeteredNetwork, true);
        expect(constraints.requiresCharging, true);
      });

      test('none preset', () {
        const constraints = Constraints.none;

        expect(constraints.requiresNetwork, false);
        expect(constraints.requiresCharging, false);
        expect(constraints.isHeavyTask, false);
      });
    });

    group('toMap()', () {
      test('serializes all fields correctly', () {
        const constraints = Constraints(
          requiresNetwork: true,
          requiresUnmeteredNetwork: true,
          requiresCharging: true,
          requiresDeviceIdle: true,
          requiresBatteryNotLow: true,
          requiresStorageNotLow: true,
          allowWhileIdle: true,
          isHeavyTask: true,
          qos: QoS.utility,
          exactAlarmIOSBehavior: ExactAlarmIOSBehavior.attemptBackgroundRun,
          backoffPolicy: BackoffPolicy.linear,
          backoffDelayMs: 15000,
        );

        final map = constraints.toMap();

        expect(map['requiresNetwork'], true);
        expect(map['requiresUnmeteredNetwork'], true);
        expect(map['requiresCharging'], true);
        expect(map['requiresDeviceIdle'], true);
        expect(map['requiresBatteryNotLow'], true);
        expect(map['requiresStorageNotLow'], true);
        expect(map['allowWhileIdle'], true);
        expect(map['isHeavyTask'], true);
        expect(map['qos'], 'utility');
        expect(map['exactAlarmIOSBehavior'], 'attemptBackgroundRun');
        expect(map['backoffPolicy'], 'linear');
        expect(map['backoffDelayMs'], 15000);
      });

      test('serializes system constraints', () {
        const constraints = Constraints(
          systemConstraints: {
            SystemConstraint.deviceIdle,
            SystemConstraint.allowLowBattery,
          },
        );

        final map = constraints.toMap();
        final systemConstraints = map['systemConstraints'] as List;

        expect(systemConstraints, contains('deviceIdle'));
        expect(systemConstraints, contains('allowLowBattery'));
        expect(systemConstraints.length, 2);
      });

      test('serializes bgTaskType', () {
        const constraints = Constraints(
          bgTaskType: BGTaskType.processing,
        );

        final map = constraints.toMap();
        expect(map['bgTaskType'], 'processing');
      });

      test('serializes foregroundServiceType', () {
        const constraints = Constraints(
          foregroundServiceType: ForegroundServiceType.location,
        );

        final map = constraints.toMap();
        expect(map['foregroundServiceType'], 'location');
      });

      test('null values serialize correctly', () {
        const constraints = Constraints();
        final map = constraints.toMap();

        expect(map['bgTaskType'], isNull);
        expect(map['foregroundServiceType'], isNull);
      });
    });

    group('fromMap()', () {
      test('deserializes all fields correctly', () {
        final map = {
          'requiresNetwork': true,
          'requiresUnmeteredNetwork': true,
          'requiresCharging': true,
          'requiresDeviceIdle': true,
          'requiresBatteryNotLow': true,
          'requiresStorageNotLow': true,
          'allowWhileIdle': true,
          'isHeavyTask': true,
          'qos': 'utility',
          'exactAlarmIOSBehavior': 'attemptBackgroundRun',
          'backoffPolicy': 'linear',
          'backoffDelayMs': 15000,
        };

        final constraints = Constraints.fromMap(map);

        expect(constraints.requiresNetwork, true);
        expect(constraints.requiresUnmeteredNetwork, true);
        expect(constraints.requiresCharging, true);
        expect(constraints.requiresDeviceIdle, true);
        expect(constraints.requiresBatteryNotLow, true);
        expect(constraints.requiresStorageNotLow, true);
        expect(constraints.allowWhileIdle, true);
        expect(constraints.isHeavyTask, true);
        expect(constraints.qos, QoS.utility);
        expect(constraints.exactAlarmIOSBehavior,
            ExactAlarmIOSBehavior.attemptBackgroundRun);
        expect(constraints.backoffPolicy, BackoffPolicy.linear);
        expect(constraints.backoffDelayMs, 15000);
      });

      test('deserializes system constraints', () {
        final map = {
          'systemConstraints': ['deviceIdle', 'allowLowBattery'],
        };

        final constraints = Constraints.fromMap(map);

        expect(constraints.systemConstraints,
            contains(SystemConstraint.deviceIdle));
        expect(constraints.systemConstraints,
            contains(SystemConstraint.allowLowBattery));
      });

      test('deserializes nullable fields', () {
        final map = {
          'bgTaskType': 'processing',
          'foregroundServiceType': 'location',
        };

        final constraints = Constraints.fromMap(map);

        expect(constraints.bgTaskType, BGTaskType.processing);
        expect(constraints.foregroundServiceType, ForegroundServiceType.location);
      });

      test('handles missing fields with defaults', () {
        final map = <String, dynamic>{};
        final constraints = Constraints.fromMap(map);

        expect(constraints.requiresNetwork, false);
        expect(constraints.qos, QoS.background);
        expect(constraints.backoffDelayMs, 30000);
        expect(constraints.systemConstraints, isEmpty);
      });
    });

    group('copyWith()', () {
      test('copies with updated values', () {
        const original = Constraints(
          requiresNetwork: true,
          requiresCharging: false,
        );

        final updated = original.copyWith(
          requiresCharging: true,
          isHeavyTask: true,
        );

        expect(updated.requiresNetwork, true); // preserved
        expect(updated.requiresCharging, true); // updated
        expect(updated.isHeavyTask, true); // updated
      });

      test('preserves all fields when nothing updated', () {
        const original = Constraints(
          requiresNetwork: true,
          requiresCharging: true,
          isHeavyTask: true,
        );

        final copy = original.copyWith();

        expect(copy.requiresNetwork, original.requiresNetwork);
        expect(copy.requiresCharging, original.requiresCharging);
        expect(copy.isHeavyTask, original.isHeavyTask);
      });

      test('can update system constraints', () {
        const original = Constraints(
          systemConstraints: {SystemConstraint.deviceIdle},
        );

        final updated = original.copyWith(
          systemConstraints: {
            SystemConstraint.allowLowBattery,
            SystemConstraint.allowLowStorage,
          },
        );

        expect(updated.systemConstraints,
            contains(SystemConstraint.allowLowBattery));
        expect(updated.systemConstraints,
            isNot(contains(SystemConstraint.deviceIdle)));
      });
    });

    group('Equality', () {
      test('equal constraints are equal', () {
        const constraints1 = Constraints(
          requiresNetwork: true,
          requiresCharging: true,
          isHeavyTask: true,
        );

        const constraints2 = Constraints(
          requiresNetwork: true,
          requiresCharging: true,
          isHeavyTask: true,
        );

        expect(constraints1, equals(constraints2));
        expect(constraints1.hashCode, equals(constraints2.hashCode));
      });

      test('different constraints are not equal', () {
        const constraints1 = Constraints(requiresNetwork: true);
        const constraints2 = Constraints(requiresNetwork: false);

        expect(constraints1, isNot(equals(constraints2)));
      });

      test('static presets are equal', () {
        const preset1 = Constraints.networkRequired;
        const preset2 = Constraints.networkRequired;

        expect(preset1, equals(preset2));
      });
    });

    group('toString()', () {
      test('provides readable output', () {
        const constraints = Constraints(
          requiresNetwork: true,
          requiresCharging: true,
          isHeavyTask: true,
        );

        final str = constraints.toString();

        expect(str, contains('Constraints'));
        expect(str, contains('network: true'));
        expect(str, contains('charging: true'));
        expect(str, contains('heavy: true'));
      });
    });

    group('Enums', () {
      test('BackoffPolicy has correct values', () {
        expect(BackoffPolicy.values, hasLength(2));
        expect(BackoffPolicy.values, contains(BackoffPolicy.exponential));
        expect(BackoffPolicy.values, contains(BackoffPolicy.linear));
      });

      test('QoS has correct values', () {
        expect(QoS.values, hasLength(4));
        expect(QoS.values, contains(QoS.utility));
        expect(QoS.values, contains(QoS.background));
        expect(QoS.values, contains(QoS.userInitiated));
        expect(QoS.values, contains(QoS.userInteractive));
      });

      test('ExactAlarmIOSBehavior has correct values', () {
        expect(ExactAlarmIOSBehavior.values, hasLength(3));
        expect(ExactAlarmIOSBehavior.values,
            contains(ExactAlarmIOSBehavior.showNotification));
        expect(ExactAlarmIOSBehavior.values,
            contains(ExactAlarmIOSBehavior.attemptBackgroundRun));
        expect(ExactAlarmIOSBehavior.values,
            contains(ExactAlarmIOSBehavior.throwError));
      });

      test('SystemConstraint has correct values', () {
        expect(SystemConstraint.values, hasLength(4));
        expect(SystemConstraint.values,
            contains(SystemConstraint.allowLowStorage));
        expect(SystemConstraint.values,
            contains(SystemConstraint.allowLowBattery));
        expect(SystemConstraint.values,
            contains(SystemConstraint.requireBatteryNotLow));
        expect(SystemConstraint.values, contains(SystemConstraint.deviceIdle));
      });

      test('BGTaskType has correct values', () {
        expect(BGTaskType.values, hasLength(2));
        expect(BGTaskType.values, contains(BGTaskType.appRefresh));
        expect(BGTaskType.values, contains(BGTaskType.processing));
      });

      test('ForegroundServiceType has correct values', () {
        expect(ForegroundServiceType.values, hasLength(6));
        expect(ForegroundServiceType.values,
            contains(ForegroundServiceType.dataSync));
        expect(ForegroundServiceType.values,
            contains(ForegroundServiceType.location));
        expect(ForegroundServiceType.values,
            contains(ForegroundServiceType.mediaPlayback));
        expect(ForegroundServiceType.values,
            contains(ForegroundServiceType.camera));
        expect(ForegroundServiceType.values,
            contains(ForegroundServiceType.microphone));
        expect(ForegroundServiceType.values,
            contains(ForegroundServiceType.health));
      });
    });
  });
}
