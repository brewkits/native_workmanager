/// Cryptography Operations Template
///
/// Copy-paste ready code for file hashing, encryption, and decryption.
/// This template demonstrates:
/// - File integrity verification (hashing)
/// - Secure file encryption/decryption
/// - Secure data workflows
///
/// USAGE:
/// 1. Replace file paths with your actual files
/// 2. Use secure passwords (not hardcoded in production!)
/// 3. Run and test each operation
/// 4. Integrate into your workflows
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'dart:developer' as developer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize native_workmanager
  await NativeWorkManager.initialize();

  runApp(const CryptoOperationsApp());
}

class CryptoOperationsApp extends StatefulWidget {
  const CryptoOperationsApp({super.key});

  @override
  State<CryptoOperationsApp> createState() => _CryptoOperationsAppState();
}

class _CryptoOperationsAppState extends State<CryptoOperationsApp> {
  String _status = 'Ready';
  String? _result;

  @override
  void initState() {
    super.initState();
    _setupEventListener();
  }

  void _setupEventListener() {
    NativeWorkManager.events.listen((event) {
      if (event.taskId.startsWith('crypto-')) {
        setState(() {
          _status = event.success ? 'succeeded' : 'failed';

          if (event.success) {
            final data = event.resultData;
            _result = data?['hash'] ?? data?['outputPath'] ?? 'Success';
            developer.log('✅ Crypto operation completed!');
            developer.log('   Result: $_result');
          } else {
            _result = 'Error: ${event.message}';
            developer.log('❌ Crypto operation failed: ${event.message}');
          }
        });
      }
    });
  }

  /// Example 1: Hash File (Verify Integrity)
  /// Calculate checksum to detect file corruption or tampering
  Future<void> _hashFile() async {
    // 👇 REPLACE with your actual file path
    const filePath = '/path/to/file.bin';

    if (!await File(filePath).exists()) {
      setState(() {
        _status = 'Error: File not found';
      });
      return;
    }

    try {
      await NativeWorkManager.enqueue(
        taskId: 'crypto-hash-${DateTime.now().millisecondsSinceEpoch}',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.hashFile(
          filePath: filePath,
          algorithm: HashAlgorithm.sha256, // MD5, SHA-1, SHA-256, SHA-512
        ),
      );

      setState(() {
        _status = 'Calculating hash...';
        _result = null;
      });

      developer.log('✅ Hash calculation started');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      developer.log('❌ Failed to hash file: $e');
    }
  }

  /// Example 2: Hash String (Password Hashing, etc.)
  /// Hash text data for deduplication, password storage, etc.
  Future<void> _hashString() async {
    const data = 'Hello, World!'; // 👈 REPLACE with your data

    try {
      await NativeWorkManager.enqueue(
        taskId: 'crypto-hash-string-${DateTime.now().millisecondsSinceEpoch}',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.hashString(
          data: data,
          algorithm: HashAlgorithm.sha256,
        ),
      );

      setState(() {
        _status = 'Hashing string...';
        _result = null;
      });

      developer.log('✅ String hash started');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      developer.log('❌ Failed to hash string: $e');
    }
  }

  /// Example 3: Encrypt File
  /// Encrypt sensitive file with password
  Future<void> _encryptFile() async {
    // 👇 REPLACE with your actual file path
    const inputPath = '/path/to/sensitive.txt';
    const outputPath = '/path/to/sensitive.enc';

    if (!await File(inputPath).exists()) {
      setState(() {
        _status = 'Error: Input file not found';
      });
      return;
    }

    try {
      await NativeWorkManager.enqueue(
        taskId: 'crypto-encrypt-${DateTime.now().millisecondsSinceEpoch}',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.cryptoEncrypt(
          inputPath: inputPath,
          outputPath: outputPath,
          // 👇 IMPORTANT: Use secure password in production!
          // DO NOT hardcode passwords - get from secure storage
          password: 'user-secure-password',
        ),
      );

      setState(() {
        _status = 'Encrypting file...';
        _result = null;
      });

      developer.log('✅ Encryption started');
      developer.log(
        '⚠️  WARNING: Keep your password safe! Cannot decrypt without it.',
      );
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      developer.log('❌ Failed to encrypt file: $e');
    }
  }

