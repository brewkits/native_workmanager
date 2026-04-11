import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'file_system_demo_page.dart';

// ──────────────────────────────────────────────────────────────────────────
// Data model for searchable/filterable demo items
// ──────────────────────────────────────────────────────────────────────────

enum _DemoCategory { all, http, file, scheduling, chain, advanced }

extension _DemoCategoryLabel on _DemoCategory {
  String get label => switch (this) {
    _DemoCategory.all => 'All',
    _DemoCategory.http => 'HTTP',
    _DemoCategory.file => 'File',
    _DemoCategory.scheduling => 'Schedule',
    _DemoCategory.chain => 'Chain',
    _DemoCategory.advanced => 'Advanced',
  };

  IconData get icon => switch (this) {
    _DemoCategory.all => Icons.apps,
    _DemoCategory.http => Icons.cloud_outlined,
    _DemoCategory.file => Icons.folder_outlined,
    _DemoCategory.scheduling => Icons.schedule_outlined,
    _DemoCategory.chain => Icons.account_tree_outlined,
    _DemoCategory.advanced => Icons.science_outlined,
  };

  Color get color => switch (this) {
    _DemoCategory.all => const Color(0xFF607D8B),
    _DemoCategory.http => const Color(0xFF1565C0),
    _DemoCategory.file => const Color(0xFFE65100),
    _DemoCategory.scheduling => const Color(0xFF2E7D32),
    _DemoCategory.chain => const Color(0xFF6A1B9A),
    _DemoCategory.advanced => const Color(0xFFAD1457),
  };
}

class _DemoEntry {
  const _DemoEntry({
    required this.section,
    required this.category,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String section;
  final _DemoCategory category;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  bool matches(String query) {
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q) ||
        section.toLowerCase().contains(q);
  }
}

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

  // v1.1 parallel download live-progress state
  String? _v11TaskId;
  bool _v11Downloading = false;
  int _v11Progress = 0;
  double? _v11Speed;
  Duration? _v11Eta;
  int? _v11Bytes;
  int? _v11Total;
  StreamSubscription<TaskProgress>? _v11ProgressSub;

  // Search & filter state
  String _searchQuery = '';
  _DemoCategory _selectedCategory = _DemoCategory.all;
  final TextEditingController _searchController = TextEditingController();

  // Cached entry list — built once at init, not on every rebuild/filter call
  late final List<_DemoEntry> _allEntries = _buildEntries();

