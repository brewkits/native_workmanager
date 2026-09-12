import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against a real regression introduced while fixing issue #72: a
/// `@pragma('vm:entry-point')` annotation silently detached from the
/// function it was meant to protect.
///
/// `@pragma` binds to the single top-level declaration syntactically
/// following it — nothing more. Inserting a new `const`/`final` declaration
/// between an existing `@pragma('vm:entry-point')` and its intended function
/// re-targets the pragma onto that new declaration instead, where it is a
/// silent no-op (pragmas on variables are simply ignored, no warning). The
/// function loses tree-shaking protection and its native-callable entry
/// point registration, with **no compile error and no analyzer warning** —
/// `flutter analyze` and every mocked-channel unit test stay green.
///
/// The only thing that actually catches it is booting a real background
/// isolate on a device and hitting:
/// ```
/// Dart Error: ERROR: To closurize '...' from native code, it must be
/// annotated.
/// Could not resolve main entrypoint function.
/// ```
/// — which is exactly what happened once, on a Pixel 6 Pro, while adding
/// issue #72's Zone-key constants right after the pragma above
/// `_callbackDispatcher` in native_work_manager.dart. This test makes that
/// class of mistake fail fast, on every `flutter analyze`/CI run, without
/// needing a device.
///
/// If this test fails: something now sits between a `@pragma('vm:entry-point')`
/// and the function/method it must protect. Move the pragma back to
/// immediately precede its function (blank lines, comments, and other
/// annotations are fine in between — a `const`/`final`/`var` declaration is
/// not).
void main() {
  /// Resolves a repo path whether the test runs from the repo root or
  /// elsewhere (mirrors channel_method_parity_test.dart's helper).
  Directory _repoDir(String relative) {
    final direct = Directory(relative);
    if (direct.existsSync()) return direct;
    final nested = Directory('../$relative');
    if (nested.existsSync()) return nested;
    fail('Could not locate $relative from ${Directory.current.path}');
  }

  test(
      '@pragma(\'vm:entry-point\') is never separated from its declaration '
      'by a const/final/var in between', () {
    final pragmaPattern = RegExp(
      r'''@pragma\(\s*['"]vm:entry-point['"]\s*\)''',
    );
    // What a misplaced pragma ends up sitting on top of instead: a plain
    // variable/field/getter declaration, not a function, method, or class.
    final suspiciousNextDeclaration = RegExp(
      r'^\s*(?:static\s+)?(?:const|final|var)\b',
    );

    final violations = <String>[];

    for (final dir in [_repoDir('lib')]) {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();

        for (var i = 0; i < lines.length; i++) {
          if (!pragmaPattern.hasMatch(lines[i])) continue;

          // Walk forward past blank lines, comments, and other single-line
          // annotations — those are all legal between a pragma and its
          // target. The first *substantive* line is what the pragma binds to.
          var j = i + 1;
          while (j < lines.length) {
            final line = lines[j].trim();
            final isBlank = line.isEmpty;
            final isComment = line.startsWith('//');
            final isAnotherAnnotation = line.startsWith('@');
            if (isBlank || isComment || isAnotherAnnotation) {
              j++;
              continue;
            }
            break;
          }

          if (j >= lines.length) continue; // pragma at EOF — not this bug.

          if (suspiciousNextDeclaration.hasMatch(lines[j])) {
            violations.add(
              '${entity.path}:${i + 1} — @pragma(\'vm:entry-point\') is '
              'immediately followed by a const/final/var at line ${j + 1} '
              '(\'${lines[j].trim()}\'), not the function/class it should '
              'protect. Move the pragma to sit directly above its intended '
              'declaration.',
            );
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: violations.join('\n'),
    );
  });
}
