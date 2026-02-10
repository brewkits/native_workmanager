import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;

/// Integration tests for FileSystemWorker.
///
/// Tests actual file system operations on real files.
/// Requires running on a device/emulator.
///
/// Coverage: End-to-end worker execution
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDir;
  late String testDirPath;

  setUp(() async {
    // Create temporary test directory
    final tempDir = await getTemporaryDirectory();
    testDir = Directory('${tempDir.path}/file_system_test_${DateTime.now().millisecondsSinceEpoch}');
    await testDir.create(recursive: true);
    testDirPath = testDir.path;

    developer.log('Test directory: $testDirPath');
  });

  tearDown(() async {
    // Cleanup test directory
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('Copy Operations', () {
    test('copy single file', () async {
      // Create source file
      final sourceFile = File('$testDirPath/source.txt');
      await sourceFile.writeAsString('Test content');

      // Copy file
      await NativeWorkManager.enqueue(
        taskId: 'test-copy-file',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: sourceFile.path,
          destinationPath: '$testDirPath/destination.txt',
        ),
      );

      // Wait for completion
      await Future.delayed(const Duration(seconds: 2));

      // Verify destination exists
      final destFile = File('$testDirPath/destination.txt');
      expect(await destFile.exists(), true);
      expect(await destFile.readAsString(), 'Test content');

      // Verify source still exists
      expect(await sourceFile.exists(), true);
    });

    test('copy directory recursively', () async {
      // Create source directory structure
      final sourceDir = Directory('$testDirPath/source_dir');
      await sourceDir.create();
      await File('${sourceDir.path}/file1.txt').writeAsString('Content 1');
      await File('${sourceDir.path}/file2.txt').writeAsString('Content 2');

      final subDir = Directory('${sourceDir.path}/subdir');
      await subDir.create();
      await File('${subDir.path}/file3.txt').writeAsString('Content 3');

      // Copy directory
      await NativeWorkManager.enqueue(
        taskId: 'test-copy-dir',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: sourceDir.path,
          destinationPath: '$testDirPath/dest_dir',
          recursive: true,
        ),
      );

      // Wait for completion
      await Future.delayed(const Duration(seconds: 3));

      // Verify all files copied
      expect(await File('$testDirPath/dest_dir/file1.txt').exists(), true);
      expect(await File('$testDirPath/dest_dir/file2.txt').exists(), true);
      expect(await File('$testDirPath/dest_dir/subdir/file3.txt').exists(), true);
    });

    test('copy with overwrite', () async {
      // Create files
      final sourceFile = File('$testDirPath/source.txt');
      await sourceFile.writeAsString('New content');

      final destFile = File('$testDirPath/destination.txt');
      await destFile.writeAsString('Old content');

      // Copy with overwrite
      await NativeWorkManager.enqueue(
        taskId: 'test-copy-overwrite',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: sourceFile.path,
          destinationPath: destFile.path,
          overwrite: true,
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Verify overwritten
      expect(await destFile.readAsString(), 'New content');
    });
  });

  group('Move Operations', () {
    test('move file', () async {
      // Create source file
      final sourceFile = File('$testDirPath/move_source.txt');
      await sourceFile.writeAsString('Move me');

      // Move file
      await NativeWorkManager.enqueue(
        taskId: 'test-move-file',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileMove(
          sourcePath: sourceFile.path,
          destinationPath: '$testDirPath/moved.txt',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Verify moved
      expect(await sourceFile.exists(), false);
      expect(await File('$testDirPath/moved.txt').exists(), true);
      expect(await File('$testDirPath/moved.txt').readAsString(), 'Move me');
    });

    test('move directory', () async {
      // Create source directory
      final sourceDir = Directory('$testDirPath/move_dir');
      await sourceDir.create();
      await File('${sourceDir.path}/file.txt').writeAsString('Content');

      // Move directory
      await NativeWorkManager.enqueue(
        taskId: 'test-move-dir',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileMove(
          sourcePath: sourceDir.path,
          destinationPath: '$testDirPath/moved_dir',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Verify moved
      expect(await sourceDir.exists(), false);
      expect(await Directory('$testDirPath/moved_dir').exists(), true);
      expect(await File('$testDirPath/moved_dir/file.txt').exists(), true);
    });
  });

  group('Delete Operations', () {
    test('delete single file', () async {
      // Create file
      final file = File('$testDirPath/delete_me.txt');
      await file.writeAsString('Delete this');

      // Delete file
      await NativeWorkManager.enqueue(
        taskId: 'test-delete-file',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileDelete(
          path: file.path,
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Verify deleted
      expect(await file.exists(), false);
    });

    test('delete directory recursively', () async {
      // Create directory structure
      final dir = Directory('$testDirPath/delete_dir');
      await dir.create();
      await File('${dir.path}/file1.txt').writeAsString('Content 1');
      await File('${dir.path}/file2.txt').writeAsString('Content 2');

      final subDir = Directory('${dir.path}/subdir');
      await subDir.create();
      await File('${subDir.path}/file3.txt').writeAsString('Content 3');

      // Delete directory
      await NativeWorkManager.enqueue(
        taskId: 'test-delete-dir',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileDelete(
          path: dir.path,
          recursive: true,
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Verify deleted
      expect(await dir.exists(), false);
    });
  });

  group('List Operations', () {
    test('list files in directory', () async {
      // Create files
      await File('$testDirPath/file1.txt').writeAsString('Content 1');
      await File('$testDirPath/file2.txt').writeAsString('Content 2');
      await File('$testDirPath/file3.jpg').writeAsString('Image');

      // List files
      await NativeWorkManager.enqueue(
        taskId: 'test-list-files',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileList(
          path: testDirPath,
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Verify via event result
      // (In real test, would listen to NativeWorkManager.results)
    });

    test('list with pattern', () async {
      // Create files
      await File('$testDirPath/photo1.jpg').writeAsString('Image 1');
      await File('$testDirPath/photo2.jpg').writeAsString('Image 2');
      await File('$testDirPath/document.txt').writeAsString('Text');

      // List only JPG files
      await NativeWorkManager.enqueue(
        taskId: 'test-list-pattern',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileList(
          path: testDirPath,
          pattern: '*.jpg',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Should list only 2 JPG files
    });

    test('list recursively', () async {
      // Create nested structure
      await File('$testDirPath/root.txt').writeAsString('Root');

      final subDir = Directory('$testDirPath/subdir');
      await subDir.create();
      await File('${subDir.path}/sub.txt').writeAsString('Sub');

      final deepDir = Directory('${subDir.path}/deep');
      await deepDir.create();
      await File('${deepDir.path}/deep.txt').writeAsString('Deep');

      // List recursively
      await NativeWorkManager.enqueue(
        taskId: 'test-list-recursive',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileList(
          path: testDirPath,
          recursive: true,
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Should list all 3 files
    });
  });

  group('Mkdir Operations', () {
    test('create single directory', () async {
      final newDir = Directory('$testDirPath/new_directory');

      // Create directory
      await NativeWorkManager.enqueue(
        taskId: 'test-mkdir',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileMkdir(
          path: newDir.path,
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Verify created
      expect(await newDir.exists(), true);
    });

    test('create nested directories', () async {
      final deepDir = Directory('$testDirPath/level1/level2/level3');

      // Create with parents
      await NativeWorkManager.enqueue(
        taskId: 'test-mkdir-nested',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileMkdir(
          path: deepDir.path,
          createParents: true,
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Verify all levels created
      expect(await deepDir.exists(), true);
      expect(await Directory('$testDirPath/level1').exists(), true);
      expect(await Directory('$testDirPath/level1/level2').exists(), true);
    });
  });

  group('Complete Workflows', () {
    test('workflow: mkdir → copy → list → move → delete', () async {
      // Step 1: Create directory
      await NativeWorkManager.enqueue(
        taskId: 'workflow-mkdir',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileMkdir(
          path: '$testDirPath/workflow',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Step 2: Create source file and copy
      final sourceFile = File('$testDirPath/source.txt');
      await sourceFile.writeAsString('Workflow test');

      await NativeWorkManager.enqueue(
        taskId: 'workflow-copy',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: sourceFile.path,
          destinationPath: '$testDirPath/workflow/file.txt',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Step 3: List files
      await NativeWorkManager.enqueue(
        taskId: 'workflow-list',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileList(
          path: '$testDirPath/workflow',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Step 4: Move file
      await NativeWorkManager.enqueue(
        taskId: 'workflow-move',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileMove(
          sourcePath: '$testDirPath/workflow/file.txt',
          destinationPath: '$testDirPath/workflow/moved_file.txt',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Step 5: Delete directory
      await NativeWorkManager.enqueue(
        taskId: 'workflow-delete',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileDelete(
          path: '$testDirPath/workflow',
          recursive: true,
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Verify final state
      expect(await Directory('$testDirPath/workflow').exists(), false);
    });

    test('workflow: create backup structure', () async {
      // Create source files
      await File('$testDirPath/doc1.txt').writeAsString('Document 1');
      await File('$testDirPath/doc2.txt').writeAsString('Document 2');

      // Create backup directory
      await NativeWorkManager.enqueue(
        taskId: 'backup-mkdir',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileMkdir(
          path: '$testDirPath/backup/${DateTime.now().toIso8601String().split('T')[0]}',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      final backupDate = DateTime.now().toIso8601String().split('T')[0];

      // Copy files to backup
      await NativeWorkManager.enqueue(
        taskId: 'backup-copy-1',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: '$testDirPath/doc1.txt',
          destinationPath: '$testDirPath/backup/$backupDate/doc1.txt',
        ),
      );

      await NativeWorkManager.enqueue(
        taskId: 'backup-copy-2',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: '$testDirPath/doc2.txt',
          destinationPath: '$testDirPath/backup/$backupDate/doc2.txt',
        ),
      );

      await Future.delayed(const Duration(seconds: 3));

      // Verify backup created
      expect(await File('$testDirPath/backup/$backupDate/doc1.txt').exists(), true);
      expect(await File('$testDirPath/backup/$backupDate/doc2.txt').exists(), true);
    });
  });

  group('Error Handling', () {
    test('copy non-existent source fails gracefully', () async {
      // Attempt to copy non-existent file
      await NativeWorkManager.enqueue(
        taskId: 'test-error-copy',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: '$testDirPath/non_existent.txt',
          destinationPath: '$testDirPath/dest.txt',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Should fail without crashing
      // (Verify via event listener in real test)
    });

    test('delete non-existent file fails gracefully', () async {
      // Attempt to delete non-existent file
      await NativeWorkManager.enqueue(
        taskId: 'test-error-delete',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileDelete(
          path: '$testDirPath/non_existent.txt',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Should fail without crashing
    });

    test('list non-existent directory fails gracefully', () async {
      // Attempt to list non-existent directory
      await NativeWorkManager.enqueue(
        taskId: 'test-error-list',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileList(
          path: '$testDirPath/non_existent_dir',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Should fail without crashing
    });
  });

  group('Performance Tests', () {
    test('copy large file (10MB)', () async {
      // Create large file
      final largeFile = File('$testDirPath/large_file.bin');
      final data = List.generate(10 * 1024 * 1024, (i) => i % 256);
      await largeFile.writeAsBytes(data);

      final stopwatch = Stopwatch()..start();

      // Copy large file
      await NativeWorkManager.enqueue(
        taskId: 'test-perf-copy-large',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: largeFile.path,
          destinationPath: '$testDirPath/large_file_copy.bin',
        ),
      );

      await Future.delayed(const Duration(seconds: 5));

      stopwatch.stop();

      developer.log('Large file copy time: ${stopwatch.elapsedMilliseconds}ms');

      // Verify copied
      expect(await File('$testDirPath/large_file_copy.bin').exists(), true);
    });

    test('copy many small files (100 files)', () async {
      // Create many small files
      for (int i = 0; i < 100; i++) {
        await File('$testDirPath/small_$i.txt').writeAsString('Content $i');
      }

      final stopwatch = Stopwatch()..start();

      // Copy directory with many files
      await NativeWorkManager.enqueue(
        taskId: 'test-perf-copy-many',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: testDirPath,
          destinationPath: '$testDirPath/../many_files_copy',
          recursive: true,
        ),
      );

      await Future.delayed(const Duration(seconds: 5));

      stopwatch.stop();

      developer.log('Many files copy time: ${stopwatch.elapsedMilliseconds}ms');
    });
  });
}
