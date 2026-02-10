import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Native WorkManager
  await NativeWorkManager.initialize(
    dartWorkers: {'customTask': customTaskCallback},
  );

  runApp(const MyApp());
}

/// Custom Dart worker callback.
///
/// This runs in a background isolate when scheduled.
Future<bool> customTaskCallback(Map<String, dynamic>? input) async {
  debugPrint('📱 Dart Worker: Executing custom task with input: $input');

  // Simulate some work
  await Future.delayed(const Duration(seconds: 2));

  debugPrint('📱 Dart Worker: Task completed successfully');
  return true;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native WorkManager Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final List<String> _logs = [];
  int _taskCounter = 0;

  @override
  void initState() {
    super.initState();

    // Listen to task events
    NativeWorkManager.events.listen((event) {
      setState(() {
        _logs.insert(
          0,
          '${event.success ? "✅" : "❌"} Task ${event.taskId}: '
          '${event.message ?? (event.success ? "Success" : "Failed")}',
        );
      });
    });

    _addLog('🚀 Native WorkManager initialized');
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, message);
      if (_logs.length > 20) _logs.removeLast();
    });
  }

  Future<void> _scheduleHttpRequest() async {
    final taskId = 'http-${_taskCounter++}';

    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpRequest(
          url: 'https://httpbin.org/get',
          method: HttpMethod.get,
        ),
      );

      _addLog('📤 Scheduled HTTP GET task: $taskId');
    } catch (e) {
      _addLog('❌ Failed to schedule task: $e');
    }
  }

  Future<void> _scheduleHttpPost() async {
    final taskId = 'post-${_taskCounter++}';

    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpRequest(
          url: 'https://httpbin.org/post',
          method: HttpMethod.post,
          headers: {'Content-Type': 'application/json'},
          body:
              '{"test":"data","timestamp":${DateTime.now().millisecondsSinceEpoch}}',
        ),
      );

      _addLog('📤 Scheduled HTTP POST task: $taskId');
    } catch (e) {
      _addLog('❌ Failed to schedule task: $e');
    }
  }

  Future<void> _scheduleSync() async {
    final taskId = 'sync-${_taskCounter++}';

    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpSync(
          url: 'https://httpbin.org/post',
          requestBody: {
            'lastSync': DateTime.now().millisecondsSinceEpoch,
            'data': ['item1', 'item2', 'item3'],
          },
        ),
        constraints: Constraints.networkRequired,
      );

      _addLog('📤 Scheduled JSON sync task: $taskId');
    } catch (e) {
      _addLog('❌ Failed to schedule task: $e');
    }
  }

  Future<void> _scheduleDartWorker() async {
    final taskId = 'dart-${_taskCounter++}';

    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: DartWorker(
          callbackId: 'customTask',
          input: {
            'timestamp': DateTime.now().toIso8601String(),
            'counter': _taskCounter,
          },
        ),
      );

      _addLog('📤 Scheduled Dart worker task: $taskId');
    } catch (e) {
      _addLog('❌ Failed to schedule task: $e');
    }
  }

  Future<void> _cancelAllTasks() async {
    try {
      await NativeWorkManager.cancelAll();
      _addLog('🗑️ Cancelled all tasks');
    } catch (e) {
      _addLog('❌ Failed to cancel tasks: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Native WorkManager Demo'),
      ),
      body: Column(
        children: [
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Mode 1: Native Workers (Zero Engine)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _scheduleHttpRequest,
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('HTTP GET'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _scheduleHttpPost,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('HTTP POST'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _scheduleSync,
                      icon: const Icon(Icons.sync),
                      label: const Text('JSON Sync'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mode 2: Dart Workers (FlutterEngine)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _scheduleDartWorker,
                  icon: const Icon(Icons.code),
                  label: const Text('Custom Dart Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade100,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _cancelAllTasks,
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Cancel All Tasks'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Logs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Event Log',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _logs.clear();
                    });
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),

          Expanded(
            child: _logs.isEmpty
                ? const Center(
                    child: Text('No events yet. Try scheduling a task!'),
                  )
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        dense: true,
                        title: Text(
                          _logs[index],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
