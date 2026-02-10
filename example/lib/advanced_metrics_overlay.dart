import 'dart:async';
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Advanced draggable metrics overlay with multiple modes
class AdvancedMetricsOverlay extends StatefulWidget {
  const AdvancedMetricsOverlay({super.key});

  @override
  State<AdvancedMetricsOverlay> createState() => _AdvancedMetricsOverlayState();
}

class _AdvancedMetricsOverlayState extends State<AdvancedMetricsOverlay>
    with SingleTickerProviderStateMixin {
  // Position
  double _x = 20;
  double _y = 100;

  // Display mode: mini, compact, full
  DisplayMode _mode = DisplayMode.compact;

  // Metrics
  double _memoryMB = 45.0;
  double _cpuPercent = 0.0;
  int _batteryLevel = 100;
  int _totalTasks = 0;
  int _successfulTasks = 0;
  int _failedTasks = 0;
  String _lastTaskTime = '--:--';
  String _lastTaskId = 'None';
  bool _lastTaskSuccess = true;
  WorkerType _lastWorkerType = WorkerType.native;

  // Performance history (for graphs)
  final List<double> _memoryHistory = [];
  final List<double> _cpuHistory = [];
  static const int _maxHistoryLength = 30;

  // UI State
  bool _isDragging = false;
  late AnimationController _pulseController;

  // Timers
  Timer? _updateTimer;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _startMonitoring();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _updateTimer?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
  }

  // Placeholder methods for system metrics
  Future<double> getMemoryUsageMB() async {
    return 60.0; // Dummy value
  }

  Future<double> getCpuUsage() async {
    return 15.0; // Dummy value
  }

  Future<int> getBatteryLevel() async {
    return 80; // Dummy value
  }

  void _startMonitoring() {
    // Update metrics every 2 seconds
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final memory = await getMemoryUsageMB();
      final cpu = await getCpuUsage();
      final battery = await getBatteryLevel();

      setState(() {
        _memoryMB = memory > 0 ? memory : _memoryMB;
        _cpuPercent = cpu;
        _batteryLevel = battery;

        // Update history
        _memoryHistory.add(_memoryMB);
        if (_memoryHistory.length > _maxHistoryLength) {
          _memoryHistory.removeAt(0);
        }

        _cpuHistory.add(_cpuPercent);
        if (_cpuHistory.length > _maxHistoryLength) {
          _cpuHistory.removeAt(0);
        }
      });
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

        // Detect worker type from task ID
        if (event.taskId.contains('dart') ||
            event.taskId.contains('heavy') ||
            event.taskId.contains('custom')) {
          _lastWorkerType = WorkerType.dart;
        } else {
          _lastWorkerType = WorkerType.native;
        }
      });
    });
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  double get _successRate {
    if (_totalTasks == 0) return 100;
    return (_successfulTasks / _totalTasks) * 100;
  }

  void _cycleMode() {
    setState(() {
      switch (_mode) {
        case DisplayMode.mini:
          _mode = DisplayMode.compact;
          break;
        case DisplayMode.compact:
          _mode = DisplayMode.full;
          break;
        case DisplayMode.full:
          _mode = DisplayMode.mini;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() => _isDragging = true);
        },
        onPanUpdate: (details) {
          setState(() {
            _x += details.delta.dx;
            _y += details.delta.dy;

            final size = MediaQuery.of(context).size;
            final width = _getWidthForMode();
            final height = _getHeightForMode();
            _x = _x.clamp(0, size.width - width);
            _y = _y.clamp(0, size.height - height);
          });
        },
        onPanEnd: (_) {
          setState(() => _isDragging = false);
        },
        onDoubleTap: _cycleMode,
        child: Material(
          elevation: _isDragging ? 16 : 8,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _getWidthForMode(),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.9),
                  Colors.grey.shade900.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _getBorderColor(), width: 2),
              boxShadow: [
                BoxShadow(
                  color: _getBorderColor().withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  double _getWidthForMode() {
    switch (_mode) {
      case DisplayMode.mini:
        return 80;
      case DisplayMode.compact:
        return 200;
      case DisplayMode.full:
        return 280;
    }
  }

  double _getHeightForMode() {
    switch (_mode) {
      case DisplayMode.mini:
        return 80;
      case DisplayMode.compact:
        return 280;
      case DisplayMode.full:
        return 400;
    }
  }

  Color _getBorderColor() {
    if (_lastWorkerType == WorkerType.dart) {
      return Colors.purple;
    }
    if (_successRate >= 90) return Colors.green;
    if (_successRate >= 70) return Colors.orange;
    return Colors.red;
  }

  Widget _buildContent() {
    switch (_mode) {
      case DisplayMode.mini:
        return _buildMiniMode();
      case DisplayMode.compact:
        return _buildCompactMode();
      case DisplayMode.full:
        return _buildFullMode();
    }
  }

  // Mini mode: Just icon and memory
  Widget _buildMiniMode() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Icon(
                Icons.speed,
                color: Colors.blue.withValues(
                  alpha: 0.5 + (_pulseController.value * 0.5),
                ),
                size: 32,
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${_memoryMB.toStringAsFixed(0)}MB',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Compact mode: Original design
  Widget _buildCompactMode() {
    return Column(children: [_buildHeader(), _buildCompactBody()]);
  }

  // Full mode: All metrics with graphs
  Widget _buildFullMode() {
    return Column(children: [_buildHeader(), _buildFullBody()]);
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getBorderColor().withValues(alpha: 0.3),
            _getBorderColor().withValues(alpha: 0.2),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Icon(
                Icons.speed,
                color: _getBorderColor().withValues(
                  alpha: 0.5 + (_pulseController.value * 0.5),
                ),
                size: 18,
              );
            },
          ),
          const SizedBox(width: 8),
          const Text(
            'Live Metrics',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          _buildMemoryBadge(),
        ],
      ),
    );
  }

  Widget _buildMemoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_getMemoryColor(), _getMemoryColor().withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _getMemoryColor().withValues(alpha: 0.4),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.memory, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            '${_memoryMB.toStringAsFixed(0)} MB',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getMemoryColor() {
    if (_memoryMB < 10) return Colors.green;
    if (_memoryMB < 50) return Colors.orange;
    return Colors.red;
  }

  Widget _buildCompactBody() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricRow(
              Icons.task_alt,
              'Tasks',
              '$_totalTasks',
              Colors.blue,
            ),
            const SizedBox(height: 6),
            _buildMetricRow(
              Icons.check_circle,
              'Success',
              '$_successfulTasks',
              Colors.green,
            ),
            const SizedBox(height: 6),
            _buildMetricRow(Icons.error, 'Failed', '$_failedTasks', Colors.red),
            const SizedBox(height: 10),
            _buildSuccessRateBar(),
            const SizedBox(height: 12),
            _buildLastTaskCard(),
            const SizedBox(height: 12),
            _buildWorkerTypeIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildFullBody() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // System metrics
            _buildSystemMetricsSection(),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),

            // Task statistics
            _buildTaskStatisticsSection(),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),

            // Last task
            _buildLastTaskCard(),
            const SizedBox(height: 12),

            // Worker type
            _buildWorkerTypeIndicator(),
            const SizedBox(height: 12),

            // Memory graph
            if (_memoryHistory.length > 2) ...[
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              _buildMemoryGraph(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMetricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSystemMetricCard(
                icon: Icons.memory,
                label: 'RAM',
                value: '${_memoryMB.toStringAsFixed(0)}MB',
                color: _getMemoryColor(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSystemMetricCard(
                icon: Icons.battery_charging_full,
                label: 'Battery',
                value: '$_batteryLevel%',
                color: _batteryLevel > 20 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSystemMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 9),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tasks',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildMetricRow(Icons.task_alt, 'Total', '$_totalTasks', Colors.blue),
        const SizedBox(height: 6),
        _buildMetricRow(
          Icons.check_circle,
          'Success',
          '$_successfulTasks',
          Colors.green,
        ),
        const SizedBox(height: 6),
        _buildMetricRow(Icons.error, 'Failed', '$_failedTasks', Colors.red),
        const SizedBox(height: 10),
        _buildSuccessRateBar(),
      ],
    );
  }

  Widget _buildMetricRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
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
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
            Text(
              '${_successRate.toStringAsFixed(0)}%',
              style: TextStyle(
                color: _successRate >= 90 ? Colors.green : Colors.orange,
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
              _successRate >= 90 ? Colors.green : Colors.orange,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildLastTaskCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _lastTaskSuccess
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _lastTaskSuccess ? Icons.check_circle : Icons.error,
                color: _lastTaskSuccess ? Colors.green : Colors.red,
                size: 14,
              ),
              const SizedBox(width: 6),
              const Text(
                'Last Task',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                _lastTaskTime,
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _lastTaskId,
            style: const TextStyle(color: Colors.white, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerTypeIndicator() {
    final isNative = _lastWorkerType == WorkerType.native;
    final color = isNative ? Colors.green : Colors.purple;
    final label = isNative ? 'Native Worker' : 'Dart Worker';
    final timing = isNative ? '<50ms' : '~800ms';
    final memory = isNative ? '2-5MB' : '30-50MB';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(isNative ? Icons.flash_on : Icons.code, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$timing • $memory',
                  style: const TextStyle(color: Colors.white54, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryGraph() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Memory Trend',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: CustomPaint(
            painter: _MemoryGraphPainter(_memoryHistory),
            size: const Size(double.infinity, 60),
          ),
        ),
      ],
    );
  }
}

enum DisplayMode { mini, compact, full }

enum WorkerType { native, dart }

/// Custom painter for memory graph
class _MemoryGraphPainter extends CustomPainter {
  final List<double> data;

  _MemoryGraphPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.blue.withValues(alpha: 0.3),
          Colors.blue.withValues(alpha: 0.05),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedValue = range > 0 ? (data[i] - minValue) / range : 0.5;
      final y =
          size.height -
          (normalizedValue * size.height * 0.8) -
          (size.height * 0.1);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
