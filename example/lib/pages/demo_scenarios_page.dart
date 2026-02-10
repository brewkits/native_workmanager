import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'file_system_demo_page.dart';

/// Comprehensive demo scenarios showcasing all native_workmanager features.
///
/// This page provides ready-to-run examples of:
/// - Basic task scheduling with various triggers
/// - Periodic tasks with constraints
/// - Task chains (sequential, parallel, mixed)
/// - Constraint demonstrations
/// - Built-in workers (HTTP, File, etc.)
/// - Real-world usage patterns
///
/// Inspired by kmpworkmanager demo app.
class DemoScenariosPage extends StatefulWidget {
  const DemoScenariosPage({super.key});

  @override
  State<DemoScenariosPage> createState() => _DemoScenariosPageState();
}

class _DemoScenariosPageState extends State<DemoScenariosPage> {
  bool _isAnyTaskRunning = false;
  String _runningTaskName = '';
  StreamSubscription<TaskEvent>? _eventSubscription;

  @override
  void initState() {
    super.initState();

    // Listen for task completion events to reset running state
    // Removed .where() filter to catch ALL events.
    // This ensures the UI always unlocks, regardless of the Task ID format.
    _eventSubscription = NativeWorkManager.events.listen((event) {
      if (mounted) {
        // Only update UI if we were actually waiting for a task
        if (_isAnyTaskRunning) {
          setState(() {
            _isAnyTaskRunning = false;
            _runningTaskName = '';
          });

          // Show result snackbar
          final icon = event.success ? '✅' : '❌';
          final message =
              event.message ?? (event.success ? 'Task completed' : 'Task failed');
          _showSnackbar('$icon [${event.taskId}] $message');
        }
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _runTask(String taskName, Future<void> Function() action) {
    if (_isAnyTaskRunning) return;

    setState(() {
      _isAnyTaskRunning = true;
      _runningTaskName = taskName;
    });

    // On iOS, reset UI after 3 seconds since background tasks don't execute while app is in foreground
    // The task is successfully scheduled, but iOS will execute it when app is backgrounded
    if (Platform.isIOS) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isAnyTaskRunning) {
          setState(() {
            _isAnyTaskRunning = false;
            _runningTaskName = '';
          });
          _showSnackbar(
            '✅ Task scheduled successfully\n'
            '💡 Background the app (swipe up) for iOS to execute it',
          );
        }
      });
    }

    action().catchError((error) {
      if (mounted) {
        setState(() {
          _isAnyTaskRunning = false;
          _runningTaskName = '';
        });
        _showSnackbar('❌ Error: $error');
      }
    });
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Scenarios'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // iOS Warning Banner
          if (Platform.isIOS) ...[
            Card(
              color: Colors.orange.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade900,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'iOS Background Task Limitation',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Background tasks on iOS only execute when the app is backgrounded. '
                            'To test: tap a demo button, then swipe up to home screen and wait a few seconds.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Header
          Text(
            'Demo Scenarios',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comprehensive demonstrations of all library features',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // FileSystemWorker Demo Link
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: ListTile(
              leading: Icon(
                Icons.folder_special,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
                size: 32,
              ),
              title: Text(
                'FileSystemWorker Demo',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Interactive demos for all file operations (copy, move, delete, list, mkdir)',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onTertiaryContainer.withAlpha(204),
                  fontSize: 12,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FileSystemDemoPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Running Task Indicator
          if (_isAnyTaskRunning) ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Task Running',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _runningTaskName,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isAnyTaskRunning = false;
                          _runningTaskName = '';
                        });
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      child: const Text('Stop'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ═══════════════════════════════════════════════════════════
          // 1. BASIC TASKS
          // ═══════════════════════════════════════════════════════════
          _buildSection(
            title: 'Basic Tasks',
            icon: Icons.play_arrow,
            children: [
              _buildDemoCard(
                title: 'Quick Sync',
                description: 'OneTime task with no constraints',
                icon: Icons.sync,
                onTap: () => _runTask('Quick Sync', _demoQuickSync),
              ),
              _buildDemoCard(
                title: 'File Upload',
                description: 'OneTime with network required',
                icon: Icons.upload,
                onTap: () => _runTask('File Upload', _demoFileUpload),
              ),
              _buildDemoCard(
                title: 'Database Operation',
                description: 'Batch inserts with progress',
                icon: Icons.storage,
                onTap: () => _runTask('Database Operation', _demoDatabaseOp),
              ),
            ],
          ),

          // ═══════════════════════════════════════════════════════════
          // 2. PERIODIC TASKS
          // ═══════════════════════════════════════════════════════════
          _buildSection(
            title: 'Periodic Tasks',
            icon: Icons.loop,
            children: [
              _buildDemoCard(
                title: 'Hourly Sync',
                description: 'Repeats every hour with network constraints',
                icon: Icons.schedule,
                onTap: () => _runTask('Hourly Sync', _demoHourlySync),
              ),
              _buildDemoCard(
                title: 'Daily Cleanup',
                description: 'Runs every 24 hours while charging',
                icon: Icons.cleaning_services,
                onTap: () => _runTask('Daily Cleanup', _demoDailyCleanup),
              ),
              _buildDemoCard(
                title: 'Location Sync',
                description: 'Periodic 15min location upload',
                icon: Icons.location_on,
                onTap: () => _runTask('Location Sync', _demoLocationSync),
              ),
            ],
          ),

          // ═══════════════════════════════════════════════════════════
          // 3. TASK CHAINS
          // ═══════════════════════════════════════════════════════════
          _buildSection(
            title: 'Task Chains',
            icon: Icons.link,
            children: [
              _buildDemoCard(
                title: 'Sequential: Download → Process → Upload',
                description: 'Three tasks in sequence',
                icon: Icons.arrow_forward,
                onTap: () => _runTask('Sequential Chain', _demoSequentialChain),
              ),
              _buildDemoCard(
                title: 'Parallel: Process 3 Images → Upload',
                description: 'Parallel processing then upload',
                icon: Icons.dynamic_feed,
                onTap: () => _runTask('Parallel Chain', _demoParallelChain),
              ),
              _buildDemoCard(
                title: 'Mixed: Fetch → [Process ∥ Analyze ∥ Compress] → Upload',
                description: 'Sequential + parallel combination',
                icon: Icons.account_tree,
                onTap: () => _runTask('Mixed Chain', _demoMixedChain),
              ),
              _buildDemoCard(
                title: 'Long Chain: 5 Sequential Steps',
                description: 'Extended workflow demonstration',
                icon: Icons.linear_scale,
                onTap: () => _runTask('Long Chain', _demoLongChain),
              ),
            ],
          ),

          // ═══════════════════════════════════════════════════════════
          // 4. CONSTRAINT DEMOS
          // ═══════════════════════════════════════════════════════════
          _buildSection(
            title: 'Constraint Demos',
            icon: Icons.security,
            children: [
              _buildDemoCard(
                title: 'Network Required',
                description: 'Only runs when network available',
                icon: Icons.wifi,
                onTap: () => _runTask('Network Required', _demoNetworkRequired),
              ),
              _buildDemoCard(
                title: 'Unmetered Network (WiFi Only)',
                description: 'Only runs on WiFi/unmetered',
                icon: Icons.wifi_tethering,
                onTap: () => _runTask('WiFi Only', _demoWiFiOnly),
              ),
              _buildDemoCard(
                title: 'Charging Required',
                description: 'Runs only while device is charging',
                icon: Icons.battery_charging_full,
                onTap: () =>
                    _runTask('Charging Required', _demoChargingRequired),
              ),
              _buildDemoCard(
                title: 'Battery Not Low',
                description: 'Defers when battery is low',
                icon: Icons.battery_full,
                onTap: () => _runTask('Battery Not Low', _demoBatteryNotLow),
              ),
              _buildDemoCard(
                title: 'Storage Not Low',
                description: 'Waits for sufficient storage',
                icon: Icons.sd_storage,
                onTap: () => _runTask('Storage Not Low', _demoStorageNotLow),
              ),
              _buildDemoCard(
                title: 'Device Idle (Android)',
                description: 'Runs when device is idle',
                icon: Icons.bedtime,
                onTap: () => _runTask('Device Idle', _demoDeviceIdle),
              ),
            ],
          ),

          // ═══════════════════════════════════════════════════════════
          // 5. BUILT-IN WORKERS
          // ═══════════════════════════════════════════════════════════
          _buildSection(
            title: 'Built-in Workers',
            icon: Icons.construction,
            children: [
              _buildDemoCard(
                title: 'HTTP Download',
                description: 'Download file with progress tracking',
                icon: Icons.download,
                onTap: () => _runTask('HTTP Download', _demoHttpDownload),
              ),
              _buildDemoCard(
                title: 'HTTP Upload',
                description: 'Upload file with multipart form',
                icon: Icons.cloud_upload,
                onTap: () => _runTask('HTTP Upload', _demoHttpUpload),
              ),
              _buildDemoCard(
                title: 'File Compression',
                description: 'Compress files to ZIP archive',
                icon: Icons.compress,
                onTap: () => _runTask('File Compression', _demoFileCompression),
              ),
              _buildDemoCard(
                title: 'HTTP Sync',
                description: 'Sync data with retry logic',
                icon: Icons.sync_alt,
                onTap: () => _runTask('HTTP Sync', _demoHttpSync),
              ),
              _buildDemoCard(
                title: 'File Decompression',
                description: 'Extract ZIP archive with security validation',
                icon: Icons.folder_zip,
                onTap: () =>
                    _runTask('File Decompression', _demoFileDecompression),
              ),
              _buildDemoCard(
                title: 'Image Processing',
                description: 'Resize and compress image (10x faster)',
                icon: Icons.image,
                onTap: () => _runTask('Image Processing', _demoImageProcess),
              ),
              _buildDemoCard(
                title: 'Crypto Hash',
                description: 'SHA-256 hash file for integrity check',
                icon: Icons.fingerprint,
                onTap: () => _runTask('Crypto Hash', _demoCryptoHash),
              ),
              _buildDemoCard(
                title: 'File System',
                description: 'Copy, move, delete files natively',
                icon: Icons.folder,
                onTap: () => _runTask('File System', _demoFileSystem),
              ),
              _buildDemoCard(
                title: 'Complete Native Chain',
                description:
                    'Download → Extract → Process → Upload (all native!)',
                icon: Icons.all_inclusive,
                onTap: () =>
                    _runTask('Complete Chain', _demoCompleteNativeChain),
              ),
            ],
          ),

          // ═══════════════════════════════════════════════════════════
          // 6. iOS BACKGROUND SESSION (v2.3.0+)
          // ═══════════════════════════════════════════════════════════
          if (Platform.isIOS) ...[
            _buildSection(
              title: 'iOS Background Session (v2.3.0+)',
              icon: Icons.cloud_download,
              children: [
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade900),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Background sessions survive app termination and have no time limits. '
                            'Perfect for large files (>10MB) on unreliable networks.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildDemoCard(
                  title: 'Large File Download',
                  description:
                      'Download 10MB file that survives app termination',
                  icon: Icons.download_for_offline,
                  onTap: () => _runTask(
                    'Background Download',
                    _demoBackgroundDownload,
                  ),
                ),
                _buildDemoCard(
                  title: 'Large File Upload',
                  description: 'Upload large file with background session',
                  icon: Icons.upload_file,
                  onTap: () => _runTask(
                    'Background Upload',
                    _demoBackgroundUpload,
                  ),
                ),
              ],
            ),
          ],

          // ═══════════════════════════════════════════════════════════
          // 7. REAL-WORLD SCENARIOS
          // ═══════════════════════════════════════════════════════════
          _buildSection(
            title: 'Real-World Scenarios',
            icon: Icons.business,
            children: [
              _buildDemoCard(
                title: 'Photo Backup Workflow',
                description: 'Compress → Upload → Cleanup on WiFi',
                icon: Icons.photo_library,
                onTap: () => _runTask('Photo Backup', _demoPhotoBackup),
              ),
              _buildDemoCard(
                title: 'Data Sync Pipeline',
                description: 'Download → Process → Save → Notify',
                icon: Icons.cloud_sync,
                onTap: () => _runTask('Data Sync', _demoDataSync),
              ),
              _buildDemoCard(
                title: 'Offline-First Upload Queue',
                description: 'Queue uploads, retry on network',
                icon: Icons.cloud_queue,
                onTap: () => _runTask('Upload Queue', _demoUploadQueue),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDemoCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final enabled = !_isAnyTaskRunning;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: enabled
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: enabled
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_circle_outline,
                color: enabled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BASIC TASKS
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _demoQuickSync() async {
    await NativeWorkManager.enqueue(
      taskId: 'demo-quick-sync',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 2)),
      worker: DartWorker(callbackId: 'customTask'),
    );
    _showSnackbar('⏱️ Quick Sync scheduled (2s delay)');
  }

  Future<void> _demoFileUpload() async {
    await NativeWorkManager.enqueue(
      taskId: 'demo-file-upload',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 5)),
      worker: DartWorker(callbackId: 'customTask'),
      constraints: const Constraints(requiresNetwork: true),
    );
    _showSnackbar('📤 File Upload scheduled (5s, network required)');
  }

  Future<void> _demoDatabaseOp() async {
    await NativeWorkManager.enqueue(
      taskId: 'demo-database',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 3)),
      worker: DartWorker(callbackId: 'customTask'),
    );
    _showSnackbar('💾 Database Worker scheduled (3s delay)');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PERIODIC TASKS
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _demoHourlySync() async {
    await NativeWorkManager.enqueue(
      taskId: 'demo-hourly-sync',
      trigger: TaskTrigger.periodic(const Duration(hours: 1)),
      worker: DartWorker(callbackId: 'customTask'),
      constraints: const Constraints(
        requiresNetwork: true,
        requiresUnmeteredNetwork: true,
      ),
    );
    _showSnackbar('🔄 Hourly Sync scheduled (1h interval, WiFi only)');
  }

  Future<void> _demoDailyCleanup() async {
    await NativeWorkManager.enqueue(
      taskId: 'demo-daily-cleanup',
      trigger: TaskTrigger.periodic(const Duration(hours: 24)),
      worker: DartWorker(callbackId: 'customTask'),
      constraints: const Constraints(requiresCharging: true),
    );
    _showSnackbar('🧹 Daily Cleanup scheduled (24h, charging)');
  }

  Future<void> _demoLocationSync() async {
    await NativeWorkManager.enqueue(
      taskId: 'demo-location-sync',
      trigger: TaskTrigger.periodic(const Duration(minutes: 15)),
      worker: DartWorker(callbackId: 'customTask'),
    );
    _showSnackbar('📍 Location Sync scheduled (15min interval)');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TASK CHAINS (Fixed: IDs must start with 'chain-' to match event listener)
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _demoSequentialChain() async {
    await NativeWorkManager.beginWith(
      TaskRequest(
        id: 'chain-download', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
    )
        .then(
      TaskRequest(
        id: 'chain-process', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
    )
        .then(
      TaskRequest(
        id: 'chain-upload', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
    )
        .enqueue();
    _showSnackbar('⛓️ Sequential chain started (Download → Process → Upload)');
  }

  Future<void> _demoParallelChain() async {
    await NativeWorkManager.beginWith(
      TaskRequest(
        id: 'chain-download-p', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
    )
        .thenAll([
      TaskRequest(
        id: 'chain-process-1', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
      TaskRequest(
        id: 'chain-process-2', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
      TaskRequest(
        id: 'chain-process-3', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
    ])
        .then(
      TaskRequest(
        id: 'chain-upload-p', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
    )
        .enqueue();
    _showSnackbar('⚡ Parallel chain started (3 parallel tasks → Upload)');
  }

  Future<void> _demoMixedChain() async {
    await NativeWorkManager.beginWith(
      TaskRequest(
        id: 'chain-fetch', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
    )
        .thenAll([
      TaskRequest(
        id: 'chain-process-m', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
      TaskRequest(
        id: 'chain-analyze', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
      TaskRequest(
        id: 'chain-compress', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
    ])
        .then(
      TaskRequest(
        id: 'chain-upload-m', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
    )
        .enqueue();
    _showSnackbar('🔀 Mixed chain started (Fetch → [3 parallel] → Upload)');
  }

  Future<void> _demoLongChain() async {
    await NativeWorkManager.beginWith(
      TaskRequest(
        id: 'chain-step-1', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
    )
        .then(
      TaskRequest(
        id: 'chain-step-2', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
    )
        .then(
      TaskRequest(
        id: 'chain-step-3', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
    )
        .then(
      TaskRequest(
        id: 'chain-step-4', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
    )
        .then(
      TaskRequest(
        id: 'chain-step-5', // ✅ ADDED chain- prefix
        worker: DartWorker(callbackId: 'customTask'),
      ),
    )
        .enqueue();
    _showSnackbar('🔗 Long chain started (5 sequential steps)');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CONSTRAINT DEMOS
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _demoNetworkRequired() async {
    await NativeWorkManager.enqueue(
      taskId: 'demo-network-required',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 3)),
      worker: DartWorker(callbackId: 'customTask'),
      constraints: const Constraints(requiresNetwork: true),
    );
    _showSnackbar('📶 Network-constrained task scheduled');
  }

  Future<void> _demoWiFiOnly() async {
    await NativeWorkManager.enqueue(
      taskId: 'demo-wifi-only',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 3)),
      worker: DartWorker(callbackId: 'customTask'),
      constraints: const Constraints(
        requiresNetwork: true,
        requiresUnmeteredNetwork: true,
      ),
    );
    _showSnackbar('📡 WiFi-only task scheduled');
  }

  Future<void> _demoChargingRequired() async {
    await NativeWorkManager.enqueue(
      taskId: 'demo-charging',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 3)),
      worker: DartWorker(callbackId: 'customTask'),
      constraints: const Constraints(requiresCharging: true, isHeavyTask: true),
    );
    _showSnackbar('🔌 Charging-constrained task scheduled');
  }

  Future<void> _demoBatteryNotLow() async {
    await NativeWorkManager.enqueue(
      taskId: 'demo-battery-ok',
      trigger: TaskTrigger.batteryOkay(),
      worker: DartWorker(callbackId: 'customTask'),
    );
    _showSnackbar('🔋 Battery-aware task scheduled');
  }

  Future<void> _demoStorageNotLow() async {
    await NativeWorkManager.enqueue(
      taskId: 'demo-storage-ok',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 3)),
      worker: DartWorker(callbackId: 'customTask'),
      constraints: const Constraints(requiresStorageNotLow: true),
    );
    _showSnackbar('💾 Storage-aware task scheduled');
  }

  Future<void> _demoDeviceIdle() async {
    await NativeWorkManager.enqueue(
      taskId: 'demo-device-idle',
      trigger: TaskTrigger.deviceIdle(),
      worker: DartWorker(callbackId: 'customTask'),
    );
    _showSnackbar('😴 Idle-triggered task scheduled (Android only)');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILT-IN WORKERS
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _demoHttpDownload() async {
    // Use Directory.systemTemp.path instead of hardcoded '/tmp'
    final savePath = '${Directory.systemTemp.path}/demo-download.bin';

    await NativeWorkManager.enqueue(
      taskId: 'demo-http-download',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 2)),
      worker: NativeWorker.httpDownload(
        url: 'https://httpbin.org/bytes/51200', // 50KB test file
        savePath: savePath, // Updated path
      ),
      constraints: const Constraints(requiresNetwork: true),
    );
    _showSnackbar('⬇️ HTTP Download scheduled (50KB file)');
  }

  Future<void> _demoHttpUpload() async {
    // Create demo file first
    final file = File('${Directory.systemTemp.path}/demo-file.txt');
    await file.parent.create(recursive: true);
    await file.writeAsString('Demo upload content: ${DateTime.now()}');

    await NativeWorkManager.enqueue(
      taskId: 'demo-http-upload',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 2)),
      worker: NativeWorker.httpUpload(
        url: 'https://httpbin.org/post',
        filePath: '${Directory.systemTemp.path}/demo-file.txt',
        fileFieldName: 'file',
        additionalFields: {'userId': '123', 'description': 'Demo upload'},
      ),
      constraints: const Constraints(requiresNetwork: true),
    );
    _showSnackbar('⬆️ HTTP Upload scheduled');
  }

  Future<void> _demoFileCompression() async {
    await NativeWorkManager.enqueue(
      taskId: 'demo-file-compress',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 2)),
      worker: DartWorker(
        callbackId: 'customTask',
      ), // Replace with FileCompressionWorker when available
    );
    _showSnackbar('📦 File Compression scheduled');
  }

  Future<void> _demoHttpSync() async {
    await NativeWorkManager.enqueue(
      taskId: 'demo-http-sync',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 2)),
      worker: HttpRequestWorker(
        url: 'https://httpbin.org/get',
        method: HttpMethod.get,
      ),
      constraints: const Constraints(
        requiresNetwork: true,
        backoffPolicy: BackoffPolicy.exponential,
        backoffDelayMs: 30000,
      ),
    );
    _showSnackbar('🔄 HTTP Sync scheduled (with retry)');
  }

  Future<void> _demoFileDecompression() async {
    // Ensure ZIP file exists
    final zipPath = '${Directory.systemTemp.path}/demo-archive.zip';
    final file = File(zipPath);

    if (!await file.exists()) {
      // Create a dummy file (Note: Worker might fail extraction if content is invalid,
      // but it won't crash with "File not found")
      await file.writeAsString('PK... (fake zip content)');
    }

    await NativeWorkManager.enqueue(
      taskId: 'demo-file-decompress',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 2)),
      worker: NativeWorker.fileDecompress(
        zipPath: zipPath,
        targetDir: '${Directory.systemTemp.path}/extracted/',
        overwrite: true,
      ),
    );
    _showSnackbar('📂 File Decompression scheduled (extracts ZIP)');
  }

  Future<void> _demoImageProcess() async {
    final inputPath = '${Directory.systemTemp.path}/demo-photo.jpg';
    final file = File(inputPath);

    if (!await file.exists()) {
      await file.writeAsBytes(List.filled(100, 0)); // Dummy bytes
    }

    await NativeWorkManager.enqueue(
      taskId: 'demo-image-process',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 2)),
      worker: NativeWorker.imageProcess(
        inputPath: inputPath,
        outputPath: '${Directory.systemTemp.path}/demo-photo-1080p.jpg',
        maxWidth: 1920,
        maxHeight: 1080,
        quality: 85,
        outputFormat: ImageFormat.jpeg,
      ),
    );
    _showSnackbar('🖼️ Image Processing scheduled (resize to 1080p)');
  }

  Future<void> _demoCryptoHash() async {
    // Use system temp path and create dummy file if missing
    final filePath = '${Directory.systemTemp.path}/demo-download.bin';
    final file = File(filePath);

    // Create dummy file to prevent "File not found" error
    if (!await file.exists()) {
      await file.writeAsString('Dummy content for hashing check integrity');
    }

    await NativeWorkManager.enqueue(
      taskId: 'demo-crypto-hash',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 2)),
      worker: NativeWorker.hashFile(
        filePath: filePath,
        algorithm: HashAlgorithm.sha256,
      ),
    );
    _showSnackbar('🔐 Crypto Hash scheduled (SHA-256)');
  }

  Future<void> _demoFileSystem() async {
    final sourcePath = '${Directory.systemTemp.path}/demo-download.bin';
    final destPath = '${Directory.systemTemp.path}/backup/demo-download.bin';

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      await sourceFile.writeAsString('Content to be copied via FileSystemWorker');
    }

    // Ensure destination directory exists
    await Directory('${Directory.systemTemp.path}/backup').create(recursive: true);

    await NativeWorkManager.enqueue(
      taskId: 'demo-file-copy',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 2)),
      worker: NativeWorker.fileCopy(
        sourcePath: sourcePath,
        destinationPath: destPath,
        overwrite: true,
      ),
    );
    _showSnackbar('📁 File System scheduled (copy file)');
  }

  // ═══════════════════════════════════════════════════════════
  // iOS BACKGROUND SESSION DEMOS (v2.3.0+)
  // ═══════════════════════════════════════════════════════════

  Future<void> _demoBackgroundDownload() async {
    await NativeWorkManager.enqueue(
      taskId: 'demo-background-download',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 2)),
      worker: NativeWorker.httpDownload(
        url: 'https://httpbin.org/bytes/10485760', // 10MB test file
        savePath: '${Directory.systemTemp.path}/large-download.bin',
        useBackgroundSession: true, // 🚀 Survives app termination
      ),
      constraints: const Constraints(requiresNetwork: true),
    );
    _showSnackbar(
      '⬇️ Background Download scheduled (10MB)\n'
      '💡 Try force-quitting the app - download continues!',
    );
  }

  Future<void> _demoBackgroundUpload() async {
    // Create a large test file (1MB)
    final file = File('${Directory.systemTemp.path}/large-upload.bin');
    await file.parent.create(recursive: true);

    // Generate 1MB of data
    final data = List<int>.filled(1024 * 1024, 65); // 1MB of 'A' characters
    await file.writeAsBytes(data);

    await NativeWorkManager.enqueue(
      taskId: 'demo-background-upload',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 2)),
      worker: NativeWorker.httpUpload(
        url: 'https://httpbin.org/post',
        filePath: '${Directory.systemTemp.path}/large-upload.bin',
        fileFieldName: 'file',
        useBackgroundSession: true, // 🚀 Survives app termination
      ),
      constraints: const Constraints(requiresNetwork: true),
    );
    _showSnackbar(
      '⬆️ Background Upload scheduled (1MB)\n'
      '💡 Upload continues even if app is terminated!',
    );
  }

  Future<void> _demoCompleteNativeChain() async {
    // Complete native chain: Download → Move → Extract → Process → Hash → Upload
    // All workers are native, no Flutter Engine needed!

    // Step 1: Download ZIP file
    await NativeWorkManager.beginWith(
          TaskRequest(
            id: 'chain-download',
            worker: HttpDownloadWorker(
              url: 'https://httpbin.org/bytes/102400', // 100KB test file
              savePath: '${Directory.systemTemp.path}/chain-download.zip',
            ),
            constraints: const Constraints(requiresNetwork: true),
          ),
        )
        // Step 2: Move to processing directory
        .then(
          TaskRequest(
            id: 'chain-move',
            worker: NativeWorker.fileMove(
              sourcePath: '${Directory.systemTemp.path}/chain-download.zip',
              destinationPath: '${Directory.systemTemp.path}/processing/archive.zip',
            ),
          ),
        )
        // Step 3: Create backup copy
        .then(
          TaskRequest(
            id: 'chain-copy',
            worker: NativeWorker.fileCopy(
              sourcePath: '${Directory.systemTemp.path}/processing/archive.zip',
              destinationPath: '${Directory.systemTemp.path}/backup/archive.zip',
            ),
          ),
        )
        // Step 4: Hash for integrity
        .then(
          TaskRequest(
            id: 'chain-hash',
            worker: NativeWorker.hashFile(
              filePath: '${Directory.systemTemp.path}/processing/archive.zip',
              algorithm: HashAlgorithm.sha256,
            ),
          ),
        )
        // Step 5: Extract files (if it were a real ZIP)
        // Note: In real app, would have actual ZIP content
        // .then(
        //   TaskRequest(
        //     id: 'chain-extract',
        //     worker: NativeWorker.fileDecompress(
        //       zipPath: '/tmp/processing/archive.zip',
        //       targetDir: '/tmp/extracted/',
        //     ),
        //   ),
        // )
        // Step 6: Process image (if extracted contains images)
        // .then(
        //   TaskRequest(
        //     id: 'chain-process',
        //     worker: NativeWorker.imageProcess(
        //       inputPath: '/tmp/extracted/photo.jpg',
        //       outputPath: '/tmp/processed/photo.jpg',
        //       maxWidth: 1920,
        //       maxHeight: 1080,
        //     ),
        //   ),
        // )
        // Step 7: Upload result
        .then(
          TaskRequest(
            id: 'chain-upload',
            worker: HttpUploadWorker(
              url: 'https://httpbin.org/post',
              filePath: '${Directory.systemTemp.path}/backup/archive.zip',
              fileFieldName: 'file',
              additionalFields: {
                'workflow': 'complete-native-chain',
                'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
              },
            ),
            constraints: const Constraints(requiresNetwork: true),
          ),
        )
        // Step 8: Cleanup temp files
        .then(
          TaskRequest(
            id: 'chain-cleanup',
            worker: NativeWorker.fileDelete(
              path: '${Directory.systemTemp.path}/processing',
              recursive: true,
            ),
          ),
        )
        .enqueue();

    _showSnackbar('🚀 Complete Native Chain started (7 steps, all native!)');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REAL-WORLD SCENARIOS
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _demoPhotoBackup() async {
    // Create dummy input photo
    final inputPath = '${Directory.systemTemp.path}/original-photo.jpg';
    final processedPath = '${Directory.systemTemp.path}/processed-photo.jpg';
    final zipPath = '${Directory.systemTemp.path}/photos.zip';

    final photoFile = File(inputPath);
    if (!await photoFile.exists()) {
      await photoFile.writeAsBytes(List.filled(1024, 0)); // Dummy image data
    }

    // Photo Backup: Process → Compress → Upload → Cleanup (on WiFi)
    await NativeWorkManager.beginWith(
      TaskRequest(
        id: 'chain-process-photo', // Added 'chain-' prefix
        worker: NativeWorker.imageProcess(
          inputPath: inputPath,
          outputPath: processedPath,
          maxWidth: 1920,
          maxHeight: 1080,
          quality: 80,
        ),
      ),
    )
        .then(
      TaskRequest(
        id: 'chain-compress-photos', // Added 'chain-' prefix
        worker: NativeWorker.fileCompress(
          inputPath: processedPath,
          outputPath: zipPath,
          level: CompressionLevel.high,
        ),
      ),
    )
        .then(
      TaskRequest(
        id: 'chain-upload-backup', // Added 'chain-' prefix
        worker: HttpUploadWorker(
          url: 'https://httpbin.org/post',
          filePath: zipPath,
          fileFieldName: 'backup',
          additionalFields: {'userId': '123', 'backupType': 'photos'},
        ),
        constraints: const Constraints(
          requiresNetwork: true,
          requiresUnmeteredNetwork: true,
        ),
      ),
    )
        .then(
      TaskRequest(
        id: 'chain-cleanup-temp', // Added 'chain-' prefix
        worker: NativeWorker.fileDelete(path: processedPath),
      ),
    )
        .enqueue();
    _showSnackbar('📸 Photo Backup workflow started (WiFi only, all native!)');
  }

  Future<void> _demoDataSync() async {
    final downloadPath = '${Directory.systemTemp.path}/download/data.json';
    final processingPath = '${Directory.systemTemp.path}/processing/data.json';
    final backupPath = '${Directory.systemTemp.path}/backup/data.json';

    await File(downloadPath).parent.create(recursive: true);
    final downloadFile = File(downloadPath);
    if (!await downloadFile.exists()) {
      await downloadFile.writeAsString('{"data": "dummy content for sync"}');
    }

    // Data Sync: Download → Move → Backup → Hash → Process
    await NativeWorkManager.beginWith(
      TaskRequest(
        id: 'chain-download-data',
        worker: HttpDownloadWorker(
          url: 'https://httpbin.org/json',
          savePath: downloadPath,
        ),
        constraints: const Constraints(requiresNetwork: true),
      ),
    )
        .then(
      TaskRequest(
        id: 'chain-move-processing',
        worker: NativeWorker.fileMove(
          sourcePath: downloadPath,
          destinationPath: processingPath,
          overwrite: true,
        ),
      ),
    )
        .then(
      TaskRequest(
        id: 'chain-create-backup',
        worker: NativeWorker.fileCopy(
          sourcePath: processingPath,
          destinationPath: backupPath,
          overwrite: true,
        ),
      ),
    )
        .then(
      TaskRequest(
        id: 'chain-verify-hash',
        worker: NativeWorker.hashFile(
          filePath: processingPath,
          algorithm: HashAlgorithm.sha256,
        ),
      ),
    )
        .then(
      TaskRequest(
        id: 'chain-process-data',
        worker: DartWorker(callbackId: 'customTask'),
      ),
    )
        .enqueue();
    _showSnackbar('🔄 Data Sync Pipeline started (native file ops!)');
  }

  Future<void> _demoUploadQueue() async {
    // Offline-First Upload Queue: Queue multiple uploads with retry
    for (int i = 1; i <= 3; i++) {
      // Create dummy file first
      final filePath = '${Directory.systemTemp.path}/file-$i.txt';
      final file = File(filePath);
      if (!await file.exists()) {
        await file.writeAsString('Dummy content for upload $i');
      }

      await NativeWorkManager.enqueue(
        taskId: 'upload-queue-$i',
        trigger: TaskTrigger.oneTime(Duration(seconds: i * 2)),
        worker: HttpUploadWorker(
          url: 'https://httpbin.org/post', // Updated to valid test endpoint
          filePath: filePath, // Use system temp path
        ),
        constraints: const Constraints(
          requiresNetwork: true,
          backoffPolicy: BackoffPolicy.exponential,
          backoffDelayMs: 10000,
        ),
      );
    }
    _showSnackbar('☁️ Upload Queue scheduled (3 files with retry)');
  }
}
