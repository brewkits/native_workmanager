import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  // Absolute path to the CLI entrypoint. The tests run the CLI with
  // workingDirectory set to a temp mock project, so a relative 'bin/setup.dart'
  // would resolve against the temp dir and fail with "Could not find file".
  final setupScript = path.join(Directory.current.path, 'bin', 'setup.dart');

  late Directory tempDir;
  late File infoPlist;
  late File androidManifest;

  setUp(() async {
    // 1. Create mock workspace
    tempDir = await Directory.systemTemp.createTemp('native_wm_cli_test_');

    // setup.dart refuses to run unless it sees a pubspec.yaml (Flutter project
    // root guard). Provide a minimal one so the CLI proceeds.
    await File(path.join(tempDir.path, 'pubspec.yaml')).writeAsString('''
name: test_app
''');

    // 2. Create raw Info.plist
    final iosDir = await Directory(path.join(tempDir.path, 'ios', 'Runner'))
        .create(recursive: true);
    infoPlist = File(path.join(iosDir.path, 'Info.plist'));
    await infoPlist.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>test_app</string>
</dict>
</plist>
''');

    // 3. Create raw AndroidManifest.xml
    final androidDir = await Directory(
            path.join(tempDir.path, 'android', 'app', 'src', 'main'))
        .create(recursive: true);
    androidManifest = File(path.join(androidDir.path, 'AndroidManifest.xml'));
    await androidManifest.writeAsString('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:name=".MainApplication">
    </application>
</manifest>
''');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('CLI --ios must inject BGTaskSchedulerPermittedIdentifiers', () async {
    final result = await Process.run(
      'dart',
      ['run', setupScript, '--ios'],
      workingDirectory: tempDir.path,
    );

    expect(result.exitCode, 0, reason: 'CLI failed: ${result.stderr}');

    final modifiedPlist = await infoPlist.readAsString();

    expect(modifiedPlist, contains('UIBackgroundModes'));
    expect(modifiedPlist, contains('fetch'));
    expect(modifiedPlist, contains('processing'));
    expect(modifiedPlist, contains('BGTaskSchedulerPermittedIdentifiers'));
    expect(modifiedPlist, contains('dev.brewkits.native_workmanager.refresh'));
  });

  test('CLI --check must not modify files and return non-zero exit code',
      () async {
    final oldStat = await infoPlist.stat();

    final result = await Process.run(
      'dart',
      ['run', setupScript, '--ios', '--check'],
      workingDirectory: tempDir.path,
    );

    expect(result.exitCode, isNot(0),
        reason: '--check must fail if not setup yet');

    final modifiedStat = await infoPlist.stat();
    expect(oldStat.modified, equals(modifiedStat.modified),
        reason: '--check must NOT write disk');
  });
}
