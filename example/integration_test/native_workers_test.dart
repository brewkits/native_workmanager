// ignore_for_file: avoid_print
// ============================================================
// native_workmanager — Native Workers Integration Tests
// ============================================================
//
// Covers workers that had no prior device-level integration tests:
//   ✅ CryptoHashWorker (file hash + string hash)
//   ✅ ImageProcessWorker (resize + format conversion)
//   ✅ FileSystem workers (copy, delete, list)
//   ✅ ParallelHttpUploadWorker (multi-file, concurrent)
//   ✅ MultiUploadWorker (multiple files in one request)
//
// Run on a real device or emulator:
//
//   flutter test integration_test/native_workers_test.dart \
//     --timeout=none
// ============================================================

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

// ──────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────

String _id(String label) =>
    'nwt_${label}_${DateTime.now().millisecondsSinceEpoch}';

Future<TaskEvent?> _waitEvent(
  String taskId, {
  Duration timeout = const Duration(seconds: 120),
}) async {
  final completer = Completer<TaskEvent?>();
  late StreamSubscription<TaskEvent> sub;
  sub = NativeWorkManager.events.listen((event) {
    print('WaitEvent: received event for ${event.taskId}, status=${event.success}, isStarted=${event.isStarted}, hasResultData=${event.resultData != null}');
    if (event.taskId == taskId && !completer.isCompleted && !event.isStarted) {
      if (event.resultData != null) {
        completer.complete(event);
        sub.cancel();
      } else {
        print('WaitEvent: event for $taskId has no resultData, waiting for fallback...');
      }
    }
  });

  try {
    return await completer.future.timeout(timeout);
  } catch (e) {
    sub.cancel();
    // Small delay to allow native side to finish DB write if event was missed
    print('WaitEvent: timeout for $taskId, waiting for fallback...');
    await Future.delayed(const Duration(seconds: 2));
    
    print('WaitEvent: calling getTaskRecord for $taskId');
    final record = await NativeWorkManager.getTaskRecord(taskId: taskId);
    print('WaitEvent: fallback record for $taskId: status=${record?.status}, rawResultData=${record?.resultData}');
    if (record?.resultData != null) {
      print('WaitEvent: resultData type: ${record!.resultData.runtimeType}');
      print('WaitEvent: resultData keys: ${record.resultData!.keys.toList()}');
    }
    if (record != null &&
        (record.status == 'success' ||
            record.status == 'completed' ||
            record.status == 'failed' ||
            record.status == 'cancelled')) {
      print('WaitEvent: returning synthetic event for $taskId');
      return TaskEvent(
        taskId: taskId,
        success: record.status == 'success' || record.status == 'completed',
        message: record.status == 'failed' ? 'Task failed in background' : null,
        resultData: record.resultData, // This is already parsed as Map in TaskRecord.fromMap
        timestamp: record.updatedAt,
      );
    }
    return null;
  }
}

/// Minimal 32×32 blue pixel PNG — more robust for native decoders.
Uint8List get _minimalPng => Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x20, 0x00, 0x00, 0x00, 0x20,
      0x08, 0x02, 0x00, 0x00, 0x00, 0xFC, 0x18, 0xED, 0xA3, 0x00, 0x00, 0x00,
      0x01, 0x73, 0x52, 0x47, 0x42, 0x00, 0xAE, 0xCE, 0x1C, 0xE9, 0x00, 0x00,
      0x00, 0x04, 0x67, 0x41, 0x4D, 0x41, 0x00, 0x00, 0xB1, 0x8F, 0x0B, 0xFC,
      0x61, 0x05, 0x00, 0x00, 0x00, 0x09, 0x70, 0x48, 0x59, 0x73, 0x00, 0x00,
      0x0E, 0xC3, 0x00, 0x00, 0x0E, 0xC3, 0x01, 0xC7, 0x6F, 0xA8, 0x64, 0x00,
      0x00, 0x00, 0x1B, 0x49, 0x44, 0x41, 0x54, 0x48, 0x43, 0x63, 0x60, 0x60,
      0x60, 0xF8, 0x0F, 0xC1, 0x00, 0x09, 0x06, 0x1A, 0x01, 0x13, 0x01, 0xAA,
      0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x03, 0x00, 0x00, 0x06,
      0x00, 0x01, 0xBE, 0xCD, 0x7A, 0x2E, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
      0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ]);

