import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('dev.brewkits/native_workmanager');

  final Map<String, String?> taskStore = {};

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'initialize':
          return true;
        case 'enqueue':
          final args = methodCall.arguments as Map;
          final id = args['taskId'] as String;
          taskStore[id] = 'pending';
          return 'ACCEPTED';
        case 'cancel':
          final args = methodCall.arguments as Map;
          final id = args['taskId'] as String;
          taskStore[id] = 'cancelled';
          return true;
        case 'getTaskStatus':
          final args = methodCall.arguments as Map;
          final id = args['taskId'] as String;
          return taskStore[id];
        default:
          return null;
      }
    });
  });

  tearDown(() {
    taskStore.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Full task lifecycle integration test', () async {
    await NativeWorkManager.initialize();

    const taskId = 'lifecycle-test-1';
    
    // 1. Enqueue
    final enqueueResult = await NativeWorkManager.enqueue(
      taskId: taskId,
      trigger: TaskTrigger.oneTime(),
      worker: NativeWorker.httpSync(url: 'https://example.com'),
    );
    expect(enqueueResult.scheduleResult, ScheduleResult.accepted);

    // 2. Check status
    var status = await NativeWorkManager.getTaskStatus(taskId: taskId);
    expect(status, isA<TaskStatus>());

    // 3. Cancel
    await NativeWorkManager.cancel(taskId: taskId);

    // 4. Check status again
    status = await NativeWorkManager.getTaskStatus(taskId: taskId);
    // Note: status might be cancelled or null depending on how mock handles it
    // In our mock it sets to 'cancelled' so we check that
    expect(status.toString(), contains('cancelled'));
  });

  test('Policy interaction with initialDelay', () async {
    await NativeWorkManager.initialize();
    const taskId = 'policy-test';

    // 1. Enqueue with 30m delay
    await NativeWorkManager.enqueue(
      taskId: taskId,
      trigger: TaskTrigger.periodic(
        const Duration(hours: 1),
        initialDelay: const Duration(minutes: 30),
      ),
      worker: NativeWorker.httpSync(url: 'https://example.com'),
    );

    // 2. Enqueue again with 10m delay and REPLACE policy
    final result = await NativeWorkManager.enqueue(
      taskId: taskId,
      trigger: TaskTrigger.periodic(
        const Duration(hours: 1),
        initialDelay: const Duration(minutes: 10),
      ),
      worker: NativeWorker.httpSync(url: 'https://example.com'),
      existingPolicy: ExistingTaskPolicy.replace,
    );

    expect(result.scheduleResult, ScheduleResult.accepted);
    // In a real integration test, we'd verify the native side received the new delay.
    // Our mock currently just returns ACCEPTED, but it confirms the flow is valid.
  });
}
