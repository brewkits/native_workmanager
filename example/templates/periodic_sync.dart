/// Periodic Background Sync Template
///
/// Copy-paste ready code for periodic background synchronization tasks.
/// This template demonstrates:
/// - Periodic task scheduling
/// - Constraint-based execution (WiFi, battery, etc.)
/// - Multiple sync endpoints
/// - Sync conflict resolution
///
/// USAGE:
/// 1. Replace API URLs with your actual endpoints
/// 2. Configure sync intervals for your needs
/// 3. Add your authentication logic
/// 4. Run and test
library;

import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'dart:developer' as developer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize native_workmanager
  await NativeWorkManager.initialize();

  runApp(const PeriodicSyncApp());
}

class PeriodicSyncApp extends StatefulWidget {
  const PeriodicSyncApp({super.key});

  @override
  State<PeriodicSyncApp> createState() => _PeriodicSyncAppState();
}

class _PeriodicSyncAppState extends State<PeriodicSyncApp> {
  final Map<String, SyncStatus> _syncStatuses = {};

  @override
  void initState() {
    super.initState();
    _setupEventListener();
    _scheduleAllSyncs();
  }

  void _setupEventListener() {
    NativeWorkManager.events.listen((event) {
      final syncType = event.taskId.replaceAll('-sync', '');

      setState(() {
        _syncStatuses[syncType] = SyncStatus(
          state: event.success ? TaskStatus.completed : TaskStatus.failed,
          lastSync: event.success
              ? DateTime.now()
              : _syncStatuses[syncType]?.lastSync,
          error: event.success ? null : event.message,
        );
      });

      developer.log(
        '🔄 $syncType sync: ${event.success ? 'succeeded' : 'failed'}',
      );
    });
  }

  /// Schedule all background syncs
  Future<void> _scheduleAllSyncs() async {
    await _scheduleUserDataSync();
    await _scheduleMessagesSync();
    await _scheduleMediaBackup();
    await _scheduleAnalyticsSync();
  }

  /// Example 1: User Data Sync (Every 1 hour)
  /// Syncs user profile, settings, preferences
  Future<void> _scheduleUserDataSync() async {
    try {
      await NativeWorkManager.enqueue(
        taskId: 'user-sync',
        trigger: TaskTrigger.periodic(
          const Duration(hours: 1),
          flexInterval: const Duration(minutes: 15),
        ),
        worker: NativeWorker.httpRequest(
          // 👇 REPLACE with your user data endpoint
          url: 'https://api.example.com/user/sync',
          method: HttpMethod.post,
          body: '{"lastSync": "${DateTime.now().toIso8601String()}"}',
          headers: {
            'Authorization': 'Bearer YOUR_AUTH_TOKEN',
            'Content-Type': 'application/json',
          },
        ),
        constraints: const Constraints(
          requiresNetwork: true,
          requiresBatteryNotLow: true,
        ),
      );

      developer.log('✅ User data sync scheduled (every 1 hour)');
    } catch (e) {
      developer.log('❌ Failed to schedule user sync: $e');
    }
  }

  /// Example 2: Messages Sync (Every 15 minutes)
  /// Syncs chat messages, notifications
  Future<void> _scheduleMessagesSync() async {
    try {
      await NativeWorkManager.enqueue(
        taskId: 'messages-sync',
        trigger: TaskTrigger.periodic(
          const Duration(minutes: 15),
          flexInterval: const Duration(minutes: 5),
        ),
        worker: NativeWorker.httpRequest(
          url: 'https://api.example.com/messages/sync',
          method: HttpMethod.get,
          headers: {'Authorization': 'Bearer YOUR_AUTH_TOKEN'},
        ),
        constraints: Constraints(requiresNetwork: true),
      );

      developer.log('✅ Messages sync scheduled (every 15 minutes)');
    } catch (e) {
      developer.log('❌ Failed to schedule messages sync: $e');
    }
  }

  /// Example 3: Media Backup (Daily on WiFi + Charging)
  /// Backs up photos, videos to cloud
  Future<void> _scheduleMediaBackup() async {
    try {
      await NativeWorkManager.enqueue(
        taskId: 'media-sync',
        trigger: TaskTrigger.periodic(
          const Duration(days: 1),
          flexInterval: const Duration(hours: 4),
        ),
        worker: NativeWorker.httpUpload(
          url: 'https://backup.example.com/media',
          // In real app, you'd get list of unsynced media files
          filePath: '/photos/recent.jpg',
          headers: const {'Authorization': 'Bearer YOUR_AUTH_TOKEN'},
        ),
        constraints: const Constraints(
          requiresUnmeteredNetwork: true, // Only on WiFi for large uploads
          requiresCharging: true, // Only when charging
          requiresBatteryNotLow: true,
        ),
      );

      developer.log('✅ Media backup scheduled (daily on WiFi + charging)');
    } catch (e) {
      developer.log('❌ Failed to schedule media backup: $e');
    }
  }

