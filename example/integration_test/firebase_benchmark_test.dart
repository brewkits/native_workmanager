// ignore_for_file: avoid_print
// ============================================================
// native_workmanager — Firebase Test Lab Benchmark Suite
// ============================================================
//
// Measures real-device performance for key task execution paths.
// Results are printed as JSON lines with the prefix:
//   BENCHMARK_RESULT: { ... }
// so parse-firebase-results.py can extract them from FTL output.
//
// Run locally:
//   flutter test integration_test/firebase_benchmark_test.dart \
//     --timeout=none -d <device-id>
//
// Run on Firebase Test Lab (via scripts/firebase-benchmark.sh):
//   Automated — triggered by .github/workflows/firebase-benchmark.yml
//
// Benchmark groups:
//   1. Task startup latency     — enqueue → first completion event
//   2. Task throughput          — N tasks completed in X ms
//   3. Chain overhead           — sequential chain vs individual tasks
//   4. Worker type comparison   — hash / http-request / file-write latency
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

String _id(String name) =>
    'bm_${name}_${DateTime.now().millisecondsSinceEpoch}';

/// Subscribe to events and wait for [taskId] completion (success or failure).
/// Returns elapsed ms, or -1 on timeout.
/// Elapsed ms for [taskId], or a negative sentinel.
///
/// `-1` timed out. `-2` reached a terminal event but **failed** — that case used
/// to be reported as an ordinary timing, so a task that failed in 5 ms was
/// indistinguishable from one that succeeded in 5 ms. Every "fast" number this
/// harness produced had to be read with that in mind, and at least one was an
/// artefact: see the note on the FGS comparison below.
Future<int> _measureTaskMs(
  String taskId,
  Future<void> Function() enqueue, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final completer = Completer<int>();
  final sw = Stopwatch();

  late StreamSubscription<TaskEvent> sub;
  sub = NativeWorkManager.events.listen((event) {
    if (event.taskId == taskId && !event.isStarted && !completer.isCompleted) {
      sw.stop();
      if (!event.success) {
        // Timing a failure is meaningless — it measures how fast the platform
        // gave up, not how fast the work ran.
        print(
          'BENCHMARK_FAILED: $taskId failed after '
          '${sw.elapsedMilliseconds}ms — ${event.message}',
        );
        completer.complete(-2);
      } else {
        completer.complete(sw.elapsedMilliseconds);
      }
      sub.cancel();
    }
  });

  sw.start();
  await enqueue();

  Future.delayed(timeout, () {
    if (!completer.isCompleted) {
      sub.cancel();
      sw.stop();
      completer.complete(-1); // timeout sentinel
    }
  });

  return completer.future;
}

/// Wait for [count] tasks (by ID prefix) to complete. Returns elapsed ms.
Future<int> _measureBatchMs(
  List<String> taskIds,
  Future<void> Function() enqueueAll, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final remaining = taskIds.toSet();
  final completer = Completer<int>();
  final sw = Stopwatch();

  late StreamSubscription<TaskEvent> sub;
  sub = NativeWorkManager.events.listen((event) {
    if (!event.isStarted && remaining.remove(event.taskId)) {
      if (remaining.isEmpty && !completer.isCompleted) {
        sw.stop();
        completer.complete(sw.elapsedMilliseconds);
        sub.cancel();
      }
    }
  });

  sw.start();
  await enqueueAll();

  Future.delayed(timeout, () {
    if (!completer.isCompleted) {
      sub.cancel();
      sw.stop();
      completer.complete(-1);
    }
  });

  return completer.future;
}

/// Emit a result line that parse-firebase-results.py will extract.
void _emitResult(Map<String, dynamic> result) {
  print('BENCHMARK_RESULT: ${jsonEncode(result)}');
}

