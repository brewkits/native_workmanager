import 'package:flutter/widgets.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize();

  print('--- VERIFICATION START ---');
  final result = await NativeWorkManager.enqueue(
    taskId: 'verification-delayed-sync',
    trigger: TaskTrigger.periodic(
      const Duration(hours: 1),
      initialDelay: const Duration(minutes: 30),
    ),
    worker: NativeWorker.httpSync(url: 'https://httpbin.org/get'),
  );
  print('Schedule Result: ${result.scheduleResult}');
  print('--- VERIFICATION END ---');
}
