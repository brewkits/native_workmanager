import 'dart:async';
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Draggable floating overlay showing real-time performance metrics
class FloatingMetricsOverlay extends StatefulWidget {
  const FloatingMetricsOverlay({super.key});

  @override
  State<FloatingMetricsOverlay> createState() => _FloatingMetricsOverlayState();
}

class _FloatingMetricsOverlayState extends State<FloatingMetricsOverlay> {
  // Position
  double _x = 20;
  double _y = 100;

  // Metrics
  int _memoryUsageMB = 0;
  int _totalTasks = 0;
  int _successfulTasks = 0;
  int _failedTasks = 0;
  String _lastTaskTime = '--:--:--';
  String _lastTaskId = 'None';
  bool _lastTaskSuccess = true;
  int _executionTimeMs = 0;

  // UI State
  bool _isExpanded = true;
  bool _isDragging = false;

  // Timers
  Timer? _memoryTimer;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  @override
  void dispose() {
    _memoryTimer?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _startMonitoring() {
    // Update memory every 2 seconds
    _memoryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateMemoryUsage();
    });

    // Listen to task events
    _eventSubscription = NativeWorkManager.events.listen((event) {
      setState(() {
        _totalTasks++;
        if (event.success) {
          _successfulTasks++;
        } else {
          _failedTasks++;
        }
        _lastTaskId = event.taskId;
        _lastTaskSuccess = event.success;
        _lastTaskTime = _formatTime(event.timestamp);

        // Estimate execution time (simplified)
        _executionTimeMs = 50; // Default for native workers
        if (event.taskId.contains('dart') || event.taskId.contains('heavy')) {
          _executionTimeMs = 800; // Estimated for Dart workers
        }
      });
    });

    // Initial memory update
    _updateMemoryUsage();
  }

  void _updateMemoryUsage() {
    // Get current process memory (simplified)
    // In real app, use package like 'system_info' or native channels
    setState(() {
      // Simulate memory reading (replace with actual memory API)
      _memoryUsageMB = ProcessInfo.currentRss ~/ (1024 * 1024);
    });
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  double get _successRate {
    if (_totalTasks == 0) return 0;
    return (_successfulTasks / _totalTasks) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _x += details.delta.dx;
            _y += details.delta.dy;

            // Keep within screen bounds
            final size = MediaQuery.of(context).size;
            _x = _x.clamp(0, size.width - 200);
            _y = _y.clamp(0, size.height - (_isExpanded ? 280 : 60));
          });
        },
        onPanEnd: (_) {
          setState(() {
            _isDragging = false;
          });
        },
        child: Material(
          elevation: _isDragging ? 12 : 6,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.black.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                if (_isExpanded) ...[_buildMetricsBody()],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.speed, color: Colors.blue, size: 16),
          const SizedBox(width: 8),
          const Text(
            'Metrics',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          // Memory badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getMemoryColor(),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$_memoryUsageMB MB',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Expand/collapse button
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.white70,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Color _getMemoryColor() {
    if (_memoryUsageMB < 10) return Colors.green;
    if (_memoryUsageMB < 50) return Colors.orange;
    return Colors.red;
  }

  Widget _buildMetricsBody() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task statistics
          _buildMetricRow(
            icon: Icons.task_alt,
            label: 'Tasks',
            value: '$_totalTasks',
            color: Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildMetricRow(
            icon: Icons.check_circle,
            label: 'Success',
            value: '$_successfulTasks',
            color: Colors.green,
          ),
          const SizedBox(height: 8),
          _buildMetricRow(
            icon: Icons.error,
            label: 'Failed',
            value: '$_failedTasks',
            color: Colors.red,
          ),
          const SizedBox(height: 8),

          // Success rate bar
          _buildSuccessRateBar(),

          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),

          // Last task info
          _buildLastTaskInfo(),

          const SizedBox(height: 12),

          // Performance indicator
          _buildPerformanceIndicator(),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessRateBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Success Rate',
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
            Text(
              '${_successRate.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _successRate / 100,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(
              _successRate >= 90
                  ? Colors.green
                  : _successRate >= 70
                  ? Colors.orange
                  : Colors.red,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildLastTaskInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _lastTaskSuccess ? Icons.check_circle : Icons.error,
                color: _lastTaskSuccess ? Colors.green : Colors.red,
                size: 12,
              ),
              const SizedBox(width: 6),
              const Text(
                'Last Task',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _lastTaskId,
            style: const TextStyle(color: Colors.white, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            _lastTaskTime,
            style: const TextStyle(color: Colors.white54, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceIndicator() {
    final bool isFast = _executionTimeMs < 100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: (isFast ? Colors.green : Colors.orange).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isFast ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFast ? Icons.flash_on : Icons.hourglass_bottom,
            color: isFast ? Colors.green : Colors.orange,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            isFast ? 'Native Worker' : 'Dart Worker',
            style: TextStyle(
              color: isFast ? Colors.green : Colors.orange,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '~${_executionTimeMs}ms',
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

/// Simple process info helper (replace with actual implementation)
class ProcessInfo {
  static int get currentRss {
    // Simplified - in real app use platform channels or packages
    // For demo, return estimated value based on worker type
    return 45 * 1024 * 1024; // ~45MB (typical Flutter app)
  }
}
