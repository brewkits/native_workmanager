import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('BackoffPolicy Tests', () {
    test('BackoffPolicy enum has correct values', () {
      expect(BackoffPolicy.values.length, 2);
      expect(BackoffPolicy.values, contains(BackoffPolicy.exponential));
      expect(BackoffPolicy.values, contains(BackoffPolicy.linear));
    });

    test('BackoffPolicy toString returns correct values', () {
      expect(BackoffPolicy.exponential.toString(), 'BackoffPolicy.exponential');
      expect(BackoffPolicy.linear.toString(), 'BackoffPolicy.linear');
    });

    test('BackoffPolicy equality works', () {
      expect(BackoffPolicy.exponential, equals(BackoffPolicy.exponential));
      expect(BackoffPolicy.linear, equals(BackoffPolicy.linear));
      expect(BackoffPolicy.exponential, isNot(equals(BackoffPolicy.linear)));
    });
  });

  group('ContentUri Trigger Tests', () {
    test('ContentUriTrigger creates with required uri', () {
      final uri = Uri.parse('content://media/external/images/media');
      final trigger = TaskTrigger.contentUri(uri: uri, triggerForDescendants: false);

      expect(trigger, isA<ContentUriTrigger>());
      expect((trigger as ContentUriTrigger).uri, equals(uri));
      expect(trigger.triggerForDescendants, isFalse);
    });

    test('ContentUriTrigger creates with triggerForDescendants', () {
      final uri = Uri.parse('content://media/external/images/media');
      final trigger = TaskTrigger.contentUri(
        uri: uri,
        triggerForDescendants: true,
      );

      expect(trigger, isA<ContentUriTrigger>());
      expect((trigger as ContentUriTrigger).uri, equals(uri));
      expect(trigger.triggerForDescendants, isTrue);
    });

    test('ContentUriTrigger toMap serializes correctly', () {
      final uri = Uri.parse('content://media/external/images/media');
      final trigger = TaskTrigger.contentUri(
        uri: uri,
        triggerForDescendants: true,
      );

      final map = trigger.toMap();

      expect(map['type'], equals('contentUri'));
      expect(map['uriString'], equals(uri.toString()));
      expect(map['triggerForDescendants'], isTrue);
    });

    test('ContentUriTrigger toMap with false triggerForDescendants', () {
      final uri = Uri.parse('content://com.android.contacts/contacts');
      final trigger = TaskTrigger.contentUri(
        uri: uri,
        triggerForDescendants: false,
      );

      final map = trigger.toMap();

      expect(map['type'], equals('contentUri'));
      expect(map['uriString'], equals(uri.toString()));
      expect(map['triggerForDescendants'], isFalse);
    });

    test('ContentUriTrigger equality works', () {
      final uri1 = Uri.parse('content://media/external/images/media');
      final uri2 = Uri.parse('content://media/external/images/media');
      final uri3 = Uri.parse('content://media/external/video/media');

      final trigger1 = TaskTrigger.contentUri(uri: uri1, triggerForDescendants: false);
      final trigger2 = TaskTrigger.contentUri(uri: uri2, triggerForDescendants: false);
      final trigger3 = TaskTrigger.contentUri(uri: uri3, triggerForDescendants: false);
      final trigger4 = TaskTrigger.contentUri(uri: uri1, triggerForDescendants: true);

      expect(trigger1, equals(trigger2));
      expect(trigger1, isNot(equals(trigger3)));
      expect(trigger1, isNot(equals(trigger4))); // Different triggerForDescendants
    });

    test('ContentUriTrigger handles various content URIs', () {
      final testUris = [
        'content://media/external/images/media',
        'content://media/external/video/media',
        'content://media/external/audio/media',
        'content://com.android.contacts/contacts',
        'content://com.android.calendar/events',
      ];

      for (final uriString in testUris) {
        final uri = Uri.parse(uriString);
        final trigger = TaskTrigger.contentUri(uri: uri, triggerForDescendants: false);

        expect((trigger as ContentUriTrigger).uri, equals(uri));
        expect(trigger.toMap()['uriString'], equals(uriString));
      }
    });
  });

  group('Constraints with BackoffPolicy Tests', () {
    test('Constraints creates with default backoffPolicy', () {
      const constraints = Constraints();

      expect(constraints.backoffPolicy, equals(BackoffPolicy.exponential));
      expect(constraints.backoffDelayMs, equals(30000));
    });

    test('Constraints creates with custom backoffPolicy', () {
      const constraints = Constraints(
        backoffPolicy: BackoffPolicy.linear,
        backoffDelayMs: 60000,
      );

      expect(constraints.backoffPolicy, equals(BackoffPolicy.linear));
      expect(constraints.backoffDelayMs, equals(60000));
    });

    test('Constraints toMap includes backoffPolicy fields', () {
      const constraints = Constraints(
        requiresNetwork: true,
        backoffPolicy: BackoffPolicy.exponential,
        backoffDelayMs: 45000,
      );

      final map = constraints.toMap();

      expect(map['requiresNetwork'], isTrue);
      expect(map['backoffPolicy'], equals('exponential'));
      expect(map['backoffDelayMs'], equals(45000));
    });

    test('Constraints toMap converts BackoffPolicy enum correctly', () {
      const exponential = Constraints(backoffPolicy: BackoffPolicy.exponential);
      const linear = Constraints(backoffPolicy: BackoffPolicy.linear);

      expect(exponential.toMap()['backoffPolicy'], equals('exponential'));
      expect(linear.toMap()['backoffPolicy'], equals('linear'));
    });

    test('Constraints fromMap parses backoffPolicy fields', () {
      final map = {
        'requiresNetwork': true,
        'backoffPolicy': 'linear',
        'backoffDelayMs': 20000,
      };

      final constraints = Constraints.fromMap(map);

      expect(constraints.requiresNetwork, isTrue);
      expect(constraints.backoffPolicy, equals(BackoffPolicy.linear));
      expect(constraints.backoffDelayMs, equals(20000));
    });

    test('Constraints fromMap handles missing backoffPolicy', () {
      final map = {'requiresNetwork': true};

      final constraints = Constraints.fromMap(map);

      expect(constraints.backoffPolicy, equals(BackoffPolicy.exponential)); // Default
      expect(constraints.backoffDelayMs, equals(30000)); // Default
    });

    test('Constraints fromMap handles invalid backoffPolicy', () {
      final map = {
        'backoffPolicy': 'invalid',
        'backoffDelayMs': 15000,
      };

      final constraints = Constraints.fromMap(map);

      expect(constraints.backoffPolicy, equals(BackoffPolicy.exponential)); // Fallback
      expect(constraints.backoffDelayMs, equals(15000));
    });

    test('Constraints copyWith updates backoffPolicy', () {
      const original = Constraints(
        requiresNetwork: true,
        backoffPolicy: BackoffPolicy.exponential,
        backoffDelayMs: 30000,
      );

      final updated = original.copyWith(
        backoffPolicy: BackoffPolicy.linear,
        backoffDelayMs: 60000,
      );

      expect(updated.requiresNetwork, isTrue); // Preserved
      expect(updated.backoffPolicy, equals(BackoffPolicy.linear)); // Updated
      expect(updated.backoffDelayMs, equals(60000)); // Updated
    });

    test('Constraints equality with backoffPolicy', () {
      const c1 = Constraints(
        backoffPolicy: BackoffPolicy.exponential,
        backoffDelayMs: 30000,
      );
      const c2 = Constraints(
        backoffPolicy: BackoffPolicy.exponential,
        backoffDelayMs: 30000,
      );
      const c3 = Constraints(
        backoffPolicy: BackoffPolicy.linear,
        backoffDelayMs: 30000,
      );
      const c4 = Constraints(
        backoffPolicy: BackoffPolicy.exponential,
        backoffDelayMs: 60000,
      );

      expect(c1, equals(c2));
      expect(c1, isNot(equals(c3))); // Different policy
      expect(c1, isNot(equals(c4))); // Different delay
    });

    test('Constraints hashCode with backoffPolicy', () {
      const c1 = Constraints(
        backoffPolicy: BackoffPolicy.exponential,
        backoffDelayMs: 30000,
      );
      const c2 = Constraints(
        backoffPolicy: BackoffPolicy.exponential,
        backoffDelayMs: 30000,
      );
      const c3 = Constraints(
        backoffPolicy: BackoffPolicy.linear,
        backoffDelayMs: 30000,
      );

      expect(c1.hashCode, equals(c2.hashCode));
      expect(c1.hashCode, isNot(equals(c3.hashCode)));
    });

    test('Constraints toString includes backoffPolicy', () {
      const constraints = Constraints(
        requiresNetwork: true,
        backoffPolicy: BackoffPolicy.linear,
        backoffDelayMs: 45000,
      );

      final str = constraints.toString();

      // Constraints uses abbreviated format: backoff: linear, backoffDelay: 45000ms
      expect(str, contains('backoff: linear'));
      expect(str, contains('backoffDelay: 45000ms'));
      expect(str, contains('network: true'));
    });
  });

  group('Edge Cases & Validation Tests', () {
    test('ContentUriTrigger handles empty path URI', () {
      final uri = Uri.parse('content://media/external/images');
      final trigger = TaskTrigger.contentUri(uri: uri, triggerForDescendants: false);

      expect((trigger as ContentUriTrigger).uri.toString(), equals(uri.toString()));
    });

    test('Constraints handles minimum backoffDelayMs', () {
      const constraints = Constraints(backoffDelayMs: 10000);

      expect(constraints.backoffDelayMs, equals(10000));
    });

    test('Constraints handles large backoffDelayMs', () {
      const constraints = Constraints(backoffDelayMs: 3600000); // 1 hour

      expect(constraints.backoffDelayMs, equals(3600000));
    });

    test('Constraints with all v0.7.0 features', () {
      const constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        backoffPolicy: BackoffPolicy.exponential,
        backoffDelayMs: 60000,
        isHeavyTask: true,
      );

      expect(constraints.requiresNetwork, isTrue);
      expect(constraints.requiresCharging, isTrue);
      expect(constraints.backoffPolicy, equals(BackoffPolicy.exponential));
      expect(constraints.backoffDelayMs, equals(60000));
      expect(constraints.isHeavyTask, isTrue);

      final map = constraints.toMap();
      expect(map['requiresNetwork'], isTrue);
      expect(map['requiresCharging'], isTrue);
      expect(map['backoffPolicy'], equals('exponential'));
      expect(map['backoffDelayMs'], equals(60000));
      expect(map['isHeavyTask'], isTrue);
    });

    test('Multiple TaskTrigger types coexist', () {
      final oneTime = TaskTrigger.oneTime();
      final periodic = TaskTrigger.periodic(const Duration(hours: 1));
      final contentUri = TaskTrigger.contentUri(
        uri: Uri.parse('content://test'),
        triggerForDescendants: false,
      );

      expect(oneTime, isA<OneTimeTrigger>());
      expect(periodic, isA<PeriodicTrigger>());
      expect(contentUri, isA<ContentUriTrigger>());
    });

    test('Constraints serialization round-trip with all fields', () {
      const original = Constraints(
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
        backoffDelayMs: 45000,
      );

      final map = original.toMap();
      final deserialized = Constraints.fromMap(map);

      expect(deserialized, equals(original));
    });
  });

  group('Platform-Specific Behavior Tests', () {
    test('BackoffPolicy values match Android expectations', () {
      // Android expects lowercase strings
      const exponential = Constraints(backoffPolicy: BackoffPolicy.exponential);
      const linear = Constraints(backoffPolicy: BackoffPolicy.linear);

      expect(exponential.toMap()['backoffPolicy'], equals('exponential'));
      expect(linear.toMap()['backoffPolicy'], equals('linear'));
    });

    test('ContentUri URI format validation', () {
      // Valid content URIs
      final validUris = [
        'content://media/external/images/media',
        'content://com.android.contacts/contacts',
        'content://com.example.provider/data',
      ];

      for (final uriString in validUris) {
        final uri = Uri.parse(uriString);
        expect(uri.scheme, equals('content'));

        final trigger = TaskTrigger.contentUri(uri: uri, triggerForDescendants: false);
        expect((trigger as ContentUriTrigger).uri.scheme, equals('content'));
      }
    });

    test('BackoffPolicy defaults match KMP WorkManager', () {
      const constraints = Constraints();

      // Default values should match KMP WorkManager defaults
      expect(constraints.backoffPolicy, equals(BackoffPolicy.exponential));
      expect(constraints.backoffDelayMs, equals(30000)); // 30 seconds
    });
  });

  group('Integration with Existing Features Tests', () {
    test('Constraints with backoffPolicy works with all other constraints', () {
      const constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        isHeavyTask: true,
        qos: QoS.utility,
        backoffPolicy: BackoffPolicy.exponential,
        backoffDelayMs: 30000,
      );

      final map = constraints.toMap();

      // All fields should be present
      expect(map, containsPair('requiresNetwork', true));
      expect(map, containsPair('requiresCharging', true));
      expect(map, containsPair('isHeavyTask', true));
      expect(map, containsPair('qos', 'utility'));
      expect(map, containsPair('backoffPolicy', 'exponential'));
      expect(map, containsPair('backoffDelayMs', 30000));
    });

    test('ContentUri trigger works in trigger type hierarchy', () {
      final contentUri = TaskTrigger.contentUri(
        uri: Uri.parse('content://test'),
      );

      // Should be part of TaskTrigger sealed class
      expect(contentUri, isA<TaskTrigger>());
      expect(contentUri, isA<ContentUriTrigger>());

      // Should have toMap method
      final map = contentUri.toMap();
      expect(map, containsPair('type', 'contentUri'));
    });

    test('All trigger types serialize with correct type field', () {
      final triggers = {
        TaskTrigger.oneTime(): 'oneTime',
        TaskTrigger.periodic(const Duration(hours: 1)): 'periodic',
        TaskTrigger.exact(DateTime.now()): 'exact',
        TaskTrigger.windowed(
          earliest: const Duration(hours: 1),
          latest: const Duration(hours: 2),
        ): 'windowed',
        TaskTrigger.contentUri(uri: Uri.parse('content://test'), triggerForDescendants: false): 'contentUri',
      };

      for (final entry in triggers.entries) {
        final map = entry.key.toMap();
        expect(map['type'], equals(entry.value),
            reason: 'Trigger ${entry.key.runtimeType} should have type ${entry.value}');
      }
    });
  });
}
