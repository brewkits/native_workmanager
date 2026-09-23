import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards issue #76: the plugin must not apply the Kotlin Gradle Plugin (KGP)
/// in `android/build.gradle`.
///
/// Flutter (>= 3.44) decides whether a plugin "applies KGP" by running a regex
/// over the build file's TEXT, not by looking at what Gradle actually applied.
/// A match gets the plugin named in a build warning on AGP 9, and future
/// Flutter versions turn that warning into a hard build failure. Worse, with
/// `android.builtInKotlin=true` an applied `kotlin-android` already fails the
/// build today ("Failed to apply plugin 'kotlin-android'"). Wrapping the apply
/// in an `if` does not help — the regex still matches the indented line (that
/// is exactly why flutter_workmanager 0.10.x is still flagged).
///
/// Removing KGP is only safe because Flutter >= 3.44 applies it to plugin
/// subprojects itself when built-in Kotlin is off — below 3.44 nothing does,
/// and the plugin's Kotlin silently stops compiling. So the Flutter floor in
/// pubspec.yaml is checked here too.
void main() {
  File repoFile(String relative) {
    final direct = File(relative);
    if (direct.existsSync()) return direct;
    final nested = File('../$relative');
    if (nested.existsSync()) return nested;
    fail('Could not locate $relative from ${Directory.current.path}');
  }

  // Copied from flutter_tools FlutterPluginUtils.kgpRegexGroovy (3.47.5), with
  // the inline `(?m)` flags moved into `multiLine: true` (Dart has no inline
  // flags).
  final kgpRegexGroovy = RegExp(
    r'''^[ \t]*apply[ \t]+plugin[ \t]*:[ \t]*(['"])(?:kotlin-android|org\.jetbrains\.kotlin\.android)\1|^[ \t]*plugins[ \t]*\{[^{}]*?(?<=[\n{])[ \t]*(?:id|alias)(?:[ \t]*\(\s*|[ \t]+)(['"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['"]|libs\.plugins\.(?:android|kotlin)\.android)(?:\s*\))?(?=[ \t]*(\n|$|\}))''',
    multiLine: true,
  );

  test('issue_76: the KGP detection regex still catches the old apply line',
      () {
    // Without this, a regex that silently matches nothing would make the
    // real check below pass vacuously.
    expect(kgpRegexGroovy.hasMatch('apply plugin: "kotlin-android"\n'), isTrue);
    expect(
      kgpRegexGroovy
          .hasMatch('if (!builtIn) {\n    apply plugin: "kotlin-android"\n}\n'),
      isTrue,
    );
    expect(
      kgpRegexGroovy
          .hasMatch("plugins {\n    id 'org.jetbrains.kotlin.android'\n}\n"),
      isTrue,
    );
  });

  test('issue_76: android/build.gradle does not apply the Kotlin Gradle Plugin',
      () {
    final gradle = repoFile('android/build.gradle').readAsStringSync();
    // Strip line comments so the explanatory comment in build.gradle, which
    // quotes the removed line, does not trip the check.
    final code = gradle
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
        .join('\n');
    expect(kgpRegexGroovy.hasMatch(code), isFalse,
        reason: 'Flutter flags this plugin as applying KGP (issue #76).');
    expect(code.contains('kotlinOptions'), isFalse,
        reason:
            'kotlinOptions {} is gone in AGP 9 — use kotlin.compilerOptions.');
    expect(code.contains('compilerOptions'), isTrue,
        reason:
            'jvmTarget must still be pinned to 17 via kotlin.compilerOptions.');
  });

  test('issue_76: pubspec requires Flutter >= 3.44 (first to auto-apply KGP)',
      () {
    final pubspec = repoFile('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'''^\s*flutter:\s*['"]>=(\d+)\.(\d+)''', multiLine: true)
            .firstMatch(pubspec);
    expect(match, isNotNull, reason: 'environment.flutter lower bound missing');
    final major = int.parse(match!.group(1)!);
    final minor = int.parse(match.group(2)!);
    expect(major > 3 || (major == 3 && minor >= 44), isTrue,
        reason: 'Below Flutter 3.44 nothing applies KGP to this plugin, so its '
            'Kotlin sources would not compile.');
  });
}
