// Android: cancelling a task must stop the worker's network activity promptly.
//
// Regression coverage for two bugs found in the 2026-11 review (no GitHub issue number):
//  * WebSocketWorker blocked a thread on CountDownLatch.await(), so a cancelled task kept
//    its connection open until the full receive timeout.
//  * ParallelHttpUploadWorker used OkHttp's blocking execute(), so a cancelled upload kept
//    streaming the whole file.
// The assertions live on the SERVER side (it is the only party that can tell whether the
// socket really closed); this test only drives enqueue + cancel.
// Run via scripts/android-cancellation-check.sh, which starts the server, sets up
// `adb reverse` and evaluates the server log.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await NativeWorkManager.initialize();
    await NativeWorkManager.cancelAll();
  });

  testWidgets('cancel_stops_websocket_worker_promptly', (tester) async {
    await NativeWorkManager.enqueue(
      taskId: 'cancel_ws',
      trigger: const TaskTrigger.oneTime(),
      worker: const WebSocketWorker(
        url: 'ws://127.0.0.1:8765/',
        timeoutSeconds: 120, // server never answers: only cancellation can end it early
        receiveMessages: 1,
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 5));
    await NativeWorkManager.cancel(taskId: 'cancel_ws');
    // Give the server time to observe the close; the script asserts on its log.
    await Future<void>.delayed(const Duration(seconds: 12));
  }, skip: !Platform.isAndroid);

  testWidgets('cancel_stops_parallel_upload_promptly', (tester) async {
    // Observed from the app side: through `adb reverse` the tunnel buffers the stream, so the
    // server cannot tell when the client stopped. Progress is counted as bytes are written by
    // OkHttp, so "progress stops advancing after cancel" is the reliable signal. Before the
    // fix the blocking execute() kept going and progress climbed on to 99 after cancel().
    final file = File('${Directory.systemTemp.path}/cancel_upload_12mb.bin');
    file.writeAsBytesSync(List<int>.filled(12 * 1024 * 1024, 7));
    var latest = 0;
    final sub = NativeWorkManager.progress
        .where((p) => p.taskId == 'cancel_upload')
        .listen((p) => latest = p.progress);
    try {
      await NativeWorkManager.enqueue(
        taskId: 'cancel_upload',
        trigger: const TaskTrigger.oneTime(),
        worker: ParallelHttpUploadWorker(
          url: 'http://127.0.0.1:8766/upload',
          files: [UploadFile(filePath: file.path)],
          maxRetries: 0,
          timeout: const Duration(minutes: 5),
        ),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (latest < 20 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(latest, greaterThanOrEqualTo(20), reason: 'upload never started');
      await NativeWorkManager.cancel(taskId: 'cancel_upload');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final atCancel = latest;
      await Future<void>.delayed(const Duration(seconds: 5));
      expect(latest, lessThan(99), reason: 'upload ran to completion after cancel');
      expect(latest - atCancel, lessThanOrEqualTo(2),
          reason: 'progress kept advancing after cancel: $atCancel -> $latest');
    } finally {
      await sub.cancel();
      if (file.existsSync()) file.deleteSync();
    }
  }, skip: !Platform.isAndroid);
}
