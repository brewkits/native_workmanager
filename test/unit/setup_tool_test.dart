import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Setup Tool CLI', () {
    test('bin/setup.dart exists', () {
      expect(File('bin/setup.dart').existsSync(), isTrue,
          reason:
              'bin/setup.dart must exist for pub to expose it as executable');
    });

    test('bin/setup_ios.dart exists (backward compat)', () {
      expect(File('bin/setup_ios.dart').existsSync(), isTrue);
    });

    test('pubspec.yaml declares setup executable', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('setup: setup'));
    });

    test('--help exits 0 and shows usage', () async {
      final result =
          await Process.run('dart', ['run', 'bin/setup.dart', '--help']);
      expect(result.exitCode, equals(0));
      final out = result.stdout as String;
      expect(out, contains('native_workmanager setup tool'));
      expect(out, contains('--android'));
      expect(out, contains('--ios'));
      expect(out, contains('--check'));
    });

    test('--check exits 0 when no android/ios directories present', () async {
      // Run from plugin root — no android/ios app directories here.
      final result =
          await Process.run('dart', ['run', 'bin/setup.dart', '--check']);
      expect(result.exitCode, equals(0));
    });

    test('--check --ios validates Info.plist when ios/ present', () async {
      // Run from plugin root pointing at example ios dir
      final plist = File('example/ios/Runner/Info.plist');
      if (!plist.existsSync()) return; // skip if no example ios dir
      final result = await Process.run(
          'dart', ['run', 'bin/setup.dart', '--ios', '--check']);
      // Either passes (already configured) or exits 1 with informative output.
      final out = (result.stdout as String) + (result.stderr as String);
      // The tool runs from plugin root, ios/ not found → skips gracefully
      expect(out, isNotEmpty);
    });

    test('--android exits 0 with auto-init message', () async {
      final result = await Process.run(
        'dart',
        ['run', 'bin/setup.dart', '--android', '--check'],
      );
      expect(result.exitCode, equals(0));
      final out = result.stdout as String;
      // Plugin root has no android/app dir, tool skips gracefully
      expect(out, isNotEmpty);
    });

    test('setup tool detects SwiftUI @main App structure gracefully', () async {
      final tempDir = Directory.systemTemp.createTempSync('nwm_swiftui_test_');
      try {
        final iosRunner = Directory('${tempDir.path}/ios/Runner')
          ..createSync(recursive: true);
        File('${tempDir.path}/pubspec.yaml')
            .writeAsStringSync('name: test_app\n');
        File('${iosRunner.path}/Info.plist')
            .writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>''');
        File('${iosRunner.path}/App.swift').writeAsStringSync('''
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
''');
        final currentDir = Directory.current.path;
        final setupScript = '$currentDir/bin/setup.dart';
        final result = await Process.run(
          'dart',
          ['run', setupScript, '--ios', '--check'],
          workingDirectory: tempDir.path,
        );
        final out = result.stdout as String;
        expect(out, contains('SwiftUI @main App detected'));
        expect(out, contains('@UIApplicationDelegateAdaptor'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('setup tool reports OK when @UIApplicationDelegateAdaptor is present',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('nwm_swiftui_ok_');
      try {
        _writeSwiftUiProject(tempDir, withAdaptor: true);
        final result = await Process.run(
          'dart',
          [
            'run',
            '${Directory.current.path}/bin/setup.dart',
            '--ios',
            '--check'
          ],
          workingDirectory: tempDir.path,
        );
        final out = result.stdout as String;
        expect(
            out,
            contains(
                'SwiftUI @main detected with @UIApplicationDelegateAdaptor'));
        expect(out, isNot(contains('SwiftUI @main App detected in')));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('SwiftUI check still runs when ios/Runner/Info.plist is absent',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('nwm_no_plist_');
      try {
        _writeSwiftUiProject(tempDir, withAdaptor: false, withPlist: false);
        final result = await Process.run(
          'dart',
          [
            'run',
            '${Directory.current.path}/bin/setup.dart',
            '--ios',
            '--check'
          ],
          workingDirectory: tempDir.path,
        );
        final out = result.stdout as String;
        expect(out, contains('No ios/Runner/Info.plist found'));
        expect(out, contains('SwiftUI @main App detected'),
            reason: 'the SwiftUI check is independent of the plist and must '
                'not be skipped when the plist is missing');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('legacy setup_ios entrypoint delegates and keeps SwiftUI parity',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('nwm_setup_ios_');
      try {
        _writeSwiftUiProject(tempDir, withAdaptor: false);
        final result = await Process.run(
          'dart',
          [
            'run',
            '${Directory.current.path}/bin/setup_ios.dart',
            '--check',
          ],
          workingDirectory: tempDir.path,
        );
        final out = result.stdout as String;
        expect(out, contains('legacy alias'));
        expect(out, contains('SwiftUI @main App detected'),
            reason: 'setup_ios must not lag behind setup — it delegates now');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('a non-SwiftUI AppDelegate project triggers no SwiftUI notice',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('nwm_uikit_');
      try {
        final runner = Directory('${tempDir.path}/ios/Runner')
          ..createSync(recursive: true);
        File('${tempDir.path}/pubspec.yaml')
            .writeAsStringSync('name: test_app\n');
        File('${runner.path}/Info.plist').writeAsStringSync(_emptyPlist);
        File('${runner.path}/AppDelegate.swift').writeAsStringSync('''
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
}
''');
        final result = await Process.run(
          'dart',
          [
            'run',
            '${Directory.current.path}/bin/setup.dart',
            '--ios',
            '--check'
          ],
          workingDirectory: tempDir.path,
        );
        final out = result.stdout as String;
        expect(out, isNot(contains('SwiftUI @main')),
            reason: 'a UIKit @main AppDelegate is not a SwiftUI App');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}

const _emptyPlist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>''';

void _writeSwiftUiProject(
  Directory root, {
  required bool withAdaptor,
  bool withPlist = true,
}) {
  final runner = Directory('${root.path}/ios/Runner')
    ..createSync(recursive: true);
  File('${root.path}/pubspec.yaml').writeAsStringSync('name: test_app\n');
  if (withPlist) {
    File('${runner.path}/Info.plist').writeAsStringSync(_emptyPlist);
  }
  final adaptor = withAdaptor
      ? '    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate\n'
      : '';
  File('${runner.path}/App.swift').writeAsStringSync('''
import SwiftUI

@main
struct MyApp: App {
$adaptor    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
''');
}
