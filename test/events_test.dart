import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('TaskEvent -', () {
    test('creates event with all fields', () {
      final now = DateTime.now();
      final resultData = {
        'filePath': '/tmp/file.txt',
        'fileSize': 1024,
      };

      final event = TaskEvent(
        taskId: 'test-task',
        success: true,
        message: 'Task completed',
        timestamp: now,
        resultData: resultData,
      );

      expect(event.taskId, 'test-task');
      expect(event.success, true);
      expect(event.message, 'Task completed');
      expect(event.timestamp, now);
      expect(event.resultData, resultData);
    });

    test('creates event without optional fields', () {
      final now = DateTime.now();

      final event = TaskEvent(
        taskId: 'test-task',
        success: false,
        timestamp: now,
      );

      expect(event.taskId, 'test-task');
      expect(event.success, false);
      expect(event.message, isNull);
      expect(event.resultData, isNull);
      expect(event.timestamp, now);
    });

    test('equality works correctly', () {
      final now = DateTime.now();

      final event1 = TaskEvent(
        taskId: 'test',
        success: true,
        message: 'Done',
        timestamp: now,
      );

      final event2 = TaskEvent(
        taskId: 'test',
        success: true,
        message: 'Done',
        timestamp: now,
      );

      final event3 = TaskEvent(
        taskId: 'other',
        success: true,
        message: 'Done',
        timestamp: now,
      );

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
    });

    test('hashCode is consistent', () {
      final now = DateTime.now();

      final event1 = TaskEvent(
        taskId: 'test',
        success: true,
        timestamp: now,
      );

      final event2 = TaskEvent(
        taskId: 'test',
        success: true,
        timestamp: now,
      );

      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('toString() is descriptive', () {
      final now = DateTime.now();

      final event = TaskEvent(
        taskId: 'test-task',
        success: true,
        message: 'Completed',
        timestamp: now,
        resultData: {'key': 'value'},
      );

      final str = event.toString();

      expect(str, contains('test-task'));
      expect(str, contains('success'));
      expect(str, contains('Completed'));
    });
  });

  group('TaskProgress -', () {
    test('creates progress event', () {
      final event = TaskProgress(
        taskId: 'download-task',
        progress: 50,
        message: 'Downloading...',
      );

      expect(event.taskId, 'download-task');
      expect(event.progress, 50);
      expect(event.message, 'Downloading...');
    });

    test('creates progress event without message', () {
      final event = TaskProgress(
        taskId: 'task',
        progress: 75,
      );

      expect(event.taskId, 'task');
      expect(event.progress, 75);
      expect(event.message, isNull);
    });

    test('progress validation - accepts 0', () {
      final event = TaskProgress(
        taskId: 'task',
        progress: 0,
      );

      expect(event.progress, 0);
    });

    test('progress validation - accepts 100', () {
      final event = TaskProgress(
        taskId: 'task',
        progress: 100,
      );

      expect(event.progress, 100);
    });

    test('equality works correctly', () {
      final event1 = TaskProgress(
        taskId: 'task',
        progress: 50,
        message: 'Loading',
      );

      final event2 = TaskProgress(
        taskId: 'task',
        progress: 50,
        message: 'Loading',
      );

      final event3 = TaskProgress(
        taskId: 'task',
        progress: 75,
        message: 'Loading',
      );

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
    });

    test('toString() is descriptive', () {
      final event = TaskProgress(
        taskId: 'upload',
        progress: 65,
        message: 'Uploading file...',
      );

      final str = event.toString();

      expect(str, contains('upload'));
      expect(str, contains('65'));
      expect(str, contains('Uploading'));
    });
  });

  group('ScheduleResult -', () {
    test('all enum values exist', () {
      expect(ScheduleResult.values, hasLength(3));
      expect(ScheduleResult.values, contains(ScheduleResult.accepted));
      expect(ScheduleResult.values, contains(ScheduleResult.rejectedOsPolicy));
      expect(ScheduleResult.values, contains(ScheduleResult.throttled));
    });

    test('enum values have correct names', () {
      expect(ScheduleResult.accepted.name, 'accepted');
      expect(ScheduleResult.rejectedOsPolicy.name, 'rejectedOsPolicy');
      expect(ScheduleResult.throttled.name, 'throttled');
    });
  });
}
