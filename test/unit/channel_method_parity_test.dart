import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against the single most dangerous defect class this plugin has:
/// **Dart invoking a method-channel name that a platform never registers.**
///
/// It fails at runtime with `MissingPluginException`, only on the platform that
/// is missing it, only when a user actually calls that API — so unit tests,
/// analysis, and both native compilers all stay perfectly green while a public
/// API is dead in production.
///
/// Two shipped instances found on 2026-09-06:
///
///  * `getTasksByStatus` — invoked by Dart, registered by **neither** platform.
///    Took `pauseAll()` and `resumeAll()` down with it. A unit test mocked the
///    missing method and asserted on the mock's own reply, so it stayed green.
///  * `offlineQueueEnqueue` — Dart and Android agreed on the name; iOS spelled
///    it `enqueueOfflineQueue`, the words the other way round. Offline-queue
///    enqueue had never worked on iOS.
///
/// Neither was reachable by any host-side test, because a mock will happily
/// answer a method no platform implements. The only reliable check is to read
/// the real dispatch tables, which is what this does — the same approach
/// `ManifestGuardTest` uses for AndroidManifest.xml.
///
/// If this test fails, do not silence it by adding the name to [_notOnMainChannel].
/// Either register a handler on the platform that is missing one, or stop Dart
/// invoking it.
void main() {
  /// Methods Dart sends on a channel other than the main plugin channel, or that
  /// are deliberately platform-specific. Each needs a reason.
  const Map<String, String> _notOnMainChannel = {
    // Sent on MethodChannel('dev.brewkits/dart_worker_channel') from the headless
    // isolate, handled by FlutterEngineManager on both platforms — not by the
    // plugin's own onMethodCall.
    'dartReady': 'dart_worker_channel — FlutterEngineManager handles it',
    'reportProgress': 'dart_worker_channel — FlutterEngineManager handles it',
    'isTaskCancelled': 'dart_worker_channel — FlutterEngineManager handles it '
        '(iOS also answers it from the main-isolate dartWorkerChannel handler '
        'in NativeWorkmanagerPlugin.swift, issue #66)',
  };

  /// Resolves a repo path whether the test runs from the repo root or elsewhere.
  File _repoFile(String relative) {
    final direct = File(relative);
    if (direct.existsSync()) return direct;
    final nested = File('../$relative');
    if (nested.existsSync()) return nested;
    fail('Could not locate $relative from ${Directory.current.path}');
  }

  /// Every method name Dart invokes across lib/.
  Set<String> _dartInvokedMethods() {
    final dir =
        Directory('lib').existsSync() ? Directory('lib') : Directory('../lib');
    final pattern = RegExp(r"""invokeMethod(?:<[^>]*>)?\(\s*'([a-zA-Z_]+)'""");
    final found = <String>{};
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final m in pattern.allMatches(entity.readAsStringSync())) {
        found.add(m.group(1)!);
      }
    }
    return found;
  }

  Set<String> _androidHandledMethods() {
    final src = _repoFile(
      'android/src/main/kotlin/dev/brewkits/native_workmanager/'
      'NativeWorkmanagerPlugin.kt',
    ).readAsStringSync();
    return RegExp(r'"([a-zA-Z_]+)"\s*->')
        .allMatches(src)
        .map((m) => m.group(1)!)
        .toSet();
  }

  Set<String> _iosHandledMethods() {
    final src = _repoFile(
      'ios/native_workmanager/Sources/native_workmanager/'
      'NativeWorkmanagerPlugin.swift',
    ).readAsStringSync();
    return RegExp(r'case\s+"([a-zA-Z_]+)"')
        .allMatches(src)
        .map((m) => m.group(1)!)
        .toSet();
  }

  group('method-channel parity', () {
    late Set<String> dartMethods;

    setUpAll(() {
      dartMethods = _dartInvokedMethods()
        ..removeWhere(_notOnMainChannel.containsKey);
    });

    test('the scan actually found the Dart call sites', () {
      // Guards the guard: a regex that silently matches nothing would make every
      // assertion below vacuously pass.
      expect(
        dartMethods.length,
        greaterThan(10),
        reason: 'expected to find the plugin\'s method-channel calls in lib/ — '
            'if this is near zero the regex has drifted from the call syntax',
      );
      expect(dartMethods, contains('enqueue'));
      expect(dartMethods, contains('cancel'));
    });

    test('Android registers a handler for every method Dart invokes', () {
      final android = _androidHandledMethods();
      final missing = dartMethods.difference(android).toList()..sort();

      expect(
        missing,
        isEmpty,
        reason: 'These are invoked from Dart but have no Android handler, so '
            'they throw MissingPluginException at runtime: $missing',
      );
    });

    test('iOS registers a handler for every method Dart invokes', () {
      final ios = _iosHandledMethods();
      final missing = dartMethods.difference(ios).toList()..sort();

      expect(
        missing,
        isEmpty,
        reason: 'These are invoked from Dart but have no iOS handler, so they '
            'throw MissingPluginException at runtime: $missing',
      );
    });

    test('the two platforms agree on which methods they handle', () {
      // Catches the offlineQueueEnqueue shape directly: a name present on one
      // platform and spelled differently on the other. Only names Dart actually
      // invokes are compared — each platform is free to carry extra internal
      // cases (iOS has debug probes Android does not).
      final android = _androidHandledMethods();
      final ios = _iosHandledMethods();

      final androidOnly = dartMethods.intersection(android).difference(ios);
      final iosOnly = dartMethods.intersection(ios).difference(android);

      expect(
        {...androidOnly, ...iosOnly},
        isEmpty,
        reason: 'Cross-platform parity gap. Android-only: $androidOnly, '
            'iOS-only: $iosOnly',
      );
    });

    test('every exemption is a real Dart call site with a stated reason', () {
      // Stops the allowlist becoming a dumping ground: an entry that no longer
      // matches a real call must be deleted, not left to hide a future gap.
      final allDartMethods = _dartInvokedMethods();
      for (final entry in _notOnMainChannel.entries) {
        expect(
          allDartMethods,
          contains(entry.key),
          reason: '"${entry.key}" is exempted but Dart no longer invokes it — '
              'delete the exemption',
        );
        expect(entry.value, isNotEmpty);
      }
    });
  });

  // Everything above is exempted from the main-channel checks (they're sent on
  // MethodChannel('dev.brewkits/dart_worker_channel') instead), which left them
  // with no automated check at all — the exact shape this whole file exists to
  // catch, just one channel over. Closed 2026-09-10 while reviewing #66/#68:
  // 'isTaskCancelled' had a written-out "iOS also answers it from ..." comment
  // that no test actually verified.
  group('dart_worker_channel parity (the gap _notOnMainChannel left open)', () {
    Set<String> androidHandledMethods() {
      final src = _repoFile(
        'android/src/main/kotlin/dev/brewkits/native_workmanager/'
        'engine/FlutterEngineManager.kt',
      ).readAsStringSync();
      return RegExp(r'"([a-zA-Z_]+)"\s*->')
          .allMatches(src)
          .map((m) => m.group(1)!)
          .toSet();
    }

    Set<String> iosHeadlessHandledMethods() {
      final src = _repoFile(
        'ios/native_workmanager/Sources/native_workmanager/'
        'engine/FlutterEngineManager.swift',
      ).readAsStringSync();
      return RegExp(r'call\.method\s*==\s*"([a-zA-Z_]+)"')
          .allMatches(src)
          .map((m) => m.group(1)!)
          .toSet();
    }

    Set<String> iosForegroundHandledMethods() {
      // NativeWorkmanagerPlugin.swift's own dartWorkerChannel — the main-isolate
      // handler for foreground/test-mode DartWorker callbacks (see
      // CLAUDE.md "Execution Modes"). Android has no equivalent: it always
      // executes DartWorker callbacks through the headless engine above.
      final src = _repoFile(
        'ios/native_workmanager/Sources/native_workmanager/'
        'NativeWorkmanagerPlugin.swift',
      ).readAsStringSync();
      final marker = src.indexOf('dartWorkerChannel?.setMethodCallHandler');
      expect(
        marker,
        greaterThanOrEqualTo(0),
        reason: 'NativeWorkmanagerPlugin.swift no longer wires the foreground '
            'dartWorkerChannel handler — if this moved, update this test\'s '
            'anchor rather than deleting the check',
      );
      final handlerBody = src.substring(marker);
      return RegExp(r'case\s+"([a-zA-Z_]+)"')
          .allMatches(handlerBody)
          .map((m) => m.group(1)!)
          .toSet();
    }

    // dartReady only matters to the headless engine (it signals the isolate is
    // up before enqueuing work) — the foreground path has no isolate to wait
    // for, so it is deliberately absent there.
    const headlessOnlyMethods = {'dartReady'};
    // reportProgress and isTaskCancelled must work identically no matter which
    // engine a DartWorker callback happens to be running on.
    const bothEnginesMethods = {'reportProgress', 'isTaskCancelled'};

    test('Android handles every dart_worker_channel method', () {
      final handled = androidHandledMethods();
      final missing =
          {...headlessOnlyMethods, ...bothEnginesMethods}.difference(handled);
      expect(
        missing,
        isEmpty,
        reason: 'dev.brewkits/dart_worker_channel methods with no Android '
            'FlutterEngineManager.kt handler: $missing',
      );
    });

    test('iOS headless engine handles every dart_worker_channel method', () {
      final handled = iosHeadlessHandledMethods();
      final missing =
          {...headlessOnlyMethods, ...bothEnginesMethods}.difference(handled);
      expect(
        missing,
        isEmpty,
        reason: 'dev.brewkits/dart_worker_channel methods with no iOS '
            'FlutterEngineManager.swift handler: $missing',
      );
    });

    test('iOS foreground engine handles the methods it must', () {
      final handled = iosForegroundHandledMethods();
      final missing = bothEnginesMethods.difference(handled);
      expect(
        missing,
        isEmpty,
        reason: 'dev.brewkits/dart_worker_channel methods with no iOS '
            'foreground dartWorkerChannel handler in '
            'NativeWorkmanagerPlugin.swift: $missing — a callback running in '
            'foreground/test mode (see CLAUDE.md "Execution Modes") would '
            'throw MissingPluginException calling this',
      );
    });
  });
}
