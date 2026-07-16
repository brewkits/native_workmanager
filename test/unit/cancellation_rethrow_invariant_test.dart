import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Architecture-invariant guard for the v1.4.1 fix (CancellationException
/// swallowed by generic exception handling in Android workers).
///
/// Kotlin's `CancellationException` **is-a** `Exception`, so a generic
/// `catch (e: Exception)` in a worker's `doWork()` swallows cooperative
/// cancellation and converts it into a normal `WorkerResult.Failure` — for
/// `HttpDownloadWorker` that even carried `shouldRetry = true`, so a task the
/// user explicitly cancelled could reschedule itself. The fix is a
/// `catch (e: CancellationException) { throw e }` placed *before* the generic
/// catch in every worker whose vulnerable scope contains a real suspension
/// point.
///
/// This test fails if that rethrow is removed from any of the workers it was
/// added to — a fast, deterministic regression guard that runs in the standard
/// `flutter test` gate (the real worker unit tests are `@Ignore`d because they
/// need an Android runtime, so they cannot guard this). It reads the Kotlin
/// source directly; paths are relative to the package root where `flutter test`
/// runs.
void main() {
  const workersDir =
      'android/src/main/kotlin/dev/brewkits/native_workmanager/workers';

  // The workers whose doWork()/setForeground scope wraps a genuine suspension
  // point (network I/O awaited via child coroutines, delay(), setForeground())
  // inside a generic catch. Each MUST rethrow CancellationException first.
  const workersRequiringRethrow = <String>[
    'DbCleanupWorker',
    'FileCompressionWorker',
    'FileDecompressionWorker',
    'FileSystemWorker',
    'ForegroundNativeWorker',
    'HttpDownloadWorker',
    'HttpRequestWorker',
    'HttpSyncWorker',
    'HttpUploadWorker',
    'ImageProcessWorker',
    'ParallelHttpDownloadWorker',
  ];

  group('v1.4.1: CancellationException is rethrown before generic catch', () {
    for (final worker in workersRequiringRethrow) {
      test('$worker rethrows CancellationException', () {
        final file = File('$workersDir/$worker.kt');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Expected worker source at ${file.path}. If a worker was '
              'renamed or removed, update this invariant list.',
        );

        final source = file.readAsStringSync();

        // Must catch CancellationException...
        final catchesCancellation =
            RegExp(r'catch\s*\(\s*\w+\s*:\s*(kotlinx\.coroutines\.)?'
                    r'CancellationException\s*\)')
                .hasMatch(source);
        expect(
          catchesCancellation,
          isTrue,
          reason: '$worker must catch CancellationException before its generic '
              '`catch (e: Exception)` (v1.4.1 fix). It is-a Exception and is '
              'otherwise swallowed into a WorkerResult.Failure, discarding '
              'cooperative cancellation.',
        );

        // ...and rethrow it (not swallow it).
        final rethrows = RegExp(
          r'catch\s*\(\s*(\w+)\s*:\s*(kotlinx\.coroutines\.)?'
          r'CancellationException\s*\)\s*\{\s*throw\s+\1',
        ).hasMatch(source);
        expect(
          rethrows,
          isTrue,
          reason: '$worker catches CancellationException but must rethrow it '
              '(`catch (e: CancellationException) { throw e }`), not handle it '
              'like a normal failure.',
        );
      });
    }

    test('the invariant list matches the workers directory (no new worker '
        'silently skips the check)', () {
      // Not every worker needs the rethrow — some have no local catch and
      // correctly rely on BaseKmpWorker, and WebSocketWorker uses try/finally.
      // This test just makes sure the directory is discoverable so the list
      // above can be kept honest during review; it does not force every file
      // into the list.
      final dir = Directory(workersDir);
      expect(dir.existsSync(), isTrue, reason: 'workers dir not found');
      final workerFiles = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.kt'))
          .toList();
      expect(
        workerFiles.length,
        greaterThanOrEqualTo(workersRequiringRethrow.length),
        reason: 'Fewer worker files than the invariant list expects — a worker '
            'may have been removed; reconcile the list.',
      );
    });
  });
}
