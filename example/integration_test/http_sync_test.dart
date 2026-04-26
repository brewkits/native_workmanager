import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('HttpSyncWorker Token Refresh Test', () {
    setUpAll(() async {
      await NativeWorkManager.initialize();
      await NativeWorkManager.cancelAll();
    });

    /// Helper to wait for a task event
    Future<TaskEvent?> waitEvent(
      String taskId, {
      Duration timeout = const Duration(seconds: 60),
    }) async {
      final completer = Completer<TaskEvent?>();
      late StreamSubscription<TaskEvent> sub;
      sub = NativeWorkManager.events.listen((event) {
        if (event.taskId == taskId &&
            !completer.isCompleted &&
            !event.isStarted) {
          completer.complete(event);
          sub.cancel();
        }
      });

      try {
        return await completer.future.timeout(timeout);
      } catch (e) {
        sub.cancel();
        // Fallback: check status directly from DB
        final record = await NativeWorkManager.getTaskRecord(taskId: taskId);
        if (record != null &&
            (record.status == 'success' ||
                record.status == 'failed' ||
                record.status == 'cancelled')) {
          return TaskEvent(
            taskId: taskId,
            success: record.status == 'success',
            message: record.status == 'failed'
                ? 'Task failed in background'
                : null,
            resultData: record.resultData,
            timestamp: record.updatedAt,
          );
        }
        return null;
      }
    }

    testWidgets('should refresh token on 401 for HttpSyncWorker', (
      tester,
    ) async {
      final taskId = 'sync_refresh_${DateTime.now().millisecondsSinceEpoch}';
      final future = waitEvent(taskId);

      await NativeWorkManager.enqueue(
        taskId: taskId,
        worker: NativeWorker.httpSync(
          url: 'https://httpbin.org/bearer',
          method: HttpMethod.get,
          tokenRefresh: TokenRefreshConfig(
            url: 'https://httpbin.org/post',
            method: 'POST',
            body: {'access_token': 'sync_fresh_token'},
            responseKey: 'json.access_token',
          ),
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;

      expect(event, isNotNull, reason: 'Sync task should complete');
      expect(
        event!.success,
        isTrue,
        reason: 'Sync task should succeed after refresh: ${event.message}',
      );
    });
  });
}
