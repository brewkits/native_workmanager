import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Issue #66: https://github.com/brewkits/native_workmanager/discussions/66
///
/// Cancelling a task does not interrupt a running `DartWorker` callback —
/// Dart has no API to preemptively abort a `Future` that is already
/// executing. `NativeWorkManager.isTaskCancelled(taskId)` gives a callback a
/// way to poll cooperatively and bail out.
///
/// This is a Dart-side consumer test only (per the CLAUDE.md issue #30 rule,
/// serialization/round-trip tests alone are not sufficient for a field that
/// crosses Dart → native → Dart — those are covered on the native side by
/// unit tests + `issue_66_*` entries in device_integration_test.dart).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.brewkits/dart_worker_channel');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      if (call.method == 'isTaskCancelled') {
        final taskId = (call.arguments as Map)['taskId'] as String;
        return taskId == 'cancelled-task';
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('isTaskCancelled', () {
    test('returns false without a platform call when taskId is empty', () async {
      final result = await NativeWorkManager.isTaskCancelled('');
      expect(result, isFalse);
      expect(calls, isEmpty);
    });

    test('forwards taskId and returns the native reply (false case)', () async {
      final result = await NativeWorkManager.isTaskCancelled('running-task');
      expect(result, isFalse);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'isTaskCancelled');
      expect(calls.single.arguments, {'taskId': 'running-task'});
    });

    test('forwards taskId and returns the native reply (true case)', () async {
      final result = await NativeWorkManager.isTaskCancelled('cancelled-task');
      expect(result, isTrue);
      expect(calls, hasLength(1));
      expect(calls.single.arguments, {'taskId': 'cancelled-task'});
    });

    test('returns false, not an exception, if the platform channel has no handler', () async {
      // Simulates a platform that has not registered a handler for this
      // method on this channel yet — MissingPluginException must not crash
      // a DartWorker callback that is only trying to check cancellation.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      await expectLater(
        NativeWorkManager.isTaskCancelled('any-task'),
        completion(isFalse),
      );
    });
  });
}
