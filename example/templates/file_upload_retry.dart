/// File Upload with Retry Template
///
/// Copy-paste ready code for uploading files with automatic retry on failure.
/// This template demonstrates:
/// - File upload with progress tracking
/// - Automatic retry with exponential backoff
/// - Multi-file upload support
///
/// USAGE:
/// 1. Replace YOUR_UPLOAD_URL with your actual upload endpoint
/// 2. Replace YOUR_AUTH_TOKEN with your authentication token
/// 3. Update file paths to your actual files
/// 4. Run and test
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'dart:developer' as developer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize native_workmanager
  await NativeWorkManager.initialize();

  runApp(const FileUploadRetryApp());
}

class FileUploadRetryApp extends StatefulWidget {
  const FileUploadRetryApp({super.key});

  @override
  State<FileUploadRetryApp> createState() => _FileUploadRetryAppState();
}

class _FileUploadRetryAppState extends State<FileUploadRetryApp> {
  String _status = 'Ready';
  double _progress = 0.0;
  final int _retryCount = 0;
  String? _uploadedUrl;

  @override
  void initState() {
    super.initState();
    _setupEventListener();
  }

  void _setupEventListener() {
    NativeWorkManager.events.listen((event) {
      if (event.taskId.startsWith('upload-')) {
        setState(() {
          if (event.success) {
            _status = 'Upload successful!';
            _progress = 1.0;
            final data = event.resultData;
            _uploadedUrl = data?['responseBody'];
            developer.log('✅ Upload successful!');
            developer.log('   Uploaded size: ${data?['uploadedSize']} bytes');
            developer.log('   Response: $_uploadedUrl');
          } else {
            _status = 'Upload failed!';
            developer.log('❌ Upload failed: ${event.message}');
            developer.log('   Retry count: $_retryCount');
          }
        });
      }
    });

    // Add a separate listener for progress updates
    NativeWorkManager.progress.listen((progress) {
      if (progress.taskId.startsWith('upload-')) {
        setState(() {
          _progress = progress.progress / 100.0;
          _status =
              'Uploading... (${progress.message ?? '${progress.progress}%'})';
        });
      }
    });
  }

  /// Upload single file with retry
  Future<void> _uploadSingleFile() async {
    // 👇 REPLACE THIS with your actual file path
    const filePath = '/path/to/your/photo.jpg';

    // Validate file exists
    if (!await File(filePath).exists()) {
      setState(() {
        _status = 'Error: File not found';
      });
      developer.log('❌ File not found: $filePath');
      return;
    }

    try {
      await NativeWorkManager.enqueue(
        taskId: 'upload-single-${DateTime.now().millisecondsSinceEpoch}',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpUpload(
          // 👇 REPLACE THIS with your upload endpoint
          url: 'https://api.example.com/upload',
          filePath: filePath,
          fileFieldName: 'file', // Form field name on server
          fileName: 'photo.jpg', // Override file name
          headers: {
            // 👇 REPLACE THIS with your auth token
            'Authorization': 'Bearer YOUR_AUTH_TOKEN',
          },
          additionalFields: {
            // Additional form fields
            'userId': '123',
            'description': 'Uploaded from Flutter',
          },
          timeout: const Duration(milliseconds: 120000), // 2 minutes timeout
        ),
        constraints: const Constraints(
          requiresNetwork: true, // Only upload when network available
          backoffPolicy: BackoffPolicy.exponential,
          backoffDelayMs: 10000,
        ),
      );

      setState(() {
        _status = 'Uploading...';
        _progress = 0.0;
      });

      developer.log('✅ Upload started with retry (max 5 attempts)');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      developer.log('❌ Failed to start upload: $e');
    }
  }

