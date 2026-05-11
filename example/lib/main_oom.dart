import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NativeWorkManager.initialize();

  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('OOM Demo Running...'))),
    ),
  );

  print('[OOM_DEMO] Scheduling FGS Task...');
  await NativeWorkManager.enqueue(
    taskId: 'oom_test_task',
    trigger: TaskTrigger.oneTime(
      const Duration(seconds: 5),
    ), // Delay 5s to allow OOM to happen first
    worker: HttpRequestWorker(
      url: 'https://jsonplaceholder.typicode.com/posts/1',
    ),
    constraints: const Constraints(
      isHeavyTask: true,
      foregroundNotificationConfig: ForegroundNotificationConfig(
        title: 'OOM Survivor',
        body: 'I survived the Memory Kill!',
      ),
    ),
  );

  print(
    '[OOM_DEMO] FGS Task Scheduled. Waiting 2 seconds before memory bomb...',
  );
  await Future.delayed(const Duration(seconds: 2));

  print('[OOM_DEMO] Triggering OOM kill...');
  List<List<int>> memoryHog = [];
  try {
    while (true) {
      memoryHog.add(List.filled(10000000, 0)); // Allocate ~80MB chunks rapidly
    }
  } catch (e) {
    print('[OOM_DEMO] Out of memory caught in Dart: $e');
  }
}
