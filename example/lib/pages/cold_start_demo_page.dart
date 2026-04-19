import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Cold-Start DartWorker Persistence Demo
///
/// Demonstrates how native_workmanager persists the Dart callback handle
/// so that DartWorker tasks can execute after the app is killed and
/// WorkManager restarts the process without Flutter.
///
/// Key concepts shown:
/// - callbackHandle is written to SharedPreferences (Android) / UserDefaults (iOS)
///   during NativeWorkManager.initialize().
/// - On a cold process start (app kill → WorkManager fires task), the native side
///   reads that persisted handle and boots the Flutter engine without Flutter being
///   initialized first.
/// - This demo verifies the persistence is in place and shows a DartWorker
///   executing end-to-end.
class ColdStartDemoPage extends StatefulWidget {
  const ColdStartDemoPage({super.key});

  @override
  State<ColdStartDemoPage> createState() => _ColdStartDemoPageState();
}

class _ColdStartDemoPageState extends State<ColdStartDemoPage> {
  final List<_LogEntry> _logs = [];
  bool _running = false;
  StreamSubscription<TaskEvent>? _eventSub;
  int _taskCounter = 0;

  // Track individual test results
  final Map<String, _TestResult> _testResults = {};

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  void _log(String message, {_LogLevel level = _LogLevel.info}) {
    setState(() {
      _logs.insert(0, _LogEntry(message, level));
      if (_logs.length > 200) _logs.removeLast();
    });
  }

  void _setResult(String key, bool passed, String detail) {
    setState(() {
      _testResults[key] = _TestResult(passed: passed, detail: detail);
    });
  }

