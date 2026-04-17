import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';

class ProgressTrackingDemoPage extends StatefulWidget {
  const ProgressTrackingDemoPage({super.key});

  @override
  State<ProgressTrackingDemoPage> createState() =>
      _ProgressTrackingDemoPageState();
}

class _ProgressTrackingDemoPageState extends State<ProgressTrackingDemoPage> {
  TaskHandler? _handler;
  bool _isDownloading = false;

  Future<void> _startDownload() async {
    setState(() => _isDownloading = true);

    try {
      // 1. Enqueue and get the handler
      final handler = await NativeWorkManager.enqueue(
        taskId: 'demo-download-${DateTime.now().millisecondsSinceEpoch}',
        worker: NativeWorker.httpDownload(
          url: 'https://httpbin.org/bytes/1024000', // 1MB random bytes
          savePath: 'demo_file.bin',
        ),
      );

      setState(() => _handler = handler);

      // 2. Listen to progress updates via handler
      // TaskProgressCard subscribes to handler.progress internally;
      // no manual listener needed here.

      // 3. Wait for final result
      final result = await handler.result;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success ? '✅ Download complete!' : '❌ Download failed',
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
        setState(() => _isDownloading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress Tracking Demo')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_download_outlined,
                      size: 48,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Task Handler API',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This demo uses the new TaskHandler API to track a specific download task with real-time speed and ETAs.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_handler != null) ...[
              TaskProgressCard(
                handler: _handler!,
                title: 'High-Speed Download',
                icon: const Icon(
                  Icons.download_for_offline,
                  color: Colors.blue,
                ),
                padding: const EdgeInsets.all(20),
              ),
              const SizedBox(height: 24),
              Text(
                'The widget above is the new TaskProgressCard which is built-in to the library. '
                'It handles stream subscription and formatting automatically.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _isDownloading ? null : _startDownload,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(
                _isDownloading ? 'Downloading...' : 'Start 1MB Download',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
