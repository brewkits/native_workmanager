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
  });
}
