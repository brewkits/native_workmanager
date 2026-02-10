import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Comprehensive unit tests for TaskTrigger API.
///
/// Tests all trigger types:
/// - OneTimeTrigger (immediate & delayed)
/// - PeriodicTrigger (with/without flex)
/// - ExactTrigger (specific DateTime)
/// - WindowedTrigger (time range)
/// - ContentUriTrigger (Android only)
/// - Battery triggers (Android only)
/// - Device triggers (Android only)
/// - Storage triggers (Android only)
void main() {
  group('TaskTrigger', () {
    group('OneTimeTrigger', () {
      test('should create immediate oneTime trigger', () {
        final trigger = TaskTrigger.oneTime();

        expect(trigger, isA<OneTimeTrigger>());
        expect((trigger as OneTimeTrigger).initialDelay, Duration.zero);
      });

      test('should create delayed oneTime trigger', () {
        final trigger = TaskTrigger.oneTime(Duration(minutes: 5));

        expect(trigger, isA<OneTimeTrigger>());
        expect((trigger as OneTimeTrigger).initialDelay, Duration(minutes: 5));
      });

      test('should serialize immediate oneTime to map', () {
        final trigger = TaskTrigger.oneTime();
        final map = trigger.toMap();

        expect(map['type'], 'oneTime');
        expect(map['initialDelayMs'], 0);
      });

      test('should serialize delayed oneTime to map', () {
        final trigger = TaskTrigger.oneTime(Duration(hours: 2));
        final map = trigger.toMap();

        expect(map['type'], 'oneTime');
        expect(map['initialDelayMs'], Duration(hours: 2).inMilliseconds);
      });

      test('should support equality', () {
        final trigger1 = TaskTrigger.oneTime(Duration(minutes: 30));
        final trigger2 = TaskTrigger.oneTime(Duration(minutes: 30));
        final trigger3 = TaskTrigger.oneTime(Duration(minutes: 60));

        expect(trigger1, equals(trigger2));
        expect(trigger1, isNot(equals(trigger3)));
      });

      test('should support hashCode', () {
        final trigger1 = TaskTrigger.oneTime(Duration(minutes: 30));
        final trigger2 = TaskTrigger.oneTime(Duration(minutes: 30));

        expect(trigger1.hashCode, equals(trigger2.hashCode));
      });

      test('should have proper toString', () {
        final trigger = TaskTrigger.oneTime(Duration(seconds: 45));
        final str = trigger.toString();

        expect(str, contains('TaskTrigger.oneTime'));
        expect(str, contains('0:00:45'));
      });
    });

    group('PeriodicTrigger', () {
      test('should create periodic trigger without flex', () {
        final trigger = TaskTrigger.periodic(Duration(hours: 1));

        expect(trigger, isA<PeriodicTrigger>());
        expect((trigger as PeriodicTrigger).interval, Duration(hours: 1));
        expect(trigger.flexInterval, isNull);
      });

      test('should create periodic trigger with flex', () {
        final trigger = TaskTrigger.periodic(
          Duration(hours: 6),
          flexInterval: Duration(minutes: 30),
        );

        expect(trigger, isA<PeriodicTrigger>());
        expect((trigger as PeriodicTrigger).interval, Duration(hours: 6));
        expect(trigger.flexInterval, Duration(minutes: 30));
      });

      test('should serialize periodic without flex to map', () {
        final trigger = TaskTrigger.periodic(Duration(hours: 1));
        final map = trigger.toMap();

        expect(map['type'], 'periodic');
        expect(map['intervalMs'], Duration(hours: 1).inMilliseconds);
        expect(map['flexMs'], isNull);
      });

      test('should serialize periodic with flex to map', () {
        final trigger = TaskTrigger.periodic(
          Duration(hours: 6),
          flexInterval: Duration(minutes: 30),
        );
        final map = trigger.toMap();

        expect(map['type'], 'periodic');
        expect(map['intervalMs'], Duration(hours: 6).inMilliseconds);
        expect(map['flexMs'], Duration(minutes: 30).inMilliseconds);
      });

      test('should support minimum interval (15 minutes)', () {
        final trigger = TaskTrigger.periodic(Duration(minutes: 15));

        expect((trigger as PeriodicTrigger).interval, Duration(minutes: 15));
      });

      test('should support equality', () {
        final trigger1 = TaskTrigger.periodic(Duration(hours: 1));
        final trigger2 = TaskTrigger.periodic(Duration(hours: 1));
        final trigger3 = TaskTrigger.periodic(
          Duration(hours: 1),
          flexInterval: Duration(minutes: 15),
        );

        expect(trigger1, equals(trigger2));
        expect(trigger1, isNot(equals(trigger3)));
      });

      test('should support hashCode', () {
        final trigger1 = TaskTrigger.periodic(Duration(hours: 2));
        final trigger2 = TaskTrigger.periodic(Duration(hours: 2));

        expect(trigger1.hashCode, equals(trigger2.hashCode));
      });

      test('should have proper toString', () {
        final trigger = TaskTrigger.periodic(
          Duration(hours: 1),
          flexInterval: Duration(minutes: 15),
        );
        final str = trigger.toString();

        expect(str, contains('TaskTrigger.periodic'));
        expect(str, contains('1:00:00'));
        expect(str, contains('0:15:00'));
      });
    });

    group('ExactTrigger', () {
      test('should create exact trigger with DateTime', () {
        final scheduledTime = DateTime(2026, 2, 1, 9, 0);
        final trigger = TaskTrigger.exact(scheduledTime);

        expect(trigger, isA<ExactTrigger>());
        expect((trigger as ExactTrigger).scheduledTime, scheduledTime);
      });

      test('should serialize exact trigger to map', () {
        final scheduledTime = DateTime(2026, 2, 1, 9, 0);
        final trigger = TaskTrigger.exact(scheduledTime);
        final map = trigger.toMap();

        expect(map['type'], 'exact');
        expect(map['scheduledTimeMs'], scheduledTime.millisecondsSinceEpoch);
      });

      test('should support future DateTime', () {
        final futureTime = DateTime.now().add(Duration(hours: 2));
        final trigger = TaskTrigger.exact(futureTime);

        expect((trigger as ExactTrigger).scheduledTime, futureTime);
      });

      test('should support equality', () {
        final time = DateTime(2026, 2, 1, 9, 0);
        final trigger1 = TaskTrigger.exact(time);
        final trigger2 = TaskTrigger.exact(time);
        final trigger3 = TaskTrigger.exact(DateTime(2026, 2, 1, 10, 0));

        expect(trigger1, equals(trigger2));
        expect(trigger1, isNot(equals(trigger3)));
      });

      test('should support hashCode', () {
        final time = DateTime(2026, 2, 1, 9, 0);
        final trigger1 = TaskTrigger.exact(time);
        final trigger2 = TaskTrigger.exact(time);

        expect(trigger1.hashCode, equals(trigger2.hashCode));
      });

      test('should have proper toString', () {
        final time = DateTime(2026, 2, 1, 9, 0);
        final trigger = TaskTrigger.exact(time);
        final str = trigger.toString();

        expect(str, contains('TaskTrigger.exact'));
        expect(str, contains('2026-02-01'));
      });
    });

    group('WindowedTrigger', () {
      test('should create windowed trigger', () {
        final trigger = TaskTrigger.windowed(
          earliest: Duration(hours: 1),
          latest: Duration(hours: 2),
        );

        expect(trigger, isA<WindowedTrigger>());
        expect((trigger as WindowedTrigger).earliest, Duration(hours: 1));
        expect(trigger.latest, Duration(hours: 2));
      });

      test('should serialize windowed trigger to map', () {
        final trigger = TaskTrigger.windowed(
          earliest: Duration(hours: 1),
          latest: Duration(hours: 2),
        );
        final map = trigger.toMap();

        expect(map['type'], 'windowed');
        expect(map['earliestMs'], Duration(hours: 1).inMilliseconds);
        expect(map['latestMs'], Duration(hours: 2).inMilliseconds);
      });

      test('should support narrow time window', () {
        final trigger = TaskTrigger.windowed(
          earliest: Duration(minutes: 30),
          latest: Duration(minutes: 45),
        );

        expect((trigger as WindowedTrigger).earliest, Duration(minutes: 30));
        expect(trigger.latest, Duration(minutes: 45));
      });

      test('should support wide time window', () {
        final trigger = TaskTrigger.windowed(
          earliest: Duration(hours: 6),
          latest: Duration(hours: 8),
        );

        expect((trigger as WindowedTrigger).earliest, Duration(hours: 6));
        expect(trigger.latest, Duration(hours: 8));
      });

      test('should support equality', () {
        final trigger1 = TaskTrigger.windowed(
          earliest: Duration(hours: 1),
          latest: Duration(hours: 2),
        );
        final trigger2 = TaskTrigger.windowed(
          earliest: Duration(hours: 1),
          latest: Duration(hours: 2),
        );
        final trigger3 = TaskTrigger.windowed(
          earliest: Duration(hours: 2),
          latest: Duration(hours: 3),
        );

        expect(trigger1, equals(trigger2));
        expect(trigger1, isNot(equals(trigger3)));
      });

      test('should support hashCode', () {
        final trigger1 = TaskTrigger.windowed(
          earliest: Duration(hours: 1),
          latest: Duration(hours: 2),
        );
        final trigger2 = TaskTrigger.windowed(
          earliest: Duration(hours: 1),
          latest: Duration(hours: 2),
        );

        expect(trigger1.hashCode, equals(trigger2.hashCode));
      });

      test('should have proper toString', () {
        final trigger = TaskTrigger.windowed(
          earliest: Duration(hours: 1),
          latest: Duration(hours: 2),
        );
        final str = trigger.toString();

        expect(str, contains('TaskTrigger.windowed'));
        expect(str, contains('1:00:00'));
        expect(str, contains('2:00:00'));
      });
    });

    group('ContentUriTrigger', () {
      test('should create contentUri trigger without descendants', () {
        final uri = Uri.parse('content://media/external/images/media');
        final trigger = TaskTrigger.contentUri(
          uri: uri,
          triggerForDescendants: false,
        );

        expect(trigger, isA<ContentUriTrigger>());
        expect((trigger as ContentUriTrigger).uri, uri);
        expect(trigger.triggerForDescendants, isFalse);
      });

      test('should create contentUri trigger with descendants', () {
        final uri = Uri.parse('content://media/external/images/media');
        final trigger = TaskTrigger.contentUri(
          uri: uri,
          triggerForDescendants: true,
        );

        expect(trigger, isA<ContentUriTrigger>());
        expect((trigger as ContentUriTrigger).uri, uri);
        expect(trigger.triggerForDescendants, isTrue);
      });

      test('should serialize contentUri to map', () {
        final uri = Uri.parse('content://media/external/images/media');
        final trigger = TaskTrigger.contentUri(
          uri: uri,
          triggerForDescendants: true,
        );
        final map = trigger.toMap();

        expect(map['type'], 'contentUri');
        expect(map['uriString'], 'content://media/external/images/media');
        expect(map['triggerForDescendants'], isTrue);
      });

      test('should support MediaStore images URI', () {
        final trigger = TaskTrigger.contentUri(
          uri: Uri.parse('content://media/external/images/media'),
          triggerForDescendants: true,
        );

        expect((trigger as ContentUriTrigger).uri.toString(),
            'content://media/external/images/media');
      });

      test('should support contacts URI', () {
        final trigger = TaskTrigger.contentUri(
          uri: Uri.parse('content://com.android.contacts/contacts'),
          triggerForDescendants: false,
        );

        expect((trigger as ContentUriTrigger).uri.toString(),
            'content://com.android.contacts/contacts');
      });

      test('should support equality', () {
        final uri = Uri.parse('content://media/external/images/media');
        final trigger1 = TaskTrigger.contentUri(
          uri: uri,
          triggerForDescendants: true,
        );
        final trigger2 = TaskTrigger.contentUri(
          uri: uri,
          triggerForDescendants: true,
        );
        final trigger3 = TaskTrigger.contentUri(
          uri: uri,
          triggerForDescendants: false,
        );

        expect(trigger1, equals(trigger2));
        expect(trigger1, isNot(equals(trigger3)));
      });

      test('should support hashCode', () {
        final uri = Uri.parse('content://media/external/images/media');
        final trigger1 = TaskTrigger.contentUri(
          uri: uri,
          triggerForDescendants: true,
        );
        final trigger2 = TaskTrigger.contentUri(
          uri: uri,
          triggerForDescendants: true,
        );

        expect(trigger1.hashCode, equals(trigger2.hashCode));
      });

      test('should have proper toString', () {
        final uri = Uri.parse('content://media/external/images/media');
        final trigger = TaskTrigger.contentUri(
          uri: uri,
          triggerForDescendants: true,
        );
        final str = trigger.toString();

        expect(str, contains('TaskTrigger.contentUri'));
        expect(str, contains('content://media/external/images/media'));
        expect(str, contains('descendants: true'));
      });
    });

    group('BatteryOkayTrigger', () {
      test('should create batteryOkay trigger', () {
        final trigger = TaskTrigger.batteryOkay();

        expect(trigger, isA<BatteryOkayTrigger>());
      });

      test('should serialize batteryOkay to map', () {
        final trigger = TaskTrigger.batteryOkay();
        final map = trigger.toMap();

        expect(map['type'], 'batteryOkay');
      });

      test('should support equality', () {
        final trigger1 = TaskTrigger.batteryOkay();
        final trigger2 = TaskTrigger.batteryOkay();

        expect(trigger1, equals(trigger2));
      });

      test('should have consistent hashCode', () {
        final trigger1 = TaskTrigger.batteryOkay();
        final trigger2 = TaskTrigger.batteryOkay();

        expect(trigger1.hashCode, equals(trigger2.hashCode));
      });

      test('should have proper toString', () {
        final trigger = TaskTrigger.batteryOkay();
        final str = trigger.toString();

        expect(str, 'TaskTrigger.batteryOkay()');
      });
    });

    group('BatteryLowTrigger', () {
      test('should create batteryLow trigger', () {
        final trigger = TaskTrigger.batteryLow();

        expect(trigger, isA<BatteryLowTrigger>());
      });

      test('should serialize batteryLow to map', () {
        final trigger = TaskTrigger.batteryLow();
        final map = trigger.toMap();

        expect(map['type'], 'batteryLow');
      });

      test('should support equality', () {
        final trigger1 = TaskTrigger.batteryLow();
        final trigger2 = TaskTrigger.batteryLow();

        expect(trigger1, equals(trigger2));
      });

      test('should have consistent hashCode', () {
        final trigger1 = TaskTrigger.batteryLow();
        final trigger2 = TaskTrigger.batteryLow();

        expect(trigger1.hashCode, equals(trigger2.hashCode));
      });

      test('should have proper toString', () {
        final trigger = TaskTrigger.batteryLow();
        final str = trigger.toString();

        expect(str, 'TaskTrigger.batteryLow()');
      });
    });

    group('DeviceIdleTrigger', () {
      test('should create deviceIdle trigger', () {
        final trigger = TaskTrigger.deviceIdle();

        expect(trigger, isA<DeviceIdleTrigger>());
      });

      test('should serialize deviceIdle to map', () {
        final trigger = TaskTrigger.deviceIdle();
        final map = trigger.toMap();

        expect(map['type'], 'deviceIdle');
      });

      test('should support equality', () {
        final trigger1 = TaskTrigger.deviceIdle();
        final trigger2 = TaskTrigger.deviceIdle();

        expect(trigger1, equals(trigger2));
      });

      test('should have consistent hashCode', () {
        final trigger1 = TaskTrigger.deviceIdle();
        final trigger2 = TaskTrigger.deviceIdle();

        expect(trigger1.hashCode, equals(trigger2.hashCode));
      });

      test('should have proper toString', () {
        final trigger = TaskTrigger.deviceIdle();
        final str = trigger.toString();

        expect(str, 'TaskTrigger.deviceIdle()');
      });
    });

    group('StorageLowTrigger', () {
      test('should create storageLow trigger', () {
        final trigger = TaskTrigger.storageLow();

        expect(trigger, isA<StorageLowTrigger>());
      });

      test('should serialize storageLow to map', () {
        final trigger = TaskTrigger.storageLow();
        final map = trigger.toMap();

        expect(map['type'], 'storageLow');
      });

      test('should support equality', () {
        final trigger1 = TaskTrigger.storageLow();
        final trigger2 = TaskTrigger.storageLow();

        expect(trigger1, equals(trigger2));
      });

      test('should have consistent hashCode', () {
        final trigger1 = TaskTrigger.storageLow();
        final trigger2 = TaskTrigger.storageLow();

        expect(trigger1.hashCode, equals(trigger2.hashCode));
      });

      test('should have proper toString', () {
        final trigger = TaskTrigger.storageLow();
        final str = trigger.toString();

        expect(str, 'TaskTrigger.storageLow()');
      });
    });

    group('Common Use Cases', () {
      test('should create trigger for immediate task', () {
        final trigger = TaskTrigger.oneTime();

        expect((trigger as OneTimeTrigger).initialDelay, Duration.zero);
      });

      test('should create trigger for delayed notification', () {
        final trigger = TaskTrigger.oneTime(Duration(minutes: 5));

        expect((trigger as OneTimeTrigger).initialDelay, Duration(minutes: 5));
      });

      test('should create trigger for hourly sync', () {
        final trigger = TaskTrigger.periodic(Duration(hours: 1));

        expect((trigger as PeriodicTrigger).interval, Duration(hours: 1));
      });

      test('should create trigger for daily cleanup', () {
        final trigger = TaskTrigger.periodic(Duration(days: 1));

        expect((trigger as PeriodicTrigger).interval, Duration(days: 1));
      });

      test('should create trigger for morning alarm', () {
        final tomorrow9am = DateTime.now()
            .add(Duration(days: 1))
            .copyWith(hour: 9, minute: 0, second: 0);
        final trigger = TaskTrigger.exact(tomorrow9am);

        expect((trigger as ExactTrigger).scheduledTime, tomorrow9am);
      });

      test('should create trigger for flexible overnight task', () {
        final trigger = TaskTrigger.windowed(
          earliest: Duration(hours: 6),
          latest: Duration(hours: 8),
        );

        expect((trigger as WindowedTrigger).earliest, Duration(hours: 6));
        expect(trigger.latest, Duration(hours: 8));
      });

      test('should create trigger for photo backup on new media', () {
        final trigger = TaskTrigger.contentUri(
          uri: Uri.parse('content://media/external/images/media'),
          triggerForDescendants: true,
        );

        expect(trigger, isA<ContentUriTrigger>());
        expect((trigger as ContentUriTrigger).triggerForDescendants, isTrue);
      });

      test('should create trigger for safe backup when battery okay', () {
        final trigger = TaskTrigger.batteryOkay();

        expect(trigger, isA<BatteryOkayTrigger>());
      });

      test('should create trigger for low battery warning', () {
        final trigger = TaskTrigger.batteryLow();

        expect(trigger, isA<BatteryLowTrigger>());
      });

      test('should create trigger for maintenance during idle', () {
        final trigger = TaskTrigger.deviceIdle();

        expect(trigger, isA<DeviceIdleTrigger>());
      });

      test('should create trigger for emergency cleanup on low storage', () {
        final trigger = TaskTrigger.storageLow();

        expect(trigger, isA<StorageLowTrigger>());
      });
    });

    group('Edge Cases', () {
      test('should handle zero delay oneTime', () {
        final trigger = TaskTrigger.oneTime(Duration.zero);

        expect((trigger as OneTimeTrigger).initialDelay, Duration.zero);
      });

      test('should handle very long delay', () {
        final trigger = TaskTrigger.oneTime(Duration(days: 365));

        expect((trigger as OneTimeTrigger).initialDelay, Duration(days: 365));
      });

      test('should handle minimum periodic interval (15 minutes)', () {
        final trigger = TaskTrigger.periodic(Duration(minutes: 15));

        expect((trigger as PeriodicTrigger).interval, Duration(minutes: 15));
      });

      test('should handle periodic with zero flex', () {
        final trigger = TaskTrigger.periodic(
          Duration(hours: 1),
          flexInterval: Duration.zero,
        );

        expect((trigger as PeriodicTrigger).flexInterval, Duration.zero);
      });

      test('should handle past DateTime in exact trigger', () {
        final pastTime = DateTime(2020, 1, 1);
        final trigger = TaskTrigger.exact(pastTime);

        expect((trigger as ExactTrigger).scheduledTime, pastTime);
      });

      test('should handle same earliest and latest in windowed', () {
        final trigger = TaskTrigger.windowed(
          earliest: Duration(hours: 1),
          latest: Duration(hours: 1),
        );

        expect((trigger as WindowedTrigger).earliest, Duration(hours: 1));
        expect(trigger.latest, Duration(hours: 1));
      });

      test('should handle contentUri with empty descendants flag', () {
        final trigger = TaskTrigger.contentUri(
          uri: Uri.parse('content://test'),
          triggerForDescendants: false,
        );

        expect((trigger as ContentUriTrigger).triggerForDescendants, isFalse);
      });
    });

    group('Serialization Round-Trip', () {
      test('should round-trip oneTime trigger', () {
        final original = TaskTrigger.oneTime(Duration(minutes: 30));
        final map = original.toMap();

        expect(map['type'], 'oneTime');
        expect(map['initialDelayMs'], Duration(minutes: 30).inMilliseconds);
      });

      test('should round-trip periodic trigger', () {
        final original = TaskTrigger.periodic(
          Duration(hours: 2),
          flexInterval: Duration(minutes: 15),
        );
        final map = original.toMap();

        expect(map['type'], 'periodic');
        expect(map['intervalMs'], Duration(hours: 2).inMilliseconds);
        expect(map['flexMs'], Duration(minutes: 15).inMilliseconds);
      });

      test('should round-trip exact trigger', () {
        final time = DateTime(2026, 2, 1, 9, 0);
        final original = TaskTrigger.exact(time);
        final map = original.toMap();

        expect(map['type'], 'exact');
        expect(map['scheduledTimeMs'], time.millisecondsSinceEpoch);
      });

      test('should round-trip windowed trigger', () {
        final original = TaskTrigger.windowed(
          earliest: Duration(hours: 1),
          latest: Duration(hours: 2),
        );
        final map = original.toMap();

        expect(map['type'], 'windowed');
        expect(map['earliestMs'], Duration(hours: 1).inMilliseconds);
        expect(map['latestMs'], Duration(hours: 2).inMilliseconds);
      });

      test('should round-trip contentUri trigger', () {
        final uri = Uri.parse('content://media/external/images/media');
        final original = TaskTrigger.contentUri(
          uri: uri,
          triggerForDescendants: true,
        );
        final map = original.toMap();

        expect(map['type'], 'contentUri');
        expect(map['uriString'], uri.toString());
        expect(map['triggerForDescendants'], isTrue);
      });

      test('should round-trip battery triggers', () {
        final batteryOkay = TaskTrigger.batteryOkay().toMap();
        final batteryLow = TaskTrigger.batteryLow().toMap();

        expect(batteryOkay['type'], 'batteryOkay');
        expect(batteryLow['type'], 'batteryLow');
      });

      test('should round-trip device triggers', () {
        final deviceIdle = TaskTrigger.deviceIdle().toMap();
        final storageLow = TaskTrigger.storageLow().toMap();

        expect(deviceIdle['type'], 'deviceIdle');
        expect(storageLow['type'], 'storageLow');
      });
    });
  });
}
