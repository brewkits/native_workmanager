import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('dev.brewkits/native_workmanager');

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

    test('one-time task is accepted', () async {
      await NativeWorkManager.initialize();
      final result = await NativeWorkManager.enqueue(
        taskId: 'one-time',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
      );
      expect(result.scheduleResult, ScheduleResult.accepted);
    });

    test('one-time task with delay is accepted', () async {
      await NativeWorkManager.initialize();
      final result = await NativeWorkManager.enqueue(
        taskId: 'delayed',
        trigger: const TaskTrigger.oneTime(Duration(seconds: 30)),
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
      );
      expect(result.scheduleResult, ScheduleResult.accepted);
    });

    test('periodic 15-minute interval is accepted (minimum valid)', () async {
      await NativeWorkManager.initialize();
      final result = await NativeWorkManager.enqueue(
        taskId: 'min-periodic',
        trigger: TaskTrigger.periodic(const Duration(minutes: 15)),
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
      );
      expect(result.scheduleResult, ScheduleResult.accepted);
    });

    test('periodic 1-hour interval is accepted', () async {
      await NativeWorkManager.initialize();
      final result = await NativeWorkManager.enqueue(
        taskId: 'hourly',
        trigger: TaskTrigger.periodic(const Duration(hours: 1)),
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
      );
      expect(result.scheduleResult, ScheduleResult.accepted);
    });

    test('14-minute interval throws ArgumentError', () async {
      await NativeWorkManager.initialize();
      expect(
        () => NativeWorkManager.enqueue(
          taskId: 'too-short',
          trigger: TaskTrigger.periodic(const Duration(minutes: 14)),
          worker: NativeWorker.httpRequest(url: 'https://example.com'),
        ),
        throwsArgumentError,
      );
    });

    test('1-minute interval throws ArgumentError', () async {
      await NativeWorkManager.initialize();
      expect(
        () => NativeWorkManager.enqueue(
          taskId: 'too-short-2',
          trigger: TaskTrigger.periodic(const Duration(minutes: 1)),
          worker: NativeWorker.httpRequest(url: 'https://example.com'),
        ),
        throwsArgumentError,
      );
    });

    test('enqueue with tag is accepted', () async {
      await NativeWorkManager.initialize();
      final result = await NativeWorkManager.enqueue(
        taskId: 'tagged-task',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
        tag: 'my-group',
      );
      expect(result.scheduleResult, ScheduleResult.accepted);
    });

    test('enqueue with existingPolicy=keep is accepted', () async {
      await NativeWorkManager.initialize();
      final result = await NativeWorkManager.enqueue(
        taskId: 'keep-policy',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
        existingPolicy: ExistingTaskPolicy.keep,
      );
      expect(result.scheduleResult, ScheduleResult.accepted);
    });

    test('enqueue with existingPolicy=replace is accepted', () async {
      await NativeWorkManager.initialize();
      final result = await NativeWorkManager.enqueue(
        taskId: 'replace-policy',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
        existingPolicy: ExistingTaskPolicy.replace,
      );
      expect(result.scheduleResult, ScheduleResult.accepted);
    });

    test('enqueue with constraints is accepted', () async {
      await NativeWorkManager.initialize();
      final result = await NativeWorkManager.enqueue(
        taskId: 'constrained',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpRequest(url: 'https://example.com'),
        constraints: const Constraints(requiresNetwork: true),
      );
      expect(result.scheduleResult, ScheduleResult.accepted);
    });

    test('enqueue native httpDownload worker is accepted', () async {
      await NativeWorkManager.initialize();
      final result = await NativeWorkManager.enqueue(
        taskId: 'download',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpDownload(
          url: 'https://example.com/file.zip',
          savePath: '/tmp/file.zip',
        ),
      );
      expect(result.scheduleResult, ScheduleResult.accepted);
    });

    test('EnqueueResult scheduleResult is accessible', () async {
      await NativeWorkManager.initialize();
      final result = await NativeWorkManager.enqueue(
        taskId: 'check-result',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpSync(url: 'https://example.com'),
      );
      expect(result.scheduleResult, isA<ScheduleResult>());
    });
  });

  // ─── ExistingTaskPolicy enum ───────────────────────────────────────────────

  group('ExistingTaskPolicy', () {
    test('has keep and replace values', () {
      expect(ExistingTaskPolicy.values, contains(ExistingTaskPolicy.keep));
      expect(ExistingTaskPolicy.values, contains(ExistingTaskPolicy.replace));
    });

    test('keep != replace', () {
      expect(ExistingTaskPolicy.keep, isNot(ExistingTaskPolicy.replace));
    });
  });
}