  /// Upload multiple files in one request
  Future<void> _uploadMultipleFiles() async {
    // 👇 REPLACE THESE with your actual file paths
    final filePaths = [
      '/path/to/photo1.jpg',
      '/path/to/photo2.jpg',
      '/path/to/photo3.jpg',
    ];

    // Validate all files exist
    for (final path in filePaths) {
      if (!await File(path).exists()) {
        setState(() {
          _status = 'Error: File not found - $path';
        });
        return;
      }
    }

    try {
      for (final filePath in filePaths) {
        await NativeWorkManager.enqueue(
          taskId: 'upload-multi-${DateTime.now().millisecondsSinceEpoch}',
          trigger: TaskTrigger.oneTime(),
          worker: NativeWorker.httpUpload(
            url: 'https://api.example.com/gallery/upload',
            filePath: filePath,
            headers: const {'Authorization': 'Bearer YOUR_AUTH_TOKEN'},
            additionalFields: const {'albumId': '456'},
            timeout: const Duration(milliseconds: 300000), // 5 minutes for multiple files
          ),
          constraints: const Constraints(
            requiresNetwork: true,
            requiresUnmeteredNetwork: true, // Only upload on WiFi for multiple files
            backoffPolicy: BackoffPolicy.exponential,
            backoffDelayMs: 30000,
          ),
        );
      }

      setState(() {
        _status = 'Uploading ${filePaths.length} files...';
        _progress = 0.0;
      });

      developer.log('✅ Multi-file upload started');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      developer.log('❌ Failed to start upload: $e');
    }
  }

  /// Upload raw JSON data (no file)
  Future<void> _uploadJsonData() async {
    try {
      await NativeWorkManager.enqueue(
        taskId: 'upload-json-${DateTime.now().millisecondsSinceEpoch}',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpRequest(
          url: 'https://api.example.com/data',
          method: HttpMethod.post,
          body:
              '{"userId": "123", "action": "backup", "timestamp": "${DateTime.now().toIso8601String()}"}',
          headers: const {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer YOUR_AUTH_TOKEN'
          },
        ),
        constraints: const Constraints(
          backoffPolicy: BackoffPolicy.exponential,
          backoffDelayMs: 5000,
        ),
      );

      setState(() {
        _status = 'Uploading JSON data...';
      });

      developer.log('✅ JSON upload started');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      developer.log('❌ Failed to upload JSON: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('File Upload with Retry')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload Examples',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: $_status'),
                      const SizedBox(height: 8),
                      Text(
                        'Progress: ${(_progress * 100).toStringAsFixed(1)}%',
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _progress),
                      if (_uploadedUrl != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Response: $_uploadedUrl',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _uploadSingleFile,
                child: const Text('Upload Single File'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _uploadMultipleFiles,
                child: const Text('Upload Multiple Files'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _uploadJsonData,
                child: const Text('Upload JSON Data'),
              ),
              const SizedBox(height: 20),
              const Text(
                '🔄 Retry Configuration:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Max 5 attempts (single file)'),
              const Text('• Exponential backoff: 10s, 20s, 40s, 80s, ...'),
              const Text('• Only retries on network/server errors'),
              const Text('• Preserves upload progress'),
              const SizedBox(height: 20),
              const Text(
                '💡 Common Use Cases:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Photo/video backup'),
              const Text('• Document upload'),
              const Text('• Multi-file gallery upload'),
              const Text('• Log file upload'),
            ],
          ),
        ),
      ),
    );
  }
}

/// 📚 Additional Examples:
///
/// Upload with Checksum Verification:
/// ```dart
/// // Download file with checksum
/// await NativeWorkManager.beginWith(TaskRequest(
///   id: 'download',
///   worker: NativeWorker.httpDownload(
///     url: 'https://cdn.example.com/file.zip',
///     savePath: '/downloads/file.zip',
///     expectedChecksum: 'abc123...',
///     checksumAlgorithm: 'SHA-256',
///   ),
/// ))
/// .then(TaskRequest(
///   id: 'upload',
///   worker: NativeWorker.httpUpload(
///     url: 'https://api.example.com/backup',
///     filePath: '/downloads/file.zip',
///   ),
/// ))
/// .enqueue();
/// ```
///
/// Conditional Upload (Only on WiFi + Charging):
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'backup-upload',
///   trigger: TaskTrigger.periodic(Duration(days: 1)),
///   worker: NativeWorker.httpUpload(
///     url: 'https://api.example.com/backup',
///     filePath: '/backup/data.zip',
///   ),
///   constraints: Constraints(
///     requiresWifi: true,        // Only on WiFi
///     requiresCharging: true,    // Only when charging
///     requiresBatteryNotLow: true,
///   ),
/// );
/// ```
