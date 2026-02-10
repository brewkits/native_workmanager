/// Task Chain Workflow Template
///
/// Copy-paste ready code for complex multi-step background workflows.
/// This template demonstrates:
/// - Sequential task chains (A → B → C)
/// - Parallel task chains (A → [B1, B2, B3] → D)
/// - Error handling and retry
/// - Real-world Download → Process → Upload workflow
///
/// USAGE:
/// 1. Replace URLs with your actual endpoints
/// 2. Replace file paths with your actual directories
/// 3. Adjust workflow steps to your needs
/// 4. Run and test
library;

import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'dart:developer' as developer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize native_workmanager
  await NativeWorkManager.initialize();

  runApp(const ChainWorkflowApp());
}

class ChainWorkflowApp extends StatefulWidget {
  const ChainWorkflowApp({super.key});

  @override
  State<ChainWorkflowApp> createState() => _ChainWorkflowAppState();
}

class _ChainWorkflowAppState extends State<ChainWorkflowApp> {
  final Map<String, String> _taskStatuses = {};
  String _currentWorkflow = 'None';

  @override
  void initState() {
    super.initState();
    _setupEventListener();
  }

  /// Setup event listener to track all tasks in chain
  void _setupEventListener() {
    NativeWorkManager.events.listen((event) {
      setState(() {
        _taskStatuses[event.taskId] = event.success ? 'succeeded' : 'failed';
      });

      developer.log(
        '📋 Task ${event.taskId}: ${event.success ? 'succeeded' : 'failed'}',
      );
      if (event.success) {
        developer.log('   ✅ Data: ${event.resultData}');
      } else {
        developer.log('   ❌ Error: ${event.message}');
      }
    });
  }

