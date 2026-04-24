import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('dev.brewkits/native_workmanager');

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

  group('NativeWorkManager.enqueue validation', () {
    test('should throw ArgumentError for periodic interval < 15m', () async {
      await NativeWorkManager.initialize();
      
      expect(
        () => NativeWorkManager.enqueue(
          taskId: 'test',
          trigger: TaskTrigger.periodic(const Duration(minutes: 10)),
          worker: NativeWorker.httpRequest(url: 'https://example.com'),
        ),
        throwsArgumentError,
      );
    });

    test('should throw ArgumentError for negative initialDelay', () async {
      await NativeWorkManager.initialize();
      
      expect(
        () => NativeWorkManager.enqueue(
          taskId: 'test',
          trigger: TaskTrigger.periodic(
            const Duration(hours: 1),
            initialDelay: const Duration(minutes: -1),
          ),
          worker: NativeWorker.httpRequest(url: 'https://example.com'),
        ),
        throwsArgumentError,
      );
    });

    test('should allow zero initialDelay', () async {
      await NativeWorkManager.initialize();
      
      final result = await NativeWorkManager.enqueue(
        taskId: 'test',
        trigger: TaskTrigger.periodic(
          const Duration(hours: 1),
          initialDelay: Duration.zero,
        ),
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
      );
      
      expect(result.scheduleResult, ScheduleResult.accepted);
    });

    test('should allow positive initialDelay', () async {
      await NativeWorkManager.initialize();
      
      final result = await NativeWorkManager.enqueue(
        taskId: 'test',
        trigger: TaskTrigger.periodic(
          const Duration(hours: 1),
          initialDelay: const Duration(minutes: 30),
        ),
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
      );
      
      expect(result.scheduleResult, ScheduleResult.accepted);
    });
  });
}
