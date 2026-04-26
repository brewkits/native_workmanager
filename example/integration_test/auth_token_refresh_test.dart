import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Token Refresh Integration Test', () {
    setUpAll(() async {
      await NativeWorkManager.initialize();
      await NativeWorkManager.cancelAll();
    });

    tearDownAll(() async {
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
        print(
          'WaitEvent: received event for ${event.taskId}, success=${event.success}, hasResultData=${event.resultData != null}, isStarted=${event.isStarted}',
        );
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

    testWidgets('should refresh token on 401 and retry successfully', (
      tester,
    ) async {
      final taskId = 'auth_refresh_${DateTime.now().millisecondsSinceEpoch}';
      final future = waitEvent(taskId);

      // We use httpbin.org/bearer which returns 200 ONLY if Authorization header is present.
      // 1. Initial request fails because we don't provide a token in headers initially.
      // 2. Plugin sees 401 (httpbin returns 401 for /bearer if no auth).
      // 3. Plugin calls refreshUrl (httpbin.org/post) which returns a JSON containing "access_token".
      // 4. Plugin retries with the new token.

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: const TaskTrigger.oneTime(),
        worker: NativeWorker.httpRequest(
          url: 'https://httpbin.org/bearer',
          method: HttpMethod.get,
          // Configure automatic token refresh
          tokenRefresh: TokenRefreshConfig(
            url: 'https://httpbin.org/post', // Mock refresh endpoint
            method: 'POST',
            body: {
              'access_token': 'fresh_token_from_httpbin',
            }, // Put token in body so it's echoed
            responseKey:
                'json.access_token', // Path to echoed token in httpbin /post response
            tokenHeaderName: 'Authorization',
            tokenPrefix: 'Bearer ',
          ),
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;

      expect(event, isNotNull, reason: 'Task should complete');
      expect(
        event!.success,
        isTrue,
        reason: 'Task should succeed after token refresh',
      );

      // Additional verification: resultData should contain response from httpbin/bearer
      if (event.resultData != null) {
        final body = event.resultData!['body'] as String?;
        expect(
          body,
          contains('"authenticated": true'),
          reason: 'Should be authenticated after refresh',
        );
      }
    });

    testWidgets(
      'should fail if token refresh itself fails (e.g., 404 on refresh URL)',
      (tester) async {
        final taskId = 'auth_fail_${DateTime.now().millisecondsSinceEpoch}';
        final future = waitEvent(taskId);

        await NativeWorkManager.enqueue(
          taskId: taskId,
          trigger: const TaskTrigger.oneTime(),
          worker: NativeWorker.httpRequest(
            url: 'https://httpbin.org/bearer',
            tokenRefresh: TokenRefreshConfig(
              url: 'https://httpbin.org/status/404', // Invalid refresh URL
            ),
          ),
        );

        final event = await future;
        expect(event, isNotNull);
        expect(
          event!.success,
          isFalse,
          reason: 'Task should fail if refresh fails',
        );
      },
    );
  });
}
