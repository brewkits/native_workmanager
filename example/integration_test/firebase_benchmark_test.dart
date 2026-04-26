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
      completer.complete(sw.elapsedMilliseconds);
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await NativeWorkManager.initialize();
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
      sub = NativeWorkManager.events.listen((event) {
        if (event.taskId == chainId &&
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