  /// Example 1: Download → Extract → Upload Workflow
  /// Use case: Download resource pack, extract, upload processed files
  Future<void> _downloadExtractUploadWorkflow() async {
    setState(() {
      _currentWorkflow = 'Download → Extract → Upload';
      _taskStatuses.clear();
    });

    try {
      await NativeWorkManager.beginWith(
            TaskRequest(
              id: 'download',
              worker: NativeWorker.httpDownload(
                // 👇 REPLACE with your download URL
                url: 'https://cdn.example.com/resources.zip',
                savePath: '/downloads/resources.zip',
                enableResume: true, // Resume if download fails
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'extract',
              worker: NativeWorker.fileDecompress(
                zipPath: '/downloads/resources.zip',
                targetDir: '/data/resources/',
                deleteAfterExtract: true, // Delete ZIP after extraction
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'upload',
              worker: NativeWorker.httpUpload(
                // 👇 REPLACE with your upload URL
                url: 'https://api.example.com/backup',
                filePath: '/data/resources/manifest.json',
              ),
            ),
          )
          .enqueue();

      developer.log('✅ Download → Extract → Upload chain started');
    } catch (e) {
      developer.log('❌ Failed to start workflow: $e');
    }
  }

  /// Example 2: Download → Compress → Upload Workflow
  /// Use case: Download data, compress for bandwidth, upload to backup
  Future<void> _downloadCompressUploadWorkflow() async {
    setState(() {
      _currentWorkflow = 'Download → Compress → Upload';
      _taskStatuses.clear();
    });

    try {
      await NativeWorkManager.beginWith(
            TaskRequest(
              id: 'download-data',
              worker: NativeWorker.httpDownload(
                url: 'https://api.example.com/export/data.json',
                savePath: '/downloads/data.json',
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'compress',
              worker: NativeWorker.fileCompress(
                inputPath: '/downloads/data.json',
                outputPath: '/downloads/data.zip',
                level: CompressionLevel.medium, // Balance speed vs size
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'upload-backup',
              worker: NativeWorker.httpUpload(
                url: 'https://backup.example.com/upload',
                filePath: '/downloads/data.zip',
              ),
            ),
          )
          .enqueue();

      developer.log('✅ Download → Compress → Upload chain started');
    } catch (e) {
      developer.log('❌ Failed to start workflow: $e');
    }
  }

  /// Example 3: Parallel Processing Workflow
  /// Download → [Process1, Process2, Process3] → Upload Results
  Future<void> _parallelProcessingWorkflow() async {
    setState(() {
      _currentWorkflow = 'Download → Parallel Process → Upload';
      _taskStatuses.clear();
    });

    try {
      await NativeWorkManager.beginWith(
            TaskRequest(
              id: 'download-images',
              worker: NativeWorker.httpDownload(
                url: 'https://cdn.example.com/images.zip',
                savePath: '/downloads/images.zip',
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'extract-images',
              worker: NativeWorker.fileDecompress(
                zipPath: '/downloads/images.zip',
                targetDir: '/images/',
                deleteAfterExtract: true,
              ),
            ),
          )
          .thenAll([
            // Parallel: Process images in different formats
            TaskRequest(
              id: 'compress-thumb',
              worker: NativeWorker.imageProcess(
                inputPath: '/images/photo.jpg',
                outputPath: '/images/thumb.jpg',
                quality: 50,
                maxWidth: 200,
                maxHeight: 200,
              ),
            ),
            TaskRequest(
              id: 'compress-medium',
              worker: NativeWorker.imageProcess(
                inputPath: '/images/photo.jpg',
                outputPath: '/images/medium.jpg',
                quality: 75,
                maxWidth: 800,
                maxHeight: 800,
              ),
            ),
            TaskRequest(
              id: 'compress-large',
              worker: NativeWorker.imageProcess(
                inputPath: '/images/photo.jpg',
                outputPath: '/images/large.jpg',
                quality: 85,
                maxWidth: 1920,
                maxHeight: 1920,
              ),
            ),
          ])
          .then(
            TaskRequest(
              id: 'upload-all',
              worker: NativeWorker.httpUpload(
                url: 'https://api.example.com/gallery/upload',
                filePath: '/images/large.jpg',
              ),
            ),
          )
          .enqueue();

      developer.log('✅ Parallel processing workflow started');
    } catch (e) {
      developer.log('❌ Failed to start workflow: $e');
    }
  }

  /// Example 4: Crypto Workflow (Download → Verify → Decrypt → Process)
  /// Use case: Secure file processing with integrity verification
  Future<void> _cryptoWorkflow() async {
    setState(() {
      _currentWorkflow = 'Download → Hash → Decrypt → Upload';
      _taskStatuses.clear();
    });

    try {
      await NativeWorkManager.beginWith(
            TaskRequest(
              id: 'download-encrypted',
              worker: NativeWorker.httpDownload(
                url: 'https://secure.example.com/data.enc',
                savePath: '/downloads/data.enc',
                // Verify integrity with checksum
                expectedChecksum: 'abc123...',
                checksumAlgorithm: 'SHA-256',
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'decrypt',
              worker: NativeWorker.cryptoDecrypt(
                inputPath: '/downloads/data.enc',
                outputPath: '/downloads/data.json',
                password: 'user-password', // 👈 REPLACE with secure password
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'upload-decrypted',
              worker: NativeWorker.httpUpload(
                url: 'https://api.example.com/data',
                filePath: '/downloads/data.json',
              ),
            ),
          )
          .enqueue();

      developer.log('✅ Crypto workflow started');
    } catch (e) {
      developer.log('❌ Failed to start workflow: $e');
    }
  }

  /// Example 5: Conditional Workflow with Retry
  /// Download → Validate → (Upload if valid | Retry if invalid)
  Future<void> _conditionalWorkflow() async {
    setState(() {
      _currentWorkflow = 'Download → Validate → Upload';
      _taskStatuses.clear();
    });

    try {
      await NativeWorkManager.beginWith(
            TaskRequest(
              id: 'download-api',
              worker: NativeWorker.httpRequest(
                url: 'https://api.example.com/data',
                method: HttpMethod.get,
              ),
            ),
          )
          .then(
            TaskRequest(
              id: 'upload-result',
              worker: NativeWorker.httpRequest(
                url: 'https://backup.example.com/store',
                method: HttpMethod.post,
                body:
                    '{"source": "api", "timestamp": "${DateTime.now().toIso8601String()}"}',
                headers: const {'Content-Type': 'application/json'},
              ),
            ),
          )
          .enqueue();

      developer.log('✅ Conditional workflow started');
    } catch (e) {
      developer.log('❌ Failed to start workflow: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Task Chain Workflows')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Workflow Examples',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current: $_currentWorkflow',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Task Statuses:'),
                      ..._taskStatuses.entries.map(
                        (entry) => Text(
                          '  ${entry.key}: ${entry.value}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    ElevatedButton(
                      onPressed: _downloadExtractUploadWorkflow,
                      child: const Text('Download → Extract → Upload'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _downloadCompressUploadWorkflow,
                      child: const Text('Download → Compress → Upload'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _parallelProcessingWorkflow,
                      child: const Text('Parallel Image Processing'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _cryptoWorkflow,
                      child: const Text('Crypto Workflow (Decrypt)'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _conditionalWorkflow,
                      child: const Text('Conditional API Workflow'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '💡 Chain Patterns:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Sequential: A → B → C'),
              const Text('• Parallel: A → [B1, B2, B3] → D'),
              const Text('• Conditional: if-success → continue'),
              const Text('• Automatic retry on failure'),
            ],
          ),
        ),
      ),
    );
  }
}

/// 📚 More Chain Examples:
///
/// Custom Retry Policy:
/// ```dart
/// await NativeWorkManager.beginWith(TaskRequest(
///   id: 'download',
///   worker: NativeWorker.httpDownload(...),
/// ))
/// .then(TaskRequest(
///   id: 'process',
///   worker: NativeWorker.fileCompression(...),
/// ))
/// .enqueue(
///   backoffPolicy: BackoffPolicy(
///     delay: Duration(seconds: 30),
///     maxDelay: Duration(minutes: 10),
///     backoffType: BackoffType.exponential,
///   ),
///   maxAttempts: 5,
/// );
/// ```
///
/// Constraints for Entire Chain:
/// ```dart
/// await NativeWorkManager.beginWith(...)
///   .then(...)
///   .then(...)
///   .enqueue(
///     constraints: Constraints(
///       requiresWifi: true,
///       requiresCharging: true,
///     ),
///   );
/// ```
