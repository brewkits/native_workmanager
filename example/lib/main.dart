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
import 'pages/case_study_page.dart';
import 'examples/chain_resilience_test.dart';
import 'examples/chain_data_flow_demo.dart';
import 'screens/bug_fix_demo_screen.dart';

/// workmanager background callback.
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

  // Initialize workmanager (for A/B benchmark comparison only)
  Workmanager().initialize(flutterWorkmanagerCallback);

  // Initialize native_workmanager
  await NativeWorkManager.initialize(
    dartWorkers: {
      'customTask': customTaskCallback,
      'heavyTask': heavyTaskCallback,
      'benchHeavyCompute': benchHeavyComputeCallback,
      // Stress & System Test Workers
      'stress_worker': stressWorkerCallback,
      'media_processor': mediaProcessorCallback,
      'large_payload': largePayloadWorkerCallback,
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

@pragma('vm:entry-point')
Future<bool> stressWorkerCallback(Map<String, dynamic>? input) async {
  final int index = input?['index'] ?? 0;
  debugPrint('[StressWorker] index=$index starting...');
  await Future.delayed(const Duration(milliseconds: 100));
  return true;
}

@pragma('vm:entry-point')
Future<bool> mediaProcessorCallback(Map<String, dynamic>? input) async {
  debugPrint('[MediaProcessor] input=$input');
  return true;
}

@pragma('vm:entry-point')
Future<bool> largePayloadWorkerCallback(Map<String, dynamic>? input) async {
  final data = input?['data'] as String?;
  final len = data?.length ?? 0;
  debugPrint('[LargePayloadWorker] received data length: $len');
  return len > 0;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Custom Seed Color for a high-end feel
    const seedColor = Color(0xFF6750A4); // Deep Royal Purple

    return MaterialApp(
      title: 'Brewkits Native WorkManager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Inter', // Modern clean font
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
          surface: const Color(0xFF121212),
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          clipBehavior: Clip.antiAlias,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  int _selectedIndex = 0;
  final List<String> _logs = [];
  int _taskCounter = 0;
  bool _showMetricsOverlay = false;
  bool _logExpanded = true;

  static const _pageTitles = [
    'Quick Demo',
    'All Scenarios',
    'Performance',
    'Benchmark',
    'Production Impact',
    'User Case Studies',
    'Bug Fixes',
    'Core API',
    'Transfer',
    'Reliability',
    'Environment',
    'Workflows',
    'Scheduling',
    'Extensibility',
    'Resilience',
    'Data Flow',
  ];

  @override
  void initState() {
    super.initState();

    // Listen to task events (v2.3.0+: includes resultData)
    NativeWorkManager.events.listen((event) {
      if (!mounted) return;
      setState(() {
        String logMessage;
        if (event.isStarted) {
          // isStarted events are NOT failures — task just began execution.
          logMessage =
              '${_formatTime(event.timestamp)} ▶️ ${event.taskId}: Started';
        } else {
          logMessage =
              '${_formatTime(event.timestamp)} ${event.success ? "✅" : "❌"} ${event.taskId}: ${event.message ?? (event.success ? "Success" : "Failed")}';

          if (event.resultData != null && event.resultData!.isNotEmpty) {
            final data = event.resultData!;
            if (data.containsKey('filePath')) {
              logMessage +=
                  ' | File: ${data['fileName']}, Size: ${data['fileSize']} bytes';
            } else if (data.containsKey('statusCode')) {
              logMessage += ' | HTTP ${data['statusCode']}';
            }
          }
        }

        _logs.insert(0, logMessage);
        if (_logs.length > 100) _logs.removeLast();
      });
    });

    _addLog('🚀 NativeWorkManager v1.1.1 — High-Performance Background Engine');
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '${_formatTime(DateTime.now())} $message');
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  // Task scheduling methods remain unchanged...
  Future<void> _scheduleHttpGet() async {
    final taskId = 'get-${_taskCounter++}';
    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/get',
          method: HttpMethod.get,
        ),
      );
      _addLog('📤 Enqueued: HTTP GET ($taskId)');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _scheduleHttpPost() async {
    final taskId = 'post-${_taskCounter++}';
    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://httpbin.org/post',
          method: HttpMethod.post,
          headers: const {'Content-Type': 'application/json'},
          body: '{"ts":${DateTime.now().millisecondsSinceEpoch}}',
        ),
      );
      _addLog('📤 Enqueued: HTTP POST ($taskId)');
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
            'ts': DateTime.now().millisecondsSinceEpoch,
            'v': '1.0.8',
          },
        ),
        constraints: const Constraints(requiresNetwork: true),
      );
      _addLog('📤 Enqueued: Sync ($taskId)');
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
      _addLog('📤 Enqueued: Dart Task ($taskId)');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Row(
        children: [
          // Navigation Rail for larger screens or modern feel
          if (MediaQuery.of(context).size.width > 900)
            NavigationRail(
              selectedIndex: _selectedIndex < 15 ? _selectedIndex : 0,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              labelType: NavigationRailLabelType.selected,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bolt_outlined),
                  selectedIcon: Icon(Icons.bolt),
                  label: Text('Tasks'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.speed_outlined),
                  selectedIcon: Icon(Icons.speed),
                  label: Text('Metrics'),
                ),
              ],
            ),

          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar.large(
                  title: Text(
                    _pageTitles[_selectedIndex],
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  centerTitle: false,
                  actions: [
                    IconButton.filledTonal(
                      icon: Icon(
                        _showMetricsOverlay
                            ? Icons.analytics
                            : Icons.analytics_outlined,
                      ),
                      onPressed: () => setState(
                        () => _showMetricsOverlay = !_showMetricsOverlay,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Builder(
                      builder: (context) => IconButton.filledTonal(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: [
                          const DemoScenariosPage(), // 0
                          const ComprehensiveDemoPage(), // 1
                          const PerformancePage(), // 2
                          const ManualBenchmarkPage(), // 3
                          const ProductionImpactPageImproved(), // 4
                          const CaseStudyPage(), // 5
                          const BugFixDemoScreen(), // 6
                          _buildModernGridTab(), // 7
                          const Center(
                            child: Text('Transfer Page Content'),
                          ), // 8
                          const Center(
                            child: Text('Reliability Page Content'),
                          ), // 9
                          const Center(
                            child: Text('Environment Page Content'),
                          ), // 10
                          const Center(
                            child: Text('Workflow Page Content'),
                          ), // 11
                          const Center(
                            child: Text('Scheduling Page Content'),
                          ), // 12
                          const Center(
                            child: Text('Extensibility Page Content'),
                          ), // 13
                          const ChainResilienceTest(), // 14
                          const ChainDataFlowDemo(), // 15
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 220)),
              ],
            ),
          ),
        ],
      ),
      drawer: NavigationDrawer(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          setState(() => _selectedIndex = i);
          Navigator.pop(context);
        },
        children: [
          const _DrawerHeader(),
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
            child: Text(
              'MAIN FEATURES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.rocket_launch_outlined),
            label: Text('All Scenarios'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.layers_outlined),
            label: Text('Built-in Workers'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
            child: Text(
              'PERFORMANCE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.speed_outlined),
            label: Text('Core Performance'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.timer_outlined),
            label: Text('Manual Benchmarks'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.insights_outlined),
            label: Text('Production Impact'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
            child: Text(
              'CASE STUDIES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.auto_stories_outlined),
            label: Text('User Case Studies'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
            child: Text(
              'DEVELOPER',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.bug_report_outlined),
            label: Text('Bug Regression'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.api_outlined),
            label: Text('Core API'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.swap_vert_outlined),
            label: Text('Transfer & Files'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.refresh_outlined),
            label: Text('Reliability & Retry'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.security_outlined),
            label: Text('Constraints'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.link_outlined),
            label: Text('Task Chains'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.schedule_outlined),
            label: Text('Scheduling'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.extension_outlined),
            label: Text('Custom Native'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.account_tree_outlined),
            label: Text('Resilience'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.device_hub_outlined),
            label: Text('Data Flow'),
          ),
        ],
      ),
      bottomSheet: _buildLogTerminal(colorScheme),
      floatingActionButton: _selectedIndex == 6
          ? FloatingActionButton.extended(
              onPressed: () => NativeWorkManager.cancelAll().then(
                (_) => _addLog('🧹 Cleared all tasks'),
              ),
              label: const Text('Clear All'),
              icon: const Icon(Icons.delete_outline),
            )
          : null,
    );
  }

  Widget _buildModernGridTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildInfoCard(),
        const SizedBox(height: 24),
        const _SectionHeader('NATIVE WORKERS', 'Low-overhead processing'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildActionCard(
              'HTTP GET',
              Icons.download,
              Colors.blue,
              _scheduleHttpGet,
            ),
            _buildActionCard(
              'HTTP POST',
              Icons.upload,
              Colors.green,
              _scheduleHttpPost,
            ),
            _buildActionCard(
              'JSON Sync',
              Icons.sync,
              Colors.orange,
              _scheduleSync,
            ),
            _buildActionCard(
              'Download',
              Icons.file_download,
              Colors.teal,
              () => setState(() => _selectedIndex = 7),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionHeader('DART WORKERS', 'Full framework access'),
        const SizedBox(height: 12),
        _buildActionCard(
          'Execute Custom Dart Task',
          Icons.code,
          Colors.purple,
          _scheduleCustomDartTask,
          wide: true,
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 32),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Architecture Choice',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'Mode 1 (Native) uses 2-5MB RAM. Mode 2 (Dart) uses 30-50MB RAM. Brewkits lets you choose based on task complexity.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool wide = false,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogTerminal(ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: _logExpanded ? 200 : 48,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header — always visible, tap to toggle
          InkWell(
            onTap: () => setState(() => _logExpanded = !_logExpanded),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: SizedBox(
                height: 46,
                child: Row(
                  children: [
                    const Icon(Icons.terminal, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'ENGINE LOG',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_logs.isNotEmpty)
                      Text(
                        '(${_logs.length})',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const Spacer(),
                    if (_logExpanded)
                      IconButton(
                        icon: const Icon(Icons.clear_all, size: 16),
                        onPressed: () => setState(() => _logs.clear()),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        tooltip: 'Clear log',
                      ),
                    IconButton(
                      icon: Icon(
                        _logExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _logExpanded = !_logExpanded),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
          // Log list — only visible when expanded
          if (_logExpanded)
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      _logs[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        height: 1.4,
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

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Brewkits Native',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const Text(
            'WorkManager SDK',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader(this.title, this.subtitle);
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.grey,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }
}
