import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('dev.brewkits.native_workmanager');

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
    var status = await NativeWorkManager.getTaskStatus(taskId);
    expect(status, 'pending');

    // 3. Cancel
    await NativeWorkManager.cancel(taskId);

    // 4. Check status again
    status = await NativeWorkManager.getTaskStatus(taskId);
    expect(status, 'cancelled');
  });
}
