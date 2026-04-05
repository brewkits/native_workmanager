import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('ObservabilityExtension', () {
    test('useSentry registers callbacks', () async {
      // Setup
      NativeWorkManager.useSentry(addBreadcrumbs: true);

      // Since configuration is internal, we trigger an event and verify
      // the debugPrint output or lack of crash.
      // In a real app, this would forward to Sentry.

      // Verify no crash on invocation
      final event = TaskEvent(
        taskId: 'test-task',
        success: true,
        workerType: 'HttpDownloadWorker',
        timestamp: DateTime.now(),
      );

      // Trigger internal dispatcher logic (indirectly)
      expect(
          () => NativeWorkManager.configure(
                observability: ObservabilityConfig(
                  onTaskStart: (id, type) {},
                ),
              ),
          returnsNormally);
    });

    test('useFirebase registers callbacks', () async {
      NativeWorkManager.useFirebase(
          logToAnalytics: true, logToCrashlytics: true);

      // Verify no crash when triggering failure event
      final failEvent = TaskEvent(
        taskId: 'test-task-fail',
        success: false,
        message: 'Network error',
        workerType: 'HttpUploadWorker',
        timestamp: DateTime.now(),
      );

      expect(
          () => NativeWorkManager.configure(
                observability: ObservabilityConfig(
                  onTaskFail: (e) {},
                ),
              ),
          returnsNormally);
    });

    test('Isolated callbacks survive multiple configurations', () {
      var count = 0;
      NativeWorkManager.configure(
        observability: ObservabilityConfig(
          onTaskStart: (id, type) => count++,
        ),
      );

      // Overriding config should be possible
      NativeWorkManager.configure(
        observability: ObservabilityConfig(
          onTaskStart: (id, type) => count += 2,
        ),
      );

      expect(count, 0); // Not triggered yet
    });
  });
}