String get _tmp => Directory.systemTemp.path;

// ──────────────────────────────────────────────────────────────
// Test suite
// ──────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await NativeWorkManager.initialize(debugMode: true);
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 1 — CryptoHashWorker
  // ──────────────────────────────────────────────────────────
  group('CryptoHashWorker', () {
    testWidgets('SHA-256 file hash returns 64-char hex string', (tester) async {
      await tester.pumpAndSettle();

      // Create a small test file with known content.
      final filePath =
          '$_tmp/crypto-test-${DateTime.now().millisecondsSinceEpoch}.txt';
      await File(filePath).writeAsString('native_workmanager crypto test');

      final taskId = _id('crypto-sha256');
      final eventFuture = _waitEvent(taskId);

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: const TaskTrigger.oneTime(),
        worker: CryptoHashWorker.file(
          filePath: filePath,
          algorithm: HashAlgorithm.sha256,
        ),
      );

      final event = await eventFuture;
      expect(event, isNotNull, reason: 'SHA-256 task must fire');
      expect(event!.success, isTrue, reason: 'SHA-256 hash must succeed');

      final result = CryptoResult.from(event.resultData);
      expect(result, isNotNull, reason: 'CryptoResult must parse');
      expect(result!.hash, isNotNull);
      expect(
        result.hash!.length,
        64,
        reason: 'SHA-256 hex string must be 64 characters',
      );
      expect(
        RegExp(r'^[0-9a-f]+$').hasMatch(result.hash!),
        isTrue,
        reason: 'Hash must be lowercase hex',
      );

      await File(filePath).delete().catchError((_) => File(filePath));
    });

    testWidgets('MD5 file hash returns 32-char hex string', (tester) async {
      await tester.pumpAndSettle();

      final filePath =
          '$_tmp/crypto-md5-${DateTime.now().millisecondsSinceEpoch}.txt';
      await File(filePath).writeAsString('md5 test content');

      final taskId = _id('crypto-md5');
      final eventFuture = _waitEvent(taskId);

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: const TaskTrigger.oneTime(),
        worker: CryptoHashWorker.file(
          filePath: filePath,
          algorithm: HashAlgorithm.md5,
        ),
      );

      final event = await eventFuture;
      expect(event?.success, isTrue);

      final result = CryptoResult.from(event!.resultData);
      expect(result?.hash?.length, 32, reason: 'MD5 hex must be 32 chars');

      await File(filePath).delete().catchError((_) => File(filePath));
    });

    testWidgets('SHA-256 string hash produces consistent output', (
      tester,
    ) async {
      await tester.pumpAndSettle();

      const input = 'hello native_workmanager';
      // Known SHA-256 of "hello native_workmanager":
      //   computed offline — test only checks format + length here.

      final taskId = _id('crypto-str');
      final eventFuture = _waitEvent(taskId);

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: const TaskTrigger.oneTime(),
        worker: CryptoHashWorker.string(
          data: input,
          algorithm: HashAlgorithm.sha256,
        ),
      );

      final event = await eventFuture;
      expect(event?.success, isTrue);

      final result = CryptoResult.from(event!.resultData);
      expect(result?.hash?.length, 64);

      // Enqueue a second time — same input must produce same hash.
      final taskId2 = _id('crypto-str2');
      final event2Future = _waitEvent(taskId2);

      await NativeWorkManager.enqueue(
        taskId: taskId2,
        trigger: const TaskTrigger.oneTime(),
        worker: CryptoHashWorker.string(
          data: input,
          algorithm: HashAlgorithm.sha256,
        ),
      );

      final event2 = await event2Future;
      final result2 = CryptoResult.from(event2?.resultData);
      expect(
        result2?.hash,
        equals(result!.hash),
        reason: 'Same input must produce same SHA-256 hash',
      );
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 2 — ImageProcessWorker
  // ──────────────────────────────────────────────────────────
  group('ImageProcessWorker', () {
    testWidgets('resize PNG produces output file', (tester) async {
      await tester.pumpAndSettle();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final inputPath = '$_tmp/img-in-$ts.png';
      final outputPath = '$_tmp/img-out-$ts.jpg';

      // Write minimal valid PNG.
      await File(inputPath).writeAsBytes(_minimalPng);

      final taskId = _id('img-resize');
      final eventFuture = _waitEvent(
        taskId,
        timeout: const Duration(seconds: 60),
      );

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: const TaskTrigger.oneTime(),
        worker: ImageProcessWorker(
          inputPath: inputPath,
          outputPath: outputPath,
          maxWidth: 32,
          maxHeight: 32,
          quality: 80,
          outputFormat: ImageFormat.jpeg,
        ),
      );

      final event = await eventFuture;
      expect(event, isNotNull, reason: 'ImageProcess task must fire');
      expect(
        event!.success,
        isTrue,
        reason: 'Image resize must succeed: ${event.message}',
      );

      final result = ImageProcessResult.from(event.resultData);
      expect(result, isNotNull, reason: 'ImageProcessResult must parse');
      expect(result!.outputPath, isNotEmpty);

      // Cleanup.
      for (final p in [inputPath, outputPath]) {
        await File(p).delete().catchError((_) => File(p));
      }
    });

    testWidgets('PNG to JPEG conversion preserves output', (tester) async {
      await tester.pumpAndSettle();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final inputPath = '$_tmp/img-in2-$ts.png';
      final outputPath = '$_tmp/img-out2-$ts.jpeg';

      await File(inputPath).writeAsBytes(_minimalPng);

      final taskId = _id('img-convert');
      final eventFuture = _waitEvent(taskId);

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: const TaskTrigger.oneTime(),
        worker: ImageProcessWorker(
          inputPath: inputPath,
          outputPath: outputPath,
          quality: 75,
          outputFormat: ImageFormat.jpeg,
        ),
      );

      final event = await eventFuture;
      expect(
        event?.success,
        isTrue,
        reason: 'PNG → JPEG conversion must succeed',
      );

      for (final p in [inputPath, outputPath]) {
        await File(p).delete().catchError((_) => File(p));
      }
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 3 — FileSystem Workers
  // ──────────────────────────────────────────────────────────
  group('FileSystem Workers', () {
    testWidgets('FileSystemCopyWorker copies a file', (tester) async {
      await tester.pumpAndSettle();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final src = '$_tmp/fs-src-$ts.txt';
      final dst = '$_tmp/fs-dst-$ts.txt';

      await File(src).writeAsString('copy test content');

      final taskId = _id('fs-copy');
      final eventFuture = _waitEvent(taskId);

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: const TaskTrigger.oneTime(),
        worker: FileSystemCopyWorker(
          sourcePath: src,
          destinationPath: dst,
          overwrite: true,
        ),
      );

      final event = await eventFuture;
      expect(event, isNotNull, reason: 'Copy task must fire');
      expect(
        event!.success,
        isTrue,
        reason: 'File copy must succeed: ${event.message}',
      );

      // Verify both files exist after copy.
      expect(
        await File(src).exists(),
        isTrue,
        reason: 'Source must still exist',
      );
      expect(
        await File(dst).exists(),
        isTrue,
        reason: 'Destination must be created',
      );

      for (final p in [src, dst]) {
        await File(p).delete().catchError((_) => File(p));
      }
    });

    testWidgets('FileSystemDeleteWorker removes a file', (tester) async {
      await tester.pumpAndSettle();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '$_tmp/fs-del-$ts.txt';
      await File(path).writeAsString('delete me');

      final taskId = _id('fs-delete');
      final eventFuture = _waitEvent(taskId);

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: const TaskTrigger.oneTime(),
        worker: FileSystemDeleteWorker(path: path),
      );

      final event = await eventFuture;
      expect(
        event?.success,
        isTrue,
        reason: 'File delete must succeed: ${event?.message}',
      );
      expect(
        await File(path).exists(),
        isFalse,
        reason: 'File must not exist after delete',
      );
    });

    testWidgets('FileSystemListWorker lists directory contents', (
      tester,
    ) async {
      await tester.pumpAndSettle();

      // Create a small temp directory with two known files.
      final ts = DateTime.now().millisecondsSinceEpoch;
      final dir = Directory('$_tmp/fs-list-dir-$ts');
      await dir.create(recursive: true);
      await File('${dir.path}/a.txt').writeAsString('a');
      await File('${dir.path}/b.txt').writeAsString('b');

      final taskId = _id('fs-list');
      final eventFuture = _waitEvent(taskId);

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: const TaskTrigger.oneTime(),
        worker: FileSystemListWorker(path: dir.path),
      );

      final event = await eventFuture;
      expect(
        event?.success,
        isTrue,
        reason: 'List task must succeed: ${event?.message}',
      );

      final result = FileSystemResult.from(event!.resultData);
      expect(result, isNotNull, reason: 'FileSystemResult must parse');
      expect(
        result!.entries?.length,
        greaterThanOrEqualTo(2),
        reason: 'Must list at least the 2 created files',
      );

      await dir.delete(recursive: true).catchError((_) => dir);
    });

    testWidgets('FileSystemMoveWorker moves a file', (tester) async {
      await tester.pumpAndSettle();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final src = '$_tmp/fs-mv-src-$ts.txt';
      final dst = '$_tmp/fs-mv-dst-$ts.txt';

      await File(src).writeAsString('move test content');

      final taskId = _id('fs-move');
      final eventFuture = _waitEvent(taskId);

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: const TaskTrigger.oneTime(),
        worker: FileSystemMoveWorker(
          sourcePath: src,
          destinationPath: dst,
          overwrite: false,
        ),
      );

      final event = await eventFuture;
      expect(
        event?.success,
        isTrue,
        reason: 'Move must succeed: ${event?.message}',
      );
      expect(
        await File(src).exists(),
        isFalse,
        reason: 'Source must be removed after move',
      );
      expect(
        await File(dst).exists(),
        isTrue,
        reason: 'Destination must exist after move',
      );

      await File(dst).delete().catchError((_) => File(dst));
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 4 — NativeWorker Extensions (Convenience Factories)
  // ──────────────────────────────────────────────────────────
  group('NativeWorker Extensions', () {
    testWidgets('NativeWorker.fileCopy copies correctly', (tester) async {
      await tester.pumpAndSettle();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final src = '$_tmp/nw-src-$ts.txt';
      final dst = '$_tmp/nw-dst-$ts.txt';

      await File(src).writeAsString('factory copy test');

      final taskId = _id('nw-copy');
      final eventFuture = _waitEvent(taskId);

      await NativeWorkManager.enqueue(
        taskId: taskId,
        worker: NativeWorker.fileCopy(
          sourcePath: src,
          destinationPath: dst,
        ),
      );

      final event = await eventFuture;
      expect(event?.success, isTrue);
      expect(await File(dst).exists(), isTrue);

      for (final p in [src, dst]) {
        await File(p).delete().catchError((_) => File(p));
      }
    });

    testWidgets('NativeWorker.fileMove moves correctly', (tester) async {
      await tester.pumpAndSettle();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final src = '$_tmp/nw-mv-src-$ts.txt';
      final dst = '$_tmp/nw-mv-dst-$ts.txt';

      await File(src).writeAsString('factory move test');

      final taskId = _id('nw-move');
      final eventFuture = _waitEvent(taskId);

      await NativeWorkManager.enqueue(
        taskId: taskId,
        worker: NativeWorker.fileMove(
          sourcePath: src,
          destinationPath: dst,
        ),
      );

      final event = await eventFuture;
      expect(event?.success, isTrue);
      expect(await File(src).exists(), isFalse);
      expect(await File(dst).exists(), isTrue);

      await File(dst).delete().catchError((_) => File(dst));
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 5 — ParallelHttpUploadWorker
  // ──────────────────────────────────────────────────────────
  group('ParallelHttpUploadWorker', () {
    testWidgets('uploads 3 files with maxConcurrent=2 — all succeed', (
      tester,
    ) async {
      await tester.pumpAndSettle();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final paths = <String>[];
      for (var i = 1; i <= 3; i++) {
        final p = '$_tmp/par-up-$i-$ts.txt';
        await File(p).writeAsString('parallel upload file $i (ts=$ts)');
        paths.add(p);
      }

      final taskId = _id('par-upload');
      final eventFuture = _waitEvent(
        taskId,
        timeout: const Duration(seconds: 90),
      );

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: const TaskTrigger.oneTime(),
        worker: ParallelHttpUploadWorker(
          url: 'https://httpbin.org/post',
          files: paths.map((p) => UploadFile(filePath: p)).toList(),
          maxConcurrent: 2,
          maxRetries: 1,
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await eventFuture;
      expect(event, isNotNull, reason: 'Parallel upload task must fire');
      expect(
        event!.success,
        isTrue,
        reason: 'All files must upload: ${event.message}',
      );

      final result = ParallelUploadResult.from(event.resultData);
      if (result != null) {
        expect(
          result.uploadedCount,
          3,
          reason: 'uploadedCount must equal number of files',
        );
        expect(result.failedCount, 0, reason: 'No files should fail');
      }

      for (final p in paths) {
        await File(p).delete().catchError((_) => File(p));
      }
    });

    testWidgets('single file upload succeeds', (tester) async {
      await tester.pumpAndSettle();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final filePath = '$_tmp/par-single-$ts.txt';
      await File(filePath).writeAsString('single parallel upload');

      final taskId = _id('par-single');
      final eventFuture = _waitEvent(taskId);

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: const TaskTrigger.oneTime(),
        worker: ParallelHttpUploadWorker(
          url: 'https://httpbin.org/post',
          files: [UploadFile(filePath: filePath)],
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await eventFuture;
      expect(event?.success, isTrue);

      await File(filePath).delete().catchError((_) => File(filePath));
    });
  });

  // ──────────────────────────────────────────────────────────
  // GROUP 5 — MultiUploadWorker
  // ──────────────────────────────────────────────────────────
  group('MultiUploadWorker (NativeWorker.multiUpload)', () {
    testWidgets('uploads 2 files in single multipart request', (tester) async {
      await tester.pumpAndSettle();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final f1 = '$_tmp/multi-1-$ts.txt';
      final f2 = '$_tmp/multi-2-$ts.txt';
      await File(f1).writeAsString('multi upload file 1');
      await File(f2).writeAsString('multi upload file 2');

      final taskId = _id('multi-upload');
      final eventFuture = _waitEvent(
        taskId,
        timeout: const Duration(seconds: 60),
      );

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: const TaskTrigger.oneTime(),
        worker: NativeWorker.multiUpload(
          url: 'https://httpbin.org/post',
          files: [
            UploadFile(filePath: f1, fieldName: 'files'),
            UploadFile(filePath: f2, fieldName: 'files'),
          ],
          additionalFields: const {'source': 'integration-test'},
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await eventFuture;
      expect(event, isNotNull, reason: 'MultiUpload task must fire');
      expect(
        event!.success,
        isTrue,
        reason: 'Multi-file upload must succeed: ${event.message}',
      );

      for (final p in [f1, f2]) {
        await File(p).delete().catchError((_) => File(p));
      }
    });

    testWidgets('multiUpload with custom headers succeeds', (tester) async {
      await tester.pumpAndSettle();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final filePath = '$_tmp/multi-hdr-$ts.txt';
      await File(filePath).writeAsString('multi upload with headers');

      final taskId = _id('multi-headers');
      final eventFuture = _waitEvent(taskId);

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: const TaskTrigger.oneTime(),
        worker: NativeWorker.multiUpload(
          url: 'https://httpbin.org/post',
          files: [UploadFile(filePath: filePath)],
          headers: const {'X-Test': 'integration-test'},
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await eventFuture;
      expect(event?.success, isTrue);

      await File(filePath).delete().catchError((_) => File(filePath));
    });
  });
}
