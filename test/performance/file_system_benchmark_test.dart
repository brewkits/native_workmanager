import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'dart:developer' as developer;

/// Performance benchmark tests for the Dart-side of native_workmanager.
///
/// These tests run in pure Dart (no native platform / device required).
/// They benchmark:
/// - Worker object creation throughput
/// - Serialization (toMap()) performance
/// - Real Dart file I/O (baseline comparisons)
/// - Edge-case file operations using system temp
///
/// Device-dependent benchmarks (actual native execution speed) belong in
/// example/integration_test/.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDir;
  late String testDirPath;

  setUp(() async {
    final tempDir = Directory.systemTemp;
    testDir = Directory(
        '${tempDir.path}/fs_bench_${DateTime.now().millisecondsSinceEpoch}');
    await testDir.create(recursive: true);
    testDirPath = testDir.path;
  });

  tearDown(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Worker creation + serialization benchmarks
  // ───────────────────────────────────────────────────────────────────────────

  group('Worker Creation Benchmarks', () {
    test('benchmark: create 1000 FileSystemCopyWorkers', () {
      final sw = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        FileSystemCopyWorker(
          sourcePath: '$testDirPath/src_$i.txt',
          destinationPath: '$testDirPath/dst_$i.txt',
          overwrite: i.isEven,
          recursive: i.isOdd,
        );
      }
      sw.stop();

      developer.log('Create 1000 CopyWorkers: ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(500),
          reason: '1000 worker creations should finish in <500ms');
    });

    test('benchmark: create mixed worker types (500 each)', () {
      final sw = Stopwatch()..start();
      for (int i = 0; i < 500; i++) {
        FileSystemCopyWorker(
            sourcePath: '/src/$i', destinationPath: '/dst/$i');
        FileSystemMoveWorker(
            sourcePath: '/src/$i', destinationPath: '/dst/$i');
        FileSystemDeleteWorker(path: '/path/$i');
        FileSystemListWorker(path: '/dir/$i', pattern: '*.txt');
        FileSystemMkdirWorker(path: '/new/$i');
      }
      sw.stop();

      developer.log('Create 500×5 workers: ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('Serialization Benchmarks', () {
    test('benchmark: toMap() 10,000 times (CopyWorker)', () {
      final worker = FileSystemCopyWorker(
        sourcePath: '/source/file.txt',
        destinationPath: '/dest/file.txt',
        overwrite: true,
        recursive: true,
      );

      final sw = Stopwatch()..start();
      for (int i = 0; i < 10000; i++) {
        worker.toMap();
      }
      sw.stop();

      developer.log('10k toMap() calls: ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(1000),
          reason: '10k serializations should finish in <1s');
    });

    test('benchmark: toMap() for all worker types (2000 each)', () {
      final copy = FileSystemCopyWorker(
          sourcePath: '/src', destinationPath: '/dst', overwrite: true);
      final move = FileSystemMoveWorker(
          sourcePath: '/src', destinationPath: '/dst', overwrite: false);
      final delete = FileSystemDeleteWorker(path: '/path', recursive: true);
      final list =
          FileSystemListWorker(path: '/dir', pattern: '*.jpg', recursive: true);
      final mkdir = FileSystemMkdirWorker(path: '/new', createParents: true);

      final sw = Stopwatch()..start();
      for (int i = 0; i < 2000; i++) {
        copy.toMap();
        move.toMap();
        delete.toMap();
        list.toMap();
        mkdir.toMap();
      }
      sw.stop();

      developer.log('2000×5 toMap() calls: ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    test('benchmark: NativeWorker factory + toMap() (1000 calls)', () {
      final sw = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        NativeWorker.fileCopy(
          sourcePath: '/src/$i.txt',
          destinationPath: '/dst/$i.txt',
          overwrite: i.isEven,
        ).toMap();
      }
      sw.stop();

      developer.log('1000 factory+toMap(): ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(500));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Real Dart I/O benchmarks (baseline — what native replaces)
  // ───────────────────────────────────────────────────────────────────────────

  group('Dart File I/O Benchmarks', () {
    test('benchmark: copy 1MB file via Dart I/O', () async {
      final src = File('$testDirPath/1mb.bin');
      await src.writeAsBytes(List.generate(1024 * 1024, (i) => i % 256));

      final sw = Stopwatch()..start();
      await src.copy('$testDirPath/1mb_copy.bin');
      sw.stop();

      developer.log('Dart 1MB copy: ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(3000));
      expect(await File('$testDirPath/1mb_copy.bin').exists(), isTrue);
    });

    test('benchmark: copy 10MB file via Dart I/O', () async {
      final src = File('$testDirPath/10mb.bin');
      await src.writeAsBytes(
          List.generate(10 * 1024 * 1024, (i) => i % 256));

      final sw = Stopwatch()..start();
      await src.copy('$testDirPath/10mb_copy.bin');
      sw.stop();

      developer.log('Dart 10MB copy: ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(10000));
      expect(await File('$testDirPath/10mb_copy.bin').exists(), isTrue);
    });

    test('benchmark: list 1000 files via Dart I/O', () async {
      for (int i = 0; i < 1000; i++) {
        await File('$testDirPath/f_$i.txt').writeAsString('$i');
      }

      final sw = Stopwatch()..start();
      final files = await testDir.list().toList();
      sw.stop();

      developer.log('Dart list 1000 files: ${sw.elapsedMilliseconds}ms');
      expect(files.length, 1000);
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });

    test('benchmark: copy 100 small files via Dart I/O', () async {
      for (int i = 0; i < 100; i++) {
        await File('$testDirPath/src_$i.txt')
            .writeAsString('Content $i' * 100);
      }
      final destDir = Directory('$testDirPath/dest');
      await destDir.create();

      final sw = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        await File('$testDirPath/src_$i.txt')
            .copy('${destDir.path}/src_$i.txt');
      }
      sw.stop();

      developer.log('Dart copy 100 files: ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });

    test('benchmark: move (rename) 100 files via Dart I/O', () async {
      for (int i = 0; i < 100; i++) {
        await File('$testDirPath/move_src_$i.txt').writeAsString('$i');
      }

      final sw = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        await File('$testDirPath/move_src_$i.txt')
            .rename('$testDirPath/move_dst_$i.txt');
      }
      sw.stop();

      developer.log('Dart move 100 files: ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });

    test('benchmark: create 200 nested directories via Dart I/O', () async {
      final sw = Stopwatch()..start();
      for (int i = 0; i < 200; i++) {
        await Directory('$testDirPath/dir_$i/sub').create(recursive: true);
      }
      sw.stop();

      developer.log('Dart create 200 nested dirs: ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Edge cases (real file ops, no native platform required)
  // ───────────────────────────────────────────────────────────────────────────

  group('Edge Cases', () {
    test('edge: copy file with special characters in name', () async {
      final src = File("$testDirPath/file (1) [copy]'s v2.txt");
      await src.writeAsString('Special content');

      final dst = File('$testDirPath/copied (2) [new].txt');
      await src.copy(dst.path);

      expect(await dst.exists(), isTrue);
      expect(await dst.readAsString(), 'Special content');
    });

    test('edge: copy file with unicode characters', () async {
      final src = File('$testDirPath/ảnh_đẹp_图片_фото.jpg');
      await src.writeAsString('Unicode content');

      final dst = File('$testDirPath/复制_копия.jpg');
      await src.copy(dst.path);

      expect(await dst.exists(), isTrue);
      expect(await dst.readAsString(), 'Unicode content');
    });

    test('edge: copy zero-byte file', () async {
      final src = File('$testDirPath/empty.txt');
      await src.create();

      final dst = File('$testDirPath/empty_copy.txt');
      await src.copy(dst.path);

      expect(await dst.exists(), isTrue);
      expect(await dst.length(), 0);
    });

    test('edge: list empty directory', () async {
      final emptyDir = Directory('$testDirPath/empty_dir');
      await emptyDir.create();

      final files = await emptyDir.list().toList();

      expect(files, isEmpty);
    });

    test('edge: create directory when it already exists (idempotent)', () async {
      final dir = Directory('$testDirPath/existing_dir');
      await dir.create();
      expect(await dir.exists(), isTrue);

      // Dart: createSync with recursive:true is idempotent
      await dir.create(recursive: true); // should not throw

      expect(await dir.exists(), isTrue);
    });

    test('edge: worker config for special-char paths serializes correctly', () {
      final worker = FileSystemCopyWorker(
        sourcePath: "$testDirPath/file (1) [copy]'s v2.txt",
        destinationPath: '$testDirPath/复制_копия.jpg',
        overwrite: true,
      );

      final map = worker.toMap();
      expect(map['sourcePath'], contains('file (1)'));
      expect(map['destinationPath'], contains('复制'));
    });

    test('edge: worker config for zero-length path accepted', () {
      // Workers accept any string path; validation happens at native execution
      expect(
        () => FileSystemCopyWorker(sourcePath: '', destinationPath: ''),
        returnsNormally,
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Stress / memory tests (Dart-side only)
  // ───────────────────────────────────────────────────────────────────────────

  group('Stress Tests', () {
    test('stress: create 10,000 workers without memory issues', () {
      final sw = Stopwatch()..start();
      final workers = List.generate(
        10000,
        (i) => FileSystemCopyWorker(
          sourcePath: '/source/file_$i.txt',
          destinationPath: '/dest/file_$i.txt',
          overwrite: i.isEven,
        ),
      );
      sw.stop();

      expect(workers.length, 10000);
      developer.log('10k workers created in ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('stress: serialize 10,000 workers without memory issues', () {
      final workers = List.generate(
        10000,
        (i) => FileSystemCopyWorker(
          sourcePath: '/source/file_$i.txt',
          destinationPath: '/dest/file_$i.txt',
        ),
      );

      final sw = Stopwatch()..start();
      final maps = workers.map((w) => w.toMap()).toList();
      sw.stop();

      expect(maps.length, 10000);
      developer.log('10k toMap() calls in ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('stress: copy deeply nested directory (100 levels) via Dart I/O',
        () async {
      // Build 100-level deep path
      String current = testDirPath;
      for (int i = 0; i < 100; i++) {
        current = '$current/level_$i';
      }
      await Directory(current).create(recursive: true);
      await File('$current/deep_file.txt').writeAsString('Deep file');

      expect(await File('$current/deep_file.txt').exists(), isTrue);

      // Delete from the top of the subtree
      await Directory('$testDirPath/level_0').delete(recursive: true);
      expect(await Directory('$testDirPath/level_0').exists(), isFalse);
    });

    test('stress: pattern matching config for many workers', () {
      final patterns = ['*.txt', '*.jpg', '*.{jpg,png}', 'file_?.txt', 'f*'];
      final random = Random();

      final sw = Stopwatch()..start();
      final workers = List.generate(1000, (i) {
        final pattern = patterns[random.nextInt(patterns.length)];
        return FileSystemListWorker(
          path: '/dir_$i',
          pattern: pattern,
          recursive: i.isEven,
        );
      });
      final maps = workers.map((w) => w.toMap()).toList();
      sw.stop();

      expect(maps.length, 1000);
      developer.log('1000 ListWorker configs in ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(500));
    });
  });

  group('Memory Usage Tests', () {
    test('memory: Dart streaming copy of large file stays within bounds',
        () async {
      // Create 20MB file
      final src = File('$testDirPath/20mb.bin');
      final random = Random();
      final sink = src.openWrite();
      for (int i = 0; i < 20; i++) {
        sink.add(List.generate(1024 * 1024, (_) => random.nextInt(256)));
      }
      await sink.close();

      developer.log('20MB file created');

      final memBefore = ProcessInfo.currentRss;

      // Copy using Dart streaming (openRead/openWrite pipeline)
      final dst = File('$testDirPath/20mb_copy.bin');
      await src.openRead().pipe(dst.openWrite());

      final memAfter = ProcessInfo.currentRss;
      final memIncreaseMB = (memAfter - memBefore) / (1024 * 1024);

      developer
          .log('Memory increase: ${memIncreaseMB.toStringAsFixed(2)} MB');

      expect(await dst.length(), await src.length());
      // Streaming should not load entire 20MB at once
      expect(memIncreaseMB, lessThan(20),
          reason: 'Streaming copy should not load entire file into RAM');
    });

    test('memory: creating many workers does not leak', () {
      final memBefore = ProcessInfo.currentRss;

      for (int i = 0; i < 50000; i++) {
        // Create and let GC collect
        FileSystemCopyWorker(
            sourcePath: '/src/$i', destinationPath: '/dst/$i');
      }

      final memAfter = ProcessInfo.currentRss;
      final memIncreaseMB = (memAfter - memBefore) / (1024 * 1024);

      developer.log(
          '50k worker create/GC cycle: ${memIncreaseMB.toStringAsFixed(2)} MB increase');
      // No strict assertion — GC timing varies; just ensure no catastrophic leak
      expect(memIncreaseMB, lessThan(100),
          reason: 'Transient workers should not retain >100MB');
    });
  });
}
