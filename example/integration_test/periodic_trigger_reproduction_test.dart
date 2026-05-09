// ignore_for_file: avoid_print
// ============================================================
// Periodic Trigger Reproduction & Regression Tests
// ============================================================
//
// Covers all valid TaskTrigger.periodic parameter combinations,
// including Issue #26 (initialDelay + runImmediately: false).
//
// Run on a real device or emulator:
//   cd example && flutter test integration_test/periodic_trigger_reproduction_test.dart
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Unique task IDs to avoid collisions across test runs.
String _id(String name) =>
    'prt_${name}_${DateTime.now().millisecondsSinceEpoch}';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await NativeWorkManager.initialize();
    // Cancel any leftover tasks from previous runs.
    await NativeWorkManager.cancelAll();
  });

  tearDownAll(() async {
    await NativeWorkManager.cancelAll();
  });

  group('Periodic Trigger – parameter acceptance', () {
    // ──────────────────────────────────────────────────────────
    // REGRESSION – Issue #26
    // Previously an AssertionError was thrown for this combo because
    // "initialDelay + runImmediately: false seemed contradictory".
    // Both params are independently valid; the OS decides ordering.
    // ──────────────────────────────────────────────────────────
    testWidgets(
      'issue_26: periodic with initialDelay + runImmediately:false is accepted',
      (tester) async {
        final id = _id('issue_26');

        final result = await NativeWorkManager.enqueue(
          taskId: id,
          trigger: TaskTrigger.periodic(
            const Duration(minutes: 15),
            initialDelay: const Duration(minutes: 5),
            runImmediately: false,
          ),
          worker: NativeWorker.httpSync(url: 'https://example.com/sync'),
        );

        expect(
          result.scheduleResult,
          ScheduleResult.accepted,
          reason:
              'issue_26: periodic with initialDelay + runImmediately:false must be accepted',
        );

        final status = await NativeWorkManager.getTaskStatus(taskId: id);
        expect(status, isNotNull, reason: 'Task must be tracked after enqueue');

        await NativeWorkManager.cancel(taskId: id);
      },
    );

    // ──────────────────────────────────────────────────────────
    // Baseline: minimum valid periodic task (15-min interval only)
    // ──────────────────────────────────────────────────────────
    testWidgets('periodic – minimum interval (15 min) is accepted', (
      tester,
    ) async {
      final id = _id('min_interval');

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.periodic(Duration(minutes: 15)),
        worker: NativeWorker.httpSync(url: 'https://example.com/sync'),
      );

      expect(
        result.scheduleResult,
        ScheduleResult.accepted,
        reason: 'Minimum 15-min periodic must be accepted',
      );

      await NativeWorkManager.cancel(taskId: id);
    });

    // ──────────────────────────────────────────────────────────
    // flexInterval: tests the KMP bridge flexMs conversion.
    // A wrong cast (flexMs as? KotlinLong) silently returns nil —
    // the KotlinLong(value:) constructor is the correct path.
    // ──────────────────────────────────────────────────────────
    testWidgets('periodic – with flexInterval is accepted', (tester) async {
      final id = _id('flex');

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: TaskTrigger.periodic(
          const Duration(minutes: 15),
          flexInterval: const Duration(minutes: 5),
        ),
        worker: NativeWorker.httpSync(url: 'https://example.com/sync'),
      );

      expect(
        result.scheduleResult,
        ScheduleResult.accepted,
        reason: 'Periodic with flexInterval must be accepted',
      );

      await NativeWorkManager.cancel(taskId: id);
    });

    // ──────────────────────────────────────────────────────────
    // initialDelay alone (no runImmediately override)
    // ──────────────────────────────────────────────────────────
    testWidgets('periodic – with initialDelay is accepted', (tester) async {
      final id = _id('initial_delay');

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: TaskTrigger.periodic(
          const Duration(minutes: 15),
          initialDelay: const Duration(minutes: 1),
        ),
        worker: NativeWorker.httpSync(url: 'https://example.com/sync'),
      );

      expect(
        result.scheduleResult,
        ScheduleResult.accepted,
        reason: 'Periodic with initialDelay must be accepted',
      );

      await NativeWorkManager.cancel(taskId: id);
    });

    // ──────────────────────────────────────────────────────────
    // runImmediately: true (explicit, should behave same as default)
    // ──────────────────────────────────────────────────────────
    testWidgets('periodic – with runImmediately:true is accepted', (
      tester,
    ) async {
      final id = _id('run_immediately');

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: TaskTrigger.periodic(
          const Duration(minutes: 15),
          runImmediately: true,
        ),
        worker: NativeWorker.httpSync(url: 'https://example.com/sync'),
      );

      expect(
        result.scheduleResult,
        ScheduleResult.accepted,
        reason: 'Periodic with runImmediately:true must be accepted',
      );

      await NativeWorkManager.cancel(taskId: id);
    });

    // ──────────────────────────────────────────────────────────
    // All params combined: interval + flex + initialDelay + runImmediately:false
    // This is the most complete form and must not be blocked by any assert.
    // ──────────────────────────────────────────────────────────
    testWidgets(
      'issue_26: periodic with all params (interval+flex+initialDelay+runImmediately:false) is accepted',
      (tester) async {
        final id = _id('all_params');

        final result = await NativeWorkManager.enqueue(
          taskId: id,
          trigger: TaskTrigger.periodic(
            const Duration(minutes: 15),
            flexInterval: const Duration(minutes: 5),
            initialDelay: const Duration(minutes: 1),
            runImmediately: false,
          ),
          worker: NativeWorker.httpSync(url: 'https://example.com/sync'),
        );

        expect(
          result.scheduleResult,
          ScheduleResult.accepted,
          reason:
              'issue_26: periodic with all params must be accepted without error',
        );

        final status = await NativeWorkManager.getTaskStatus(taskId: id);
        expect(
          status,
          isNotNull,
          reason: 'Task must be tracked after full-param enqueue',
        );

        await NativeWorkManager.cancel(taskId: id);
      },
    );

    // ──────────────────────────────────────────────────────────
    // Cancel verification: task must disappear from tracking after cancel.
    // Protects against state leaks between test runs.
    // ──────────────────────────────────────────────────────────
    testWidgets('periodic – cancel removes task from tracking', (tester) async {
      final id = _id('cancel_verify');

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.periodic(Duration(minutes: 15)),
        worker: NativeWorker.httpSync(url: 'https://example.com/sync'),
      );

      expect(result.scheduleResult, ScheduleResult.accepted);

      await NativeWorkManager.cancel(taskId: id);

      // After cancel, task must not be in a runnable/pending state.
      final status = await NativeWorkManager.getTaskStatus(taskId: id);
      expect(
        status,
        anyOf(isNull, equals(TaskStatus.cancelled)),
        reason: 'Cancelled periodic task must not remain pending',
      );
    });

    // ──────────────────────────────────────────────────────────
    // ExistingPolicy.replace: re-enqueueing the same ID replaces it.
    // ──────────────────────────────────────────────────────────
    testWidgets('periodic – REPLACE policy updates existing task', (
      tester,
    ) async {
      final id = _id('policy_replace');

      // First enqueue
      final r1 = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.periodic(Duration(minutes: 15)),
        worker: NativeWorker.httpSync(url: 'https://example.com/sync'),
        existingPolicy: ExistingTaskPolicy.keep,
      );
      expect(r1.scheduleResult, ScheduleResult.accepted);

      // Replace with a different flex window
      final r2 = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: TaskTrigger.periodic(
          const Duration(minutes: 15),
          flexInterval: const Duration(minutes: 5),
        ),
        worker: NativeWorker.httpSync(url: 'https://example.com/sync'),
        existingPolicy: ExistingTaskPolicy.replace,
      );

      expect(
        r2.scheduleResult,
        ScheduleResult.accepted,
        reason: 'REPLACE on an existing periodic task must be accepted',
      );

      await NativeWorkManager.cancel(taskId: id);
    });
  });
}
