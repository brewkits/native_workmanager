import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:path_provider/path_provider.dart';

class CaseStudyPage extends StatefulWidget {
  const CaseStudyPage({super.key});

  @override
  State<CaseStudyPage> createState() => _CaseStudyPageState();
}

class _CaseStudyPageState extends State<CaseStudyPage> {
  final List<String> _logs = [];
  bool _isRunning = false;

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      _logs.insert(
        0,
        '[${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}] $message',
      );
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-World Case Studies'),
        backgroundColor: cs.primaryContainer,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildIntroCard(cs),
                const SizedBox(height: 20),
                _buildCaseStudy(
                  title: 'Smart Media Pipeline',
                  subtitle: 'Efficient Video/Image Processing',
                  description:
                      'Imagine a social app that needs to process media before upload. Instead of keeping the Flutter app alive, we use a fully native chain.',
                  icon: Icons.video_library_outlined,
                  color: Colors.purple,
                  steps: [
                    'Download high-res media (Native)',
                    'Apply image processing / resize (Native)',
                    'Compress to ZIP for bundle (Native)',
                    'Upload to server with HMAC signing (Native)',
                    'Cleanup temporary workspace (Native)',
                  ],
                  onTap: _runMediaPipeline,
                ),
                const SizedBox(height: 16),
                _buildCaseStudy(
                  title: 'Enterprise Secure Sync',
                  subtitle: 'Offline-First Data Integrity',
                  description:
                      'A logistics app syncing sensitive manifest data. Needs strict security, retries, and background execution guarantees.',
                  icon: Icons.security_outlined,
                  color: Colors.blueGrey,
                  steps: [
                    'Sync manifests on WiFi only (Native)',
                    'Verify SHA-256 integrity (Native)',
                    'Decrypt manifest using Secure Key (Native)',
                    'Batch process in Dart (Isolate Caching)',
                    'Update local database state (Native)',
                  ],
                  onTap: _runEnterpriseSync,
                ),
                const SizedBox(height: 16),
                _buildCaseStudy(
                  title: 'Smart Backup (Content Trigger)',
                  subtitle: 'Automated Photo Cloud Sync',
                  description:
                      'Automatically back up new photos as they appear in the system gallery, but only when charging and on WiFi.',
                  icon: Icons.cloud_upload_outlined,
                  color: Colors.blue,
                  steps: [
                    'Detect new photos in Gallery (ContentUri)',
                    'Wait for Charging + WiFi (Constraints)',
                    'Parallel upload of chunks (Native)',
                    'Show progress notification (Native)',
                  ],
                  onTap: _runSmartBackup,
                ),
              ],
            ),
          ),
          _buildLogTerminal(cs),
        ],
      ),
    );
  }

  Widget _buildIntroCard(ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.secondaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.secondary.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline, color: cs.secondary, size: 32),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'These case studies demonstrate how to combine native workers into complex, reliable workflows.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaseStudy({
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color color,
    required List<String> steps,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _isRunning ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: color.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isRunning)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(Icons.play_circle_fill, color: color, size: 32),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ...steps.map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: color.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 8),
                          Text(step, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogTerminal(ColorScheme cs) {
    return Container(
      height: 180,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.terminal, color: Colors.white70, size: 14),
                SizedBox(width: 8),
                Text(
                  'WORKFLOW LOGS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _logs.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _logs[index],
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // WORKFLOW IMPLEMENTATIONS
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _runMediaPipeline() async {
    setState(() => _isRunning = true);
    _addLog('🚀 Starting Smart Media Pipeline...');

    try {
      final tmp = (await getTemporaryDirectory()).path;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await NativeWorkManager.beginWith(
            TaskRequest(
              id: 'media-dl-$ts',
              worker: NativeWorker.httpDownload(
                url: 'https://httpbin.org/bytes/51200',
                savePath: '$tmp/input-$ts.jpg',
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'media-process-$ts',
              worker: NativeWorker.imageProcess(
                inputPath: '$tmp/input-$ts.jpg',
                outputPath: '$tmp/processed-$ts.jpg',
                maxWidth: 1280,
                quality: 75,
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'media-zip-$ts',
              worker: NativeWorker.fileCompress(
                inputPath: '$tmp/processed-$ts.jpg',
                outputPath: '$tmp/bundle-$ts.zip',
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'media-upload-$ts',
              worker: NativeWorker.httpUpload(
                url: 'https://httpbin.org/post',
                filePath: '$tmp/bundle-$ts.zip',
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'media-cleanup-$ts',
              worker: NativeWorker.fileDelete(path: '$tmp/input-$ts.jpg'),
            ),
          )
          .enqueue();

      _addLog('✅ Pipeline enqueued! All steps will run natively.');
      _addLog('💡 iOS: Background the app to see it run.');
    } catch (e) {
      _addLog('❌ Error: $e');
    } finally {
      setState(() => _isRunning = false);
    }
  }

  Future<void> _runEnterpriseSync() async {
    setState(() => _isRunning = true);
    _addLog('🚀 Starting Enterprise Secure Sync...');

    try {
      final tmp = (await getTemporaryDirectory()).path;
      final ts = DateTime.now().millisecondsSinceEpoch;

      await NativeWorkManager.beginWith(
            TaskRequest(
              id: 'sync-dl-$ts',
              worker:
                  HttpDownloadWorker(
                    url: 'https://httpbin.org/json',
                    savePath: '$tmp/manifest-$ts.json',
                  ).withSigning(
                    const RequestSigning(secretKey: 'ent-secret-key-123'),
                  ),
              constraints: const Constraints(
                requiresNetwork: true,
                requiresUnmeteredNetwork: true,
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'sync-verify-$ts',
              worker: NativeWorker.hashFile(
                filePath: '$tmp/manifest-$ts.json',
                algorithm: HashAlgorithm.sha256,
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'sync-dart-process-$ts',
              worker: DartWorker(
                callbackId: 'customTask',
                input: {'file': '$tmp/manifest-$ts.json'},
              ),
            ),
          )
          .enqueue();

      _addLog('✅ Secure Sync enqueued (WiFi Only + HMAC).');
    } catch (e) {
      _addLog('❌ Error: $e');
    } finally {
      setState(() => _isRunning = false);
    }
  }

  Future<void> _runSmartBackup() async {
    _addLog('🚀 Configuring Smart Backup...');

    try {
      // On Android, this would use ContentUri.
      // For demo, we use a one-time trigger that simulates it.
      await NativeWorkManager.enqueue(
        taskId: 'smart-backup-${DateTime.now().millisecondsSinceEpoch}',
        trigger: TaskTrigger.oneTime(const Duration(seconds: 10)),
        worker: NativeWorker.parallelHttpDownload(
          url: 'https://httpbin.org/bytes/102400',
          savePath: '${(await getTemporaryDirectory()).path}/backup-demo.bin',
          numChunks: 3,
        ),
        constraints: const Constraints(
          requiresNetwork: true,
          requiresCharging: true,
          requiresUnmeteredNetwork: true,
        ),
      );

      _addLog('✅ Smart Backup scheduled.');
      _addLog('💡 Will run when Charging + WiFi criteria are met.');
    } catch (e) {
      _addLog('❌ Error: $e');
    }
  }
}
