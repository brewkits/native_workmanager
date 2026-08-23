import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:native_workmanager/src/method_channel.dart';
import 'package:native_workmanager/src/platform_interface.dart';

/// Regression tests for the `OfflineQueue` cancel-during-flight race.
///
/// `_processHead()` captures `slot = _pending.first`, then awaits the task's
/// completion event for up to an hour. `cancel()` is synchronous and mutates
/// `_pending` directly, so it can land inside that window. The failure path
/// then wrote back through a **positional** index (`_pending[0] = …` /
/// `_pending.removeAt(0)`) on the assumption that index 0 was still the slot it
/// started with — while the success path at the top of the same method already
/// used the correct identity-based `_pending.remove(slot)`.
///
/// Two observable consequences, both covered below:
///   1. queue emptied by cancel  → `RangeError` writing to `_pending[0]`
///   2. head replaced by another → that other entry is silently overwritten
class _FakeQueuePlatform extends MethodChannelNativeWorkManager {
  final eventsController = StreamController<TaskEvent>.broadcast();
  final enqueued = <String>[];
  final cancelled = <String>[];

  @override
  Stream<TaskEvent> get events => eventsController.stream;

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
    required Constraints constraints,
    required ExistingTaskPolicy existingPolicy,
    String? tag,
  }) async {
    enqueued.add(taskId);
    return ScheduleResult.accepted;
  }

  @override
  Future<bool> cancel({String? taskId, String? tag}) async {
    if (taskId != null) cancelled.add(taskId);
    return true;
  }

  void failTask(String nativeTaskId) {
    eventsController.add(TaskEvent(
      taskId: nativeTaskId,
      success: false,
      message: 'simulated failure',
      timestamp: DateTime.now(),
    ));
  }

  Future<void> dispose() => eventsController.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeQueuePlatform platform;

  setUp(() async {
    platform = _FakeQueuePlatform();
    NativeWorkManagerPlatform.instance = platform;
    NativeWorkManager.resetInitializedState();
    await NativeWorkManager.initialize();
  });

  tearDown(() async {
    await platform.dispose();
  });

  QueueEntry entryFor(String id) => QueueEntry(
        taskId: id,
        worker: NativeWorker.httpRequest(url: 'https://example.com/$id'),
        // maxRetries > 0 so a failure takes the retry branch (the buggy write),
        // not the dead-letter branch.
        retryPolicy: const OfflineRetryPolicy(
          maxRetries: 3,
          initialDelay: Duration.zero,
          requiresNetwork: false,
        ),
      );

  group('OfflineQueue: cancel during an in-flight task', () {
    test(
        'cancelling the in-flight task must not overwrite the next queued entry',
        () async {
      final queue = OfflineQueue(id: 'q1');
      await queue.enqueue(entryFor('taskA'));
      await queue.enqueue(entryFor('taskB'));

      queue.start();
      await pumpEventQueue();
      expect(platform.enqueued, contains('q1__taskA__0'),
          reason: 'taskA should be the in-flight head');
      expect(queue.pendingCount, 2);

      // Cancel the in-flight head while _processHead is awaiting its event.
      queue.cancel(taskId: 'taskA');
      expect(queue.pendingCount, 1, reason: 'only taskB should remain');

      // Now the awaited event arrives as a failure → retry branch runs.
      platform.failTask('q1__taskA__0');
      await pumpEventQueue();

      // The retry slot for taskA must NOT clobber taskB at index 0.
      expect(
        queue.pendingCount,
        1,
        reason: 'taskB must still be queued after taskA was cancelled '
            'mid-flight — a positional _pending[0] write would replace it',
      );
      expect(
        platform.enqueued.any((t) => t.contains('taskB')),
        isTrue,
        reason: 'taskB must still get scheduled; if the retry slot for the '
            'cancelled taskA overwrote it, taskB is silently lost forever',
      );
      expect(
        platform.enqueued.any((t) => t == 'q1__taskA__1'),
        isFalse,
        reason: 'a cancelled task must not be retried',
      );
    });

    test('cancelling every entry mid-flight must not throw RangeError',
        () async {
      final queue = OfflineQueue(id: 'q2');
      await queue.enqueue(entryFor('solo'));

      queue.start();
      await pumpEventQueue();
      expect(platform.enqueued, contains('q2__solo__0'));

      // Empties _pending while _processHead is awaiting.
      queue.cancel(taskId: 'solo');
      expect(queue.pendingCount, 0);

      Object? caught;
      await runZonedGuardedAsync(() async {
        platform.failTask('q2__solo__0');
        await pumpEventQueue();
      }, (e, _) => caught = e);

      expect(
        caught,
        isNull,
        reason: 'writing to _pending[0] on an emptied queue throws '
            'RangeError (index): Valid value range is empty: 0',
      );
      expect(queue.pendingCount, 0);
      expect(queue.deadLetterCount, 0,
          reason: 'a cancelled task must not be dead-lettered either');
    });

    test('normal retry path still works when nothing is cancelled', () async {
      final queue = OfflineQueue(id: 'q3');
      await queue.enqueue(entryFor('keep'));

      queue.start();
      await pumpEventQueue();
      expect(platform.enqueued, contains('q3__keep__0'));

      platform.failTask('q3__keep__0');
      await pumpEventQueue();

      expect(queue.pendingCount, 1,
          reason: 'the entry stays queued with an incremented attempt');
      expect(platform.enqueued, contains('q3__keep__1'),
          reason: 'attempt 1 must be scheduled — the retry path must not '
              'regress while fixing the cancel race');
    });
  });
}

/// Runs [body] capturing async errors that escape into the zone.
Future<void> runZonedGuardedAsync(
  Future<void> Function() body,
  void Function(Object, StackTrace) onError,
) async {
  final done = Completer<void>();
  runZonedGuarded(() async {
    try {
      await body();
    } finally {
      if (!done.isCompleted) done.complete();
    }
  }, (e, s) {
    onError(e, s);
    if (!done.isCompleted) done.complete();
  });
  await done.future;
}
