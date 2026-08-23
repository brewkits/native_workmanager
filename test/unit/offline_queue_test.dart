import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:native_workmanager/src/method_channel.dart';
import 'package:native_workmanager/src/platform_interface.dart';

class _FakeQueuePlatform extends MethodChannelNativeWorkManager {
  final eventsController = StreamController<TaskEvent>.broadcast();
  final progressController = StreamController<TaskProgress>.broadcast();

  final List<String> enqueuedIds = [];
  final List<String> cancelledIds = [];

  @override
  Stream<TaskEvent> get events => eventsController.stream;

  @override
  Stream<TaskProgress> get progress => progressController.stream;

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
  }) async {}

  @override
  Future<ScheduleResult> enqueue({
    required String taskId,
    required TaskTrigger trigger,
    required Worker worker,
    Constraints constraints = const Constraints(),
    ExistingTaskPolicy existingPolicy = ExistingTaskPolicy.replace,
    String? tag,
  }) async {
    enqueuedIds.add(taskId);
    return ScheduleResult.accepted;
  }

  @override
  Future<void> cancel({required String taskId}) async {
    cancelledIds.add(taskId);
  }

  Future<void> dispose() async {
    await eventsController.close();
    await progressController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineRetryPolicy', () {
    test('default values', () {
      const policy = OfflineRetryPolicy();
      expect(policy.maxRetries, 5);
      expect(policy.requiresNetwork, isTrue);
      expect(policy.requiresCharging, isFalse);
      expect(policy.backoffMultiplier, 2.0);
      expect(policy.initialDelay, const Duration(seconds: 30));
      expect(policy.maxDelay, const Duration(hours: 6));
    });

    test('convenience policies', () {
      expect(OfflineRetryPolicy.networkAvailable.maxRetries, 10);
      expect(OfflineRetryPolicy.networkAvailable.requiresNetwork, isTrue);

      expect(OfflineRetryPolicy.networkRequired.maxRetries, 5);
      expect(OfflineRetryPolicy.networkRequired.requiresNetwork, isTrue);

      expect(OfflineRetryPolicy.aggressive.maxRetries, 3);
      expect(OfflineRetryPolicy.aggressive.requiresNetwork, isFalse);
      expect(OfflineRetryPolicy.aggressive.initialDelay,
          const Duration(seconds: 5));
    });

    test('delayFor calculations with backoffMultiplier = 2.0', () {
      const policy = OfflineRetryPolicy(
        initialDelay: Duration(seconds: 10),
        backoffMultiplier: 2.0,
        maxDelay: Duration(seconds: 100),
      );

      // attempt 0 = initialDelay * 1
      expect(policy.delayFor(0), const Duration(seconds: 10));
      // attempt 1 = initialDelay * 2^1
      expect(policy.delayFor(1), const Duration(seconds: 20));
      // attempt 2 = initialDelay * 2^2
      expect(policy.delayFor(2), const Duration(seconds: 40));
      // attempt 3 = initialDelay * 2^3 (80s)
      expect(policy.delayFor(3), const Duration(seconds: 80));
      // attempt 4 = initialDelay * 2^4 (160s, clamped to 100s)
      expect(policy.delayFor(4), const Duration(seconds: 100));
    });

    test('delayFor calculations with backoffMultiplier = 1.0 (constant)', () {
      const policy = OfflineRetryPolicy(
        initialDelay: Duration(seconds: 10),
        backoffMultiplier: 1.0,
      );

      expect(policy.delayFor(0), const Duration(seconds: 10));
      expect(policy.delayFor(1), const Duration(seconds: 10));
      expect(policy.delayFor(5), const Duration(seconds: 10));
    });

    test('toMap serializes correctly', () {
      const policy = OfflineRetryPolicy(
        maxRetries: 3,
        requiresNetwork: false,
        requiresCharging: true,
        backoffMultiplier: 1.5,
        initialDelay: Duration(seconds: 15),
        maxDelay: Duration(hours: 1),
      );

      final map = policy.toMap();
      expect(map['maxRetries'], 3);
      expect(map['requiresNetwork'], isFalse);
      expect(map['requiresCharging'], isTrue);
      expect(map['backoffMultiplier'], 1.5);
      expect(map['initialDelayMs'], 15000);
      expect(map['maxDelayMs'], 3600000);
    });

    test('asserts on invalid inputs', () {
      expect(() => OfflineRetryPolicy(maxRetries: -1),
          throwsA(isA<AssertionError>()));
      expect(() => OfflineRetryPolicy(maxRetries: 101),
          throwsA(isA<AssertionError>()));
      expect(() => OfflineRetryPolicy(backoffMultiplier: 0.5),
          throwsA(isA<AssertionError>()));
    });
  });

  group('QueueEntry', () {
    test('toMap serializes correctly', () {
      final worker = NativeWorker.httpRequest(url: 'https://example.com');
      final entry = QueueEntry(
        taskId: 'task-1',
        worker: worker,
        retryPolicy: OfflineRetryPolicy.aggressive,
        tag: 'my-tag',
      );

      final map = entry.toMap();
      expect(map['taskId'], 'task-1');
      expect(map['workerClassName'], 'HttpRequestWorker');
      expect(map['workerConfig'], worker.toMap());
      expect(map['retryPolicy'], isNotNull);
      expect(map['tag'], 'my-tag');
    });
  });

  group('OfflineQueue', () {
    late OfflineQueue queue;
    late _FakeQueuePlatform platform;

    setUp(() async {
      platform = _FakeQueuePlatform();
      NativeWorkManagerPlatform.instance = platform;
      await NativeWorkManager.initialize();
      queue = OfflineQueue(id: 'test-queue', maxSize: 3);
    });

    tearDown(() async {
      queue.stop();
      await platform.dispose();
    });

    test('initial state', () {
      expect(queue.id, 'test-queue');
      expect(queue.maxSize, 3);
      expect(queue.pendingCount, 0);
      expect(queue.deadLetterCount, 0);
      expect(queue.isRunning, isFalse);
    });

    test('enqueue adds to pending', () async {
      await queue.enqueue(QueueEntry(
        taskId: 't1',
        worker: NativeWorker.httpRequest(url: 'https://a.com'),
      ));
      expect(queue.pendingCount, 1);
    });

    test('enqueue respects maxSize', () async {
      final worker = NativeWorker.httpRequest(url: 'https://a.com');
      await queue.enqueue(QueueEntry(taskId: 't1', worker: worker));
      await queue.enqueue(QueueEntry(taskId: 't2', worker: worker));
      await queue.enqueue(QueueEntry(taskId: 't3', worker: worker));
      expect(queue.pendingCount, 3);

      // 4th should be ignored
      await queue.enqueue(QueueEntry(taskId: 't4', worker: worker));
      expect(queue.pendingCount, 3);
    });

    test('start and stop toggle isRunning', () {
      expect(queue.isRunning, isFalse);
      queue.start();
      expect(queue.isRunning, isTrue);
      queue.stop();
      expect(queue.isRunning, isFalse);
    });

    test('cancel removes from pending by taskId', () async {
      final worker = NativeWorker.httpRequest(url: 'https://a.com');
      await queue.enqueue(QueueEntry(taskId: 't1', worker: worker));
      await queue.enqueue(QueueEntry(taskId: 't2', worker: worker));

      expect(queue.pendingCount, 2);
      queue.cancel(taskId: 't1');
      expect(queue.pendingCount, 1);
    });

    test('cancel removes from pending by tag', () async {
      final worker = NativeWorker.httpRequest(url: 'https://a.com');
      await queue
          .enqueue(QueueEntry(taskId: 't1', worker: worker, tag: 'groupA'));
      await queue
          .enqueue(QueueEntry(taskId: 't2', worker: worker, tag: 'groupB'));

      expect(queue.pendingCount, 2);
      queue.cancel(tag: 'groupA');
      expect(queue.pendingCount, 1);
    });

    test('clearDeadLetter empties deadLetter list', () {
      queue.clearDeadLetter();
      expect(queue.deadLetterCount, 0);
    });

    test('processes head task and completes on success event', () async {
      final worker = NativeWorker.httpRequest(url: 'https://example.com');
      await queue.enqueue(QueueEntry(
        taskId: 'success_task',
        worker: worker,
        retryPolicy: const OfflineRetryPolicy(
          maxRetries: 1,
          initialDelay: Duration.zero,
        ),
      ));

      queue.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(platform.enqueuedIds, contains('test-queue__success_task__0'));

      platform.eventsController.add(TaskEvent(
        taskId: 'test-queue__success_task__0',
        success: true,
        isStarted: false,
        timestamp: DateTime.now(),
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(queue.pendingCount, 0);
      expect(queue.deadLetterCount, 0);
    });

    test('retries on failure and moves to dead letter when exhausted',
        () async {
      final worker = NativeWorker.httpRequest(url: 'https://example.com');
      await queue.enqueue(QueueEntry(
        taskId: 'fail_task',
        worker: worker,
        retryPolicy: const OfflineRetryPolicy(
          maxRetries: 1,
          initialDelay: Duration.zero,
        ),
      ));

      queue.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Attempt 0 fails
      platform.eventsController.add(TaskEvent(
        taskId: 'test-queue__fail_task__0',
        success: false,
        isStarted: false,
        timestamp: DateTime.now(),
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(platform.enqueuedIds, contains('test-queue__fail_task__1'));

      // Attempt 1 fails (exhausts maxRetries: 1)
      platform.eventsController.add(TaskEvent(
        taskId: 'test-queue__fail_task__1',
        success: false,
        isStarted: false,
        timestamp: DateTime.now(),
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(queue.pendingCount, 0);
      expect(queue.deadLetterCount, 1);

      queue.clearDeadLetter();
      expect(queue.deadLetterCount, 0);
    });
  });
}
