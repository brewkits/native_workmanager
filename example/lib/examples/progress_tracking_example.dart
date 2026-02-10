import 'dart:async';
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Example demonstrating progress tracking for all workers.
///
/// This example shows how to:
/// - Track upload progress with real-time updates
/// - Track download progress with UI feedback
/// - Track file compression progress
/// - Handle progress events properly
/// - Display progress in various UI patterns
class ProgressTrackingExample extends StatefulWidget {
  const ProgressTrackingExample({super.key});

  @override
  State<ProgressTrackingExample> createState() =>
      _ProgressTrackingExampleState();
}

class _ProgressTrackingExampleState extends State<ProgressTrackingExample> {
  final Map<String, TaskProgressState> _taskProgress = {};
  StreamSubscription<TaskProgress>? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToProgress();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToProgress() {
    _progressSubscription = NativeWorkManager.progress.listen((
      TaskProgress progress,
    ) {
      setState(() {
        _taskProgress[progress.taskId] = TaskProgressState(
          progress: progress.progress,
          message: progress.message ?? '',
          currentStep: progress.currentStep,
          totalSteps: progress.totalSteps,
          lastUpdate: DateTime.now(),
        );
      });

      // Auto-remove completed tasks after 3 seconds
      if (progress.progress >= 100) {
        Future.delayed(const Duration(seconds: 3), () {
          setState(() {
            _taskProgress.remove(progress.taskId);
          });
        });
      }
    });
  }

  Future<void> _startFileUpload() async {
    const taskId = 'example-upload';

    // NOTE: Replace with actual file path and upload URL
    // This is just a demonstration of the API
    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpUpload(
          url: 'https://httpbin.org/post', // Test endpoint
          filePath: '/path/to/file.jpg', // Replace with actual path
          headers: {'Content-Type': 'multipart/form-data'},
        ),
        constraints: Constraints.networkRequired,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload started - watch progress below'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _startFileDownload() async {
    const taskId = 'example-download';

    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpDownload(
          url: 'https://httpbin.org/bytes/10485760', // 10MB test file
          savePath: '/tmp/download-test.bin',
        ),
        constraints: Constraints.networkRequired,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download started - watch progress below'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  Future<void> _startFileCompression() async {
    const taskId = 'example-compress';

    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.fileCompress(
          inputPath: '/tmp/test-directory', // Replace with actual path
          outputPath: '/tmp/archive.zip',
          level: CompressionLevel.medium,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compression started - watch progress below'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Compression failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Tracking'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _startFileUpload,
                  icon: const Icon(Icons.upload),
                  label: const Text('Start Upload (with progress)'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _startFileDownload,
                  icon: const Icon(Icons.download),
                  label: const Text('Start Download (with progress)'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _startFileCompression,
                  icon: const Icon(Icons.compress),
                  label: const Text('Start Compression (with progress)'),
                ),
              ],
            ),
          ),

          const Divider(),

          // Progress List
          Expanded(
            child: _taskProgress.isEmpty
                ? const Center(
                    child: Text(
                      'No active tasks\n\nStart a task above to see progress tracking',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _taskProgress.length,
                    itemBuilder: (context, index) {
                      final taskId = _taskProgress.keys.elementAt(index);
                      final progress = _taskProgress[taskId]!;

                      return _buildProgressCard(taskId, progress);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(String taskId, TaskProgressState progress) {
    final isComplete = progress.progress >= 100;
    final color = isComplete ? Colors.green : Colors.blue;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task ID and Icon
            Row(
              children: [
                Icon(_getTaskIcon(taskId), color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    taskId,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (isComplete)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),

            const SizedBox(height: 12),

            // Progress Bar
            LinearProgressIndicator(
              value: progress.progress / 100.0,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),

            const SizedBox(height: 8),

            // Progress Text
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.progress}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                if (progress.currentStep != null && progress.totalSteps != null)
                  Text(
                    '${progress.currentStep}/${progress.totalSteps} items',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),

            // Status Message
            if (progress.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                progress.message,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],

            // Timestamp
            const SizedBox(height: 4),
            Text(
              'Last update: ${_formatTimestamp(progress.lastUpdate)}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTaskIcon(String taskId) {
    if (taskId.contains('upload')) return Icons.upload;
    if (taskId.contains('download')) return Icons.download;
    if (taskId.contains('compress')) return Icons.compress;
    return Icons.work;
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// State container for task progress.
class TaskProgressState {
  final int progress;
  final String message;
  final int? currentStep;
  final int? totalSteps;
  final DateTime lastUpdate;

  TaskProgressState({
    required this.progress,
    required this.message,
    this.currentStep,
    this.totalSteps,
    required this.lastUpdate,
  });
}
