import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('TaskProgress.fromMap Robustness', () {
    test('handles networkSpeed vs networkSpeedBytesPerSecond', () {
      final p1 = TaskProgress.fromMap({'taskId': 't1', 'networkSpeed': 100});
      final p2 = TaskProgress.fromMap(
          {'taskId': 't2', 'networkSpeedBytesPerSecond': 200});

      expect(p1.networkSpeed, 100.0);
      expect(p2.networkSpeed, 200.0);
    });

    test('handles timeRemainingMs vs timeRemainingSeconds', () {
      final p1 =
          TaskProgress.fromMap({'taskId': 't1', 'timeRemainingMs': 5000});
      final p2 =
          TaskProgress.fromMap({'taskId': 't2', 'timeRemainingSeconds': 10});

      expect(p1.timeRemaining?.inSeconds, 5);
      expect(p2.timeRemaining?.inSeconds, 10);
    });

    test('handles missing optional fields safely', () {
      final p = TaskProgress.fromMap({'taskId': 't1', 'progress': 50});
      expect(p.taskId, 't1');
      expect(p.progress, 50);
      expect(p.message, isNull);
      expect(p.networkSpeed, isNull);
      expect(p.timeRemaining, isNull);
    });
  });

  group('TaskEvent.fromMap Robustness', () {
    test('handles resultData as Map or null', () {
      final e1 = TaskEvent.fromMap({
        'taskId': 't1',
        'success': true,
        'resultData': {'foo': 'bar'},
        'timestamp': 123456789
      });
      final e2 = TaskEvent.fromMap({
        'taskId': 't2',
        'success': true,
        'resultData': null,
        'timestamp': 123456789
      });

      expect(e1.resultData?['foo'], 'bar');
      expect(e2.resultData, isNull);
    });

    test('handles missing timestamp safely', () {
      final e = TaskEvent.fromMap({
        'taskId': 't1',
        'success': true,
      });
      expect(e.timestamp, isA<DateTime>());
    });

    test('handles null success — defaults to false', () {
      final e = TaskEvent.fromMap({'taskId': 't', 'timestamp': 0});
      expect(e.success, isFalse);
    });

    test('handles empty map without crash', () {
      final e = TaskEvent.fromMap({});
      expect(e.taskId, '');
      expect(e.success, isFalse);
      expect(e.isStarted, isFalse);
    });

    test('handles resultData as non-map string — returns null', () {
      final e = TaskEvent.fromMap({
        'taskId': 't',
        'success': true,
        'resultData': 'plain-string',
        'timestamp': 0,
      });
      expect(e.resultData, isNull);
    });
  });

  group('TaskProgress edge cases', () {
    test('progress clamped to integer from double', () {
      final p = TaskProgress.fromMap({'taskId': 't', 'progress': 66.9});
      expect(p.progress, 66); // truncated
    });

    test('all zero numeric fields parse correctly', () {
      final p = TaskProgress.fromMap({
        'taskId': 't',
        'progress': 0,
        'bytesDownloaded': 0,
        'totalBytes': 0,
        'networkSpeed': 0.0,
      });
      expect(p.progress, 0);
      expect(p.bytesDownloaded, 0);
      expect(p.totalBytes, 0);
      expect(p.networkSpeed, 0.0);
    });

    test('timeRemainingMs=0 → Duration.zero', () {
      final p = TaskProgress.fromMap(
          {'taskId': 't', 'progress': 0, 'timeRemainingMs': 0});
      expect(p.timeRemaining, Duration.zero);
    });

    test('timeRemainingMs and timeRemainingSeconds both absent → null', () {
      final p = TaskProgress.fromMap({'taskId': 't', 'progress': 0});
      expect(p.timeRemaining, isNull);
    });

    test('step info is preserved', () {
      final p = TaskProgress.fromMap({
        'taskId': 't',
        'progress': 50,
        'currentStep': 3,
        'totalSteps': 6,
      });
      expect(p.currentStep, 3);
      expect(p.totalSteps, 6);
    });

    test('toString contains taskId and progress', () {
      const p = TaskProgress(taskId: 'my-task', progress: 42);
      expect(p.toString(), contains('my-task'));
      expect(p.toString(), contains('42'));
    });
  });

  group('TaskRecord edge cases', () {
    test('resultData as double-encoded JSON string is parsed', () {
      final r = TaskRecord.fromMap({
        'taskId': 't',
        'status': 'completed',
        'workerClassName': 'W',
        'resultData': '{"nested":{"key":1}}',
        'createdAt': 0,
        'updatedAt': 0,
      });
      final nested = r.resultData?['nested'];
      expect(nested, isA<Map>());
    });

    test('workerConfig is preserved as raw string', () {
      final r = TaskRecord.fromMap({
        'taskId': 't',
        'status': 'pending',
        'workerClassName': 'W',
        'workerConfig': '{"url":"https://x.com"}',
        'createdAt': 0,
        'updatedAt': 0,
      });
      expect(r.workerConfig, contains('url'));
    });

    test('toMap preserves all fields', () {
      final r = TaskRecord.fromMap({
        'taskId': 'rt',
        'tag': 'sync',
        'status': 'running',
        'workerClassName': 'HttpDownloadWorker',
        'workerConfig': '{}',
        'createdAt': 1000,
        'updatedAt': 2000,
      });
      final m = r.toMap();
      expect(m['taskId'], 'rt');
      expect(m['tag'], 'sync');
      expect(m['status'], 'running');
      expect(m['workerClassName'], 'HttpDownloadWorker');
      expect(m['createdAt'], 1000);
      expect(m['updatedAt'], 2000);
    });
  });

  group('NativeWorkManagerError edge cases', () {
    test('empty string returns unknown', () {
      expect(NativeWorkManagerError.fromString(''),
          NativeWorkManagerError.unknown);
    });

    test('whitespace string returns unknown', () {
      expect(NativeWorkManagerError.fromString(' NETWORK_ERROR '),
          NativeWorkManagerError.unknown);
    });

    test('all enum values have non-empty rawValue', () {
      for (final e in NativeWorkManagerError.values) {
        expect(e.rawValue, isNotEmpty,
            reason: '${e.name} rawValue should not be empty');
      }
    });

    test('all rawValues are unique', () {
      final rawValues = NativeWorkManagerError.values.map((e) => e.rawValue);
      expect(rawValues.toSet().length, NativeWorkManagerError.values.length);
    });
  });
}
