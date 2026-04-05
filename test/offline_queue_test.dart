import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineRetryPolicy', () {
    test('toMap handles all fields', () {
      const policy = OfflineRetryPolicy(
        maxRetries: 3,
        requiresNetwork: true,
        requiresCharging: true,
        backoffMultiplier: 1.5,
        initialDelay: Duration(minutes: 1),
        maxDelay: Duration(hours: 1),
      );

      final map = policy.toMap();
      expect(map['maxRetries'], 3);
      expect(map['requiresNetwork'], true);
      expect(map['requiresCharging'], true);
      expect(map['backoffMultiplier'], 1.5);
      expect(map['initialDelayMs'], 60000);
      expect(map['maxDelayMs'], 3600000);
    });
  });

  group('QueueEntry', () {
    test('toMap handles worker and policy', () {
      final entry = QueueEntry(
        taskId: 'test-task',
        worker: NativeWorker.httpSync(url: 'https://api.com'),
        retryPolicy: OfflineRetryPolicy.networkAvailable,
        tag: 'my-tag',
      );

      final map = entry.toMap();
      expect(map['taskId'], 'test-task');
      expect(map['workerClassName'], contains('HttpSyncWorker'));
      expect(map['retryPolicy']['maxRetries'], 10);
      expect(map['tag'], 'my-tag');
    });
  });
}
