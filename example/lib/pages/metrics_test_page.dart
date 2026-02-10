/// Test page for real-time metrics collection
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../core/core.dart';

class MetricsTestPage extends StatefulWidget {
  const MetricsTestPage({super.key});

  @override
  State<MetricsTestPage> createState() => _MetricsTestPageState();
}

class _MetricsTestPageState extends State<MetricsTestPage> {
  final _metricsCollector = MetricsCollector();

  MemoryMetrics? _memoryMetrics;
  CPUMetrics? _cpuMetrics;
  BatteryMetrics? _batteryMetrics;

  String? _error;
  bool _isMonitoring = false;

  StreamSubscription<MemoryMetrics>? _memorySubscription;
  StreamSubscription<CPUMetrics>? _cpuSubscription;
  StreamSubscription<BatteryMetrics>? _batterySubscription;

  @override
  void initState() {
    super.initState();
    _loadInitialMetrics();
  }

  @override
  void dispose() {
    _stopMonitoring();
    super.dispose();
  }

  Future<void> _loadInitialMetrics() async {
    try {
      final memory = await _metricsCollector.getMemoryUsage();
      final cpu = await _metricsCollector.getCpuUsage();
      final battery = await _metricsCollector.getBatteryMetrics();

      if (mounted) {
        setState(() {
          _memoryMetrics = memory;
          _cpuMetrics = cpu;
          _batteryMetrics = battery;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  void _startMonitoring() {
    if (_isMonitoring) return;

    setState(() {
      _isMonitoring = true;
      _error = null;
    });

    _metricsCollector.startMonitoring(interval: const Duration(seconds: 2));

    _memorySubscription = _metricsCollector.memoryStream.listen(
      (metrics) {
        if (mounted) {
          setState(() {
            _memoryMetrics = metrics;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = 'Memory monitoring error: $error';
          });
        }
      },
    );

    _cpuSubscription = _metricsCollector.cpuStream.listen(
      (metrics) {
        if (mounted) {
          setState(() {
            _cpuMetrics = metrics;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = 'CPU monitoring error: $error';
          });
        }
      },
    );

    _batterySubscription = _metricsCollector.batteryStream.listen(
      (metrics) {
        if (mounted) {
          setState(() {
            _batteryMetrics = metrics;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = 'Battery monitoring error: $error';
          });
        }
      },
    );
  }

  void _stopMonitoring() {
    if (!_isMonitoring) return;

    setState(() {
      _isMonitoring = false;
    });

    _metricsCollector.stopMonitoring();
    _memorySubscription?.cancel();
    _cpuSubscription?.cancel();
    _batterySubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Metrics Test'),
        actions: [
          IconButton(
            icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
            onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
            tooltip: _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialMetrics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            ),

          _buildStatusCard(),
          const SizedBox(height: 16),

          _buildMemoryCard(),
          const SizedBox(height: 16),

          _buildCPUCard(),
          const SizedBox(height: 16),

          _buildBatteryCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: ListTile(
        leading: Icon(
          _isMonitoring
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: _isMonitoring ? Colors.green : Colors.grey,
        ),
        title: Text(_isMonitoring ? 'Monitoring Active' : 'Monitoring Stopped'),
        subtitle: Text(
          _isMonitoring
              ? 'Real-time updates every 2 seconds'
              : 'Tap play button to start monitoring',
        ),
      ),
    );
  }

  Widget _buildMemoryCard() {
    final memory = _memoryMetrics;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Memory Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            if (memory == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No data available'),
                ),
              )
            else ...[
              _buildMetricRow(
                'App RAM',
                '${memory.appRAMMB.toStringAsFixed(1)} MB',
              ),
              _buildMetricRow(
                'Available RAM',
                '${memory.availableRAMMB.toStringAsFixed(1)} MB',
              ),
              _buildMetricRow(
                'Total RAM',
                '${memory.totalRAMMB.toStringAsFixed(0)} MB',
              ),
              _buildMetricRow(
                'Memory Usage',
                '${memory.memoryUsagePercent.toStringAsFixed(1)}%',
              ),
              _buildMetricRow(
                'Dart Heap',
                '${(memory.dartHeap / 1024 / 1024).toStringAsFixed(1)} MB',
              ),
              _buildMetricRow(
                'Native Heap',
                '${(memory.nativeHeap / 1024 / 1024).toStringAsFixed(1)} MB',
              ),
              const SizedBox(height: 8),
              Text(
                'Updated: ${_formatTime(memory.timestamp)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCPUCard() {
    final cpu = _cpuMetrics;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  'CPU Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            if (cpu == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No data available'),
                ),
              )
            else ...[
              _buildMetricRow(
                'CPU Usage',
                '${cpu.cpuUsage.toStringAsFixed(1)}%',
              ),
              _buildMetricRow('CPU Cores', '${cpu.cpuCores}'),
              const SizedBox(height: 8),
              Text(
                'Updated: ${_formatTime(cpu.timestamp)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryCard() {
    final battery = _batteryMetrics;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.battery_std, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Battery Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            if (battery == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No data available'),
                ),
              )
            else ...[
              _buildMetricRow(
                'Battery Level',
                '${battery.level.toStringAsFixed(1)}%',
              ),
              _buildMetricRow('Charging', battery.isCharging ? 'Yes' : 'No'),
              if (battery.drainRate > 0)
                _buildMetricRow(
                  'Drain Rate',
                  '${battery.drainRate.toStringAsFixed(2)}% / hour',
                ),
              const SizedBox(height: 8),
              Text(
                'Updated: ${_formatTime(battery.timestamp)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
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

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}
