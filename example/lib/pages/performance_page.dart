import 'dart:async';
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import '../utils/performance_benchmark.dart';

/// Performance monitoring and profiling page.
///
/// Displays:
/// - Real-time performance statistics
/// - Historical metrics
/// - Benchmark results
/// - Performance optimization tips
class PerformancePage extends StatefulWidget {
  const PerformancePage({super.key});

  @override
  State<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<PerformancePage> {
  final _monitor = PerformanceMonitor.instance;
  PerformanceStatistics _stats = PerformanceStatistics.empty();
  BenchmarkResults? _benchmarkResults;
  bool _isRunningBenchmarks = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _monitor.enable();
    _updateStats();

    // Refresh stats every 2 seconds using Timer (properly cancelable)
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _updateStats();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _updateStats() {
    if (!mounted) return;
    setState(() {
      _stats = _monitor.getStatistics();
    });
  }

  Future<void> _runBenchmarks() async {
    setState(() {
      _isRunningBenchmarks = true;
    });

    // Show initial snackbar with estimated time
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🏃 Running benchmarks... (Est. ~30-60 seconds)'),
        duration: Duration(seconds: 3),
      ),
    );

    try {
      final results = await PerformanceBenchmark.runAll();
      if (mounted) {
        setState(() {
          _benchmarkResults = results;
          _isRunningBenchmarks = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Benchmarks completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunningBenchmarks = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Benchmark error: $e')),
        );
      }
    }
  }

  void _clearData() {
    _monitor.clear();
    setState(() {
      _stats = PerformanceStatistics.empty();
      _benchmarkResults = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Monitor'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateStats,
            tooltip: 'Refresh statistics',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearData,
            tooltip: 'Clear data',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Text(
            'Performance Monitoring',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Real-time performance metrics and benchmarks',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Overview Card
          _buildOverviewCard(),
          const SizedBox(height: 16),

          // Performance Metrics
          _buildMetricsCard(),
          const SizedBox(height: 16),

          // Worker Type Statistics
          if (_stats.workerTypeStatistics.isNotEmpty) ...[
            _buildWorkerTypeStatsCard(),
            const SizedBox(height: 16),
          ],

          // Benchmarks Section
          _buildBenchmarksCard(),
          const SizedBox(height: 16),

          // Optimization Tips
          _buildOptimizationTipsCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Overview',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    'Total Tasks',
                    '${_stats.totalTasksScheduled}',
                  ),
                ),
                Expanded(
                  child: _buildStatTile(
                    'Completed',
                    '${_stats.totalTasksCompleted}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    'Successful',
                    '${_stats.totalTasksSuccessful}',
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatTile(
                    'Failed',
                    '${_stats.totalTasksFailed}',
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    'Success Rate',
                    '${(_stats.successRate * 100).toStringAsFixed(1)}%',
                    color: _stats.successRate > 0.9
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatTile(
                    'Monitoring',
                    '${_stats.monitoringDuration.inSeconds}s',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Performance Metrics',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              'Average Task Duration',
              '${_stats.averageTaskDuration.toStringAsFixed(1)} ms',
            ),
            _buildMetricRow('Min Duration', '${_stats.minTaskDuration} ms'),
            _buildMetricRow('Max Duration', '${_stats.maxTaskDuration} ms'),
            _buildMetricRow(
              'Avg Event Latency',
              '${_stats.averageEventDispatchLatency.toStringAsFixed(1)} ms',
            ),
            _buildMetricRow(
              'Throughput',
              '${_stats.tasksPerMinute.toStringAsFixed(2)} tasks/min',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerTypeStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.category,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Worker Type Statistics',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._stats.workerTypeStatistics.entries.map((entry) {
              final stats = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.workerType,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tasks: ${stats.totalTasks}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Avg: ${stats.averageDuration.toStringAsFixed(1)}ms',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Success: ${(stats.successRate * 100).toStringAsFixed(1)}%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBenchmarksCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Performance Benchmarks',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isRunningBenchmarks)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _runBenchmarks,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Run'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_benchmarkResults != null) ...[
              if (_benchmarkResults!.taskStartupLatency != null)
                _buildBenchmarkResultTile(
                  _benchmarkResults!.taskStartupLatency!,
                ),
              if (_benchmarkResults!.chainExecutionPerformance != null)
                _buildBenchmarkResultTile(
                  _benchmarkResults!.chainExecutionPerformance!,
                ),
              if (_benchmarkResults!.eventDispatchLatency != null)
                _buildBenchmarkResultTile(
                  _benchmarkResults!.eventDispatchLatency!,
                ),
              if (_benchmarkResults!.throughput != null)
                _buildBenchmarkResultTile(_benchmarkResults!.throughput!),
            ] else if (_isRunningBenchmarks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Running benchmarks...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This may take 30-60 seconds',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Testing task startup latency (10 iterations)\n'
                      '• Testing chain execution (5 iterations)\n'
                      '• Testing event dispatch latency\n'
                      '• Testing throughput',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Click "Run" to start benchmarks\n(Est. 30-60 seconds)',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenchmarkResultTile(BenchmarkResult result) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildBenchmarkStat(
                  'Avg',
                  '${result.average.toStringAsFixed(2)} ${result.unit}',
                ),
              ),
              Expanded(
                child: _buildBenchmarkStat(
                  'Median',
                  '${result.median.toStringAsFixed(2)} ${result.unit}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _buildBenchmarkStat(
                  'Min',
                  '${result.min} ${result.unit}',
                ),
              ),
              Expanded(
                child: _buildBenchmarkStat(
                  'Max',
                  '${result.max} ${result.unit}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizationTipsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Optimization Tips',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTipItem(
              'Use constraints to avoid unnecessary task executions',
            ),
            _buildTipItem(
              'Batch multiple operations into chains for better efficiency',
            ),
            _buildTipItem(
              'Use periodic tasks instead of frequent one-time tasks',
            ),
            _buildTipItem('Set appropriate backoff policies for retry logic'),
            _buildTipItem('Monitor success rate and investigate failures'),
            _buildTipItem('Use isHeavyTask constraint for CPU-intensive work'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBenchmarkStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTipItem(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(tip, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
