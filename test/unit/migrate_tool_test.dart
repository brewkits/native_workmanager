import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration Tool CLI', () {
    test('bin/migrate.dart exists and is executable', () {
      final file = File('bin/migrate.dart');
      expect(file.existsSync(), isTrue, reason: 'bin/migrate.dart must exist for pub to expose it');
    });

    test('Running migration tool with --dry-run executes successfully', () async {
      // Use the example directory as the target project
      final result = await Process.run('dart', ['run', 'bin/migrate.dart', '--path', 'example', '--dry-run']);
      
      expect(result.exitCode, equals(0), reason: 'Migration tool should exit with code 0 on dry run');
      
      // Ensure the output uses print instead of developer.log (which doesn't show in stdout by default)
      final output = result.stdout as String;
      expect(output, contains('native_workmanager Migration Tool'));
      expect(output, contains('DRY RUN MODE - No files will be modified'));
      expect(output, contains('Files with import:'));
    });
  });
}
