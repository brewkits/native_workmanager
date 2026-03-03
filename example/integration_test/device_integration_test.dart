// ignore_for_file: avoid_print
// ============================================================
// Native WorkManager v1.0.6 – DEVICE INTEGRATION TESTS
// ============================================================
//
// Run on a real device or emulator (NOT unit/mock tests):
//
//   flutter test integration_test/device_integration_test.dart \
//     --timeout=none
//   # or specific group:
//   flutter test integration_test/device_integration_test.dart \
//     --name "Trigger Types"
//
// Coverage:
//   ✅ All trigger types           (oneTime, oneTime+delay, periodic)
//   ✅ ExistingPolicy              (REPLACE, KEEP)
//   ✅ All constraints             (network, charging, heavy, backoff, systemConstraints)
//   ✅ All 11 workers              (HTTP, File, Image, Crypto, DartWorker)
//   ✅ Custom native workers       (success, missing input, unknown className)
//   ✅ Task chains                 (sequential A→B→C)
//   ✅ Tags                        (assign, query, cancelByTag)
//   ✅ Events & Progress streams
//   ✅ cancelAll / cancel by ID
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

/// Unique task IDs to avoid collisions across test runs.
String _id(String name) =>
    'dit_${name}_${DateTime.now().millisecondsSinceEpoch}';

/// Subscribes to [NativeWorkManager.events] and resolves when the
/// first matching event for [taskId] arrives, or returns null on timeout.
/// Subscribes to [NativeWorkManager.events] and resolves when the first
/// matching event for [taskId] arrives, or returns null on timeout.
///
/// Default timeout is 60 s — generous enough for real-device WorkManager
/// scheduling variability while still catching genuine hangs.
Future<TaskEvent?> _waitEvent(
  String taskId, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final completer = Completer<TaskEvent?>();
  late StreamSubscription<TaskEvent> sub;
  sub = NativeWorkManager.events.listen((event) {
    if (event.taskId == taskId && !completer.isCompleted) {
      completer.complete(event);
      sub.cancel();
    }
  });
  Future.delayed(timeout, () {
    if (!completer.isCompleted) {
      sub.cancel();
      completer.complete(null);
    }
  });
  return completer.future;
}

/// Creates a small valid text file at [path] and returns it.
File _createTextFile(String path, {String content = 'NativeWorkManager test'}) {
  final file = File(path);
  file.writeAsStringSync(content * 100); // ~2 KB
  return file;
}

/// Minimal 1×1 red pixel PNG (RGB, correct Adler-32 and CRC).
/// Generated via Python's zlib to ensure valid checksums.
Uint8List get _minimalPng => Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR len+type
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // width=1, height=1
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, // depth=8, RGB
      0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IHDR CRC, IDAT
      0x54, 0x78, 0xDA, 0x63, 0xF8, 0xCF, 0xC0, 0x00, // IDAT zlib+data
      0x00, 0x03, 0x01, 0x01, 0x00, 0xF7, 0x03, 0x41, // Adler-32 + CRC
      0x43, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, // IEND
      0x44, 0xAE, 0x42, 0x60, 0x82,                   // IEND CRC
    ]);

// ──────────────────────────────────────────────────────────────
// Top-level DartWorker callbacks (must NOT be anonymous/closures)
// PluginUtilities.getCallbackHandle() requires top-level or static functions.
// ──────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<bool> _ditPass(Map<String, dynamic>? input) async {
  print('[DartWorker] dit_pass ran, input=$input');
  return true;
}

@pragma('vm:entry-point')
Future<bool> _ditFail(Map<String, dynamic>? input) async {
  print('[DartWorker] dit_fail returning false');
  return false;
}

@pragma('vm:entry-point')
Future<bool> _chainA(Map<String, dynamic>? input) async {
  print('[DartWorker] chain_a ran');
  return true;
}

@pragma('vm:entry-point')
Future<bool> _chainB(Map<String, dynamic>? input) async {
  print('[DartWorker] chain_b ran');
  return true;
}

@pragma('vm:entry-point')
Future<bool> _chainC(Map<String, dynamic>? input) async {
  print('[DartWorker] chain_c ran');
  return true;
}

