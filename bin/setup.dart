// ignore_for_file: avoid_print
import 'dart:io';

/// Unified setup tool for native_workmanager.
///
/// Usage:
///   dart run native_workmanager:setup           # both platforms
///   dart run native_workmanager:setup --android # Android only
///   dart run native_workmanager:setup --ios     # iOS only
///   dart run native_workmanager:setup --check   # validate only, no writes
///   dart run native_workmanager:setup --help
Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printHelp();
    return;
  }

  final checkOnly = args.contains('--check');
  final doAndroid = args.isEmpty || args.contains('--android');
  final doIos = args.isEmpty || args.contains('--ios');

  _banner();

  if (!File('pubspec.yaml').existsSync()) {
    print(
        '⚠️  pubspec.yaml not found. Run this command from a Flutter project root.\n'
        '   Example: cd my_flutter_app && dart run native_workmanager:setup');
    exit(1);
  }

  var hasError = false;

  if (doAndroid) {
    print('\n📱 Android');
    print('─' * 50);
    final ok = await _setupAndroid(checkOnly: checkOnly);
    if (!ok) hasError = true;
  }

  if (doIos) {
    print('\n🍎 iOS');
    print('─' * 50);
    final ok = await _setupIos(checkOnly: checkOnly);
    if (!ok) hasError = true;
  }

  print('\n${'─' * 50}');
  if (hasError) {
    print('⚠️  Setup completed with issues. Review output above.');
    exit(1);
  } else if (checkOnly) {
    print('✅ Validation passed.');
  } else {
    print('✅ Setup complete!');
    print('');
    print('Next steps:');
    print('  1. flutter clean && flutter pub get');
    print('  2. Run your app and test background tasks.');
    print(
        '  3. See doc/ANDROID_SETUP.md / doc/IOS_BACKGROUND_LIMITS.md for advanced config.');
  }
}

// ─── Android ─────────────────────────────────────────────────────────────────

Future<bool> _setupAndroid({required bool checkOnly}) async {
  final manifestFile = File('android/app/src/main/AndroidManifest.xml');
  if (!manifestFile.existsSync()) {
    print('  ℹ️  No android/ directory found — skipping.');
    return true;
  }

  print('  ✅ Auto-init is handled by the plugin manifest (androidx.startup).');
  print('     No AndroidManifest.xml changes required for DartWorker support.');

  // Validate: check that the user hasn't accidentally removed our initializer.
  final content = manifestFile.readAsStringSync();
  final issues = <String>[];

  // Proximity check: only warn if tools:node="remove" appears on a line within 5 lines
  // of the NativeWorkManagerInitializer declaration (avoids false positives from other
  // providers using tools:node="remove" elsewhere in the same manifest).
  if (_elementHasAttribute(
      content, 'NativeWorkManagerInitializer', 'tools:node="remove"')) {
    issues.add(
      'Your AndroidManifest.xml removes NativeWorkManagerInitializer.\n'
      '     DartWorker will not survive app kill. Remove the tools:node="remove" entry,\n'
      '     or add <meta-data android:name="native_workmanager.auto_init" android:value="false" />\n'
      '     and follow the manual setup guide in doc/ANDROID_SETUP.md.',
    );
  }

  // Check if WorkManagerInitializer is re-enabled in the app manifest (it should stay removed).
  if (_elementHasAttribute(content, 'androidx.work.WorkManagerInitializer',
          'android:value="androidx.startup"') &&
      !_elementHasAttribute(content, 'androidx.work.WorkManagerInitializer',
          'tools:node="remove"')) {
    issues.add(
      'Your AndroidManifest.xml re-enables androidx.work.WorkManagerInitializer.\n'
      '     This conflicts with native_workmanager\'s auto-init. Remove the entry or\n'
      '     opt out of auto-init via native_workmanager.auto_init=false meta-data.',
    );
  }

  if (issues.isNotEmpty) {
    for (final issue in issues) {
      print('  ⚠️  $issue');
    }
    return false;
  }

  // Check custom worker setup hint.
  final mainActivityKt = _findMainActivity();
  if (mainActivityKt != null) {
    final activityContent = mainActivityKt.readAsStringSync();
    if (activityContent.contains('SimpleAndroidWorkerFactory.registerWorker') ||
        activityContent.contains('setUserFactory')) {
      print(
          '  ✅ Custom worker registration detected in ${mainActivityKt.path}.');
    }
  }

  print(
      '  ℹ️  Custom workers? Call SimpleAndroidWorkerFactory.registerWorker() in\n'
      '     MainActivity.configureFlutterEngine() before NativeWorkManager.initialize().');

  return true;
}

