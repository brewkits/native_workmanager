/// A/B Testing UI for comparing native_workmanager vs workmanager
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/core.dart';

class ABTestingPage extends StatefulWidget {
  const ABTestingPage({super.key});

  @override
  State<ABTestingPage> createState() => _ABTestingPageState();
}

class _ABTestingPageState extends State<ABTestingPage>
    with SingleTickerProviderStateMixin {
  final _testingService = ABTestingService();
  late TabController _tabController;

  ABTestComparison? _lastComparison;
  ABTestProgress? _currentProgress;
  final List<LiveMetrics> _liveMetricsList = [];

  StreamSubscription<ABTestProgress>? _progressSubscription;
  StreamSubscription<LiveMetrics>? _liveMetricsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    // Listen to test progress
    _progressSubscription = _testingService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _currentProgress = progress;
        });

        if (progress.phase == TestPhase.completed) {
          // Switch to results tab
          _tabController.animateTo(3);
        }
      }
    });

    // Listen to live metrics
    _liveMetricsSubscription = _testingService.liveMetricsStream.listen((
      metrics,
    ) {
      if (mounted) {
        setState(() {
          _liveMetricsList.add(metrics);
          // Keep only last 60 samples (1 minute at 1s interval)
          if (_liveMetricsList.length > 60) {
            _liveMetricsList.removeAt(0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _progressSubscription?.cancel();
    _liveMetricsSubscription?.cancel();
    _testingService.dispose();
    super.dispose();
  }

  Future<void> _runQuickTest() async {
    setState(() {
      _liveMetricsList.clear();
      _lastComparison = null;
    });

    _tabController.animateTo(2); // Switch to live metrics

    try {
      final comparison = await _testingService.runTest(
        ABTestConfig.quickTest(),
      );

      if (mounted) {
        setState(() {
          _lastComparison = comparison;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Test failed: $e')));
      }
    }
  }

  Future<void> _runCustomTest(ABTestConfig config) async {
    setState(() {
      _liveMetricsList.clear();
      _lastComparison = null;
    });

    _tabController.animateTo(2); // Switch to live metrics

    try {
      final comparison = await _testingService.runTest(config);

      if (mounted) {
        setState(() {
          _lastComparison = comparison;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Test failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('A/B Testing'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Quick Test'),
            Tab(text: 'Custom Test'),
            Tab(text: 'Live Metrics'),
            Tab(text: 'Results'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuickTestTab(),
          _buildCustomTestTab(),
          _buildLiveMetricsTab(),
          _buildResultsTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildQuickTestTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Performance Test',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Run a fast comparison between native_workmanager and workmanager with 5 simple tasks.',
                ),
                const SizedBox(height: 16),
                const Divider(),
                _buildInfoRow('Tasks', '5'),
                _buildInfoRow('Delay', '500ms'),
                _buildInfoRow('Scenario', 'Quick Test'),
                _buildInfoRow('Duration', '~5 seconds'),
                const SizedBox(height: 16),
                if (_testingService.isTestRunning && _currentProgress != null)
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _currentProgress!.progress,
                      ),
                      const SizedBox(height: 8),
                      Text(_currentProgress!.message),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _runQuickTest,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Run Quick Test'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomTestTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Custom Test Scenarios',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        _buildScenarioCard(
          scenario: TestScenario.httpOperations,
          icon: Icons.http,
          color: Colors.blue,
          config: ABTestConfig.httpTest(),
        ),
        _buildScenarioCard(
          scenario: TestScenario.stressTest,
          icon: Icons.speed,
          color: Colors.red,
          config: ABTestConfig.stressTest(),
        ),
        _buildScenarioCard(
          scenario: TestScenario.fileTransfer,
          icon: Icons.file_download,
          color: Colors.green,
          config: const ABTestConfig(
            scenario: TestScenario.fileTransfer,
            taskCount: 10,
            taskDelayMs: 1000,
          ),
        ),
        _buildScenarioCard(
          scenario: TestScenario.periodicTasks,
          icon: Icons.update,
          color: Colors.orange,
          config: const ABTestConfig(
            scenario: TestScenario.periodicTasks,
            taskCount: 15,
            taskDelayMs: 800,
          ),
        ),
        _buildScenarioCard(
          scenario: TestScenario.chainedTasks,
          icon: Icons.link,
          color: Colors.purple,
          config: const ABTestConfig(
            scenario: TestScenario.chainedTasks,
            taskCount: 8,
            taskDelayMs: 1500,
          ),
        ),
        _buildScenarioCard(
          scenario: TestScenario.batteryTest,
          icon: Icons.battery_full,
          color: Colors.amber,
          config: const ABTestConfig(
            scenario: TestScenario.batteryTest,
            taskCount: 5,
            taskDelayMs: 2000,
          ),
        ),
      ],
    );
  }

  Widget _buildScenarioCard({
    required TestScenario scenario,
    required IconData icon,
    required Color color,
    required ABTestConfig config,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(51),
          child: Icon(icon, color: color),
        ),
        title: Text(scenario.title),
        subtitle: Text(scenario.description),
        trailing: _testingService.isTestRunning
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward_ios),
        onTap: _testingService.isTestRunning
            ? null
            : () => _runCustomTest(config),
      ),
    );
  }

  Widget _buildLiveMetricsTab() {
    if (_liveMetricsList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No live metrics available'),
            SizedBox(height: 8),
            Text('Run a test to see real-time metrics'),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_currentProgress != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Progress',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _currentProgress!.progress),
                  const SizedBox(height: 8),
                  Text(_currentProgress!.message),
                  if (_currentProgress!.currentTaskCount != null)
                    Text(
                      '${_currentProgress!.currentTaskCount}/${_currentProgress!.totalTaskCount} tasks',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Memory chart
        _buildChartCard(
          title: 'Memory Usage (MB)',
          color: Colors.blue,
          data: _liveMetricsList.map((m) => m.memory.appRAMMB).toList(),
        ),

        // CPU chart
        _buildChartCard(
          title: 'CPU Usage (%)',
          color: Colors.orange,
          data: _liveMetricsList.map((m) => m.cpu.cpuUsage).toList(),
        ),

        // Battery chart
        _buildChartCard(
          title: 'Battery Level (%)',
          color: Colors.green,
          data: _liveMetricsList.map((m) => m.battery.level).toList(),
        ),
      ],
    );
  }

  Widget _buildChartCard({
    required String title,
    required Color color,
    required List<double> data,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: data.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value);
                      }).toList(),
                      isCurved: true,
                      color: color,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsTab() {
    if (_lastComparison == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assessment, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No results available'),
            SizedBox(height: 8),
            Text('Run a test to see comparison results'),
          ],
        ),
      );
    }

    final comparison = _lastComparison!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Winner card
        Card(
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
                const SizedBox(height: 8),
                const Text(
                  'Winner',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  comparison.winner,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Speed comparison
        _buildComparisonCard(
          title: 'Speed',
          icon: Icons.speed,
          color: Colors.blue,
          native: comparison.nativeResult.avgExecutionTime,
          flutter: comparison.flutterResult?.avgExecutionTime ?? 0,
          unit: 'ms',
          lowerIsBetter: true,
        ),

        // Memory comparison
        _buildComparisonCard(
          title: 'Peak Memory',
          icon: Icons.memory,
          color: Colors.orange,
          native: comparison.nativeResult.peakMemoryMB,
          flutter: comparison.flutterResult?.peakMemoryMB ?? 0,
          unit: 'MB',
          lowerIsBetter: true,
        ),

        // CPU comparison
        _buildComparisonCard(
          title: 'CPU Usage',
          icon: Icons.show_chart,
          color: Colors.purple,
          native: comparison.nativeResult.avgCpuUsage,
          flutter: comparison.flutterResult?.avgCpuUsage ?? 0,
          unit: '%',
          lowerIsBetter: true,
        ),

        // Battery drain comparison
        _buildComparisonCard(
          title: 'Battery Drain',
          icon: Icons.battery_alert,
          color: Colors.red,
          native: comparison.nativeResult.batteryDrainRate,
          flutter: comparison.flutterResult?.batteryDrainRate ?? 0,
          unit: '%/h',
          lowerIsBetter: true,
        ),

        // Success rate
        _buildComparisonCard(
          title: 'Success Rate',
          icon: Icons.check_circle,
          color: Colors.green,
          native: comparison.nativeResult.successRate * 100,
          flutter: (comparison.flutterResult?.successRate ?? 0) * 100,
          unit: '%',
          lowerIsBetter: false,
        ),
      ],
    );
  }

  Widget _buildComparisonCard({
    required String title,
    required IconData icon,
    required Color color,
    required double native,
    required double flutter,
    required String unit,
    required bool lowerIsBetter,
  }) {
    final nativeWins = lowerIsBetter ? native < flutter : native > flutter;
    final improvement = flutter > 0
        ? ((flutter - native) / flutter * 100).abs()
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildValueColumn(
                  'native_workmanager',
                  native,
                  unit,
                  nativeWins,
                ),
                const Icon(Icons.compare_arrows),
                _buildValueColumn(
                  'workmanager',
                  flutter,
                  unit,
                  !nativeWins,
                ),
              ],
            ),
            if (improvement > 0) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${improvement.toStringAsFixed(1)}% ${lowerIsBetter ? 'faster' : 'better'}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValueColumn(
    String label,
    double value,
    String unit,
    bool isWinner,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${value.toStringAsFixed(1)} $unit',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isWinner ? Colors.green : null,
              ),
            ),
            if (isWinner) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_circle, size: 16, color: Colors.green),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    final history = _testingService.testHistory;

    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No test history'),
            SizedBox(height: 8),
            Text('Your test results will appear here'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final comparison = history[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Icon(Icons.assessment, color: Colors.blue.shade700),
            ),
            title: Text(comparison.scenario.title),
            subtitle: Text(
              '${_formatDateTime(comparison.timestamp)}\n'
              'Winner: ${comparison.winner}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () {
                setState(() {
                  _lastComparison = comparison;
                  _tabController.animateTo(3); // Switch to results
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