  /// Example 4: Decrypt File
  /// Decrypt previously encrypted file
  Future<void> _decryptFile() async {
    // 👇 REPLACE with your encrypted file path
    const inputPath = '/path/to/sensitive.enc';
    const outputPath = '/path/to/sensitive-decrypted.txt';

    if (!await File(inputPath).exists()) {
      setState(() {
        _status = 'Error: Encrypted file not found';
      });
      return;
    }

    try {
      await NativeWorkManager.enqueue(
        taskId: 'crypto-decrypt-${DateTime.now().millisecondsSinceEpoch}',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.cryptoDecrypt(
          inputPath: inputPath,
          outputPath: outputPath,
          // 👇 Must use SAME password as encryption
          password: 'user-secure-password',
        ),
      );

      setState(() {
        _status = 'Decrypting file...';
        _result = null;
      });

      developer.log('✅ Decryption started');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      developer.log('❌ Failed to decrypt file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Crypto Operations')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cryptography Tools',
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
                      if (_result != null)
                        SelectableText(
                          'Result: $_result',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Hash Operations:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _hashFile,
                child: const Text('Hash File (SHA-256)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _hashString,
                child: const Text('Hash String'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Encryption Operations:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _encryptFile,
                child: const Text('Encrypt File (AES-256)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _decryptFile,
                child: const Text('Decrypt File'),
              ),
              const SizedBox(height: 20),
              const Text(
                '🔐 Security Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• AES-256 encryption (industry standard)'),
              const Text('• PBKDF2 key derivation (100K iterations)'),
              const Text('• Streaming for large files (low memory)'),
              const Text('• Automatic IV/nonce generation'),
              const SizedBox(height: 20),
              const Text(
                '💡 Common Use Cases:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Verify downloaded file integrity'),
              const Text('• Encrypt sensitive user data'),
              const Text('• Secure file storage'),
              const Text('• Deduplication (hash-based)'),
            ],
          ),
        ),
      ),
    );
  }
}

/// 📚 Advanced Crypto Workflows:
///
/// Download → Verify → Decrypt Workflow:
/// ```dart
/// await NativeWorkManager.beginWith(TaskRequest(
///   id: 'download',
///   worker: NativeWorker.httpDownload(
///     url: 'https://secure.example.com/data.enc',
///     savePath: '/downloads/data.enc',
///     // Verify integrity during download
///     expectedChecksum: 'abc123...',
///     checksumAlgorithm: 'SHA-256',
///   ),
/// ))
/// .then(TaskRequest(
///   id: 'decrypt',
///   worker: NativeWorker.crypto(
///     operation: CryptoOperation.decrypt,
///     filePath: '/downloads/data.enc',
///     outputPath: '/downloads/data.json',
///     password: 'user-password',
///   ),
/// ))
/// .enqueue();
/// ```
///
/// Encrypt → Upload Workflow:
/// ```dart
/// await NativeWorkManager.beginWith(TaskRequest(
///   id: 'encrypt',
///   worker: NativeWorker.crypto(
///     operation: CryptoOperation.encrypt,
///     filePath: '/data/sensitive.json',
///     outputPath: '/data/sensitive.enc',
///     password: 'user-password',
///   ),
/// ))
/// .then(TaskRequest(
///   id: 'upload',
///   worker: NativeWorker.httpUpload(
///     url: 'https://backup.example.com/upload',
///     filePath: '/data/sensitive.enc',
///   ),
/// ))
/// .enqueue();
/// ```
///
/// Deduplication Workflow:
/// ```dart
/// // Hash files to detect duplicates
/// final hashes = <String, String>{};
///
/// for (final file in files) {
///   await NativeWorkManager.enqueue(
///     taskId: 'hash-$file',
///     trigger: TaskTrigger.oneTime(),
///     worker: NativeWorker.crypto(
///       operation: CryptoOperation.hash,
///       filePath: file,
///       algorithm: 'SHA-256',
///     ),
///   );
///
///   // Listen for result
///   NativeWorkManager.events.listen((event) {
///     if (event.taskId == 'hash-$file' && event.state == TaskState.succeeded) {
///       final hash = event.outputData?['hash'];
///       if (hashes.containsValue(hash)) {
///         print('Duplicate found: $file');
///       } else {
///         hashes[file] = hash;
///       }
///     }
///   });
/// }
/// ```
///
/// Secure Backup Workflow:
/// ```dart
/// // Compress → Hash → Encrypt → Upload
/// await NativeWorkManager.beginWith(TaskRequest(
///   id: 'compress',
///   worker: NativeWorker.fileCompression(
///     sourcePath: '/data/backup/',
///     outputPath: '/backups/data.zip',
///   ),
/// ))
/// .then(TaskRequest(
///   id: 'hash',
///   worker: NativeWorker.crypto(
///     operation: CryptoOperation.hash,
///     filePath: '/backups/data.zip',
///     algorithm: 'SHA-256',
///   ),
/// ))
/// .then(TaskRequest(
///   id: 'encrypt',
///   worker: NativeWorker.crypto(
///     operation: CryptoOperation.encrypt,
///     filePath: '/backups/data.zip',
///     outputPath: '/backups/data.enc',
///     password: 'user-password',
///   ),
/// ))
/// .then(TaskRequest(
///   id: 'upload',
///   worker: NativeWorker.httpUpload(
///     url: 'https://backup.example.com/secure-upload',
///     filePath: '/backups/data.enc',
///   ),
/// ))
/// .enqueue();
/// ```
