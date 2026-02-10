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

  const MethodChannel channel = MethodChannel('dev.brewkits/native_workmanager');
  const EventChannel eventChannel = EventChannel('dev.brewkits/native_workmanager/events');

  group('NativeWorkManager API Tests -', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'enqueue':
            return true;
          case 'enqueueChain':
            return true;
          case 'cancel':
            return true;
          case 'cancelAll':
            return true;
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

      final result = await NativeWorkManager.enqueue(
        taskId: 'test-http-request',
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.get,
        ),
      );

      expect(result, equals(ScheduleResult.accepted));
    });

    test('enqueue() with HttpDownloadWorker', () async {
      await NativeWorkManager.initialize();

      final result = await NativeWorkManager.enqueue(
        taskId: 'test-download',
        trigger: TaskTrigger.oneTime(),
        worker: HttpDownloadWorker(
          url: 'https://example.com/file.zip',
          savePath: '/tmp/file.zip',
        ),
      );

      expect(result, equals(ScheduleResult.accepted));
    });

    test('enqueue() with HttpUploadWorker', () async {
      await NativeWorkManager.initialize();

      final result = await NativeWorkManager.enqueue(
        taskId: 'test-upload',
        trigger: TaskTrigger.oneTime(),
        worker: HttpUploadWorker(
          url: 'https://api.example.com/upload',
          filePath: '/tmp/file.zip',
        ),
      );

      expect(result, equals(ScheduleResult.accepted));
    });

    test('enqueue() with DartWorker', () async {
      await NativeWorkManager.initialize();

      final result = await NativeWorkManager.enqueue(
        taskId: 'test-dart',
        trigger: TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'testCallback'),
      );

      expect(result, equals(ScheduleResult.accepted));
    });

    test('enqueue() with all constraint types', () async {
      await NativeWorkManager.initialize();

      final result = await NativeWorkManager.enqueue(
        taskId: 'test-constraints',
        trigger: TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'test'),
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

      expect(result, equals(ScheduleResult.accepted));
    });

    test('cancel() task by ID', () async {
      await NativeWorkManager.initialize();

      // Enqueue a task first
      await NativeWorkManager.enqueue(
        taskId: 'test-cancel',
        trigger: TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'test'),
      );

      // Cancel it
      await NativeWorkManager.cancel('test-cancel');
      // Test passes if no exception thrown
    });

    test('cancelAll() tasks', () async {
      await NativeWorkManager.initialize();

      // Enqueue multiple tasks
      await NativeWorkManager.enqueue(
        taskId: 'test-1',
        trigger: TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'test'),
      );
      await NativeWorkManager.enqueue(
        taskId: 'test-2',
        trigger: TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'test'),
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
            return true;
          case 'enqueue':
            // Validate trigger format
            final args = call.arguments as Map<dynamic, dynamic>;
            final trigger = args['trigger'] as Map<dynamic, dynamic>;
            expect(trigger, containsPair('type', anything));
            return true;
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

      final result = await NativeWorkManager.enqueue(
        taskId: 'test-onetime',
        trigger: TaskTrigger.oneTime(const Duration(minutes: 5)),
        worker: DartWorker(callbackId: 'test'),
      );

      expect(result, equals(ScheduleResult.accepted));
    });

    test('Periodic trigger', () async {
      await NativeWorkManager.initialize();

      final result = await NativeWorkManager.enqueue(
        taskId: 'test-periodic',
        trigger: TaskTrigger.periodic(
          const Duration(hours: 1),
          flexInterval: const Duration(minutes: 15),
        ),
        worker: DartWorker(callbackId: 'test'),
      );

      expect(result, equals(ScheduleResult.accepted));
    });

    test('Exact trigger', () async {
      await NativeWorkManager.initialize();

      final result = await NativeWorkManager.enqueue(
        taskId: 'test-exact',
        trigger: TaskTrigger.exact(
          DateTime.now().add(const Duration(hours: 2)),
        ),
        worker: DartWorker(callbackId: 'test'),
      );

      expect(result, equals(ScheduleResult.accepted));
    });

    test('Windowed trigger', () async {
      await NativeWorkManager.initialize();

      final result = await NativeWorkManager.enqueue(
        taskId: 'test-windowed',
        trigger: TaskTrigger.windowed(
          earliest: const Duration(hours: 1),
          latest: const Duration(hours: 2),
        ),
        worker: DartWorker(callbackId: 'test'),
      );

      expect(result, equals(ScheduleResult.accepted));
    });

    test('ContentUri trigger (Android)', () async {
      await NativeWorkManager.initialize();

      final result = await NativeWorkManager.enqueue(
        taskId: 'test-content-uri',
        trigger: TaskTrigger.contentUri(
          uri: Uri.parse('content://media/external/images/media'),
          triggerForDescendants: true,
        ),
        worker: DartWorker(callbackId: 'test'),
      );

      expect(result, equals(ScheduleResult.accepted));
    });
  });

  group('Task Chains -', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'enqueueChain':
            // Validate chain format
            final args = call.arguments as Map<dynamic, dynamic>;
            final steps = args['steps'] as List<dynamic>;
            expect(steps, isNotEmpty);
            return true;
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
      ).then(
        TaskRequest(
          id: 'chain-2',
          worker: DartWorker(callbackId: 'process'),
        ),
      ).enqueue();

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
          worker: DartWorker(callbackId: 'process1'),
        ),
        TaskRequest(
          id: 'process-2',
          worker: DartWorker(callbackId: 'process2'),
        ),
        TaskRequest(
          id: 'process-3',
          worker: DartWorker(callbackId: 'process3'),
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
      ).then(
        TaskRequest(
          id: 'step-2',
          worker: HttpRequestWorker(
            url: 'https://api.example.com/data',
            method: HttpMethod.get,
          ),
        ),
      ).then(
        TaskRequest(
          id: 'step-3',
          worker: DartWorker(callbackId: 'process'),
        ),
      ).then(
        TaskRequest(
          id: 'step-4',
          worker: HttpUploadWorker(
            url: 'https://api.example.com/upload',
            filePath: '/tmp/result.json',
          ),
        ),
      ).enqueue();

      // Test passes if no exception thrown
    });
  });

  group('Event Stream -', () {
    late StreamController<Map<String, dynamic>> eventStreamController;

    setUp(() {
      eventStreamController = StreamController<Map<String, dynamic>>.broadcast();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'enqueue':
            // Simulate task completion event
            final args = call.arguments as Map<dynamic, dynamic>;
            final taskId = args['taskId'] as String;

            Future.delayed(const Duration(milliseconds: 50), () {
              eventStreamController.add({
                'taskId': taskId,
                'success': true,
                'message': 'Task completed successfully',
                'timestamp': DateTime.now().toIso8601String(),
                'resultData': {
                  'statusCode': 200,
                  'responseBody': '{"status":"ok"}',
                },
              });
            });
            return true;
          default:
            return null;
        }
      });

      // Mock event channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            eventChannel,
            MockStreamHandler.inline(
              onListen: (Object? arguments, MockStreamHandlerEventSink events) {
                eventStreamController.stream.listen(
                  (event) => events.success(event),
                  onError: (error) => events.error(
                    code: 'ERROR',
                    message: error.toString(),
                  ),
                  onDone: () => events.endOfStream(),
                );
              },
              onCancel: (Object? arguments) {
                // No-op
              },
            ),
          );
    });

    tearDown(() {
      eventStreamController.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(eventChannel, null);
    });

    test('receives completion event', () async {
      await NativeWorkManager.initialize();

      final eventFuture = NativeWorkManager.events.first;

      await NativeWorkManager.enqueue(
        taskId: 'test-event',
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.get,
        ),
      );

      final event = await eventFuture.timeout(const Duration(seconds: 5));

      expect(event.taskId, equals('test-event'));
      expect(event.success, isTrue);
      expect(event.resultData, isNotNull);
    });

    test('receives result data', () async {
      await NativeWorkManager.initialize();

      final eventFuture = NativeWorkManager.events.first;

      await NativeWorkManager.enqueue(
        taskId: 'test-result-data',
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.get,
        ),
      );

      final event = await eventFuture.timeout(const Duration(seconds: 5));

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
            return true;
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
            return true;
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

      expect(
        () => NativeWorkManager.enqueue(
          taskId: 'test-error',
          trigger: TaskTrigger.oneTime(),
          worker: DartWorker(callbackId: 'test'),
        ),
        throwsA(isA<PlatformException>()),
      );
    });

    test('validates required parameters', () async {
      await NativeWorkManager.initialize();

      // Empty taskId should throw
      expect(
        () => NativeWorkManager.enqueue(
          taskId: '',
          trigger: TaskTrigger.oneTime(),
          worker: DartWorker(callbackId: 'test'),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Worker Configuration -', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'enqueue':
            // Validate worker configuration
            final args = call.arguments as Map<dynamic, dynamic>;
            final worker = args['worker'] as Map<dynamic, dynamic>;
            expect(worker, containsPair('type', anything));
            expect(worker, containsPair('config', anything));
            return true;
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

      final result = await NativeWorkManager.enqueue(
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

      expect(result, equals(ScheduleResult.accepted));
    });

    test('HttpRequestWorker with body', () async {
      await NativeWorkManager.initialize();

      final result = await NativeWorkManager.enqueue(
        taskId: 'test-body',
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://api.example.com/data',
          method: HttpMethod.post,
          body: '{"userId": "123", "action": "sync"}',
        ),
      );

      expect(result, equals(ScheduleResult.accepted));
    });

    test('HttpDownloadWorker with headers', () async {
      await NativeWorkManager.initialize();

      final result = await NativeWorkManager.enqueue(
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

      expect(result, equals(ScheduleResult.accepted));
    });

    test('HttpUploadWorker with additional fields', () async {
      await NativeWorkManager.initialize();

      final result = await NativeWorkManager.enqueue(
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

      expect(result, equals(ScheduleResult.accepted));
    });
  });
}
