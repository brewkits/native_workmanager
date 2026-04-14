import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Progress System Integration Tests', () {
    setUpAll(() async {
      await NativeWorkManager.initialize();
    });

    testWidgets('Full Progress Cycle: Enqueue -> Progress -> Recovery', (tester) async {
      const taskId = 'int-test-progress';
      print('Starting test for task: $taskId');
      
      // Get an absolute path for the download
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/int_test.bin';
      
      // Cleanup if exists
      final file = File(savePath);
      if (file.existsSync()) {
        print('Deleting existing file at $savePath');
        await file.delete();
      }
      
      // 1. Enqueue a real download task (using a 5MB file for more progress updates)
      print('Enqueuing task...');
      final handler = await NativeWorkManager.enqueue(
        taskId: taskId,
        worker: NativeWorker.httpDownload(
          url: 'https://httpbin.org/bytes/5242880', // 5MB
          savePath: savePath,
        ),
      );

      print('Schedule result: ${handler.scheduleResult}');
      expect(handler.scheduleResult, ScheduleResult.accepted);

      // 2. Listen for progress updates
      print('Listening for progress...');
      final progressUpdates = <int>[];
      final sub = handler.progress.listen((p) {
        print('Received progress: ${p.progress}%');
        progressUpdates.add(p.progress);
      });

      // 3. Wait for at least one progress update OR completion
      // We use a longer timeout and check if the task finished
      try {
        await handler.result.timeout(const Duration(minutes: 3));
        print('Task completed. Total progress updates: ${progressUpdates.length}');
      } catch (e) {
        print('Error waiting for result: $e');
        rethrow;
      }

      await sub.cancel();

      // We expect at least the 100% completion event if it's very fast, 
      // but usually multiple updates for 5MB.
      expect(progressUpdates, isNotEmpty, reason: 'Should have received at least one progress update');

      // 4. Test Recovery (getRunningProgress) - might be empty now since it finished, 
      // but let's check if we can call it without crash.
      final runningTasks = await NativeWorkManager.getRunningProgress();
      print('Running tasks after completion: ${runningTasks.keys}');
      
      // 5. Verify file exists
      expect(file.existsSync(), true);
      print('File downloaded successfully to $savePath (${file.lengthSync()} bytes)');
    });
  });
}
