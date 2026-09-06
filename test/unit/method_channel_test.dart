import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('dev.brewkits/native_workmanager');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      final now = DateTime.now().millisecondsSinceEpoch;
      switch (methodCall.method) {
        case 'initialize':
          return null;
        case 'enqueue':
          return 'accepted';
        case 'cancel':
          return null;
        case 'getTaskStatus':
          return 'completed';
        case 'getTaskRecord':
          return {
            'taskId': 't1',
            'status': 'completed',
            'workerClassName': 'HttpWorker',
            'createdAt': now,
            'updatedAt': now,
          };
        // NOTE: there is deliberately no 'getTasksByStatus' case. No platform
        // implements that method — mocking it here is what let the real bug
        // (MissingPluginException on every call, on both platforms) sit unseen
        // behind a green unit test. getTasksByStatus now filters allTasks().
        case 'allTasks':
          return [
            {
              'taskId': 't1',
              'status': 'completed',
              'workerClassName': 'HttpWorker',
              'createdAt': now,
              'updatedAt': now,
            },
            {
              'taskId': 't2',
              'status': 'running',
              'workerClassName': 'HttpWorker',
              'createdAt': now,
              'updatedAt': now,
            },
          ];
        case 'enqueueChain':
          return 'accepted';
        default:
          return null;
      }
    });
    log.clear();
  });

  group('MethodChannelNativeWorkManager', () {
    test('initialize', () async {
      await NativeWorkManager.initialize();
      expect(log.any((call) => call.method == 'initialize'), isTrue);
    });

    test('enqueue', () async {
      final handler = await NativeWorkManager.enqueue(
        taskId: 't1',
        worker: NativeWorker.httpSync(url: 'https://a.com'),
      );
      expect(handler.scheduleResult, ScheduleResult.accepted);
      expect(
          log.any((call) =>
              call.method == 'enqueue' && call.arguments['taskId'] == 't1'),
          isTrue);
    });

    test('cancel', () async {
      await NativeWorkManager.cancel(taskId: 't1');
      expect(
          log.any((call) =>
              call.method == 'cancel' && call.arguments['taskId'] == 't1'),
          isTrue);
    });

    test('getTaskStatus', () async {
      final status = await NativeWorkManager.getTaskStatus(taskId: 't1');
      expect(status, TaskStatus.completed);
      expect(
          log.any((call) =>
              call.method == 'getTaskStatus' &&
              call.arguments['taskId'] == 't1'),
          isTrue);
    });

    test('getTaskRecord', () async {
      final record = await NativeWorkManager.getTaskRecord(taskId: 't1');
      expect(record, isNotNull);
      expect(record!.taskId, 't1');
    });

    test('getTasksByStatus filters allTasks and calls no missing method',
        () async {
      final tasks =
          await NativeWorkManager.getTasksByStatus(TaskStatus.completed);

      expect(tasks.length, 1);
      expect(tasks.single.taskId, 't1');

      // The regression this guards: invoking a channel method no platform
      // registers throws MissingPluginException at runtime, which a mock that
      // answers it would hide.
      expect(log.any((c) => c.method == 'allTasks'), isTrue);
      expect(log.any((c) => c.method == 'getTasksByStatus'), isFalse);
    });

    test('enqueueChain', () async {
      await NativeWorkManager.beginWith(TaskRequest(
        id: 'c1',
        worker: NativeWorker.httpSync(url: 'https://a.com'),
      )).enqueue();

      expect(log.any((call) => call.method == 'enqueueChain'), isTrue);
    });
  });
}
