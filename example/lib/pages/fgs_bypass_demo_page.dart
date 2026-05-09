import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'dart:math';

class FgsBypassDemoPage extends StatefulWidget {
  const FgsBypassDemoPage({super.key});

  @override
  State<FgsBypassDemoPage> createState() => _FgsBypassDemoPageState();
}

class _FgsBypassDemoPageState extends State<FgsBypassDemoPage> {
  final List<String> _logs = [];
  bool _isScheduling = false;

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, "[${DateTime.now().toString().split(' ').last.split('.').first}] $message");
    });
  }

  Future<void> _runFgsTask() async {
    setState(() => _isScheduling = true);
    final taskId = "fgs_task_${Random().nextInt(1000)}";
    
    _addLog("Scheduling FGS Task: $taskId");
    _addLog("Check your notification tray!");

    try {
      await NativeWorkManager.enqueue(
        taskId: taskId,
        worker: HttpRequestWorker(
          url: "https://hub.dummyapis.com/delay?seconds=10", // Artificial 10s delay
          method: HttpMethod.get,
        ),
        constraints: Constraints(
          requiresNetwork: true,
          // Mandatory for FGS Bypass
          foregroundNotificationConfig: ForegroundNotificationConfig(
            title: "Industrial Data Sync",
            body: "Processing task $taskId in high-priority mode...",
            iconName: "ic_launcher_foreground", // Use app icon
            colorHex: "#FF5722", // Deep Orange
            showCancelButton: true,
            cancelText: "Stop Sync",
          ),
        ),
      );
      _addLog("✅ ACCEPTED: Task is now running as a Foreground Service.");
    } catch (e) {
      _addLog("❌ Error: $e");
    } finally {
      setState(() => _isScheduling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("FGS Bypass Demo"),
        backgroundColor: Colors.orange.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: theme.colorScheme.primaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Text(
                      "Foreground Service (FGS) Mode",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "This mode allows tasks to bypass Android Doze Mode and App Standby restrictions by showing a mandatory ongoing notification.",
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isScheduling ? null : _runFgsTask,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
              icon: _isScheduling 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.bolt),
              label: const Text("RUN HIGH-PRIORITY FGS TASK"),
            ),
            const SizedBox(height: 20),
            const Text("Execution Logs:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => Text(
                    _logs[index],
                    style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
