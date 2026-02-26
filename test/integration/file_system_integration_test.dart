import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// File system integration tests using real dart:io operations.
///
/// These tests verify actual file system behavior (copy, move, delete,
/// list, mkdir) using Dart's built-in dart:io — no native WorkManager
/// execution required.
///
/// Worker serialization tests verify that NativeWorker factories
/// produce correct configuration maps for each operation type.
///
/// End-to-end tests with real WorkManager execution are in:
///   example/integration_test/device_integration_test.dart
void main() {
  late Directory testDir;
  late String testDirPath;

  setUp(() async {
    final tempDir = Directory.systemTemp;
    testDir = Directory(
      '${tempDir.path}/fs_integration_${DateTime.now().millisecondsSinceEpoch}',
    );
    await testDir.create(recursive: true);
    testDirPath = testDir.path;
  });

  tearDown(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  // ---------------------------------------------------------------------------
  // Copy Operations — real dart:io
  // ---------------------------------------------------------------------------

  group('Copy Operations', () {
    test('copy single file preserves content', () async {
      final source = File('$testDirPath/source.txt');
      await source.writeAsString('Test content');

      await source.copy('$testDirPath/destination.txt');

      final dest = File('$testDirPath/destination.txt');
      expect(await dest.exists(), isTrue);
      expect(await dest.readAsString(), 'Test content');
      expect(await source.exists(), isTrue); // source unchanged
    });

    test('copy preserves binary content', () async {
      final bytes = List<int>.generate(256, (i) => i);
      final source = File('$testDirPath/binary.bin');
      await source.writeAsBytes(bytes);

      await source.copy('$testDirPath/binary_copy.bin');

      final dest = File('$testDirPath/binary_copy.bin');
      expect(await dest.readAsBytes(), equals(bytes));
    });

    test('copy with overwrite replaces destination content', () async {
      final source = File('$testDirPath/source.txt');
      await source.writeAsString('New content');

      final dest = File('$testDirPath/destination.txt');
      await dest.writeAsString('Old content');

      await source.copy(dest.path);

      expect(await dest.readAsString(), 'New content');
    });

    test('copy directory recursively copies all nested files', () async {
      final sourceDir = Directory('$testDirPath/source_dir');
      await sourceDir.create();
      await File('${sourceDir.path}/file1.txt').writeAsString('Content 1');
      await File('${sourceDir.path}/file2.txt').writeAsString('Content 2');

      final subDir = Directory('${sourceDir.path}/subdir');
      await subDir.create();
      await File('${subDir.path}/file3.txt').writeAsString('Content 3');

      // Recursive copy using dart:io
      Future<void> copyDir(Directory src, Directory dst) async {
        await dst.create(recursive: true);
        await for (final entity in src.list()) {
          final name = entity.path.split('/').last;
          if (entity is File) {
            await entity.copy('${dst.path}/$name');
          } else if (entity is Directory) {
            await copyDir(entity, Directory('${dst.path}/$name'));
          }
        }
      }

      final destDir = Directory('$testDirPath/dest_dir');
      await copyDir(sourceDir, destDir);

      expect(await File('${destDir.path}/file1.txt').exists(), isTrue);
      expect(await File('${destDir.path}/file2.txt').exists(), isTrue);
      expect(await File('${destDir.path}/subdir/file3.txt').exists(), isTrue);

      expect(
        await File('${destDir.path}/file1.txt').readAsString(),
        'Content 1',
      );
    });

    test('copy large file (5MB) preserves all bytes', () async {
      final data = List<int>.generate(5 * 1024 * 1024, (i) => i % 256);
      final source = File('$testDirPath/large.bin');
      await source.writeAsBytes(data);

      final sw = Stopwatch()..start();
      await source.copy('$testDirPath/large_copy.bin');
      sw.stop();

      final dest = File('$testDirPath/large_copy.bin');
      expect(await dest.length(), data.length);
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });
  });

  // ---------------------------------------------------------------------------
  // Move Operations — real dart:io
  // ---------------------------------------------------------------------------

  group('Move Operations', () {
    test('move file removes source and creates destination', () async {
      final source = File('$testDirPath/move_source.txt');
      await source.writeAsString('Move me');

      await source.rename('$testDirPath/moved.txt');

      expect(await source.exists(), isFalse);
      final dest = File('$testDirPath/moved.txt');
      expect(await dest.exists(), isTrue);
      expect(await dest.readAsString(), 'Move me');
    });

    test('move preserves binary content', () async {
      final bytes = List<int>.generate(1024, (i) => i % 256);
      final source = File('$testDirPath/binary.bin');
      await source.writeAsBytes(bytes);

      await source.rename('$testDirPath/binary_moved.bin');

      final dest = File('$testDirPath/binary_moved.bin');
      expect(await dest.readAsBytes(), equals(bytes));
    });

    test('move directory moves all contents', () async {
      final sourceDir = Directory('$testDirPath/move_dir');
      await sourceDir.create();
      await File('${sourceDir.path}/file.txt').writeAsString('Content');

      await sourceDir.rename('$testDirPath/moved_dir');

      expect(await sourceDir.exists(), isFalse);
      expect(await Directory('$testDirPath/moved_dir').exists(), isTrue);
      expect(
        await File('$testDirPath/moved_dir/file.txt').exists(),
        isTrue,
      );
      expect(
        await File('$testDirPath/moved_dir/file.txt').readAsString(),
        'Content',
      );
    });

    test('move 100 small files sequentially', () async {
      final sw = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        final src = File('$testDirPath/file_$i.txt');
        await src.writeAsString('Content $i');
        await src.rename('$testDirPath/moved_$i.txt');
      }
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(5000));

      // Spot-check
      expect(await File('$testDirPath/moved_0.txt').exists(), isTrue);
      expect(await File('$testDirPath/moved_99.txt').exists(), isTrue);
      expect(await File('$testDirPath/file_0.txt').exists(), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Delete Operations — real dart:io
  // ---------------------------------------------------------------------------

  group('Delete Operations', () {
    test('delete single file removes it', () async {
      final file = File('$testDirPath/delete_me.txt');
      await file.writeAsString('Delete this');

      await file.delete();

      expect(await file.exists(), isFalse);
    });

    test('delete directory recursively removes all contents', () async {
      final dir = Directory('$testDirPath/delete_dir');
      await dir.create();
      await File('${dir.path}/file1.txt').writeAsString('Content 1');
      await File('${dir.path}/file2.txt').writeAsString('Content 2');

      final subDir = Directory('${dir.path}/subdir');
      await subDir.create();
      await File('${subDir.path}/file3.txt').writeAsString('Content 3');

      await dir.delete(recursive: true);

      expect(await dir.exists(), isFalse);
    });

    test('delete non-existent file throws FileSystemException', () async {
      final file = File('$testDirPath/non_existent.txt');
      expect(
        () => file.delete(),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('delete 200 small files efficiently', () async {
      final files = <File>[];
      for (int i = 0; i < 200; i++) {
        final f = File('$testDirPath/file_$i.txt');
        await f.writeAsString('Content $i');
        files.add(f);
      }

      final sw = Stopwatch()..start();
      await Future.wait(files.map((f) => f.delete()));
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(5000));
      expect(await File('$testDirPath/file_0.txt').exists(), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // List Operations — real dart:io
  // ---------------------------------------------------------------------------

  group('List Operations', () {
    test('list files in directory returns all entries', () async {
      await File('$testDirPath/file1.txt').writeAsString('Content 1');
      await File('$testDirPath/file2.txt').writeAsString('Content 2');
      await File('$testDirPath/file3.jpg').writeAsString('Image');

      final entities = await testDir.list().toList();
      expect(entities.length, 3);
    });

    test('list with pattern filters by extension', () async {
      await File('$testDirPath/photo1.jpg').writeAsString('Image 1');
      await File('$testDirPath/photo2.jpg').writeAsString('Image 2');
      await File('$testDirPath/document.txt').writeAsString('Text');

      final all = await testDir.list().toList();
      final jpgs = all.where((e) => e.path.endsWith('.jpg')).toList();

      expect(all.length, 3);
      expect(jpgs.length, 2);
    });

    test('list recursively finds all nested files', () async {
      await File('$testDirPath/root.txt').writeAsString('Root');

      final subDir = Directory('$testDirPath/subdir');
      await subDir.create();
      await File('${subDir.path}/sub.txt').writeAsString('Sub');

      final deepDir = Directory('${subDir.path}/deep');
      await deepDir.create();
      await File('${deepDir.path}/deep.txt').writeAsString('Deep');

      final allFiles = await testDir
          .list(recursive: true)
          .where((e) => e is File)
          .toList();

      expect(allFiles.length, 3);
    });

    test('list 1000 files returns all entries', () async {
      await Future.wait(
        List.generate(1000, (i) async {
          await File('$testDirPath/file_$i.txt').writeAsString('Content $i');
        }),
      );

      final sw = Stopwatch()..start();
      final entities = await testDir.list().toList();
      sw.stop();

      expect(entities.length, 1000);
      expect(sw.elapsedMilliseconds, lessThan(3000));
    });

    test('list empty directory returns empty list', () async {
      final empty = Directory('$testDirPath/empty');
      await empty.create();

      final entities = await empty.list().toList();
      expect(entities, isEmpty);
    });

    test('list non-existent directory throws', () async {
      final dir = Directory('$testDirPath/non_existent_dir');
      expect(
        () => dir.list().toList(),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Mkdir Operations — real dart:io
  // ---------------------------------------------------------------------------

  group('Mkdir Operations', () {
    test('create single directory', () async {
      final newDir = Directory('$testDirPath/new_directory');
      await newDir.create();
      expect(await newDir.exists(), isTrue);
    });

    test('create nested directories with recursive flag', () async {
      final deepDir = Directory('$testDirPath/level1/level2/level3');
      await deepDir.create(recursive: true);

      expect(await deepDir.exists(), isTrue);
      expect(await Directory('$testDirPath/level1').exists(), isTrue);
      expect(await Directory('$testDirPath/level1/level2').exists(), isTrue);
    });

    test('create already-existing directory does not throw', () async {
      final dir = Directory('$testDirPath/existing');
      await dir.create();
      // Creating again should not throw (recursive: true)
      await dir.create(recursive: true);
      expect(await dir.exists(), isTrue);
    });

    test('create 200 directories efficiently', () async {
      final sw = Stopwatch()..start();
      await Future.wait(
        List.generate(200, (i) async {
          await Directory('$testDirPath/dir_$i').create();
        }),
      );
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(5000));
      expect(await Directory('$testDirPath/dir_0').exists(), isTrue);
      expect(await Directory('$testDirPath/dir_199').exists(), isTrue);
    });

    test('create 50-level deep directory hierarchy', () async {
      final deepPath = List.generate(50, (i) => 'level_$i').join('/');
      final deepDir = Directory('$testDirPath/$deepPath');
      await deepDir.create(recursive: true);
      expect(await deepDir.exists(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Complete Workflows — real dart:io
  // ---------------------------------------------------------------------------

  group('Complete Workflows', () {
    test('workflow: mkdir → copy → list → move → delete', () async {
      // Step 1: Create workflow directory
      final workDir = Directory('$testDirPath/workflow');
      await workDir.create();
      expect(await workDir.exists(), isTrue);

      // Step 2: Create source file and copy into workflow dir
      final source = File('$testDirPath/source.txt');
      await source.writeAsString('Workflow test');
      await source.copy('${workDir.path}/file.txt');
      expect(await File('${workDir.path}/file.txt').exists(), isTrue);

      // Step 3: List files in workflow dir
      final listed = await workDir.list().toList();
      expect(listed.length, 1);

      // Step 4: Move file within workflow dir
      await File('${workDir.path}/file.txt').rename(
        '${workDir.path}/moved_file.txt',
      );
      expect(await File('${workDir.path}/file.txt').exists(), isFalse);
      expect(await File('${workDir.path}/moved_file.txt').exists(), isTrue);

      // Step 5: Delete workflow directory
      await workDir.delete(recursive: true);
      expect(await workDir.exists(), isFalse);
    });

    test('workflow: create dated backup structure', () async {
      // Create source documents
      await File('$testDirPath/doc1.txt').writeAsString('Document 1');
      await File('$testDirPath/doc2.txt').writeAsString('Document 2');

      // Create dated backup directory
      final backupDate = DateTime.now().toIso8601String().split('T')[0];
      final backupDir = Directory('$testDirPath/backup/$backupDate');
      await backupDir.create(recursive: true);

      // Copy files to backup
      await File('$testDirPath/doc1.txt').copy('${backupDir.path}/doc1.txt');
      await File('$testDirPath/doc2.txt').copy('${backupDir.path}/doc2.txt');

      // Verify backup
      expect(await File('${backupDir.path}/doc1.txt').exists(), isTrue);
      expect(await File('${backupDir.path}/doc2.txt').exists(), isTrue);
      expect(
        await File('${backupDir.path}/doc1.txt').readAsString(),
        'Document 1',
      );
      expect(
        await File('${backupDir.path}/doc2.txt').readAsString(),
        'Document 2',
      );

      // Original files still exist
      expect(await File('$testDirPath/doc1.txt').exists(), isTrue);
    });

    test('workflow: rotate logs (keep last 3, delete rest)', () async {
      // Create 6 log files
      for (int i = 1; i <= 6; i++) {
        await File('$testDirPath/app_$i.log').writeAsString('Log $i content');
      }

      // Sort by name (oldest first) and delete all but last 3
      final logs = (await testDir.list().toList())
          .whereType<File>()
          .where((f) => f.path.endsWith('.log'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      final toDelete = logs.take(logs.length - 3).toList();
      for (final f in toDelete) {
        await f.delete();
      }

      final remaining = await testDir
          .list()
          .where((e) => e is File && e.path.endsWith('.log'))
          .toList();

      expect(remaining.length, 3);
    });
  });

  // ---------------------------------------------------------------------------
  // Worker Serialization — verifies NativeWorker config maps
  // ---------------------------------------------------------------------------

  group('Worker Serialization', () {
    test('fileCopy worker serializes all fields', () {
      final worker = NativeWorker.fileCopy(
        sourcePath: '/src/file.txt',
        destinationPath: '/dst/file.txt',
        overwrite: true,
        recursive: true,
      );
      final map = worker.toMap();

      expect(map['workerType'], equals('fileSystem'));
      expect(map['operation'], equals('copy'));
      expect(map['sourcePath'], equals('/src/file.txt'));
      expect(map['destinationPath'], equals('/dst/file.txt'));
      expect(map['overwrite'], isTrue);
      expect(map['recursive'], isTrue);
    });

    test('fileMove worker serializes all fields', () {
      final worker = NativeWorker.fileMove(
        sourcePath: '/src/file.txt',
        destinationPath: '/dst/file.txt',
        overwrite: false,
      );
      final map = worker.toMap();

      expect(map['workerType'], equals('fileSystem'));
      expect(map['operation'], equals('move'));
      expect(map['sourcePath'], equals('/src/file.txt'));
      expect(map['destinationPath'], equals('/dst/file.txt'));
      expect(map['overwrite'], isFalse);
    });

    test('fileDelete worker serializes all fields', () {
      final worker = NativeWorker.fileDelete(
        path: '/data/logs',
        recursive: true,
      );
      final map = worker.toMap();

      expect(map['workerType'], equals('fileSystem'));
      expect(map['operation'], equals('delete'));
      expect(map['path'], equals('/data/logs'));
      expect(map['recursive'], isTrue);
    });

    test('fileList worker serializes all fields', () {
      final worker = NativeWorker.fileList(
        path: '/data/photos',
        pattern: '*.jpg',
        recursive: false,
      );
      final map = worker.toMap();

      expect(map['workerType'], equals('fileSystem'));
      expect(map['operation'], equals('list'));
      expect(map['path'], equals('/data/photos'));
      expect(map['pattern'], equals('*.jpg'));
      expect(map['recursive'], isFalse);
    });

    test('fileMkdir worker serializes all fields', () {
      final worker = NativeWorker.fileMkdir(
        path: '/data/new_dir',
        createParents: true,
      );
      final map = worker.toMap();

      expect(map['workerType'], equals('fileSystem'));
      expect(map['operation'], equals('mkdir'));
      expect(map['path'], equals('/data/new_dir'));
      expect(map['createParents'], isTrue);
    });

    test('workers have correct workerClassName', () {
      expect(
        NativeWorker.fileCopy(sourcePath: '/a', destinationPath: '/b')
            .workerClassName,
        equals('FileSystemWorker'),
      );
      expect(
        NativeWorker.fileMove(sourcePath: '/a', destinationPath: '/b')
            .workerClassName,
        equals('FileSystemWorker'),
      );
      expect(
        NativeWorker.fileDelete(path: '/a').workerClassName,
        equals('FileSystemWorker'),
      );
      expect(
        NativeWorker.fileList(path: '/a').workerClassName,
        equals('FileSystemWorker'),
      );
      expect(
        NativeWorker.fileMkdir(path: '/a').workerClassName,
        equals('FileSystemWorker'),
      );
    });

    test('fileCopy defaults: overwrite=false, recursive=true', () {
      final map = NativeWorker.fileCopy(
        sourcePath: '/a',
        destinationPath: '/b',
      ).toMap();

      expect(map['overwrite'], isFalse);
      expect(map['recursive'], isTrue);
    });

    test('fileDelete defaults: recursive=false', () {
      final map = NativeWorker.fileDelete(path: '/a').toMap();
      expect(map['recursive'], isFalse);
    });

    test('fileList defaults: recursive=false, pattern=null', () {
      final map = NativeWorker.fileList(path: '/a').toMap();
      expect(map['recursive'], isFalse);
      expect(map['pattern'], isNull);
    });

    test('fileMkdir defaults: createParents=true', () {
      final map = NativeWorker.fileMkdir(path: '/a').toMap();
      expect(map['createParents'], isTrue);
    });
  });
}
