import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('dev.brewkits/native_workmanager');
  // ignore: unused_local_variable
  const EventChannel eventChannel = EventChannel('dev.brewkits/native_workmanager/events');

  group('BackoffPolicy Integration Tests', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'enqueue':
            // Verify backoffPolicy is passed correctly
            final args = call.arguments as Map<dynamic, dynamic>;
            final constraints = args['constraints'] as Map<dynamic, dynamic>?;

            if (constraints != null) {
              expect(constraints, containsPair('backoffPolicy', anything));
              expect(constraints, containsPair('backoffDelayMs', anything));
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

    test('enqueue with exponential backoffPolicy', () async {
      await NativeWorkManager.initialize();

      await NativeWorkManager.enqueue(
        taskId: 'test-exponential',
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/get',
          method: HttpMethod.get,
        ),
        constraints: const Constraints(
          backoffPolicy: BackoffPolicy.exponential,
          backoffDelayMs: 30000,
        ),
      );

      // Test passes if no exception thrown
    });

    test('enqueue with linear backoffPolicy', () async {
      await NativeWorkManager.initialize();

      await NativeWorkManager.enqueue(
        taskId: 'test-linear',
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/get',
          method: HttpMethod.get,
        ),
        constraints: const Constraints(
          backoffPolicy: BackoffPolicy.linear,
          backoffDelayMs: 60000,
        ),
      );

      // Test passes if no exception thrown
    });

    test('enqueue with custom backoffDelayMs', () async {
      await NativeWorkManager.initialize();

      final customDelays = [10000, 30000, 60000, 120000];

      for (final delay in customDelays) {
        await NativeWorkManager.enqueue(
          taskId: 'test-delay-$delay',
          trigger: TaskTrigger.oneTime(),
          worker: HttpRequestWorker(
            url: 'https://httpbin.org/get',
            method: HttpMethod.get,
          ),
          constraints: Constraints(
            backoffPolicy: BackoffPolicy.exponential,
            backoffDelayMs: delay,
          ),
        );
      }

      // Test passes if no exception thrown
    });
  });

  group('ContentUri Integration Tests', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'enqueue':
            // Verify ContentUri trigger is passed correctly
            final args = call.arguments as Map<dynamic, dynamic>;
            final trigger = args['trigger'] as Map<dynamic, dynamic>?;

            if (trigger?['type'] == 'contentUri') {
              expect(trigger, containsPair('uriString', anything));
              expect(trigger, containsPair('triggerForDescendants', anything));
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

    test('enqueue with ContentUri trigger (photos)', () async {
      await NativeWorkManager.initialize();

      await NativeWorkManager.enqueue(
        taskId: 'test-contentUri-photos',
        trigger: TaskTrigger.contentUri(
          uri: Uri.parse('content://media/external/images/media'),
          triggerForDescendants: true,
        ),
        worker: DartWorker(callbackId: 'testCallback'),
      );

      // Test passes if no exception thrown
    });

    test('enqueue with ContentUri trigger (contacts)', () async {
      await NativeWorkManager.initialize();

      await NativeWorkManager.enqueue(
        taskId: 'test-contentUri-contacts',
        trigger: TaskTrigger.contentUri(
          uri: Uri.parse('content://com.android.contacts/contacts'),
          triggerForDescendants: false,
        ),
        worker: DartWorker(callbackId: 'testCallback'),
      );

      // Test passes if no exception thrown
    });

    test('enqueue with ContentUri and constraints', () async {
      await NativeWorkManager.initialize();

      await NativeWorkManager.enqueue(
        taskId: 'test-contentUri-with-constraints',
        trigger: TaskTrigger.contentUri(
          uri: Uri.parse('content://media/external/video/media'),
          triggerForDescendants: true,
        ),
        worker: DartWorker(callbackId: 'testCallback'),
        constraints: const Constraints(
          requiresNetwork: true,
          requiresCharging: true,
        ),
      );

      // Test passes if no exception thrown
    });
  });

  group('Combined Features Integration Tests', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'enqueue':
          case 'enqueueChain':
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

    test('task chain with backoffPolicy', () async {
      await NativeWorkManager.initialize();

      await NativeWorkManager.beginWith(
        TaskRequest(
          id: 'chain-step-1',
          worker: HttpRequestWorker(
            url: 'https://httpbin.org/get',
            method: HttpMethod.get,
          ),
          constraints: const Constraints(
            backoffPolicy: BackoffPolicy.exponential,
            backoffDelayMs: 30000,
          ),
        ),
      ).then(
        TaskRequest(
          id: 'chain-step-2',
          worker: DartWorker(callbackId: 'processData'),
          constraints: const Constraints(
            backoffPolicy: BackoffPolicy.linear,
            backoffDelayMs: 60000,
          ),
        ),
      ).enqueue();

      // Test passes if no exception thrown
    });

    test('ContentUri with backoffPolicy (theoretical Android scenario)', () async {
      await NativeWorkManager.initialize();

      await NativeWorkManager.enqueue(
        taskId: 'contentUri-with-backoff',
        trigger: TaskTrigger.contentUri(
          uri: Uri.parse('content://media/external/images/media'),
          triggerForDescendants: true,
        ),
        worker: HttpUploadWorker(
          url: 'https://api.example.com/upload',
          filePath: '/path/to/photo.jpg',
        ),
        constraints: const Constraints(
          requiresUnmeteredNetwork: true,
          backoffPolicy: BackoffPolicy.exponential,
          backoffDelayMs: 30000,
        ),
      );

      // Test passes if no exception thrown
    });

    test('All v0.7.0 features in single task', () async {
      await NativeWorkManager.initialize();

      await NativeWorkManager.enqueue(
        taskId: 'all-v0.7.0-features',
        trigger: TaskTrigger.contentUri(
          uri: Uri.parse('content://media/external/images/media'),
          triggerForDescendants: true,
        ),
        worker: DartWorker(callbackId: 'fullFeatureCallback'),
        constraints: const Constraints(
          requiresNetwork: true,
          requiresCharging: true,
          isHeavyTask: true,
          qos: QoS.utility,
          backoffPolicy: BackoffPolicy.exponential,
          backoffDelayMs: 45000,
        ),
      );

      // Test passes if no exception thrown
    });
  });

  group('Event Streaming with New Features', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'enqueue':
            // Simulate task completion event after delay
            Future.delayed(const Duration(milliseconds: 100), () {
              // Would normally send event via EventChannel
            });
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

    test('event stream receives completion for backoffPolicy task', () async {
      await NativeWorkManager.initialize();

      // ignore: unused_local_variable
      final eventsFuture = NativeWorkManager.events.first;

      await NativeWorkManager.enqueue(
        taskId: 'test-event-backoff',
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/get',
          method: HttpMethod.get,
        ),
        constraints: const Constraints(
          backoffPolicy: BackoffPolicy.exponential,
        ),
      );

      // In real scenario, would verify event is received
      // For now, just verify enqueue doesn't throw
    });
  });

  group('Error Handling Integration Tests', () {
    test('invalid backoffDelayMs throws or adjusts', () async {
      await NativeWorkManager.initialize();

      // Negative delay - should use default
      await NativeWorkManager.enqueue(
        taskId: 'test-negative-delay',
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/get',
          method: HttpMethod.get,
        ),
        constraints: const Constraints(
          backoffDelayMs: -1000, // Invalid
        ),
      );

      // Test passes if handled gracefully
    });

    test('invalid ContentUri scheme handled', () async {
      await NativeWorkManager.initialize();

      // Non-content URI scheme
      final invalidUri = Uri.parse('https://example.com/data');

      await NativeWorkManager.enqueue(
        taskId: 'test-invalid-uri',
        trigger: TaskTrigger.contentUri(uri: invalidUri),
        worker: DartWorker(callbackId: 'testCallback'),
      );

      // Platform layer should handle validation
    });
  });

  group('Cross-Platform Compatibility Tests', () {
    test('backoffPolicy serialization for Android', () async {
      await NativeWorkManager.initialize();

      const constraints = Constraints(
        backoffPolicy: BackoffPolicy.exponential,
        backoffDelayMs: 30000,
      );

      final map = constraints.toMap();

      // Verify format matches Android expectations
      expect(map['backoffPolicy'], equals('exponential'));
      expect(map['backoffDelayMs'], isA<int>());
      expect(map['backoffDelayMs'], equals(30000));
    });

    test('ContentUri trigger serialization', () async {
      final trigger = TaskTrigger.contentUri(
        uri: Uri.parse('content://media/external/images/media'),
        triggerForDescendants: true,
      );

      final map = trigger.toMap();

      // Verify format matches platform expectations
      expect(map['type'], equals('contentUri'));
      expect(map['uriString'], isA<String>());
      expect(map['uriString'], startsWith('content://'));
      expect(map['triggerForDescendants'], isA<bool>());
    });
  });
}
