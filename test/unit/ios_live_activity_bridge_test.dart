import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:native_workmanager/src/method_channel.dart';
import 'package:native_workmanager/src/platform_interface.dart';

/// Fake platform that lets a test push progress events onto the same stream
/// [IosLiveActivityBridge.onProgress] reads from.
class _FakeProgressPlatform extends MethodChannelNativeWorkManager {
  final controller = StreamController<TaskProgress>.broadcast();

  @override
  Stream<TaskProgress> get progress => controller.stream;

  @override
  Future<void> initialize({
    int? callbackHandle,
    bool debugMode = false,
    int maxConcurrentTasks = 4,
    int diskSpaceBufferMB = 20,
    int cleanupAfterDays = 30,
    bool enforceHttps = false,
    bool blockPrivateIPs = false,
    bool registerPlugins = false,
  }) async {
    // No-op: avoid MissingPluginException on the host machine.
  }

  @override
  void reportTestProgress(TaskProgress progress) => controller.add(progress);

  Future<void> dispose() => controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IosLiveActivityBridge', () {
    late _FakeProgressPlatform platform;

    setUp(() {
      platform = _FakeProgressPlatform();
      NativeWorkManagerPlatform.instance = platform;
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await platform.dispose();
    });

    test('NativeWorkManager.iosLiveActivity is an IosLiveActivityBridge', () {
      expect(NativeWorkManager.iosLiveActivity, isA<IosLiveActivityBridge>());
    });

    test('isSupported tracks the current platform', () {
      const bridge = IosLiveActivityBridge();

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(bridge.isSupported, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(bridge.isSupported, isFalse);
    });

    // The load-bearing test: this FAILS if the taskId filter in
    // `onProgress` stops discriminating (e.g. `.where((_) => true)`).
    test('onProgress(taskId:) delivers only that task\'s progress', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const bridge = IosLiveActivityBridge();

      final received = <TaskProgress>[];
      final sub = bridge.onProgress(taskId: 'task_A').listen(received.add);
      addTearDown(sub.cancel);

      platform
        ..reportTestProgress(const TaskProgress(taskId: 'task_A', progress: 10))
        ..reportTestProgress(const TaskProgress(taskId: 'task_B', progress: 99))
        ..reportTestProgress(
            const TaskProgress(taskId: 'task_A', progress: 55));

      await pumpEventQueue();

      expect(received.map((p) => p.taskId), everyElement('task_A'),
          reason: 'task_B progress must not leak into a task_A subscription');
      expect(received.map((p) => p.progress), [10, 55]);
    });

    test('onProgress() with no taskId passes every task through', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const bridge = IosLiveActivityBridge();

      final received = <TaskProgress>[];
      final sub = bridge.onProgress().listen(received.add);
      addTearDown(sub.cancel);

      platform
        ..reportTestProgress(const TaskProgress(taskId: 'task_A', progress: 10))
        ..reportTestProgress(
            const TaskProgress(taskId: 'task_B', progress: 20));

      await pumpEventQueue();

      expect(received.map((p) => p.taskId), ['task_A', 'task_B']);
    });

    test('two concurrent taskId subscriptions each get their own task',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const bridge = IosLiveActivityBridge();

      final a = <int>[];
      final b = <int>[];
      final subA =
          bridge.onProgress(taskId: 'task_A').listen((p) => a.add(p.progress));
      final subB =
          bridge.onProgress(taskId: 'task_B').listen((p) => b.add(p.progress));
      addTearDown(subA.cancel);
      addTearDown(subB.cancel);

      platform
        ..reportTestProgress(const TaskProgress(taskId: 'task_A', progress: 1))
        ..reportTestProgress(const TaskProgress(taskId: 'task_B', progress: 2));

      await pumpEventQueue();

      expect(a, [1]);
      expect(b, [2]);
    });

    // Documents the non-iOS contract: an already-closed stream, so listeners
    // get onDone and never an event.
    test('onProgress returns a closed, empty stream on non-iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const bridge = IosLiveActivityBridge();

      var done = false;
      final received = <TaskProgress>[];
      final sub = bridge
          .onProgress(taskId: 'task_A')
          .listen(received.add, onDone: () => done = true);
      addTearDown(sub.cancel);

      platform.reportTestProgress(
          const TaskProgress(taskId: 'task_A', progress: 10));

      await pumpEventQueue();

      expect(received, isEmpty);
      expect(done, isTrue);
    });
  });
}
