import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('v1.1.1 Feature Verification', () {
    test('Constraints should support all v1.1.1 flags', () {
      const constraints = Constraints(
        requiresNetwork: true,
        requiresCharging: true,
        isHeavyTask: true,
        backoffPolicy: BackoffPolicy.linear,
        backoffDelayMs: 45000,
        allowWhileIdle: true,
      );

      expect(constraints.requiresNetwork, isTrue);
      expect(constraints.requiresCharging, isTrue);
      expect(constraints.isHeavyTask, isTrue);
      expect(constraints.backoffPolicy, BackoffPolicy.linear);
      expect(constraints.backoffDelayMs, 45000);
      expect(constraints.allowWhileIdle, isTrue);

      final map = constraints.toMap();
      expect(map['isHeavyTask'], isTrue);
      expect(map['backoffPolicy'], 'linear');
      expect(map['backoffDelayMs'], 45000);
      expect(map['allowWhileIdle'], isTrue);
    });

    test('Constraints round-trip for new fields', () {
      const original = Constraints(
        isHeavyTask: true,
        backoffPolicy: BackoffPolicy.linear,
        backoffDelayMs: 15000,
      );

      final map = original.toMap();
      final decoded = Constraints.fromMap(map);

      expect(decoded.isHeavyTask, isTrue);
      expect(decoded.backoffPolicy, BackoffPolicy.linear);
      expect(decoded.backoffDelayMs, 15000);
    });

    test('BackoffPolicy serialization handles all enum values', () {
      expect(
          const Constraints(backoffPolicy: BackoffPolicy.exponential)
              .toMap()['backoffPolicy'],
          'exponential');
      expect(
          const Constraints(backoffPolicy: BackoffPolicy.linear)
              .toMap()['backoffPolicy'],
          'linear');
    });

    test('ContentUriTrigger toMap includes all necessary fields for Android',
        () {
      final uri = Uri.parse('content://com.android.contacts/contacts');
      final trigger =
          TaskTrigger.contentUri(uri: uri, triggerForDescendants: true);

      final map = trigger.toMap();
      expect(map['type'], 'contentUri');
      expect(map['uriString'], 'content://com.android.contacts/contacts');
      expect(map['triggerForDescendants'], isTrue);
    });
  });
}
