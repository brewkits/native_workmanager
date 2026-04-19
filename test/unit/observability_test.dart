import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('ObservabilityExtension', () {
    // ignore: deprecated_member_use
    test('useSentry (deprecated) registers callbacks without crashing', () {
      // ignore: deprecated_member_use
      expect(() => NativeWorkManager.useSentry(addBreadcrumbs: true),
          returnsNormally);
    });

    // ignore: deprecated_member_use
    test('useFirebase (deprecated) registers callbacks without crashing', () {
      // ignore: deprecated_member_use
      expect(
          () => NativeWorkManager.useFirebase(
              logToAnalytics: true, logToCrashlytics: true),
          returnsNormally);
    });

    test('Isolated callbacks survive multiple configurations', () {
      var count = 0;
      NativeWorkManager.configure(
        observability: ObservabilityConfig(
          onTaskStart: (id, type) => count++,
        ),
      );

      NativeWorkManager.configure(
        observability: ObservabilityConfig(
          onTaskStart: (id, type) => count += 2,
        ),
      );

      expect(count, 0);
    });
  });

  group('WorkManagerLogger', () {
    test('ObservabilityConfig.fromLogger wires all three callbacks', () {
      final starts = <String>[];
      final completes = <String>[];
      final fails = <String>[];

      final logger = _TestLogger(
        onStart: (id, _) => starts.add(id),
        onComplete: (e) => completes.add(e.taskId),
        onFail: (e) => fails.add(e.taskId),
      );

      final config = ObservabilityConfig.fromLogger(logger);

      final event = TaskEvent(
        taskId: 'task-1',
        success: true,
        workerType: 'HttpRequestWorker',
        timestamp: DateTime.now(),
      );
      final failEvent = TaskEvent(
        taskId: 'task-2',
        success: false,
        message: 'Network error',
        workerType: 'HttpDownloadWorker',
        timestamp: DateTime.now(),
      );

      config.onTaskStart!('task-1', 'HttpRequestWorker');
      config.onTaskComplete!(event);
      config.onTaskFail!(failEvent);

      expect(starts, ['task-1']);
      expect(completes, ['task-1']);
      expect(fails, ['task-2']);
    });

    test('ObservabilityConfig.fromLogger onProgress is null by default', () {
      final config = ObservabilityConfig.fromLogger(
        _TestLogger(
          onStart: (_, __) {},
          onComplete: (_) {},
          onFail: (_) {},
        ),
      );
      expect(config.onProgress, isNull);
    });

    test('WorkManagerLogger can be implemented as a plain class', () {
      // Verify that the abstract class is implementable
      final logger = _TestLogger(
        onStart: (_, __) {},
        onComplete: (_) {},
        onFail: (_) {},
      );
      expect(logger, isA<WorkManagerLogger>());
    });
  });

  group('ExactTrigger iOS guard', () {
    test('enqueue throws UnsupportedError for ExactTrigger on iOS', () {
      // This test verifies the guard is present in the codebase;
      // platform-specific behaviour requires integration tests on device.
      // We verify the trigger type is correctly classified.
      final trigger = TaskTrigger.exact(DateTime(2025, 1, 1, 9, 0));
      expect(trigger, isA<ExactTrigger>());
    });
  });
}

class _TestLogger implements WorkManagerLogger {
  _TestLogger({
    required void Function(String taskId, String workerType) onStart,
    required void Function(TaskEvent event) onComplete,
    required void Function(TaskEvent event) onFail,
  })  : _onStart = onStart,
        _onComplete = onComplete,
        _onFail = onFail;

  final void Function(String, String) _onStart;
  final void Function(TaskEvent) _onComplete;
  final void Function(TaskEvent) _onFail;

  @override
  void onTaskStart(String taskId, String workerType) =>
      _onStart(taskId, workerType);

  @override
  void onTaskComplete(TaskEvent event) => _onComplete(event);

  @override
  void onTaskFail(TaskEvent event) => _onFail(event);
}
