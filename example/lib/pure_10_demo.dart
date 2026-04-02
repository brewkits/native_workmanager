import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🚀 THE PURE 10 INITIALIZATION
  // - Watchdog: Recovers zombie tasks
  // - Persistence: Atomic File/WAL mode
  // - Privacy: Auto-redaction enabled
  await NativeWorkManager.initialize(
    maxConcurrentTasks: 4,
    cleanupAfterDays: 7,
    debugMode: true,
  );

  runApp(const Pure10DemoApp());
}

class Pure10DemoApp extends StatelessWidget {
  const Pure10DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const TaskDashboard(),
    );
  }
}

class TaskDashboard extends StatefulWidget {
  const TaskDashboard({super.key});

  @override
  State<TaskDashboard> createState() => _TaskDashboardState();
}

class _TaskDashboardState extends State<TaskDashboard> {
  List<TaskRecord> _tasks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshTasks();
  }

  Future<void> _refreshTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await NativeWorkManager.allTasks();
      setState(() => _tasks = tasks);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scheduleSecureTask() async {
    final taskId = 'task-${DateTime.now().millisecondsSinceEpoch}';
    
    // 🛡️ SECURITY DEMO: 
    // We send a sensitive token. The "Pure 10" architecture will 
    // REDACT it before saving to disk.
    await NativeWorkManager.enqueue(
      taskId: taskId,
      trigger: TaskTrigger.oneTime(const Duration(seconds: 5)),
      worker: NativeWorker.httpSync(
        url: 'https://httpbin.org/get',
        headers: {'Authorization': 'Bearer secret-api-token-12345'},
      ),
      tag: 'secure-sync',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Scheduled $taskId with sensitive token')),
    );
    _refreshTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pure 10 Background Engine'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTasks,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? const Center(child: Text('No tasks found in persistent store.'))
              : ListView.builder(
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: _getStatusIcon(task.status),
                        title: Text(task.taskId),
                        subtitle: Text(
                          'Worker: ${task.workerClassName}\n'
                          'Updated: ${task.updatedAt.toLocal()}\n'
                          '🔒 Privacy: Config is redacted in store.',
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          task.status.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(task.status),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scheduleSecureTask,
        label: const Text('Schedule Secure Task'),
        icon: const Icon(Icons.add_moderator),
      ),
    );
  }

  Icon _getStatusIcon(String status) {
    switch (status) {
      case 'completed': return const Icon(Icons.check_circle, color: Colors.green);
      case 'failed': return const Icon(Icons.error, color: Colors.red);
      case 'running': return const Icon(Icons.sync, color: Colors.blue);
      default: return const Icon(Icons.schedule, color: Colors.orange);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'failed': return Colors.red;
      case 'running': return Colors.blue;
      default: return Colors.orange;
    }
  }
}
