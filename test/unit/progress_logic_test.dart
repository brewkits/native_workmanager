import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:native_workmanager/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.brewkits/native_workmanager');

  group('TaskHandler & Progress Logic', () {
    late FakeWorkManager wm;

    setUpAll(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') return null;
        if (methodCall.method == 'enqueue') return 'accepted';
        return null;
      });
      await NativeWorkManager.initialize();
    });

    setUp(() {
      wm = FakeWorkManager();
    });

    tearDown(() {
      wm.dispose();
    });

    test('progress stream filters by taskId', () async {
      await wm.enqueue(
        taskId: 'my-task-1',
        trigger: const TaskTrigger.oneTime(),
        worker: NativeWorker.httpDownload(
          url: 'https://example.com',
          savePath: '/tmp/file.bin',
        ),
      );

      final received = <int>[];
      wm.progress.where((p) => p.taskId == 'my-task-1').listen(
            (p) => received.add(p.progress),
          );

      wm.emitProgress(const TaskProgress(taskId: 'my-task-1', progress: 10));
      wm.emitProgress(const TaskProgress(taskId: 'other-task', progress: 50));
      wm.emitProgress(const TaskProgress(taskId: 'my-task-1', progress: 20));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(received, [10, 20]);
    });

    test('events stream resolves on terminal event', () async {
      final resultFuture = wm.events
          .where((e) => e.taskId == 'terminating-task' && !e.isStarted)
          .first;

      Timer(const Duration(milliseconds: 20), () {
        wm.emitEvent(TaskEvent(
          taskId: 'terminating-task',
          success: true,
          timestamp: DateTime.now(),
        ));
      });

      final result = await resultFuture;
      expect(result.success, isTrue);
      expect(result.taskId, equals('terminating-task'));
    });

    test('started events are distinguished from completion events', () async {
      final events = <TaskEvent>[];
      wm.events.where((e) => e.taskId == 'my-task').listen(events.add);

      wm.emitEvent(TaskEvent(
        taskId: 'my-task',
        success: false,
        isStarted: true,
        workerType: 'HttpDownloadWorker',
        timestamp: DateTime.now(),
      ));
      wm.emitEvent(TaskEvent(
        taskId: 'my-task',
        success: true,
        timestamp: DateTime.now(),
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(events, hasLength(2));
      expect(events[0].isStarted, isTrue);
      expect(events[0].workerType, equals('HttpDownloadWorker'));
      expect(events[1].isStarted, isFalse);
      expect(events[1].success, isTrue);
    });

    test('TaskProgressExtensions formats bytes per second', () {
      const slow = TaskProgress(taskId: 't', progress: 0, networkSpeed: 512);
      const medium = TaskProgress(taskId: 't', progress: 0, networkSpeed: 1536);
      const fast = TaskProgress(
          taskId: 't', progress: 0, networkSpeed: 1024 * 1024 * 1.5);

      expect(slow.networkSpeedHuman, '512.0 B/s');
      expect(medium.networkSpeedHuman, '1.5 KB/s');
      expect(fast.networkSpeedHuman, '1.5 MB/s');
    });

    test('TaskProgressExtensions formats time remaining', () {
      const seconds = TaskProgress(
          taskId: 't',
          progress: 0,
          timeRemaining: Duration(seconds: 45));
      const minutes = TaskProgress(
          taskId: 't',
          progress: 0,
          timeRemaining: Duration(seconds: 65));
      const hours = TaskProgress(
          taskId: 't',
          progress: 0,
          timeRemaining: Duration(hours: 2, minutes: 10));
      const unknown = TaskProgress(taskId: 't', progress: 0);

      expect(seconds.timeRemainingHuman, '45s');
      expect(minutes.timeRemainingHuman, '1m 5s');
      expect(hours.timeRemainingHuman, '2h 10m');
      expect(unknown.timeRemainingHuman, 'unknown');
    });

    test('networkSpeedHuman returns n/a when null', () {
      const p = TaskProgress(taskId: 't', progress: 50);
      expect(p.networkSpeedHuman, 'n/a');
    });
  });
}
