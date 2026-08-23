import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Architecture-invariant guard for the v1.4.1 fix (CancellationException
/// swallowed by generic exception handling in Android coroutine paths).
///
/// Kotlin's `CancellationException` **is-a** `Exception`
/// (`kotlinx.coroutines.CancellationException` → `java.util.concurrent.
/// CancellationException` → `IllegalStateException` → `RuntimeException` →
/// `Exception`), so a generic `catch (e: Exception)` around a suspension point
/// swallows cooperative cancellation and turns it into a normal failure — for
/// `HttpDownloadWorker` that even carried `shouldRetry = true`, so a task the
/// user explicitly cancelled could reschedule itself.
///
/// ## Why this test was rewritten (v1.5.0)
///
/// The first version matched the rethrow regex against the **whole file**. That
/// is too coarse: `HttpUploadWorker.kt` contains two suspend functions, and a
/// single rethrow in `doWork()` made the file pass while the sibling
/// `handleRawBodyUpload()` had no guard at all. The guard built to catch this
/// exact bug could not see it.
///
/// This version parses each `suspend fun` body by brace depth and checks the
/// invariant **per function**. A function is either guarded, or listed in
/// [_exemptions] with a human-written reason.
///
/// Suspension-point detection is deliberately **not** automated: a heuristic
/// that scans for `withContext`/`await` counts the function's own enclosing
/// `withContext` and produces false alarms. Whether a guarded region can
/// actually observe a cancellation is a judgement call, so it lives in an
/// exemption reason a reviewer can read and challenge.
void main() {
  // Scoped to the paths where WorkManager/coroutine cancellation is real: the
  // worker execution bodies and the Flutter engine host. MethodChannel handlers
  // in NativeWorkmanagerPlugin+*.kt run on the platform thread servicing a call
  // and are a different concern.
  const scannedDirs = <String>[
    'android/src/main/kotlin/dev/brewkits/native_workmanager/workers',
    'android/src/main/kotlin/dev/brewkits/native_workmanager/engine',
  ];

  /// `File#function` → why a generic catch there cannot swallow a real
  /// cancellation. Verified by reading the guarded region.
  const exemptions = <String, String>{
    'CryptoWorker.kt#doWork':
        'guarded regions are CPU-bound crypto inside the enclosing '
            'withContext — no suspension point inside any try block',
    'PdfWorker.kt#doWork':
        'guarded regions are blocking PdfRenderer/file I/O — no suspension '
            'point inside any try block',
    'MoveToSharedStorageWorker.kt#doWork':
        'guarded regions are blocking MediaStore/ContentResolver calls — no '
            'suspension point inside any try block',
    'WebSocketWorker.kt#doWork':
        'uses try/finally around the OkHttp WebSocket listener; cancellation '
            'is handled by the finally block, not converted to a result',
    'FlutterEngineManager.kt#ensureEngineInitialized':
        'guarded region is FlutterLoader/engine construction on the main '
            'thread — blocking, no suspension point inside the try',
    'FlutterEngineManager.kt#dispose':
        'teardown path; swallowing here is deliberate so a failed dispose '
            'cannot mask the original result',
    'ParallelHttpUploadWorker.kt#doWork':
        'the only generic catch is `catch (_: Exception)` around '
            'JSONObject(input).optString("__taskId") — pure parsing. The HTTP '
            'work has no outer generic catch, so cancellation propagates to '
            'BaseKmpWorker; uploadSingleFile() is a non-suspend blocking fun',
    'ChainResultCapturingWorker.kt#doWork':
        'guarded region is blocking ChainStore/SQLite persistence of a '
            'finished step — no suspension point inside the try',
    'ForegroundNativeWorker.kt#emitToBus':
        'best-effort telemetry emit; a failure here must not mask the task '
            'result, and the caller doWork() carries its own rethrow',
    'ForegroundNativeWorker.kt#getForegroundInfo':
        'guarded region is Color.parseColor on a user-supplied hex string — '
            'pure parsing, no suspension point',
  };

  final rethrowPattern = RegExp(
    r'catch\s*\(\s*(\w+)\s*:\s*(kotlinx\.coroutines\.)?'
    r'CancellationException\s*\)\s*\{\s*throw\s+\1',
  );
  final genericCatchPattern =
      RegExp(r'catch\s*\(\s*\w+\s*:\s*(java\.lang\.)?Exception\s*\)');

  group('v1.4.1/v1.5.0: CancellationException rethrow, checked per function',
      () {
    late Map<String, String> functionBodies; // 'File.kt#name' -> body source

    setUpAll(() {
      functionBodies = <String, String>{};
      for (final dir in scannedDirs) {
        final d = Directory(dir);
        expect(d.existsSync(), isTrue, reason: 'scanned dir missing: $dir');
        for (final f in d
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.kt'))) {
          final name = f.uri.pathSegments.last;
          final src = _strip(f.readAsStringSync());
          functionBodies.addAll(_suspendFunctionBodies(src, name));
        }
      }
      expect(functionBodies, isNotEmpty,
          reason: 'parser found no suspend functions — it is broken');
    });

    test('every suspend fun with a generic catch rethrows or is exempt', () {
      final offenders = <String>[];

      functionBodies.forEach((key, body) {
        if (!genericCatchPattern.hasMatch(body)) return;
        if (rethrowPattern.hasMatch(body)) return;
        if (exemptions.containsKey(key)) return;
        offenders.add(key);
      });

      expect(
        offenders,
        isEmpty,
        reason: 'These suspend functions wrap a generic `catch (e: Exception)` '
            'with no `catch (e: CancellationException) { throw e }` before it, '
            'and are not exempted:\n'
            '${offenders.map((o) => '  - $o').join('\n')}\n\n'
            'Either add the rethrow, or add an entry to `exemptions` in this '
            'test explaining why the guarded region cannot observe a '
            'cancellation.',
      );
    });

    test('the two HttpUploadWorker suspend functions are checked separately',
        () {
      // Regression guard for the flaw this rewrite fixes: the old file-scoped
      // regex passed on HttpUploadWorker because doWork() had a rethrow, hiding
      // that handleRawBodyUpload() had none.
      expect(functionBodies.keys, contains('HttpUploadWorker.kt#doWork'));
      expect(functionBodies.keys,
          contains('HttpUploadWorker.kt#handleRawBodyUpload'));
      for (final k in [
        'HttpUploadWorker.kt#doWork',
        'HttpUploadWorker.kt#handleRawBodyUpload',
      ]) {
        expect(rethrowPattern.hasMatch(functionBodies[k]!), isTrue,
            reason: '$k must carry its own rethrow');
      }
    });

    test('parser regression: ParallelHttpUploadWorker#doWork reads as clean',
        () {
      // The earlier ad-hoc scan mis-flagged this because it delimited function
      // bodies by "next `suspend fun`", so doWork() ran to EOF and absorbed the
      // catch inside the NON-suspend `uploadSingleFile()`. Brace matching must
      // stop at doWork()'s real closing brace.
      final body = functionBodies['ParallelHttpUploadWorker.kt#doWork'];
      expect(body, isNotNull);
      expect(
        body!.contains('uploadSingleFile('),
        isTrue,
        reason: 'doWork should still contain the call site',
      );
      expect(
        RegExp(r'private fun uploadSingleFile').hasMatch(body),
        isFalse,
        reason: 'brace matching leaked past doWork() into uploadSingleFile — '
            'the parser is broken and every verdict it produces is suspect',
      );
    });

    test('no stale exemptions', () {
      final unknown =
          exemptions.keys.where((k) => !functionBodies.containsKey(k)).toList();
      expect(unknown, isEmpty,
          reason: 'exemptions reference functions that no longer exist '
              '(renamed or removed): $unknown');
    });
  });
}

/// Removes comments and string literals so brace matching is not thrown off by
/// `${...}` templates or braces inside strings.
String _strip(String src) {
  final out = StringBuffer();
  var i = 0;
  while (i < src.length) {
    final rest = src.length - i;
    if (rest >= 2 && src[i] == '/' && src[i + 1] == '/') {
      while (i < src.length && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (rest >= 2 && src[i] == '/' && src[i + 1] == '*') {
      i += 2;
      while (i + 1 < src.length && !(src[i] == '*' && src[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    if (rest >= 3 && src.startsWith('"""', i)) {
      i += 3;
      while (i + 2 < src.length && !src.startsWith('"""', i)) {
        i++;
      }
      i += 3;
      out.write('""');
      continue;
    }
    if (src[i] == '"') {
      i++;
      while (i < src.length && src[i] != '"') {
        if (src[i] == r'\') i++;
        i++;
      }
      i++;
      out.write('""');
      continue;
    }
    out.write(src[i]);
    i++;
  }
  return out.toString();
}

/// Maps `<file>#<functionName>` to the function's body source, delimited by
/// brace depth from the declaration's opening `{`.
Map<String, String> _suspendFunctionBodies(String src, String fileName) {
  final result = <String, String>{};
  final decl = RegExp(r'\bsuspend\s+fun\s+(\w+)\s*\(');
  for (final m in decl.allMatches(src)) {
    final name = m.group(1)!;
    final open = src.indexOf('{', m.end);
    if (open == -1) continue;
    var depth = 0;
    var i = open;
    for (; i < src.length; i++) {
      if (src[i] == '{') depth++;
      if (src[i] == '}') {
        depth--;
        if (depth == 0) break;
      }
    }
    if (depth != 0) continue; // unbalanced — skip rather than guess
    result['$fileName#$name'] = src.substring(open, i + 1);
  }
  return result;
}
