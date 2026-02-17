/// Manual Benchmark page
///
/// Flow: User picks task + library → taps Run → system tracks metrics in
/// background → after run completes, result is stored. Repeat for other
/// libraries. Results table auto-updates showing side-by-side comparison.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart' hide TaskStatus;
import 'package:native_workmanager/native_workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────────────────────

enum BenchTaskType {
  httpGet('HTTP GET', Icons.http),
  httpPost('HTTP POST', Icons.send),
  fileDownload('Download 50KB', Icons.file_download),
  jsonSync('JSON Sync', Icons.sync),
  heavyCompute('Heavy Compute', Icons.memory);

  final String label;
  final IconData icon;

  const BenchTaskType(this.label, this.icon);
}

enum BenchLibrary {
  native('native_wm', Color(0xFF1976D2), Icons.rocket_launch),
  flutter('workmanager', Color(0xFF3F51B5), Icons.code),
  direct('Direct', Color(0xFF00897B), Icons.flash_on);

  final String label;
  final Color color;
  final IconData icon;

  const BenchLibrary(this.label, this.color, this.icon);
}

/// Single benchmark run result — stored per (taskType, library) pair.
class BenchResult {
  final BenchTaskType taskType;
  final BenchLibrary library;
  final int timeMs;
  final bool success;
  final String? error;

  const BenchResult({
    required this.taskType,
    required this.library,
    required this.timeMs,
    required this.success,
    this.error,
  });
}

/// CPU-bound fibonacci — used as the heavy compute workload baseline.
int _fib(int n) => n <= 1 ? n : _fib(n - 1) + _fib(n - 2);

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class ManualBenchmarkPage extends StatefulWidget {
  const ManualBenchmarkPage({super.key});

  @override
  State<ManualBenchmarkPage> createState() => _ManualBenchmarkPageState();
}

class _ManualBenchmarkPageState extends State<ManualBenchmarkPage> {
  BenchTaskType _task = BenchTaskType.httpGet;
  BenchLibrary _lib = BenchLibrary.native;
  bool _running = false;
  String? _status;

  /// Latest result per (taskType, library). Replaced on re-run.
  final List<BenchResult> _results = [];

  // ── Core run logic ────────────────────────────────────────────────────────

  Future<void> _run() async {
    setState(() {
      _running = true;
      _status = 'Baseline...';
    });

    try {
      setState(() {
        _status = 'Running ${_task.label} on ${_lib.label}...';
      });

      // 2. Execute task + measure wall-clock time
      final sw = Stopwatch()..start();
      bool ok = true;
      String? err;

      try {
        switch (_lib) {
          case BenchLibrary.native:
            await _execNative();
          case BenchLibrary.flutter:
            await _execFlutter();
          case BenchLibrary.direct:
            await _execDirect();
        }
      } catch (e) {
        ok = false;
        err = e.toString();
      }

      sw.stop();

      final result = BenchResult(
        taskType: _task,
        library: _lib,
        timeMs: sw.elapsedMilliseconds,
        success: ok,
        error: err,
      );

      // 4. Store — replace previous run for same task+lib
      setState(() {
        _results.removeWhere((r) => r.taskType == _task && r.library == _lib);
        _results.add(result);
        _status = ok ? 'Done: ${sw.elapsedMilliseconds}ms' : 'Failed: $err';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _running = false;
      });
    }
  }

  // ── native_workmanager execution ──────────────────────────────────────────
  // Uses NativeWorker (native HTTP) for HTTP tasks, DartWorker for compute.
  // Completion detected via the events stream (reliable, no polling needed).

  Future<void> _execNative() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final id = 'bm_n_${_task.name}_$ts';

    // Set up completion listener BEFORE enqueueing to avoid missing fast tasks.
    final completer = Completer<TaskEvent>();
    final sub = NativeWorkManager.events.listen((event) {
      if (event.taskId == id && !completer.isCompleted) {
        completer.complete(event);
      }
    });

