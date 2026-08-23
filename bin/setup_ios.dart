// ignore_for_file: avoid_print
import 'setup.dart' as unified;

/// Legacy iOS-only entrypoint, kept for backward compatibility.
///
/// This used to carry its own copy of the Info.plist patching logic, which
/// meant every improvement to `setup` had to be written twice and, in practice,
/// wasn't — `setup_ios` silently lagged behind (it never gained `--check`, nor
/// the SwiftUI `@main` lifecycle check added in 1.5.0). It now delegates to the
/// unified tool so the two can no longer drift.
///
/// Prefer:
///   dart run native_workmanager:setup --ios
void main(List<String> args) async {
  print('ℹ️  native_workmanager:setup_ios is a legacy alias.\n'
      '   Prefer: dart run native_workmanager:setup --ios\n');

  // Forward user flags (--check, --help, …) and force the iOS-only path.
  final forwarded = <String>['--ios', ...args.where((a) => a != '--ios')];
  await unified.main(forwarded);
}