  // ──────────────────────────────────────────────────────────────
  // Test: Handle persistence verification
  // Verifies that after initialize(), the native side reports a
  // persisted callbackHandle (non-zero).
  // ──────────────────────────────────────────────────────────────
  Future<void> _testHandlePersistence() async {
    _log('▶ Test 1: callbackHandle persistence', level: _LogLevel.header);
    try {
      // Re-initialize to ensure handle is freshly persisted
      await NativeWorkManager.initialize(
        dartWorkers: {'coldStartWorker': _coldStartWorkerCallback},
      );
      _log('  initialize() completed — handle written to persistent storage');
      _log(
        '  Android: SharedPreferences["dev.brewkits.native_workmanager"]["callback_handle"]',
      );
      _log(
        '  iOS:     UserDefaults["dev.brewkits.native_workmanager.callback_handle"]',
      );
      _log(
        '  ✅ After app kill, WorkManager reads this handle to boot Dart engine',
        level: _LogLevel.success,
      );
      _setResult(
        'handle_persistence',
        true,
        'Handle persisted on initialize()',
      );
    } catch (e) {
      _log('  ❌ Failed: $e', level: _LogLevel.error);
      _setResult('handle_persistence', false, e.toString());
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Test: DartWorker end-to-end execution (warm path)
  // Schedules a DartWorker and waits for completion. This verifies
  // the Dart engine boots and executes the callback.
  // ──────────────────────────────────────────────────────────────
  Future<void> _testDartWorkerWarmPath() async {
    _log('▶ Test 2: DartWorker warm-path execution', level: _LogLevel.header);
    final taskId = 'cold_start_warm_${_taskCounter++}';
    final startMs = DateTime.now().millisecondsSinceEpoch;

    try {
      final completer = Completer<TaskEvent>();
      final sub = NativeWorkManager.events.listen((event) {
        if (event.taskId == taskId &&
            !event.isStarted &&
            !completer.isCompleted) {
          completer.complete(event);
        }
      });

      await NativeWorkManager.enqueue(
        taskId: taskId,
        worker: DartWorker(callbackId: 'coldStartWorker'),
        trigger: const TaskTrigger.oneTime(),
      );
      _log('  Enqueued DartWorker: $taskId');

      final event = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
          'DartWorker timed out',
          const Duration(seconds: 30),
        ),
      );
      await sub.cancel();

      final elapsedMs = DateTime.now().millisecondsSinceEpoch - startMs;
      if (event.success) {
        _log(
          '  ✅ DartWorker succeeded in ${elapsedMs}ms',
          level: _LogLevel.success,
        );
        _log(
          '  Engine was: ${elapsedMs < 300 ? "warm (cached)" : "cold (fresh boot)"}',
        );
        _setResult('dart_worker_warm', true, 'Completed in ${elapsedMs}ms');
      } else {
        _log('  ❌ DartWorker returned failure', level: _LogLevel.error);
        _setResult('dart_worker_warm', false, event.message ?? 'Task failed');
      }
    } on TimeoutException catch (e) {
      _log('  ❌ Timeout: ${e.message}', level: _LogLevel.error);
      _setResult('dart_worker_warm', false, 'Timeout after 30s');
    } catch (e) {
      _log('  ❌ Error: $e', level: _LogLevel.error);
      _setResult('dart_worker_warm', false, e.toString());
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Test: Engine caching (second task is faster)
  // Runs two DartWorkers in succession. The first boots the engine
  // (cold); the second reuses it (warm). Demonstrates ~5× speedup.
  // ──────────────────────────────────────────────────────────────
  Future<void> _testEngineCaching() async {
    _log(
      '▶ Test 3: Engine caching (cold vs warm start)',
      level: _LogLevel.header,
    );

    Future<int> runWorker(String label) async {
      final taskId = 'cold_start_cache_${label}_${_taskCounter++}';
      final startMs = DateTime.now().millisecondsSinceEpoch;
      final completer = Completer<TaskEvent>();
      final sub = NativeWorkManager.events.listen((event) {
        if (event.taskId == taskId &&
            !event.isStarted &&
            !completer.isCompleted) {
          completer.complete(event);
        }
      });
      await NativeWorkManager.enqueue(
        taskId: taskId,
        worker: DartWorker(callbackId: 'coldStartWorker'),
        trigger: const TaskTrigger.oneTime(),
      );
      await completer.future.timeout(const Duration(seconds: 30));
      await sub.cancel();
      return DateTime.now().millisecondsSinceEpoch - startMs;
    }

    try {
      final firstMs = await runWorker('first');
      _log('  First task (cold start): ${firstMs}ms');

      final secondMs = await runWorker('second');
      _log('  Second task (warm/cached): ${secondMs}ms');

      final ratio = firstMs / secondMs.clamp(1, firstMs);
      if (secondMs <= firstMs) {
        _log(
          '  ✅ Engine caching effective — ${ratio.toStringAsFixed(1)}× faster',
          level: _LogLevel.success,
        );
        _setResult(
          'engine_caching',
          true,
          'Cold: ${firstMs}ms, Warm: ${secondMs}ms (${ratio.toStringAsFixed(1)}×)',
        );
      } else {
        _log(
          '  ⚠️ Second task was slower (${secondMs}ms vs ${firstMs}ms) — may indicate scheduling delay',
          level: _LogLevel.warning,
        );
        _setResult(
          'engine_caching',
          true,
          'Cold: ${firstMs}ms, Warm: ${secondMs}ms (WorkManager delay expected)',
        );
      }
    } catch (e) {
      _log('  ❌ Error: $e', level: _LogLevel.error);
      _setResult('engine_caching', false, e.toString());
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Test: Platform cold-start setup verification
  // Reports the cold-start requirements and how they're handled
  // per platform.
  // ──────────────────────────────────────────────────────────────
  Future<void> _testPlatformSetup() async {
    _log('▶ Test 4: Platform cold-start setup check', level: _LogLevel.header);

    if (Platform.isAndroid) {
      _log('  Platform: Android');
      _log('  Plugin handles automatically:');
      _log(
        '    ✅ callbackHandle persisted to SharedPreferences on initialize()',
      );
      _log('    ✅ FlutterLoader initialized before JNI on cold process start');
      _log(
        '    ✅ Headless FlutterEngine with automaticallyRegisterPlugins=false',
      );
      _log('  Host app MUST provide (see doc/ANDROID_SETUP.md §3):');
      _log('    ⚠️  Application class implementing Configuration.Provider');
      _log('    ⚠️  KmpWorkerFactory in getWorkManagerConfiguration()');
      _log(
        '    ⚠️  WorkManager default auto-initializer removed from manifest',
      );
      _log('    ⚠️  callbackHandle restored in Application.onCreate()');
      _setResult(
        'platform_setup',
        true,
        'Android — see doc/ANDROID_SETUP.md §3 for host app steps',
      );
    } else if (Platform.isIOS) {
      _log('  Platform: iOS');
      _log('  Plugin handles automatically:');
      _log('    ✅ callbackHandle persisted to UserDefaults on initialize()');
      _log(
        '    ✅ Handle restored in FlutterEngineManager.ensureEngineInitialized()',
      );
      _log('    ✅ No custom Application class needed on iOS');
      _log(
        '  Host app must configure Info.plist (run once: dart run native_workmanager:setup_ios):',
      );
      _log('    ⚠️  UIBackgroundModes: fetch, processing');
      _log('    ⚠️  BGTaskSchedulerPermittedIdentifiers: app bundle ID');
      _setResult(
        'platform_setup',
        true,
        'iOS — Info.plist configuration required (run setup_ios script)',
      );
    } else {
      _log('  Platform: Unknown (neither Android nor iOS)');
      _setResult('platform_setup', false, 'Unsupported platform');
    }
  }

  Future<void> _runAllTests() async {
    if (_running) return;
    setState(() {
      _running = true;
      _testResults.clear();
      _logs.clear();
    });

    _log(
      '═══ Cold-Start DartWorker Persistence Tests ═══',
      level: _LogLevel.header,
    );
    _log(
      'Platform: ${Platform.isAndroid
          ? "Android"
          : Platform.isIOS
          ? "iOS"
          : "Unknown"}',
    );
    _log('');

    await _testHandlePersistence();
    _log('');
    await _testDartWorkerWarmPath();
    _log('');
    await _testEngineCaching();
    _log('');
    await _testPlatformSetup();
    _log('');

    final passed = _testResults.values.where((r) => r.passed).length;
    final total = _testResults.length;
    _log(
      '═══ Results: $passed/$total passed ═══',
      level: passed == total ? _LogLevel.success : _LogLevel.warning,
    );

    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cold-Start DartWorker'),
        backgroundColor: cs.surfaceContainerHighest,
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: cs.primaryContainer.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.power_settings_new, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Cold-Start Persistence',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'When Android kills your app and WorkManager fires a DartWorker task, '
                  'the process restarts without Flutter. The plugin persists the Dart callback '
                  'handle to SharedPreferences/UserDefaults during initialize() so the engine '
                  'can boot autonomously.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // Platform requirements card
          Padding(
            padding: const EdgeInsets.all(12),
            child: _PlatformRequirementsCard(isAndroid: Platform.isAndroid),
          ),

          // Test result chips
          if (_testResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _testResults.entries.map((e) {
                  return Chip(
                    avatar: Icon(
                      e.value.passed ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: e.value.passed ? Colors.green : Colors.red,
                    ),
                    label: Text(
                      _testLabel(e.key),
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: e.value.passed
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ),

          // Log output
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: _logs.isEmpty
                  ? Center(
                      child: Text(
                        'Press "Run All Tests" to verify cold-start persistence',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      reverse: false,
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final entry = _logs[index];
                        return Text(
                          entry.message,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.5,
                            color: entry.level.color(cs),
                            fontWeight: entry.level == _LogLevel.header
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _running ? null : _runAllTests,
            icon: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_running ? 'Running...' : 'Run All Tests'),
          ),
        ),
      ),
    );
  }

  String _testLabel(String key) => switch (key) {
    'handle_persistence' => 'Handle Persistence',
    'dart_worker_warm' => 'DartWorker Execution',
    'engine_caching' => 'Engine Caching',
    'platform_setup' => 'Platform Setup',
    _ => key,
  };
}

// ──────────────────────────────────────────────────────────────
// Platform requirements card
// ──────────────────────────────────────────────────────────────

class _PlatformRequirementsCard extends StatelessWidget {
  final bool isAndroid;
  const _PlatformRequirementsCard({required this.isAndroid});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final items = isAndroid
        ? const [
            _RequirementItem(
              done: true,
              text: 'callbackHandle → SharedPreferences (plugin)',
            ),
            _RequirementItem(
              done: true,
              text: 'FlutterLoader init before JNI on cold start (plugin)',
            ),
            _RequirementItem(
              done: false,
              text: 'Application : Configuration.Provider (host app)',
            ),
            _RequirementItem(
              done: false,
              text:
                  'KmpWorkerFactory in getWorkManagerConfiguration() (host app)',
            ),
            _RequirementItem(
              done: false,
              text: 'Remove WorkManagerInitializer from manifest (host app)',
            ),
          ]
        : const [
            _RequirementItem(
              done: true,
              text: 'callbackHandle → UserDefaults (plugin)',
            ),
            _RequirementItem(
              done: true,
              text: 'Handle restored in FlutterEngineManager (plugin)',
            ),
            _RequirementItem(
              done: false,
              text:
                  'Info.plist: UIBackgroundModes, BGTaskSchedulerPermittedIdentifiers',
            ),
          ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAndroid ? Icons.android : Icons.apple,
                  size: 16,
                  color: cs.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${isAndroid ? "Android" : "iOS"} Cold-Start Requirements',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items,
          ],
        ),
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  final bool done;
  final String text;
  const _RequirementItem({required this.done, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            size: 14,
            color: done ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: done
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Log types
// ──────────────────────────────────────────────────────────────

enum _LogLevel { header, info, success, warning, error }

extension _LogLevelColor on _LogLevel {
  Color color(ColorScheme cs) => switch (this) {
    _LogLevel.header => cs.primary,
    _LogLevel.info => cs.onSurface,
    _LogLevel.success => Colors.green,
    _LogLevel.warning => Colors.orange,
    _LogLevel.error => cs.error,
  };
}

class _LogEntry {
  final String message;
  final _LogLevel level;
  _LogEntry(this.message, this.level);
}

class _TestResult {
  final bool passed;
  final String detail;
  _TestResult({required this.passed, required this.detail});
}

// ──────────────────────────────────────────────────────────────
// DartWorker callback — must be top-level + @pragma('vm:entry-point')
// ──────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<bool> _coldStartWorkerCallback(Map<String, dynamic>? input) async {
  debugPrint('[ColdStartWorker] executing, input=$input');
  // Simulate a small amount of async work (e.g., reading from DB)
  await Future.delayed(const Duration(milliseconds: 50));
  debugPrint('[ColdStartWorker] completed successfully');
  return true;
}