  @override
  void initState() {
    super.initState();

    // Rich-progress subscription for v1.1 parallel-download live demo
    _v11ProgressSub = NativeWorkManager.progress.listen((p) {
      if (p.taskId == _v11TaskId && mounted) {
        setState(() {
          _v11Progress = p.progress;
          _v11Speed = p.networkSpeed;
          _v11Eta = p.timeRemaining;
          _v11Bytes = p.bytesDownloaded;
          _v11Total = p.totalBytes;
        });
      }
    });

    // Listen for task completion events to reset running state
    _eventSubscription = NativeWorkManager.events.listen((event) {
      // Reset v1.1 parallel download when it finishes (completion only)
      if (event.taskId == _v11TaskId && !event.isStarted && mounted) {
        setState(() => _v11Downloading = false);
      }
      if (mounted && !event.isStarted) {
        // Only update UI if we were actually waiting for a task
        if (_isAnyTaskRunning) {
          setState(() {
            _isAnyTaskRunning = false;
            _runningTaskName = '';
          });

          // Show result snackbar
          final icon = event.success ? '✅' : '❌';
          final message =
              event.message ??
              (event.success ? 'Task completed' : 'Task failed');
          _showSnackbar('$icon [${event.taskId}] $message');
        }
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _v11ProgressSub?.cancel();
    _searchController.dispose();
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
    final isFiltering =
        _searchQuery.isNotEmpty || _selectedCategory != _DemoCategory.all;

    return Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (Platform.isIOS) ...[
                  _buildIosBanner(),
                  const SizedBox(height: 16),
                ],
                if (_isAnyTaskRunning) ...[
                  _buildRunningIndicator(),
                  const SizedBox(height: 16),
                ],
                if (isFiltering)
                  ..._buildFilteredList()
                else ...[
                  _buildHeroBanner(),
                  const SizedBox(height: 16),
                  _buildFileSystemCard(),
                  const SizedBox(height: 16),
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
                        onTap: () =>
                            _runTask('Database Operation', _demoDatabaseOp),
                      ),
                    ],
                  ),
                  _buildSection(
                    title: 'Periodic Tasks',
                    icon: Icons.loop,
                    children: [
                      _buildDemoCard(
                        title: 'Hourly Sync',
                        description:
                            'Repeats every hour with network constraints',
                        icon: Icons.schedule,
                        onTap: () => _runTask('Hourly Sync', _demoHourlySync),
                      ),
                      _buildDemoCard(
                        title: 'Daily Cleanup',
                        description: 'Runs every 24 hours while charging',
                        icon: Icons.cleaning_services,
                        onTap: () =>
                            _runTask('Daily Cleanup', _demoDailyCleanup),
                      ),
                      _buildDemoCard(
                        title: 'Location Sync',
                        description: 'Periodic 15min location upload',
                        icon: Icons.location_on,
                        onTap: () =>
                            _runTask('Location Sync', _demoLocationSync),
                      ),
                    ],
                  ),
                  _buildSection(
                    title: 'Task Chains',
                    icon: Icons.link,
                    children: [
                      _buildDemoCard(
                        title:
                            'Sequential: Download \u2192 Process \u2192 Upload',
                        description: 'Three tasks in sequence',
                        icon: Icons.arrow_forward,
                        onTap: () =>
                            _runTask('Sequential Chain', _demoSequentialChain),
                      ),
                      _buildDemoCard(
                        title: 'Parallel: Process 3 Images \u2192 Upload',
                        description: 'Parallel processing then upload',
                        icon: Icons.dynamic_feed,
                        onTap: () =>
                            _runTask('Parallel Chain', _demoParallelChain),
                      ),
                      _buildDemoCard(
                        title:
                            'Mixed: Fetch \u2192 [Process \u2225 Analyze \u2225 Compress] \u2192 Upload',
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
                  _buildSection(
                    title: 'Constraint Demos',
                    icon: Icons.security,
                    children: [
                      _buildDemoCard(
                        title: 'Network Required',
                        description: 'Only runs when network available',
                        icon: Icons.wifi,
                        onTap: () =>
                            _runTask('Network Required', _demoNetworkRequired),
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
                        onTap: () => _runTask(
                          'Charging Required',
                          _demoChargingRequired,
                        ),
                      ),
                      _buildDemoCard(
                        title: 'Battery Not Low',
                        description: 'Defers when battery is low',
                        icon: Icons.battery_full,
                        onTap: () =>
                            _runTask('Battery Not Low', _demoBatteryNotLow),
                      ),
                      _buildDemoCard(
                        title: 'Storage Not Low',
                        description: 'Waits for sufficient storage',
                        icon: Icons.sd_storage,
                        onTap: () =>
                            _runTask('Storage Not Low', _demoStorageNotLow),
                      ),
                      _buildDemoCard(
                        title: 'Device Idle (Android)',
                        description: 'Runs when device is idle',
                        icon: Icons.bedtime,
                        onTap: () => _runTask('Device Idle', _demoDeviceIdle),
                      ),
                    ],
                  ),
                  _buildSection(
                    title: 'Built-in Workers',
                    icon: Icons.construction,
                    children: [
                      _buildDemoCard(
                        title: 'HTTP Download',
                        description: 'Download file with progress tracking',
                        icon: Icons.download,
                        onTap: () =>
                            _runTask('HTTP Download', _demoHttpDownload),
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
                        onTap: () =>
                            _runTask('File Compression', _demoFileCompression),
                      ),
                      _buildDemoCard(
                        title: 'HTTP Sync',
                        description: 'Sync data with retry logic',
                        icon: Icons.sync_alt,
                        onTap: () => _runTask('HTTP Sync', _demoHttpSync),
                      ),
                      _buildDemoCard(
                        title: 'File Decompression',
                        description:
                            'Extract ZIP archive with security validation',
                        icon: Icons.folder_zip,
                        onTap: () => _runTask(
                          'File Decompression',
                          _demoFileDecompression,
                        ),
                      ),
                      _buildDemoCard(
                        title: 'Image Processing',
                        description: 'Resize and compress image (10x faster)',
                        icon: Icons.image,
                        onTap: () =>
                            _runTask('Image Processing', _demoImageProcess),
                      ),
                      _buildDemoCard(
                        title: 'Crypto Hash',
                        description: 'SHA-256 hash file for integrity check',
                        icon: Icons.fingerprint,
                        onTap: () => _runTask('Crypto Hash', _demoCryptoHash),
                      ),
                      _buildDemoCard(
                        title: 'Crypto Encrypt',
                        description: 'AES-256-GCM — password via secure vault',
                        icon: Icons.lock,
                        onTap: () =>
                            _runTask('Crypto Encrypt', _demoCryptoEncrypt),
                      ),
                      _buildDemoCard(
                        title: 'Crypto Decrypt',
                        description: 'Decrypt AES-256-GCM encrypted file',
                        icon: Icons.lock_open,
                        onTap: () =>
                            _runTask('Crypto Decrypt', _demoCryptoDecrypt),
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
                            'Download \u2192 Extract \u2192 Process \u2192 Upload (all native!)',
                        icon: Icons.all_inclusive,
                        onTap: () => _runTask(
                          'Complete Chain',
                          _demoCompleteNativeChain,
                        ),
                      ),
                    ],
                  ),
                  if (Platform.isIOS)
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
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade900,
                                ),
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
                          description:
                              'Upload large file with background session',
                          icon: Icons.upload_file,
                          onTap: () => _runTask(
                            'Background Upload',
                            _demoBackgroundUpload,
                          ),
                        ),
                      ],
                    ),
                  _buildSection(
                    title: 'Real-World Scenarios',
                    icon: Icons.business,
                    children: [
                      _buildDemoCard(
                        title: 'Photo Backup Workflow',
                        description:
                            'Compress \u2192 Upload \u2192 Cleanup on WiFi',
                        icon: Icons.photo_library,
                        onTap: () => _runTask('Photo Backup', _demoPhotoBackup),
                      ),
                      _buildDemoCard(
                        title: 'Data Sync Pipeline',
                        description:
                            'Download \u2192 Process \u2192 Save \u2192 Notify',
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
                  _buildSection(
                    title: 'New v1.1 Features',
                    icon: Icons.new_releases,
                    children: [
                      _buildParallelDownloadCard(),
                      _buildDemoCard(
                        title: 'skipExisting \u2013 Skip if File Exists',
                        description:
                            'Enqueue download; file already exists \u2192 task returns skipped=true instantly',
                        icon: Icons.skip_next,
                        onTap: () =>
                            _runTask('skipExisting', _demoSkipExisting),
                      ),
                      _buildDemoCard(
                        title: 'pauseByTag / resumeByTag',
                        description:
                            'Enqueue 2 tasks with tag "v11-group", pause group, then resume',
                        icon: Icons.pause_circle_outline,
                        onTap: () =>
                            _runTask('Group Control', _demoGroupControl),
                      ),
                      _buildDemoCard(
                        title: 'pauseAll / resumeAll',
                        description:
                            'Pause every running task, then immediately resume all',
                        icon: Icons.pause_presentation,
                        onTap: () => _runTask(
                          'pauseAll + resumeAll',
                          _demoPauseResumeAll,
                        ),
                      ),
                      _buildDemoCard(
                        title: 'enqueueAll \u2013 Batch Enqueue',
                        description:
                            'Schedule 3 HTTP tasks in one call, no await waterfall',
                        icon: Icons.playlist_add,
                        onTap: () => _runTask('enqueueAll', _demoEnqueueAll),
                      ),
                      _buildDemoCard(
                        title: 'getTasksByStatus',
                        description:
                            'Query all tasks, group by status, show summary snackbar',
                        icon: Icons.filter_list,
                        onTap: _demoGetTasksByStatus,
                      ),
                    ],
                  ),
                  _buildSection(
                    title: 'Advanced API',
                    icon: Icons.science,
                    children: [
                      _buildDemoCard(
                        title: 'TaskGraph (DAG) \u2014 Fan-out + Fan-in',
                        description:
                            'Two parallel downloads feed one merge step; cycle detection included',
                        icon: Icons.account_tree,
                        onTap: () => _runTask('TaskGraph', _demoTaskGraph),
                      ),
                      _buildDemoCard(
                        title: 'ObservabilityConfig \u2014 Lifecycle Hooks',
                        description:
                            'Configure onTaskComplete / onTaskFail callbacks; shows snackbar from hook',
                        icon: Icons.visibility,
                        onTap: () =>
                            _runTask('Observability', _demoObservability),
                      ),
                      _buildDemoCard(
                        title: 'OfflineQueue \u2014 FIFO with Retry',
                        description:
                            'Queue 3 uploads via OfflineQueue class with exponential backoff',
                        icon: Icons.queue,
                        onTap: () =>
                            _runTask('OfflineQueue', _demoOfflineQueueClass),
                      ),
                      _buildDemoCard(
                        title: 'Request Signing (HMAC-SHA256)',
                        description:
                            'HttpDownloadWorker.withSigning() \u2014 adds X-Signature header',
                        icon: Icons.lock,
                        onTap: () =>
                            _runTask('Request Signing', _demoRequestSigning),
                      ),
                      _buildDemoCard(
                        title: 'Bandwidth Limit (500\u00a0KB/s)',
                        description:
                            'Download throttled to 500\u00a0KB/s via withBandwidthLimit()',
                        icon: Icons.speed,
                        onTap: () =>
                            _runTask('Bandwidth Limit', _demoBandwidthLimit),
                      ),
                      _buildDemoCard(
                        title: 'Parallel Upload (3 files, max 2 concurrent)',
                        description:
                            'ParallelHttpUploadWorker: each file gets its own request with retry',
                        icon: Icons.upload_file,
                        onTap: () =>
                            _runTask('Parallel Upload', _demoParallelUpload),
                      ),
                      _buildDemoCard(
                        title: 'Multi-File Upload (single request)',
                        description:
                            'MultiUploadWorker: 2 files in one multipart/form-data request',
                        icon: Icons.folder_zip,
                        onTap: () => _runTask('Multi Upload', _demoMultiUpload),
                      ),
                      _buildDemoCard(
                        title: 'NET Fixes — Validation & Safety Demos',
                        description:
                            'NET-009/016/018/028: JSON body validation, multipart size guard, '
                            'runtime constructor checks, per-attempt timeout docs',
                        icon: Icons.security,
                        onTap: () => _runTask('NET Fixes', _demoNetFixes),
                      ),
                      _buildDemoCard(
                        title: 'MEDIA Fixes — Safety & Robustness Demos',
                        description:
                            'MEDIA-001..015: BitmapRegionDecoder leak, div-by-zero in PDF, '
                            'atomic image write, partial output cleanup, crop validation',
                        icon: Icons.image_search,
                        onTap: () => _runTask('MEDIA Fixes', _demoMediaFixes),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
    );
  }

  // ── Hero banner ───────────────────────────────────────────────────────────

  Widget _buildHeroBanner() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NativeWorkManager',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'v1.1.1 · 40+ ready-to-run examples',
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildHeroBadge(Icons.android, 'Android'),
              _buildHeroBadge(Icons.apple, 'iOS'),
              _buildHeroBadge(Icons.flash_on_rounded, 'Zero overhead'),
              _buildHeroBadge(Icons.wifi_off_rounded, 'Works offline'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Extracted widget helpers ──────────────────────────────────────────────

  Widget _buildIosBanner() {
    return Card(
      color: Colors.orange.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade900),
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
    );
  }

  Widget _buildRunningIndicator() {
    return Card(
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
                  Text(_runningTaskName, style: const TextStyle(fontSize: 12)),
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
    );
  }

  Widget _buildFileSystemCard() {
    return Card(
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
            MaterialPageRoute(builder: (context) => const FileSystemDemoPage()),
          );
        },
      ),
    );
  }

  Widget _buildParallelDownloadCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.download_for_offline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parallel Download (4 chunks)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Live speed + ETA via rich progress events',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_v11Downloading)
                  TextButton(
                    onPressed: _cancelParallelDownload,
                    child: const Text('Cancel'),
                  )
                else
                  ElevatedButton(
                    onPressed: _startParallelDownload,
                    child: const Text('Start'),
                  ),
              ],
            ),
            if (_v11Downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _v11Progress / 100,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '$_v11Progress%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (_v11Speed != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.speed,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatSpeed(_v11Speed!),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (_v11Eta != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ETA ${_formatEta(_v11Eta!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              if (_v11Bytes != null && _v11Total != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${_formatBytes(_v11Bytes!)} / ${_formatBytes(_v11Total!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Search & filter UI ────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search demos\u2026',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: _DemoCategory.values.map((cat) {
          final selected = _selectedCategory == cat;
          final catColor = cat.color;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: selected,
              showCheckmark: false,
              label: Text(
                cat.label,
                style: TextStyle(
                  color: selected ? Colors.white : null,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
              avatar: Icon(
                cat.icon,
                size: 14,
                color: selected ? Colors.white : catColor,
              ),
              selectedColor: catColor,
              onSelected: (_) => setState(() => _selectedCategory = cat),
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: catColor.withAlpha(80)),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<_DemoEntry> _buildEntries() => [
    _DemoEntry(
      section: 'Basic Tasks',
      category: _DemoCategory.http,
      title: 'Quick Sync',
      description: 'OneTime task with no constraints',
      icon: Icons.sync,
      onTap: () => _runTask('Quick Sync', _demoQuickSync),
    ),
    _DemoEntry(
      section: 'Basic Tasks',
      category: _DemoCategory.http,
      title: 'File Upload',
      description: 'OneTime with network required',
      icon: Icons.upload,
      onTap: () => _runTask('File Upload', _demoFileUpload),
    ),
    _DemoEntry(
      section: 'Basic Tasks',
      category: _DemoCategory.http,
      title: 'Database Operation',
      description: 'Batch inserts with progress',
      icon: Icons.storage,
      onTap: () => _runTask('Database Operation', _demoDatabaseOp),
    ),
    _DemoEntry(
      section: 'Periodic Tasks',
      category: _DemoCategory.scheduling,
      title: 'Hourly Sync',
      description: 'Repeats every hour with network constraints',
      icon: Icons.schedule,
      onTap: () => _runTask('Hourly Sync', _demoHourlySync),
    ),
    _DemoEntry(
      section: 'Periodic Tasks',
      category: _DemoCategory.scheduling,
      title: 'Daily Cleanup',
      description: 'Runs every 24 hours while charging',
      icon: Icons.cleaning_services,
      onTap: () => _runTask('Daily Cleanup', _demoDailyCleanup),
    ),
    _DemoEntry(
      section: 'Periodic Tasks',
      category: _DemoCategory.scheduling,
      title: 'Location Sync',
      description: 'Periodic 15min location upload',
      icon: Icons.location_on,
      onTap: () => _runTask('Location Sync', _demoLocationSync),
    ),
    _DemoEntry(
      section: 'Task Chains',
      category: _DemoCategory.chain,
      title: 'Sequential: Download \u2192 Process \u2192 Upload',
      description: 'Three tasks in sequence',
      icon: Icons.arrow_forward,
      onTap: () => _runTask('Sequential Chain', _demoSequentialChain),
    ),
    _DemoEntry(
      section: 'Task Chains',
      category: _DemoCategory.chain,
      title: 'Parallel: Process 3 Images \u2192 Upload',
      description: 'Parallel processing then upload',
      icon: Icons.dynamic_feed,
      onTap: () => _runTask('Parallel Chain', _demoParallelChain),
    ),
    _DemoEntry(
      section: 'Task Chains',
      category: _DemoCategory.chain,
      title:
          'Mixed: Fetch \u2192 [Process \u2225 Analyze \u2225 Compress] \u2192 Upload',
      description: 'Sequential + parallel combination',
      icon: Icons.account_tree,
      onTap: () => _runTask('Mixed Chain', _demoMixedChain),
    ),
    _DemoEntry(
      section: 'Task Chains',
      category: _DemoCategory.chain,
      title: 'Long Chain: 5 Sequential Steps',
      description: 'Extended workflow demonstration',
      icon: Icons.linear_scale,
      onTap: () => _runTask('Long Chain', _demoLongChain),
    ),
    _DemoEntry(
      section: 'Constraint Demos',
      category: _DemoCategory.scheduling,
      title: 'Network Required',
      description: 'Only runs when network available',
      icon: Icons.wifi,
      onTap: () => _runTask('Network Required', _demoNetworkRequired),
    ),
    _DemoEntry(
      section: 'Constraint Demos',
      category: _DemoCategory.scheduling,
      title: 'Unmetered Network (WiFi Only)',
      description: 'Only runs on WiFi/unmetered',
      icon: Icons.wifi_tethering,
      onTap: () => _runTask('WiFi Only', _demoWiFiOnly),
    ),
    _DemoEntry(
      section: 'Constraint Demos',
      category: _DemoCategory.scheduling,
      title: 'Charging Required',
      description: 'Runs only while device is charging',
      icon: Icons.battery_charging_full,
      onTap: () => _runTask('Charging Required', _demoChargingRequired),
    ),
    _DemoEntry(
      section: 'Constraint Demos',
      category: _DemoCategory.scheduling,
      title: 'Battery Not Low',
      description: 'Defers when battery is low',
      icon: Icons.battery_full,
      onTap: () => _runTask('Battery Not Low', _demoBatteryNotLow),
    ),
    _DemoEntry(
      section: 'Constraint Demos',
      category: _DemoCategory.scheduling,
      title: 'Storage Not Low',
      description: 'Waits for sufficient storage',
      icon: Icons.sd_storage,
      onTap: () => _runTask('Storage Not Low', _demoStorageNotLow),
    ),
    _DemoEntry(
      section: 'Constraint Demos',
      category: _DemoCategory.scheduling,
      title: 'Device Idle (Android)',
      description: 'Runs when device is idle',
      icon: Icons.bedtime,
      onTap: () => _runTask('Device Idle', _demoDeviceIdle),
    ),
    _DemoEntry(
      section: 'Built-in Workers',
      category: _DemoCategory.http,
      title: 'HTTP Download',
      description: 'Download file with progress tracking',
      icon: Icons.download,
      onTap: () => _runTask('HTTP Download', _demoHttpDownload),
    ),
    _DemoEntry(
      section: 'Built-in Workers',
      category: _DemoCategory.http,
      title: 'HTTP Upload',
      description: 'Upload file with multipart form',
      icon: Icons.cloud_upload,
      onTap: () => _runTask('HTTP Upload', _demoHttpUpload),
    ),
    _DemoEntry(
      section: 'Built-in Workers',
      category: _DemoCategory.file,
      title: 'File Compression',
      description: 'Compress files to ZIP archive',
      icon: Icons.compress,
      onTap: () => _runTask('File Compression', _demoFileCompression),
    ),
    _DemoEntry(
      section: 'Built-in Workers',
      category: _DemoCategory.http,
      title: 'HTTP Sync',
      description: 'Sync data with retry logic',
      icon: Icons.sync_alt,
      onTap: () => _runTask('HTTP Sync', _demoHttpSync),
    ),
    _DemoEntry(
      section: 'Built-in Workers',
      category: _DemoCategory.file,
      title: 'File Decompression',
      description: 'Extract ZIP archive with security validation',
      icon: Icons.folder_zip,
      onTap: () => _runTask('File Decompression', _demoFileDecompression),
    ),
    _DemoEntry(
      section: 'Built-in Workers',
      category: _DemoCategory.file,
      title: 'Image Processing',
      description: 'Resize and compress image (10x faster)',
      icon: Icons.image,
      onTap: () => _runTask('Image Processing', _demoImageProcess),
    ),
    _DemoEntry(
      section: 'Built-in Workers',
      category: _DemoCategory.file,
      title: 'Crypto Hash',
      description: 'SHA-256 hash file for integrity check',
      icon: Icons.fingerprint,
      onTap: () => _runTask('Crypto Hash', _demoCryptoHash),
    ),
    _DemoEntry(
      section: 'Built-in Workers',
      category: _DemoCategory.file,
      title: 'Crypto Encrypt',
      description: 'AES-256-GCM encrypt — password via secure vault (SC-C-001)',
      icon: Icons.lock,
      onTap: () => _runTask('Crypto Encrypt', _demoCryptoEncrypt),
    ),
    _DemoEntry(
      section: 'Built-in Workers',
      category: _DemoCategory.file,
      title: 'Crypto Decrypt',
      description: 'AES-256-GCM decrypt from encrypted file (SC-C-001)',
      icon: Icons.lock_open,
      onTap: () => _runTask('Crypto Decrypt', _demoCryptoDecrypt),
    ),
    _DemoEntry(
      section: 'Built-in Workers',
      category: _DemoCategory.file,
      title: 'File System',
      description: 'Copy, move, delete files natively',
      icon: Icons.folder,
      onTap: () => _runTask('File System', _demoFileSystem),
    ),
    _DemoEntry(
      section: 'Built-in Workers',
      category: _DemoCategory.advanced,
      title: 'Complete Native Chain',
      description:
          'Download \u2192 Extract \u2192 Process \u2192 Upload (all native!)',
      icon: Icons.all_inclusive,
      onTap: () => _runTask('Complete Chain', _demoCompleteNativeChain),
    ),
    if (Platform.isIOS) ...[
      _DemoEntry(
        section: 'iOS Background Session',
        category: _DemoCategory.http,
        title: 'Large File Download',
        description: 'Download 10MB file that survives app termination',
        icon: Icons.download_for_offline,
        onTap: () => _runTask('Background Download', _demoBackgroundDownload),
      ),
      _DemoEntry(
        section: 'iOS Background Session',
        category: _DemoCategory.http,
        title: 'Large File Upload',
        description: 'Upload large file with background session',
        icon: Icons.upload_file,
        onTap: () => _runTask('Background Upload', _demoBackgroundUpload),
      ),
    ],
    _DemoEntry(
      section: 'Real-World Scenarios',
      category: _DemoCategory.http,
      title: 'Photo Backup Workflow',
      description: 'Compress \u2192 Upload \u2192 Cleanup on WiFi',
      icon: Icons.photo_library,
      onTap: () => _runTask('Photo Backup', _demoPhotoBackup),
    ),
    _DemoEntry(
      section: 'Real-World Scenarios',
      category: _DemoCategory.http,
      title: 'Data Sync Pipeline',
      description: 'Download \u2192 Process \u2192 Save \u2192 Notify',
      icon: Icons.cloud_sync,
      onTap: () => _runTask('Data Sync', _demoDataSync),
    ),
    _DemoEntry(
      section: 'Real-World Scenarios',
      category: _DemoCategory.http,
      title: 'Offline-First Upload Queue',
      description: 'Queue uploads, retry on network',
      icon: Icons.cloud_queue,
      onTap: () => _runTask('Upload Queue', _demoUploadQueue),
    ),
    _DemoEntry(
      section: 'New v1.1 Features',
      category: _DemoCategory.advanced,
      title: 'Parallel Download (4 chunks)',
      description: 'Live speed + ETA via rich progress events',
      icon: Icons.download_for_offline,
      onTap: _startParallelDownload,
    ),
    _DemoEntry(
      section: 'New v1.1 Features',
      category: _DemoCategory.advanced,
      title: 'skipExisting \u2013 Skip if File Exists',
      description:
          'Enqueue download; file already exists \u2192 task returns skipped=true instantly',
      icon: Icons.skip_next,
      onTap: () => _runTask('skipExisting', _demoSkipExisting),
    ),
    _DemoEntry(
      section: 'New v1.1 Features',
      category: _DemoCategory.advanced,
      title: 'pauseByTag / resumeByTag',
      description:
          'Enqueue 2 tasks with tag "v11-group", pause group, then resume',
      icon: Icons.pause_circle_outline,
      onTap: () => _runTask('Group Control', _demoGroupControl),
    ),
    _DemoEntry(
      section: 'New v1.1 Features',
      category: _DemoCategory.advanced,
      title: 'pauseAll / resumeAll',
      description: 'Pause every running task, then immediately resume all',
      icon: Icons.pause_presentation,
      onTap: () => _runTask('pauseAll + resumeAll', _demoPauseResumeAll),
    ),
    _DemoEntry(
      section: 'New v1.1 Features',
      category: _DemoCategory.advanced,
      title: 'enqueueAll \u2013 Batch Enqueue',
      description: 'Schedule 3 HTTP tasks in one call, no await waterfall',
      icon: Icons.playlist_add,
      onTap: () => _runTask('enqueueAll', _demoEnqueueAll),
    ),
    _DemoEntry(
      section: 'New v1.1 Features',
      category: _DemoCategory.advanced,
      title: 'getTasksByStatus',
      description: 'Query all tasks, group by status, show summary snackbar',
      icon: Icons.filter_list,
      onTap: _demoGetTasksByStatus,
    ),
    _DemoEntry(
      section: 'Advanced API',
      category: _DemoCategory.advanced,
      title: 'TaskGraph (DAG) \u2014 Fan-out + Fan-in',
      description:
          'Two parallel downloads feed one merge step; cycle detection included',
      icon: Icons.account_tree,
      onTap: () => _runTask('TaskGraph', _demoTaskGraph),
    ),
    _DemoEntry(
      section: 'Advanced API',
      category: _DemoCategory.advanced,
      title: 'ObservabilityConfig \u2014 Lifecycle Hooks',
      description:
          'Configure onTaskComplete / onTaskFail callbacks; shows snackbar from hook',
      icon: Icons.visibility,
      onTap: () => _runTask('Observability', _demoObservability),
    ),
    _DemoEntry(
      section: 'Advanced API',
      category: _DemoCategory.advanced,
      title: 'OfflineQueue \u2014 FIFO with Retry',
      description:
          'Queue 3 uploads via OfflineQueue class with exponential backoff',
      icon: Icons.queue,
      onTap: () => _runTask('OfflineQueue', _demoOfflineQueueClass),
    ),
    _DemoEntry(
      section: 'Advanced API',
      category: _DemoCategory.advanced,
      title: 'Request Signing (HMAC-SHA256)',
      description:
          'HttpDownloadWorker.withSigning() \u2014 adds X-Signature header',
      icon: Icons.lock,
      onTap: () => _runTask('Request Signing', _demoRequestSigning),
    ),
    _DemoEntry(
      section: 'Advanced API',
      category: _DemoCategory.advanced,
      title: 'Bandwidth Limit (500\u00a0KB/s)',
      description:
          'Download throttled to 500\u00a0KB/s via withBandwidthLimit()',
      icon: Icons.speed,
      onTap: () => _runTask('Bandwidth Limit', _demoBandwidthLimit),
    ),
    _DemoEntry(
      section: 'Advanced API',
      category: _DemoCategory.advanced,
      title: 'Parallel Upload (3 files, max 2 concurrent)',
      description:
          'ParallelHttpUploadWorker: each file gets its own request with retry',
      icon: Icons.upload_file,
      onTap: () => _runTask('Parallel Upload', _demoParallelUpload),
    ),
    _DemoEntry(
      section: 'Advanced API',
      category: _DemoCategory.advanced,
      title: 'Multi-File Upload (single request)',
      description:
          'MultiUploadWorker: 2 files in one multipart/form-data request',
      icon: Icons.folder_zip,
      onTap: () => _runTask('Multi Upload', _demoMultiUpload),
    ),
  ];

  List<Widget> _buildFilteredList() {
    final filtered = _allEntries.where((e) {
      final catOk =
          _selectedCategory == _DemoCategory.all ||
          e.category == _selectedCategory;
      final qOk = _searchQuery.isEmpty || e.matches(_searchQuery);
      return catOk && qOk;
    }).toList();

    if (filtered.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('No demos found', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ];
    }

    // Group by section preserving insertion order, tracking per-section category
    final bySection = <String, List<_DemoEntry>>{};
    for (final e in filtered) {
      bySection.putIfAbsent(e.section, () => []).add(e);
    }

    final widgets = <Widget>[];
    for (final section in bySection.keys) {
      final entries = bySection[section]!;
      final sectionColor = entries.first.category.color;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: sectionColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                section,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: sectionColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      );
      for (final e in entries) {
        widgets.add(
          _buildDemoCard(
            title: e.title,
            description: e.description,
            icon: e.icon,
            onTap: e.onTap,
            accentColor: e.category.color,
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = true,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        initiallyExpanded: initiallyExpanded,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildDemoCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    final enabled = !_isAnyTaskRunning;
    final cs = Theme.of(context).colorScheme;
    final effectiveAccent = accentColor ?? cs.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withAlpha(80)),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: enabled
                      ? effectiveAccent.withAlpha(20)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: enabled ? effectiveAccent : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: enabled ? effectiveAccent : cs.onSurfaceVariant,
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

  // ── NET Fixes Demo ────────────────────────────────────────────────────────
  /// Demonstrates runtime validation and safety improvements from the NET fixes.
  ///
  /// NET-009/016: HttpSyncWorker validates that requestBody is valid JSON
  ///             before dispatching to the native layer.
  /// NET-018:    HttpUploadWorker rejects total multipart uploads > 512 MB.
  /// NET-027:    timeout is per-attempt (documents via enqueue call).
  /// NET-028:    ParallelHttpUploadWorker throws at construction (not assert).
  Future<void> _demoNetFixes() async {
    final messages = <String>[];

    // ── NET-016: JSON body validation ──────────────────────────────────────
    try {
      HttpSyncWorker(
        url: 'https://httpbin.org/post',
        requestBody: {'fn': Object()}, // non-serialisable
      ).toMap();
      messages.add('NET-016: UNEXPECTED — should have thrown');
    } on ArgumentError catch (e) {
      messages.add('NET-016 ✓ non-serialisable body rejected: ${e.message}');
    }

    // ── NET-028: ParallelHttpUploadWorker runtime validation ────────────────
    try {
      ParallelHttpUploadWorker(
        url: 'https://httpbin.org/post',
        files: const [],
      );
      messages.add('NET-028: UNEXPECTED — should have thrown');
    } on ArgumentError {
      messages.add('NET-028 ✓ empty files list rejected');
    }
    try {
      ParallelHttpUploadWorker(
        url: 'https://httpbin.org/post',
        files: [UploadFile(filePath: '/tmp/a.txt')],
        maxConcurrent: 20,
      );
      messages.add('NET-028: UNEXPECTED — should have thrown');
    } on RangeError {
      messages.add('NET-028 ✓ maxConcurrent=20 rejected (valid range: 1–16)');
    }

    // ── NET-027: per-attempt timeout (schedule a real task to show it works) ─
    await NativeWorkManager.enqueue(
      taskId: 'net-fixes-sync-${DateTime.now().millisecondsSinceEpoch}',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 3)),
      // NET-027: timeout = per attempt; WorkManager may retry multiple times.
      worker: HttpSyncWorker(
        url: 'https://httpbin.org/post',
        requestBody: {
          'demo': 'NET-009/016/027',
          'ts': DateTime.now().toIso8601String(),
        },
        timeout: const Duration(seconds: 20),
      ),
      constraints: const Constraints(requiresNetwork: true),
    );
    messages.add(
      'NET-027/009 ✓ HttpSyncWorker scheduled (timeout=20 s per attempt)',
    );

    _showSnackbar(messages.join(' | '));
  }

  // ── MEDIA Fixes Demo ──────────────────────────────────────────────────────
  /// Demonstrates the Media & Processing bug fixes (MEDIA-001..015).
  ///
  /// - MEDIA-001: BitmapRegionDecoder recycled after use (Android).
  /// - MEDIA-002/003: zero-dimension guard before scale division (iOS/Android).
  /// - MEDIA-004: partial output deleted on failure (PdfWorker/Compression).
  /// - MEDIA-005: ImageProcessWorker writes to temp file then renames (atomic).
  /// - MEDIA-006: PHPhotoLibrary.requestAuthorization on main thread (iOS).
  /// - MEDIA-007: crop with negative width/height throws early (Android).
  /// - MEDIA-008: negative margin clamped to 0 (iOS PdfWorker).
  /// - MEDIA-009: mkdirs failure returns clear error instead of cryptic IOE.
  /// - MEDIA-010: empty strings in imagePaths rejected (iOS PdfWorker).
  /// - MEDIA-011: PdfWorker.swift logs via NativeLogger.d().
  /// - MEDIA-012: WebP error message clarifies UIImage cannot encode WebP.
  /// - MEDIA-013: openOutputStream null-check before !! (Android MoveToShared).
  /// - MEDIA-014: zero-size PDF pages skipped in compress (iOS PdfWorker).
  Future<void> _demoMediaFixes() async {
    final messages = <String>[];
    final tmp = Directory.systemTemp.path;
    final ts = DateTime.now().millisecondsSinceEpoch;

    // ── MEDIA-005: schedule an imageProcess task (uses atomic temp+rename) ──
    try {
      await NativeWorkManager.enqueue(
        taskId: 'media-imgprocess-$ts',
        trigger: TaskTrigger.oneTime(const Duration(seconds: 2)),
        worker: NativeWorker.imageProcess(
          inputPath: '$tmp/demo-in-$ts.jpg',
          outputPath: '$tmp/demo-out-$ts.jpg',
          maxWidth: 1280,
          quality: 80,
        ),
        constraints: const Constraints(),
      );
      messages.add('MEDIA-005 ✓ imageProcess scheduled (atomic write)');
    } catch (e) {
      messages.add('MEDIA-005: schedule error: $e');
    }

    // ── MEDIA-004: schedule a fileCompress task ──────────────────────────────
    try {
      await NativeWorkManager.enqueue(
        taskId: 'media-compress-$ts',
        trigger: TaskTrigger.oneTime(const Duration(seconds: 3)),
        worker: NativeWorker.fileCompress(
          inputPath: '$tmp/demo-in-$ts.jpg',
          outputPath: '$tmp/demo-out-$ts.zip',
        ),
        constraints: const Constraints(),
      );
      messages.add('MEDIA-004 ✓ fileCompress scheduled (cleanup on failure)');
    } catch (e) {
      messages.add('MEDIA-004: schedule error: $e');
    }

    // ── MEDIA-007: non-positive cropRect rejected at parse time (Android) ────
    // This is verified at the native Kotlin level; we show the worker serialises
    // correctly for valid rects (negative width would be passed through Dart
    // layer, then rejected by parseConfig in the worker).
    final cropMap = NativeWorker.imageProcess(
      inputPath: '$tmp/in.jpg',
      outputPath: '$tmp/out.jpg',
      cropRect: const Rect.fromLTWH(10, 20, 300, 200),
    ).toMap();
    final crop = cropMap['cropRect'] as Map<String, dynamic>?;
    if (crop != null && crop['width'] == 300 && crop['height'] == 200) {
      messages.add(
        'MEDIA-007 ✓ valid cropRect serialised: w=${crop['width']} h=${crop['height']}',
      );
    }

    _showSnackbar(messages.join(' | '));
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
    final outputPath = '${Directory.systemTemp.path}/demo-photo-1080p.jpg';

    // Download a real JPEG then process it in a chain
    await NativeWorkManager.beginWith(
          TaskRequest(
            id: 'demo-image-download',
            worker: HttpDownloadWorker(
              url: 'https://httpbin.org/image/jpeg',
              savePath: inputPath,
            ),
            constraints: const Constraints(requiresNetwork: true),
          ),
        )
        .then(
          TaskRequest(
            id: 'demo-image-process',
            worker: NativeWorker.imageProcess(
              inputPath: inputPath,
              outputPath: outputPath,
              maxWidth: 1920,
              maxHeight: 1080,
              quality: 85,
              outputFormat: ImageFormat.jpeg,
            ),
          ),
        )
        .enqueue();
    _showSnackbar('🖼️ Image Processing scheduled (download → resize to 1080p)');
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

  Future<void> _demoCryptoEncrypt() async {
    final inputPath = '${Directory.systemTemp.path}/demo-plaintext.txt';
    final outputPath = '${Directory.systemTemp.path}/demo-plaintext.txt.enc';
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      await inputFile.writeAsString(
        'Sensitive data to encrypt with AES-256-GCM',
      );
    }
    await NativeWorkManager.enqueue(
      taskId: 'demo-crypto-encrypt',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 2)),
      worker: NativeWorker.cryptoEncrypt(
        inputPath: inputPath,
        outputPath: outputPath,
        password: 'dem0SecretPass!',
      ),
    );
    _showSnackbar(
      'Crypto Encrypt scheduled — password stored in secure vault (SC-C-001)',
    );
  }

  Future<void> _demoCryptoDecrypt() async {
    final inputPath = '${Directory.systemTemp.path}/demo-plaintext.txt.enc';
    final outputPath =
        '${Directory.systemTemp.path}/demo-plaintext-decrypted.txt';
    if (!await File(inputPath).exists()) {
      _showSnackbar('Run Crypto Encrypt first to create the .enc file');
      return;
    }
    await NativeWorkManager.enqueue(
      taskId: 'demo-crypto-decrypt',
      trigger: TaskTrigger.oneTime(const Duration(seconds: 2)),
      worker: NativeWorker.cryptoDecrypt(
        inputPath: inputPath,
        outputPath: outputPath,
        password: 'dem0SecretPass!',
      ),
    );
    _showSnackbar('Crypto Decrypt scheduled (SC-C-001)');
  }

  Future<void> _demoFileSystem() async {
    final sourcePath = '${Directory.systemTemp.path}/demo-download.bin';
    final destPath = '${Directory.systemTemp.path}/backup/demo-download.bin';

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      await sourceFile.writeAsString(
        'Content to be copied via FileSystemWorker',
      );
    }

    // Ensure destination directory exists
    await Directory(
      '${Directory.systemTemp.path}/backup',
    ).create(recursive: true);

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
              destinationPath:
                  '${Directory.systemTemp.path}/processing/archive.zip',
            ),
          ),
        )
        // Step 3: Create backup copy
        .then(
          TaskRequest(
            id: 'chain-copy',
            worker: NativeWorker.fileCopy(
              sourcePath: '${Directory.systemTemp.path}/processing/archive.zip',
              destinationPath:
                  '${Directory.systemTemp.path}/backup/archive.zip',
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
    final downloadPath = '${Directory.systemTemp.path}/original-photo.jpg';
    final processedPath = '${Directory.systemTemp.path}/processed-photo.jpg';
    final zipPath = '${Directory.systemTemp.path}/photos.zip';

    // Photo Backup: Download → Process → Compress → Upload → Cleanup (on WiFi)
    await NativeWorkManager.beginWith(
          TaskRequest(
            id: 'chain-fetch-photo',
            worker: HttpDownloadWorker(
              url: 'https://httpbin.org/image/jpeg',
              savePath: downloadPath,
            ),
            constraints: const Constraints(requiresNetwork: true),
          ),
        )
        .then(
          TaskRequest(
            id: 'chain-process-photo',
            worker: NativeWorker.imageProcess(
              inputPath: downloadPath,
              outputPath: processedPath,
              maxWidth: 1920,
              maxHeight: 1080,
              quality: 80,
            ),
          ),
        )
        .then(
          TaskRequest(
            id: 'chain-compress-photos',
            worker: NativeWorker.fileCompress(
              inputPath: processedPath,
              outputPath: zipPath,
              level: CompressionLevel.high,
            ),
          ),
        )
        .then(
          TaskRequest(
            id: 'chain-upload-backup',
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
            id: 'chain-cleanup-temp',
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

  // ═══════════════════════════════════════════════════════════════════════
  // NEW v1.1 FEATURES
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _startParallelDownload() async {
    final taskId = 'v11-parallel-${DateTime.now().millisecondsSinceEpoch}';
    final savePath = '${Directory.systemTemp.path}/v11_parallel_demo.bin';

    setState(() {
      _v11TaskId = taskId;
      _v11Downloading = true;
      _v11Progress = 0;
      _v11Speed = null;
      _v11Eta = null;
      _v11Bytes = null;
      _v11Total = null;
    });

    await NativeWorkManager.enqueue(
      taskId: taskId,
      trigger: const TaskTrigger.oneTime(),
      worker: NativeWorker.parallelHttpDownload(
        url: 'https://httpbin.org/bytes/524288', // 512 KB
        savePath: savePath,
        numChunks: 4,
      ),
      constraints: const Constraints(requiresNetwork: true),
    );
    _showSnackbar('⬇️ Parallel download started (4 chunks)');
  }

  Future<void> _cancelParallelDownload() async {
    if (_v11TaskId != null) {
      await NativeWorkManager.cancel(taskId: _v11TaskId!);
    }
    if (mounted) setState(() => _v11Downloading = false);
    _showSnackbar('🛑 Parallel download cancelled');
  }

  Future<void> _demoSkipExisting() async {
    final taskId = 'v11-skip-${DateTime.now().millisecondsSinceEpoch}';
    final savePath = '${Directory.systemTemp.path}/v11_skip_demo.txt';
    // Pre-create the file so the worker will skip it
    File(savePath).writeAsStringSync('pre-existing content — must not change');

    await NativeWorkManager.enqueue(
      taskId: taskId,
      trigger: const TaskTrigger.oneTime(),
      worker: HttpDownloadWorker(
        url: 'https://httpbin.org/get',
        savePath: savePath,
        skipExisting: true,
      ),
      constraints: const Constraints(requiresNetwork: true),
    );
    _showSnackbar(
      '⏭️ skipExisting task scheduled\n'
      'The file already exists — worker will skip the download.',
    );
  }

  Future<void> _demoGroupControl() async {
    const tag = 'v11-group';
    final base = DateTime.now().millisecondsSinceEpoch;

    // Enqueue two long-delayed tasks so we can pause them
    await NativeWorkManager.enqueueAll([
      EnqueueRequest(
        taskId: 'v11-group-a-$base',
        trigger: const TaskTrigger.oneTime(Duration(minutes: 5)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        tag: tag,
        constraints: const Constraints(requiresNetwork: true),
      ),
      EnqueueRequest(
        taskId: 'v11-group-b-$base',
        trigger: const TaskTrigger.oneTime(Duration(minutes: 5)),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/2',
        ),
        tag: tag,
        constraints: const Constraints(requiresNetwork: true),
      ),
    ]);

    await NativeWorkManager.pauseByTag(tag: tag);
    _showSnackbar('⏸️ Group "$tag" paused (2 tasks)');

    await Future<void>.delayed(const Duration(seconds: 1));
    await NativeWorkManager.resumeByTag(tag: tag);
    _showSnackbar('▶️ Group "$tag" resumed');

    await NativeWorkManager.cancelByTag(tag: tag);
  }

  Future<void> _demoPauseResumeAll() async {
    await NativeWorkManager.pauseAll();
    _showSnackbar('⏸️ All tasks paused');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await NativeWorkManager.resumeAll();
    _showSnackbar('▶️ All tasks resumed');
  }

  Future<void> _demoEnqueueAll() async {
    final base = DateTime.now().millisecondsSinceEpoch;
    final results = await NativeWorkManager.enqueueAll([
      EnqueueRequest(
        taskId: 'batch-1-$base',
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/1',
        ),
        constraints: const Constraints(requiresNetwork: true),
      ),
      EnqueueRequest(
        taskId: 'batch-2-$base',
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/2',
        ),
        constraints: const Constraints(requiresNetwork: true),
      ),
      EnqueueRequest(
        taskId: 'batch-3-$base',
        trigger: const TaskTrigger.oneTime(),
        worker: HttpRequestWorker(
          url: 'https://jsonplaceholder.typicode.com/posts/3',
        ),
        constraints: const Constraints(requiresNetwork: true),
      ),
    ]);

    final accepted = results.where((r) => r == ScheduleResult.accepted).length;
    _showSnackbar('📋 enqueueAll: $accepted/3 tasks accepted');
  }

  Future<void> _demoGetTasksByStatus() async {
    final all = await NativeWorkManager.allTasks();
    final grouped = <String, int>{};
    for (final t in all) {
      grouped[t.status] = (grouped[t.status] ?? 0) + 1;
    }
    if (grouped.isEmpty) {
      _showSnackbar('📊 No tasks in store (enqueue some first)');
      return;
    }
    final summary = grouped.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('  ·  ');
    _showSnackbar('📊 Tasks by status — $summary');
  }

  // ── Rich-progress helpers ─────────────────────────────────────────────

  String _formatSpeed(double bps) {
    if (bps >= 1024 * 1024) {
      return '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (bps >= 1024) {
      return '${(bps / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${bps.toStringAsFixed(0)} B/s';
  }

  String _formatEta(Duration eta) {
    if (eta.inSeconds < 60) return '${eta.inSeconds}s';
    return '${eta.inMinutes}m ${eta.inSeconds % 60}s';
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UPLOAD QUEUE (existing)
  // ═══════════════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════════════
  // ADVANCED API DEMOS
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _demoTaskGraph() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final tmp = Directory.systemTemp.path;

    // Build a small DAG:  dlA ─┐
    //                           ├─▶ merge
    //                    dlB ─┘
    final graph = TaskGraph(id: 'demo-graph-$ts')
      ..add(
        TaskNode(
          id: 'dl-a-$ts',
          worker: HttpDownloadWorker(
            url: 'https://httpbin.org/bytes/1024',
            savePath: '$tmp/graph-a-$ts.bin',
          ),
        ),
      )
      ..add(
        TaskNode(
          id: 'dl-b-$ts',
          worker: HttpDownloadWorker(
            url: 'https://httpbin.org/bytes/1024',
            savePath: '$tmp/graph-b-$ts.bin',
          ),
        ),
      )
      ..add(
        TaskNode(
          id: 'merge-$ts',
          worker: HttpRequestWorker(url: 'https://httpbin.org/get'),
          dependsOn: ['dl-a-$ts', 'dl-b-$ts'],
        ),
      );

    final exec = await NativeWorkManager.enqueueGraph(graph);
    _showSnackbar('🔀 TaskGraph enqueued — waiting for result…');

    exec.result.then((result) {
      if (mounted) {
        _showSnackbar(
          result.success
              ? '✅ DAG done — ${result.completedCount} nodes completed'
              : '❌ DAG failed — ${result.failedNodes}',
        );
      }
    });
  }

  Future<void> _demoObservability() async {
    // Configure lifecycle hooks — they fire for every subsequent task.
    NativeWorkManager.configure(
      observability: ObservabilityConfig(
        onTaskComplete: (event) {
          if (mounted) {
            _showSnackbar('👁 [hook] completed: ${event.taskId}');
          }
        },
        onTaskFail: (event) {
          if (mounted) {
            _showSnackbar('👁 [hook] failed: ${event.taskId}');
          }
        },
      ),
    );

    // Enqueue a quick task so the hook fires visibly.
    final ts = DateTime.now().millisecondsSinceEpoch;
    await NativeWorkManager.enqueue(
      taskId: 'obs-task-$ts',
      trigger: const TaskTrigger.oneTime(),
      worker: HttpRequestWorker(url: 'https://httpbin.org/get'),
      constraints: const Constraints(requiresNetwork: true),
    );

    _showSnackbar('👁 Observability hooks configured — task enqueued');

    // Reset hooks after 30 s to avoid spamming subsequent demos.
    Future.delayed(const Duration(seconds: 30), () {
      NativeWorkManager.configure();
    });
  }

  Future<void> _demoOfflineQueueClass() async {
    final tmp = Directory.systemTemp.path;

    // Create 3 small dummy files.
    for (var i = 1; i <= 3; i++) {
      final f = File('$tmp/oq-file-$i.txt');
      if (!await f.exists()) await f.writeAsString('OfflineQueue demo file $i');
    }

    final queue = OfflineQueue(
      id: 'demo-oq-${DateTime.now().millisecondsSinceEpoch}',
      defaultRetryPolicy: const OfflineRetryPolicy(
        maxRetries: 3,
        requiresNetwork: true,
      ),
    );
    queue.start();

    for (var i = 1; i <= 3; i++) {
      await queue.enqueue(
        QueueEntry(
          taskId: 'oq-upload-$i',
          worker: HttpUploadWorker(
            url: 'https://httpbin.org/post',
            filePath: '$tmp/oq-file-$i.txt',
          ),
        ),
      );
    }

    _showSnackbar(
      '📥 OfflineQueue: ${queue.pendingCount} items queued (retry × 3 on error)',
    );
  }

  Future<void> _demoRequestSigning() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final worker =
        HttpDownloadWorker(
          url: 'https://httpbin.org/bytes/512',
          savePath: '${Directory.systemTemp.path}/signed-$ts.bin',
        ).withSigning(
          const RequestSigning(
            secretKey: 'demo-secret-key-for-testing',
            headerName: 'X-Signature',
            includeTimestamp: true,
          ),
        );

    await NativeWorkManager.enqueue(
      taskId: 'signed-dl-$ts',
      trigger: const TaskTrigger.oneTime(),
      worker: worker,
      constraints: const Constraints(requiresNetwork: true),
    );
    _showSnackbar(
      '🔐 Signed download enqueued (HMAC-SHA256, X-Signature header)',
    );
  }

  Future<void> _demoBandwidthLimit() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final worker = HttpDownloadWorker(
      url: 'https://httpbin.org/bytes/524288', // 512 KB
      savePath: '${Directory.systemTemp.path}/throttled-$ts.bin',
    ).withBandwidthLimit(500 * 1024); // 500 KB/s

    await NativeWorkManager.enqueue(
      taskId: 'throttled-dl-$ts',
      trigger: const TaskTrigger.oneTime(),
      worker: worker,
      constraints: const Constraints(requiresNetwork: true),
    );
    _showSnackbar('🐌 Throttled download enqueued (max 500 KB/s)');
  }

  Future<void> _demoParallelUpload() async {
    final tmp = Directory.systemTemp.path;
    final ts = DateTime.now().millisecondsSinceEpoch;

    // Create 3 small files.
    for (var i = 1; i <= 3; i++) {
      final f = File('$tmp/par-up-$i-$ts.txt');
      await f.writeAsString('parallel upload demo file $i (ts=$ts)');
    }

    await NativeWorkManager.enqueue(
      taskId: 'par-upload-$ts',
      trigger: const TaskTrigger.oneTime(),
      worker: ParallelHttpUploadWorker(
        url: 'https://httpbin.org/post',
        files: [
          UploadFile(filePath: '$tmp/par-up-1-$ts.txt'),
          UploadFile(filePath: '$tmp/par-up-2-$ts.txt'),
          UploadFile(filePath: '$tmp/par-up-3-$ts.txt'),
        ],
        maxConcurrent: 2,
        maxRetries: 1,
      ),
      constraints: const Constraints(requiresNetwork: true),
    );
    _showSnackbar('📤 ParallelHttpUploadWorker: 3 files (max 2 concurrent)');
  }

  Future<void> _demoMultiUpload() async {
    final tmp = Directory.systemTemp.path;
    final ts = DateTime.now().millisecondsSinceEpoch;

    final f1 = File('$tmp/multi-up-1-$ts.txt');
    final f2 = File('$tmp/multi-up-2-$ts.txt');
    await f1.writeAsString('multi-upload file 1');
    await f2.writeAsString('multi-upload file 2');

    await NativeWorkManager.enqueue(
      taskId: 'multi-upload-$ts',
      trigger: const TaskTrigger.oneTime(),
      worker: NativeWorker.multiUpload(
        url: 'https://httpbin.org/post',
        files: [
          UploadFile(filePath: f1.path, fieldName: 'files'),
          UploadFile(filePath: f2.path, fieldName: 'files'),
        ],
        additionalFields: {'source': 'demo'},
      ),
      constraints: const Constraints(requiresNetwork: true),
    );
    _showSnackbar('📦 MultiUploadWorker: 2 files in 1 multipart request');
  }
}
