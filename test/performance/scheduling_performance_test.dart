import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('dev.brewkits.native_workmanager');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'initialize') return true;
      if (methodCall.method == 'enqueue') return 'ACCEPTED';
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Scheduling overhead performance test', () async {
    await NativeWorkManager.initialize();

    final stopwatch = Stopwatch()..start();
    const count = 1000;

    for (var i = 0; i < count; i++) {
      await NativeWorkManager.enqueue(
        taskId: 'perf-task-$i',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpSync(url: 'https://example.com'),
      );
    }

    stopwatch.stop();
    final avgMs = stopwatch.elapsedMilliseconds / count;
    print('Average scheduling time: ${avgMs.toStringAsFixed(3)}ms per task');
    
    // Threshold check (heuristic)
    expect(avgMs, lessThan(5.0), reason: 'Scheduling overhead should be low');
  });
}
