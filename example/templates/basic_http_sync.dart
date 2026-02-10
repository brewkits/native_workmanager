/// Basic HTTP Sync Template
///
/// Copy-paste ready code for periodic API sync background tasks.
/// This template demonstrates the simplest use case: periodic HTTP GET requests.
///
/// USAGE:
/// 1. Replace YOUR_API_URL with your actual API endpoint
/// 2. Replace YOUR_AUTH_TOKEN with your authentication token (if needed)
/// 3. Adjust the interval (currently 1 hour)
/// 4. Run and test
library;

import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'dart:developer' as developer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize native_workmanager
  await NativeWorkManager.initialize();

  runApp(const BasicHttpSyncApp());
}

class BasicHttpSyncApp extends StatefulWidget {
  const BasicHttpSyncApp({super.key});

  @override
  State<BasicHttpSyncApp> createState() => _BasicHttpSyncAppState();
}

class _BasicHttpSyncAppState extends State<BasicHttpSyncApp> {
  String _status = 'Not started';
  String _lastSync = 'Never';

  @override
  void initState() {
    super.initState();
    _setupEventListener();
    _scheduleSync();
  }

  /// Setup event listener to track task completion
  void _setupEventListener() {
    NativeWorkManager.events.listen((event) {
      if (event.taskId == 'api-sync') {
        setState(() {
          _status = event.success ? 'succeeded' : 'failed';
          if (event.success) {
            _lastSync = DateTime.now().toString();
            // Access response data
            final data = event.resultData;
            developer.log('Sync successful! Response: ${data?['body']}');
          } else {
            developer.log('Sync failed: ${event.message}');
          }
        });
      }
    });
  }

  /// Schedule periodic API sync every 1 hour
  Future<void> _scheduleSync() async {
    try {
      await NativeWorkManager.enqueue(
        taskId: 'api-sync',
        trigger: TaskTrigger.periodic(
          const Duration(hours: 1),
          flexInterval: const Duration(minutes: 15), // Allow 15min flexibility
        ),
        worker: NativeWorker.httpRequest(
          // 👇 REPLACE THIS with your API endpoint
          url: 'https://api.example.com/sync',
          method: HttpMethod.get,
          headers: {
            // 👇 REPLACE THIS with your auth token
            'Authorization': 'Bearer YOUR_AUTH_TOKEN',
            'Content-Type': 'application/json',
          },
          // Optional: Validate response contains success
        ),
        constraints: Constraints(
          requiresNetwork: true, // Only run when network available
          requiresBatteryNotLow: true, // Skip if battery is low
        ),
      );

      setState(() {
        _status = 'Scheduled';
      });

      developer.log('✅ API sync scheduled! Will run every hour.');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      developer.log('❌ Failed to schedule sync: $e');
    }
  }

  /// Trigger sync immediately (for testing)
  Future<void> _syncNow() async {
    try {
      await NativeWorkManager.enqueue(
        taskId: 'api-sync-manual',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpRequest(
          url: 'https://api.example.com/sync',
          method: HttpMethod.get,
          headers: {
            'Authorization': 'Bearer YOUR_AUTH_TOKEN',
            'Content-Type': 'application/json',
          },
        ),
      );

      developer.log('✅ Manual sync triggered!');
    } catch (e) {
      developer.log('❌ Failed to trigger sync: $e');
    }
  }

  /// Cancel scheduled sync
  Future<void> _cancelSync() async {
    try {
      await NativeWorkManager.cancel('api-sync');
      setState(() {
        _status = 'Cancelled';
      });
      developer.log('✅ Sync cancelled');
    } catch (e) {
      developer.log('❌ Failed to cancel: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Basic HTTP Sync')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Periodic API Sync',
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
                      Text('Last Sync: $_lastSync'),
                      const SizedBox(height: 8),
                      const Text('Interval: Every 1 hour'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _syncNow,
                child: const Text('Sync Now (Test)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _cancelSync,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Cancel Sync'),
              ),
              const SizedBox(height: 20),
              const Text(
                '📝 Configuration:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Runs every 1 hour'),
              const Text('• Only when network available'),
              const Text('• Skips if battery is low'),
              const Text('• Uses native worker (no Flutter overhead)'),
              const SizedBox(height: 20),
              const Text(
                '💡 Common Use Cases:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Sync app data with server'),
              const Text('• Check for new messages/notifications'),
              const Text('• Update content cache'),
              const Text('• Refresh user session'),
            ],
          ),
        ),
      ),
    );
  }
}

/// 📚 Additional Examples:
///
/// POST Request with Body:
/// ```dart
/// NativeWorker.httpRequest(
///   url: 'https://api.example.com/sync',
///   method: HttpMethod.post,
///   body: '{"lastSync": "2024-01-01T00:00:00Z"}',
///   headers: {
///     'Authorization': 'Bearer YOUR_TOKEN',
///     'Content-Type': 'application/json',
///   },
/// )
/// ```
///
/// With Response Validation:
/// ```dart
/// NativeWorker.httpRequest(
///   url: 'https://api.example.com/check',
///   method: HttpMethod.get,
///   successPattern: r'"status"\s*:\s*"ok"',  // Must contain this
///   failurePattern: r'"error"',              // Fail if contains this
/// )
/// ```
///
/// Multiple Sync Endpoints:
/// ```dart
/// // User data sync
/// await NativeWorkManager.enqueue(
///   taskId: 'user-sync',
///   trigger: TaskTrigger.periodic(Duration(hours: 1)),
///   worker: NativeWorker.httpRequest(url: 'https://api.example.com/user'),
/// );
///
/// // Messages sync
/// await NativeWorkManager.enqueue(
///   taskId: 'messages-sync',
///   trigger: TaskTrigger.periodic(Duration(minutes: 15)),
///   worker: NativeWorker.httpRequest(url: 'https://api.example.com/messages'),
/// );
/// ```
