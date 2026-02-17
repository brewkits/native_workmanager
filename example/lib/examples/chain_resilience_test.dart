import 'dart:io';
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:path_provider/path_provider.dart';

/// Test example for iOS chain state persistence and resilience.
///
/// This example demonstrates that chains can survive app kills and resume
/// from the last completed step.
///
/// **Test Procedure:**
/// 1. Tap "Start Resilient Chain"
/// 2. Wait for step 1 to complete (5 seconds)
/// 3. Force kill the app (swipe up from app switcher)
/// 4. Reopen the app
/// 5. Chain should auto-resume from step 2
///
/// **Expected Behavior:**
/// - iOS: Chain resumes from last completed step ✅
/// - Android: Chain restarts from beginning (KMP behavior)
class ChainResilienceTest extends StatefulWidget {
  const ChainResilienceTest({super.key});

  @override
  State<ChainResilienceTest> createState() => _ChainResilienceTestState();
}

class _ChainResilienceTestState extends State<ChainResilienceTest> {
  String _status = 'Ready to test';
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _checkForResumedChain();
  }

  void _log(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $message');
      _status = message;
    });
    print('ChainResilienceTest: $message');
  }

  Future<void> _checkForResumedChain() async {
    // Check if there's a marker file indicating chain was in progress
    // Delay slightly to ensure platform channels are ready
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final dir = await getApplicationDocumentsDirectory();
      final markerFile = File('${dir.path}/chain_test_marker.txt');

      if (await markerFile.exists()) {
        final content = await markerFile.readAsString();
        _log('⚠️ Chain was interrupted! Last: $content');
        _log('📱 iOS should auto-resume chain...');
      } else {
        _log('✅ No interrupted chains found');
      }
    } catch (e) {
      // Ignore path_provider initialization errors on first launch
      if (!e.toString().contains('objective_c')) {
        _log('Error checking marker: $e');
      }
    }
  }

  Future<void> _startResilientChain() async {
    _log('🚀 Starting resilient chain (3 steps)...');

    try {
      final dir = await getApplicationDocumentsDirectory();

      // Create test files
      final inputFile = File('${dir.path}/chain_input.txt');
      final step1File = File('${dir.path}/chain_step1_done.txt');
      final step2File = File('${dir.path}/chain_step2_done.txt');
      final step3File = File('${dir.path}/chain_step3_done.txt');
      final markerFile = File('${dir.path}/chain_test_marker.txt');

      // Cleanup old test files
      await inputFile.writeAsString('Test data for chain');
      await step1File.delete().catchError((_) => step1File);
      await step2File.delete().catchError((_) => step2File);
      await step3File.delete().catchError((_) => step3File);
      await markerFile.writeAsString('Chain started');

      _log('📁 Test files created');
      _log('');
      _log('⚠️ KILL APP NOW TO TEST RESUME!');
      _log('   (Force quit after step 1 completes)');
      _log('');

      // Start chain using builder API
      await NativeWorkManager.beginWith(
        TaskRequest(
          id: 'resilience-step-1',
          worker: NativeWorker.fileCopy(
            sourcePath: inputFile.path,
            destinationPath: step1File.path,
          ),
        ),
      ).then(
        TaskRequest(
          id: 'resilience-step-2',
          worker: NativeWorker.fileCopy(
            sourcePath: inputFile.path,
            destinationPath: step2File.path,
          ),
        ),
      ).then(
        TaskRequest(
          id: 'resilience-step-3',
          worker: NativeWorker.fileCopy(
            sourcePath: inputFile.path,
            destinationPath: step3File.path,
          ),
        ),
      ).named('resilience_test').enqueue();

      _log('✅ Chain enqueued');
      _log('📊 Monitoring progress...');

      // Monitor progress
      _monitorChainProgress(step1File, step2File, step3File, markerFile);

    } catch (e) {
      _log('❌ Error: $e');
    }
  }

  Future<void> _monitorChainProgress(
    File step1File,
    File step2File,
    File step3File,
    File markerFile,
  ) async {
    // Poll for step completion
    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 1));

      if (await step1File.exists()) {
        if (_status != '✅ Step 1 complete') {
          _log('✅ Step 1 complete');
          await markerFile.writeAsString('Step 1 done');
        }
      }

      if (await step2File.exists()) {
        if (_status != '✅ Step 2 complete') {
          _log('✅ Step 2 complete');
          await markerFile.writeAsString('Step 2 done');
        }
      }

      if (await step3File.exists()) {
        if (_status != '🎉 Chain completed!') {
          _log('✅ Step 3 complete');
          _log('🎉 Chain completed!');
          await markerFile.delete();
        }
        break;
      }
    }
  }

  Future<void> _clearTestData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();

      final files = [
        'chain_input.txt',
        'chain_step1_done.txt',
        'chain_step2_done.txt',
        'chain_step3_done.txt',
        'chain_test_marker.txt',
      ];

      for (final filename in files) {
        final file = File('${dir.path}/$filename');
        await file.delete().catchError((_) => file);
      }

      setState(() {
        _logs.clear();
        _status = 'Test data cleared';
      });

      _log('🗑️ Test data cleared');
    } catch (e) {
      _log('Error clearing: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chain Resilience Test'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
          // Instructions Card
          Card(
            margin: const EdgeInsets.all(16),
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.science, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Test Chain Persistence',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Tap "Start Resilient Chain"\n'
                    '2. Wait for Step 1 to complete (5s)\n'
                    '3. Force quit app (swipe from app switcher)\n'
                    '4. Reopen app\n'
                    '5. iOS: Should resume from Step 2 ✅',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                             size: 16,
                             color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'iOS: Uses ChainStateManager for persistence\n'
                            'Android: KMP behavior (restart from beginning)',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
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
                  const Icon(Icons.flag, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _status,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startResilientChain,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Chain'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearTestData,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(),

          // Logs
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.list_alt, size: 20),
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

          SizedBox(
            height: 300,
            child: Container(
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
                            : _logs[index].contains('✅') || _logs[index].contains('🎉')
                            ? Colors.green
                            : Colors.black87,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
      ),
    );
  }
}