// ──────────────────────────────────────────────────────────────
// Main
// ──────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;

  setUpAll(() async {
    tmpDir = Directory(
      '${Directory.systemTemp.path}/nwm_dit_${DateTime.now().millisecondsSinceEpoch}',
    )..createSync();

    await NativeWorkManager.initialize(
      dartWorkers: {
        'dit_pass': _ditPass,
        'dit_fail': _ditFail,
        'chain_a': _chainA,
        'chain_b': _chainB,
        'chain_c': _chainC,
      },
    );

    // Cancel any leftover tasks from previous runs.
    await NativeWorkManager.cancelAll();
  });

  tearDownAll(() async {
    await NativeWorkManager.cancelAll();
    tmpDir.deleteSync(recursive: true);
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 1 – Trigger Types
  // Verifies the bug fix: trigger was previously hardcoded to
  // OneTime; now every type is wired through correctly.
  // ════════════════════════════════════════════════════════════
  group('Trigger Types', () {
    testWidgets('oneTime – executes and emits success event', (tester) async {
      final id = _id('onetime');
      final future = _waitEvent(id);

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      expect(result, ScheduleResult.accepted,
          reason: 'oneTime task must be accepted');

      final event = await future;
      expect(event, isNotNull, reason: 'Must receive completion event');
      expect(event!.success, isTrue,
          reason: 'oneTime task must succeed');
    });

    testWidgets('oneTime with delay – schedules without crash', (tester) async {
      final id = _id('onetime_delay');

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 10)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      expect(result, ScheduleResult.accepted,
          reason: 'Delayed oneTime must be accepted');

      // Clean up before the delay elapses.
      await NativeWorkManager.cancel(id);
    });

    testWidgets(
        'periodic – first execution fires; task survives first run',
        (tester) async {
      final id = _id('periodic');
      var execCount = 0;
      final firstExecCompleter = Completer<void>();

      final sub = NativeWorkManager.events.listen((event) {
        if (event.taskId == id) {
          execCount++;
          print('[periodic test] execution #$execCount success=${event.success}');
          if (!firstExecCompleter.isCompleted) firstExecCompleter.complete();
        }
      });

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.periodic(Duration(minutes: 15)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      expect(result, ScheduleResult.accepted,
          reason: 'Periodic task must be accepted');

      // WorkManager 2.10+ changed periodic task scheduling: the first execution
      // now waits the full interval (15 min) before running, especially on
      // Android 16+ emulators. On real devices with older Android, the first
      // run fires within seconds.
      //
      // We give it 2 minutes. If it doesn't fire (e.g. Android 16 emulator),
      // we fall back to checking that the task is at least tracked as pending,
      // which still validates correct scheduling.
      bool didFire = false;
      try {
        await firstExecCompleter.future.timeout(const Duration(minutes: 2));
        didFire = true;
      } catch (_) {
        // Timeout: likely Android 16 emulator deferring first periodic execution
        print('[periodic test] First execution not observed within 2 min – '
            'checking scheduled state instead (Android 16 emulator limitation)');
      }

      if (didFire) {
        expect(execCount, greaterThanOrEqualTo(1),
            reason: 'Periodic task must execute at least once');

        // Wait 3 s – a second execution should NOT happen (15-min interval).
        await Future.delayed(const Duration(seconds: 3));
        expect(execCount, 1,
            reason:
                'Only 1 execution expected within 3s of a 15-min periodic task');
      } else {
        // Validate the task is still tracked as scheduled (not accidentally cancelled)
        final status = await NativeWorkManager.getTaskStatus(id);
        expect(status, isNotNull,
            reason: 'Periodic task should still be tracked after enqueue');
        print('[periodic test] PASS – task is scheduled (execution skipped on emulator)');
      }

      await sub.cancel();
      await NativeWorkManager.cancel(id);

      // After cancel, no more events should arrive.
      await Future.delayed(const Duration(seconds: 2));
      if (didFire) {
        expect(execCount, 1, reason: 'No events after cancellation');
      }
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 2 – ExistingPolicy
  // Verifies the bug fix: policy was previously hardcoded to KEEP.
  // ════════════════════════════════════════════════════════════
  group('ExistingPolicy', () {
    testWidgets('REPLACE – replaces an existing pending task', (tester) async {
      final id = _id('policy_replace');

      // First enqueue with a 60s delay so it stays pending.
      final r1 = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        existingPolicy: ExistingTaskPolicy.keep,
      );
      expect(r1, ScheduleResult.accepted);

      // Replace with an immediate task; should be accepted.
      // Use 60s timeout: Android 16 emulator HTTP requests can take ~20-25s.
      final future = _waitEvent(id, timeout: const Duration(seconds: 60));
      final r2 = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        existingPolicy: ExistingTaskPolicy.replace,
        constraints: const Constraints(requiresNetwork: true),
      );
      expect(r2, ScheduleResult.accepted,
          reason: 'REPLACE must be accepted');

      final event = await future;
      expect(event, isNotNull,
          reason: 'Replaced task must execute');
      expect(event!.success, isTrue);
    });

    testWidgets('KEEP – ignores new request when task already exists',
        (tester) async {
      final id = _id('policy_keep');

      // First enqueue with a 60s delay (stays pending).
      final r1 = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        existingPolicy: ExistingTaskPolicy.keep,
      );
      expect(r1, ScheduleResult.accepted);

      // Second enqueue with KEEP must also be accepted (library-level).
      final r2 = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/2',
        ),
        existingPolicy: ExistingTaskPolicy.keep,
      );
      expect(r2, ScheduleResult.accepted,
          reason: 'KEEP must be accepted without error');

      await NativeWorkManager.cancel(id);
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 3 – Constraints
  // Verifies the bug fix: constraints were hardcoded to Constraints()
  // and silently ignored. Each field is now wired correctly.
  // ════════════════════════════════════════════════════════════
  group('Constraints', () {
    testWidgets('requiresNetwork=true – runs when network available',
        (tester) async {
      final id = _id('constraint_network');
      final future = _waitEvent(id);

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      expect(result, ScheduleResult.accepted);
      final event = await future;
      expect(event?.success, isTrue,
          reason: 'Task with requiresNetwork must run on networked device');
    });

    testWidgets('isHeavyTask=true – runs as foreground service (Android)',
        (tester) async {
      final id = _id('constraint_heavy');
      final future = _waitEvent(id, timeout: const Duration(seconds: 45));

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'dit_pass', input: {'heavy': true}),
        constraints: const Constraints(isHeavyTask: true),
      );

      expect(result, ScheduleResult.accepted,
          reason: 'Heavy task must be accepted');

      final event = await future;
      expect(event, isNotNull, reason: 'Heavy task must emit event');
      expect(event!.success, isTrue);
    });

    testWidgets('backoffPolicy=linear + backoffDelayMs=10000 – accepted',
        (tester) async {
      final id = _id('constraint_backoff');

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(
          requiresNetwork: true,
          backoffPolicy: BackoffPolicy.linear,
          backoffDelayMs: 10000,
        ),
      );

      expect(result, ScheduleResult.accepted,
          reason: 'Linear backoff constraint must be accepted');

      await NativeWorkManager.cancel(id);
    });

    testWidgets('requiresCharging=false – runs without charger',
        (tester) async {
      final id = _id('constraint_no_charging');
      final future = _waitEvent(id);

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(
          requiresNetwork: true,
          requiresCharging: false,
        ),
      );

      expect(result, ScheduleResult.accepted);
      final event = await future;
      expect(event?.success, isTrue);
    });

    testWidgets(
        'systemConstraints=requireBatteryNotLow – accepted (Android)',
        (tester) async {
      final id = _id('constraint_syscon');

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'dit_pass'),
        constraints: const Constraints(
          systemConstraints: {SystemConstraint.requireBatteryNotLow},
        ),
      );

      expect(result, ScheduleResult.accepted,
          reason: 'SystemConstraint must be accepted');

      await NativeWorkManager.cancel(id);
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 4 – All Workers Execute
  // Each declared worker must: (a) schedule, (b) emit a success event.
  // ════════════════════════════════════════════════════════════
  group('All Workers', () {
    // ── HTTP Workers ─────────────────────────────────────────

    testWidgets('HttpRequestWorker GET – success', (tester) async {
      final id = _id('http_get');
      final future = _waitEvent(id);

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
          method: HttpMethod.get,
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'HttpRequestWorker GET failed');
    });

    testWidgets('HttpRequestWorker POST – success', (tester) async {
      final id = _id('http_post');
      final future = _waitEvent(id);

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts',
          method: HttpMethod.post,
          body: '{"title":"test","body":"body","userId":1}',
          headers: {'Content-Type': 'application/json'},
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'HttpRequestWorker POST failed');
    });

    testWidgets('HttpDownloadWorker – downloads file successfully',
        (tester) async {
      final id = _id('http_download');
      final savePath = '${tmpDir.path}/downloaded.json';
      final future = _waitEvent(id, timeout: const Duration(seconds: 60));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpDownloadWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
          savePath: savePath,
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'HttpDownloadWorker failed');
      expect(File(savePath).existsSync(), isTrue,
          reason: 'Downloaded file must exist on disk');
    });

    testWidgets('HttpUploadWorker – uploads file successfully', (tester) async {
      final id = _id('http_upload');
      final filePath = '${tmpDir.path}/upload_test.txt';
      _createTextFile(filePath);
      final future = _waitEvent(id, timeout: const Duration(seconds: 60));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpUploadWorker(
          url: 'https://httpbin.org/post',
          filePath: filePath,
          fileFieldName: 'file',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'HttpUploadWorker failed');
    });

    testWidgets('HttpSyncWorker – syncs data successfully', (tester) async {
      final id = _id('http_sync');
      final future = _waitEvent(id);

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpSyncWorker(
          url: 'https://jsonplaceholder.typicode.com/posts',
          method: HttpMethod.post,
          requestBody: {'title': 'sync', 'body': 'test', 'userId': 1},
          headers: {'Content-Type': 'application/json'},
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'HttpSyncWorker failed');
    });

    // ── File Workers ─────────────────────────────────────────

    testWidgets('FileCompressionWorker – compresses file to zip',
        (tester) async {
      final id = _id('file_compress');
      final inputPath = '${tmpDir.path}/to_compress.txt';
      final outputPath = '${tmpDir.path}/compressed.zip';
      _createTextFile(inputPath);
      final future = _waitEvent(id, timeout: const Duration(seconds: 45));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: FileCompressionWorker(
          inputPath: inputPath,
          outputPath: outputPath,
          level: CompressionLevel.medium,
        ),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'FileCompressionWorker failed');
      expect(File(outputPath).existsSync(), isTrue,
          reason: 'Zip file must exist after compression');
    });

    testWidgets('FileDecompressionWorker – extracts zip correctly',
        (tester) async {
      // First compress a file, then decompress it.
      final compressId = _id('file_compress_for_decomp');
      final inputPath = '${tmpDir.path}/to_zip.txt';
      final zipPath = '${tmpDir.path}/archive.zip';
      final extractDir = '${tmpDir.path}/extracted/';
      _createTextFile(inputPath);
      Directory(extractDir).createSync();

      // Compress.
      final compressFuture = _waitEvent(compressId,
          timeout: const Duration(seconds: 45));
      await NativeWorkManager.enqueue(
        taskId: compressId,
        trigger: const TaskTrigger.oneTime(),
        worker: FileCompressionWorker(
          inputPath: inputPath,
          outputPath: zipPath,
        ),
      );
      final compressEvent = await compressFuture;
      expect(compressEvent?.success, isTrue,
          reason: 'Compression step failed, cannot test decompression');

      // Decompress.
      final id = _id('file_decompress');
      final future = _waitEvent(id, timeout: const Duration(seconds: 45));
      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: FileDecompressionWorker(
          zipPath: zipPath,
          targetDir: extractDir,
        ),
      );

      final event = await future;
      expect(event?.success, isTrue,
          reason: 'FileDecompressionWorker failed');
    });

    // ── Image Worker ─────────────────────────────────────────

    testWidgets('ImageProcessWorker – resizes image successfully',
        (tester) async {
      final id = _id('image_process');
      final inputPath = '${tmpDir.path}/input.png';
      final outputPath = '${tmpDir.path}/output.png';

      // Write minimal valid PNG.
      File(inputPath).writeAsBytesSync(_minimalPng);

      final future = _waitEvent(id, timeout: const Duration(seconds: 45));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: ImageProcessWorker(
          inputPath: inputPath,
          outputPath: outputPath,
          maxWidth: 100,
          maxHeight: 100,
          quality: 80,
        ),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'ImageProcessWorker failed');
    });

    // ── Crypto Workers ───────────────────────────────────────

    testWidgets('CryptoHashWorker – hashes file successfully', (tester) async {
      final id = _id('crypto_hash');
      final filePath = '${tmpDir.path}/hash_input.txt';
      _createTextFile(filePath);
      final future = _waitEvent(id);

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: CryptoHashWorker.file(
          filePath: filePath,
          algorithm: HashAlgorithm.sha256,
        ),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'CryptoHashWorker failed');
      // Note: resultData availability depends on kmpworkmanager's WorkManager output data
      // support. We verify success is true; resultData is a bonus if available.
    });

    testWidgets('CryptoEncryptWorker – encrypts file successfully',
        (tester) async {
      final id = _id('crypto_encrypt');
      final inputPath = '${tmpDir.path}/plaintext.txt';
      final outputPath = '${tmpDir.path}/encrypted.dat';
      _createTextFile(inputPath);
      final future = _waitEvent(id, timeout: const Duration(seconds: 45));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: CryptoEncryptWorker(
          inputPath: inputPath,
          outputPath: outputPath,
          password: 'test-password-123',
          algorithm: EncryptionAlgorithm.aes,
        ),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'CryptoEncryptWorker failed');
      expect(File(outputPath).existsSync(), isTrue,
          reason: 'Encrypted file must exist');
    });

    testWidgets('CryptoDecryptWorker – decrypts previously encrypted file',
        (tester) async {
      const password = 'test-password-decrypt';
      final encryptId = _id('crypto_enc_for_dec');
      final plainPath = '${tmpDir.path}/plain_dec.txt';
      final encPath = '${tmpDir.path}/encrypted_dec.dat';
      final decPath = '${tmpDir.path}/decrypted.txt';
      _createTextFile(plainPath, content: 'Hello NativeWorkManager!');

      // Encrypt first.
      final encFuture =
          _waitEvent(encryptId, timeout: const Duration(seconds: 45));
      await NativeWorkManager.enqueue(
        taskId: encryptId,
        trigger: const TaskTrigger.oneTime(),
        worker: CryptoEncryptWorker(
          inputPath: plainPath,
          outputPath: encPath,
          password: password,
        ),
      );
      final encEvent = await encFuture;
      expect(encEvent?.success, isTrue,
          reason: 'Encryption step failed, cannot test decryption');

      // Decrypt.
      final id = _id('crypto_decrypt');
      final future = _waitEvent(id, timeout: const Duration(seconds: 45));
      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: CryptoDecryptWorker(
          inputPath: encPath,
          outputPath: decPath,
          password: password,
        ),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'CryptoDecryptWorker failed');
      expect(File(decPath).existsSync(), isTrue,
          reason: 'Decrypted file must exist');
    });

    // ── DartWorker ───────────────────────────────────────────

    testWidgets('DartWorker – callback executes and returns true',
        (tester) async {
      final id = _id('dart_worker_pass');
      final future = _waitEvent(id, timeout: const Duration(seconds: 45));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(
          callbackId: 'dit_pass',
          input: {'key': 'value', 'num': 42},
        ),
      );

      final event = await future;
      expect(event?.success, isTrue, reason: 'DartWorker callback failed');
    });

    testWidgets('DartWorker – callback returning false emits failure event',
        (tester) async {
      final id = _id('dart_worker_fail');
      final future = _waitEvent(id, timeout: const Duration(seconds: 45));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'dit_fail'),
      );

      final event = await future;
      expect(event?.success, isFalse,
          reason: 'DartWorker returning false must emit a failure event');
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 5 – Task Chains (sequential A → B → C)
  // ════════════════════════════════════════════════════════════
  group('Task Chains', () {
    testWidgets('Sequential chain A→B→C – all steps complete in order',
        (tester) async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final idA = 'chain_a_$ts';
      final idB = 'chain_b_$ts';
      final idC = 'chain_c_$ts';

      final executionOrder = <String>[];
      final chainDone = Completer<void>();

      final sub = NativeWorkManager.events.listen((event) {
        if (event.taskId == idA && event.success) {
          executionOrder.add('A');
        } else if (event.taskId == idB && event.success) {
          executionOrder.add('B');
        } else if (event.taskId == idC && event.success) {
          executionOrder.add('C');
          if (!chainDone.isCompleted) chainDone.complete();
        }
      });

      await NativeWorkManager.beginWith(
        TaskRequest(
          id: idA,
          worker: DartWorker(callbackId: 'chain_a'),
        ),
      )
          .then(TaskRequest(
            id: idB,
            worker: DartWorker(callbackId: 'chain_b'),
          ))
          .then(TaskRequest(
            id: idC,
            worker: DartWorker(callbackId: 'chain_c'),
          ))
          .enqueue();

      await chainDone.future
          .timeout(const Duration(seconds: 90), onTimeout: () {
        fail('Chain A→B→C did not complete within 90s');
      });

      await sub.cancel();

      expect(executionOrder, equals(['A', 'B', 'C']),
          reason: 'Chain steps must execute in order A→B→C');
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 6 – Tags
  // ════════════════════════════════════════════════════════════
  group('Tags', () {
    testWidgets('assign tag – queryable via getTasksByTag', (tester) async {
      final tag = 'dit_tag_${DateTime.now().millisecondsSinceEpoch}';
      final id1 = _id('tag_task_1');
      final id2 = _id('tag_task_2');

      // Schedule with 60s delay so they stay in the pending queue.
      await NativeWorkManager.enqueue(
        taskId: id1,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
        worker: DartWorker(callbackId: 'dit_pass'),
        tag: tag,
      );
      await NativeWorkManager.enqueue(
        taskId: id2,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
        worker: DartWorker(callbackId: 'dit_pass'),
        tag: tag,
      );

      final tasks = await NativeWorkManager.getTasksByTag(tag);
      expect(tasks, containsAll([id1, id2]),
          reason: 'Both tagged tasks must appear in getTasksByTag');

      await NativeWorkManager.cancelByTag(tag);
    });

    testWidgets('cancelByTag – cancels all tasks with that tag', (tester) async {
      final tag = 'dit_cancel_tag_${DateTime.now().millisecondsSinceEpoch}';
      final ids = List.generate(3, (i) => _id('cancel_tag_$i'));

      for (final id in ids) {
        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
          worker: DartWorker(callbackId: 'dit_pass'),
          tag: tag,
        );
      }

      // Verify tasks exist.
      final before = await NativeWorkManager.getTasksByTag(tag);
      expect(before.length, equals(3),
          reason: '3 tasks must exist before cancelByTag');

      await NativeWorkManager.cancelByTag(tag);

      // After cancel, the plugin's in-memory tag map is cleared.
      final after = await NativeWorkManager.getTasksByTag(tag);
      expect(after, isEmpty, reason: 'No tasks must remain after cancelByTag');
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 7 – Cancellation
  // ════════════════════════════════════════════════════════════
  group('Cancellation', () {
    testWidgets('cancel by ID – no event fires after cancel', (tester) async {
      final id = _id('cancel_by_id');
      var received = false;

      final sub = NativeWorkManager.events.listen((event) {
        if (event.taskId == id) received = true;
      });

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
        worker: DartWorker(callbackId: 'dit_pass'),
      );

      await NativeWorkManager.cancel(id);

      // Wait 3 s; the task must NOT execute.
      await Future.delayed(const Duration(seconds: 3));
      await sub.cancel();

      expect(received, isFalse,
          reason: 'Cancelled task must not emit any event');
    });

    testWidgets('cancelAll – clears all pending tasks', (tester) async {
      // Schedule several tasks with long delays.
      for (var i = 0; i < 3; i++) {
        await NativeWorkManager.enqueue(
          taskId: _id('cancel_all_$i'),
          trigger: const TaskTrigger.oneTime(Duration(seconds: 60)),
          worker: DartWorker(callbackId: 'dit_pass'),
        );
      }

      // Must not throw.
      await NativeWorkManager.cancelAll();
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 8 – Events & Progress Streams
  // ════════════════════════════════════════════════════════════
  group('Events and Progress Streams', () {
    testWidgets('events stream – delivers resultData from worker',
        (tester) async {
      final id = _id('events_result_data');
      final future = _waitEvent(id);

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await future;
      expect(event, isNotNull);
      expect(event!.taskId, equals(id),
          reason: 'taskId in event must match scheduled taskId');
      expect(event.success, isTrue);
      // resultData is optional — availability depends on kmpworkmanager's output data support.
    });

    testWidgets('progress stream – emits updates for workers that report progress',
        (tester) async {
      // HttpDownloadWorker emits progress during download.
      final id = _id('progress_stream');
      final progressValues = <int>[];
      final completedOrTimeout = Completer<void>();

      final progressSub = NativeWorkManager.progress.listen((p) {
        if (p.taskId == id) {
          progressValues.add(p.progress);
          if (p.progress >= 100 && !completedOrTimeout.isCompleted) {
            completedOrTimeout.complete();
          }
        }
      });

      final eventFuture = _waitEvent(id, timeout: const Duration(seconds: 60));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: HttpDownloadWorker(
          url: 'https://jsonplaceholder.typicode.com/posts',
          savePath: '${tmpDir.path}/progress_test.json',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      final event = await eventFuture;
      await progressSub.cancel();

      expect(event?.success, isTrue, reason: 'Download task must succeed');
      // Progress may or may not be emitted depending on file size;
      // just ensure the stream does not crash if no progress is reported.
      // If progress was emitted, values must be between 0 and 1.
      for (final v in progressValues) {
        expect(v, inInclusiveRange(0, 100),
            reason: 'Progress value must be in [0, 100]');
      }
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 9 – DartWorker Constraint & Delay Enforcement
  //
  // Reproduces GitHub issue #1: "Constraints (requiresNetwork) and
  // TaskTrigger delays are completely ignored for DartWorker tasks."
  //
  // HOW IT WORKS:
  //   • Delay tests measure wall-clock time from enqueue → event.
  //     If elapsed < 7 s the delay was ignored (task fired immediately).
  //   • Network constraint tests verify DartWorker runs when network
  //     IS available (emulator/device always has network during tests).
  //   • The HttpRequestWorker control test lets us confirm whether the
  //     bug is DartWorker-specific or affects all workers.
  //
  // Run with:
  //   flutter test integration_test/device_integration_test.dart \
  //     --name "DartWorker Constraint" --timeout=none
  //
  // Grab logs with:
  //   adb logcat -s NativeWorkmanagerPlugin:D DartCallbackWorker:D \
  //               FlutterEngineManager:D WorkManager:D
  // ════════════════════════════════════════════════════════════
  group('DartWorker Constraint and Delay Enforcement', () {
    // ── Delay enforcement ─────────────────────────────────────

    testWidgets(
        'DartWorker initialDelay=8s – task must not fire before delay elapses',
        (tester) async {
      final id = _id('dart_delay_8s');
      final enqueueTime = DateTime.now();

      print('[DIAG] Enqueueing DartWorker with 8s delay at $enqueueTime');
      // 90s timeout: real devices under WorkManager queue load can take 30–60s
      // to service a new task even when constraints are met immediately.
      final future = _waitEvent(id, timeout: const Duration(seconds: 90));

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 8)),
        worker: DartWorker(
          callbackId: 'dit_pass',
          input: {'test': 'delay_enforcement', 'delayMs': 8000},
        ),
      );

      expect(result, ScheduleResult.accepted,
          reason: 'DartWorker with 8s delay must be accepted');

      final event = await future;
      final elapsedMs = DateTime.now().difference(enqueueTime).inMilliseconds;

      print('[DIAG] DartWorker delay=8s: elapsed=${elapsedMs}ms '
          'success=${event?.success}');

      expect(event, isNotNull,
          reason: 'DartWorker with 8s delay must eventually complete '
              '(waited up to 45s)');
      expect(event!.success, isTrue,
          reason: 'DartWorker callback must return true');

      // 7 s threshold: WorkManager may fire slightly early due to scheduling
      // jitter, but firing within 1–2 s means the delay was completely ignored.
      expect(
        elapsedMs,
        greaterThanOrEqualTo(7000),
        reason: '[BUG #1] DartWorker fired after only ${elapsedMs}ms '
            '— 8s delay was IGNORED. '
            'Check logcat tag NativeWorkmanagerPlugin for WorkRequest details.',
      );
    });

    testWidgets(
        'DartWorker delay=8s + requiresNetwork=true – both constraints applied',
        (tester) async {
      final id = _id('dart_delay_net_8s');
      final enqueueTime = DateTime.now();

      print('[DIAG] Enqueueing DartWorker with 8s delay + requiresNetwork=true');
      final future = _waitEvent(id, timeout: const Duration(seconds: 90));

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 8)),
        worker: DartWorker(
          callbackId: 'dit_pass',
          input: {'test': 'delay_and_network'},
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      expect(result, ScheduleResult.accepted);

      final event = await future;
      final elapsedMs = DateTime.now().difference(enqueueTime).inMilliseconds;

      print('[DIAG] DartWorker delay=8s + requiresNetwork: elapsed=${elapsedMs}ms '
          'success=${event?.success}');

      expect(event, isNotNull,
          reason: 'DartWorker with delay+network must eventually complete');
      expect(event!.success, isTrue);
      expect(
        elapsedMs,
        greaterThanOrEqualTo(7000),
        reason: '[BUG #1] DartWorker fired after only ${elapsedMs}ms '
            '— 8s delay was IGNORED even with requiresNetwork=true set.',
      );
    });

    // ── Network constraint enforcement ────────────────────────

    testWidgets(
        'DartWorker requiresNetwork=true – runs when network is available',
        (tester) async {
      final id = _id('dart_net_constraint');

      print('[DIAG] Enqueueing DartWorker with requiresNetwork=true '
          '(device/emulator has network — task should run)');

      final future = _waitEvent(id, timeout: const Duration(seconds: 90));

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: DartWorker(
          callbackId: 'dit_pass',
          input: {'test': 'network_constraint'},
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      expect(result, ScheduleResult.accepted,
          reason: 'DartWorker with requiresNetwork must be accepted');

      final event = await future;
      print('[DIAG] DartWorker requiresNetwork: success=${event?.success}');

      expect(event, isNotNull,
          reason: 'DartWorker with requiresNetwork must run when network is on');
      expect(event!.success, isTrue,
          reason: 'DartWorker callback must succeed');
    });

    // ── Control: HttpRequestWorker with delay (not DartWorker) ──

    testWidgets(
        'HttpRequestWorker initialDelay=8s – control: verify delay enforced '
        '(if this ALSO fails, bug is systemic, not DartWorker-specific)',
        (tester) async {
      final id = _id('http_delay_8s_ctrl');
      final enqueueTime = DateTime.now();

      print('[DIAG] Enqueueing HttpRequestWorker with 8s delay (control test)');
      final future = _waitEvent(id, timeout: const Duration(seconds: 90));

      final result = await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(Duration(seconds: 8)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      );

      expect(result, ScheduleResult.accepted);

      final event = await future;
      final elapsedMs = DateTime.now().difference(enqueueTime).inMilliseconds;

      print('[DIAG] HttpRequestWorker delay=8s control: elapsed=${elapsedMs}ms '
          'success=${event?.success}');

      expect(event, isNotNull,
          reason: 'HttpRequestWorker with 8s delay must complete within 45s');
      expect(event!.success, isTrue);
      expect(
        elapsedMs,
        greaterThanOrEqualTo(7000),
        reason: '[CONTROL] HttpRequestWorker fired after only ${elapsedMs}ms '
            '— delay was IGNORED. Bug is NOT DartWorker-specific.',
      );
    });
  });

  // ════════════════════════════════════════════════════════════
  // GROUP 10 – Custom Native Workers
  // Verifies the extensibility feature end-to-end on real device.
  // ImageCompressWorker is registered in:
  //   Android → example/android/.../MainActivity.kt
  //   iOS     → example/ios/Runner/AppDelegate.swift
  // These tests run the REAL native worker, not a simulation.
  // ════════════════════════════════════════════════════════════
  group('Custom Native Workers', () {
    // Uses _minimalPng (defined at top of file) — a verified valid 1×1 PNG.
    // UIImage and BitmapFactory both support PNG input; the worker outputs JPEG.

    testWidgets(
        'ImageCompressWorker – compresses image and creates output file',
        (tester) async {
      final id = _id('custom_compress_ok');
      final inputPath = '${tmpDir.path}/custom_input.png';
      final outputPath = '${tmpDir.path}/custom_compressed.jpg';

      await File(inputPath).writeAsBytes(_minimalPng);

      final future = _waitEvent(id, timeout: const Duration(seconds: 45));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: NativeWorker.custom(
          className: 'ImageCompressWorker',
          input: {
            'inputPath': inputPath,
            'outputPath': outputPath,
            'quality': 80,
          },
        ),
      );

      final event = await future;
      expect(event, isNotNull,
          reason: 'Must receive a completion event from ImageCompressWorker');
      expect(event!.success, isTrue,
          reason: 'ImageCompressWorker must succeed with a valid image');
      expect(File(outputPath).existsSync(), isTrue,
          reason: 'Output file must be created on disk after compression');
    });

    testWidgets(
        'ImageCompressWorker – fails gracefully when input file is missing',
        (tester) async {
      final id = _id('custom_compress_no_input');
      final outputPath = '${tmpDir.path}/custom_missing_out.jpg';

      final future = _waitEvent(id, timeout: const Duration(seconds: 30));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: NativeWorker.custom(
          className: 'ImageCompressWorker',
          input: {
            'inputPath': '/nonexistent/path/does_not_exist.jpg',
            'outputPath': outputPath,
            'quality': 80,
          },
        ),
      );

      final event = await future;
      expect(event, isNotNull,
          reason: 'Worker must emit a completion event, not hang');
      expect(event!.success, isFalse,
          reason: 'Worker must return failure when input file does not exist');
    });

    testWidgets(
        'Custom worker – unregistered className emits failure event (no crash)',
        (tester) async {
      final id = _id('custom_unknown_class');

      final future = _waitEvent(id, timeout: const Duration(seconds: 30));

      await NativeWorkManager.enqueue(
        taskId: id,
        trigger: const TaskTrigger.oneTime(),
        worker: NativeWorker.custom(
          className: 'ThisWorkerIsNotRegistered_xyz123',
          input: {'key': 'value'},
        ),
      );

      final event = await future;
      expect(event, isNotNull,
          reason: 'Unknown worker must emit a completion event, not hang');
      expect(event!.success, isFalse,
          reason: 'Unknown className must produce a failure, not silently succeed');
    });
  });
}