File? _findMainActivity() {
  final base = Directory('android/app/src/main/kotlin');
  if (!base.existsSync()) return null;
  try {
    return base
        .listSync(recursive: true)
        .whereType<File>()
        .firstWhere((f) => f.path.endsWith('MainActivity.kt'));
  } catch (_) {
    return null;
  }
}

// ─── iOS ─────────────────────────────────────────────────────────────────────

Future<bool> _setupIos({required bool checkOnly}) async {
  final infoPlistFile = File('ios/Runner/Info.plist');
  if (!infoPlistFile.existsSync()) {
    print('  ℹ️  No ios/Runner/Info.plist found — skipping plist checks.');
    // The SwiftUI lifecycle check is independent of the plist — a project with
    // a non-standard plist path is exactly the kind that may use SwiftUI @main.
    _checkSwiftUiMain();
    return true;
  }

  String content = infoPlistFile.readAsStringSync();

  if (!content.contains('</dict>')) {
    print(
        '  ❌ Info.plist appears malformed (no closing </dict> tag). Fix the file manually.');
    _checkSwiftUiMain();
    return false;
  }

  final patches = <String>[];

  // 1. UIBackgroundModes
  if (!content.contains('<key>UIBackgroundModes</key>')) {
    patches.add('Add UIBackgroundModes (fetch, processing)');
    if (!checkOnly) {
      content = content.replaceFirst(
        '</dict>',
        '''\t<key>UIBackgroundModes</key>
\t<array>
\t\t<string>fetch</string>
\t\t<string>processing</string>
\t</array>
</dict>''',
      );
    }
  } else {
    for (final mode in ['fetch', 'processing']) {
      if (!content.contains('<string>$mode</string>')) {
        patches.add('Add "$mode" to UIBackgroundModes');
        if (!checkOnly) {
          // Regex handles both tab-indented and space-indented plists.
          content = content.replaceFirst(
            RegExp(r'<key>UIBackgroundModes</key>\s*<array>'),
            '<key>UIBackgroundModes</key>\n\t<array>\n\t\t<string>$mode</string>',
          );
        }
      }
    }
  }

  // 2. BGTaskSchedulerPermittedIdentifiers
  final identifiers = [
    'dev.brewkits.native_workmanager.task',
    'dev.brewkits.native_workmanager.refresh',
  ];

  if (!content.contains('<key>BGTaskSchedulerPermittedIdentifiers</key>')) {
    patches.add('Add BGTaskSchedulerPermittedIdentifiers');
    if (!checkOnly) {
      final idStr =
          identifiers.map((id) => '\t\t<string>$id</string>').join('\n');
      content = content.replaceFirst(
        '</dict>',
        '''\t<key>BGTaskSchedulerPermittedIdentifiers</key>
\t<array>
$idStr
\t</array>
</dict>''',
      );
    }
  } else {
    for (final id in identifiers) {
      if (!content.contains('<string>$id</string>')) {
        patches.add('Add missing identifier: $id');
        if (!checkOnly) {
          // Use a regex to match the array opening regardless of tab vs space indentation.
          content = content.replaceFirst(
            RegExp(r'<key>BGTaskSchedulerPermittedIdentifiers</key>\s*<array>'),
            '<key>BGTaskSchedulerPermittedIdentifiers</key>\n\t<array>\n\t\t<string>$id</string>',
          );
        }
      }
    }
  }

  var success = true;
  if (patches.isNotEmpty) {
    if (checkOnly) {
      for (final p in patches) {
        print('  ⚠️  Missing: $p');
      }
      print('  Run without --check to apply these changes.');
      success = false;
    } else {
      await infoPlistFile.writeAsString(content);
      for (final p in patches) {
        print('  ➕ $p');
      }
      print('  ✅ Info.plist updated.');
    }
  } else {
    print('  ✅ Info.plist already configured correctly.');
  }

  // 3. Check SwiftUI @main app structure
  _checkSwiftUiMain();

  return success;
}

