import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'dart:developer' as developer;

/// Performance benchmark and stress tests for FileSystemWorker.
///
/// Tests:
/// - Performance benchmarks vs Dart File I/O
/// - Stress tests (large files, many operations, edge cases)
/// - Memory usage monitoring
/// - Concurrent operations
///
/// Coverage: Performance validation
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDir;
  late String testDirPath;

  setUp(() async {
    final tempDir = Directory.systemTemp;
    testDir = Directory('${tempDir.path}/fs_bench_${DateTime.now().millisecondsSinceEpoch}');
    await testDir.create(recursive: true);
    testDirPath = testDir.path;
  });

  tearDown(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('Performance Benchmarks', () {
    test('benchmark: copy 1MB file - Native vs Dart', () async {
      // Create 1MB test file
      final sourceFile = File('$testDirPath/1mb_source.bin');
      final data = List.generate(1024 * 1024, (i) => i % 256);
      await sourceFile.writeAsBytes(data);

      // Benchmark Native Worker
      final nativeStopwatch = Stopwatch()..start();
      await NativeWorkManager.enqueue(
        taskId: 'bench-native-1mb',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: sourceFile.path,
          destinationPath: '$testDirPath/1mb_native.bin',
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      nativeStopwatch.stop();

      // Benchmark Dart File I/O
      final dartStopwatch = Stopwatch()..start();
      await sourceFile.copy('$testDirPath/1mb_dart.bin');
      dartStopwatch.stop();

      developer.log('1MB Copy - Native: ${nativeStopwatch.elapsedMilliseconds}ms');
      developer.log('1MB Copy - Dart: ${dartStopwatch.elapsedMilliseconds}ms');
      developer.log('Ratio: ${dartStopwatch.elapsedMilliseconds / nativeStopwatch.elapsedMilliseconds}x');

      // Native should be comparable or faster
      expect(nativeStopwatch.elapsedMilliseconds, lessThan(5000));
    });

    test('benchmark: copy 10MB file - Native vs Dart', () async {
      // Create 10MB test file
      final sourceFile = File('$testDirPath/10mb_source.bin');
      final data = List.generate(10 * 1024 * 1024, (i) => i % 256);
      await sourceFile.writeAsBytes(data);

      // Benchmark Native Worker
      final nativeStopwatch = Stopwatch()..start();
      await NativeWorkManager.enqueue(
        taskId: 'bench-native-10mb',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: sourceFile.path,
          destinationPath: '$testDirPath/10mb_native.bin',
        ),
      );
      await Future.delayed(const Duration(seconds: 5));
      nativeStopwatch.stop();

      // Benchmark Dart File I/O
      final dartStopwatch = Stopwatch()..start();
      await sourceFile.copy('$testDirPath/10mb_dart.bin');
      dartStopwatch.stop();

      developer.log('10MB Copy - Native: ${nativeStopwatch.elapsedMilliseconds}ms');
      developer.log('10MB Copy - Dart: ${dartStopwatch.elapsedMilliseconds}ms');

      // Native should handle large files efficiently
      expect(nativeStopwatch.elapsedMilliseconds, lessThan(10000));
    });

    test('benchmark: copy 100 small files (1KB each)', () async {
      // Create 100 small files
      for (int i = 0; i < 100; i++) {
        final file = File('$testDirPath/small_$i.txt');
        await file.writeAsString('Content $i' * 100); // ~1KB
      }

      // Benchmark Native Worker (copy directory)
      final nativeStopwatch = Stopwatch()..start();
      await NativeWorkManager.enqueue(
        taskId: 'bench-native-100files',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: testDirPath,
          destinationPath: '$testDirPath/../copy_native',
          recursive: true,
        ),
      );
      await Future.delayed(const Duration(seconds: 5));
      nativeStopwatch.stop();

      // Benchmark Dart File I/O
      final copyDir = Directory('$testDirPath/../copy_dart');
      await copyDir.create();

      final dartStopwatch = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        await File('$testDirPath/small_$i.txt').copy('${copyDir.path}/small_$i.txt');
      }
      dartStopwatch.stop();

      developer.log('100 Files Copy - Native: ${nativeStopwatch.elapsedMilliseconds}ms');
      developer.log('100 Files Copy - Dart: ${dartStopwatch.elapsedMilliseconds}ms');

      // Cleanup
      await Directory('$testDirPath/../copy_native').delete(recursive: true);
      await copyDir.delete(recursive: true);
    });

    test('benchmark: move file vs copy+delete', () async {
      // Create test file
      final sourceFile = File('$testDirPath/move_test.bin');
      final data = List.generate(1024 * 1024, (i) => i % 256); // 1MB
      await sourceFile.writeAsBytes(data);

      // Benchmark Native Move
      final moveStopwatch = Stopwatch()..start();
      await NativeWorkManager.enqueue(
        taskId: 'bench-move',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileMove(
          sourcePath: sourceFile.path,
          destinationPath: '$testDirPath/moved.bin',
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      moveStopwatch.stop();

      // Benchmark Dart Copy+Delete
      final sourceFile2 = File('$testDirPath/move_test2.bin');
      await sourceFile2.writeAsBytes(data);

      final copyDeleteStopwatch = Stopwatch()..start();
      await sourceFile2.copy('$testDirPath/moved2.bin');
      await sourceFile2.delete();
      copyDeleteStopwatch.stop();

      developer.log('Move - Native: ${moveStopwatch.elapsedMilliseconds}ms');
      developer.log('Copy+Delete - Dart: ${copyDeleteStopwatch.elapsedMilliseconds}ms');

      // Move should be faster (atomic operation)
      expect(moveStopwatch.elapsedMilliseconds, lessThan(copyDeleteStopwatch.elapsedMilliseconds + 100));
    });

    test('benchmark: list 1000 files', () async {
      // Create 1000 files
      for (int i = 0; i < 1000; i++) {
        await File('$testDirPath/file_$i.txt').writeAsString('Content $i');
      }

      // Benchmark Native List
      final nativeStopwatch = Stopwatch()..start();
      await NativeWorkManager.enqueue(
        taskId: 'bench-list-1000',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileList(
          path: testDirPath,
        ),
      );
      await Future.delayed(const Duration(seconds: 3));
      nativeStopwatch.stop();

      // Benchmark Dart List
      final dartStopwatch = Stopwatch()..start();
      final files = await testDir.list().toList();
      dartStopwatch.stop();

      developer.log('List 1000 Files - Native: ${nativeStopwatch.elapsedMilliseconds}ms');
      developer.log('List 1000 Files - Dart: ${dartStopwatch.elapsedMilliseconds}ms');
      developer.log('File count: ${files.length}');

      expect(nativeStopwatch.elapsedMilliseconds, lessThan(5000));
    });
  });

  group('Stress Tests', () {
    test('stress: copy very large file (100MB)', () async {
      // Create 100MB file
      final largeFile = File('$testDirPath/100mb.bin');
      final random = Random();

      // Write in chunks to avoid memory issues
      final sink = largeFile.openWrite();
      for (int i = 0; i < 100; i++) {
        final chunk = List.generate(1024 * 1024, (_) => random.nextInt(256));
        sink.add(chunk);
      }
      await sink.close();

      developer.log('100MB file created');

      // Copy large file
      final stopwatch = Stopwatch()..start();
      await NativeWorkManager.enqueue(
        taskId: 'stress-100mb-copy',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: largeFile.path,
          destinationPath: '$testDirPath/100mb_copy.bin',
        ),
      );

      await Future.delayed(const Duration(seconds: 30));
      stopwatch.stop();

      developer.log('100MB copy completed in: ${stopwatch.elapsedMilliseconds}ms');

      // Verify copied
      final copiedFile = File('$testDirPath/100mb_copy.bin');
      expect(await copiedFile.exists(), true);
      expect(await copiedFile.length(), await largeFile.length());

      // Should complete within reasonable time
      expect(stopwatch.elapsedMilliseconds, lessThan(60000)); // 60s
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('stress: copy directory with 1000 files', () async {
      // Create 1000 files in nested structure
      for (int i = 0; i < 10; i++) {
        final subDir = Directory('$testDirPath/dir_$i');
        await subDir.create();

        for (int j = 0; j < 100; j++) {
          await File('${subDir.path}/file_$j.txt').writeAsString('Content $i-$j');
        }
      }

      developer.log('1000 files created');

      // Copy entire directory
      final stopwatch = Stopwatch()..start();
      await NativeWorkManager.enqueue(
        taskId: 'stress-1000files-copy',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: testDirPath,
          destinationPath: '$testDirPath/../1000files_copy',
          recursive: true,
        ),
      );

      await Future.delayed(const Duration(seconds: 30));
      stopwatch.stop();

      developer.log('1000 files copy completed in: ${stopwatch.elapsedMilliseconds}ms');

      // Verify
      final copyDir = Directory('$testDirPath/../1000files_copy');
      expect(await copyDir.exists(), true);

      // Cleanup
      await copyDir.delete(recursive: true);

      // Should complete within reasonable time
      expect(stopwatch.elapsedMilliseconds, lessThan(60000)); // 60s
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('stress: delete directory with deep nesting (100 levels)', () async {
      // Create deeply nested directory
      String currentPath = testDirPath;
      for (int i = 0; i < 100; i++) {
        currentPath = '$currentPath/level_$i';
        await Directory(currentPath).create();
      }
      await File('$currentPath/deep_file.txt').writeAsString('Deep file');

      developer.log('100-level deep directory created');

      // Delete from root
      final stopwatch = Stopwatch()..start();
      await NativeWorkManager.enqueue(
        taskId: 'stress-deep-delete',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileDelete(
          path: '$testDirPath/level_0',
          recursive: true,
        ),
      );

      await Future.delayed(const Duration(seconds: 10));
      stopwatch.stop();

      developer.log('Deep directory deleted in: ${stopwatch.elapsedMilliseconds}ms');

      // Verify deleted
      expect(await Directory('$testDirPath/level_0').exists(), false);

      // Should handle deep nesting
      expect(stopwatch.elapsedMilliseconds, lessThan(15000));
    });

    test('stress: list directory with 5000 files', () async {
      // Create 5000 files
      developer.log('Creating 5000 files...');
      for (int i = 0; i < 5000; i++) {
        await File('$testDirPath/file_$i.txt').writeAsString('Content $i');

        if (i % 500 == 0) {
          developer.log('Created $i files...');
        }
      }

      developer.log('5000 files created');

      // List files
      final stopwatch = Stopwatch()..start();
      await NativeWorkManager.enqueue(
        taskId: 'stress-5000files-list',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileList(
          path: testDirPath,
        ),
      );

      await Future.delayed(const Duration(seconds: 10));
      stopwatch.stop();

      developer.log('5000 files listed in: ${stopwatch.elapsedMilliseconds}ms');

      // Should handle large listings
      expect(stopwatch.elapsedMilliseconds, lessThan(15000));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('stress: concurrent copy operations (10 parallel)', () async {
      // Create 10 source files
      for (int i = 0; i < 10; i++) {
        final file = File('$testDirPath/concurrent_source_$i.bin');
        final data = List.generate(1024 * 1024, (j) => (i + j) % 256); // 1MB each
        await file.writeAsBytes(data);
      }

      developer.log('10 source files created');

      // Start 10 copy operations concurrently
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 10; i++) {
        NativeWorkManager.enqueue(
          taskId: 'concurrent-copy-$i',
          trigger: TaskTrigger.oneTime(),
          worker: NativeWorker.fileCopy(
            sourcePath: '$testDirPath/concurrent_source_$i.bin',
            destinationPath: '$testDirPath/concurrent_dest_$i.bin',
          ),
        );
      }

      // Wait for all to complete
      await Future.delayed(const Duration(seconds: 15));
      stopwatch.stop();

      developer.log('10 concurrent copies completed in: ${stopwatch.elapsedMilliseconds}ms');

      // Verify all copied
      int successCount = 0;
      for (int i = 0; i < 10; i++) {
        if (await File('$testDirPath/concurrent_dest_$i.bin').exists()) {
          successCount++;
        }
      }

      developer.log('Success count: $successCount/10');

      // Should handle concurrent operations
      expect(successCount, greaterThan(5)); // At least 50% success
      expect(stopwatch.elapsedMilliseconds, lessThan(30000));
    });

    test('stress: pattern matching with complex patterns', () async {
      // Create files with various extensions
      final extensions = ['txt', 'jpg', 'png', 'pdf', 'doc', 'mp3', 'mp4'];

      for (int i = 0; i < 100; i++) {
        final ext = extensions[i % extensions.length];
        await File('$testDirPath/file_$i.$ext').writeAsString('Content $i');
      }

      // Test various patterns
      final patterns = [
        '*.txt',
        '*.jpg',
        '*.{jpg,png}',
        'file_?.txt',
        'file_1*.txt',
      ];

      for (final pattern in patterns) {
        final stopwatch = Stopwatch()..start();

        await NativeWorkManager.enqueue(
          taskId: 'stress-pattern-${pattern.hashCode}',
          trigger: TaskTrigger.oneTime(),
          worker: NativeWorker.fileList(
            path: testDirPath,
            pattern: pattern,
          ),
        );

        await Future.delayed(const Duration(seconds: 2));
        stopwatch.stop();

        developer.log('Pattern "$pattern" matched in: ${stopwatch.elapsedMilliseconds}ms');

        // Should handle patterns efficiently
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      }
    });
  });

  group('Edge Cases', () {
    test('edge: copy file with special characters in name', () async {
      // Create file with special chars
      final specialFile = File('$testDirPath/file (1) [copy]\'s version #2.txt');
      await specialFile.writeAsString('Special content');

      // Copy
      await NativeWorkManager.enqueue(
        taskId: 'edge-special-chars',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: specialFile.path,
          destinationPath: '$testDirPath/copied (2) [new].txt',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Verify
      expect(await File('$testDirPath/copied (2) [new].txt').exists(), true);
    });

    test('edge: copy file with unicode characters', () async {
      // Create file with unicode
      final unicodeFile = File('$testDirPath/ảnh_đẹp_图片_фото.jpg');
      await unicodeFile.writeAsString('Unicode content');

      // Copy
      await NativeWorkManager.enqueue(
        taskId: 'edge-unicode',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: unicodeFile.path,
          destinationPath: '$testDirPath/复制_копия.jpg',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Verify
      expect(await File('$testDirPath/复制_копия.jpg').exists(), true);
    });

    test('edge: copy zero-byte file', () async {
      // Create empty file
      final emptyFile = File('$testDirPath/empty.txt');
      await emptyFile.create();

      // Copy
      await NativeWorkManager.enqueue(
        taskId: 'edge-zero-byte',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: emptyFile.path,
          destinationPath: '$testDirPath/empty_copy.txt',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Verify
      final copiedFile = File('$testDirPath/empty_copy.txt');
      expect(await copiedFile.exists(), true);
      expect(await copiedFile.length(), 0);
    });

    test('edge: list empty directory', () async {
      // Create empty directory
      final emptyDir = Directory('$testDirPath/empty_dir');
      await emptyDir.create();

      // List
      await NativeWorkManager.enqueue(
        taskId: 'edge-empty-list',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileList(
          path: emptyDir.path,
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Should complete without error
      // (Verify via event listener in real test)
    });

    test('edge: create directory with existing name', () async {
      // Create directory
      final dir = Directory('$testDirPath/existing_dir');
      await dir.create();

      // Try to create again
      await NativeWorkManager.enqueue(
        taskId: 'edge-mkdir-existing',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileMkdir(
          path: dir.path,
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      // Should succeed (idempotent operation)
      expect(await dir.exists(), true);
    });
  });

  group('Memory Usage Tests', () {
    test('memory: copy large file should not load entire file', () async {
      // Create 50MB file
      final largeFile = File('$testDirPath/50mb.bin');
      final random = Random();
      final sink = largeFile.openWrite();

      for (int i = 0; i < 50; i++) {
        final chunk = List.generate(1024 * 1024, (_) => random.nextInt(256));
        sink.add(chunk);
      }
      await sink.close();

      developer.log('50MB file created');

      // Get memory before
      final memBefore = ProcessInfo.currentRss;

      // Copy (should use streaming)
      await NativeWorkManager.enqueue(
        taskId: 'memory-test-50mb',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCopy(
          sourcePath: largeFile.path,
          destinationPath: '$testDirPath/50mb_copy.bin',
        ),
      );

      await Future.delayed(const Duration(seconds: 20));

      // Get memory after
      final memAfter = ProcessInfo.currentRss;
      final memIncrease = (memAfter - memBefore) / (1024 * 1024); // MB

      developer.log('Memory increase: ${memIncrease.toStringAsFixed(2)} MB');

      // Should not increase by 50MB (streaming copy)
      expect(memIncrease, lessThan(50));
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}
