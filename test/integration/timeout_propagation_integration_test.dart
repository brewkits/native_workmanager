import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Issue #30 integration test — covers the Dart→native→Dart loop without
/// needing a device.
///
/// We intercept the main plugin method channel to capture the `workerConfig`
/// payload that the Dart side sends to native (proving `timeoutMs` is in the
/// wire payload), then directly exercise the `_executeDartCallback` handler
/// on the same channel (proving the foreground/test path honors the value).
///
/// Together this closes the loop that Issue #30 broke: serialization tests
/// alone never proved the value crossed the bridge.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.brewkits/native_workmanager');

  group('issue_30 integration: timeoutMs Dart→native payload', () {
    late Map<dynamic, dynamic>? lastEnqueueArgs;

    setUpAll(() {
      NativeWorkManager.registerDartWorker('cb', _fastRunner);
    });

    tearDownAll(() {
      NativeWorkManager.unregisterDartWorker('cb');
    });

    setUp(() {
      lastEnqueueArgs = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'initialize':
            return null;
          case 'enqueue':
            lastEnqueueArgs = call.arguments as Map<dynamic, dynamic>;
            return 'accepted';
          case 'cancelAll':
            return null;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('user-set timeoutMs reaches native enqueue payload', () async {
      await NativeWorkManager.initialize();

      await NativeWorkManager.enqueue(
        taskId: 'issue30-payload',
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'cb', timeoutMs: 75000),
      );

      expect(lastEnqueueArgs, isNotNull);
      final workerConfig =
          lastEnqueueArgs!['workerConfig'] as Map<dynamic, dynamic>;
      expect(
        workerConfig['timeoutMs'],
        75000,
        reason: 'DartWorker.timeoutMs must appear in the enqueue payload so '
            'the native bridge can forward it to the Dart dispatcher.',
      );
    });

    test('omitted timeoutMs is absent from payload (native picks default)',
        () async {
      await NativeWorkManager.initialize();

      await NativeWorkManager.enqueue(
        taskId: 'issue30-default',
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'cb'),
      );

      final workerConfig =
          lastEnqueueArgs!['workerConfig'] as Map<dynamic, dynamic>;
      expect(
        workerConfig.containsKey('timeoutMs'),
        isFalse,
        reason: 'When the user omits timeoutMs, the key must be absent so the '
            'native side picks its 5-minute default — not coerced to a fixed '
            'value here.',
      );
    });
  });

  group('issue_30 integration: timeoutMs native→Dart enforcement', () {
    setUpAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'initialize') return null;
        return null;
      });
      // Register workers via the runtime API rather than initialize() —
      // NativeWorkManager.initialize() is a one-shot static, so subsequent
      // calls between tests are no-ops.
      NativeWorkManager.registerDartWorker('longRunner', _longRunner);
      NativeWorkManager.registerDartWorker('fastRunner', _fastRunner);
    });

    tearDownAll(() {
      NativeWorkManager.unregisterDartWorker('longRunner');
      NativeWorkManager.unregisterDartWorker('fastRunner');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('foreground path kills callback when it exceeds timeoutMs', () async {
      // Simulate the iOS foreground path: native side invokes
      // `executeDartCallback` on the main plugin channel with the user's
      // timeoutMs forwarded in args.
      final result = await _invokeExecuteDartCallback(
        callbackId: 'longRunner',
        input: jsonInput({'delayMs': 5000}),
        timeoutMs: 200,
      );

      expect(
        result,
        isFalse,
        reason: 'Callback that sleeps 5 s with timeoutMs=200 ms must be '
            'cancelled and return false on the foreground path.',
      );
    });

    test('foreground path lets callback finish under timeoutMs', () async {
      final result = await _invokeExecuteDartCallback(
        callbackId: 'fastRunner',
        input: null,
        timeoutMs: 5000,
      );

      expect(
        result,
        isTrue,
        reason: 'Quick callback must complete and return true when well '
            'within its timeoutMs budget.',
      );
    });

    test('foreground path falls back to 25 s when timeoutMs omitted', () async {
      // The fast callback completes well under 25 s, so this verifies the
      // fallback default keeps callbacks running rather than killing them at 0.
      final result = await _invokeExecuteDartCallback(
        callbackId: 'fastRunner',
        input: null,
        timeoutMs: null,
      );

      expect(result, isTrue);
    });
  });
}

@pragma('vm:entry-point')
Future<bool> _longRunner(Map<String, dynamic>? input) async {
  final delayMs = (input?['delayMs'] as int?) ?? 1000;
  await Future<void>.delayed(Duration(milliseconds: delayMs));
  return true;
}

@pragma('vm:entry-point')
Future<bool> _fastRunner(Map<String, dynamic>? input) async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return true;
}

String? jsonInput(Object value) {
  // Inputs are JSON-encoded by the bridge; mirror that here so the dispatcher
  // unpacks them the way it does in production.
  return jsonEncode(value);
}

/// Drives the main plugin channel's `executeDartCallback` handler the same way
/// the iOS foreground path does: a `MethodCall` to the channel name registered
/// by `MethodChannelNativeWorkManager`. Returns whatever the Dart-side
/// handler returns to native.
Future<bool> _invokeExecuteDartCallback({
  required String callbackId,
  required String? input,
  required int? timeoutMs,
}) async {
  const channelName = 'dev.brewkits/native_workmanager';
  final codec = const StandardMethodCodec();
  final call = codec.encodeMethodCall(MethodCall('executeDartCallback', {
    'callbackId': callbackId,
    'input': input,
    if (timeoutMs != null) 'timeoutMs': timeoutMs,
  }));

  final reply = await TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .handlePlatformMessage(channelName, call, (_) {});

  if (reply == null) {
    throw StateError('No reply from executeDartCallback handler.');
  }
  final decoded = codec.decodeEnvelope(reply);
  return decoded as bool;
}
