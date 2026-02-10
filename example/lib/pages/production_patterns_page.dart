/// Production-ready patterns and best practices for native_workmanager
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

class ProductionPatternsPage extends StatefulWidget {
  const ProductionPatternsPage({super.key});

  @override
  State<ProductionPatternsPage> createState() => _ProductionPatternsPageState();
}

class _ProductionPatternsPageState extends State<ProductionPatternsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _logs = [];
  final _logController = StreamController<String>.broadcast();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _logController.stream.listen((log) {
      if (mounted) {
        setState(() {
          _logs.add(log);
          // Keep last 50 logs
          if (_logs.length > 50) {
            _logs.removeAt(0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _logController.close();
    super.dispose();
  }

  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logController.add('[$timestamp] $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Production Patterns'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Error Handling'),
            Tab(text: 'State Recovery'),
            Tab(text: 'Data Passing'),
            Tab(text: 'Monitoring'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildErrorHandlingTab(),
                _buildStateRecoveryTab(),
                _buildDataPassingTab(),
                _buildMonitoringTab(),
              ],
            ),
          ),
          _buildLogPanel(),
        ],
      ),
    );
  }

  Widget _buildErrorHandlingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          'Error Handling Patterns',
          'Production-ready strategies for handling failures',
        ),

        // Retry Pattern
        _buildPatternCard(
          title: 'Retry with Exponential Backoff',
          description:
              'Automatically retry failed tasks with increasing delays',
          icon: Icons.replay,
          color: Colors.blue,
          codeExample: '''
// Configure retry policy
final config = TaskConfig(
  taskId: 'api-sync',
  constraints: Constraints(
    requiresNetwork: true,
  ),
  backoffPolicy: BackoffPolicy.exponential,
  initialBackoffDelay: Duration(seconds: 30),
  maxBackoffDelay: Duration(hours: 1),
);

// Task will retry automatically on failure
// Delay: 30s → 60s → 120s → 240s → ... → 1h
''',
          onRun: () => _demonstrateRetryPattern(),
        ),

        // Circuit Breaker Pattern
        _buildPatternCard(
          title: 'Circuit Breaker',
          description: 'Prevent cascade failures by breaking the circuit',
          icon: Icons.power_off,
          color: Colors.orange,
          codeExample: '''
class CircuitBreaker {
  int failureCount = 0;
  DateTime? lastFailure;
  bool isOpen = false;

  final int threshold = 5;
  final Duration resetTimeout = Duration(minutes: 5);

  Future<T> execute<T>(Future<T> Function() action) async {
    if (isOpen) {
      if (DateTime.now().difference(lastFailure!) > resetTimeout) {
        // Try to close circuit
        isOpen = false;
        failureCount = 0;
      } else {
        throw Exception('Circuit breaker is OPEN');
      }
    }

    try {
      final result = await action();
      failureCount = 0;
      return result;
    } catch (e) {
      failureCount++;
      lastFailure = DateTime.now();

      if (failureCount >= threshold) {
        isOpen = true;
      }
      rethrow;
    }
  }
}
''',
          onRun: () => _demonstrateCircuitBreaker(),
        ),

        // Fallback Pattern
        _buildPatternCard(
          title: 'Fallback Strategy',
          description: 'Provide alternative behavior when primary fails',
          icon: Icons.alt_route,
          color: Colors.green,
          codeExample: '''
Future<Data> fetchData() async {
  try {
    // Try primary source (API)
    return await fetchFromAPI();
  } catch (e) {
    try {
      // Fallback to cache
      return await fetchFromCache();
    } catch (e2) {
      // Final fallback to default data
      return getDefaultData();
    }
  }
}
''',
          onRun: () => _demonstrateFallback(),
        ),

        // Timeout Pattern
        _buildPatternCard(
          title: 'Timeout & Cancellation',
          description: 'Prevent indefinite waits with timeouts',
          icon: Icons.timer,
          color: Colors.red,
          codeExample: '''
// Set timeout on task execution
final config = TaskConfig(
  taskId: 'long-task',
  // Task will be cancelled if exceeds timeout
);

// In your task:
Future<void> myTask() async {
  await Future.any([
    actualWork(),
    Future.delayed(Duration(minutes: 5))
      .then((_) => throw TimeoutException('Task timeout')),
  ]);
}
''',
          onRun: () => _demonstrateTimeout(),
        ),
      ],
    );
  }

  Widget _buildStateRecoveryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          'State Recovery Patterns',
          'Ensure reliability with proper state management',
        ),

        // Chain Resumption
        _buildPatternCard(
          title: 'Chain Resumption',
          description: 'Resume multi-step workflows from checkpoint',
          icon: Icons.link,
          color: Colors.purple,
          codeExample: '''
// Save progress after each step
class TaskChain {
  Future<void> execute() async {
    final checkpoint = await loadCheckpoint();

    if (checkpoint.step < 1) {
      await step1();
      await saveCheckpoint(step: 1);
    }

    if (checkpoint.step < 2) {
      await step2();
      await saveCheckpoint(step: 2);
    }

    if (checkpoint.step < 3) {
      await step3();
      await saveCheckpoint(step: 3);
    }

    await clearCheckpoint();
  }
}
''',
          onRun: () => _demonstrateChainResumption(),
        ),

        // Idempotency
        _buildPatternCard(
          title: 'Idempotent Operations',
          description: 'Safe to retry without side effects',
          icon: Icons.check_circle,
          color: Colors.teal,
          codeExample: '''
// Use unique IDs to prevent duplicates
Future<void> syncData(String syncId) async {
  // Check if already processed
  if (await isProcessed(syncId)) {
    return; // Already done, skip
  }

  try {
    // Perform operation
    await uploadData(syncId);

    // Mark as processed
    await markProcessed(syncId);
  } catch (e) {
    // Can safely retry - won't duplicate
    rethrow;
  }
}
''',
          onRun: () => _demonstrateIdempotency(),
        ),

        // State Persistence
        _buildPatternCard(
          title: 'State Persistence',
          description: 'Survive app restarts with saved state',
          icon: Icons.save,
          color: Colors.indigo,
          codeExample: '''
class StatefulTask {
  Future<void> execute() async {
    // Load previous state
    final state = await loadState();

    try {
      // Process with state tracking
      for (var i = state.processedCount; i < data.length; i++) {
        await processItem(data[i]);

        // Update state periodically
        state.processedCount = i + 1;
        await saveState(state);
      }
    } catch (e) {
      // State is saved, can resume on retry
      rethrow;
    }
  }
}
''',
          onRun: () => _demonstrateStatePersistence(),
        ),

        // Transaction Pattern
        _buildPatternCard(
          title: 'Transactional Rollback',
          description: 'Roll back on failure to maintain consistency',
          icon: Icons.undo,
          color: Colors.amber,
          codeExample: '''
Future<void> transactionalOperation() async {
  final rollbackStack = <Future<void> Function()>[];

  try {
    // Step 1
    await operation1();
    rollbackStack.add(() => undoOperation1());

    // Step 2
    await operation2();
    rollbackStack.add(() => undoOperation2());

    // Step 3
    await operation3();

    // All succeeded - commit
  } catch (e) {
    // Rollback in reverse order
    for (final rollback in rollbackStack.reversed) {
      try {
        await rollback();
      } catch (e) {
        // Log rollback failure
      }
    }
    rethrow;
  }
}
''',
          onRun: () => _demonstrateTransaction(),
        ),
      ],
    );
  }

  Widget _buildDataPassingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          'Data Passing Patterns',
          'Type-safe communication between tasks',
        ),

        // JSON Serialization
        _buildPatternCard(
          title: 'JSON Serialization',
          description: 'Pass structured data using JSON',
          icon: Icons.code,
          color: Colors.blue,
          codeExample: '''
// Define data model
class TaskData {
  final String userId;
  final List<String> items;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'items': items,
    'metadata': metadata,
  };

  factory TaskData.fromJson(Map<String, dynamic> json) => TaskData(
    userId: json['userId'],
    items: List<String>.from(json['items']),
    metadata: Map<String, dynamic>.from(json['metadata']),
  );
}

// Pass to task
final data = TaskData(...);
await workmanager.registerTask(
  taskId: 'process',
  inputData: data.toJson(),
);
''',
          onRun: () => _demonstrateJsonSerialization(),
        ),

        // File Path Passing
        _buildPatternCard(
          title: 'File Path References',
          description: 'Share large data via file system',
          icon: Icons.file_present,
          color: Colors.green,
          codeExample: '''
// Save large data to file
final file = File('\${directory.path}/task_data.json');
await file.writeAsString(jsonEncode(largeData));

// Pass file path
await workmanager.registerTask(
  taskId: 'process',
  inputData: {'dataFile': file.path},
);

// In task: read file
final path = inputData['dataFile'];
final content = await File(path).readAsString();
final data = jsonDecode(content);
''',
          onRun: () => _demonstrateFilePath(),
        ),

        // Typed Contracts
        _buildPatternCard(
          title: 'Typed Contracts',
          description: 'Strong typing for task inputs/outputs',
          icon: Icons.type_specimen,
          color: Colors.purple,
          codeExample: '''
// Define contract
abstract class TaskContract {
  Map<String, dynamic> toInputData();
  static TaskContract fromInputData(Map<String, dynamic> data);
}

class SyncTaskContract implements TaskContract {
  final String endpoint;
  final Map<String, String> headers;

  @override
  Map<String, dynamic> toInputData() => {
    'type': 'sync',
    'endpoint': endpoint,
    'headers': headers,
  };

  static SyncTaskContract fromInputData(Map<String, dynamic> data) {
    return SyncTaskContract(
      endpoint: data['endpoint'],
      headers: Map<String, String>.from(data['headers']),
    );
  }
}
''',
          onRun: () => _demonstrateTypedContracts(),
        ),

        // Result Passing
        _buildPatternCard(
          title: 'Result Propagation',
          description: 'Return results from background tasks',
          icon: Icons.output,
          color: Colors.orange,
          codeExample: '''
// Task execution
Future<void> backgroundTask() async {
  final result = await processData();

  // Save result for retrieval
  await saveResult({
    'status': 'success',
    'data': result,
    'timestamp': DateTime.now().toIso8601String(),
  });
}

// Retrieve in app
final resultStream = workmanager.getResultStream('task-id');
await for (final result in resultStream) {
  final data = result['data'];
  // Use result
}
''',
          onRun: () => _demonstrateResultPassing(),
        ),
      ],
    );
  }

  Widget _buildMonitoringTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          'Monitoring & Observability',
          'Track task execution and diagnose issues',
        ),

        // Structured Logging
        _buildPatternCard(
          title: 'Structured Logging',
          description: 'Rich logs for debugging and analysis',
          icon: Icons.article,
          color: Colors.blue,
          codeExample: '''
class TaskLogger {
  void log(String level, String message, {Map<String, dynamic>? data}) {
    final entry = {
      'timestamp': DateTime.now().toIso8601String(),
      'level': level,
      'message': message,
      'taskId': currentTaskId,
      'data': data,
    };

    // Send to logging service
    loggingService.write(jsonEncode(entry));
  }

  void info(String message, {Map<String, dynamic>? data}) =>
    log('INFO', message, data: data);

  void error(String message, {Map<String, dynamic>? data}) =>
    log('ERROR', message, data: data);
}
''',
          onRun: () => _demonstrateStructuredLogging(),
        ),

        // Progress Tracking
        _buildPatternCard(
          title: 'Progress Tracking',
          description: 'Report task progress to UI',
          icon: Icons.trending_up,
          color: Colors.green,
          codeExample: '''
Future<void> longRunningTask() async {
  final total = items.length;

  for (var i = 0; i < total; i++) {
    await processItem(items[i]);

    // Report progress
    final progress = ((i + 1) / total * 100).toInt();
    await workmanager.emitProgress(
      taskId: 'long-task',
      progress: progress,
      message: 'Processing item \${i + 1}/\$total',
    );
  }
}

// In UI: listen to progress
workmanager.progressStream.listen((event) {
  setState(() {
    currentProgress = event.progress;
    currentMessage = event.message;
  });
});
''',
          onRun: () => _demonstrateProgressTracking(),
        ),

        // Performance Metrics
        _buildPatternCard(
          title: 'Performance Metrics',
          description: 'Measure and track task performance',
          icon: Icons.speed,
          color: Colors.orange,
          codeExample: '''
class PerformanceMetrics {
  Future<T> measure<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    final stopwatch = Stopwatch()..start();
    final memoryStart = await getMemoryUsage();

    try {
      final result = await action();

      stopwatch.stop();
      final memoryEnd = await getMemoryUsage();

      // Record metrics
      await recordMetric({
        'operation': operation,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'memory_delta_mb': (memoryEnd - memoryStart) / 1024 / 1024,
        'status': 'success',
      });

      return result;
    } catch (e) {
      stopwatch.stop();
      await recordMetric({
        'operation': operation,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'status': 'error',
        'error': e.toString(),
      });
      rethrow;
    }
  }
}
''',
          onRun: () => _demonstratePerformanceMetrics(),
        ),

        // Alerting
        _buildPatternCard(
          title: 'Alerting & Notifications',
          description: 'Alert on critical failures',
          icon: Icons.notifications_active,
          color: Colors.red,
          codeExample: '''
class AlertManager {
  Future<void> checkAndAlert() async {
    final metrics = await getRecentMetrics();

    // Check failure rate
    final failureRate = metrics.failures / metrics.total;
    if (failureRate > 0.1) {
      await sendAlert(
        severity: 'high',
        message: 'Task failure rate: \${(failureRate * 100).toStringAsFixed(1)}%',
      );
    }

    // Check execution time
    if (metrics.avgDuration > Duration(minutes: 5)) {
      await sendAlert(
        severity: 'medium',
        message: 'Tasks taking longer than expected',
      );
    }

    // Check memory usage
    if (metrics.peakMemory > 500 * 1024 * 1024) {
      await sendAlert(
        severity: 'medium',
        message: 'High memory usage: \${metrics.peakMemory / 1024 / 1024}MB',
      );
    }
  }
}
''',
          onRun: () => _demonstrateAlerting(),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String codeExample,
    required VoidCallback onRun,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(description),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      codeExample,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onRun,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Run Demo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogPanel() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Execution Log',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.green, size: 16),
                  onPressed: () {
                    setState(() {
                      _logs.clear();
                    });
                  },
                  tooltip: 'Clear logs',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Text(
                  _logs[index],
                  style: const TextStyle(
                    color: Colors.green,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Demo implementations
  Future<void> _demonstrateRetryPattern() async {
    _log('🔄 Retry Pattern Demo');
    _log('Simulating API call with failures...');

    for (var attempt = 1; attempt <= 3; attempt++) {
      await Future.delayed(const Duration(milliseconds: 500));

      if (attempt < 3) {
        final delay = Duration(seconds: attempt * 2);
        _log('❌ Attempt $attempt failed');
        _log('⏳ Retrying in ${delay.inSeconds}s (exponential backoff)...');
        await Future.delayed(delay);
      } else {
        _log('✅ Attempt $attempt succeeded');
        _log('📊 Total attempts: $attempt');
      }
    }
  }

  Future<void> _demonstrateCircuitBreaker() async {
    _log('⚡ Circuit Breaker Demo');
    _log('Simulating cascade failures...');

    var failures = 0;
    const threshold = 3;

    for (var i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(milliseconds: 300));

      if (failures >= threshold) {
        _log('🔴 Circuit OPEN - Rejecting request $i');
        continue;
      }

      if (i <= threshold) {
        failures++;
        _log('❌ Request $i failed (failures: $failures/$threshold)');
      } else {
        _log('⚪ Request $i blocked by circuit breaker');
      }
    }

    _log('⏱️ Waiting 5s for circuit reset...');
    await Future.delayed(const Duration(seconds: 1));
    _log('🟢 Circuit CLOSED - Accepting requests');
  }

  Future<void> _demonstrateFallback() async {
    _log('🔀 Fallback Pattern Demo');
    _log('Attempting primary source (API)...');
    await Future.delayed(const Duration(milliseconds: 500));
    _log('❌ Primary source failed: Network timeout');

    _log('Attempting fallback 1 (Cache)...');
    await Future.delayed(const Duration(milliseconds: 300));
    _log('✅ Cache hit - Returning cached data');
    _log('📦 Data retrieved from cache (age: 2h)');
  }

  Future<void> _demonstrateTimeout() async {
    _log('⏱️ Timeout Pattern Demo');
    _log('Starting long-running task (timeout: 2s)...');

    final timeout = Future.delayed(const Duration(milliseconds: 2000));
    final work = Future.delayed(const Duration(milliseconds: 3000));

    try {
      await Future.any([work, timeout.then((_) => throw TimeoutException(''))]);
      _log('✅ Task completed');
    } catch (e) {
      _log('⏰ Task cancelled - Timeout exceeded');
      _log('🛑 Cleanup resources');
    }
  }

  Future<void> _demonstrateChainResumption() async {
    _log('🔗 Chain Resumption Demo');
    _log('Loading checkpoint...');
    await Future.delayed(const Duration(milliseconds: 300));

    final steps = ['Download', 'Process', 'Upload'];
    var completedStep = 1; // Simulate previous progress

    _log('📍 Checkpoint found: Step $completedStep completed');

    for (var i = completedStep; i < steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      _log('▶️ Executing step ${i + 1}: ${steps[i]}');
      await Future.delayed(const Duration(milliseconds: 500));
      _log('✅ Step ${i + 1} complete - Saved checkpoint');
    }

    _log('🏁 Chain completed - Clearing checkpoint');
  }

  Future<void> _demonstrateIdempotency() async {
    _log('🔄 Idempotency Demo');

    const syncId = 'sync_12345';
    _log('Processing operation: $syncId');

    await Future.delayed(const Duration(milliseconds: 500));
    _log('✅ Operation completed - Marked as processed');

    _log('');
    _log('Simulating retry (network recovered)...');
    await Future.delayed(const Duration(milliseconds: 500));
    _log('🔍 Checking if already processed: $syncId');
    await Future.delayed(const Duration(milliseconds: 300));
    _log('✋ Already processed - Skipping (idempotent)');
    _log('📊 No duplicate side effects');
  }

  Future<void> _demonstrateStatePersistence() async {
    _log('💾 State Persistence Demo');
    _log('Loading previous state...');
    await Future.delayed(const Duration(milliseconds: 300));

    const total = 10;
    var processed = 4; // Simulate crash recovery

    _log('📍 Resumed from checkpoint: $processed/$total processed');

    for (var i = processed; i < total; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      _log('▶️ Processing item ${i + 1}/$total');
      await Future.delayed(const Duration(milliseconds: 200));
      _log('💾 Saved state: ${i + 1}/$total');
    }

    _log('✅ All items processed - Clearing state');
  }

  Future<void> _demonstrateTransaction() async {
    _log('🔄 Transactional Rollback Demo');
    _log('Starting multi-step transaction...');

    final steps = ['Create record', 'Upload file', 'Send notification'];

    try {
      for (var i = 0; i < steps.length; i++) {
        await Future.delayed(const Duration(milliseconds: 400));
        _log('▶️ Step ${i + 1}: ${steps[i]}');

        if (i == 2) {
          throw Exception('Network error');
        }

        await Future.delayed(const Duration(milliseconds: 300));
        _log('✅ Step ${i + 1} completed');
      }
    } catch (e) {
      _log('❌ Transaction failed: $e');
      _log('🔙 Rolling back changes...');

      for (var i = 1; i >= 0; i--) {
        await Future.delayed(const Duration(milliseconds: 300));
        _log('↩️ Undo step ${i + 1}: ${steps[i]}');
      }

      _log('✅ Rollback complete - System consistent');
    }
  }

  Future<void> _demonstrateJsonSerialization() async {
    _log('📝 JSON Serialization Demo');

    final data = {
      'userId': 'user_123',
      'items': ['item1', 'item2', 'item3'],
      'metadata': {
        'timestamp': DateTime.now().toIso8601String(),
        'priority': 'high',
      },
    };

    _log('Serializing data to JSON...');
    await Future.delayed(const Duration(milliseconds: 300));
    final json = jsonEncode(data);
    _log('✅ JSON: ${json.substring(0, 60)}...');

    _log('Passing to background task...');
    await Future.delayed(const Duration(milliseconds: 300));
    final items = data['items'] as List?;
    _log('📤 Task received: ${items?.length ?? 0} items');
  }

  Future<void> _demonstrateFilePath() async {
    _log('📁 File Path Passing Demo');
    _log('Generating large dataset (10MB)...');
    await Future.delayed(const Duration(milliseconds: 500));

    const filePath = '/tmp/task_data_12345.json';
    _log('💾 Saved to: $filePath');
    _log('📤 Passing file path to task...');
    await Future.delayed(const Duration(milliseconds: 300));
    _log('📥 Task reading file...');
    await Future.delayed(const Duration(milliseconds: 400));
    _log('✅ Data loaded from file (10MB)');
  }

  Future<void> _demonstrateTypedContracts() async {
    _log('📋 Typed Contracts Demo');
    _log('Creating SyncTaskContract...');
    await Future.delayed(const Duration(milliseconds: 300));

    _log('Contract: {');
    _log('  type: "sync",');
    _log('  endpoint: "https://api.example.com/sync",');
    _log('  headers: {"Authorization": "Bearer ***"}');
    _log('}');

    _log('✅ Type-safe task input created');
  }

  Future<void> _demonstrateResultPassing() async {
    _log('📊 Result Propagation Demo');
    _log('Background task executing...');
    await Future.delayed(const Duration(milliseconds: 600));

    final result = {
      'status': 'success',
      'recordsProcessed': 142,
      'duration': '2.3s',
    };

    _log('💾 Saving result...');
    await Future.delayed(const Duration(milliseconds: 300));
    _log('📤 Result available for retrieval:');
    _log('  Records: ${result['recordsProcessed']}');
    _log('  Duration: ${result['duration']}');
  }

  Future<void> _demonstrateStructuredLogging() async {
    _log('📝 Structured Logging Demo');

    final entry = {
      'timestamp': DateTime.now().toIso8601String(),
      'level': 'INFO',
      'message': 'Task completed successfully',
      'taskId': 'sync_789',
      'duration_ms': 1240,
      'records_processed': 56,
    };

    _log('Writing structured log entry...');
    await Future.delayed(const Duration(milliseconds: 300));
    _log('✅ Log: ${jsonEncode(entry)}');
  }

  Future<void> _demonstrateProgressTracking() async {
    _log('📈 Progress Tracking Demo');
    const total = 10;

    for (var i = 0; i < total; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      final progress = ((i + 1) / total * 100).toInt();
      _log('Progress: $progress% (${i + 1}/$total items)');
    }

    _log('✅ Task completed');
  }

  Future<void> _demonstratePerformanceMetrics() async {
    _log('⚡ Performance Metrics Demo');
    _log('Measuring operation performance...');

    final stopwatch = Stopwatch()..start();
    await Future.delayed(const Duration(milliseconds: 450));
    stopwatch.stop();

    _log('📊 Metrics:');
    _log('  Duration: ${stopwatch.elapsedMilliseconds}ms');
    _log('  Memory delta: 12.3 MB');
    _log('  CPU usage: 23.5%');
    _log('  Status: success');
  }

  Future<void> _demonstrateAlerting() async {
    _log('🚨 Alerting Demo');
    _log('Checking system health...');
    await Future.delayed(const Duration(milliseconds: 500));

    _log('⚠️ Alert: Task failure rate exceeded threshold');
    _log('  Current: 15.2%');
    _log('  Threshold: 10.0%');
    _log('  Severity: HIGH');
    await Future.delayed(const Duration(milliseconds: 300));
    _log('📧 Notification sent to ops team');
  }
}
