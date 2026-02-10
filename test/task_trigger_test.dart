import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('TaskTrigger -', () {
    group('OneTimeTrigger', () {
      test('creates with zero delay by default', () {
        const trigger = TaskTrigger.oneTime();
        expect(trigger, isA<OneTimeTrigger>());
        expect((trigger as OneTimeTrigger).initialDelay, Duration.zero);
      });

      test('creates with custom delay', () {
        const delay = Duration(minutes: 5);
        const trigger = TaskTrigger.oneTime(delay);
        expect((trigger as OneTimeTrigger).initialDelay, delay);
      });

      test('toMap() produces correct JSON', () {
        const trigger = TaskTrigger.oneTime(Duration(hours: 2));
        final map = trigger.toMap();

        expect(map['type'], 'oneTime');
        expect(map['initialDelayMs'], 2 * 60 * 60 * 1000); // 2 hours in ms
      });

      test('equality works correctly', () {
        const trigger1 = TaskTrigger.oneTime(Duration(minutes: 10));
        const trigger2 = TaskTrigger.oneTime(Duration(minutes: 10));
        const trigger3 = TaskTrigger.oneTime(Duration(minutes: 20));

        expect(trigger1, equals(trigger2));
        expect(trigger1, isNot(equals(trigger3)));
      });

      test('hashCode is consistent', () {
        const trigger1 = TaskTrigger.oneTime(Duration(minutes: 10));
        const trigger2 = TaskTrigger.oneTime(Duration(minutes: 10));

        expect(trigger1.hashCode, equals(trigger2.hashCode));
      });

      test('toString() is descriptive', () {
        const trigger = TaskTrigger.oneTime(Duration(minutes: 5));
        expect(trigger.toString(), contains('oneTime'));
        expect(trigger.toString(), contains('0:05:00'));
      });
    });

    group('PeriodicTrigger', () {
      test('creates with interval only', () {
        const interval = Duration(hours: 1);
        const trigger = TaskTrigger.periodic(interval);

        expect(trigger, isA<PeriodicTrigger>());
        expect((trigger as PeriodicTrigger).interval, interval);
        expect(trigger.flexInterval, isNull);
      });

      test('creates with flex interval', () {
        const interval = Duration(hours: 6);
        const flex = Duration(minutes: 30);
        const trigger = TaskTrigger.periodic(interval, flexInterval: flex);

        final periodicTrigger = trigger as PeriodicTrigger;
        expect(periodicTrigger.interval, interval);
        expect(periodicTrigger.flexInterval, flex);
      });

      test('toMap() produces correct JSON', () {
        const trigger = TaskTrigger.periodic(
          Duration(hours: 1),
          flexInterval: Duration(minutes: 15),
        );
        final map = trigger.toMap();

        expect(map['type'], 'periodic');
        expect(map['intervalMs'], 60 * 60 * 1000); // 1 hour
        expect(map['flexMs'], 15 * 60 * 1000); // 15 minutes
      });

      test('toMap() handles null flex interval', () {
        const trigger = TaskTrigger.periodic(Duration(hours: 1));
        final map = trigger.toMap();

        expect(map['type'], 'periodic');
        expect(map['flexMs'], isNull);
      });

      test('equality works correctly', () {
        const trigger1 = TaskTrigger.periodic(
          Duration(hours: 1),
          flexInterval: Duration(minutes: 15),
        );
        const trigger2 = TaskTrigger.periodic(
          Duration(hours: 1),
          flexInterval: Duration(minutes: 15),
        );
        const trigger3 = TaskTrigger.periodic(Duration(hours: 1));

        expect(trigger1, equals(trigger2));
        expect(trigger1, isNot(equals(trigger3)));
      });
    });

    group('ExactTrigger', () {
      test('creates with DateTime', () {
        final scheduledTime = DateTime(2026, 2, 7, 14, 30);
        final trigger = TaskTrigger.exact(scheduledTime);

        expect(trigger, isA<ExactTrigger>());
        expect((trigger as ExactTrigger).scheduledTime, scheduledTime);
      });

      test('toMap() produces correct JSON', () {
        final scheduledTime = DateTime(2026, 2, 7, 14, 30);
        final trigger = TaskTrigger.exact(scheduledTime);
        final map = trigger.toMap();

        expect(map['type'], 'exact');
        expect(map['scheduledTimeMs'], scheduledTime.millisecondsSinceEpoch);
      });

      test('equality works correctly', () {
        final time1 = DateTime(2026, 2, 7, 14, 30);
        final time2 = DateTime(2026, 2, 7, 14, 30);
        final time3 = DateTime(2026, 2, 7, 15, 30);

        final trigger1 = TaskTrigger.exact(time1);
        final trigger2 = TaskTrigger.exact(time2);
        final trigger3 = TaskTrigger.exact(time3);

        expect(trigger1, equals(trigger2));
        expect(trigger1, isNot(equals(trigger3)));
      });
    });

    group('WindowedTrigger', () {
      test('creates with earliest and latest', () {
        const earliest = Duration(hours: 1);
        const latest = Duration(hours: 2);
        const trigger = TaskTrigger.windowed(
          earliest: earliest,
          latest: latest,
        );

        expect(trigger, isA<WindowedTrigger>());
        final windowedTrigger = trigger as WindowedTrigger;
        expect(windowedTrigger.earliest, earliest);
        expect(windowedTrigger.latest, latest);
      });

      test('toMap() produces correct JSON', () {
        const trigger = TaskTrigger.windowed(
          earliest: Duration(minutes: 30),
          latest: Duration(hours: 2),
        );
        final map = trigger.toMap();

        expect(map['type'], 'windowed');
        expect(map['earliestMs'], 30 * 60 * 1000);
        expect(map['latestMs'], 2 * 60 * 60 * 1000);
      });

      test('equality works correctly', () {
        const trigger1 = TaskTrigger.windowed(
          earliest: Duration(hours: 1),
          latest: Duration(hours: 2),
        );
        const trigger2 = TaskTrigger.windowed(
          earliest: Duration(hours: 1),
          latest: Duration(hours: 2),
        );
        const trigger3 = TaskTrigger.windowed(
          earliest: Duration(hours: 1),
          latest: Duration(hours: 3),
        );

        expect(trigger1, equals(trigger2));
        expect(trigger1, isNot(equals(trigger3)));
      });
    });

    group('ContentUriTrigger', () {
      test('creates with URI', () {
        final uri = Uri.parse('content://media/external/images/media');
        final trigger = TaskTrigger.contentUri(uri: uri);

        expect(trigger, isA<ContentUriTrigger>());
        final contentTrigger = trigger as ContentUriTrigger;
        expect(contentTrigger.uri, uri);
        expect(contentTrigger.triggerForDescendants, false);
      });

      test('creates with triggerForDescendants', () {
        final uri = Uri.parse('content://media/external');
        final trigger = TaskTrigger.contentUri(
          uri: uri,
          triggerForDescendants: true,
        );

        expect((trigger as ContentUriTrigger).triggerForDescendants, true);
      });

      test('toMap() produces correct JSON', () {
        final uri = Uri.parse('content://media/external/images/media');
        final trigger = TaskTrigger.contentUri(
          uri: uri,
          triggerForDescendants: true,
        );
        final map = trigger.toMap();

        expect(map['type'], 'contentUri');
        expect(map['uriString'], uri.toString());
        expect(map['triggerForDescendants'], true);
      });

      test('equality works correctly', () {
        final uri1 = Uri.parse('content://media/external/images/media');
        final uri2 = Uri.parse('content://media/external/images/media');
        final uri3 = Uri.parse('content://media/external/video/media');

        final trigger1 = TaskTrigger.contentUri(uri: uri1);
        final trigger2 = TaskTrigger.contentUri(uri: uri2);
        final trigger3 = TaskTrigger.contentUri(uri: uri3);

        expect(trigger1, equals(trigger2));
        expect(trigger1, isNot(equals(trigger3)));
      });
    });

    group('Android-only Triggers', () {
      test('BatteryOkayTrigger creates correctly', () {
        const trigger = TaskTrigger.batteryOkay();

        expect(trigger, isA<BatteryOkayTrigger>());
        expect(trigger.toMap()['type'], 'batteryOkay');
      });

      test('BatteryLowTrigger creates correctly', () {
        const trigger = TaskTrigger.batteryLow();

        expect(trigger, isA<BatteryLowTrigger>());
        expect(trigger.toMap()['type'], 'batteryLow');
      });

      test('DeviceIdleTrigger creates correctly', () {
        const trigger = TaskTrigger.deviceIdle();

        expect(trigger, isA<DeviceIdleTrigger>());
        expect(trigger.toMap()['type'], 'deviceIdle');
      });

      test('StorageLowTrigger creates correctly', () {
        const trigger = TaskTrigger.storageLow();

        expect(trigger, isA<StorageLowTrigger>());
        expect(trigger.toMap()['type'], 'storageLow');
      });

      test('Android triggers are singletons (equality)', () {
        const trigger1 = TaskTrigger.batteryOkay();
        const trigger2 = TaskTrigger.batteryOkay();

        expect(trigger1, equals(trigger2));
        expect(trigger1.hashCode, equals(trigger2.hashCode));
      });
    });
  });
}