  /// Example 4: Analytics Sync (Every 6 hours)
  /// Syncs usage analytics, app events
  Future<void> _scheduleAnalyticsSync() async {
    try {
      await NativeWorkManager.enqueue(
        taskId: 'analytics-sync',
        trigger: TaskTrigger.periodic(
          const Duration(hours: 6),
          flexInterval: const Duration(hours: 1),
        ),
        worker: NativeWorker.httpRequest(
          url: 'https://analytics.example.com/events',
          method: HttpMethod.post,
          body:
              '{"events": [], "timestamp": "${DateTime.now().toIso8601String()}"}',
          headers: {'Content-Type': 'application/json'},
        ),
        constraints: Constraints(requiresNetwork: true),
      );

      developer.log('✅ Analytics sync scheduled (every 6 hours)');
    } catch (e) {
      developer.log('❌ Failed to schedule analytics sync: $e');
    }
  }

  /// Cancel all syncs
  Future<void> _cancelAllSyncs() async {
    await NativeWorkManager.cancelAll();
    setState(() {
      _syncStatuses.clear();
    });
    developer.log('✅ All syncs cancelled');
  }

  /// Trigger manual sync for testing
  Future<void> _manualSync(String syncType) async {
    try {
      await NativeWorkManager.enqueue(
        taskId: '$syncType-manual',
        trigger: TaskTrigger.oneTime(),
        worker: NativeWorker.httpRequest(
          url: 'https://api.example.com/$syncType/sync',
          method: HttpMethod.get,
          headers: {'Authorization': 'Bearer YOUR_AUTH_TOKEN'},
        ),
      );
      developer.log('✅ Manual $syncType sync triggered');
    } catch (e) {
      developer.log('❌ Failed manual sync: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Periodic Background Sync')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Background Syncs',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    _buildSyncCard(
                      'User Data',
                      'Every 1 hour',
                      'user',
                      Icons.person,
                    ),
                    _buildSyncCard(
                      'Messages',
                      'Every 15 minutes',
                      'messages',
                      Icons.message,
                    ),
                    _buildSyncCard(
                      'Media Backup',
                      'Daily (WiFi + Charging)',
                      'media',
                      Icons.photo,
                    ),
                    _buildSyncCard(
                      'Analytics',
                      'Every 6 hours',
                      'analytics',
                      Icons.analytics,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _cancelAllSyncs,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Cancel All Syncs'),
              ),
              const SizedBox(height: 20),
              const Text(
                '📱 Sync Strategies:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Frequent: 15min - 1hr (messages, user data)'),
              const Text('• Moderate: 6hr - 12hr (analytics, feeds)'),
              const Text('• Rare: Daily+ (media backup, full sync)'),
              const Text('• Conditional: WiFi + charging for large data'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncCard(
    String title,
    String interval,
    String syncType,
    IconData icon,
  ) {
    final status = _syncStatuses[syncType];
    final lastSyncText = status?.lastSync != null
        ? _formatTime(status!.lastSync!)
        : 'Never';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 40),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Interval: $interval'),
            Text('Last sync: $lastSyncText'),
            if (status?.error != null)
              Text(
                'Error: ${status!.error}',
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.sync),
          onPressed: () => _manualSync(syncType),
          tooltip: 'Sync now',
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class SyncStatus {
  final TaskStatus state;
  final DateTime? lastSync;
  final String? error;

  SyncStatus({required this.state, this.lastSync, this.error});
}

/// 📚 Advanced Sync Patterns:
///
/// Incremental Sync (Only changed data):
/// ```dart
/// NativeWorker.httpRequest(
///   url: 'https://api.example.com/sync',
///   method: HttpMethod.post,
///   body: '{"lastSync": "$lastSyncTimestamp", "includeDeleted": true}',
/// )
/// ```
///
/// Batch Sync (Multiple endpoints in sequence):
/// ```dart
/// await NativeWorkManager.beginWith(TaskRequest(
///   id: 'sync-users',
///   worker: NativeWorker.httpRequest(url: 'https://api.example.com/users'),
/// ))
/// .then(TaskRequest(
///   id: 'sync-messages',
///   worker: NativeWorker.httpRequest(url: 'https://api.example.com/messages'),
/// ))
/// .then(TaskRequest(
///   id: 'sync-media',
///   worker: NativeWorker.httpRequest(url: 'https://api.example.com/media'),
/// ))
/// .enqueue();
/// ```
///
/// Conflict Resolution:
/// ```dart
/// // Server returns conflicts in response
/// NativeWorker.httpRequest(
///   url: 'https://api.example.com/sync',
///   method: HttpMethod.post,
///   successPattern: r'"conflicts"\s*:\s*\[\s*\]',  // No conflicts
///   failurePattern: r'"conflicts"\s*:\s*\[',       // Has conflicts
/// )
/// ```