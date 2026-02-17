import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'dart:async';

/// Demo screen proving WorkManager 2.10.0+ bug fix
///
/// Original bug: IllegalStateException: Not implemented at CoroutineWorker.getForegroundInfo()
/// Reporter: Abdullah Al-Hasnat
/// Fix: kmpworkmanager 2.3.3 + native_workmanager 1.0.4
class BugFixDemoScreen extends StatefulWidget {
  const BugFixDemoScreen({Key? key}) : super(key: key);

  @override
  State<BugFixDemoScreen> createState() => _BugFixDemoScreenState();
}

class _BugFixDemoScreenState extends State<BugFixDemoScreen> {
  final List<TestResult> _results = [];
  bool _isRunning = false;
  StreamSubscription? _eventsSub;
  final Set<String> _pendingTasks = {};

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }

  void _setupListeners() {
    _eventsSub = NativeWorkManager.events.listen((event) {
      if (!_pendingTasks.contains(event.taskId)) return;

      setState(() {
        final index = _results.indexWhere((r) => r.taskId == event.taskId);
        if (index != -1) {
          _results[index] = _results[index].copyWith(
            status: event.success ? TestStatus.passed : TestStatus.failed,
            output: event.message ?? (event.success ? 'Success' : 'Failed'),
            endTime: DateTime.now(),
          );
          _pendingTasks.remove(event.taskId);
        }
      });
    });
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isRunning = true;
      _results.clear();
      _pendingTasks.clear();
    });

    await _testExpeditedOneTimeTask();
    await Future.delayed(const Duration(seconds: 3));

    await _testConcurrentExpeditedTasks();
    await Future.delayed(const Duration(seconds: 5));

    await _testTaskChain();

    setState(() => _isRunning = false);

    // Wait a bit for pending tasks
    await Future.delayed(const Duration(seconds: 5));

    if (mounted) _showSummaryDialog();
  }

  Future<void> _testExpeditedOneTimeTask() async {
    final taskId = 'bug-fix-expedited-${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _results.add(TestResult(
        testName: 'OneTime Expedited Task',
        taskId: taskId,
        description: 'Original crash scenario - WorkManager 2.10.0+ calls getForegroundInfoAsync()',
        status: TestStatus.running,
        startTime: DateTime.now(),
      ));
      _pendingTasks.add(taskId);
    });

    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/delay/1',
          method: HttpMethod.get,
        ),
        constraints: const Constraints(requiresNetwork: true),
      );
    } catch (e) {
      setState(() {
        final index = _results.indexWhere((r) => r.taskId == taskId);
        if (index != -1) {
          _results[index] = _results[index].copyWith(
            status: TestStatus.failed,
            output: 'Scheduling failed: $e',
            endTime: DateTime.now(),
          );
        }
        _pendingTasks.remove(taskId);
      });
    }
  }

  Future<void> _testConcurrentExpeditedTasks() async {
    final taskIds = List.generate(3, (i) => 'bug-fix-concurrent-${DateTime.now().millisecondsSinceEpoch}-$i');

    for (var i = 0; i < taskIds.length; i++) {
      setState(() {
        _results.add(TestResult(
          testName: 'Concurrent Task #${i + 1}',
          taskId: taskIds[i],
          description: 'Concurrent expedited task with ${i + 1}s delay',
          status: TestStatus.running,
          startTime: DateTime.now(),
        ));
        _pendingTasks.add(taskIds[i]);
      });

      try {
        await NativeWorkManager.enqueue(
          taskId: taskIds[i],
          trigger: TaskTrigger.oneTime(),
          worker: HttpRequestWorker(
            url: 'https://httpbin.org/delay/${i + 1}',
            method: HttpMethod.get,
          ),
          constraints: const Constraints(requiresNetwork: true),
        );
      } catch (e) {
        setState(() {
          final index = _results.indexWhere((r) => r.taskId == taskIds[i]);
          if (index != -1) {
            _results[index] = _results[index].copyWith(
              status: TestStatus.failed,
              output: 'Scheduling failed: $e',
              endTime: DateTime.now(),
            );
          }
          _pendingTasks.remove(taskIds[i]);
        });
      }
    }
  }

  Future<void> _testTaskChain() async {
    final task1 = 'bug-fix-chain-1-${DateTime.now().millisecondsSinceEpoch}';
    final task2 = 'bug-fix-chain-2-${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _results.add(TestResult(
        testName: 'Task Chain Step 1',
        taskId: task1,
        description: 'First task in chain - expedited HTTP GET',
        status: TestStatus.running,
        startTime: DateTime.now(),
      ));
      _results.add(TestResult(
        testName: 'Task Chain Step 2',
        taskId: task2,
        description: 'Second task in chain - expedited HTTP POST',
        status: TestStatus.running,
        startTime: DateTime.now(),
      ));
      _pendingTasks.add(task1);
      _pendingTasks.add(task2);
    });

    try {
      await NativeWorkManager.beginWith(
        TaskRequest(
          id: task1,
          worker: HttpRequestWorker(
            url: 'https://httpbin.org/get',
            method: HttpMethod.get,
          ),
        ),
      )
          .then(
        TaskRequest(
          id: task2,
          worker: HttpRequestWorker(
            url: 'https://httpbin.org/post',
            method: HttpMethod.post,
            body: '{"step": 2}',
          ),
        ),
      )
          .enqueue();
    } catch (e) {
      setState(() {
        final index1 = _results.indexWhere((r) => r.taskId == task1);
        final index2 = _results.indexWhere((r) => r.taskId == task2);
        if (index1 != -1) {
          _results[index1] = _results[index1].copyWith(
            status: TestStatus.failed,
            output: 'Scheduling failed: $e',
            endTime: DateTime.now(),
          );
        }
        if (index2 != -1) {
          _results[index2] = _results[index2].copyWith(
            status: TestStatus.failed,
            output: 'Scheduling failed: $e',
            endTime: DateTime.now(),
          );
        }
        _pendingTasks.remove(task1);
        _pendingTasks.remove(task2);
      });
    }
  }

  void _showSummaryDialog() {
    final passed = _results.where((r) => r.status == TestStatus.passed).length;
    final failed = _results.where((r) => r.status == TestStatus.failed).length;
    final running = _results.where((r) => r.status == TestStatus.running).length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bug Fix Test Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ Passed: $passed'),
            Text('❌ Failed: $failed'),
            Text('⏳ Running: $running'),
            const SizedBox(height: 16),
            if (failed == 0 && passed > 0)
              const Text(
                '🎉 All tests passed!\n\nWorkManager 2.10.0+ bug is FIXED.',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              )
            else if (running > 0)
              Text(
                'Some tests are still running.\nWait for completion.',
                style: TextStyle(color: Colors.orange[700]),
              )
            else if (failed > 0)
              Text(
                '❌ Some tests failed.\nCheck logs for details.',
                style: TextStyle(color: Colors.red[700]),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WorkManager 2.10.0+ Bug Fix Demo'),
        backgroundColor: Colors.green[700],
      ),
      body: Column(
        children: [
          // Bug Info Card
          Card(
            margin: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bug_report, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Original Bug',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'IllegalStateException: Not implemented\n'
                    'at androidx.work.CoroutineWorker.getForegroundInfo(CoroutineWorker.kt:92)',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Fix',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• kmpworkmanager 2.3.3: Added getForegroundInfo() override\n'
                    '• native_workmanager 1.0.4: Upgraded to WM 2.10.1\n'
                    '• Fixed chain heavy-task routing bug',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reported by: Abdullah Al-Hasnat',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),

          // Test Results
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Tap "Run All Tests" to verify the bug fix.\n\n'
                        'This will schedule expedited tasks that previously crashed '
                        'on WorkManager 2.10.0+.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return _TestResultCard(result: result);
                    },
                  ),
          ),

          // Run Tests Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isRunning ? null : _runAllTests,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                minimumSize: const Size(double.infinity, 56),
              ),
              child: _isRunning
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Running Tests...', style: TextStyle(fontSize: 16)),
                      ],
                    )
                  : const Text('Run All Tests', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestResultCard extends StatelessWidget {
  final TestResult result;

  const _TestResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIcon(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.testName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              result.description,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            if (result.output != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  result.output!,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (result.endTime != null) ...[
              const SizedBox(height: 8),
              Text(
                'Duration: ${result.endTime!.difference(result.startTime).inSeconds}s',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (result.status) {
      case TestStatus.running:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case TestStatus.passed:
        return Icon(Icons.check_circle, color: Colors.green[700], size: 24);
      case TestStatus.failed:
        return Icon(Icons.error, color: Colors.red[700], size: 24);
    }
  }
}

enum TestStatus { running, passed, failed }

class TestResult {
  final String testName;
  final String taskId;
  final String description;
  final TestStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final String? output;

  TestResult({
    required this.testName,
    required this.taskId,
    required this.description,
    required this.status,
    required this.startTime,
    this.endTime,
    this.output,
  });

  TestResult copyWith({
    String? testName,
    String? taskId,
    String? description,
    TestStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    String? output,
  }) {
    return TestResult(
      testName: testName ?? this.testName,
      taskId: taskId ?? this.taskId,
      description: description ?? this.description,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      output: output ?? this.output,
    );
  }
}
