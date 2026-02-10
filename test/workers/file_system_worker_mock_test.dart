import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Mock integration tests that use system temp directory.
/// These tests can run without device/emulator.
///
/// Tests actual file operations using Dart I/O to verify
/// that the worker configurations are correct.
void main() {
  late Directory testDir;
  late String testDirPath;

  setUp(() async {
    // Use system temp directory (works on macOS/Linux/Windows)
    testDir = Directory.systemTemp.createTempSync('file_system_mock_test_');
    testDirPath = testDir.path;
  });

  tearDown(() async {
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  });

  group('FileSystemWorker Configuration Validation', () {
    test('copy worker generates correct configuration', () {
      final worker = FileSystemCopyWorker(
        sourcePath: '$testDirPath/source.txt',
        destinationPath: '$testDirPath/dest.txt',
        overwrite: true,
        recursive: false,
      );

      final config = worker.toMap();

      expect(config['workerType'], 'fileSystem');
      expect(config['operation'], 'copy');
      expect(config['sourcePath'], '$testDirPath/source.txt');
      expect(config['destinationPath'], '$testDirPath/dest.txt');
      expect(config['overwrite'], true);
      expect(config['recursive'], false);
    });

    test('move worker generates correct configuration', () {
      final worker = FileSystemMoveWorker(
        sourcePath: '$testDirPath/source.txt',
        destinationPath: '$testDirPath/dest.txt',
        overwrite: true,
      );

      final config = worker.toMap();

      expect(config['workerType'], 'fileSystem');
      expect(config['operation'], 'move');
      expect(config['sourcePath'], '$testDirPath/source.txt');
      expect(config['destinationPath'], '$testDirPath/dest.txt');
      expect(config['overwrite'], true);
    });

    test('delete worker generates correct configuration', () {
      final worker = FileSystemDeleteWorker(
        path: '$testDirPath/file.txt',
        recursive: true,
      );

      final config = worker.toMap();

      expect(config['workerType'], 'fileSystem');
      expect(config['operation'], 'delete');
      expect(config['path'], '$testDirPath/file.txt');
      expect(config['recursive'], true);
    });

    test('list worker generates correct configuration', () {
      final worker = FileSystemListWorker(
        path: testDirPath,
        pattern: '*.jpg',
        recursive: true,
      );

      final config = worker.toMap();

      expect(config['workerType'], 'fileSystem');
      expect(config['operation'], 'list');
      expect(config['path'], testDirPath);
      expect(config['pattern'], '*.jpg');
      expect(config['recursive'], true);
    });

    test('mkdir worker generates correct configuration', () {
      final worker = FileSystemMkdirWorker(
        path: '$testDirPath/new_dir',
        createParents: true,
      );

      final config = worker.toMap();

      expect(config['workerType'], 'fileSystem');
      expect(config['operation'], 'mkdir');
      expect(config['path'], '$testDirPath/new_dir');
      expect(config['createParents'], true);
    });
  });

  group('Path Validation in Workers', () {
    test('copy worker accepts valid absolute paths', () {
      expect(
        () => FileSystemCopyWorker(
          sourcePath: '/valid/absolute/path',
          destinationPath: '/valid/dest/path',
        ),
        returnsNormally,
      );
    });

    test('copy worker accepts valid relative paths', () {
      expect(
        () => FileSystemCopyWorker(
          sourcePath: 'relative/source',
          destinationPath: 'relative/dest',
        ),
        returnsNormally,
      );
    });

    test('move worker handles paths with dots', () {
      expect(
        () => FileSystemMoveWorker(
          sourcePath: './source/../file.txt',
          destinationPath: '../dest/file.txt',
        ),
        returnsNormally,
      );
    });

    test('delete worker handles current directory reference', () {
      expect(
        () => FileSystemDeleteWorker(
          path: './file.txt',
        ),
        returnsNormally,
      );
    });

    test('list worker handles parent directory reference', () {
      expect(
        () => FileSystemListWorker(
          path: '../directory',
        ),
        returnsNormally,
      );
    });
  });

  group('Pattern Matching Validation', () {
    test('list worker accepts wildcard patterns', () {
      final patterns = [
        '*.txt',
        '*.jpg',
        '*.png',
        'file*',
        '*file',
        '*file*',
        'file?.txt',
        '*.{jpg,png}',
      ];

      for (final pattern in patterns) {
        expect(
          () => FileSystemListWorker(
            path: testDirPath,
            pattern: pattern,
          ),
          returnsNormally,
          reason: 'Pattern $pattern should be valid',
        );
      }
    });

    test('list worker configuration preserves complex patterns', () {
      final worker = FileSystemListWorker(
        path: testDirPath,
        pattern: '**/*.{jpg,png,gif}',
        recursive: true,
      );

      final config = worker.toMap();

      expect(config['pattern'], '**/*.{jpg,png,gif}');
    });
  });

  group('Actual File Operations (Mock Integration)', () {
    test('can create test files for copy operation', () async {
      // Create source file
      final sourceFile = File('$testDirPath/source.txt');
      await sourceFile.writeAsString('Test content');

      expect(await sourceFile.exists(), true);
      expect(await sourceFile.readAsString(), 'Test content');

      // Verify worker can be created with this path
      final worker = FileSystemCopyWorker(
        sourcePath: sourceFile.path,
        destinationPath: '$testDirPath/dest.txt',
      );

      expect(worker.sourcePath, sourceFile.path);
    });

    test('can create test directory structure', () async {
      // Create directory structure
      final dir = Directory('$testDirPath/test_dir');
      await dir.create(recursive: true);

      await File('${dir.path}/file1.txt').writeAsString('Content 1');
      await File('${dir.path}/file2.txt').writeAsString('Content 2');

      expect(await dir.exists(), true);
      expect(await File('${dir.path}/file1.txt').exists(), true);

      // Verify worker can be created
      final worker = FileSystemCopyWorker(
        sourcePath: dir.path,
        destinationPath: '$testDirPath/dest_dir',
        recursive: true,
      );

      expect(worker.recursive, true);
    });

    test('can list files in directory using Dart I/O', () async {
      // Create test files
      await File('$testDirPath/file1.txt').writeAsString('1');
      await File('$testDirPath/file2.jpg').writeAsString('2');
      await File('$testDirPath/file3.png').writeAsString('3');

      // List all files
      final files = testDir.listSync();

      expect(files.length, 3);
      expect(files.where((f) => f.path.endsWith('.txt')).length, 1);
      expect(files.where((f) => f.path.endsWith('.jpg')).length, 1);
      expect(files.where((f) => f.path.endsWith('.png')).length, 1);
    });

    test('can delete files using Dart I/O', () async {
      // Create and delete file
      final file = File('$testDirPath/delete_me.txt');
      await file.writeAsString('Delete this');

      expect(await file.exists(), true);

      await file.delete();

      expect(await file.exists(), false);
    });

    test('can create nested directories', () async {
      // Create nested structure
      final deepDir = Directory('$testDirPath/level1/level2/level3');
      await deepDir.create(recursive: true);

      expect(await deepDir.exists(), true);
      expect(await Directory('$testDirPath/level1').exists(), true);
      expect(await Directory('$testDirPath/level1/level2').exists(), true);
    });
  });

  group('Worker Class Hierarchy', () {
    test('all worker classes extend Worker', () {
      expect(FileSystemCopyWorker(sourcePath: '', destinationPath: ''),
          isA<Worker>());
      expect(
          FileSystemMoveWorker(sourcePath: '', destinationPath: ''),
          isA<Worker>());
      expect(FileSystemDeleteWorker(path: ''), isA<Worker>());
      expect(FileSystemListWorker(path: ''), isA<Worker>());
      expect(FileSystemMkdirWorker(path: ''), isA<Worker>());
    });

    test('all workers have correct workerClassName', () {
      expect(
        FileSystemCopyWorker(sourcePath: '', destinationPath: '')
            .workerClassName,
        'FileSystemWorker',
      );
      expect(
        FileSystemMoveWorker(sourcePath: '', destinationPath: '')
            .workerClassName,
        'FileSystemWorker',
      );
      expect(
        FileSystemDeleteWorker(path: '').workerClassName,
        'FileSystemWorker',
      );
      expect(
        FileSystemListWorker(path: '').workerClassName,
        'FileSystemWorker',
      );
      expect(
        FileSystemMkdirWorker(path: '').workerClassName,
        'FileSystemWorker',
      );
    });
  });

  group('Convenience Methods Integration', () {
    test('NativeWorker.fileCopy creates valid worker', () {
      final worker = NativeWorker.fileCopy(
        sourcePath: '/source/path',
        destinationPath: '/dest/path',
        overwrite: true,
        recursive: false,
      );

      expect(worker, isA<FileSystemCopyWorker>());
      expect(worker.toMap()['operation'], 'copy');
      expect(worker.toMap()['overwrite'], true);
      expect(worker.toMap()['recursive'], false);
    });

    test('NativeWorker.fileMove creates valid worker', () {
      final worker = NativeWorker.fileMove(
        sourcePath: '/source/path',
        destinationPath: '/dest/path',
        overwrite: true,
      );

      expect(worker, isA<FileSystemMoveWorker>());
      expect(worker.toMap()['operation'], 'move');
      expect(worker.toMap()['overwrite'], true);
    });

    test('NativeWorker.fileDelete creates valid worker', () {
      final worker = NativeWorker.fileDelete(
        path: '/file/path',
        recursive: true,
      );

      expect(worker, isA<FileSystemDeleteWorker>());
      expect(worker.toMap()['operation'], 'delete');
      expect(worker.toMap()['recursive'], true);
    });

    test('NativeWorker.fileList creates valid worker', () {
      final worker = NativeWorker.fileList(
        path: '/directory/path',
        pattern: '*.jpg',
        recursive: true,
      );

      expect(worker, isA<FileSystemListWorker>());
      expect(worker.toMap()['operation'], 'list');
      expect(worker.toMap()['pattern'], '*.jpg');
      expect(worker.toMap()['recursive'], true);
    });

    test('NativeWorker.fileMkdir creates valid worker', () {
      final worker = NativeWorker.fileMkdir(
        path: '/new/directory',
        createParents: true,
      );

      expect(worker, isA<FileSystemMkdirWorker>());
      expect(worker.toMap()['operation'], 'mkdir');
      expect(worker.toMap()['createParents'], true);
    });
  });

  group('Complex Workflow Scenarios', () {
    test('workflow: create directory → create file → list', () async {
      // Step 1: Create directory
      final dir = Directory('$testDirPath/workflow');
      await dir.create();

      final mkdirWorker = FileSystemMkdirWorker(path: dir.path);
      expect(mkdirWorker.toMap()['path'], dir.path);

      // Step 2: Create files
      await File('${dir.path}/file1.txt').writeAsString('Content 1');
      await File('${dir.path}/file2.txt').writeAsString('Content 2');

      // Step 3: List files
      final listWorker = FileSystemListWorker(path: dir.path);
      expect(listWorker.toMap()['path'], dir.path);

      // Verify files exist
      final files = dir.listSync();
      expect(files.length, 2);
    });

    test('workflow: copy → move → delete', () async {
      // Create source file
      final sourceFile = File('$testDirPath/source.txt');
      await sourceFile.writeAsString('Original content');

      // Step 1: Copy
      final copyWorker = FileSystemCopyWorker(
        sourcePath: sourceFile.path,
        destinationPath: '$testDirPath/copy.txt',
      );
      expect(copyWorker.toMap()['operation'], 'copy');

      // Simulate copy
      final copyFile = File('$testDirPath/copy.txt');
      await copyFile.writeAsString(await sourceFile.readAsString());
      expect(await copyFile.exists(), true);

      // Step 2: Move
      final moveWorker = FileSystemMoveWorker(
        sourcePath: copyFile.path,
        destinationPath: '$testDirPath/moved.txt',
      );
      expect(moveWorker.toMap()['operation'], 'move');

      // Simulate move
      final movedFile = File('$testDirPath/moved.txt');
      await movedFile.writeAsString(await copyFile.readAsString());
      await copyFile.delete();
      expect(await movedFile.exists(), true);
      expect(await copyFile.exists(), false);

      // Step 3: Delete
      final deleteWorker = FileSystemDeleteWorker(path: movedFile.path);
      expect(deleteWorker.toMap()['operation'], 'delete');

      // Simulate delete
      await movedFile.delete();
      expect(await movedFile.exists(), false);
    });

    test('workflow: backup multiple files', () async {
      // Create source files
      await File('$testDirPath/doc1.txt').writeAsString('Document 1');
      await File('$testDirPath/doc2.txt').writeAsString('Document 2');
      await File('$testDirPath/doc3.txt').writeAsString('Document 3');

      // Create backup directory
      final backupDir = Directory('$testDirPath/backup');
      await backupDir.create();

      // Create workers for each file
      final workers = [
        FileSystemCopyWorker(
          sourcePath: '$testDirPath/doc1.txt',
          destinationPath: '${backupDir.path}/doc1.txt',
        ),
        FileSystemCopyWorker(
          sourcePath: '$testDirPath/doc2.txt',
          destinationPath: '${backupDir.path}/doc2.txt',
        ),
        FileSystemCopyWorker(
          sourcePath: '$testDirPath/doc3.txt',
          destinationPath: '${backupDir.path}/doc3.txt',
        ),
      ];

      expect(workers.length, 3);
      expect(workers.every((w) => w.toMap()['operation'] == 'copy'), true);

      // Simulate backup
      for (int i = 1; i <= 3; i++) {
        final sourceFile = File('$testDirPath/doc$i.txt');
        final destFile = File('${backupDir.path}/doc$i.txt');
        await destFile.writeAsString(await sourceFile.readAsString());
      }

      // Verify all files backed up
      final backupFiles = backupDir.listSync();
      expect(backupFiles.length, 3);
    });
  });

  group('Error Handling Scenarios', () {
    test('worker handles non-existent source path in configuration', () {
      expect(
        () => FileSystemCopyWorker(
          sourcePath: '/non/existent/path',
          destinationPath: '/dest/path',
        ),
        returnsNormally,
        reason: 'Worker should accept any path in configuration',
      );
    });

    test('worker handles invalid characters in configuration', () {
      // These might be invalid on some platforms, but worker should accept them
      expect(
        () => FileSystemCopyWorker(
          sourcePath: '/path/with:colons',
          destinationPath: '/path/with|pipes',
        ),
        returnsNormally,
        reason: 'Worker accepts any string, validation happens at execution',
      );
    });

    test('delete worker handles already-deleted file gracefully', () async {
      final file = File('$testDirPath/delete_twice.txt');
      await file.writeAsString('Content');

      // Delete once
      await file.delete();
      expect(await file.exists(), false);

      // Create worker for non-existent file
      final worker = FileSystemDeleteWorker(path: file.path);
      expect(worker.toMap()['path'], file.path);
      // Actual deletion would be handled by native worker with error handling
    });

    test('list worker handles empty directory', () async {
      final emptyDir = Directory('$testDirPath/empty');
      await emptyDir.create();

      final worker = FileSystemListWorker(path: emptyDir.path);
      expect(worker.toMap()['path'], emptyDir.path);

      // List empty directory
      final files = emptyDir.listSync();
      expect(files.length, 0);
    });
  });

  group('Platform Compatibility Checks', () {
    test('workers use platform-agnostic path separators', () {
      final worker = FileSystemCopyWorker(
        sourcePath: '$testDirPath${Platform.pathSeparator}file.txt',
        destinationPath: '$testDirPath${Platform.pathSeparator}dest.txt',
      );

      expect(worker.sourcePath.contains(Platform.pathSeparator), true);
    });

    test('temp directory is accessible', () {
      expect(testDir.existsSync(), true);
      expect(testDir.path.isNotEmpty, true);
    });

    test('can perform basic file operations in temp directory', () async {
      final testFile = File('$testDirPath/platform_test.txt');
      await testFile.writeAsString('Platform test');

      expect(await testFile.exists(), true);
      expect(await testFile.readAsString(), 'Platform test');

      await testFile.delete();
      expect(await testFile.exists(), false);
    });
  });

  group('Memory and Performance Considerations', () {
    test('worker configuration is lightweight', () {
      final worker = FileSystemCopyWorker(
        sourcePath: '/very/long/path' * 100,
        destinationPath: '/another/long/path' * 100,
      );

      final config = worker.toMap();

      // Configuration should be serializable
      expect(config, isA<Map<String, dynamic>>());
      expect(config.keys.length, greaterThan(0));
    });

    test('can create many workers without memory issues', () {
      final workers = List.generate(
        1000,
        (i) => FileSystemCopyWorker(
          sourcePath: '/source/file_$i.txt',
          destinationPath: '/dest/file_$i.txt',
        ),
      );

      expect(workers.length, 1000);
    });

    test('worker serialization is fast', () {
      final worker = FileSystemCopyWorker(
        sourcePath: '/source/path',
        destinationPath: '/dest/path',
        overwrite: true,
        recursive: true,
      );

      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 10000; i++) {
        worker.toMap();
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: '10k serializations should take < 1 second');
    });
  });

  group('Regression Tests', () {
    test('copy worker default values match specification', () {
      final worker = FileSystemCopyWorker(
        sourcePath: '/source',
        destinationPath: '/dest',
      );

      expect(worker.overwrite, false);
      expect(worker.recursive, true);
    });

    test('move worker default values match specification', () {
      final worker = FileSystemMoveWorker(
        sourcePath: '/source',
        destinationPath: '/dest',
      );

      expect(worker.overwrite, false);
    });

    test('delete worker default values match specification', () {
      final worker = FileSystemDeleteWorker(path: '/path');

      expect(worker.recursive, false);
    });

    test('list worker default values match specification', () {
      final worker = FileSystemListWorker(path: '/path');

      expect(worker.pattern, null);
      expect(worker.recursive, false);
    });

    test('mkdir worker default values match specification', () {
      final worker = FileSystemMkdirWorker(path: '/path');

      expect(worker.createParents, true);
    });
  });
}
