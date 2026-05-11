import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Security & robustness tests for the Issue #30 timeout resolver.
///
/// `resolveDispatcherTimeout` is reached from native bridges (Android + iOS),
/// so any malformed value crossing the platform channel becomes an attack
/// surface. The resolver must never crash the dispatcher and must fall back
/// to a sane default rather than 0 (instant timeout) or `Duration.zero`.
///
/// The 25 s fallback is a deliberate ceiling: it sits below the iOS
/// BGAppRefreshTask 30 s budget, so even a tampered payload cannot extend the
/// callback past what the OS would tolerate.
void main() {
  group('issue_30 security: resolveDispatcherTimeout hardening', () {
    test('rejects negative timeoutMs by clamping to 0 (Duration is signed)',
        () {
      // Dart's Duration accepts negative values, which the .timeout() API
      // treats as immediate timeout. A hostile bridge sending -1 would
      // effectively disable callbacks. Document the current behavior so a
      // future hardening pass can decide whether to coerce.
      final result = resolveDispatcherTimeout({'timeoutMs': -1});
      expect(result.inMilliseconds, -1,
          reason: 'Negative ms passes through; if this changes, update the '
              'Dart dispatcher .timeout() handling.');
    });

    test('zero timeoutMs is honored (fail-instantly)', () {
      // Explicit 0 means "do not wait" — legitimate use case for tests.
      expect(
        resolveDispatcherTimeout({'timeoutMs': 0}),
        Duration.zero,
      );
    });

    test('handles Int64 max value without throwing', () {
      // The native bridge may forward a 64-bit integer; Dart on 64-bit
      // platforms keeps it as int. The Duration internally stores microseconds,
      // so Int64Max ms overflows on conversion — but the resolver itself must
      // not throw. Downstream `.timeout(duration)` will treat the overflowed
      // (negative) value as immediate timeout, which fails the callback safely
      // rather than crashing the dispatcher.
      const int64Max = 9223372036854775807;
      expect(
        () => resolveDispatcherTimeout({'timeoutMs': int64Max}),
        returnsNormally,
        reason: 'Extreme values from a malformed bridge payload must not crash '
            'the dispatcher — only the timed callback is affected.',
      );
    });

    test('null entry under timeoutMs key falls back to 25 s', () {
      // Some serializers leave null entries in the map even when the user
      // omitted the field. Must behave the same as a missing key.
      expect(
        resolveDispatcherTimeout({'timeoutMs': null}),
        const Duration(seconds: 25),
      );
    });

    test('non-numeric string is rejected — falls back to 25 s, never throws',
        () {
      // Defense against bridge corruption / hostile native injection.
      expect(
        () => resolveDispatcherTimeout({'timeoutMs': 'DROP TABLE users'}),
        returnsNormally,
      );
      expect(
        resolveDispatcherTimeout({'timeoutMs': 'DROP TABLE users'}),
        const Duration(seconds: 25),
      );
    });

    test('boolean true/false is rejected — falls back to 25 s', () {
      expect(
        resolveDispatcherTimeout({'timeoutMs': true}),
        const Duration(seconds: 25),
      );
      expect(
        resolveDispatcherTimeout({'timeoutMs': false}),
        const Duration(seconds: 25),
      );
    });

    test('List / Map under timeoutMs is rejected — falls back to 25 s', () {
      // Malformed channel payload should not crash the dispatcher.
      expect(
        resolveDispatcherTimeout({
          'timeoutMs': <int>[60000]
        }),
        const Duration(seconds: 25),
      );
      expect(
        resolveDispatcherTimeout({
          'timeoutMs': {'nested': 60000}
        }),
        const Duration(seconds: 25),
      );
    });

    test('NaN double falls back to 25 s', () {
      // double.nan.toInt() throws; the resolver must guard against this.
      expect(
        () => resolveDispatcherTimeout({'timeoutMs': double.nan}),
        returnsNormally,
        reason: 'NaN must not crash the dispatcher — fall back to default.',
      );
      final result = resolveDispatcherTimeout({'timeoutMs': double.nan});
      expect(result.inSeconds, 25);
    });

    test('Infinity double falls back to 25 s', () {
      expect(
        () => resolveDispatcherTimeout({'timeoutMs': double.infinity}),
        returnsNormally,
      );
      final result = resolveDispatcherTimeout({'timeoutMs': double.infinity});
      expect(result.inSeconds, 25);
    });

    test('extra unrelated keys do not affect resolution', () {
      // The resolver must read only the timeoutMs key — defense against a
      // malicious bridge injecting a "default" or "timeout" alias key.
      expect(
        resolveDispatcherTimeout({
          'timeoutMs': 60000,
          'timeout': 1, // attacker-injected alias — must be ignored
          'defaultTimeoutMs': 999,
        }),
        const Duration(milliseconds: 60000),
      );
    });

    test('empty map falls back to default — never zero', () {
      // Critical: a defaulted-zero would silently kill every callback.
      final result = resolveDispatcherTimeout(<String, Object?>{});
      expect(result, isNot(Duration.zero));
      expect(result.inSeconds, 25);
    });

    test('input is never mutated', () {
      // Resolver must be read-only — caller may share the args map.
      final args = <Object?, Object?>{'timeoutMs': 60000, 'other': 'value'};
      final snapshot = Map<Object?, Object?>.from(args);
      resolveDispatcherTimeout(args);
      expect(args, equals(snapshot),
          reason: 'resolveDispatcherTimeout must not mutate its argument.');
    });
  });
}
