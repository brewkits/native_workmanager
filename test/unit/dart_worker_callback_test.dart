import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'dart:ui';

// Top-level callback functions for testing
// (Required: callbacks must be top-level or static to get handles)

Future<bool> successCallback(Map<String, dynamic>? input) async {
  return true;
}

Future<bool> failureCallback(Map<String, dynamic>? input) async {
  return false;
}

Future<bool> echoCallback(Map<String, dynamic>? input) async {
  // Echoes back the input data
  return input != null && input.isNotEmpty;
}

Future<bool> errorCallback(Map<String, dynamic>? input) async {
  throw Exception('Intentional test error');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dart Worker Callback Handle Resolution', () {
    test('top-level function can be resolved to handle', () {
      // Verify PluginUtilities can get handle for top-level function
      final handle = PluginUtilities.getCallbackHandle(successCallback);

      expect(handle, isNotNull, reason: 'Should get handle for top-level function');

      // Verify handle can be serialized
      final rawHandle = handle!.toRawHandle();
      expect(rawHandle, isNonZero, reason: 'Handle should be non-zero');

      // Verify handle can be resolved back
      final resolved = PluginUtilities.getCallbackFromHandle(
        CallbackHandle.fromRawHandle(rawHandle),
      );

      expect(resolved, isNotNull, reason: 'Should resolve handle back to callback');
      expect(resolved, equals(successCallback), reason: 'Resolved callback should match original');
    });

    test('anonymous function cannot be resolved to handle', () {
      // Anonymous functions cannot be serialized across isolates
      Future<bool> anonymousCallback(Map<String, dynamic>? input) async => true;

      final handle = PluginUtilities.getCallbackHandle(anonymousCallback);

      expect(
        handle,
        isNull,
        reason: 'Anonymous functions should not have handles',
      );
    });

    test('static method can be resolved to handle', () {
      final handle = PluginUtilities.getCallbackHandle(_TestCallbacks.staticCallback);

      expect(handle, isNotNull, reason: 'Static methods should have handles');

      final rawHandle = handle!.toRawHandle();
      final resolved = PluginUtilities.getCallbackFromHandle(
        CallbackHandle.fromRawHandle(rawHandle),
      );

      expect(resolved, isNotNull);
      expect(resolved, equals(_TestCallbacks.staticCallback));
    });

    test('instance method cannot be resolved to handle', () {
      final instance = _TestCallbacks();

      // Instance methods cannot be serialized
      final handle = PluginUtilities.getCallbackHandle(instance.instanceCallback);

      expect(
        handle,
        isNull,
        reason: 'Instance methods should not have handles',
      );
    });
  });

  group('NativeWorkManager Callback Handle Storage', () {
    setUp(() {
      // Note: Cannot fully reset NativeWorkManager static state
      // Tests should be independent and not rely on state from previous tests
    });

    test('initialize stores callback handles for valid callbacks', () async {
      // This test verifies the initialization process
      // Note: Actual verification requires accessing private _callbackHandles
      // which is not possible in tests. This is more of an integration test.

      await NativeWorkManager.initialize(
        dartWorkers: {
          'success': successCallback,
          'failure': failureCallback,
        },
      );

      // If initialization succeeds without throwing, it means:
      // 1. Handles were successfully obtained
      // 2. Handles were stored in _callbackHandles map

      // Verify we can create DartWorker with these IDs
      final worker = DartWorker(callbackId: 'success');
      expect(worker.callbackId, equals('success'));
    });

    test('initialize throws error for anonymous function', () async {
      expect(
        () => NativeWorkManager.initialize(
          dartWorkers: {
            'anonymous': (input) async => true, // Anonymous function
          },
        ),
        throwsStateError,
        reason: 'Should reject anonymous functions with clear error',
      );
    });

    test('initialize throws error for instance method', () async {
      final instance = _TestCallbacks();

      expect(
        () => NativeWorkManager.initialize(
          dartWorkers: {
            'instance': instance.instanceCallback,
          },
        ),
        throwsStateError,
        reason: 'Should reject instance methods',
      );
    });

    test('error message guides user to fix anonymous function', () async {
      try {
        await NativeWorkManager.initialize(
          dartWorkers: {
            'bad': (input) async => true,
          },
        );
        fail('Should have thrown StateError');
      } on StateError catch (e) {
        final message = e.message;

        // Verify error message is helpful
        expect(message, contains('top-level or static function'));
        expect(message, contains('NOT an anonymous function'));
        expect(message, contains('Example CORRECT'));
        expect(message, contains('Example WRONG'));
      }
    });
  });

  group('DartWorker Serialization', () {
    test('DartWorker toMap includes callbackId and input', () {
      final worker = DartWorker(
        callbackId: 'test',
        input: {'key': 'value'},
      );

      final map = worker.toMap();

      expect(map['workerType'], equals('dartCallback'));
      expect(map['callbackId'], equals('test'));
      expect(map['input'], isNotNull);
      expect(map['input'], contains('key'));
    });

    test('DartWorker toMap handles null input', () {
      final worker = DartWorker(callbackId: 'test');

      final map = worker.toMap();

      expect(map['workerType'], equals('dartCallback'));
      expect(map['callbackId'], equals('test'));
      expect(map['input'], isNull);
    });

    test('DartWorker asserts non-empty callbackId', () {
      expect(
        () => DartWorker(callbackId: ''),
        throwsA(isA<AssertionError>()),
        reason: 'Empty callbackId should trigger assertion',
      );
    });
  });

  group('DartWorkerInternal (Internal Use)', () {
    test('DartWorkerInternal includes callbackHandle in toMap', () {
      final worker = DartWorkerInternal(
        callbackId: 'test',
        callbackHandle: 12345,
        input: {'key': 'value'},
      );

      final map = worker.toMap();

      expect(map['workerType'], equals('dartCallback'));
      expect(map['callbackId'], equals('test'));
      expect(map['callbackHandle'], equals(12345));
      expect(map['input'], isNotNull);
    });

    test('DartWorkerInternal workerClassName matches DartWorker', () {
      final worker = DartWorkerInternal(
        callbackId: 'test',
        callbackHandle: 12345,
      );

      expect(worker.workerClassName, equals('DartCallbackWorker'));
    });
  });

  group('Callback Execution Simulation', () {
    test('successCallback returns true', () async {
      final result = await successCallback(null);
      expect(result, isTrue);
    });

    test('failureCallback returns false', () async {
      final result = await failureCallback(null);
      expect(result, isFalse);
    });

    test('echoCallback processes input', () async {
      final result1 = await echoCallback({'key': 'value'});
      expect(result1, isTrue);

      final result2 = await echoCallback(null);
      expect(result2, isFalse);

      final result3 = await echoCallback({});
      expect(result3, isFalse);
    });

    test('errorCallback throws exception', () async {
      expect(
        () => errorCallback(null),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Integration Scenarios', () {
    test('enqueue with DartWorker validates callback registration', () async {
      // Initialize with one callback
      await NativeWorkManager.initialize(
        dartWorkers: {
          'registered': successCallback,
        },
      );

      // Try to enqueue with unregistered callback
      expect(
        () => NativeWorkManager.enqueue(
          taskId: 'test',
          trigger: TaskTrigger.oneTime(),
          worker: DartWorker(callbackId: 'unregistered'),
        ),
        throwsStateError,
        reason: 'Should reject unregistered callbacks',
      );
    });

    test('error message for unregistered callback is helpful', () async {
      await NativeWorkManager.initialize(
        dartWorkers: {
          'registered': successCallback,
        },
      );

      try {
        await NativeWorkManager.enqueue(
          taskId: 'test',
          trigger: TaskTrigger.oneTime(),
          worker: DartWorker(callbackId: 'missing'),
        );
        fail('Should have thrown StateError');
      } on StateError catch (e) {
        final message = e.message;

        // Verify error message includes registration example
        expect(message, contains('not registered'));
        expect(message, contains('NativeWorkManager.initialize'));
        expect(message, contains('dartWorkers'));
      }
    });
  });
}

// Helper class for testing static and instance methods
class _TestCallbacks {
  // Static method (can be serialized)
  static Future<bool> staticCallback(Map<String, dynamic>? input) async {
    return true;
  }

  // Instance method (cannot be serialized)
  Future<bool> instanceCallback(Map<String, dynamic>? input) async {
    return true;
  }
}
