import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Performance benchmark for the Issue #30 timeout resolver.
///
/// `resolveDispatcherTimeout` runs on the hot path of *every* DartWorker
/// callback (once per invocation, both on the headless engine dispatcher and
/// on the foreground main-channel path). Anything more than a microsecond per
/// call would add a perceptible cost to high-frequency callbacks (e.g. a
/// periodic 1-minute task fires 1440 times/day).
///
/// This benchmark also serves as a regression guard for the helper: if a
/// future "cleanup" replaces the simple `num/.toInt()` path with heavier
/// logic (regex parsing, JSON decode, etc.), the budget will catch it.
void main() {
  group('issue_30 perf: resolveDispatcherTimeout overhead', () {
    test('resolver completes 100k calls under 50 ms (<0.5 us/call)', () {
      const iterations = 100000;
      final argsWithValue = {'timeoutMs': 60000};

      // Warmup — let the VM JIT.
      for (var i = 0; i < 1000; i++) {
        resolveDispatcherTimeout(argsWithValue);
      }

      final sw = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        resolveDispatcherTimeout(argsWithValue);
      }
      sw.stop();

      final usPerCall = sw.elapsedMicroseconds / iterations;
      // ignore: avoid_print
      print('resolveDispatcherTimeout: ${usPerCall.toStringAsFixed(3)} us/call '
          '(total ${sw.elapsedMilliseconds} ms for $iterations iters)');

      expect(
        sw.elapsedMilliseconds,
        lessThan(50),
        reason: 'Resolver overhead must stay negligible — > 50 ms for 100k '
            'calls indicates a heavier implementation regressed the hot path.',
      );
    });

    test('resolver fallback path is no slower than happy path', () {
      const iterations = 100000;
      final emptyArgs = <String, Object?>{};
      final argsWithValue = {'timeoutMs': 60000};

      // Warmup
      for (var i = 0; i < 1000; i++) {
        resolveDispatcherTimeout(emptyArgs);
        resolveDispatcherTimeout(argsWithValue);
      }

      final swFallback = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        resolveDispatcherTimeout(emptyArgs);
      }
      swFallback.stop();

      final swHappy = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        resolveDispatcherTimeout(argsWithValue);
      }
      swHappy.stop();

      // ignore: avoid_print
      print('Fallback: ${swFallback.elapsedMicroseconds} us; '
          'Happy: ${swHappy.elapsedMicroseconds} us');

      // Allow 4x slack — micro-benchmark noise dominates at this scale.
      expect(
        swFallback.elapsedMicroseconds,
        lessThan(swHappy.elapsedMicroseconds * 4 + 5000),
        reason: 'Fallback path must not be dramatically slower than the '
            'happy path (suggests an exception-driven implementation).',
      );
    });

    test('DartWorker.toMap with timeoutMs has no extra allocation overhead',
        () {
      const iterations = 50000;

      // Warmup
      for (var i = 0; i < 500; i++) {
        DartWorker(callbackId: 'cb', timeoutMs: 60000).toMap();
        DartWorker(callbackId: 'cb').toMap();
      }

      final swWith = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        DartWorker(callbackId: 'cb', timeoutMs: 60000).toMap();
      }
      swWith.stop();

      final swWithout = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        DartWorker(callbackId: 'cb').toMap();
      }
      swWithout.stop();

      // ignore: avoid_print
      print('With timeoutMs: ${swWith.elapsedMilliseconds} ms; '
          'Without: ${swWithout.elapsedMilliseconds} ms');

      // Setting timeoutMs adds one map entry — should be negligible.
      expect(
        swWith.elapsedMilliseconds,
        lessThan(swWithout.elapsedMilliseconds * 2 + 50),
        reason: 'Adding timeoutMs should not double serialization cost.',
      );
    });
  });
}
