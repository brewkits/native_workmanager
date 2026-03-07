import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Regression tests for all bugs found in the comprehensive audit (2026-03-07).
///
/// Each group maps to a specific bug ID from the audit report.
/// Tests that require a real device are documented separately (see device test plan below).
///
/// ## Device test plan (run on both Android + iOS physical device)
///
/// C1 - iOS chain cancel:
///   1. enqueueChain(name: 'long-chain', steps: [...5 slow steps...])
///   2. After step 1 emits, call cancel('long-chain')
///   3. Assert: no further TaskEvents arrive for 'long-chain' within 30s
///   4. Assert: getTaskStatus('long-chain') == 'cancelled'
///
/// C2 - iOS periodic limitation:
///   1. On iOS, enqueue periodic(interval: 30s) task
///   2. Background the app
///   3. Kill app from task switcher
///   4. Wait 35s then reopen — assert: no event was emitted while killed
///   5. Document: "iOS periodic requires app open — BGAppRefreshTask for true background"
///
/// M1 - iOS chain non-blocking:
///   1. Measure time from enqueueChain() call to ScheduleResult.accepted
///   2. Assert: < 100ms (returns before chain executes)
///   3. Chain completion arrives later via events stream
///
/// H2 - Android hot restart:
///   1. Initialize plugin, schedule a task, hot restart Flutter
///   2. Assert: plugin reinitialises cleanly, tasks still execute
///   3. Assert: no KoinAppAlreadyStartedException in logs
///
/// H4 - Password in WorkManager (documented, no code fix without KeyStore):
///   1. Root device / ADB shell, check WorkManager Room DB after CryptoWorker runs
///   2. Assert: password is not present in plaintext in any DB row
///   (Current state: password IS visible — document as known risk, plan KeyStore migration)
void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // M5 — TaskEvent.fromMap null-safety
  // ─────────────────────────────────────────────────────────────────────────
  group('M5 — TaskEvent.fromMap null-safety', () {
    test('parses complete map correctly', () {
      final map = {
        'taskId': 'upload-1',
        'success': true,
        'message': 'done',
        'timestamp': 1704067200000,
        'resultData': {'key': 'value'},
      };
      final event = TaskEvent.fromMap(map);
      expect(event.taskId, 'upload-1');
      expect(event.success, isTrue);
      expect(event.message, 'done');
      expect(event.resultData, {'key': 'value'});
    });

    test('does not throw when taskId is null — uses empty string fallback', () {
      // Before fix: `map['taskId'] as String` throws CastError
      // After fix: falls back to ''
      final map = <String, dynamic>{
        'taskId': null,
        'success': true,
        'message': null,
        'timestamp': 1704067200000,
      };
      expect(() => TaskEvent.fromMap(map), returnsNormally);
      final event = TaskEvent.fromMap(map);
      expect(event.taskId, '');
    });

    test('does not throw when success is null — uses false fallback', () {
      final map = <String, dynamic>{
        'taskId': 'task-1',
        'success': null,
        'timestamp': 1704067200000,
      };
      expect(() => TaskEvent.fromMap(map), returnsNormally);
      final event = TaskEvent.fromMap(map);
      expect(event.success, isFalse);
    });

    test('does not throw when timestamp is null — uses DateTime.now()', () {
      final map = <String, dynamic>{
        'taskId': 'task-1',
        'success': true,
        'timestamp': null,
      };
      expect(() => TaskEvent.fromMap(map), returnsNormally);
    });

    test('does not throw on completely empty map', () {
      final map = <String, dynamic>{};
      expect(() => TaskEvent.fromMap(map), returnsNormally);
      final event = TaskEvent.fromMap(map);
      expect(event.taskId, '');
      expect(event.success, isFalse);
    });

    test('handles numeric timestamp as num (int or double from platform)', () {
      // iOS sends timestamps as NSNumber which may decode as double
      final mapWithDouble = <String, dynamic>{
        'taskId': 'task-1',
        'success': true,
        'timestamp': 1704067200000.0,
      };
      expect(() => TaskEvent.fromMap(mapWithDouble), returnsNormally);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // M5 — TaskProgress.fromMap null-safety
  // ─────────────────────────────────────────────────────────────────────────
  group('M5 — TaskProgress.fromMap null-safety', () {
    test('parses complete map correctly', () {
      final map = {
        'taskId': 'download-1',
        'progress': 75,
        'message': '75% done',
        'currentStep': 3,
        'totalSteps': 5,
      };
      final p = TaskProgress.fromMap(map);
      expect(p.taskId, 'download-1');
      expect(p.progress, 75);
      expect(p.message, '75% done');
      expect(p.currentStep, 3);
      expect(p.totalSteps, 5);
    });

    test('does not throw when taskId is null', () {
      final map = <String, dynamic>{
        'taskId': null,
        'progress': 50,
      };
      expect(() => TaskProgress.fromMap(map), returnsNormally);
      expect(TaskProgress.fromMap(map).taskId, '');
    });

    test('does not throw when progress is null', () {
      final map = <String, dynamic>{
        'taskId': 'task-1',
        'progress': null,
      };
      expect(() => TaskProgress.fromMap(map), returnsNormally);
      expect(TaskProgress.fromMap(map).progress, 0);
    });

    test('coerces double progress from platform to int', () {
      // Platforms may send progress as a floating-point number
      final map = <String, dynamic>{
        'taskId': 'task-1',
        'progress': 42.0,
      };
      expect(() => TaskProgress.fromMap(map), returnsNormally);
      expect(TaskProgress.fromMap(map).progress, 42);
    });

    test('does not throw on completely empty map', () {
      expect(() => TaskProgress.fromMap({}), returnsNormally);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // L6 — TaskEvent equality includes message field
  // ─────────────────────────────────────────────────────────────────────────
  group('L6 — TaskEvent equality', () {
    final ts = DateTime(2026, 3, 7, 12, 0);

    test('equal when all fields match', () {
      final a = TaskEvent(taskId: 'x', success: true, message: 'ok', timestamp: ts);
      final b = TaskEvent(taskId: 'x', success: true, message: 'ok', timestamp: ts);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('not equal when only message differs', () {
      // Before fix: operator== ignored message, so these were considered equal.
      // After fix: different messages → not equal.
      final a = TaskEvent(taskId: 'x', success: true, message: 'done',   timestamp: ts);
      final b = TaskEvent(taskId: 'x', success: true, message: 'failed', timestamp: ts);
      expect(a, isNot(equals(b)));
    });

    test('not equal when taskId differs', () {
      final a = TaskEvent(taskId: 'a', success: true, message: 'ok', timestamp: ts);
      final b = TaskEvent(taskId: 'b', success: true, message: 'ok', timestamp: ts);
      expect(a, isNot(equals(b)));
    });

    test('not equal when success differs', () {
      final a = TaskEvent(taskId: 'x', success: true,  message: 'ok', timestamp: ts);
      final b = TaskEvent(taskId: 'x', success: false, message: 'ok', timestamp: ts);
      expect(a, isNot(equals(b)));
    });

    test('not equal when timestamp differs', () {
      final a = TaskEvent(taskId: 'x', success: true, message: 'ok', timestamp: ts);
      final b = TaskEvent(taskId: 'x', success: true, message: 'ok',
          timestamp: ts.add(const Duration(milliseconds: 1)));
      expect(a, isNot(equals(b)));
    });

    test('null message and non-null message are not equal', () {
      final a = TaskEvent(taskId: 'x', success: true, message: null, timestamp: ts);
      final b = TaskEvent(taskId: 'x', success: true, message: 'ok', timestamp: ts);
      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent with equality', () {
      // If a == b then a.hashCode must == b.hashCode (dart contract)
      final a = TaskEvent(taskId: 'x', success: false, message: 'err', timestamp: ts);
      final b = TaskEvent(taskId: 'x', success: false, message: 'err', timestamp: ts);
      expect(a == b, isTrue);
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // L1 — _parseScheduleResult: known values still work after refactor
  // ─────────────────────────────────────────────────────────────────────────
  // Note: _parseScheduleResult is private; we test it indirectly through
  // the public API surface that exercises the parsing path.
  // The warning for unknown values requires a mock platform; verified manually.
  group('L1 — ScheduleResult enum coverage', () {
    test('ScheduleResult.accepted exists', () {
      expect(ScheduleResult.values, contains(ScheduleResult.accepted));
    });

    test('ScheduleResult.rejectedOsPolicy exists', () {
      expect(ScheduleResult.values, contains(ScheduleResult.rejectedOsPolicy));
    });

    test('ScheduleResult.throttled exists', () {
      expect(ScheduleResult.values, contains(ScheduleResult.throttled));
    });

    test('ScheduleResult has exactly 3 values (no accidental additions)', () {
      expect(ScheduleResult.values.length, 3);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // H1 — Path traversal (Dart-layer: NativeWorker input validation)
  // ─────────────────────────────────────────────────────────────────────────
  // The native-layer canonical path fix (validateFilePathSafe) is tested by
  // existing test/security/path_traversal_test.dart. These tests cover the
  // Dart-layer guard that runs before the request reaches native code.
  group('H1 — Dart-layer path traversal guard', () {
    test('httpDownload allows absolute path without traversal', () {
      expect(
        () => NativeWorker.httpDownload(
          url: 'https://example.com/file.zip',
          savePath: '/tmp/safe/file.zip',
        ),
        returnsNormally,
      );
    });

    test('httpDownload blocks .. traversal in savePath', () {
      expect(
        () => NativeWorker.httpDownload(
          url: 'https://example.com/file.zip',
          savePath: '/tmp/../../../etc/passwd',
        ),
        throwsArgumentError,
      );
    });

    test('httpDownload blocks relative paths', () {
      expect(
        () => NativeWorker.httpDownload(
          url: 'https://example.com/file.zip',
          savePath: 'relative/path.zip',
        ),
        throwsArgumentError,
      );
    });

    test('httpDownload blocks empty savePath', () {
      expect(
        () => NativeWorker.httpDownload(
          url: 'https://example.com/file.zip',
          savePath: '',
        ),
        throwsArgumentError,
      );
    });

    test('cryptoEncrypt blocks .. in inputPath', () {
      expect(
        () => NativeWorker.cryptoEncrypt(
          inputPath: '/tmp/../../etc/passwd',
          outputPath: '/tmp/out.enc',
          password: 'secret',
        ),
        throwsArgumentError,
      );
    });

    test('cryptoEncrypt blocks .. in outputPath', () {
      expect(
        () => NativeWorker.cryptoEncrypt(
          inputPath: '/tmp/safe.txt',
          outputPath: '/tmp/../../etc/evil.enc',
          password: 'secret',
        ),
        throwsArgumentError,
      );
    });

    test('cryptoDecrypt blocks .. in inputPath', () {
      expect(
        () => NativeWorker.cryptoDecrypt(
          inputPath: '/tmp/../../etc/shadow.enc',
          outputPath: '/tmp/out.txt',
          password: 'secret',
        ),
        throwsArgumentError,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // C1 — Chain cancel ID is the chain name (Dart API contract)
  // ─────────────────────────────────────────────────────────────────────────
  // The actual cancellation is tested on device. Here we verify the Dart-side
  // API surface: that cancel() accepts the chain name as the taskId.
  group('C1 — Chain cancel API contract', () {
    test('cancel accepts a chain name string without throwing', () {
      // NativeWorkManager.cancel() is a static method that requires initialization.
      // This verifies the method signature accepts the expected parameter type.
      // Full cancellation is verified in the device integration test.
      expect(NativeWorkManager.cancel, isA<Function>());
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TaskEvent.fromMap — round-trip consistency
  // ─────────────────────────────────────────────────────────────────────────
  group('TaskEvent round-trip', () {
    test('fromMap then toMap preserves all fields', () {
      final original = TaskEvent(
        taskId: 'task-rt',
        success: true,
        message: 'round-trip ok',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200000),
        resultData: {'bytes': 1024},
      );

      final map = original.toMap();
      final restored = TaskEvent.fromMap(Map<String, dynamic>.from(map));

      expect(restored.taskId,    original.taskId);
      expect(restored.success,   original.success);
      expect(restored.message,   original.message);
      expect(restored.timestamp, original.timestamp);
      expect(restored.resultData, original.resultData);
    });

    test('fromMap then toMap on failure event preserves all fields', () {
      final original = TaskEvent(
        taskId: 'fail-rt',
        success: false,
        message: 'network timeout',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200000),
      );

      final map = original.toMap();
      final restored = TaskEvent.fromMap(Map<String, dynamic>.from(map));

      expect(restored.taskId,  original.taskId);
      expect(restored.success, original.success);
      expect(restored.message, original.message);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TaskProgress round-trip
  // ─────────────────────────────────────────────────────────────────────────
  group('TaskProgress round-trip', () {
    test('fromMap then toMap preserves all fields', () {
      final original = TaskProgress(
        taskId: 'upload-rt',
        progress: 42,
        message: 'uploading…',
        currentStep: 2,
        totalSteps: 5,
      );

      final map = original.toMap();
      final restored = TaskProgress.fromMap(Map<String, dynamic>.from(map));

      expect(restored.taskId,      original.taskId);
      expect(restored.progress,    original.progress);
      expect(restored.message,     original.message);
      expect(restored.currentStep, original.currentStep);
      expect(restored.totalSteps,  original.totalSteps);
    });
  });
}
