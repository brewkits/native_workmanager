/// Bridge Parameter Passthrough Tests
///
/// Verifies that every parameter Dart emits in toMap() uses the exact key name
/// and value type that the native bridges expect to parse.
///
/// These tests guard against:
/// - Key name typos (e.g. 'interval' instead of 'intervalMs')
/// - Wrong value types (e.g. int where bool is expected)
/// - Silent null emission for required fields
/// - Missing fields that the bridge would silently default
///
/// If a test here fails, the bridge will silently produce wrong behavior —
/// not a crash — because bridges defensively default missing/wrong values.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/src/task_trigger.dart';

void main() {
  group('Bridge Parameter Passthrough', () {
    group('PeriodicTrigger map keys and types', () {
      test('all expected keys are present', () {
        final map = TaskTrigger.periodic(
          const Duration(hours: 1),
          flexInterval: const Duration(minutes: 30),
          initialDelay: const Duration(minutes: 5),
          runImmediately: false,
        ).toMap();

        // These are the exact keys the bridges look up — any rename breaks silently.
        expect(map.containsKey('type'), isTrue);
        expect(map.containsKey('intervalMs'), isTrue);
        expect(map.containsKey('flexMs'), isTrue);
        expect(map.containsKey('initialDelayMs'), isTrue);
        expect(map.containsKey('runImmediately'), isTrue);
      });

      test('type value is exactly "periodic"', () {
        final map = TaskTrigger.periodic(const Duration(hours: 1)).toMap();
        expect(map['type'], equals('periodic'));
      });

      test('intervalMs is int (milliseconds)', () {
        final map = TaskTrigger.periodic(const Duration(hours: 2)).toMap();
        expect(map['intervalMs'], isA<int>());
        expect(map['intervalMs'], equals(const Duration(hours: 2).inMilliseconds));
      });

      test('flexMs is int when set, null when absent', () {
        final withFlex = TaskTrigger.periodic(
          const Duration(hours: 1),
          flexInterval: const Duration(minutes: 20),
        ).toMap();
        expect(withFlex['flexMs'], isA<int>());
        expect(withFlex['flexMs'], equals(const Duration(minutes: 20).inMilliseconds));

        final noFlex = TaskTrigger.periodic(const Duration(hours: 1)).toMap();
        expect(noFlex['flexMs'], isNull);
      });

      test('initialDelayMs is int when set, null when absent', () {
        final withDelay = TaskTrigger.periodic(
          const Duration(hours: 1),
          initialDelay: const Duration(minutes: 15),
        ).toMap();
        expect(withDelay['initialDelayMs'], isA<int>());
        expect(withDelay['initialDelayMs'],
            equals(const Duration(minutes: 15).inMilliseconds));

        final noDelay = TaskTrigger.periodic(const Duration(hours: 1)).toMap();
        expect(noDelay['initialDelayMs'], isNull);
      });

      test('runImmediately is bool', () {
        final trueMap =
            TaskTrigger.periodic(const Duration(hours: 1)).toMap();
        expect(trueMap['runImmediately'], isA<bool>());
        expect(trueMap['runImmediately'], isTrue);

        final falseMap = TaskTrigger.periodic(
          const Duration(hours: 1),
          runImmediately: false,
        ).toMap();
        expect(falseMap['runImmediately'], isA<bool>());
        expect(falseMap['runImmediately'], isFalse);
      });
    });

    group('OneTimeTrigger map keys and types', () {
      test('all expected keys are present', () {
        final map =
            TaskTrigger.oneTime(const Duration(minutes: 5)).toMap();
        expect(map.containsKey('type'), isTrue);
        expect(map.containsKey('initialDelayMs'), isTrue);
      });

      test('type is exactly "oneTime"', () {
        final map = TaskTrigger.oneTime().toMap();
        expect(map['type'], equals('oneTime'));
      });

      test('initialDelayMs is int (milliseconds)', () {
        final map =
            TaskTrigger.oneTime(const Duration(minutes: 10)).toMap();
        expect(map['initialDelayMs'], isA<int>());
        expect(
            map['initialDelayMs'], equals(const Duration(minutes: 10).inMilliseconds));
      });

      test('zero delay emits 0 not null', () {
        final map = TaskTrigger.oneTime().toMap();
        expect(map['initialDelayMs'], equals(0));
      });
    });

    group('ExactTrigger map keys and types', () {
      test('all expected keys are present', () {
        final map = TaskTrigger.exact(DateTime(2030)).toMap();
        expect(map.containsKey('type'), isTrue);
        expect(map.containsKey('scheduledTimeMs'), isTrue);
      });

      test('type is exactly "exact"', () {
        final map = TaskTrigger.exact(DateTime(2030)).toMap();
        expect(map['type'], equals('exact'));
      });

      test('scheduledTimeMs is epoch milliseconds as int', () {
        final dt = DateTime(2030, 6, 15, 10, 0, 0);
        final map = TaskTrigger.exact(dt).toMap();
        expect(map['scheduledTimeMs'], isA<int>());
        expect(map['scheduledTimeMs'], equals(dt.millisecondsSinceEpoch));
      });
    });

    group('WindowedTrigger map keys and types', () {
      test('all expected keys are present', () {
        final map = TaskTrigger.windowed(
          earliest: const Duration(hours: 1),
          latest: const Duration(hours: 2),
        ).toMap();
        expect(map.containsKey('type'), isTrue);
        expect(map.containsKey('earliestMs'), isTrue);
        expect(map.containsKey('latestMs'), isTrue);
      });

      test('type is exactly "windowed"', () {
        final map = TaskTrigger.windowed(
          earliest: const Duration(hours: 1),
          latest: const Duration(hours: 2),
        ).toMap();
        expect(map['type'], equals('windowed'));
      });

      test('earliestMs and latestMs are int milliseconds', () {
        final map = TaskTrigger.windowed(
          earliest: const Duration(hours: 1),
          latest: const Duration(hours: 3),
        ).toMap();
        expect(map['earliestMs'], isA<int>());
        expect(map['latestMs'], isA<int>());
        expect(map['earliestMs'], equals(const Duration(hours: 1).inMilliseconds));
        expect(map['latestMs'], equals(const Duration(hours: 3).inMilliseconds));
      });
    });
  });
}
