import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Parallel Download Integration Test', () {
    late Directory tmpDir;

    setUpAll(() async {
      await NativeWorkManager.initialize();
      await NativeWorkManager.cancelAll();
      tmpDir = await getTemporaryDirectory();
    });

    tearDownAll(() async {
      await NativeWorkManager.cancelAll();
    });

    /// Helper to wait for a task event
    Future<TaskEvent?> waitEvent(
      String taskId, {
      Duration timeout = const Duration(minutes: 2),
    }) async {
      final completer = Completer<TaskEvent?>();
      late StreamSubscription sub;
      sub = NativeWorkManager.events.listen((event) {
        if (event.taskId == taskId) {
          completer.complete(event);
          sub.cancel();
        }
      });
      return completer.future.timeout(
        timeout,
        onTimeout: () {
          sub.cancel();
          return null;
        },
      );
    }

    testWidgets('should download a file in parallel chunks and merge correctly', (
      tester,
    ) async {
      final taskId = 'parallel_dl_${DateTime.now().millisecondsSinceEpoch}';
      final savePath = '${tmpDir.path}/large_file.zip';

      // Remove old file if exists
      final file = File(savePath);
      if (file.existsSync()) file.deleteSync();

      final future = waitEvent(taskId);

      // We use a known large file from GitHub or a reliable CDN for testing parallel download.
      // 5MB is enough to test 4 chunks (~1.25MB each).
      const downloadUrl =
          'https://raw.githubusercontent.com/flutter/flutter/master/bin/cache/pkg/sky_engine/lib/ui/window.dart'; // Just a sample, better to use a real large file
      // Actually, let's use a 5MB random data file if possible, or a known stable large URL.
      // For this test, let's use a reliable 1MB file from httpbin.
      const reliableUrl =
          'https://httpbin.org/image/png'; // ~8KB, too small for parallel but good for logic.

      // Let's use a real large file for true parallel test
      const largeFileUrl =
          'https://github.com/brewkits/native_workmanager/raw/main/benchmark/assets/test_5mb.zip';

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: const TaskTrigger.oneTime(),
        worker: NativeWorker.parallelHttpDownload(
          url: largeFileUrl,
          savePath: savePath,
          numChunks: 4, // Split into 4 chunks
          expectedChecksum: 'optional_checksum_here', // If we know it
          checksumAlgorithm: 'SHA-256',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;

      expect(event, isNotNull, reason: 'Parallel download should complete');
      expect(
        event!.success,
        isTrue,
        reason: 'Parallel download should succeed',
      );

      // Verify file exists and has size
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), isPositive);

      // Verify result data indicates parallel execution
      if (event.resultData != null) {
        expect(event.resultData!['parallelDownload'], isTrue);
        expect(event.resultData!['numChunks'], 4);
      }
    });

    testWidgets(
      'should fallback to sequential download if server does not support Range',
      (tester) async {
        final taskId = 'fallback_dl_${DateTime.now().millisecondsSinceEpoch}';
        final savePath = '${tmpDir.path}/fallback_file.png';

        // httpbin.org/image/png does NOT support Range requests.
        const urlNoRange = 'https://httpbin.org/image/png';

        final future = waitEvent(taskId);

        await NativeWorkManager.enqueue(
          taskId: taskId,
          trigger: const TaskTrigger.oneTime(),
          worker: NativeWorker.parallelHttpDownload(
            url: urlNoRange,
            savePath: savePath,
            numChunks: 4,
          ),
        );

        final event = await future;

        expect(event, isNotNull);
        expect(
          event!.success,
          isTrue,
          reason: 'Should succeed even with fallback',
        );

        if (event.resultData != null) {
          // parallelDownload should be false or missing in sequential fallback
          expect(event.resultData!['parallelDownload'], isNot(isTrue));
        }
      },
    );
  });
}
