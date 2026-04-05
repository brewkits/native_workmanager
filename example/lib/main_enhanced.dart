import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Native WorkManager with Dart workers
  await NativeWorkManager.initialize(
    dartWorkers: {
      'customTask': customTaskCallback,
      'heavyTask': heavyTaskCallback,
      'photoBackup': photoBackupCallback,
    },
  );

  runApp(const MyApp());
}

/// Custom Dart worker callback.
Future<bool> customTaskCallback(Map<String, dynamic>? input) async {
  debugPrint('📱 Dart Worker: Executing custom task with input: $input');
  await Future.delayed(const Duration(seconds: 2));
  debugPrint('📱 Dart Worker: Task completed successfully');
  return true;
}

/// Heavy task callback (for isHeavyTask demo).
Future<bool> heavyTaskCallback(Map<String, dynamic>? input) async {
  debugPrint('⚙️ Heavy Task: Starting long-running work...');

  // Simulate heavy processing
  for (int i = 0; i < 10; i++) {
    await Future.delayed(const Duration(seconds: 1));
    debugPrint('⚙️ Heavy Task: Progress ${(i + 1) * 10}%');
  }

  debugPrint('⚙️ Heavy Task: Completed!');
  return true;
}

/// Photo backup callback (for ContentUri demo).
Future<bool> photoBackupCallback(Map<String, dynamic>? input) async {
  debugPrint('📸 Photo Backup: New photo detected!');
  debugPrint('📸 Photo Backup: URI: ${input?['uri']}');

  // Simulate backup process
  await Future.delayed(const Duration(seconds: 3));

  debugPrint('📸 Photo Backup: Backup completed');
  return true;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native WorkManager v1.1.0 Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _logs = [];
  int _taskCounter = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);

    // Listen to task events
    NativeWorkManager.events.listen((event) {
      setState(() {
        _logs.insert(
          0,
          '${_formatTime(event.timestamp)} '
          '${event.success ? "✅" : "❌"} '
          '${event.taskId}: '
          '${event.message ?? (event.success ? "Success" : "Failed")}',
        );
        if (_logs.length > 50) _logs.removeLast();
      });
    });

    _addLog('🚀 Native WorkManager v1.1.0 initialized (100% KMP parity)');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '${_formatTime(DateTime.now())} $message');
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 1: Basic Tasks (Native Workers)
  // ═══════════════════════════════════════════════════════════════

  Future<void> _scheduleHttpGet() async {
    final taskId = 'http-get-${_taskCounter++}';
    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/get',
          method: HttpMethod.get,
        ),
      );
      _addLog('📤 Scheduled: HTTP GET ($taskId)');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _scheduleHttpPost() async {
    final taskId = 'http-post-${_taskCounter++}';
    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/post',
          method: HttpMethod.post,
          headers: const {'Content-Type': 'application/json'},
          body: '{"timestamp":${DateTime.now().millisecondsSinceEpoch}}',
        ),
      );
      _addLog('📤 Scheduled: HTTP POST ($taskId)');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _scheduleSync() async {
    final taskId = 'sync-${_taskCounter++}';
    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: HttpSyncWorker(
          url: 'https://httpbin.org/post',
          method: HttpMethod.post,
          requestBody: {
            'lastSync': DateTime.now().millisecondsSinceEpoch,
            'data': ['item1', 'item2', 'item3'],
          },
        ),
        constraints: const Constraints(requiresNetwork: true),
      );
      _addLog('📤 Scheduled: JSON Sync ($taskId)');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 2: v1.1.0 Features - BackoffPolicy
  // ═══════════════════════════════════════════════════════════════

  Future<void> _scheduleWithExponentialBackoff() async {
    final taskId = 'backoff-exp-${_taskCounter++}';
    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/status/500', // Will fail
          method: HttpMethod.get,
        ),
        constraints: const Constraints(
          requiresNetwork: true,
          backoffPolicy: BackoffPolicy.exponential,
          backoffDelayMs: 10000, // 10s, 20s, 40s, 80s...
        ),
      );
      _addLog('📤 Scheduled: Exponential Backoff ($taskId)');
      _addLog('⏰ Retry delays: 10s → 20s → 40s → 80s');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _scheduleWithLinearBackoff() async {
    final taskId = 'backoff-lin-${_taskCounter++}';
    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/status/503', // Will fail
          method: HttpMethod.get,
        ),
        constraints: const Constraints(
          requiresNetwork: true,
          backoffPolicy: BackoffPolicy.linear,
          backoffDelayMs: 15000, // 15s, 15s, 15s, 15s...
        ),
      );
      _addLog('📤 Scheduled: Linear Backoff ($taskId)');
      _addLog('⏰ Retry delays: 15s → 15s → 15s → 15s');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 3: v1.1.0 Features - ContentUri (Android only)
  // ═══════════════════════════════════════════════════════════════

  Future<void> _schedulePhotoBackup() async {
    final taskId = 'photo-backup';
    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.contentUri(
          uri: Uri.parse('content://media/external/images/media'),
          triggerForDescendants: true,
        ),
        worker: DartWorker(
          callbackId: 'photoBackup',
          input: {'destination': 'cloud-storage'},
        ),
        constraints: const Constraints(
          requiresUnmeteredNetwork: true, // WiFi only
          requiresCharging: true,
        ),
      );
      _addLog('📤 Scheduled: Photo Backup (ContentUri)');
      _addLog('📸 Will trigger when new photo is taken (Android)');
    } catch (e) {
      _addLog('❌ Error: $e');
      if (e.toString().contains('UNSUPPORTED_IOS')) {
        _addLog('ℹ️ ContentUri is Android-only feature');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 4: Advanced Constraints
  // ═══════════════════════════════════════════════════════════════

  Future<void> _scheduleHeavyTask() async {
    final taskId = 'heavy-${_taskCounter++}';
    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'heavyTask'),
        constraints: const Constraints(
          isHeavyTask: true, // Uses ForegroundService on Android
          requiresCharging: true,
          requiresUnmeteredNetwork: true,
        ),
      );
      _addLog('📤 Scheduled: Heavy Task ($taskId)');
      _addLog('⚙️ Will show notification on Android (ForegroundService)');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _scheduleWithQoS() async {
    final taskId = 'qos-${_taskCounter++}';
    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'customTask'),
        constraints: const Constraints(
          qos: QoS.utility, // Low priority on iOS
        ),
      );
      _addLog('📤 Scheduled: QoS Task ($taskId)');
      _addLog('📱 Priority: Utility (iOS only)');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 5: Task Chains
  // ═══════════════════════════════════════════════════════════════

  Future<void> _scheduleSequentialChain() async {
    try {
      await NativeWorkManager.beginWith(
            TaskRequest(
              id: 'chain-step-1',
              worker: HttpRequestWorker(
                url: 'https://httpbin.org/get',
                method: HttpMethod.get,
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'chain-step-2',
              worker: HttpSyncWorker(
                url: 'https://httpbin.org/post',
                method: HttpMethod.post,
                requestBody: {'step': 2},
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'chain-step-3',
              worker: DartWorker(callbackId: 'customTask'),
            ),
          )
          .named('sequential-chain')
          .enqueue();

      _addLog('📤 Scheduled: Sequential Chain');
      _addLog('⛓️ Step 1 → Step 2 → Step 3');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _scheduleParallelChain() async {
    try {
      await NativeWorkManager.beginWith(
            TaskRequest(
              id: 'parallel-download',
              worker: HttpRequestWorker(
                url: 'https://httpbin.org/get',
                method: HttpMethod.get,
              ),
            ),
          )
          .thenAll([
            TaskRequest(
              id: 'parallel-upload-1',
              worker: HttpRequestWorker(
                url: 'https://httpbin.org/post',
                method: HttpMethod.post,
                body: '{"file":1}',
              ),
            ),
            TaskRequest(
              id: 'parallel-upload-2',
              worker: HttpRequestWorker(
                url: 'https://httpbin.org/post',
                method: HttpMethod.post,
                body: '{"file":2}',
              ),
            ),
          ])
          .named('parallel-chain')
          .enqueue();

      _addLog('📤 Scheduled: Parallel Chain');
      _addLog('⛓️ Download → [Upload1 + Upload2] in parallel');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 6: Periodic & Scheduled
  // ═══════════════════════════════════════════════════════════════

  Future<void> _schedulePeriodicTask() async {
    const taskId = 'periodic-sync';
    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.periodic(const Duration(minutes: 15)),
        worker: HttpSyncWorker(
          url: 'https://httpbin.org/post',
          method: HttpMethod.post,
          requestBody: {'type': 'periodic'},
        ),
        constraints: const Constraints(requiresNetwork: true),
      );
      _addLog('📤 Scheduled: Periodic Task (every 15 min)');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _scheduleExactAlarm() async {
    final taskId = 'exact-${_taskCounter++}';
    final scheduledTime = DateTime.now().add(const Duration(minutes: 5));
    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.exact(scheduledTime),
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/get',
          method: HttpMethod.get,
        ),
      );
      _addLog('📤 Scheduled: Exact Alarm ($taskId)');
      _addLog('⏰ Will run at ${_formatTime(scheduledTime)}');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _scheduleWindowedTask() async {
    final taskId = 'windowed-${_taskCounter++}';
    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.windowed(
          earliest: const Duration(minutes: 2),
          latest: const Duration(minutes: 10),
        ),
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/get',
          method: HttpMethod.get,
        ),
      );
      _addLog('📤 Scheduled: Windowed Task ($taskId)');
      _addLog('⏰ Will run between 2-10 minutes from now');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Common Actions
  // ═══════════════════════════════════════════════════════════════

  Future<void> _cancelAll() async {
    try {
      await NativeWorkManager.cancelAll();
      _addLog('🗑️ Cancelled all tasks');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
    _addLog('🧹 Logs cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Native WorkManager v1.1.0'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Basic'),
            Tab(text: 'Retry'),
            Tab(text: 'ContentUri'),
            Tab(text: 'Constraints'),
            Tab(text: 'Chains'),
            Tab(text: 'Scheduled'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBasicTab(),
                _buildBackoffPolicyTab(),
                _buildContentUriTab(),
                _buildConstraintsTab(),
                _buildChainsTab(),
                _buildScheduledTab(),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildLogSection(),
        ],
      ),
    );
  }

  Widget _buildBasicTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('Native Workers (Mode 1)'),
        const Text(
          'Zero Flutter Engine overhead\n'
          'RAM: 2-5MB | Startup: <50ms',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        _buildButton(
          'HTTP GET Request',
          Icons.cloud_download,
          _scheduleHttpGet,
          Colors.blue,
        ),
        _buildButton(
          'HTTP POST Request',
          Icons.cloud_upload,
          _scheduleHttpPost,
          Colors.green,
        ),
        _buildButton('JSON Sync', Icons.sync, _scheduleSync, Colors.orange),
      ],
    );
  }

  Widget _buildBackoffPolicyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('v1.1.0: Intelligent Retry (Android)'),
        const Text(
          'Automatic retry with exponential or linear backoff\n'
          'Failed tasks will retry automatically with increasing delays',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        _buildButton(
          'Exponential Backoff',
          Icons.trending_up,
          _scheduleWithExponentialBackoff,
          Colors.purple,
        ),
        const Text(
          '  Retry: 10s → 20s → 40s → 80s → ...',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        _buildButton(
          'Linear Backoff',
          Icons.linear_scale,
          _scheduleWithLinearBackoff,
          Colors.indigo,
        ),
        const Text(
          '  Retry: 15s → 15s → 15s → 15s → ...',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ℹ️ How it works:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '1. Task scheduled with backoffPolicy\n'
                  '2. If task fails (returns false), automatic retry\n'
                  '3. Delay increases based on policy\n'
                  '4. Continues until success or max retries',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentUriTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('v1.1.0: ContentUri Trigger (Android)'),
        const Text(
          'React to content provider changes\n'
          'Auto-backup photos, sync contacts, etc.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        _buildButton(
          'Photo Auto-Backup',
          Icons.photo_camera,
          _schedulePhotoBackup,
          Colors.pink,
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📸 Photo Backup Demo:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '1. Schedule photo backup task\n'
                  '2. Take a photo with camera app\n'
                  '3. Task triggers automatically\n'
                  '4. Photo backed up to cloud',
                  style: TextStyle(fontSize: 12),
                ),
                SizedBox(height: 8),
                Text(
                  '⚠️ Android only - iOS will show error',
                  style: TextStyle(fontSize: 11, color: Colors.orange),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConstraintsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('Advanced Constraints'),
        const Text(
          'isHeavyTask, QoS, and more',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        _buildButton(
          'Heavy Task (Foreground Service)',
          Icons.work,
          _scheduleHeavyTask,
          Colors.red,
        ),
        const Text(
          '  Uses ForegroundService on Android\n'
          '  Shows notification, prevents kill',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        _buildButton(
          'QoS Priority (iOS)',
          Icons.priority_high,
          _scheduleWithQoS,
          Colors.teal,
        ),
        const Text(
          '  Sets DispatchQoS on iOS\n'
          '  Controls task priority',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildChainsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('Task Chains'),
        const Text(
          'Complex workflows made simple\n'
          'Sequential: A → B → C\n'
          'Parallel: A → [B + C + D]',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        _buildButton(
          'Sequential Chain',
          Icons.timeline,
          _scheduleSequentialChain,
          Colors.deepPurple,
        ),
        const Text(
          '  Step 1 → Step 2 → Step 3',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        _buildButton(
          'Parallel Chain',
          Icons.account_tree,
          _scheduleParallelChain,
          Colors.cyan,
        ),
        const Text(
          '  Download → [Upload1 + Upload2]',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildScheduledTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('Scheduled Tasks'),
        const Text(
          'Periodic, Exact, and Windowed triggers',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        _buildButton(
          'Periodic (Every 15 min)',
          Icons.repeat,
          _schedulePeriodicTask,
          Colors.green,
        ),
        _buildButton(
          'Exact Alarm (5 min from now)',
          Icons.alarm,
          _scheduleExactAlarm,
          Colors.orange,
        ),
        _buildButton(
          'Windowed (2-10 min window)',
          Icons.timelapse,
          _scheduleWindowedTask,
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.2),
          foregroundColor: color,
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }

  Widget _buildLogSection() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Event Log',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _clearLogs,
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Clear'),
                    ),
                    TextButton.icon(
                      onPressed: _cancelAll,
                      icon: const Icon(Icons.delete_sweep, size: 16),
                      label: const Text('Cancel All'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      'No events yet. Schedule a task to see events!',
                    ),
                  )
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Text(
                          _logs[index],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
