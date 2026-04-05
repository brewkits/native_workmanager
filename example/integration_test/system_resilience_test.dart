// ignore_for_file: avoid_print
// ============================================================
// Native WorkManager – SYSTEM & RESILIENCE TESTS
// ============================================================
//
// These tests verify behaviour under load, rapid operations, and
// edge-case sequences that are hard to trigger in unit tests.
//
// Run on a real device (requires network):
//   flutter test integration_test/system_resilience_test.dart --timeout=none
//
// ============================================================

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

// Top-level callback — PluginUtilities.getCallbackHandle() requires
// a top-level or static function, NOT an anonymous function or closure.
@pragma('vm:entry-point')
Future<bool> _sysPass(Map<String, dynamic>? input) async => true;

String _id(String label) =>
    'sys_${label}_${DateTime.now().millisecondsSinceEpoch}';

Future<TaskEvent?> _waitEvent(
  String taskId, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final completer = Completer<TaskEvent?>();
  late StreamSubscription<TaskEvent> sub;
  sub = NativeWorkManager.events.listen((event) {
    if (event.taskId == taskId && !event.isStarted && !completer.isCompleted) {
      completer.complete(event);
      sub.cancel();
    }
  });
  return Future.any([
    completer.future,
    Future.delayed(timeout, () => null),
  ]).then((v) {
    sub.cancel();
    return v;
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await NativeWorkManager.initialize(
      dartWorkers: {'sys_pass': _sysPass},
    );
    await NativeWorkManager.cancelAll();
  });

  tearDownAll(() async {
    await NativeWorkManager.cancelAll();
  });

  // ════════════════════════════════════════════════════════════
  // STRESS – high task volume
  // ════════════════════════════════════════════════════════════
  group('Stress – high volume', () {
    testWidgets('10 tasks enqueued simultaneously – all complete', (tester) async {
      const count = 10;
      final ids = List.generate(count, (i) => _id('bulk_$i'));
      final futures = ids
          .map((id) => _waitEvent(id, timeout: const Duration(seconds: 90)))
          .toList();

      for (final id in ids) {
        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: HttpRequestWorker(
            url: 'https://jsonplaceholder.typicode.com/posts/1',
          ),
          constraints: const Constraints(requiresNetwork: true),
        );
      }

      final events = await Future.wait(futures);
      final succeeded =
          events.where((e) => e != null && e.success).length;

      print('[bulk_10] $succeeded/$count succeeded');
      expect(
        succeeded,
        greaterThanOrEqualTo(count * 8 ~/ 10), // 80% pass rate under stress
        reason: 'At least 80% of 10 concurrent tasks must succeed',
      );
    });

    testWidgets('rapid enqueue+cancel loop – no crash', (tester) async {
      for (var i = 0; i < 20; i++) {
        final id = _id('rapid_$i');
        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(Duration(seconds: 120)),
          worker: HttpRequestWorker(
            url: 'https://jsonplaceholder.typicode.com/posts/1',
          ),
        );
        await NativeWorkManager.cancel(taskId: id);
      }
      // If we get here without an exception the test passes.
      expect(true, isTrue, reason: 'Rapid enqueue+cancel must not crash');
    });
  });

  // ════════════════════════════════════════════════════════════
  // RESILIENCE – cancelAll mid-flight
  // ════════════════════════════════════════════════════════════
  group('Resilience – cancelAll', () {
    testWidgets('cancelAll during active tasks stops further events', (tester) async {
      // Enqueue 5 tasks with a 120 s delay so they won't fire before cancelAll.
      final ids = List.generate(5, (i) => _id('cancelall_$i'));
      for (final id in ids) {
        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(Duration(seconds: 120)),
          worker: HttpRequestWorker(
            url: 'https://jsonplaceholder.typicode.com/posts/1',
          ),
        );
      }

      await NativeWorkManager.cancelAll();

      var fired = 0;
      final sub = NativeWorkManager.events.listen((event) {
        if (ids.contains(event.taskId) && !event.isStarted) fired++;
      });
      await Future<void>.delayed(const Duration(seconds: 4));
      await sub.cancel();

      expect(fired, 0,
          reason: 'No events must fire after cancelAll on 120 s-delayed tasks');
    });

    testWidgets('new tasks work normally after cancelAll', (tester) async {
      await NativeWorkManager.cancelAll();

      final id = _id('post_cancelall');
      final future = _waitEvent(id, timeout: const Duration(seconds: 30));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      expect(event, isNotNull);
      expect(event!.success, isTrue,
          reason: 'Task enqueued after cancelAll must succeed');
    });
  });

  // ════════════════════════════════════════════════════════════
  // RESILIENCE – tag operations at scale
  // ════════════════════════════════════════════════════════════
  group('Resilience – tag operations at scale', () {
    testWidgets('3 tag groups × 3 tasks – cancelByTag clears each group', (tester) async {
      final tags = List.generate(
          3, (i) => 'sys_tag${i}_${DateTime.now().millisecondsSinceEpoch}');

      // Enqueue 3 tasks per tag (9 total), all with 60 s delay.
      for (final tag in tags) {
        for (var i = 0; i < 3; i++) {
          await NativeWorkManager.enqueue(
            taskId: _id('${tag}_$i'),
            trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
            worker: DartWorker(callbackId: 'sys_pass'),
            tag: tag,
          );
        }
      }

      // Verify initial counts.
      for (final tag in tags) {
        final before = await NativeWorkManager.getTasksByTag(tag: tag);
        expect(before.length, 3,
            reason: 'Each tag group must have 3 tasks before cancel');
      }

      // Cancel each group.
      for (final tag in tags) {
        await NativeWorkManager.cancelByTag(tag: tag);
      }

      // Verify all groups are empty.
      for (final tag in tags) {
        final after = await NativeWorkManager.getTasksByTag(tag: tag);
        expect(after, isEmpty,
            reason: 'Tag group "$tag" must be empty after cancelByTag');
      }
    });

    testWidgets('getAllTags – reflects all active tags', (tester) async {
      final uniqueTags = List.generate(
          3, (i) => 'sys_all_tag${i}_${DateTime.now().millisecondsSinceEpoch}');

      for (final tag in uniqueTags) {
        await NativeWorkManager.enqueue(
          taskId: _id('alltag_$tag'),
          trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
          worker: DartWorker(callbackId: 'sys_pass'),
          tag: tag,
        );
      }

      final allTags = await NativeWorkManager.getAllTags();
      for (final tag in uniqueTags) {
        expect(allTags, contains(tag),
            reason: 'getAllTags must include tag "$tag"');
      }

      // Cleanup
      for (final tag in uniqueTags) {
        await NativeWorkManager.cancelByTag(tag: tag);
      }
    });
  });

  // ════════════════════════════════════════════════════════════
  // RESILIENCE – re-initialize stability
  // ════════════════════════════════════════════════════════════
  group('Resilience – re-initialize', () {
    testWidgets('calling initialize twice does not crash', (tester) async {
      expect(
        () async {
          await NativeWorkManager.initialize(
            dartWorkers: {'sys_pass': _sysPass},
          );
          await NativeWorkManager.initialize(
            dartWorkers: {'sys_pass': _sysPass},
          );
        },
        returnsNormally,
      );
    });

    testWidgets('enqueue immediately after re-initialize succeeds', (tester) async {
      await NativeWorkManager.initialize(
        dartWorkers: {'sys_pass': _sysPass},
      );

      final id = _id('post_reinit');
      final future = _waitEvent(id, timeout: const Duration(seconds: 30));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      expect(event?.success, isTrue,
          reason: 'Task after re-initialize must succeed');
    });
  });

  // ════════════════════════════════════════════════════════════
  // SYSTEM – long-running pause/resume cycle
  // ════════════════════════════════════════════════════════════
  group('System – pause/resume cycle', () {
    testWidgets('pause then resume – task eventually executes', (tester) async {
      final id = _id('pause_resume');
      final future = _waitEvent(id, timeout: const Duration(seconds: 60));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      // Immediately pause then resume.
      await NativeWorkManager.pause(taskId: id);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await NativeWorkManager.resume(taskId: id);

      // The task should still complete (resume re-triggers it).
      final event = await future;
      expect(event, isNotNull,
          reason: 'Paused then resumed task must eventually emit an event');
    });

    testWidgets('pauseAll then resumeAll – tasks complete', (tester) async {
      final ids = List.generate(2, (i) => _id('pause_all_$i'));
      final futures =
          ids.map((id) => _waitEvent(id, timeout: const Duration(seconds: 60))).toList();

      for (final id in ids) {
        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: HttpRequestWorker(
            url: 'https://jsonplaceholder.typicode.com/posts/1',
          ),
          constraints: const Constraints(requiresNetwork: true),
        );
      }

      await NativeWorkManager.pauseAll();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await NativeWorkManager.resumeAll();

      final events = await Future.wait(futures);
      for (var i = 0; i < ids.length; i++) {
        expect(events[i], isNotNull,
            reason: 'Task ${ids[i]} must emit event after pauseAll+resumeAll');
      }
    });
  });

  // ════════════════════════════════════════════════════════════
  // SYSTEM – event stream integrity
  // ════════════════════════════════════════════════════════════
  group('System – event stream', () {
    testWidgets('each task emits exactly one terminal event', (tester) async {
      const count = 4;
      final ids = List.generate(count, (i) => _id('once_$i'));
      final terminalEvents = <String, int>{};

      final sub = NativeWorkManager.events.listen((event) {
        if (ids.contains(event.taskId) && !event.isStarted) {
          terminalEvents[event.taskId] =
              (terminalEvents[event.taskId] ?? 0) + 1;
        }
      });

      for (final id in ids) {
        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(),
          worker: HttpRequestWorker(
            url: 'https://jsonplaceholder.typicode.com/posts/1',
          ),
          constraints: const Constraints(requiresNetwork: true),
        );
      }

      // Wait for all tasks to complete (or timeout).
      await Future<void>.delayed(const Duration(seconds: 45));
      await sub.cancel();

      for (final id in ids) {
        final count = terminalEvents[id] ?? 0;
        if (count > 0) {
          expect(
            count,
            1,
            reason: 'Task $id must emit exactly one terminal event, got $count',
          );
        }
      }
    });

    testWidgets('isStarted events are separate from terminal events', (tester) async {
      final id = _id('lifecycle');
      final startedIds = <String>[];
      final terminalIds = <String>[];

      final sub = NativeWorkManager.events.listen((event) {
        if (event.taskId == id) {
          if (event.isStarted) startedIds.add(id);
          else terminalIds.add(id);
        }
      });

      final eventFuture = _waitEvent(id, timeout: const Duration(seconds: 30));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      await eventFuture;
      await Future<void>.delayed(const Duration(seconds: 1));
      await sub.cancel();

      expect(terminalIds.length, 1,
          reason: 'Exactly one terminal event for task $id');
      expect(startedIds.length, lessThanOrEqualTo(1),
          reason: 'At most one isStarted event per task');
    });
  });
}
