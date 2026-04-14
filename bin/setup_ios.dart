import 'dart:io';

void main() async {
  print('🚀 native_workmanager: Configuring iOS Info.plist...');

  final infoPlistFile = File('ios/Runner/Info.plist');
  if (!await infoPlistFile.exists()) {
    print('❌ Error: ios/Runner/Info.plist not found.');
    exit(1);
  }

  String content = await infoPlistFile.readAsString();

  // 1. Check for Background Modes
  if (!content.contains('<key>UIBackgroundModes</key>')) {
    print('➕ Adding UIBackgroundModes (fetch, processing)...');
    content = content.replaceFirst(
      '</dict>',
      '''
	<key>UIBackgroundModes</key>
	<array>
		<string>fetch</string>
		<string>processing</string>
	</array>
</dict>''',
    );
  } else {
    if (!content.contains('<string>fetch</string>')) {
      print('➕ Adding "fetch" to UIBackgroundModes...');
      content = content.replaceFirst(
        '<key>UIBackgroundModes</key>\n\t<array>',
        '<key>UIBackgroundModes</key>\n\t<array>\n\t\t<string>fetch</string>',
      );
    }
    if (!content.contains('<string>processing</string>')) {
      print('➕ Adding "processing" to UIBackgroundModes...');
      content = content.replaceFirst(
        '<key>UIBackgroundModes</key>\n\t<array>',
        '<key>UIBackgroundModes</key>\n\t<array>\n\t\t<string>processing</string>',
      );
    }
  }

  // 2. Check for BGTaskSchedulerPermittedIdentifiers
  final identifiers = [
    'dev.brewkits.native_workmanager.background_task',
    'dev.brewkits.native_workmanager.refresh_task',
  ];

  if (!content.contains('<key>BGTaskSchedulerPermittedIdentifiers</key>')) {
    print('➕ Adding BGTaskSchedulerPermittedIdentifiers...');
    final idString =
        identifiers.map((id) => '\t\t<string>$id</string>').join('\n');
    content = content.replaceFirst(
      '</dict>',
      '''
	<key>BGTaskSchedulerPermittedIdentifiers</key>
	<array>
$idString
	</array>
</dict>''',
    );
  } else {
    for (final id in identifiers) {
      if (!content.contains('<string>$id</string>')) {
        print('➕ Adding missing identifier: $id');
        content = content.replaceFirst(
          '<key>BGTaskSchedulerPermittedIdentifiers</key>\n\t<array>',
          '<key>BGTaskSchedulerPermittedIdentifiers</key>\n\t<array>\n\t\t<string>$id</string>',
        );
      }
    }
  }

  await infoPlistFile.writeAsString(content);
  print('✅ Info.plist updated successfully!');
}
