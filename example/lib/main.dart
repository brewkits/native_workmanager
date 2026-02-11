import 'dart:io';
import 'dart:typed_data'; // Added for Uint8List
import 'package:path_provider/path_provider.dart'; // Added for getTemporaryDirectory

import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart' hide Constraints, BackoffPolicy;
import 'package:native_workmanager/native_workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'advanced_metrics_overlay.dart';
import 'pages/manual_benchmark_page.dart';
import 'pages/production_impact_page_improved.dart';
import 'pages/demo_scenarios_page.dart';
import 'pages/comprehensive_demo_page.dart';
import 'pages/performance_page.dart';
import 'examples/chain_resilience_test.dart';

/// flutter_workmanager background callback.
/// Runs in a separate isolate — communicates completion back via SharedPreferences.
@pragma('vm:entry-point')
void flutterWorkmanagerCallback() {
  Workmanager().executeTask((taskName, inputData) async {
    final completionKey = inputData?['completionKey'] as String?;

    try {
      switch (taskName) {
        case 'bench_httpGet':
          final client = HttpClient();
          final req = await client.getUrl(Uri.parse('https://httpbin.org/get'));
          await req.close();
          client.close();

        case 'bench_httpPost':
          final client = HttpClient();
          final req = await client.postUrl(
            Uri.parse('https://httpbin.org/post'),
          );
          req.headers.contentType = ContentType.json;
          req.write(
            '{"benchmark":true,"ts":${DateTime.now().millisecondsSinceEpoch}}',
          );
          await req.close();
          client.close();

        case 'bench_jsonSync':
          final client = HttpClient();
          final req = await client.postUrl(
            Uri.parse('https://httpbin.org/post'),
          );
          req.headers.contentType = ContentType.json;
          req.write(
            '{"sync":true,"ts":${DateTime.now().millisecondsSinceEpoch}}',
          );
          final resp = await req.close();
          await resp.toList();
          client.close();

        case 'bench_fileDownload':
          final client = HttpClient();
          final req = await client.getUrl(
            Uri.parse('https://httpbin.org/bytes/51200'),
          );
          final resp = await req.close();
          await resp.toList();
          client.close();

        case 'bench_heavyCompute':
          // Reduced from 40 to 38 for better performance on emulators
          // fib(40) can take 30-60+ seconds on slow devices
          fibonacciCompute(38);

        default:
          return false;
      }

      // Signal completion to main thread
      if (completionKey != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          completionKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  });
}

/// CPU-intensive Fibonacci — used by both libs for heavy compute benchmark.
int fibonacciCompute(int n) {
  if (n <= 1) return n;
  return fibonacciCompute(n - 1) + fibonacciCompute(n - 2);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize flutter_workmanager (for A/B benchmark comparison only)
  Workmanager().initialize(flutterWorkmanagerCallback);

  // Initialize native_workmanager
  await NativeWorkManager.initialize(
    dartWorkers: {
      'customTask': customTaskCallback,
      'heavyTask': heavyTaskCallback,
      'benchHeavyCompute': benchHeavyComputeCallback,
    },
  );

  runApp(const MyApp());

  // Performance benchmarks - DISABLED by default to avoid auto-running tasks on app start
  // Users can run benchmarks manually from the Performance page
  debugPrint('💡 Benchmarks disabled - Use Performance page to run manually');
}

/// Heavy compute callback for A/B benchmark (runs inside native_workmanager's cached engine).
@pragma('vm:entry-point')
Future<bool> benchHeavyComputeCallback(Map<String, dynamic>? input) async {
  fibonacciCompute(40);
  return true;
}

/// Custom Dart worker callback.
@pragma('vm:entry-point')
Future<bool> customTaskCallback(Map<String, dynamic>? input) async {
  debugPrint('📱 Dart Worker: Executing custom task with input: $input');
  await Future.delayed(const Duration(seconds: 2));
  debugPrint('📱 Dart Worker: Task completed successfully');
  return true;
}

/// Heavy task callback (for isHeavyTask demo).
@pragma('vm:entry-point')
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native WorkManager v1.0.0 Demo',
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
  bool _showMetricsOverlay = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 13, vsync: this);

    // Listen to task events (v2.3.0+: includes resultData)
    NativeWorkManager.events.listen((event) {
      setState(() {
        var logMessage =
            '${_formatTime(event.timestamp)} '
            '${event.success ? "✅" : "❌"} '
            '${event.taskId}: '
            '${event.message ?? (event.success ? "Success" : "Failed")}';

        // v2.3.0+: Show result data if available
        if (event.resultData != null && event.resultData!.isNotEmpty) {
          final data = event.resultData!;
          if (data.containsKey('filePath')) {
            logMessage +=
                ' | File: ${data['fileName']}, Size: ${data['fileSize']} bytes';
          } else if (data.containsKey('statusCode')) {
            logMessage += ' | HTTP ${data['statusCode']}';
          } else if (data.containsKey('compressionRatio')) {
            logMessage +=
                ' | ${data['filesCompressed']} files, ${data['compressionRatio']}% ratio';
          }
        }

        _logs.insert(0, logMessage);
        if (_logs.length > 50) _logs.removeLast();
      });
    });

    _addLog('🚀 Native WorkManager v1.0.0 initialized (100% KMP parity)');
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
  // TAB 2: v1.0.0 Features - BackoffPolicy
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
        title: const Text('Native WorkManager v1.0.0'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Toggle metrics overlay button
          IconButton(
            icon: Icon(
              _showMetricsOverlay ? Icons.speed : Icons.speed_outlined,
              color: _showMetricsOverlay ? Colors.green : null,
            ),
            tooltip: 'Toggle Real-time Metrics',
            onPressed: () {
              setState(() {
                _showMetricsOverlay = !_showMetricsOverlay;
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Demo'),
            Tab(text: '✨ All Workers'),
            Tab(text: 'Performance'),
            Tab(text: 'Basic'),
            Tab(text: 'Upload/Download'),
            Tab(text: 'Retry'),
            Tab(text: 'Constraints'),
            Tab(text: 'Chains'),
            Tab(text: 'Scheduled'),
            Tab(text: 'Custom Worker'),
            Tab(text: 'Manual BM'),
            Tab(text: 'Production'),
            Tab(text: '🔄 Chain Test'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    const DemoScenariosPage(),
                    const ComprehensiveDemoPage(),
                    const PerformancePage(),
                    _buildBasicTab(),
                    _buildUploadDownloadTab(),
                    _buildBackoffPolicyTab(),
                    _buildConstraintsTab(),
                    _buildChainsTab(),
                    _buildScheduledTab(),
                    _buildCustomWorkerTab(),
                    const ManualBenchmarkPage(),
                    const ProductionImpactPageImproved(),
                    const ChainResilienceTest(),
                  ],
                ),
              ),
              const Divider(height: 1),
              _buildLogSection(),
            ],
          ),
          // Advanced floating metrics overlay
          if (_showMetricsOverlay) const AdvancedMetricsOverlay(),
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
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        const _SectionTitle('Dart Workers (Mode 2)'),
        const Text(
          'Full Flutter Engine access\n'
          'RAM: 30-50MB | Startup: 500-1000ms',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        _buildButton(
          'Custom Dart Task',
          Icons.code,
          _scheduleCustomDartTask,
          Colors.purple,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 2: Upload/Download Workers
  // ═══════════════════════════════════════════════════════════════

  Widget _buildUploadDownloadTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('Upload & Download Workers'),
        const Text(
          'File transfer with progress tracking\n'
          'Native URLSession/OkHttp implementation',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        _buildButton(
          'Upload File (with progress)',
          Icons.cloud_upload,
          _scheduleFileUpload,
          Colors.blue,
        ),
        const Text(
          '  Uploads with custom fileName & mimeType',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        _buildButton(
          'Download File',
          Icons.cloud_download,
          _scheduleFileDownload,
          Colors.green,
        ),
        const Text(
          '  Downloads file to app temp directory',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        _buildButton(
          'Compress File/Directory (ZIP)',
          Icons.archive,
          _scheduleFileCompression,
          Colors.orange,
        ),
        const Text(
          '  Compresses files to ZIP archive (v1.0.0+)',
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
                  '📁 File Operations:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '• Upload: Multipart w/ custom fileName & mimeType\n'
                  '• Download: Streaming with progress\n'
                  '• Compress: ZIP files/directories (NEW!)\n'
                  '• Native implementation (no Dart overhead)\n'
                  '• Works in background even when app killed',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _scheduleFileUpload() async {
    final taskId = 'upload-${_taskCounter++}';
    try {
      // Create temp file with UUID name (simulating cache file)
      final tempFileName = 'temp_${DateTime.now().millisecondsSinceEpoch}.dat';
      final testFile = '${Directory.systemTemp.path}/$tempFileName';
      await File(testFile).writeAsString(
        'test upload content - ${DateTime.now().toIso8601String()}',
      );

      // Upload with custom fileName and mimeType
      final customFileName =
          'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: HttpUploadWorker(
          url: 'https://httpbin.org/post',
          filePath: testFile,
          fileFieldName: 'photo',
          fileName: customFileName, // NEW: Custom uploaded filename
          mimeType: 'image/jpeg', // NEW: Explicit MIME type
          headers: const {'X-Test': 'Upload'},
          additionalFields: const {
            'userId': 'demo-user',
            'description': 'Test photo upload',
          },
        ),
        constraints: const Constraints(requiresNetwork: true),
      );
      _addLog('📤 Scheduled: File Upload ($taskId)');
      _addLog('📁 Local file: $tempFileName');
      _addLog('🏷️ Upload as: $customFileName (image/jpeg)');
      _addLog('👤 With userId: demo-user');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _scheduleFileDownload() async {
    final taskId = 'download-${_taskCounter++}';
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/downloaded-file.json';

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: HttpDownloadWorker(
          url: 'https://httpbin.org/json',
          savePath: savePath,
        ),
        constraints: const Constraints(requiresNetwork: true),
      );
      _addLog('📤 Scheduled: File Download ($taskId)');
      _addLog('💾 Will save to $savePath');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _scheduleFileCompression() async {
    final taskId = 'compress-${_taskCounter++}';
    try {
      // Create a test directory with sample files
      final tempDir = Directory.systemTemp.path;
      final testDir = Directory(
        '$tempDir/test_compress_${DateTime.now().millisecondsSinceEpoch}',
      );
      await testDir.create(recursive: true);

      // Create some test files
      await File(
        '${testDir.path}/file1.txt',
      ).writeAsString('Sample file 1 content\n' * 100);
      await File(
        '${testDir.path}/file2.txt',
      ).writeAsString('Sample file 2 content\n' * 100);
      await File(
        '${testDir.path}/readme.md',
      ).writeAsString('# Test Files\n\nThese are test files for compression.');

      // Create a subdirectory with more files
      final subDir = Directory('${testDir.path}/logs');
      await subDir.create();
      await File(
        '${subDir.path}/app.log',
      ).writeAsString('Log entry 1\nLog entry 2\n' * 50);
      await File(
        '${subDir.path}/error.log',
      ).writeAsString('Error 1\nError 2\n' * 30);

      // Also create files to exclude
      await File(
        '${testDir.path}/temp.tmp',
      ).writeAsString('Temporary file - should be excluded');
      await File(
        '${testDir.path}/.DS_Store',
      ).writeAsString('macOS metadata - should be excluded');

      final outputZip =
          '$tempDir/compressed_${DateTime.now().millisecondsSinceEpoch}.zip';

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCompress(
          inputPath: testDir.path,
          outputPath: outputZip,
          level: CompressionLevel.medium,
          excludePatterns: const ['*.tmp', '.DS_Store'],
          deleteOriginal: false, // Keep original for demo
        ),
      );

      _addLog('📤 Scheduled: File Compression ($taskId)');
      _addLog('📁 Input: ${testDir.path}');
      _addLog('📦 Output: $outputZip');
      _addLog('🚫 Excluding: *.tmp, .DS_Store');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _scheduleCustomDartTask() async {
    final taskId = 'dart-${_taskCounter++}';
    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: DartWorker(callbackId: 'customTask'),
      );
      _addLog('📤 Scheduled: Custom Dart Task ($taskId)');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Widget _buildBackoffPolicyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('v1.0.0: Intelligent Retry (Android)'),
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
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        const _SectionTitle('Android-Only Triggers'),
        const Text(
          'System state triggers (Android only)',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        _buildButton(
          'Schedule All Android Triggers',
          Icons.phone_android,
          _scheduleAndroidTriggers,
          Colors.green,
        ),
        const Text(
          '  Schedules battery-okay, battery-low, device-idle, storage-low',
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
          '  HTTP → Sync → Dart (all sequential)',
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
          '  Download → [Upload1 + Upload2] parallel',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        _buildButton(
          'Hybrid Chain (Native + Dart)',
          Icons.merge_type,
          _scheduleHybridChain,
          Colors.pink,
        ),
        const Text(
          '  Native Download → Dart Process → Native Upload',
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
                  '💡 Hybrid Chain Benefits:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '• Use Native workers for I/O (low memory)\n'
                  '• Use Dart workers for business logic\n'
                  '• Mix both in same chain seamlessly\n'
                  '• Example: Download (2MB) → Process (50MB) → Upload (2MB)',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _scheduleHybridChain() async {
    try {
      await NativeWorkManager.beginWith(
            TaskRequest(
              id: 'hybrid-download',
              worker: HttpRequestWorker(
                url: 'https://httpbin.org/get',
                method: HttpMethod.get,
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'hybrid-process',
              worker: DartWorker(
                callbackId: 'customTask',
                input: {'step': 'processing'},
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'hybrid-upload',
              worker: HttpRequestWorker(
                url: 'https://httpbin.org/post',
                method: HttpMethod.post,
                body: '{"status":"complete"}',
              ),
            ),
          )
          .named('hybrid-chain')
          .enqueue();

      _addLog('📤 Scheduled: Hybrid Chain');
      _addLog('🔗 Native (2MB) → Dart (50MB) → Native (2MB)');
      _addLog('💡 Optimal: Low memory for I/O, Dart for logic');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _scheduleAndroidTriggers() async {
    final triggers = [
      ('battery-okay-${_taskCounter++}', TaskTrigger.batteryOkay()),
      ('battery-low-${_taskCounter++}', TaskTrigger.batteryLow()),
      ('device-idle-${_taskCounter++}', TaskTrigger.deviceIdle()),
      ('storage-low-${_taskCounter++}', TaskTrigger.storageLow()),
    ];
    for (final (id, trigger) in triggers) {
      try {
        await NativeWorkManager.enqueue(
          taskId: id,
          trigger: trigger,
          worker: HttpRequestWorker(
            url: 'https://httpbin.org/get',
            method: HttpMethod.get,
          ),
        );
        _addLog('📤 Scheduled: $id');
      } catch (e) {
        _addLog('❌ $id: $e');
      }
    }
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

  // ═══════════════════════════════════════════════════════════════
  // TAB 10: Custom Native Workers (v1.0.0+)
  // ═══════════════════════════════════════════════════════════════

  Future<void> _scheduleImageCompress() async {
    final taskId = 'image-compress-${_taskCounter++}';
    try {
      // 1. Create a dummy image file in the app's temporary directory
      final tempDir = await getTemporaryDirectory();
      final inputFileName = 'dummy_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final inputFilePath = '${tempDir.path}/$inputFileName';

      // Create a simple dummy JPEG content (e.g., a small red square)
      // This is a minimal valid JPEG header + data for a 1x1 red pixel
      final dummyImageData = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
        0x00, 0x03, 0x02, 0x02, 0x02, 0x02, 0x02, 0x03, 0x02, 0x02, 0x02, 0x03,
        0x03, 0x03, 0x03, 0x04, 0x06, 0x04, 0x04, 0x04, 0x04, 0x04, 0x08, 0x06,
        0x06, 0x05, 0x06, 0x09, 0x08, 0x0A, 0x0A, 0x09, 0x08, 0x09, 0x09, 0x0A,
        0x0C, 0x0F, 0x0C, 0x0A, 0x0B, 0x0E, 0x0B, 0x09, 0x09, 0x0D, 0x11, 0x0D,
        0x0E, 0x0F, 0x10, 0x10, 0x11, 0x10, 0x0A, 0x0C, 0x12, 0x13, 0x12, 0x10,
        0x13, 0x0F, 0x10, 0x10, 0x10, 0xFF, 0xC9, 0x00, 0x0B, 0x08, 0x00, 0x01,
        0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xCC, 0x00, 0x06, 0x00, 0x10,
        0x10, 0x05, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
        0xD2, 0xCF, 0x20, 0xFF, 0xD9,
      ]);
      await File(inputFilePath).writeAsBytes(dummyImageData);

      final outputFileName = 'compressed_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outputFilePath = '${tempDir.path}/$outputFileName';

      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.custom(
          className: 'ImageCompressWorker',
          input: {
            'inputPath': inputFilePath,
            'outputPath': outputFilePath,
            'quality': 85,
            'maxWidth': 1920,
            'maxHeight': 1080,
          },
        ),
      );
      _addLog('🖼️ Scheduled: Image Compression ($taskId)');
      _addLog('📝 Input: $inputFileName, Output: $outputFileName');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Widget _buildCustomWorkerTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('Custom Native Workers (v1.0.0+)'),
        const Text(
          'Extend with your own high-performance native workers\n'
          'Written in Kotlin (Android) and Swift (iOS)',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        const Card(
          color: Colors.green,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✨ What\'s New in v1.0.0',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• Register custom workers without forking the plugin\n'
                  '• Same performance as built-in workers (~2-5MB RAM)\n'
                  '• Support for any native processing (image, crypto, ML, etc.)',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📖 Demo Worker: ImageCompressWorker',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'This demo shows a custom native worker that compresses images:\n\n'
                  '• Android: Uses BitmapFactory (native Android API)\n'
                  '• iOS: Uses UIImage (native iOS API)\n'
                  '• RAM Usage: ~2-5MB (same as built-in HTTP workers)\n'
                  '• Registered in MainActivity.kt / AppDelegate.swift',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildButton(
          'Compress Image (Custom Worker)',
          Icons.compress,
          _scheduleImageCompress,
          Colors.deepPurple,
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        const _SectionTitle('How It Works'),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1️⃣ Implement Worker (Kotlin/Swift)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'See: android/.../ ImageCompressWorker.kt\n'
                  'See: ios/Classes/workers/ImageCompressWorker.swift',
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
                SizedBox(height: 12),
                Text(
                  '2️⃣ Register Worker (MainActivity/AppDelegate)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'SimpleAndroidWorkerFactory.setUserFactory(...)\n'
                  'IosWorkerFactory.registerWorker(...)',
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
                SizedBox(height: 12),
                Text(
                  '3️⃣ Use from Dart',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'NativeWorker.custom(\n'
                  '  className: \'ImageCompressWorker\',\n'
                  '  input: {...},\n'
                  ')',
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          color: Colors.blue,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📚 Documentation',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'See: docs/use-cases/07-custom-native-workers.md\n'
                  'Complete tutorial with examples for image compression,\n'
                  'encryption, database operations, and more.',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          ),
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
                        child: SelectableText(
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