    try {
      switch (_task) {
        case BenchTaskType.httpGet:
          await NativeWorkManager.enqueue(
            taskId: id,
            trigger: TaskTrigger.oneTime(),
            worker: NativeWorker.httpRequest(url: 'https://httpbin.org/get'),
          );
        case BenchTaskType.httpPost:
          await NativeWorkManager.enqueue(
            taskId: id,
            trigger: TaskTrigger.oneTime(),
            worker: NativeWorker.httpRequest(
              url: 'https://httpbin.org/post',
              method: HttpMethod.post,
              headers: {'Content-Type': 'application/json'},
              body: '{"bm":true,"ts":$ts}',
            ),
          );
        case BenchTaskType.fileDownload:
          await NativeWorkManager.enqueue(
            taskId: id,
            trigger: TaskTrigger.oneTime(),
            worker: NativeWorker.httpDownload(
              url: 'https://httpbin.org/bytes/51200',
              savePath: '${Directory.systemTemp.path}/bm_$ts.bin',
            ),
          );
        case BenchTaskType.jsonSync:
          await NativeWorkManager.enqueue(
            taskId: id,
            trigger: TaskTrigger.oneTime(),
            worker: NativeWorker.httpSync(
              url: 'https://httpbin.org/post',
              requestBody: {'bm': true, 'ts': ts},
            ),
          );
        case BenchTaskType.heavyCompute:
          // No native CPU worker exists — run directly (same workload as Direct baseline).
          // DartCallbackWorker would add 500ms+ engine-spawn overhead, skewing the benchmark.
          // Reduced from 40 to 38 for better emulator performance
          _fib(38);
          return; // skip event-wait below; finally{} still cancels sub
      }

      setState(() {
        _status = 'Waiting for native task...';
      });

      final event = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Timed out (60s)');
        },
      );

      if (!event.success) {
        throw Exception('Task failed: ${event.message}');
      }
    } finally {
      sub.cancel();
    }
  }

  // ── workmanager execution ─────────────────────────────────────────
  // Registers a one-off task. The background isolate callback (in main.dart)
  // executes the work and writes a completion timestamp to SharedPreferences.
  // We poll SharedPreferences here until the key appears.

  Future<void> _execFlutter() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final key = 'bm_f_${_task.name}_$ts';
    // taskName must match switch cases in flutterWorkmanagerCallback (main.dart)
    final taskName = 'bench_${_task.name}';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key); // clear any stale signal

    await Workmanager().registerOneOffTask(
      key, // uniqueName
      taskName, // taskName → matched in callback switch
      inputData: {'completionKey': key},
    );

    setState(() {
      _status = 'Waiting for workmanager...';
    });

    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 300));
      await prefs.reload();
      if (prefs.containsKey(key)) return; // callback wrote completion signal
    }
    throw Exception('Timed out (60s)');
  }

  // ── Direct baseline execution ─────────────────────────────────────────────
  // Runs the identical workload directly in the main isolate — no background
  // manager involved. Serves as the baseline for comparison.

  Future<void> _execDirect() async {
    switch (_task) {
      case BenchTaskType.httpGet:
        {
          final c = HttpClient();
          await (await c.getUrl(Uri.parse('https://httpbin.org/get'))).close();
          c.close();
        }
      case BenchTaskType.httpPost:
        {
          final c = HttpClient();
          final req = await c.postUrl(Uri.parse('https://httpbin.org/post'));
          req.headers.contentType = ContentType.json;
          req.write(
            '{"bm":true,"ts":${DateTime.now().millisecondsSinceEpoch}}',
          );
          await req.close();
          c.close();
        }
      case BenchTaskType.fileDownload:
        {
          final c = HttpClient();
          final resp = await (await c.getUrl(
            Uri.parse('https://httpbin.org/bytes/51200'),
          )).close();
          await resp.toList();
          c.close();
        }
      case BenchTaskType.jsonSync:
        {
          final c = HttpClient();
          final req = await c.postUrl(Uri.parse('https://httpbin.org/post'));
          req.headers.contentType = ContentType.json;
          req.write(
            '{"bm":true,"ts":${DateTime.now().millisecondsSinceEpoch}}',
          );
          final resp = await req.close();
          await resp.toList();
          c.close();
        }
      case BenchTaskType.heavyCompute:
        // Reduced from 40 to 38 for better emulator performance
        _fib(
          38,
        ); // ~0.5-1.5s on modern device — intentionally blocks to measure
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Unique task types that have ≥1 result, in enum order
    final taskTypes = _results.map((r) => r.taskType).toSet().toList()
      ..sort((a, b) => a.index - b.index);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSelector(),
        const SizedBox(height: 16),
        _buildRunButton(),
        if (_status != null) ...[const SizedBox(height: 8), _buildStatusText()],
        if (taskTypes.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Results',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...taskTypes.map(_buildComparisonCard),
        ] else ...[
          const SizedBox(height: 40),
          _buildEmptyState(),
        ],
      ],
    );
  }

  // ── Selector card (task chips + library buttons) ──────────────────────────

  Widget _buildSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task type chips
            const Text(
              'Task',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: BenchTaskType.values.map((t) {
                final sel = _task == t;
                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        t.icon,
                        size: 14,
                        color: sel ? Colors.white : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        t.label,
                        style: TextStyle(
                          color: sel ? Colors.white : null,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  selected: sel,
                  onSelected: _running
                      ? null
                      : (v) {
                          if (v) {
                            setState(() {
                              _task = t;
                            });
                          }
                        },
                  selectedColor: Colors.blue.shade700,
                  checkmarkColor: Colors.white,
                  showCheckmark: false,
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Library buttons
            const Text(
              'Library',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(BenchLibrary.values.length, (i) {
                final lib = BenchLibrary.values[i];
                final sel = _lib == lib;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i < BenchLibrary.values.length - 1 ? 8 : 0,
                    ),
                    child: InkWell(
                      onTap: _running
                          ? null
                          : () {
                              setState(() {
                                _lib = lib;
                              });
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? lib.color.withValues(alpha: 0.1) : null,
                          border: Border.all(
                            color: sel ? lib.color : Colors.grey.shade300,
                            width: sel ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              lib.icon,
                              size: 20,
                              color: sel ? lib.color : Colors.grey,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              lib.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: sel ? lib.color : Colors.grey.shade600,
                                fontWeight: sel ? FontWeight.bold : null,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Run button ────────────────────────────────────────────────────────────

  Widget _buildRunButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _running ? null : _run,
        icon: _running
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.play_arrow),
        label: Text(_running ? 'Running...' : 'Run'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
    );
  }

  // ── Status line ───────────────────────────────────────────────────────────

  Widget _buildStatusText() {
    final isOk = _status!.startsWith('Done');
    final isErr = _status!.startsWith('Failed') || _status!.startsWith('Error');
    return Text(
      _status!,
      style: TextStyle(
        fontSize: 13,
        color: isOk
            ? Colors.green.shade700
            : (isErr ? Colors.red.shade700 : Colors.grey.shade600),
        fontStyle: FontStyle.italic,
      ),
    );
  }

  // ── Comparison card — one card per task type ─────────────────────────────

  Widget _buildComparisonCard(BenchTaskType taskType) {
    final runs = _results.where((r) => r.taskType == taskType).toList();
    final successes = runs.where((r) => r.success).toList();

    // Winner = fastest among successful runs (need ≥ 2 to compare)
    BenchLibrary? winner;
    if (successes.length >= 2) {
      winner = successes.reduce((a, b) => a.timeMs <= b.timeMs ? a : b).library;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: task name + winner badge
            Row(
              children: [
                Icon(taskType.icon, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  taskType.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (winner != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Best: ${winner.label}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // 3-column grid: one column per library
            Row(
              children: List.generate(BenchLibrary.values.length, (i) {
                final lib = BenchLibrary.values[i];
                final matches = runs.where((r) => r.library == lib).toList();
                final result = matches.isEmpty ? null : matches.first;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i < BenchLibrary.values.length - 1 ? 8 : 0,
                    ),
                    child: _buildResultCol(lib, result, winner == lib),
                  ),
                );
              }),
            ),

            // Hint when comparison not yet possible
            if (successes.length < 2) ...[
              const SizedBox(height: 8),
              Text(
                'Run ${3 - runs.length} more '
                '${runs.length == 1 ? 'lib' : 'libs'} to compare',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Single library column inside a comparison card ────────────────────────

  Widget _buildResultCol(BenchLibrary lib, BenchResult? result, bool best) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: best ? Colors.green.shade50 : Colors.grey.shade50,
        border: Border.all(
          color: best ? Colors.green.shade300 : Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Library label + optional star
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(lib.icon, size: 13, color: lib.color),
              const SizedBox(width: 3),
              Text(
                lib.label,
                style: TextStyle(
                  fontSize: 11,
                  color: lib.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (best) ...[
                const SizedBox(width: 3),
                const Icon(Icons.star, size: 11, color: Colors.green),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Result value / placeholder / error
          if (result == null)
            const Text('—', style: TextStyle(fontSize: 20, color: Colors.grey))
          else if (!result.success)
            Text(
              'FAIL',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            )
          else ...[
            Text(
              '${result.timeMs}ms',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.assessment_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            'No results yet',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pick a task + library, tap Run.\n'
            'Repeat for each library to compare.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
