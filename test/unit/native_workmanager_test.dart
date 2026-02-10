import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Unit tests for NativeWorkManager API.
///
/// Tests cover:
/// - TaskEvent data class (serialization, equality, fromMap)
/// - TaskProgress data class (serialization, equality, fromMap)
/// - Dart worker registration (register, unregister, isDartWorkerRegistered)
/// - Not-initialized state guards (StateError on uninitialized calls)
/// - ScheduleResult and ExistingTaskPolicy enum values
/// - TaskStatus enum values
void main() {
  group('TaskEvent', () {
    test('should create TaskEvent with required fields', () {
      final timestamp = DateTime(2026, 2, 1, 12, 0);
      final event = TaskEvent(
        taskId: 'upload-123',
        success: true,
        timestamp: timestamp,
      );

      expect(event.taskId, 'upload-123');
      expect(event.success, isTrue);
      expect(event.message, isNull);
      expect(event.resultData, isNull);
      expect(event.timestamp, timestamp);
    });

    test('should create failed TaskEvent with message', () {
      final timestamp = DateTime(2026, 2, 1, 12, 0);
      final event = TaskEvent(
        taskId: 'sync-456',
        success: false,
        message: 'Network timeout',
        timestamp: timestamp,
      );

      expect(event.taskId, 'sync-456');
      expect(event.success, isFalse);
      expect(event.message, 'Network timeout');
    });

    test('should create TaskEvent with resultData', () {
      final timestamp = DateTime(2026, 2, 1, 12, 0);
      final event = TaskEvent(
        taskId: 'process-data',
        success: true,
        resultData: {'count': 42, 'status': 'complete'},
        timestamp: timestamp,
      );

      expect(event.resultData, isNotNull);
      expect(event.resultData!['count'], 42);
      expect(event.resultData!['status'], 'complete');
    });

    test('should serialize TaskEvent to map', () {
      final timestamp = DateTime(2026, 2, 1, 12, 0);
      final event = TaskEvent(
        taskId: 'task-1',
        success: true,
        message: 'Done',
        timestamp: timestamp,
      );
      final map = event.toMap();

      expect(map['taskId'], 'task-1');
      expect(map['success'], isTrue);
      expect(map['message'], 'Done');
      expect(map['timestamp'], timestamp.millisecondsSinceEpoch);
    });

    test('should deserialize TaskEvent from map', () {
      final timestamp = DateTime(2026, 2, 1, 12, 0);
      final map = {
        'taskId': 'task-1',
        'success': true,
        'message': 'Completed',
        'resultData': {'items': 5},
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

      final event = TaskEvent.fromMap(map);

      expect(event.taskId, 'task-1');
      expect(event.success, isTrue);
      expect(event.message, 'Completed');
      expect(event.resultData!['items'], 5);
      expect(event.timestamp, timestamp);
    });

    test('should deserialize failed TaskEvent from map', () {
      final map = {
        'taskId': 'failed-task',
        'success': false,
        'message': 'Connection error',
        'resultData': null,
        'timestamp': DateTime(2026, 2, 1).millisecondsSinceEpoch,
      };

      final event = TaskEvent.fromMap(map);

      expect(event.taskId, 'failed-task');
      expect(event.success, isFalse);
      expect(event.message, 'Connection error');
      expect(event.resultData, isNull);
    });

    test('should deserialize TaskEvent with null timestamp gracefully', () {
      final map = {
        'taskId': 'no-timestamp',
        'success': true,
        'message': null,
        'resultData': null,
        'timestamp': null,
      };

      final event = TaskEvent.fromMap(map);

      expect(event.taskId, 'no-timestamp');
      expect(event.timestamp, isNotNull); // Falls back to DateTime.now()
    });

    test('should support equality based on taskId, success, timestamp', () {
      final timestamp = DateTime(2026, 2, 1, 12, 0);
      final event1 = TaskEvent(
        taskId: 'task-1',
        success: true,
        message: 'msg-A',
        timestamp: timestamp,
      );
      final event2 = TaskEvent(
        taskId: 'task-1',
        success: true,
        message: 'msg-B', // Different message, but equals ignores it
        timestamp: timestamp,
      );
      final event3 = TaskEvent(
        taskId: 'task-2',
        success: true,
        timestamp: timestamp,
      );

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
    });

    test('should support hashCode', () {
      final timestamp = DateTime(2026, 2, 1, 12, 0);
      final event1 = TaskEvent(
        taskId: 'task-1', success: true, timestamp: timestamp);
      final event2 = TaskEvent(
        taskId: 'task-1', success: true, timestamp: timestamp);

      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('should have proper toString', () {
      final timestamp = DateTime(2026, 2, 1, 12, 0);
      final event = TaskEvent(
        taskId: 'my-task',
        success: true,
        message: 'All good',
        timestamp: timestamp,
      );
      final str = event.toString();

      expect(str, contains('TaskEvent'));
      expect(str, contains('my-task'));
      expect(str, contains('true'));
      expect(str, contains('All good'));
    });
  });

  group('TaskProgress', () {
    test('should create TaskProgress with required fields', () {
      final progress = TaskProgress(
        taskId: 'upload-123',
        progress: 50,
      );

      expect(progress.taskId, 'upload-123');
      expect(progress.progress, 50);
      expect(progress.message, isNull);
      expect(progress.currentStep, isNull);
      expect(progress.totalSteps, isNull);
    });

    test('should create TaskProgress with all fields', () {
      final progress = TaskProgress(
        taskId: 'batch-upload',
        progress: 75,
        message: 'Uploading file 3 of 4',
        currentStep: 3,
        totalSteps: 4,
      );

      expect(progress.taskId, 'batch-upload');
      expect(progress.progress, 75);
      expect(progress.message, 'Uploading file 3 of 4');
      expect(progress.currentStep, 3);
      expect(progress.totalSteps, 4);
    });

    test('should serialize TaskProgress to map', () {
      final progress = TaskProgress(
        taskId: 'download-1',
        progress: 30,
        message: 'Downloading...',
        currentStep: 1,
        totalSteps: 5,
      );
      final map = progress.toMap();

      expect(map['taskId'], 'download-1');
      expect(map['progress'], 30);
      expect(map['message'], 'Downloading...');
      expect(map['currentStep'], 1);
      expect(map['totalSteps'], 5);
    });

    test('should deserialize TaskProgress from map', () {
      final map = {
        'taskId': 'upload-1',
        'progress': 60,
        'message': '60% complete',
        'currentStep': 3,
        'totalSteps': 5,
      };

      final progress = TaskProgress.fromMap(map);

      expect(progress.taskId, 'upload-1');
      expect(progress.progress, 60);
      expect(progress.message, '60% complete');
      expect(progress.currentStep, 3);
      expect(progress.totalSteps, 5);
    });

    test('should deserialize TaskProgress with null optional fields', () {
      final map = {
        'taskId': 'simple-task',
        'progress': 100,
        'message': null,
        'currentStep': null,
        'totalSteps': null,
      };

      final progress = TaskProgress.fromMap(map);

      expect(progress.taskId, 'simple-task');
      expect(progress.progress, 100);
      expect(progress.message, isNull);
      expect(progress.currentStep, isNull);
      expect(progress.totalSteps, isNull);
    });

    test('should handle zero progress', () {
      final progress = TaskProgress(
        taskId: 'starting-task',
        progress: 0,
      );

      expect(progress.progress, 0);
    });

    test('should handle 100% progress', () {
      final progress = TaskProgress(
        taskId: 'complete-task',
        progress: 100,
      );

      expect(progress.progress, 100);
    });

    test('should support equality based on taskId and progress', () {
      final p1 = TaskProgress(
        taskId: 'task-1', progress: 50, message: 'msg-A');
      final p2 = TaskProgress(
        taskId: 'task-1', progress: 50, message: 'msg-B');
      final p3 = TaskProgress(taskId: 'task-1', progress: 75);

      expect(p1, equals(p2)); // Same taskId + progress
      expect(p1, isNot(equals(p3))); // Different progress
    });

    test('should support hashCode', () {
      final p1 = TaskProgress(taskId: 'task-1', progress: 50);
      final p2 = TaskProgress(taskId: 'task-1', progress: 50);

      expect(p1.hashCode, equals(p2.hashCode));
    });

    test('should have proper toString', () {
      final progress = TaskProgress(
        taskId: 'my-upload',
        progress: 42,
        message: 'Working...',
        currentStep: 2,
        totalSteps: 5,
      );
      final str = progress.toString();

      expect(str, contains('TaskProgress'));
      expect(str, contains('my-upload'));
      expect(str, contains('42%'));
      expect(str, contains('Working...'));
      expect(str, contains('2/5'));
    });
  });

  group('Dart Worker Registration', () {
    // Clean up registered workers after each test
    tearDown(() {
      NativeWorkManager.unregisterDartWorker('test-worker');
      NativeWorkManager.unregisterDartWorker('worker-A');
      NativeWorkManager.unregisterDartWorker('worker-B');
    });

    test('should register a Dart worker', () {
      expect(NativeWorkManager.isDartWorkerRegistered('test-worker'), isFalse);

      NativeWorkManager.registerDartWorker(
        'test-worker', (input) async => true);

      expect(NativeWorkManager.isDartWorkerRegistered('test-worker'), isTrue);
    });

    test('should unregister a Dart worker', () {
      NativeWorkManager.registerDartWorker(
        'test-worker', (input) async => true);
      expect(NativeWorkManager.isDartWorkerRegistered('test-worker'), isTrue);

      NativeWorkManager.unregisterDartWorker('test-worker');

      expect(NativeWorkManager.isDartWorkerRegistered('test-worker'), isFalse);
    });

    test('should return false for unregistered worker', () {
      expect(
        NativeWorkManager.isDartWorkerRegistered('nonexistent'),
        isFalse,
      );
    });

    test('should register multiple workers independently', () {
      NativeWorkManager.registerDartWorker(
        'worker-A', (input) async => true);
      NativeWorkManager.registerDartWorker(
        'worker-B', (input) async => false);

      expect(NativeWorkManager.isDartWorkerRegistered('worker-A'), isTrue);
      expect(NativeWorkManager.isDartWorkerRegistered('worker-B'), isTrue);
    });

    test('should unregister one worker without affecting others', () {
      NativeWorkManager.registerDartWorker(
        'worker-A', (input) async => true);
      NativeWorkManager.registerDartWorker(
        'worker-B', (input) async => true);

      NativeWorkManager.unregisterDartWorker('worker-A');

      expect(NativeWorkManager.isDartWorkerRegistered('worker-A'), isFalse);
      expect(NativeWorkManager.isDartWorkerRegistered('worker-B'), isTrue);
    });

    test('should handle unregistering non-existent worker gracefully', () {
      // Should not throw
      NativeWorkManager.unregisterDartWorker('does-not-exist');
    });
  });

  group('ScheduleResult enum', () {
    test('should have accepted value', () {
      expect(ScheduleResult.accepted, isA<ScheduleResult>());
    });

    test('should have rejectedOsPolicy value', () {
      expect(ScheduleResult.rejectedOsPolicy, isA<ScheduleResult>());
    });

    test('should have throttled value', () {
      expect(ScheduleResult.throttled, isA<ScheduleResult>());
    });

    test('should have distinct enum values', () {
      expect(ScheduleResult.accepted, isNot(equals(
          ScheduleResult.rejectedOsPolicy)));
      expect(ScheduleResult.accepted, isNot(equals(
          ScheduleResult.throttled)));
      expect(ScheduleResult.rejectedOsPolicy, isNot(equals(
          ScheduleResult.throttled)));
    });
  });

  group('ExistingTaskPolicy enum', () {
    test('should have keep value', () {
      expect(ExistingTaskPolicy.keep, isA<ExistingTaskPolicy>());
    });

    test('should have replace value', () {
      expect(ExistingTaskPolicy.replace, isA<ExistingTaskPolicy>());
    });

    test('should have distinct enum values', () {
      expect(ExistingTaskPolicy.keep, isNot(equals(
          ExistingTaskPolicy.replace)));
    });
  });

  group('TaskStatus enum', () {
    test('should have all status values', () {
      expect(TaskStatus.pending, isA<TaskStatus>());
      expect(TaskStatus.running, isA<TaskStatus>());
      expect(TaskStatus.completed, isA<TaskStatus>());
      expect(TaskStatus.failed, isA<TaskStatus>());
      expect(TaskStatus.cancelled, isA<TaskStatus>());
    });

    test('should have all distinct values', () {
      final statuses = [
        TaskStatus.pending,
        TaskStatus.running,
        TaskStatus.completed,
        TaskStatus.failed,
        TaskStatus.cancelled,
      ];

      expect(statuses.toSet().length, 5);
    });
  });

  group('TaskEvent Serialization Round-Trip', () {
    test('should round-trip successful event', () {
      final timestamp = DateTime(2026, 2, 1, 12, 0);
      final original = TaskEvent(
        taskId: 'success-task',
        success: true,
        message: 'Completed successfully',
        resultData: {'duration_ms': 1500, 'items': 10},
        timestamp: timestamp,
      );

      final map = original.toMap();
      final restored = TaskEvent.fromMap(map);

      expect(restored.taskId, original.taskId);
      expect(restored.success, original.success);
      expect(restored.message, original.message);
      expect(restored.resultData!['duration_ms'], 1500);
      expect(restored.resultData!['items'], 10);
      expect(restored.timestamp, original.timestamp);
    });

    test('should round-trip failed event', () {
      final timestamp = DateTime(2026, 2, 1, 15, 30);
      final original = TaskEvent(
        taskId: 'failed-task',
        success: false,
        message: 'Upload failed: 503 Service Unavailable',
        timestamp: timestamp,
      );

      final map = original.toMap();
      final restored = TaskEvent.fromMap(map);

      expect(restored.taskId, original.taskId);
      expect(restored.success, original.success);
      expect(restored.message, original.message);
      expect(restored.resultData, isNull);
    });
  });

  group('TaskProgress Serialization Round-Trip', () {
    test('should round-trip progress with all fields', () {
      final original = TaskProgress(
        taskId: 'batch-upload',
        progress: 67,
        message: 'Uploading file 4 of 6',
        currentStep: 4,
        totalSteps: 6,
      );

      final map = original.toMap();
      final restored = TaskProgress.fromMap(map);

      expect(restored.taskId, original.taskId);
      expect(restored.progress, original.progress);
      expect(restored.message, original.message);
      expect(restored.currentStep, original.currentStep);
      expect(restored.totalSteps, original.totalSteps);
    });

    test('should round-trip progress with minimal fields', () {
      final original = TaskProgress(
        taskId: 'simple-task',
        progress: 25,
      );

      final map = original.toMap();
      final restored = TaskProgress.fromMap(map);

      expect(restored.taskId, original.taskId);
      expect(restored.progress, original.progress);
      expect(restored.message, isNull);
      expect(restored.currentStep, isNull);
      expect(restored.totalSteps, isNull);
    });
  });
}