// ── Test Setup ─────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<bool> _fgsPassWorker(Map<String, dynamic>? input) async {
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await NativeWorkManager.initialize(
      dartWorkers: {'fgs_pass': _fgsPassWorker},
    );
    // Short pause so the plugin event streams are fully wired up.
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });

  // ── 1. Task Startup Latency ──────────────────────────────────────────────

  group('1. Task Startup Latency', () {
    testWidgets('hash worker — enqueue → completion latency', (tester) async {
      final tmpDir = Directory.systemTemp.createTempSync('bm_hash_');
      final file = File('${tmpDir.path}/data.bin')
        ..writeAsBytesSync(List.generate(1024, (i) => i % 256));

      final taskId = _id('hash');
      final elapsed = await _measureTaskMs(
        taskId,
        () => NativeWorkManager.enqueue(
          taskId: taskId,
          worker: NativeWorker.hashFile(filePath: file.path),
        ),
      );

      tmpDir.deleteSync(recursive: true);

      _emitResult({
        'benchmark': 'startup_latency_hash_ms',
        'value': elapsed,
        'unit': 'ms',
        'platform': Platform.operatingSystem,
        'passed': elapsed >= 0 && elapsed < 5000,
      });

      expect(elapsed, isNot(-1), reason: 'Task timed out');
      expect(
        elapsed,
        lessThan(5000),
        reason: 'Hash task should complete in < 5s',
      );
    });

    testWidgets('file-write worker — enqueue → completion latency', (
      tester,
    ) async {
      final tmpDir = Directory.systemTemp.createTempSync('bm_fwrite_');
      final srcFile = File('${tmpDir.path}/src.txt')
        ..writeAsStringSync('native_workmanager benchmark data ' * 100);
      final dstFile = '${tmpDir.path}/dst.txt';

      final taskId = _id('fwrite');
      final elapsed = await _measureTaskMs(
        taskId,
        () => NativeWorkManager.enqueue(
          taskId: taskId,
          worker: NativeWorker.fileCopy(
            sourcePath: srcFile.path,
            destinationPath: dstFile,
          ),
        ),
      );

      tmpDir.deleteSync(recursive: true);

      _emitResult({
        'benchmark': 'startup_latency_file_copy_ms',
        'value': elapsed,
        'unit': 'ms',
        'platform': Platform.operatingSystem,
        'passed': elapsed >= 0 && elapsed < 5000,
      });

      expect(elapsed, isNot(-1), reason: 'Task timed out');
      expect(elapsed, lessThan(5000));
    });

    // Android only, and deliberately so.
    //
    // The point of this comparison is the cost of booting a Flutter engine for a
    // background task. On iOS in foreground/test mode a DartWorker does not boot
    // one — it runs through executeDartWorkerViaMethodChannel() on the engine
    // already hosting the test — so it reports ~5 ms against the native worker's
    // ~530 ms, and looks like Dart is a hundred times faster than native. It is
    // not measuring what the name says; it is comparing an in-process callback
    // against the full BGTaskScheduler dispatch path.
    //
    // The numbers were still being emitted on iOS, which is how the first
    // recorded run (benchmark/results/2026-09-06-ios-simulator/) ended up
    // carrying exactly that inversion. `isHeavyTask` (FGS) is an Android concept
    // to begin with, so the whole test is now skipped elsewhere rather than
    // publishing a figure that means something different per platform.
    testWidgets('FGS Memory Footprint Benchmark: Native Worker vs Dart Worker', (
      tester,
    ) async {
      if (!Platform.isAndroid) {
        print(
          'BENCHMARK_SKIPPED: fgs_native_vs_dart is Android-only — a '
          'DartWorker does not boot an engine on iOS in foreground mode, so '
          'the comparison would not measure engine-boot cost.',
        );
        return;
      }
      final tmpDir = Directory.systemTemp.createTempSync('bm_fgs_native_');
      final file = File('${tmpDir.path}/data.bin')
        ..writeAsBytesSync(
          List.generate(10, (i) => i % 256),
        ); // Tiny file just to trigger the worker

      // 1. Measure Native Worker (FGS)
      final nativeTaskId = _id('fgs_native');
      final nativeElapsed = await _measureTaskMs(
        nativeTaskId,
        () => NativeWorkManager.enqueue(
          taskId: nativeTaskId,
          worker: NativeWorker.hashFile(filePath: file.path),
          constraints: const Constraints(isHeavyTask: true), // Force FGS
        ),
      );

      // 2. Measure Dart Worker (Starts Flutter Engine)
      final dartTaskId = _id('fgs_dart');
      final dartElapsed = await _measureTaskMs(
        dartTaskId,
        () => NativeWorkManager.enqueue(
          taskId: dartTaskId,
          worker: DartWorker(
            callbackId: 'fgs_pass',
          ), // Use existing dummy worker
          constraints: const Constraints(isHeavyTask: true), // Force FGS
        ),
      );

      tmpDir.deleteSync(recursive: true);

      print('--- BENCHMARK RESULTS ---');
      print('Native Worker (Zero-Engine) FGS Latency: ${nativeElapsed}ms');
      print('Dart Worker (Full Engine) FGS Latency: ${dartElapsed}ms');

      _emitResult({
        'benchmark': 'fgs_native_worker_latency_ms',
        'value': nativeElapsed,
        'unit': 'ms',
        'platform': Platform.operatingSystem,
        'passed':
            nativeElapsed >= 0 &&
            nativeElapsed <
                5000, // Android WorkManager scheduling can take 1-3s
      });

      _emitResult({
        'benchmark': 'fgs_dart_worker_latency_ms',
        'value': dartElapsed,
        'unit': 'ms',
        'platform': Platform.operatingSystem,
        'passed': dartElapsed >= 0,
      });

      // Assert that Native is much faster than Dart engine booting
      if (Platform.isAndroid) {
        expect(
          nativeElapsed,
          lessThan(dartElapsed),
          reason:
              'Native worker must be faster than Dart worker because of zero-engine overhead',
        );
      }
    });
  });

  // ── 2. Task Throughput ───────────────────────────────────────────────────

  group('2. Task Throughput', () {
    testWidgets('10 hash tasks — total completion time', (tester) async {
      final tmpDir = Directory.systemTemp.createTempSync('bm_tput_');
      final file = File('${tmpDir.path}/data.bin')
        ..writeAsBytesSync(List.generate(512, (i) => i % 256));

      const count = 10;
      final ids = List.generate(count, (i) => _id('tput$i'));

      final elapsed = await _measureBatchMs(ids, () async {
        for (final id in ids) {
          await NativeWorkManager.enqueue(
            taskId: id,
            worker: NativeWorker.hashFile(filePath: file.path),
          );
        }
      }, timeout: const Duration(seconds: 90));

      tmpDir.deleteSync(recursive: true);

      final avgMs = elapsed >= 0 ? elapsed ~/ count : -1;

      _emitResult({
        'benchmark': 'throughput_10_tasks_total_ms',
        'value': elapsed,
        'unit': 'ms',
        'tasks': count,
        'avg_per_task_ms': avgMs,
        'platform': Platform.operatingSystem,
        'passed': elapsed >= 0 && elapsed < 30000,
      });

      expect(elapsed, isNot(-1), reason: '10 tasks timed out');
      expect(elapsed, lessThan(30000));
    });

    testWidgets('5 hash tasks — avg per-task time', (tester) async {
      final tmpDir = Directory.systemTemp.createTempSync('bm_tput5_');
      final file = File('${tmpDir.path}/data.bin')
        ..writeAsBytesSync(List.generate(4096, (i) => i % 256)); // 4KB

      const count = 5;
      final ids = List.generate(count, (i) => _id('tp5_$i'));

      final elapsed = await _measureBatchMs(ids, () async {
        for (final id in ids) {
          await NativeWorkManager.enqueue(
            taskId: id,
            worker: NativeWorker.hashFile(filePath: file.path),
          );
        }
      });

      tmpDir.deleteSync(recursive: true);

      _emitResult({
        'benchmark': 'throughput_5_tasks_total_ms',
        'value': elapsed,
        'unit': 'ms',
        'tasks': count,
        'avg_per_task_ms': elapsed >= 0 ? elapsed ~/ count : -1,
        'platform': Platform.operatingSystem,
        'passed': elapsed >= 0 && elapsed < 20000,
      });

      expect(elapsed, isNot(-1));
      expect(elapsed, lessThan(20000));
    });
  });

  // ── 3. Chain Overhead ────────────────────────────────────────────────────

  group('3. Chain Overhead', () {
    testWidgets('3-step chain — total elapsed', (tester) async {
      final tmpDir = Directory.systemTemp.createTempSync('bm_chain_');
      final f1 = File('${tmpDir.path}/a.txt')..writeAsStringSync('step1' * 50);
      final f2 = '${tmpDir.path}/b.txt';
      final f3 = '${tmpDir.path}/c.txt';
      final f4 = '${tmpDir.path}/d.txt';

      final chainId = _id('chain3');

      final completer = Completer<int>();
      final sw = Stopwatch();

      late StreamSubscription<TaskEvent> sub;
      // Completion events carry the individual STEP ids ('$chainId-1', '-2',
      // '-3'), never the chain's name. Listening for `chainId` matched nothing,
      // so this benchmark hit its 60 s timeout and reported the -1 sentinel on
      // every run it has ever done. The last step is what marks the chain done —
      // the same thing the chain device tests wait on.
      final lastStepId = '$chainId-3';
      sub = NativeWorkManager.events.listen((event) {
        if (event.taskId == lastStepId &&
            !event.isStarted &&
            !completer.isCompleted) {
          sw.stop();
          completer.complete(sw.elapsedMilliseconds);
          sub.cancel();
        }
      });

      sw.start();
      await NativeWorkManager.beginWith(
            TaskRequest(
              id: '$chainId-1',
              worker: NativeWorker.fileCopy(
                sourcePath: f1.path,
                destinationPath: f2,
              ),
            ),
          )
          .then(
            TaskRequest(
              id: '$chainId-2',
              worker: NativeWorker.fileCopy(
                sourcePath: f2,
                destinationPath: f3,
              ),
            ),
          )
          .then(
            TaskRequest(
              id: '$chainId-3',
              worker: NativeWorker.fileCopy(
                sourcePath: f3,
                destinationPath: f4,
              ),
            ),
          )
          .named(chainId)
          .enqueue();

      Future.delayed(const Duration(seconds: 60), () {
        if (!completer.isCompleted) {
          sub.cancel();
          sw.stop();
          completer.complete(-1);
        }
      });

      final elapsed = await completer.future;
      tmpDir.deleteSync(recursive: true);

      _emitResult({
        'benchmark': 'chain_3_steps_ms',
        'value': elapsed,
        'unit': 'ms',
        'steps': 3,
        'platform': Platform.operatingSystem,
        'passed': elapsed >= 0 && elapsed < 40000,
      });

      expect(elapsed, isNot(-1), reason: '3-step chain timed out');
      expect(elapsed, lessThan(40000));
    });
  });

  // ── 4. Worker Type Comparison ────────────────────────────────────────────

  group('4. Worker Type Comparison', () {
    testWidgets('SHA-256 hash — small file (1KB)', (tester) async {
      final tmpDir = Directory.systemTemp.createTempSync('bm_hash1k_');
      final file = File('${tmpDir.path}/1k.bin')
        ..writeAsBytesSync(List.generate(1024, (i) => i % 256));

      final taskId = _id('sha256_1k');
      final elapsed = await _measureTaskMs(
        taskId,
        () => NativeWorkManager.enqueue(
          taskId: taskId,
          worker: NativeWorker.hashFile(filePath: file.path),
        ),
      );

      tmpDir.deleteSync(recursive: true);

      _emitResult({
        'benchmark': 'hash_sha256_1kb_ms',
        'value': elapsed,
        'unit': 'ms',
        'file_size_bytes': 1024,
        'algorithm': 'SHA-256',
        'platform': Platform.operatingSystem,
        'passed': elapsed >= 0 && elapsed < 3000,
      });

      expect(elapsed, isNot(-1));
      expect(elapsed, lessThan(3000));
    });

    testWidgets('SHA-256 hash — medium file (100KB)', (tester) async {
      final tmpDir = Directory.systemTemp.createTempSync('bm_hash100k_');
      final file = File('${tmpDir.path}/100k.bin')
        ..writeAsBytesSync(List.generate(100 * 1024, (i) => i % 256));

      final taskId = _id('sha256_100k');
      final elapsed = await _measureTaskMs(
        taskId,
        () => NativeWorkManager.enqueue(
          taskId: taskId,
          worker: NativeWorker.hashFile(
            filePath: file.path,
            algorithm: HashAlgorithm.sha256,
          ),
        ),
        timeout: const Duration(seconds: 30),
      );

      tmpDir.deleteSync(recursive: true);

      _emitResult({
        'benchmark': 'hash_sha256_100kb_ms',
        'value': elapsed,
        'unit': 'ms',
        'file_size_bytes': 100 * 1024,
        'algorithm': 'SHA-256',
        'platform': Platform.operatingSystem,
        'passed': elapsed >= 0 && elapsed < 5000,
      });

      expect(elapsed, isNot(-1));
      expect(elapsed, lessThan(5000));
    });

    testWidgets('SHA-512 hash — medium file (100KB)', (tester) async {
      final tmpDir = Directory.systemTemp.createTempSync('bm_sha512_');
      final file = File('${tmpDir.path}/100k.bin')
        ..writeAsBytesSync(List.generate(100 * 1024, (i) => i % 256));

      final taskId = _id('sha512_100k');
      final elapsed = await _measureTaskMs(
        taskId,
        () => NativeWorkManager.enqueue(
          taskId: taskId,
          worker: NativeWorker.hashFile(
            filePath: file.path,
            algorithm: HashAlgorithm.sha512,
          ),
        ),
        timeout: const Duration(seconds: 30),
      );

      tmpDir.deleteSync(recursive: true);

      _emitResult({
        'benchmark': 'hash_sha512_100kb_ms',
        'value': elapsed,
        'unit': 'ms',
        'file_size_bytes': 100 * 1024,
        'algorithm': 'SHA-512',
        'platform': Platform.operatingSystem,
        'passed': elapsed >= 0 && elapsed < 5000,
      });

      expect(elapsed, isNot(-1));
      expect(elapsed, lessThan(5000));
    });

    testWidgets('file copy — 500KB', (tester) async {
      final tmpDir = Directory.systemTemp.createTempSync('bm_copy500k_');
      final src = File('${tmpDir.path}/src.bin')
        ..writeAsBytesSync(List.generate(500 * 1024, (i) => i % 256));
      final dst = '${tmpDir.path}/dst.bin';

      final taskId = _id('copy_500k');
      final elapsed = await _measureTaskMs(
        taskId,
        () => NativeWorkManager.enqueue(
          taskId: taskId,
          worker: NativeWorker.fileCopy(
            sourcePath: src.path,
            destinationPath: dst,
          ),
        ),
        timeout: const Duration(seconds: 30),
      );

      tmpDir.deleteSync(recursive: true);

      _emitResult({
        'benchmark': 'file_copy_500kb_ms',
        'value': elapsed,
        'unit': 'ms',
        'file_size_bytes': 500 * 1024,
        'platform': Platform.operatingSystem,
        'passed': elapsed >= 0 && elapsed < 5000,
      });

      expect(elapsed, isNot(-1));
      expect(elapsed, lessThan(5000));
    });
  });
}
