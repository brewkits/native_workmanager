// ignore_for_file: avoid_print
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

@pragma('vm:entry-point')
Future<bool> _fgsPassWorker(Map<String, dynamic>? input) async {
  print('[DartWorker] FGS worker running');
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  String _id(String name) =>
      'fgs_${name}_${DateTime.now().millisecondsSinceEpoch}';

  Future<TaskEvent?> _waitEvent(
    String taskId, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final completer = Completer<TaskEvent?>();
    late StreamSubscription<TaskEvent> sub;
    print('[_waitEvent] Listening for events for taskId: $taskId');
    sub = NativeWorkManager.events.listen((event) {
      print('[_waitEvent] Received event: taskId=${event.taskId}, success=${event.success}, isStarted=${event.isStarted}, message=${event.message}');
      if (event.taskId == taskId && !event.isStarted && !completer.isCompleted) {
        print('[_waitEvent] Completing for $taskId with success=${event.success}');
        completer.complete(event);
        sub.cancel();
      }
    });
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        print('[_waitEvent] Timeout for $taskId');
        sub.cancel();
        completer.complete(null);
      }
    });
    return completer.future;
  }

  group('Foreground Service (FGS) Integration Tests', () {
    setUpAll(() async {
      await NativeWorkManager.initialize(
        dartWorkers: {
          'fgs_pass': _fgsPassWorker,
        },
      );
    });

    testWidgets('Android FGS - HttpRequestWorker with FGS Config', (tester) async {
      final id = _id('http_fgs');
      final future = _waitEvent(id, timeout: const Duration(seconds: 60));

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: Constraints(
          requiresNetwork: true,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            title: 'Test FGS Task',
            body: 'Executing HTTP request in foreground...',
            colorHex: '#4CAF50',
            showCancelButton: true,
          ),
          foregroundServiceType: ForegroundServiceType.dataSync,
        ),
      );

      expect(result.scheduleResult, ScheduleResult.accepted);
      print('Task $id enqueued with FGS config');

      final event = await future;
      expect(event, isNotNull, reason: 'FGS task must emit event');
      expect(event!.success, isTrue, reason: 'FGS task must complete successfully. Error: ${event.message}');
      print('Task $id completed successfully in FGS mode');
    });

    testWidgets('Android FGS - DartWorker with FGS Config', (tester) async {
      final id = _id('dart_fgs');
      final future = _waitEvent(id, timeout: const Duration(seconds: 60));

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        worker: DartWorker(callbackId: 'fgs_pass'),
        constraints: Constraints(
          isHeavyTask: true,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            title: 'Test Dart FGS',
            body: 'Executing Dart code in foreground...',
          ),
        ),
      );

      expect(result.scheduleResult, ScheduleResult.accepted);

      final event = await future;
      expect(event, isNotNull, reason: 'Dart FGS task must emit event');
      expect(event!.success, isTrue);
    });
  });
}
