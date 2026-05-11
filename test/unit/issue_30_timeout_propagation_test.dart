import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Regression tests for Issue #30 — `DartWorker.timeoutMs` was ignored on the
/// Dart side because the dispatcher hardcoded `Duration(seconds: 25)` and the
/// native bridges never forwarded the user-set value.
///
/// These tests pin down the two behaviors that together close the bug:
///   1. The user-supplied `timeoutMs` flows through `DartWorker.toMap()` so the
///      native bridge has it to forward.
///   2. The Dart dispatcher honors `args['timeoutMs']` exactly — not 25 s.
///
/// The native→Dart forwarding step is covered separately by the device
/// integration test `issue_30_*` in `example/integration_test/`. Together they
/// form the end-to-end propagation guard.
void main() {
  group('issue_30: DartWorker.timeoutMs end-to-end propagation', () {
    group('toMap (Dart → native)', () {
      test('issue_30: timeoutMs is serialized when user sets it', () {
        final worker = DartWorker(callbackId: 'syncNightly', timeoutMs: 60000);
        expect(worker.toMap()['timeoutMs'], 60000);
      });

      test(
          'issue_30: timeoutMs key is omitted when unset (native picks default)',
          () {
        final worker = DartWorker(callbackId: 'syncNightly');
        expect(worker.toMap().containsKey('timeoutMs'), isFalse);
      });
    });

    group('resolveDispatcherTimeout (native → Dart)', () {
      test('issue_30: honors timeoutMs forwarded by the native bridge', () {
        expect(
          resolveDispatcherTimeout({'timeoutMs': 60000}),
          const Duration(milliseconds: 60000),
        );
      });

      test(
          'issue_30: large timeoutMs (10 minutes) is honored — not clamped to 25 s',
          () {
        // Pre-fix, this returned 25 s regardless of input. Pinning it explicitly
        // because the failure mode was silent (callback killed after 25 s).
        expect(
          resolveDispatcherTimeout({'timeoutMs': 10 * 60 * 1000}),
          const Duration(minutes: 10),
        );
      });

      test('issue_30: accepts num (double) for JSON-decoded payloads', () {
        // MethodChannel may decode integer JSON values as double on some platforms.
        expect(
          resolveDispatcherTimeout({'timeoutMs': 45000.0}),
          const Duration(milliseconds: 45000),
        );
      });

      test('issue_30: falls back to 25 s when timeoutMs is absent', () {
        // Older native side without the fix sends no timeoutMs — Dart must keep
        // the iOS BGAppRefreshTask-safe 25 s default (not 0, not infinite).
        expect(
          resolveDispatcherTimeout(<String, Object?>{}),
          const Duration(seconds: 25),
        );
      });

      test('issue_30: falls back to 25 s when timeoutMs is non-numeric', () {
        // Defensive: if a future bridge change forwards a malformed value,
        // we keep the safety-buffer default instead of crashing the dispatcher.
        expect(
          resolveDispatcherTimeout({'timeoutMs': 'not a number'}),
          const Duration(seconds: 25),
        );
      });

      test('issue_30: small timeoutMs (1 s) is honored for fail-fast hangs',
          () {
        expect(
          resolveDispatcherTimeout({'timeoutMs': 1000}),
          const Duration(seconds: 1),
        );
      });
    });
  });
}
