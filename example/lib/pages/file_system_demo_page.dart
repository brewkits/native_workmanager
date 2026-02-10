import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:path_provider/path_provider.dart';

/// Dedicated page for FileSystemWorker demonstrations.
///
/// Shows all 5 file system operations:
/// - Copy files/directories
/// - Move files/directories
/// - Delete files/directories
/// - List directory contents
/// - Create directories
class FileSystemDemoPage extends StatefulWidget {
  const FileSystemDemoPage({super.key});

  @override
  State<FileSystemDemoPage> createState() => _FileSystemDemoPageState();
}

class _FileSystemDemoPageState extends State<FileSystemDemoPage> {
  final List<String> _logs = [];
  String? _tempDir;
  bool _isReady = false;
  StreamSubscription<TaskEvent>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _setupTestEnvironment();

    // Listen to task events - filter for file system tasks only
    _eventSubscription = NativeWorkManager.events
        .where((event) => event.taskId.startsWith('fs-'))
        .listen((event) {
      if (mounted) {
        _addLog(
          '${event.success ? "✅" : "❌"} ${event.taskId}: ${event.message}',
        );

        // Show result data if available
        if (event.resultData != null) {
          final data = event.resultData!;
          if (data.containsKey('fileCount')) {
            _addLog('   → ${data['fileCount']} files affected');
          }
          if (data.containsKey('totalSize')) {
            _addLog(
              '   → Total size: ${_formatBytes(data['totalSize'] as int)}',
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _setupTestEnvironment() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _tempDir = tempDir.path;

      // Create test directory structure
      final testDir = Directory('${_tempDir!}/file_system_demo');
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
      await testDir.create(recursive: true);

      // Create test files
      await File('${testDir.path}/file1.txt').writeAsString('Test content 1');
      await File('${testDir.path}/file2.txt').writeAsString('Test content 2');
      await File('${testDir.path}/file3.txt').writeAsString('Test content 3');

      // Create subdirectory
      final subDir = Directory('${testDir.path}/subdir');
      await subDir.create();
      await File(
        '${subDir.path}/subfile.txt',
      ).writeAsString('Subdirectory file');

      setState(() {
        _isReady = true;
      });

      _addLog('✅ Test environment ready at: ${testDir.path}');
    } catch (e) {
      _addLog('❌ Setup failed: $e');
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, '${_formatTime(DateTime.now())} $message');
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ═══════════════════════════════════════════════════════════════
  // FILE SYSTEM OPERATIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> _demoCopyFile() async {
    if (!_isReady) return;

    await NativeWorkManager.enqueue(
      taskId: 'fs-copy-file',
      trigger: TaskTrigger.oneTime(),
      worker: NativeWorker.fileCopy(
        sourcePath: '$_tempDir/file_system_demo/file1.txt',
        destinationPath: '$_tempDir/file_system_demo/file1_copy.txt',
        overwrite: true,
      ),
    );
    _addLog('📤 Copy file scheduled');
  }

  Future<void> _demoCopyDirectory() async {
    if (!_isReady) return;

    await NativeWorkManager.enqueue(
      taskId: 'fs-copy-dir',
      trigger: TaskTrigger.oneTime(),
      worker: NativeWorker.fileCopy(
        sourcePath: '$_tempDir/file_system_demo/subdir',
        destinationPath: '$_tempDir/file_system_demo/subdir_copy',
        recursive: true,
      ),
    );
    _addLog('📤 Copy directory scheduled');
  }

  Future<void> _demoMoveFile() async {
    if (!_isReady) return;

    await NativeWorkManager.enqueue(
      taskId: 'fs-move-file',
      trigger: TaskTrigger.oneTime(),
      worker: NativeWorker.fileMove(
        sourcePath: '$_tempDir/file_system_demo/file2.txt',
        destinationPath: '$_tempDir/file_system_demo/moved/file2.txt',
        overwrite: true,
      ),
    );
    _addLog('📤 Move file scheduled');
  }

  Future<void> _demoDeleteFile() async {
    if (!_isReady) return;

    await NativeWorkManager.enqueue(
      taskId: 'fs-delete-file',
      trigger: TaskTrigger.oneTime(),
      worker: NativeWorker.fileDelete(
        path: '$_tempDir/file_system_demo/file3.txt',
      ),
    );
    _addLog('📤 Delete file scheduled');
  }

  Future<void> _demoListFiles() async {
    if (!_isReady) return;

    await NativeWorkManager.enqueue(
      taskId: 'fs-list-files',
      trigger: TaskTrigger.oneTime(),
      worker: NativeWorker.fileList(
        path: '$_tempDir/file_system_demo',
        recursive: true,
      ),
    );
    _addLog('📤 List files scheduled');
  }

  Future<void> _demoListWithPattern() async {
    if (!_isReady) return;

    await NativeWorkManager.enqueue(
      taskId: 'fs-list-pattern',
      trigger: TaskTrigger.oneTime(),
      worker: NativeWorker.fileList(
        path: '$_tempDir/file_system_demo',
        pattern: '*.txt',
        recursive: true,
      ),
    );
    _addLog('📤 List *.txt files scheduled');
  }

  Future<void> _demoCreateDirectory() async {
    if (!_isReady) return;

    await NativeWorkManager.enqueue(
      taskId: 'fs-mkdir',
      trigger: TaskTrigger.oneTime(),
      worker: NativeWorker.fileMkdir(
        path: '$_tempDir/file_system_demo/new_dir/nested/deep',
        createParents: true,
      ),
    );
    _addLog('📤 Create directory scheduled');
  }

  Future<void> _demoCompleteWorkflow() async {
    if (!_isReady) return;

    // Complete workflow: Create → Copy → Move → List → Cleanup
    await NativeWorkManager.beginWith(
          TaskRequest(
            id: 'workflow-mkdir',
            worker: NativeWorker.fileMkdir(
              path: '$_tempDir/file_system_demo/workflow',
            ),
          ),
        )
        .then(
          TaskRequest(
            id: 'workflow-copy',
            worker: NativeWorker.fileCopy(
              sourcePath: '$_tempDir/file_system_demo/file1.txt',
              destinationPath: '$_tempDir/file_system_demo/workflow/file1.txt',
            ),
          ),
        )
        .then(
          TaskRequest(
            id: 'workflow-list',
            worker: NativeWorker.fileList(
              path: '$_tempDir/file_system_demo/workflow',
            ),
          ),
        )
        .then(
          TaskRequest(
            id: 'workflow-move',
            worker: NativeWorker.fileMove(
              sourcePath: '$_tempDir/file_system_demo/workflow/file1.txt',
              destinationPath:
                  '$_tempDir/file_system_demo/workflow/moved_file1.txt',
            ),
          ),
        )
        .then(
          TaskRequest(
            id: 'workflow-cleanup',
            worker: NativeWorker.fileDelete(
              path: '$_tempDir/file_system_demo/workflow',
              recursive: true,
            ),
          ),
        )
        .enqueue();

    _addLog('📤 Complete workflow scheduled (5 steps)');
  }

  Future<void> _resetEnvironment() async {
    await _setupTestEnvironment();
    _addLog('🔄 Test environment reset');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FileSystemWorker Demo'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetEnvironment,
            tooltip: 'Reset environment',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isReady
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.errorContainer,
            child: Text(
              _isReady
                  ? '✅ Environment Ready - Test files created'
                  : '⏳ Setting up test environment...',
              style: TextStyle(
                color: _isReady
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Demo Buttons
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'File Operations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                _buildDemoButton(
                  title: 'Copy File',
                  description: 'Copy file1.txt → file1_copy.txt',
                  icon: Icons.content_copy,
                  onPressed: _demoCopyFile,
                ),
                _buildDemoButton(
                  title: 'Copy Directory',
                  description: 'Copy subdir/ → subdir_copy/ (recursive)',
                  icon: Icons.folder_copy,
                  onPressed: _demoCopyDirectory,
                ),
                _buildDemoButton(
                  title: 'Move File',
                  description: 'Move file2.txt → moved/file2.txt',
                  icon: Icons.drive_file_move,
                  onPressed: _demoMoveFile,
                ),
                _buildDemoButton(
                  title: 'Delete File',
                  description: 'Delete file3.txt',
                  icon: Icons.delete,
                  onPressed: _demoDeleteFile,
                  color: Colors.red,
                ),

                const SizedBox(height: 24),
                Text(
                  'Directory Operations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                _buildDemoButton(
                  title: 'List Files',
                  description: 'List all files in demo directory',
                  icon: Icons.list,
                  onPressed: _demoListFiles,
                ),
                _buildDemoButton(
                  title: 'List with Pattern',
                  description: 'List only *.txt files',
                  icon: Icons.filter_list,
                  onPressed: _demoListWithPattern,
                ),
                _buildDemoButton(
                  title: 'Create Directory',
                  description: 'Create nested/deep directory structure',
                  icon: Icons.create_new_folder,
                  onPressed: _demoCreateDirectory,
                ),

                const SizedBox(height: 24),
                Text(
                  'Complete Workflow',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                _buildDemoButton(
                  title: 'Run Complete Workflow',
                  description: 'Mkdir → Copy → List → Move → Delete (5 steps)',
                  icon: Icons.all_inclusive,
                  onPressed: _demoCompleteWorkflow,
                  color: Colors.green,
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // Logs Section
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(
                        Icons.terminal,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Activity Log',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.clear_all, size: 20),
                        onPressed: () {
                          setState(() {
                            _logs.clear();
                          });
                        },
                        tooltip: 'Clear logs',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          _logs[index],
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoButton({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          icon,
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.play_arrow),
        onTap: _isReady ? onPressed : null,
        enabled: _isReady,
      ),
    );
  }
}