/// Matches a SwiftUI app declaration: `struct Foo: App {` / `: SwiftUI.App {`,
/// optionally with other protocols in the conformance list.
///
/// Anchored on `struct <Name>:` so a stray `: Application` or a mention inside
/// a comment doesn't count — the loose `contains(': App')` this replaced would
/// match both.
final _swiftUiAppPattern = RegExp(
  r'struct\s+\w+\s*:\s*[^{]*\b(SwiftUI\.)?App\b',
);

void _checkSwiftUiMain() {
  final runnerDir = Directory('ios/Runner');
  if (!runnerDir.existsSync()) return;

  final List<File> swiftFiles;
  try {
    swiftFiles = runnerDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.swift'))
        .toList();
  } on FileSystemException catch (e) {
    print('  ⚠️  Could not scan ios/Runner for SwiftUI @main: ${e.message}');
    return;
  }

  for (final file in swiftFiles) {
    final String text;
    try {
      text = file.readAsStringSync();
    } on FileSystemException {
      continue; // Unreadable file — keep scanning the rest.
    }

    if (!text.contains('@main') || !_swiftUiAppPattern.hasMatch(text)) continue;

    if (text.contains('UIApplicationDelegateAdaptor')) {
      print('  ✅ SwiftUI @main detected with @UIApplicationDelegateAdaptor.');
    } else {
      print('  ℹ️  SwiftUI @main App detected in ${file.path}.\n'
          '     Without an AppDelegate the BGTask launch handlers registered in\n'
          '     NWMBGTaskRegistrar (+load) never attach, so background tasks stay dormant.\n'
          '     Add: @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate');
    }
    return;
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Returns true only when [attribute] appears within ±5 lines of [element] in [content].
/// Prevents false positives where the attribute exists on a completely unrelated XML element.
bool _elementHasAttribute(String content, String element, String attribute) {
  if (!content.contains(element)) return false;
  final lines = content.split('\n');
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains(element)) {
      final start = (i - 5).clamp(0, lines.length);
      final end = (i + 5).clamp(0, lines.length);
      final context = lines.sublist(start, end).join('\n');
      if (context.contains(attribute)) return true;
    }
  }
  return false;
}

void _banner() {
  print('');
  print('  native_workmanager setup');
  print('  ════════════════════════');
}

void _printHelp() {
  print('''
native_workmanager setup tool

Usage:
  dart run native_workmanager:setup           Setup both Android + iOS
  dart run native_workmanager:setup --android Android only
  dart run native_workmanager:setup --ios     iOS only
  dart run native_workmanager:setup --check   Validate without writing files
  dart run native_workmanager:setup --help    Show this help

What it does:

  Android
    Verifies your project is compatible with native_workmanager auto-init.
    DartWorker support after app-kill requires NO manual steps — the plugin
    ships an androidx.startup Initializer that runs automatically.

    Conflict detection:
      - Warns if your manifest accidentally removes NativeWorkManagerInitializer
      - Warns if WorkManagerInitializer is re-enabled (conflicts with auto-init)

    To opt out of auto-init (custom WorkManager setup):
      Add to AndroidManifest.xml <application>:
        <meta-data android:name="native_workmanager.auto_init"
                   android:value="false" />
      Then follow doc/ANDROID_SETUP.md.

  iOS
    Patches ios/Runner/Info.plist with:
      - UIBackgroundModes: fetch, processing
      - BGTaskSchedulerPermittedIdentifiers: 2 required task identifiers
''');
}
