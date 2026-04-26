import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Comprehensive widget/integration tests for NativeWorkManager plugin.
///
/// These tests verify the full API surface with mocked platform channels,
/// testing the integration between Dart and native platforms.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('dev.brewkits/native_workmanager');
  const EventChannel eventChannel =
      EventChannel('dev.brewkits/native_workmanager/events');

  group('NativeWorkManager API Tests -', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return null; // void
          case 'enqueue':
            return 'accepted'; // invokeMethod<String>
          case 'enqueueChain':
            return 'accepted'; // invokeMethod<String>
          case 'cancel':
          case 'cancelAll':
            return null; // void
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('initialize() succeeds', () async {
      await NativeWorkManager.initialize();
      // Test passes if no exception thrown
    });

    test('enqueue() with HttpRequestWorker', () async {
      await NativeWorkManager.initialize();

      final handler = await NativeWorkManager.enqueue(
        taskId: 'test-http-request',
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.get,
        ),
      );

      expect(handler.scheduleResult, equals(ScheduleResult.accepted));
    });

    test('enqueue() with HttpDownloadWorker', () async {
      await NativeWorkManager.initialize();

      final handler = await NativeWorkManager.enqueue(
        taskId: 'test-download',
        trigger: TaskTrigger.oneTime(),
        worker: HttpDownloadWorker(
          url: 'https://example.com/file.zip',
          savePath: '/tmp/file.zip',
        ),
      );

      expect(handler.scheduleResult, equals(ScheduleResult.accepted));
    });

    test('enqueue() with HttpUploadWorker', () async {
      await NativeWorkManager.initialize();

      final handler = await NativeWorkManager.enqueue(
        taskId: 'test-upload',
        trigger: TaskTrigger.oneTime(),
        worker: HttpUploadWorker(
          url: 'https://api.example.com/upload',
          filePath: '/tmp/file.zip',
        ),
      );

      expect(handler.scheduleResult, equals(ScheduleResult.accepted));
    });

    test('enqueue() with DartWorker - throws StateError when not registered',
        () async {
      // DartWorker requires both registration AND a real Flutter VM callback
      // handle (PluginUtilities.getCallbackHandle). In unit tests, we can only
      // verify the registration check.
      await NativeWorkManager.initialize();

      expect(
        () => NativeWorkManager.enqueue(
          taskId: 'test-dart',
          trigger: TaskTrigger.oneTime(),
          worker: DartWorker(callbackId: 'unregistered-callback'),
        ),
        throwsStateError,
      );
    });

    test('enqueue() with all constraint types', () async {
      await NativeWorkManager.initialize();

      // Use HttpRequestWorker since DartWorker requires real Flutter VM callback handles
      final handler = await NativeWorkManager.enqueue(
        taskId: 'test-constraints',
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.get,
        ),
        constraints: const Constraints(
          requiresNetwork: true,
          requiresUnmeteredNetwork: true,
          requiresCharging: true,
          requiresBatteryNotLow: true,
          requiresStorageNotLow: true,
          requiresDeviceIdle: true,
          isHeavyTask: true,
          qos: QoS.userInitiated,
          backoffPolicy: BackoffPolicy.exponential,
          backoffDelayMs: 30000,
        ),
      );

      expect(handler.scheduleResult, equals(ScheduleResult.accepted));
    });

    test('cancel() task by ID', () async {
      await NativeWorkManager.initialize();

      // Enqueue a task first
      await NativeWorkManager.enqueue(
        taskId: 'test-cancel',
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.get,
        ),
      );

      // Cancel it
      await NativeWorkManager.cancel(taskId: 'test-cancel');
      // Test passes if no exception thrown
    });

    test('cancelAll() tasks', () async {
      await NativeWorkManager.initialize();

      // Enqueue multiple tasks
      await NativeWorkManager.enqueue(
        taskId: 'test-1',
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.get,
        ),
      );
      await NativeWorkManager.enqueue(
        taskId: 'test-2',
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.get,
        ),
      );

      // Cancel all
      await NativeWorkManager.cancelAll();
      // Test passes if no exception thrown
    });
  });

  group('Task Triggers -', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return null;
          case 'enqueue':
            // Validate trigger format
            final args = call.arguments as Map<dynamic, dynamic>;
            final trigger = args['trigger'] as Map<dynamic, dynamic>;
            expect(trigger, containsPair('type', anything));
            return 'accepted'; // invokeMethod<String>
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('OneTime trigger with delay', () async {
      await NativeWorkManager.initialize();

      final handler = await NativeWorkManager.enqueue(
        taskId: 'test-onetime',
        trigger: TaskTrigger.oneTime(const Duration(minutes: 5)),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.get,
        ),
      );

      expect(handler.scheduleResult, equals(ScheduleResult.accepted));
    });

    test('Periodic trigger', () async {
      await NativeWorkManager.initialize();

      final handler = await NativeWorkManager.enqueue(
        taskId: 'test-periodic',
        trigger: TaskTrigger.periodic(
          const Duration(hours: 1),
          flexInterval: const Duration(minutes: 15),
        ),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.get,
        ),
      );

      expect(handler.scheduleResult, equals(ScheduleResult.accepted));
    });

    test('Exact trigger', () async {
      await NativeWorkManager.initialize();

      final handler = await NativeWorkManager.enqueue(
        taskId: 'test-exact',
        trigger: TaskTrigger.exact(
          DateTime.now().add(const Duration(hours: 2)),
        ),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.get,
        ),
      );

      expect(handler.scheduleResult, equals(ScheduleResult.accepted));
    });

    test('Windowed trigger', () async {
      await NativeWorkManager.initialize();

      final handler = await NativeWorkManager.enqueue(
        taskId: 'test-windowed',
        trigger: TaskTrigger.windowed(
          earliest: const Duration(hours: 1),
          latest: const Duration(hours: 2),
        ),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.get,
        ),
      );

      expect(handler.scheduleResult, equals(ScheduleResult.accepted));
    });

    test('ContentUri trigger (Android)', () async {
      await NativeWorkManager.initialize();

      final handler = await NativeWorkManager.enqueue(
        taskId: 'test-content-uri',
        trigger: TaskTrigger.contentUri(
          uri: Uri.parse('content://media/external/images/media'),
          triggerForDescendants: true,
        ),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.get,
        ),
      );

      expect(handler.scheduleResult, equals(ScheduleResult.accepted));
    });
  });

  group('Task Chains -', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return null;
          case 'enqueueChain':
            // Validate chain format
            final args = call.arguments as Map<dynamic, dynamic>;
            final steps = args['steps'] as List<dynamic>;
            expect(steps, isNotEmpty);
            return 'accepted'; // invokeMethod<String>
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('Simple chain (A → B)', () async {
      await NativeWorkManager.initialize();

      await NativeWorkManager.beginWith(
        TaskRequest(
          id: 'chain-1',
          worker: HttpRequestWorker(
            url: 'https://api.example.com/data',
            method: HttpMethod.get,
          ),
        ),
      )
          .then(
            TaskRequest(
              id: 'chain-2',
              worker: HttpRequestWorker(
                url: 'https://api.example.com/process',
                method: HttpMethod.post,
              ),
            ),
          )
          .enqueue();

      // Test passes if no exception thrown
    });

    test('Chain with parallel step (A → [B, C, D])', () async {
      await NativeWorkManager.initialize();

      await NativeWorkManager.beginWith(
        TaskRequest(
          id: 'download',
          worker: HttpDownloadWorker(
            url: 'https://example.com/file.zip',
            savePath: '/tmp/file.zip',
          ),
        ),
      ).thenAll([
        TaskRequest(
          id: 'process-1',
          worker: HttpRequestWorker(
            url: 'https://api.example.com/step1',
            method: HttpMethod.post,
          ),
        ),
        TaskRequest(
          id: 'process-2',
          worker: HttpRequestWorker(
            url: 'https://api.example.com/step2',
            method: HttpMethod.post,
          ),
        ),
        TaskRequest(
          id: 'process-3',
          worker: HttpRequestWorker(
            url: 'https://api.example.com/step3',
            method: HttpMethod.post,
          ),
        ),
      ]).enqueue();

      // Test passes if no exception thrown
    });

    test('Multi-step chain (A → B → C → D)', () async {
      await NativeWorkManager.initialize();

      await NativeWorkManager.beginWith(
        TaskRequest(
          id: 'step-1',
          worker: HttpRequestWorker(
            url: 'https://api.example.com/auth',
            method: HttpMethod.post,
          ),
        ),
      )
          .then(
            TaskRequest(
              id: 'step-2',
              worker: HttpRequestWorker(
                url: 'https://api.example.com/data',
                method: HttpMethod.get,
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'step-3',
              worker: HttpRequestWorker(
                url: 'https://api.example.com/process',
                method: HttpMethod.post,
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'step-4',
              worker: HttpUploadWorker(
                url: 'https://api.example.com/upload',
                filePath: '/tmp/result.json',
              ),
            ),
          )
          .enqueue();

      // Test passes if no exception thrown
    });
  });

  group('Event Stream -', () {
    // NativeWorkManager uses a singleton with _initialized guard, so the event
    // channel subscription is set up only once. End-to-end event tests are in
    // device_integration_test.dart. These tests verify TaskEvent parsing.

    test('receives completion event - TaskEvent.fromMap parses correctly', () {
      final map = {
        'taskId': 'test-event',
        'success': true,
        'message': 'Task completed successfully',
        'timestamp':
            DateTime.now().millisecondsSinceEpoch, // int, not ISO string
        'resultData': {
          'statusCode': 200,
          'responseBody': '{"status":"ok"}',
        },
      };

      final event = TaskEvent.fromMap(map);

      expect(event.taskId, equals('test-event'));
      expect(event.success, isTrue);
      expect(event.resultData, isNotNull);
    });

    test('receives result data - TaskEvent.fromMap includes resultData', () {
      final map = {
        'taskId': 'test-result-data',
        'success': true,
        'resultData': {
          'statusCode': 200,
          'responseBody': '{"data":"value"}',
        },
      };

      final event = TaskEvent.fromMap(map);

      expect(event.resultData, isNotNull);
      expect(event.resultData, containsPair('statusCode', 200));
      expect(event.resultData, containsPair('responseBody', anything));
    });
  });

  group('Error Handling -', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return null;
          case 'enqueue':
            // Simulate various error conditions
            final args = call.arguments as Map<dynamic, dynamic>;
            final taskId = args['taskId'] as String;

            if (taskId.contains('error')) {
              throw PlatformException(
                code: 'TASK_ERROR',
                message: 'Task scheduling failed',
              );
            }
            return 'accepted'; // invokeMethod<String>
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('handles platform exception', () async {
      await NativeWorkManager.initialize();

      await expectLater(
        NativeWorkManager.enqueue(
          taskId: 'test-error',
          trigger: TaskTrigger.oneTime(),
          worker: HttpRequestWorker(
            url: 'https://api.example.com/data',
            method: HttpMethod.get,
          ),
        ),
        throwsA(isA<PlatformException>()),
      );
    });

    test('validates required parameters', () async {
      await NativeWorkManager.initialize();

      // Empty taskId throws ArgumentError
      expect(
        () => NativeWorkManager.enqueue(
          taskId: '',
          trigger: TaskTrigger.oneTime(),
          worker: HttpRequestWorker(
            url: 'https://api.example.com/data',
            method: HttpMethod.get,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Worker Configuration -', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return null;
          case 'enqueue':
            // Validate worker configuration — key is 'workerConfig' with 'workerType' field
            final args = call.arguments as Map<dynamic, dynamic>;
            final workerConfig = args['workerConfig'] as Map<dynamic, dynamic>;
            expect(workerConfig, containsPair('workerType', anything));
            return 'accepted'; // invokeMethod<String>
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('HttpRequestWorker with headers', () async {
      await NativeWorkManager.initialize();

      final handler = await NativeWorkManager.enqueue(
        taskId: 'test-headers',
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.get,
          headers: {
            'Authorization': 'Bearer token123',
            'User-Agent': 'MyApp/1.0',
          },
        ),
      );

      expect(handler.scheduleResult, equals(ScheduleResult.accepted));
    });

    test('HttpRequestWorker with body', () async {
      await NativeWorkManager.initialize();

      final handler = await NativeWorkManager.enqueue(
        taskId: 'test-body',
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.post,
          body: '{"userId": "123", "action": "sync"}',
        ),
      );

      expect(handler.scheduleResult, equals(ScheduleResult.accepted));
    });

    test('HttpDownloadWorker with headers', () async {
      await NativeWorkManager.initialize();

      final handler = await NativeWorkManager.enqueue(
        taskId: 'test-download-headers',
        trigger: TaskTrigger.oneTime(),
        worker: HttpDownloadWorker(
          url: 'https://example.com/file.zip',
          savePath: '/tmp/file.zip',
          headers: {
            'Authorization': 'Bearer token123',
          },
        ),
      );

      expect(handler.scheduleResult, equals(ScheduleResult.accepted));
    });

    test('HttpUploadWorker with additional fields', () async {
      await NativeWorkManager.initialize();

      final handler = await NativeWorkManager.enqueue(
        taskId: 'test-upload-fields',
        trigger: TaskTrigger.oneTime(),
        worker: HttpUploadWorker(
          url: 'https://api.example.com/upload',
          filePath: '/tmp/photo.jpg',
          fileFieldName: 'photo',
          fileName: 'profile.jpg',
          mimeType: 'image/jpeg',
          additionalFields: {
            'userId': '123',
            'description': 'Profile photo',
          },
        ),
      );

      expect(handler.scheduleResult, equals(ScheduleResult.accepted));
    });
  });

  group('Tag Operations & Task Status -', () {
    late String? capturedTag;
    late String? capturedTaskId;

    setUp(() {
      capturedTag = null;
      capturedTaskId = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return null;
          case 'enqueue':
            return 'accepted';
          case 'cancelByTag':
            capturedTag =
                (call.arguments as Map<dynamic, dynamic>)['tag'] as String?;
            return null;
          case 'getTasksByTag':
            capturedTag =
                (call.arguments as Map<dynamic, dynamic>)['tag'] as String?;
            return ['task-1', 'task-2'];
          case 'getAllTags':
            return ['sync', 'upload', 'backup'];
          case 'getTaskStatus':
            capturedTaskId =
                (call.arguments as Map<dynamic, dynamic>)['taskId'] as String?;
            return 'running';
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('cancelByTag() sends correct tag to platform', () async {
      await NativeWorkManager.initialize();

      await NativeWorkManager.cancelByTag(tag: 'sync-group');

      expect(capturedTag, equals('sync-group'));
    });

    test('cancelByTag() with empty tag throws ArgumentError (Dart validation)',
        () async {
      await NativeWorkManager.initialize();

      expect(
        () => NativeWorkManager.cancelByTag(tag: ''),
        throwsArgumentError,
      );
    });

    test('getTasksByTag() returns task list from platform', () async {
      await NativeWorkManager.initialize();

      final tasks = await NativeWorkManager.getTasksByTag(tag: 'upload');

      expect(capturedTag, equals('upload'));
      expect(tasks, equals(['task-1', 'task-2']));
    });

    test(
        'getTasksByTag() with empty tag throws ArgumentError (Dart validation)',
        () async {
      await NativeWorkManager.initialize();

      expect(
        () => NativeWorkManager.getTasksByTag(tag: ''),
        throwsArgumentError,
      );
    });

    test('getAllTags() returns all tags from platform', () async {
      await NativeWorkManager.initialize();

      final tags = await NativeWorkManager.getAllTags();

      expect(tags, containsAll(['sync', 'upload', 'backup']));
      expect(tags, hasLength(3));
    });

    test('getTaskStatus() returns correct status from platform', () async {
      await NativeWorkManager.initialize();

      final status = await NativeWorkManager.getTaskStatus(taskId: 'my-task');

      expect(capturedTaskId, equals('my-task'));
      expect(status, equals(TaskStatus.running));
    });

    test('getTaskStatus() returns null for unknown task', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return null;
          case 'getTaskStatus':
            return null; // Task not found
          default:
            return null;
        }
      });

      await NativeWorkManager.initialize();
      final status =
          await NativeWorkManager.getTaskStatus(taskId: 'unknown-task');

      expect(status, isNull);
    });

    test('getTaskStatus() parses all TaskStatus values correctly', () async {
      final statusValues = {
        'pending': TaskStatus.pending,
        'running': TaskStatus.running,
        'completed': TaskStatus.completed,
        'failed': TaskStatus.failed,
        'cancelled': TaskStatus.cancelled,
      };

      for (final entry in statusValues.entries) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'getTaskStatus') return entry.key;
          if (call.method == 'initialize') return null;
          return null;
        });

        await NativeWorkManager.initialize();
        final status = await NativeWorkManager.getTaskStatus(taskId: 'task');
        expect(status, equals(entry.value),
            reason: 'Failed to parse status "${entry.key}"');
      }
    });

    test('enqueue() with periodic trigger < 15 min throws ArgumentError',
        () async {
      await NativeWorkManager.initialize();

      expect(
        () => NativeWorkManager.enqueue(
          taskId: 'test-too-frequent',
          trigger: TaskTrigger.periodic(const Duration(minutes: 10)),
          worker: HttpRequestWorker(
            url: 'https://api.example.com/sync',
            method: HttpMethod.get,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('enqueue() with periodic trigger exactly 15 min succeeds', () async {
      await NativeWorkManager.initialize();

      final handler = await NativeWorkManager.enqueue(
        taskId: 'test-15min',
        trigger: TaskTrigger.periodic(const Duration(minutes: 15)),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/sync',
          method: HttpMethod.get,
        ),
      );

      expect(handler.scheduleResult, equals(ScheduleResult.accepted));
    });

    test('enqueue() with empty tag throws ArgumentError', () async {
      await NativeWorkManager.initialize();

      expect(
        () => NativeWorkManager.enqueue(
          taskId: 'test-empty-tag',
          trigger: TaskTrigger.oneTime(),
          worker: HttpRequestWorker(
            url: 'https://api.example.com/data',
            method: HttpMethod.get,
          ),
          tag: '',
        ),
        throwsArgumentError,
      );
    });

    test('enqueue() with valid tag passes tag to platform', () async {
      String? capturedEnqueueTag;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return null;
          case 'enqueue':
            final args = call.arguments as Map<dynamic, dynamic>;
            capturedEnqueueTag = args['tag'] as String?;
            return 'accepted';
          default:
            return null;
        }
      });

      await NativeWorkManager.initialize();
      await NativeWorkManager.enqueue(
        taskId: 'test-tagged',
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.get,
        ),
        tag: 'my-group',
      );

      expect(capturedEnqueueTag, equals('my-group'));
    });
  });
}
