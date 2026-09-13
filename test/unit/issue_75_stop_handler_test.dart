import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Issue #75: https://github.com/brewkits/native_workmanager/issues/75
///
/// Follow-up to #67 / discussion #66. `isTaskCancelled()` worked but was
/// poll-only — nothing told a running DartWorker it had been stopped. #75 adds
/// the push hook: `DartWorker(onStoppedId:, cancelGrace:)`, a handler registry
/// on `initialize(onStoppedHandlers:)`, and an inbound `onDartTaskStopped` /
/// `onTaskStopped` channel method.
///
/// Per the CLAUDE.md issue #30 rule, `toMap()` round-trip tests are **not
/// sufficient** for a field crossing Dart → native → Dart. The tests that
/// actually guard the bridge here are the ones in the
/// "inbound onDartTaskStopped" group: they drive the real inbound channel
/// message and assert the registered handler ran with the forwarded values, so
/// they go red if a bridge stops sending `onStoppedId` or `cancelGraceMs`.
/// The native→Dart leg on a real device is covered by `issue_75_*` in
/// example/integration_test/device_integration_test.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('issue_75: DartWorker.toMap (Dart → native)', () {
    test('issue_75: onStoppedId and cancelGraceMs are serialized when set', () {
      final worker = DartWorker(
        callbackId: 'sync',
        onStoppedId: 'syncStopped',
        cancelGrace: const Duration(seconds: 3),
      );
      final map = worker.toMap();
      expect(map['onStoppedId'], 'syncStopped');
      expect(map['cancelGraceMs'], 3000);
    });

    test('issue_75: both keys are omitted when unset — notify-only default', () {
      // Absence is load-bearing: a missing cancelGraceMs means "never tear the
      // engine down", which is the pre-#75 behaviour. If this key ever starts
      // being emitted as 0 by default, every existing task silently becomes a
      // hard kill on cancel.
      final map = DartWorker(callbackId: 'sync').toMap();
      expect(map.containsKey('onStoppedId'), isFalse);
      expect(map.containsKey('cancelGraceMs'), isFalse);
    });

    test('issue_75: cancelGrace of zero is serialized, not dropped', () {
      // Duration.zero means "tear down as soon as the handler returns" — a
      // different instruction from absent. A falsy-value check anywhere in the
      // chain would collapse the two.
      final map =
          DartWorker(callbackId: 'sync', cancelGrace: Duration.zero).toMap();
      expect(map.containsKey('cancelGraceMs'), isTrue);
      expect(map['cancelGraceMs'], 0);
    });

    test('issue_75: DartWorkerInternal forwards the handle for the headless isolate',
        () {
      // The background isolate never runs initialize(), so it cannot resolve an
      // id — it needs the raw handle.
      const worker = DartWorkerInternal(
        callbackId: 'sync',
        callbackHandle: 111,
        onStoppedId: 'syncStopped',
        onStoppedHandle: 222,
        cancelGraceMs: 1500,
      );
      final map = worker.toMap();
      expect(map['onStoppedHandle'], 222);
      expect(map['onStoppedId'], 'syncStopped');
      expect(map['cancelGraceMs'], 1500);
    });

    test('issue_75: rejects an empty onStoppedId', () {
      expect(
        () => DartWorker(callbackId: 'sync', onStoppedId: ''),
        throwsArgumentError,
      );
    });

    test('issue_75: rejects a negative cancelGrace', () {
      expect(
        () => DartWorker(
            callbackId: 'sync', cancelGrace: const Duration(seconds: -1)),
        throwsArgumentError,
      );
    });
  });

  group('issue_75: resolveStopHandlerBudget (native → Dart)', () {
    test('issue_75: honors cancelGraceMs forwarded by the native bridge', () {
      expect(
        resolveStopHandlerBudget({'cancelGraceMs': 8000}),
        const Duration(milliseconds: 8000),
      );
    });

    test('issue_75: accepts num (double) for codec-decoded payloads', () {
      expect(
        resolveStopHandlerBudget({'cancelGraceMs': 2500.0}),
        const Duration(milliseconds: 2500),
      );
    });

    test('issue_75: falls back to the default budget when absent', () {
      expect(resolveStopHandlerBudget({}), kDefaultStopHandlerBudget);
    });

    test('issue_75: cancelGraceMs 0 still grants the default budget to return in',
        () {
      // 0 governs teardown, not how long the handler may take to return — it
      // still needs a window, or a zero-grace task could never persist anything.
      expect(
        resolveStopHandlerBudget({'cancelGraceMs': 0}),
        kDefaultStopHandlerBudget,
      );
    });

    test('issue_75: a non-finite or wrong-typed value falls back', () {
      expect(resolveStopHandlerBudget({'cancelGraceMs': double.nan}),
          kDefaultStopHandlerBudget);
      expect(resolveStopHandlerBudget({'cancelGraceMs': 'soon'}),
          kDefaultStopHandlerBudget);
      expect(resolveStopHandlerBudget({'cancelGraceMs': null}),
          kDefaultStopHandlerBudget);
    });
  });

  group('issue_75: inbound onDartTaskStopped (the bridge guard)', () {
    const mainChannel = MethodChannel('dev.brewkits/native_workmanager');

    setUp(() {
      stoppedCalls.clear();
      slowHandlerStarted = false;
      slowHandlerFinished = false;
      NativeWorkManager.resetInitializedState();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mainChannel, (MethodCall call) async {
        if (call.method == 'initialize') return null;
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mainChannel, null);
    });

    /// Drive a native→Dart call the way the platform actually does, through the
    /// binary messenger, so the plugin's own `setMethodCallHandler` runs.
    Future<void> sendStop(Map<String, Object?> args) async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        mainChannel.name,
        const StandardMethodCodec()
            .encodeMethodCall(MethodCall('onDartTaskStopped', args)),
        (_) {},
      );
    }

    test('issue_75: runs the registered handler with the forwarded input',
        () async {
      await NativeWorkManager.initialize(
        onStoppedHandlers: {'onSyncStopped': recordStopped},
      );

      await sendStop({
        'onStoppedId': 'onSyncStopped',
        'input': jsonEncode({'__taskId': 'nightly', '__executionId': 'e-1'}),
        'cancelGraceMs': 2000,
      });

      expect(stoppedCalls, hasLength(1));
      // These two assertions are the actual bridge guard: if a native side
      // stops forwarding __taskId, a shared handler can no longer tell which
      // task stopped, and this goes red.
      expect(stoppedCalls.single['__taskId'], 'nightly');
      expect(stoppedCalls.single['__executionId'], 'e-1');
    });

    test('issue_75: an unregistered onStoppedId is survivable, not fatal',
        () async {
      await NativeWorkManager.initialize(
        onStoppedHandlers: {'onSyncStopped': recordStopped},
      );

      // Must not throw back across the channel — the task is already being torn
      // down and an exception here would replace the native stop log with a
      // channel error.
      await expectLater(
        sendStop({'onStoppedId': 'neverRegistered', 'input': null}),
        completes,
      );
      expect(stoppedCalls, isEmpty);
    });

    test('issue_75: a missing onStoppedId is a no-op', () async {
      await NativeWorkManager.initialize(
        onStoppedHandlers: {'onSyncStopped': recordStopped},
      );

      await expectLater(sendStop({'input': null}), completes);
      expect(stoppedCalls, isEmpty);
    });

    test('issue_75: a handler that throws does not propagate to the channel',
        () async {
      await NativeWorkManager.initialize(
        onStoppedHandlers: {'boom': throwingStopHandler},
      );

      await expectLater(
        sendStop({'onStoppedId': 'boom', 'input': null}),
        completes,
      );
    });

    test('issue_75: a wedged handler is abandoned at the forwarded budget',
        () async {
      await NativeWorkManager.initialize(
        onStoppedHandlers: {'slow': slowStopHandler},
      );

      final sw = Stopwatch()..start();
      await sendStop({
        'onStoppedId': 'slow',
        'input': null,
        // Deliberately tiny: proves the bound comes from the forwarded value
        // and not from kDefaultStopHandlerBudget. With the forwarding dropped
        // this would wait 5 s and blow the assertion below.
        'cancelGraceMs': 120,
      });
      sw.stop();

      expect(slowHandlerStarted, isTrue);
      expect(slowHandlerFinished, isFalse,
          reason: 'the handler outlives its budget and must be abandoned');
      expect(sw.elapsed, lessThan(kDefaultStopHandlerBudget),
          reason: 'bound must come from cancelGraceMs, not the default');
    });
  });
}

// ── Top-level handlers ───────────────────────────────────────────────────────
// Top-level (not closures) on purpose: PluginUtilities.getCallbackHandle
// returns null for a closure, which is exactly what initialize() rejects.

final List<Map<String, dynamic>> stoppedCalls = <Map<String, dynamic>>[];
bool slowHandlerStarted = false;
bool slowHandlerFinished = false;

Future<void> recordStopped(Map<String, dynamic>? input) async {
  stoppedCalls.add(input ?? <String, dynamic>{});
}

Future<void> throwingStopHandler(Map<String, dynamic>? input) async {
  throw StateError('handler blew up');
}

Future<void> slowStopHandler(Map<String, dynamic>? input) async {
  slowHandlerStarted = true;
  await Future<void>.delayed(const Duration(seconds: 2));
  slowHandlerFinished = true;
}
