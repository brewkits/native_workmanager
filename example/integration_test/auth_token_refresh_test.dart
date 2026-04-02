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
    Future<TaskEvent?> waitEvent(String taskId, {Duration timeout = const Duration(seconds: 45)}) async {
      final completer = Completer<TaskEvent?>();
      late StreamSubscription sub;
      sub = NativeWorkManager.events.listen((event) {
        if (event.taskId == taskId) {
          completer.complete(event);
          sub.cancel();
        }
      });
      return completer.future.timeout(timeout, onTimeout: () {
        sub.cancel();
        return null;
      });
    }

    testWidgets('should refresh token on 401 and retry successfully', (tester) async {
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
          method: 'GET',
          // Configure automatic token refresh
          tokenRefresh: TokenRefreshConfig(
            url: 'https://httpbin.org/post', // Mock refresh endpoint
            method: 'POST',
            body: {'refresh_token': 'dummy_refresh_token'},
            responseKey: 'json.access_token', // Path to token in httpbin /post response
            tokenHeaderName: 'Authorization',
            tokenPrefix: 'Bearer ',
          ),
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      
      expect(event, isNotNull, reason: 'Task should complete');
      expect(event!.success, isTrue, reason: 'Task should succeed after token refresh');
      
      // Additional verification: resultData should contain response from httpbin/bearer
      if (event.resultData != null) {
        final body = event.resultData!['responseBody'] as String?;
        expect(body, contains('"authenticated": true'), reason: 'Should be authenticated after refresh');
      }
    });

    testWidgets('should fail if token refresh itself fails (e.g., 404 on refresh URL)', (tester) async {
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
      expect(event!.success, isFalse, reason: 'Task should fail if refresh fails');
    });
  });
}
