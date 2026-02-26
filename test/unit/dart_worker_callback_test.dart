import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Unit tests for Dart worker callback mechanisms.
///
/// Tests that can run without a real Flutter engine:
/// - DartWorker / DartWorkerInternal serialization
/// - Callback execution (pure Dart functions)
/// - NativeWorkManager dart worker registry (register/unregister)
///
/// Tests requiring a real Flutter engine (PluginUtilities.getCallbackHandle,
/// NativeWorkManager.initialize() with actual callbacks) live in
/// example/integration_test/dart_worker_callback_integration_test.dart.

// Top-level callback stubs — used for registry tests
Future<bool> _successCallback(Map<String, dynamic>? input) async => true;
Future<bool> _failureCallback(Map<String, dynamic>? input) async => false;
Future<bool> _echoCallback(Map<String, dynamic>? input) async =>
    input != null && input.isNotEmpty;

void main() {
  group('DartWorker Serialization', () {
    test('toMap includes callbackId and serialized input', () {
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

    test('toMap handles null input', () {
      final worker = DartWorker(callbackId: 'test');

      final map = worker.toMap();

      expect(map['workerType'], equals('dartCallback'));
      expect(map['callbackId'], equals('test'));
      expect(map['input'], isNull);
    });

    test('throws ArgumentError on empty callbackId', () {
      expect(
        () => DartWorker(callbackId: ''),
        throwsA(isA<ArgumentError>()),
        reason: 'Empty callbackId should throw ArgumentError (works in release builds)',
      );
    });

    test('handles complex input map', () {
      final worker = DartWorker(
        callbackId: 'complex',
        input: {
          'string': 'hello',
          'number': 123,
          'list': [1, 2, 3],
          'nested': {'inner': 'value'},
        },
      );

      final map = worker.toMap();
      expect(map['input'], isA<String>());
      expect(map['input'], contains('string'));
      expect(map['input'], contains('nested'));
    });

    test('handles empty input map', () {
      final worker = DartWorker(callbackId: 'empty', input: {});

      final map = worker.toMap();
      expect(map['input'], isA<String>());
      expect(map['input'], '{}');
    });
  });

  group('DartWorkerInternal (Internal Use)', () {
    test('includes callbackHandle in toMap', () {
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

    test('workerClassName matches DartWorker', () {
      final worker = DartWorkerInternal(
        callbackId: 'test',
        callbackHandle: 12345,
      );

      expect(worker.workerClassName, equals('DartCallbackWorker'));
    });

    test('handles null input', () {
      final worker = DartWorkerInternal(
        callbackId: 'test',
        callbackHandle: 99,
      );

      final map = worker.toMap();
      expect(map['input'], isNull);
    });
  });

  group('Callback Execution (pure Dart)', () {
    test('success callback returns true', () async {
      final result = await _successCallback(null);
      expect(result, isTrue);
    });

    test('failure callback returns false', () async {
      final result = await _failureCallback(null);
      expect(result, isFalse);
    });

    test('echo callback processes non-empty input', () async {
      expect(await _echoCallback({'key': 'value'}), isTrue);
      expect(await _echoCallback(null), isFalse);
      expect(await _echoCallback({}), isFalse);
    });

    test('callbacks accept null input safely', () async {
      expect(() => _successCallback(null), returnsNormally);
      expect(() => _failureCallback(null), returnsNormally);
    });

    test('callbacks accept empty input safely', () async {
      expect(() => _successCallback({}), returnsNormally);
      expect(() => _failureCallback({}), returnsNormally);
    });
  });

  group('Dart Worker Registry', () {
    tearDown(() {
      NativeWorkManager.unregisterDartWorker('worker-A');
      NativeWorkManager.unregisterDartWorker('worker-B');
    });

    test('registerDartWorker marks worker as registered', () {
      NativeWorkManager.registerDartWorker('worker-A', _successCallback);
      expect(NativeWorkManager.isDartWorkerRegistered('worker-A'), isTrue);
      NativeWorkManager.unregisterDartWorker('worker-A');
    });

    test('unregisterDartWorker removes worker', () {
      NativeWorkManager.registerDartWorker('worker-A', _successCallback);
      NativeWorkManager.unregisterDartWorker('worker-A');
      expect(NativeWorkManager.isDartWorkerRegistered('worker-A'), isFalse);
    });

    test('isDartWorkerRegistered returns false for unknown id', () {
      expect(
          NativeWorkManager.isDartWorkerRegistered('nonexistent'), isFalse);
    });

    test('multiple workers are independent', () {
      NativeWorkManager.registerDartWorker('worker-A', _successCallback);
      NativeWorkManager.registerDartWorker('worker-B', _failureCallback);

      expect(NativeWorkManager.isDartWorkerRegistered('worker-A'), isTrue);
      expect(NativeWorkManager.isDartWorkerRegistered('worker-B'), isTrue);

      NativeWorkManager.unregisterDartWorker('worker-A');
      expect(NativeWorkManager.isDartWorkerRegistered('worker-A'), isFalse);
      expect(NativeWorkManager.isDartWorkerRegistered('worker-B'), isTrue);
    });

    test('unregistering non-existent worker does not throw', () {
      expect(
        () => NativeWorkManager.unregisterDartWorker('does-not-exist'),
        returnsNormally,
      );
    });
  });
}
