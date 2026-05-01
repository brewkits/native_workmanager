import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  // ─── NativeWorkManagerError ────────────────────────────────────────────────

  group('NativeWorkManagerError.fromString', () {
    test('parses NETWORK_ERROR', () {
      expect(NativeWorkManagerError.fromString('NETWORK_ERROR'),
          NativeWorkManagerError.networkError);
    });
    test('parses TIMEOUT', () {
      expect(NativeWorkManagerError.fromString('TIMEOUT'),
          NativeWorkManagerError.timeout);
    });
    test('parses HTTP_CLIENT_ERROR', () {
      expect(NativeWorkManagerError.fromString('HTTP_CLIENT_ERROR'),
          NativeWorkManagerError.httpClientError);
    });
    test('parses HTTP_SERVER_ERROR', () {
      expect(NativeWorkManagerError.fromString('HTTP_SERVER_ERROR'),
          NativeWorkManagerError.httpServerError);
    });
    test('parses FILE_NOT_FOUND', () {
      expect(NativeWorkManagerError.fromString('FILE_NOT_FOUND'),
          NativeWorkManagerError.fileNotFound);
    });
    test('parses INSUFFICIENT_STORAGE', () {
      expect(NativeWorkManagerError.fromString('INSUFFICIENT_STORAGE'),
          NativeWorkManagerError.insufficientStorage);
    });
    test('parses SECURITY_VIOLATION', () {
      expect(NativeWorkManagerError.fromString('SECURITY_VIOLATION'),
          NativeWorkManagerError.securityViolation);
    });
    test('parses CANCELLED', () {
      expect(NativeWorkManagerError.fromString('CANCELLED'),
          NativeWorkManagerError.cancelled);
    });
    test('parses WORKER_EXCEPTION', () {
      expect(NativeWorkManagerError.fromString('WORKER_EXCEPTION'),
          NativeWorkManagerError.workerException);
    });
    test('returns unknown for unrecognised string', () {
      expect(NativeWorkManagerError.fromString('BOGUS'),
          NativeWorkManagerError.unknown);
    });
    test('returns unknown for null', () {
      expect(NativeWorkManagerError.fromString(null),
          NativeWorkManagerError.unknown);
    });
    test('is case-sensitive — lowercase returns unknown', () {
      expect(NativeWorkManagerError.fromString('network_error'),
          NativeWorkManagerError.unknown);
    });
  });

  group('NativeWorkManagerError.rawValue round-trips', () {
    for (final error in NativeWorkManagerError.values) {
      test('${error.name} rawValue round-trips through fromString', () {
        expect(NativeWorkManagerError.fromString(error.rawValue), error);
      });
    }
  });

  // ─── TaskStatus ────────────────────────────────────────────────────────────

  group('TaskStatus enum', () {
    test('has exactly 6 values', () {
      expect(TaskStatus.values.length, 6);
    });
    test('contains pending', () {
      expect(TaskStatus.values, contains(TaskStatus.pending));
    });
    test('contains running', () {
      expect(TaskStatus.values, contains(TaskStatus.running));
    });
    test('contains completed', () {
      expect(TaskStatus.values, contains(TaskStatus.completed));
    });
    test('contains failed', () {
      expect(TaskStatus.values, contains(TaskStatus.failed));
    });
    test('contains cancelled', () {
      expect(TaskStatus.values, contains(TaskStatus.cancelled));
    });
    test('contains paused', () {
      expect(TaskStatus.values, contains(TaskStatus.paused));
    });
    test('does NOT contain a "success" case', () {
      final names = TaskStatus.values.map((e) => e.name);
      expect(names, isNot(contains('success')));
    });
    test('parse by name: "completed" → TaskStatus.completed', () {
      final parsed =
          TaskStatus.values.where((e) => e.name == 'completed').firstOrNull;
      expect(parsed, TaskStatus.completed);
    });
    test('parse by name: "success" → null (iOS bug regression)', () {
      // iOS previously wrote "success" to SQLite. Dart must return null, not crash.
      final parsed =
          TaskStatus.values.where((e) => e.name == 'success').firstOrNull;
      expect(parsed, isNull);
    });
  });

  // ─── ScheduleResult ────────────────────────────────────────────────────────

  group('ScheduleResult', () {
    test('accepted != rejectedOsPolicy', () {
      expect(ScheduleResult.accepted, isNot(ScheduleResult.rejectedOsPolicy));
    });
    test('accepted != throttled', () {
      expect(ScheduleResult.accepted, isNot(ScheduleResult.throttled));
    });
    test('has exactly 3 values', () {
      expect(ScheduleResult.values.length, 3);
    });
  });

  // ─── TaskEvent ─────────────────────────────────────────────────────────────

  group('TaskEvent construction', () {
    final ts = DateTime(2026, 1, 1);

    test('success event has correct fields', () {
      final e = TaskEvent(taskId: 'task-1', success: true, timestamp: ts);
      expect(e.taskId, 'task-1');
      expect(e.success, isTrue);
      expect(e.isStarted, isFalse);
      expect(e.errorCode, isNull);
      expect(e.message, isNull);
      expect(e.resultData, isNull);
    });

    test('failure event stores errorCode', () {
      final e = TaskEvent(
        taskId: 'task-2',
        success: false,
        message: 'Network timeout',
        errorCode: NativeWorkManagerError.timeout,
        timestamp: ts,
      );
      expect(e.success, isFalse);
      expect(e.errorCode, NativeWorkManagerError.timeout);
      expect(e.message, 'Network timeout');
    });

    test('started event has isStarted=true', () {
      final e = TaskEvent(
        taskId: 'task-3',
        success: false,
        isStarted: true,
        workerType: 'HttpDownloadWorker',
        timestamp: ts,
      );
      expect(e.isStarted, isTrue);
      expect(e.workerType, 'HttpDownloadWorker');
    });

    test('resultData is preserved', () {
      final e = TaskEvent(
        taskId: 'task-4',
        success: true,
        resultData: {'key': 'value', 'count': 42},
        timestamp: ts,
      );
      expect(e.resultData?['key'], 'value');
      expect(e.resultData?['count'], 42);
    });
  });

  group('TaskEvent.fromMap', () {
    test('parses minimal success map', () {
      final e = TaskEvent.fromMap(
          {'taskId': 'x', 'success': true, 'timestamp': 1000});
      expect(e.taskId, 'x');
      expect(e.success, isTrue);
      expect(e.timestamp.millisecondsSinceEpoch, 1000);
    });

    test('parses failure with errorCode', () {
      final e = TaskEvent.fromMap({
        'taskId': 'y',
        'success': false,
        'errorCode': 'TIMEOUT',
        'message': 'timed out',
        'timestamp': 2000,
      });
      expect(e.success, isFalse);
      expect(e.errorCode, NativeWorkManagerError.timeout);
      expect(e.message, 'timed out');
    });

    test('parses started event', () {
      final e = TaskEvent.fromMap({
        'taskId': 'z',
        'success': true,
        'isStarted': true,
        'workerType': 'CryptoWorker',
        'timestamp': 3000,
      });
      expect(e.isStarted, isTrue);
      expect(e.workerType, 'CryptoWorker');
    });

    test('ignores errorCode on started event', () {
      final e = TaskEvent.fromMap({
        'taskId': 'z',
        'success': false,
        'isStarted': true,
        'errorCode': 'TIMEOUT',
        'timestamp': 3000,
      });
      // errorCode must be null for started events (isStarted=true suppresses it)
      expect(e.errorCode, isNull);
    });

    test('ignores errorCode on success event', () {
      final e = TaskEvent.fromMap({
        'taskId': 'ok',
        'success': true,
        'errorCode': 'TIMEOUT', // stray code on success
        'timestamp': 3000,
      });
      expect(e.errorCode, isNull);
    });

    test('parses resultData from Map', () {
      final e = TaskEvent.fromMap({
        'taskId': 'r',
        'success': true,
        'resultData': {'url': 'https://example.com'},
        'timestamp': 4000,
      });
      expect(e.resultData?['url'], 'https://example.com');
    });

    test('handles null resultData gracefully', () {
      final e = TaskEvent.fromMap(
          {'taskId': 'r', 'success': true, 'resultData': null, 'timestamp': 0});
      expect(e.resultData, isNull);
    });

    test('handles missing taskId — defaults to empty string', () {
      final e = TaskEvent.fromMap({'success': true, 'timestamp': 0});
      expect(e.taskId, '');
    });

    test('handles missing timestamp — uses DateTime.now()', () {
      final before = DateTime.now();
      final e = TaskEvent.fromMap({'taskId': 't', 'success': true});
      final after = DateTime.now();
      expect(e.timestamp.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(
          e.timestamp.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('handles non-Map resultData — returns null', () {
      final e = TaskEvent.fromMap({
        'taskId': 't',
        'success': true,
        'resultData': 'not-a-map',
        'timestamp': 0,
      });
      expect(e.resultData, isNull);
    });
  });

  group('TaskEvent equality and hashCode', () {
    final ts = DateTime(2026, 6, 1);

    test('identical instances are equal', () {
      final e = TaskEvent(taskId: 't1', success: true, timestamp: ts);
      expect(e, equals(e));
    });

    test('two equal instances are equal', () {
      final a = TaskEvent(taskId: 't1', success: true, timestamp: ts);
      final b = TaskEvent(taskId: 't1', success: true, timestamp: ts);
      expect(a, equals(b));
    });

    test('different taskId → not equal', () {
      final a = TaskEvent(taskId: 't1', success: true, timestamp: ts);
      final b = TaskEvent(taskId: 't2', success: true, timestamp: ts);
      expect(a, isNot(equals(b)));
    });

    test('different success → not equal', () {
      final a = TaskEvent(taskId: 't1', success: true, timestamp: ts);
      final b = TaskEvent(taskId: 't1', success: false, timestamp: ts);
      expect(a, isNot(equals(b)));
    });

    test('different message → not equal', () {
      final a =
          TaskEvent(taskId: 't1', success: false, message: 'a', timestamp: ts);
      final b =
          TaskEvent(taskId: 't1', success: false, message: 'b', timestamp: ts);
      expect(a, isNot(equals(b)));
    });

    test('equal instances have equal hashCode', () {
      final a = TaskEvent(taskId: 't1', success: true, timestamp: ts);
      final b = TaskEvent(taskId: 't1', success: true, timestamp: ts);
      expect(a.hashCode, b.hashCode);
    });

    test('events with resultData are equal when maps match', () {
      final a = TaskEvent(
          taskId: 't', success: true, resultData: {'k': 'v'}, timestamp: ts);
      final b = TaskEvent(
          taskId: 't', success: true, resultData: {'k': 'v'}, timestamp: ts);
      expect(a, equals(b));
    });

    test('events differ when resultData maps differ', () {
      final a = TaskEvent(
          taskId: 't', success: true, resultData: {'k': 'v1'}, timestamp: ts);
      final b = TaskEvent(
          taskId: 't', success: true, resultData: {'k': 'v2'}, timestamp: ts);
      expect(a, isNot(equals(b)));
    });
  });

  group('TaskEvent.toMap round-trip', () {
    test('success event survives fromMap(toMap())', () {
      final ts = DateTime.fromMillisecondsSinceEpoch(9999);
      final orig =
          TaskEvent(taskId: 'rt1', success: true, message: 'ok', timestamp: ts);
      final copy = TaskEvent.fromMap(orig.toMap());
      expect(copy.taskId, orig.taskId);
      expect(copy.success, orig.success);
      expect(copy.message, orig.message);
      expect(copy.timestamp, orig.timestamp);
    });

    test('failure event survives fromMap(toMap())', () {
      final ts = DateTime.fromMillisecondsSinceEpoch(12345);
      final orig = TaskEvent(
        taskId: 'rt2',
        success: false,
        message: 'Net error',
        errorCode: NativeWorkManagerError.networkError,
        timestamp: ts,
      );
      final copy = TaskEvent.fromMap(orig.toMap());
      expect(copy.errorCode, NativeWorkManagerError.networkError);
      expect(copy.message, 'Net error');
    });

    test('started event survives fromMap(toMap())', () {
      final ts = DateTime.fromMillisecondsSinceEpoch(99);
      final orig = TaskEvent(
        taskId: 'rt3',
        success: false,
        isStarted: true,
        workerType: 'ImageProcessWorker',
        timestamp: ts,
      );
      final copy = TaskEvent.fromMap(orig.toMap());
      expect(copy.isStarted, isTrue);
      expect(copy.workerType, 'ImageProcessWorker');
    });
  });

  // ─── TaskProgress ──────────────────────────────────────────────────────────

  group('TaskProgress construction', () {
    test('basic progress', () {
      const p = TaskProgress(taskId: 't', progress: 50);
      expect(p.taskId, 't');
      expect(p.progress, 50);
      expect(p.hasNetworkInfo, isFalse);
    });

    test('hasNetworkInfo true when all three fields set', () {
      const p = TaskProgress(
        taskId: 't',
        progress: 50,
        bytesDownloaded: 500,
        totalBytes: 1000,
        networkSpeed: 256.0,
      );
      expect(p.hasNetworkInfo, isTrue);
    });

    test('hasNetworkInfo false if any field null', () {
      const p = TaskProgress(
          taskId: 't', progress: 50, bytesDownloaded: 500, totalBytes: 1000);
      expect(p.hasNetworkInfo, isFalse);
    });
  });

  group('TaskProgress.fromMap', () {
    test('parses all fields', () {
      final p = TaskProgress.fromMap({
        'taskId': 'dl',
        'progress': 75,
        'message': 'Downloading…',
        'currentStep': 2,
        'totalSteps': 4,
        'bytesDownloaded': 750000,
        'totalBytes': 1000000,
        'networkSpeed': 512000.0,
        'timeRemainingMs': 2000,
      });
      expect(p.taskId, 'dl');
      expect(p.progress, 75);
      expect(p.message, 'Downloading…');
      expect(p.currentStep, 2);
      expect(p.totalSteps, 4);
      expect(p.bytesDownloaded, 750000);
      expect(p.totalBytes, 1000000);
      expect(p.networkSpeed, 512000.0);
      expect(p.timeRemaining, const Duration(seconds: 2));
    });

    test('timeRemainingSeconds is converted to milliseconds', () {
      final p = TaskProgress.fromMap(
          {'taskId': 't', 'progress': 0, 'timeRemainingSeconds': 30});
      expect(p.timeRemaining, const Duration(seconds: 30));
    });

    test('networkSpeedBytesPerSecond alias works', () {
      final p = TaskProgress.fromMap(
          {'taskId': 't', 'progress': 0, 'networkSpeedBytesPerSecond': 1024});
      expect(p.networkSpeed, 1024.0);
    });

    test('missing optional fields → null', () {
      final p = TaskProgress.fromMap({'taskId': 't', 'progress': 10});
      expect(p.message, isNull);
      expect(p.networkSpeed, isNull);
      expect(p.timeRemaining, isNull);
      expect(p.bytesDownloaded, isNull);
    });

    test('missing taskId defaults to empty string', () {
      final p = TaskProgress.fromMap({'progress': 0});
      expect(p.taskId, '');
    });

    test('missing progress defaults to 0', () {
      final p = TaskProgress.fromMap({'taskId': 't'});
      expect(p.progress, 0);
    });

    test('integer fields accept num (double)', () {
      final p = TaskProgress.fromMap(
          {'taskId': 't', 'progress': 33.0, 'bytesDownloaded': 100.0});
      expect(p.progress, 33);
      expect(p.bytesDownloaded, 100);
    });
  });

  group('TaskProgress equality and hashCode', () {
    test('identical instances are equal', () {
      const p = TaskProgress(taskId: 't', progress: 50);
      expect(p, equals(p));
    });

    test('same fields → equal', () {
      const a = TaskProgress(taskId: 't', progress: 50, message: 'x');
      const b = TaskProgress(taskId: 't', progress: 50, message: 'x');
      expect(a, equals(b));
    });

    test('different progress → not equal', () {
      const a = TaskProgress(taskId: 't', progress: 50);
      const b = TaskProgress(taskId: 't', progress: 60);
      expect(a, isNot(equals(b)));
    });

    test('different message → not equal', () {
      const a = TaskProgress(taskId: 't', progress: 0, message: 'a');
      const b = TaskProgress(taskId: 't', progress: 0, message: 'b');
      expect(a, isNot(equals(b)));
    });

    test('equal instances have equal hashCode', () {
      const a = TaskProgress(
          taskId: 't',
          progress: 50,
          networkSpeed: 1024.0,
          bytesDownloaded: 500,
          totalBytes: 1000);
      const b = TaskProgress(
          taskId: 't',
          progress: 50,
          networkSpeed: 1024.0,
          bytesDownloaded: 500,
          totalBytes: 1000);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('TaskProgress.toMap round-trip', () {
    test('full progress survives fromMap(toMap())', () {
      const orig = TaskProgress(
        taskId: 'up',
        progress: 80,
        message: 'Uploading',
        bytesDownloaded: 800,
        totalBytes: 1000,
        networkSpeed: 2048.0,
        timeRemaining: Duration(milliseconds: 500),
      );
      final copy = TaskProgress.fromMap(orig.toMap());
      expect(copy.taskId, orig.taskId);
      expect(copy.progress, orig.progress);
      expect(copy.message, orig.message);
      expect(copy.bytesDownloaded, orig.bytesDownloaded);
      expect(copy.totalBytes, orig.totalBytes);
      expect(copy.networkSpeed, orig.networkSpeed);
      expect(copy.timeRemaining, orig.timeRemaining);
    });
  });

  // ─── TaskRecord ────────────────────────────────────────────────────────────

  group('TaskRecord.fromMap', () {
    final baseMap = {
      'taskId': 'tr1',
      'tag': 'sync',
      'status': 'completed',
      'workerClassName': 'HttpSyncWorker',
      'workerConfig': '{"url":"https://x.com"}',
      'createdAt': 1000,
      'updatedAt': 2000,
    };

    test('parses required fields', () {
      final r = TaskRecord.fromMap(baseMap);
      expect(r.taskId, 'tr1');
      expect(r.tag, 'sync');
      expect(r.status, 'completed');
      expect(r.workerClassName, 'HttpSyncWorker');
    });

    test('parses timestamps', () {
      final r = TaskRecord.fromMap(baseMap);
      expect(r.createdAt.millisecondsSinceEpoch, 1000);
      expect(r.updatedAt.millisecondsSinceEpoch, 2000);
    });

    test('parses resultData as Map', () {
      final r = TaskRecord.fromMap({
        ...baseMap,
        'resultData': {'ok': true, 'count': 5},
      });
      expect(r.resultData?['ok'], isTrue);
      expect(r.resultData?['count'], 5);
    });

    test('parses resultData as JSON string', () {
      final r = TaskRecord.fromMap({
        ...baseMap,
        'resultData': '{"items":3}',
      });
      expect(r.resultData?['items'], 3);
    });

    test('parses resultData JSON string that is a list → wraps in map', () {
      final r = TaskRecord.fromMap({
        ...baseMap,
        'resultData': '[1,2,3]',
      });
      expect(r.resultData?['items'], [1, 2, 3]);
    });

    test('null resultData → null', () {
      final r = TaskRecord.fromMap({...baseMap, 'resultData': null});
      expect(r.resultData, isNull);
    });

    test('missing tag → null', () {
      final r = TaskRecord.fromMap({...baseMap, 'tag': null});
      expect(r.tag, isNull);
    });

    test('missing status defaults to "unknown"', () {
      final m = Map<String, dynamic>.from(baseMap)..remove('status');
      final r = TaskRecord.fromMap(m);
      expect(r.status, 'unknown');
    });

    test('toString contains taskId and status', () {
      final r = TaskRecord.fromMap(baseMap);
      expect(r.toString(), contains('tr1'));
      expect(r.toString(), contains('completed'));
    });
  });

  // ─── SystemError ───────────────────────────────────────────────────────────

  group('SystemError.fromMap', () {
    test('parses code and message', () {
      final e = SystemError.fromMap({
        'code': 'DISK_FULL',
        'message': 'Device out of storage',
        'timestamp': 5000,
      });
      expect(e.code, 'DISK_FULL');
      expect(e.message, 'Device out of storage');
      expect(e.timestamp.millisecondsSinceEpoch, 5000);
    });

    test('missing code defaults to UNKNOWN', () {
      final e = SystemError.fromMap({'message': 'm', 'timestamp': 0});
      expect(e.code, 'UNKNOWN');
    });

    test('missing message has default text', () {
      final e = SystemError.fromMap({'code': 'C', 'timestamp': 0});
      expect(e.message, isNotEmpty);
    });

    test('missing timestamp defaults to now', () {
      final before = DateTime.now();
      final e = SystemError.fromMap({'code': 'C', 'message': 'm'});
      expect(e.timestamp.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
    });

    test('toString contains code', () {
      final e = SystemError.fromMap(
          {'code': 'DISK_FULL', 'message': 'full', 'timestamp': 0});
      expect(e.toString(), contains('DISK_FULL'));
    });
  });
}
