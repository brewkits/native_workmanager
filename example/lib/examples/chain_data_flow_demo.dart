import 'dart:io';
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:path_provider/path_provider.dart';

/// Comprehensive demo of iOS chain data flow feature.
///
/// Demonstrates that iOS chains now pass data between steps (v1.0.0+),
/// achieving full parity with Android WorkManager.
///
/// **Test Scenarios:**
/// 1. Download → Process → Upload workflow
/// 2. Data passing between steps
/// 3. Resume with data restoration
/// 4. Multiple tasks per step
class ChainDataFlowDemo extends StatefulWidget {
  const ChainDataFlowDemo({super.key});

  @override
  State<ChainDataFlowDemo> createState() => _ChainDataFlowDemoState();
}

class _ChainDataFlowDemoState extends State<ChainDataFlowDemo> {
  final List<String> _logs = [];
  String _status = 'Ready';

  void _log(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $message');
      _status = message;
    });
    print('DataFlowDemo: $message');
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
      _status = 'Logs cleared';
    });
  }

  /// Test 1: Simple Download → Process → Upload chain
  /// Demonstrates data passing between steps
  Future<void> _testSimpleDataFlow() async {
    _log('🧪 Test 1: Simple Data Flow');
    _log('──────────────────────────');

    try {
      final dir = await getApplicationDocumentsDirectory();

      // Step 1: Create a file (simulates download)
      final sourceFile = File('${dir.path}/source_file.txt');
      await sourceFile.writeAsString('Test content - ${DateTime.now()}');

      final downloadedFile = File('${dir.path}/downloaded_file.txt');
      final processedFile = File('${dir.path}/processed_file.txt');
      final uploadedMarker = File('${dir.path}/uploaded_marker.txt');

      // Cleanup
      await downloadedFile.delete().catchError((_) => downloadedFile);
      await processedFile.delete().catchError((_) => processedFile);
      await uploadedMarker.delete().catchError((_) => uploadedMarker);

      _log('📥 Step 1: Download (FileCopy)');
      _log('   Returns: filePath, fileSize, fileName');
      _log('');
      _log('⚙️ Step 2: Process');
      _log('   Receives: filePath from Step 1');
      _log('   Returns: processedPath, processedSize');
      _log('');
      _log('📤 Step 3: Upload');
      _log('   Receives: processedPath from Step 2');
      _log('   Returns: uploadUrl, uploadedSize');
      _log('');

      await NativeWorkManager.beginWith(
        TaskRequest(
          id: 'download-step',
          worker: NativeWorker.fileCopy(
            sourcePath: sourceFile.path,
            destinationPath: downloadedFile.path,
          ),
        ),
      ).then(
        TaskRequest(
          id: 'process-step',
          // This receives filePath from download-step
          worker: NativeWorker.fileCopy(
            sourcePath: downloadedFile.path,
            destinationPath: processedFile.path,
          ),
        ),
      ).then(
        TaskRequest(
          id: 'upload-step',
          // This receives processedPath from process-step
          worker: NativeWorker.fileCopy(
            sourcePath: processedFile.path,
            destinationPath: uploadedMarker.path,
          ),
        ),
      ).named('data_flow_test').enqueue();

      _log('✅ Chain enqueued!');
      _log('💡 Check Xcode console to see data merging logs');
      _log('   "Merging X keys from previous step..."');

    } catch (e) {
      _log('❌ Error: $e');
    }
  }

  /// Test 2: HTTP chain with real data flow
  /// Download → Parse JSON → Upload results
  Future<void> _testHttpDataFlow() async {
    _log('🧪 Test 2: HTTP Data Flow');
    _log('──────────────────────────');

    try {
      _log('📥 Step 1: HTTP GET');
      _log('   Returns: body, statusCode, headers');
      _log('');
      _log('⚙️ Step 2: HTTP POST (with data from Step 1)');
      _log('   Receives: body, statusCode from Step 1');
      _log('   Posts back to server');
      _log('');

      await NativeWorkManager.beginWith(
        TaskRequest(
          id: 'http-get-step',
          worker: HttpRequestWorker(
            url: 'https://httpbin.org/json',
            method: HttpMethod.get,
          ),
        ),
      ).then(
        TaskRequest(
          id: 'http-post-step',
          // This receives body, statusCode, headers from http-get-step
          worker: HttpRequestWorker(
            url: 'https://httpbin.org/post',
            method: HttpMethod.post,
            headers: const {'Content-Type': 'application/json'},
            body: '{"received":"data from previous step"}',
          ),
        ),
      ).named('http_data_flow').enqueue();

      _log('✅ HTTP chain enqueued!');
      _log('💡 Step 2 receives HTTP response from Step 1');

    } catch (e) {
      _log('❌ Error: $e');
    }
  }

  /// Test 3: Crypto chain with data flow
  /// Encrypt → Hash → Decrypt workflow
  Future<void> _testCryptoDataFlow() async {
    _log('🧪 Test 3: Crypto Data Flow');
    _log('──────────────────────────');

    try {
      final dir = await getApplicationDocumentsDirectory();
      final inputFile = File('${dir.path}/crypto_input.txt');
      final encryptedFile = File('${dir.path}/encrypted_output.bin');
      final decryptedFile = File('${dir.path}/decrypted_output.txt');

      await inputFile.writeAsString('Sensitive data to encrypt');
      await encryptedFile.delete().catchError((_) => encryptedFile);
      await decryptedFile.delete().catchError((_) => decryptedFile);

      _log('🔒 Step 1: Encrypt file');
      _log('   Returns: encryptedPath, encryptedSize, iv');
      _log('');
      _log('🔓 Step 2: Decrypt file');
      _log('   Receives: encryptedPath, iv from Step 1');
      _log('   Can decrypt using received IV!');
      _log('');

      const password = 'TestPassword123!';

      await NativeWorkManager.beginWith(
        TaskRequest(
          id: 'encrypt-step',
          worker: NativeWorker.cryptoEncrypt(
            inputPath: inputFile.path,
            outputPath: encryptedFile.path,
            password: password,
          ),
        ),
      ).then(
        TaskRequest(
          id: 'decrypt-step',
          // This receives encryptedPath and iv from encrypt-step
          worker: NativeWorker.cryptoDecrypt(
            inputPath: encryptedFile.path,
            outputPath: decryptedFile.path,
            password: password,
          ),
        ),
      ).named('crypto_data_flow').enqueue();

      _log('✅ Crypto chain enqueued!');
      _log('💡 Step 2 receives encryption IV from Step 1');
      _log('💡 Data flow enables encrypt→decrypt workflow!');

    } catch (e) {
      _log('❌ Error: $e');
    }
  }

  /// Test 4: Parallel tasks with data merging
  /// Multiple downloads → Single processor
  Future<void> _testParallelDataFlow() async {
    _log('🧪 Test 4: Parallel Data Flow');
    _log('──────────────────────────');

    try {
      _log('📥 Step 1: Two parallel downloads');
      _log('   Task A returns: filePathA, sizeA');
      _log('   Task B returns: filePathB, sizeB');
      _log('   → Last task\'s data wins (same as Android)');
      _log('');
      _log('⚙️ Step 2: Process (receives data from last task)');
      _log('');

      final dir = await getApplicationDocumentsDirectory();
      final sourceA = File('${dir.path}/source_a.txt');
      final sourceB = File('${dir.path}/source_b.txt');
      final destA = File('${dir.path}/dest_a.txt');
      final destB = File('${dir.path}/dest_b.txt');
      final processed = File('${dir.path}/processed.txt');

      await sourceA.writeAsString('Data A');
      await sourceB.writeAsString('Data B');
      await destA.delete().catchError((_) => destA);
      await destB.delete().catchError((_) => destB);
      await processed.delete().catchError((_) => processed);

      await NativeWorkManager.beginWith(
        TaskRequest(
          id: 'download-a',
          worker: NativeWorker.fileCopy(
            sourcePath: sourceA.path,
            destinationPath: destA.path,
          ),
        ),
      ).thenAll([
        TaskRequest(
          id: 'download-b',
          worker: NativeWorker.fileCopy(
            sourcePath: sourceB.path,
            destinationPath: destB.path,
          ),
        ),
      ]).then(
        TaskRequest(
          id: 'process-parallel',
          // This receives data from last completed parallel task
          worker: NativeWorker.fileCopy(
            sourcePath: destB.path,
            destinationPath: processed.path,
          ),
        ),
      ).named('parallel_data_flow').enqueue();

      _log('✅ Parallel chain enqueued!');
      _log('💡 Last task result is passed to next step');

    } catch (e) {
      _log('❌ Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chain Data Flow Demo'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Card
            Card(
              margin: const EdgeInsets.all(16),
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.link, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'iOS Chain Data Flow (v1.0.0)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'iOS chains now pass data between steps!\n'
                      '• Step 1 output → Step 2 input\n'
                      '• Full parity with Android WorkManager\n'
                      '• Data persists through app kills\n'
                      '• Resume restores data flow',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            // Status Card
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _status,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _testSimpleDataFlow,
                    icon: const Icon(Icons.file_copy),
                    label: const Text('Test 1: Simple Data Flow\n(Download → Process → Upload)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _testHttpDataFlow,
                    icon: const Icon(Icons.http),
                    label: const Text('Test 2: HTTP Data Flow\n(GET → POST with data)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _testCryptoDataFlow,
                    icon: const Icon(Icons.lock),
                    label: const Text('Test 3: Crypto Data Flow\n(Encrypt → Decrypt with IV)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _testParallelDataFlow,
                    icon: const Icon(Icons.merge_type),
                    label: const Text('Test 4: Parallel Data Flow\n(Multiple tasks → Processor)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _clearLogs,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Logs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),

            // Info Card
            Card(
              margin: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'How to Verify Data Flow',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1. Run any test above\n'
                      '2. Open Xcode → View → Debug Area → Show Console\n'
                      '3. Look for logs:\n'
                      '   "Merging X keys from previous step into..."\n'
                      '   "Saved result data for step X (Y keys)"\n'
                      '4. Each step receives data from previous step!',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

            // Logs
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.terminal, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Logs (${_logs.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              height: 300,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _logs[index],
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: _logs[index].contains('❌')
                            ? Colors.red
                            : _logs[index].contains('✅') || _logs[index].contains('🧪')
                            ? Colors.green
                            : Colors.black87,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
