import 'dart:async';
import 'dart:math' as math;
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const NativeWorkmanagerDevToolsExtension());
}

class NativeWorkmanagerDevToolsExtension extends StatelessWidget {
  const NativeWorkmanagerDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(
      child: NativeWorkmanagerDashboard(),
    );
  }
}

class NativeWorkmanagerDashboard extends StatefulWidget {
  const NativeWorkmanagerDashboard({super.key});

  @override
  State<NativeWorkmanagerDashboard> createState() =>
      _NativeWorkmanagerDashboardState();
}

class _NativeWorkmanagerDashboardState
    extends State<NativeWorkmanagerDashboard> {
  Map<String, dynamic> _metrics = {
    'activeTasks': 0,
    'offlineQueueSize': 0,
    'failedTasks': 0,
    'completedTasks': 0,
    'dagNodes': [],
  };
  Timer? _pollingTimer;
  StreamSubscription? _eventSubscription;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _subscribeToEvents();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToEvents() {
    // Phase 2: Listen for real-time events streamed from the host app via postEvent.
    // This provides instantaneous UI updates (streaming) to complement the periodic polling.
    _eventSubscription =
        serviceManager.service?.onExtensionEvent.listen((event) {
      if (event.extensionKind?.startsWith('native_workmanager.') ?? false) {
        debugPrint(
            'DevTools: Received real-time event: ${event.extensionKind}');

        if (event.extensionKind == 'native_workmanager.event' ||
            event.extensionKind == 'native_workmanager.progress') {
          // Trigger a targeted refresh when an event occurs
          _fetchMetrics();
        }
      }
    });
  }

  void _startPolling() {
    // Poll the host application every 2 seconds for a complete snapshot (including DAG nodes)
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _fetchMetrics();
    });
    // Fetch immediately
    _fetchMetrics();
  }

  Future<void> _fetchMetrics() async {
    try {
      if (!serviceManager.hasConnection) {
        setState(() => _isConnected = false);
        return;
      }

      final response = await serviceManager.service!.callServiceExtension(
        'ext.native_workmanager.getMetrics',
        isolateId: serviceManager.isolateManager.mainIsolate.value?.id,
      );

      setState(() {
        _isConnected = true;
        _metrics = Map<String, dynamic>.from(response.json ?? {});
      });
    } catch (e) {
      // Fails silently if the extension hasn't been registered on the app yet.
      setState(() => _isConnected = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Native WorkManager Observability'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                _isConnected
                    ? '🟢 Connected to App'
                    : '🔴 Disconnected / Waiting...',
                style: TextStyle(
                  color: _isConnected ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Force Refresh',
            onPressed: _fetchMetrics,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricsOverview(),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildDagVisualizerPlaceholder(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: _buildOfflineQueueInspector(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsOverview() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _MetricCard(
          title: 'Active Tasks',
          value: _metrics['activeTasks'].toString(),
          icon: Icons.run_circle_outlined,
          color: Colors.blueAccent,
        ),
        _MetricCard(
          title: 'Offline Queue',
          value: _metrics['offlineQueueSize'].toString(),
          icon: Icons.cloud_off,
          color: Colors.orangeAccent,
        ),
        _MetricCard(
          title: 'Completed',
          value: _metrics['completedTasks'].toString(),
          icon: Icons.check_circle_outline,
          color: Colors.green,
        ),
        _MetricCard(
          title: 'Failed / Dead',
          value: _metrics['failedTasks'].toString(),
          icon: Icons.error_outline,
          color: Colors.redAccent,
        ),
      ],
    );
  }

  Widget _buildDagVisualizerPlaceholder() {
    final nodes = (_metrics['dagNodes'] as List?) ?? [];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Task Graph (DAG) Visualizer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: nodes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_tree_outlined,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No active graphs to display.'),
                          const SizedBox(height: 8),
                          Text(
                            'Trigger a task graph (Chain) in the host app to see the visualizer.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : CustomPaint(
                      painter:
                          DagPainter(nodes: nodes.cast<Map<String, dynamic>>()),
                      size: Size.infinite,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineQueueInspector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Offline Queue Inspector',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_metrics['offlineQueueSize'] > 0)
                  TextButton.icon(
                    onPressed: _syncQueue,
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Sync Now'),
                  ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _metrics['offlineQueueSize'] == 0
                  ? const Center(
                      child: Text('Offline Queue is empty',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _metrics['offlineQueueSize'] as int,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: const Icon(Icons.hourglass_bottom),
                          title: Text('Queued Task #${index + 1}'),
                          subtitle: const Text('Waiting for network...'),
                          trailing: IconButton(
                            icon: const Icon(Icons.play_arrow),
                            tooltip: 'Force Sync',
                            onPressed: _syncQueue,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncQueue() async {
    try {
      if (!serviceManager.hasConnection) {
        return;
      }
      await serviceManager.service!.callServiceExtension(
        'ext.native_workmanager.syncQueue',
        isolateId: serviceManager.isolateManager.mainIsolate.value?.id,
      );
      // Refresh metrics after sync request
      _fetchMetrics();
    } catch (e) {
      debugPrint('Sync failed: $e');
    }
  }
}

class DagPainter extends CustomPainter {
  final List<Map<String, dynamic>> nodes;

  DagPainter({required this.nodes});

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Group nodes by chainId to lay them out
    final chains = <String, List<Map<String, dynamic>>>{};
    for (final node in nodes) {
      final chainId = node['chainId'] as String;
      chains.putIfAbsent(chainId, () => []).add(node);
    }

    double currentY = 40;
    const double nodeRadius = 25;
    const double horizontalSpacing = 100;
    const double verticalSpacing = 100;

    for (final chainEntry in chains.entries) {
      final chainNodes = chainEntry.value;
      // Sort by stepIndex
      chainNodes.sort(
          (a, b) => (a['stepIndex'] as int).compareTo(b['stepIndex'] as int));

      for (int i = 0; i < chainNodes.length; i++) {
        final node = chainNodes[i];
        final double x = 50 + (i * horizontalSpacing);
        final double y = currentY;

        // Draw connections (edges)
        if (i > 0) {
          final prevX = 50 + ((i - 1) * horizontalSpacing);
          canvas.drawLine(
            Offset(prevX + nodeRadius, y),
            Offset(x - nodeRadius, y),
            Paint()
              ..color = Colors.grey.withValues(alpha: 0.5)
              ..strokeWidth = 2,
          );
          // Draw arrowhead
          _drawArrow(
              canvas, Offset(x - nodeRadius, y), Offset(prevX + nodeRadius, y));
        }

        // Choose color based on status
        final status = (node['status'] as String).toLowerCase();
        Color nodeColor = Colors.grey;
        if (status == 'completed' || status == 'success') {
          nodeColor = Colors.green;
        } else if (status == 'running') {
          nodeColor = Colors.blue;
        } else if (status == 'failed') {
          nodeColor = Colors.red;
        } else if (status == 'pending') {
          nodeColor = Colors.orange;
        }

        // Draw node circle
        paint.color = nodeColor;
        canvas.drawCircle(Offset(x, y), nodeRadius, paint);

        // Draw border
        paint.style = PaintingStyle.stroke;
        paint.color = Colors.white.withValues(alpha: 0.3);
        canvas.drawCircle(Offset(x, y), nodeRadius, paint);
        paint.style = PaintingStyle.fill;

        // Draw label
        textPainter.text = TextSpan(
          text: node['label'] as String,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        );
        textPainter.layout();
        textPainter.paint(canvas,
            Offset(x - textPainter.width / 2, y - textPainter.height / 2));
      }
      currentY += verticalSpacing;
    }
  }

  void _drawArrow(Canvas canvas, Offset tip, Offset from) {
    final double angle = (tip - from).direction;
    const double arrowSize = 10;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - arrowSize * math.cos(angle - 0.5),
          tip.dy - arrowSize * math.sin(angle - 0.5))
      ..lineTo(tip.dx - arrowSize * math.cos(angle + 0.5),
          tip.dy - arrowSize * math.sin(angle + 0.5))
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.grey.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
