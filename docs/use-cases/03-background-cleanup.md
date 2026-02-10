# Use Case: Background Cleanup

**Difficulty:** Beginner
**Platform:** Android + iOS
**Features:** Periodic triggers, Dart workers, File operations

---

## Problem

Your app needs to periodically clean up temporary files, caches, or old data in the background. The cleanup should:
- Run automatically without user intervention
- Execute even when app is closed
- Use Dart code to access app-specific logic
- Not interfere with foreground operations

Common scenarios:
- Cache cleanup (images, videos, downloads)
- Old log file removal
- Database maintenance
- Temporary file cleanup
- Analytics data

 purging

---

## Solution

Use `TaskTrigger.periodic()` with `DartWorker` to run custom Dart cleanup logic.

---

## Complete Example

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:path_provider/path_provider.dart';

/// Background cleanup callback
///
/// This function runs in a background isolate.
/// Keep it lightweight and avoid heavy UI operations.
Future<bool> cleanupCallback(Map<String, dynamic>? input) async {
  print('🧹 Starting background cleanup...');

  try {
    // 1. Clean temporary files older than 7 days
    await _cleanOldFiles(
      await getTemporaryDirectory(),
      maxAge: Duration(days: 7),
    );

    // 2. Clean cache files older than 30 days
    await _cleanOldFiles(
      Directory('${(await getApplicationDocumentsDirectory()).path}/cache'),
      maxAge: Duration(days: 30),
    );

    // 3. Trim database (hypothetical)
    await _trimDatabase(maxEntries: 1000);

    // 4. Clean old logs
    await _cleanOldLogs(maxAge: Duration(days: 14));

    print('✅ Cleanup completed successfully');
    return true;  // Success
  } catch (e) {
    print('❌ Cleanup failed: $e');
    return false;  // Failure
  }
}

/// Clean files older than maxAge from directory
Future<void> _cleanOldFiles(Directory dir, {required Duration maxAge}) async {
  if (!await dir.exists()) return;

  final now = DateTime.now();
  final cutoffTime = now.subtract(maxAge);

  try {
    final files = await dir.list().toList();

    for (final entity in files) {
      if (entity is File) {
        final stat = await entity.stat();

        if (stat.modified.isBefore(cutoffTime)) {
          await entity.delete();
          print('🗑️ Deleted: ${entity.path}');
        }
      }
    }
  } catch (e) {
    print('⚠️ Error cleaning ${dir.path}: $e');
  }
}

/// Trim database to max entries (example)
Future<void> _trimDatabase({required int maxEntries}) async {
  // Example: Delete oldest entries if count > maxEntries
  // final db = await openDatabase('app.db');
  // final count = await db.rawQuery('SELECT COUNT(*) FROM logs');
  // if (count > maxEntries) {
  //   await db.delete('logs',
  //     where: 'id NOT IN (SELECT id FROM logs ORDER BY timestamp DESC LIMIT ?)',
  //     whereArgs: [maxEntries],
  //   );
  // }
  print('📊 Database trimmed to $maxEntries entries');
}

/// Clean old log files
Future<void> _cleanOldLogs({required Duration maxAge}) async {
  final logsDir = Directory(
    '${(await getApplicationDocumentsDirectory()).path}/logs',
  );

  if (!await logsDir.exists()) return;

  await _cleanOldFiles(logsDir, maxAge: maxAge);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize with Dart worker
  await NativeWorkManager.initialize(
    dartWorkers: {
      'cleanup': cleanupCallback,  // Register cleanup callback
    },
  );

  // Schedule periodic cleanup
  await schedulePeriodicCleanup();

  runApp(MyApp());
}

/// Schedule daily cleanup task
Future<void> schedulePeriodicCleanup() async {
  final result = await NativeWorkManager.enqueue(
    // Unique task ID
    taskId: 'daily-cleanup',

    // Run every 24 hours
    trigger: TaskTrigger.periodic(const Duration(hours: 24)),

    // Use Dart worker to execute cleanup callback
    worker: DartWorker(
      callbackId: 'cleanup',
      input: {
        'max_cache_age_days': 30,
        'max_temp_age_days': 7,
        'max_log_age_days': 14,
      },
    ),

    // Only run when device is idle and charging (optional)
    constraints: Constraints(
      deviceIdle: true,      // Don't interfere with user
      charging: true,        // Device is charging
    ),

    // Replace existing cleanup task
    existingPolicy: ExistingTaskPolicy.replace,

    // Tag for easy management
    tag: 'maintenance',
  );

  if (result == ScheduleResult.accepted) {
    print('✅ Daily cleanup scheduled');
  } else {
    print('⚠️ Cleanup scheduling rejected by OS');
  }
}

/// Manually trigger cleanup (for testing)
Future<void> triggerManualCleanup() async {
  final result = await NativeWorkManager.enqueue(
    taskId: 'manual-cleanup-${DateTime.now().millisecondsSinceEpoch}',
    trigger: TaskTrigger.oneTime(),
    worker: DartWorker(callbackId: 'cleanup'),
    tag: 'maintenance',
  );

  print(result == ScheduleResult.accepted
      ? '✅ Manual cleanup started'
      : '❌ Manual cleanup failed');
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Background Cleanup Example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cleaning_services, size: 80, color: Colors.blue),
              SizedBox(height: 32),
              Text(
                'Automatic Cleanup',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Runs daily at optimal time',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: triggerManualCleanup,
                icon: Icon(Icons.play_arrow),
                label: Text('Trigger Now (Test)'),
              ),
              SizedBox(height: 16),
              _CleanupMonitor(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget to monitor cleanup events
class _CleanupMonitor extends StatefulWidget {
  @override
  State<_CleanupMonitor> createState() => _CleanupMonitorState();
}

class _CleanupMonitorState extends State<_CleanupMonitor> {
  String _lastCleanup = 'Never';
  String _status = 'Idle';

  @override
  void initState() {
    super.initState();

    // Listen to cleanup events
    NativeWorkManager.events.listen((event) {
      if (event.taskId.contains('cleanup')) {
        setState(() {
          _lastCleanup = DateTime.now().toString().substring(0, 16);
          _status = event.success ? '✅ Success' : '❌ Failed';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        children: [
          Text('Last Cleanup: $_lastCleanup'),
          SizedBox(height: 8),
          Text('Status: $_status'),
        ],
      ),
    );
  }
}
```

---

## Expected Behavior

### Android

- **First run:** ~15 minutes after scheduling
- **Subsequent runs:** Every 24 hours (±15 minutes)
- **Device idle constraint:** Waits until screen off + no movement
- **Charging constraint:** Waits until plugged in
- **Doze mode:** Deferred to maintenance window

### iOS

- **First run:** System decides (usually within hours)
- **Subsequent runs:** Opportunistic, not guaranteed every 24 hours
- **Low Power Mode:** Tasks deferred
- **Execution limit:** 30 seconds max

---

## Platform Considerations

### Android

**Optimal cleanup schedule:**
```dart
// Run daily at night when device is charging
constraints: Constraints(
  deviceIdle: true,   // Screen off, no user activity
  charging: true,     // Plugged in
)

// Or less restrictive:
constraints: Constraints(
  deviceIdle: true,   // Just wait for idle
)
```

### iOS

**Time limit warning:**
Dart workers have 30-second execution limit. Keep cleanup fast:
```dart
// ✅ Good - Fast operations
- Delete files: <100 files per run
- Database cleanup: Simple queries
- Log trimming: Small files

// ❌ Risky - May timeout
- Processing large files
- Complex database operations
- Network calls
```

---

## Common Pitfalls

### 1. ❌ Slow Cleanup Operations

```dart
// ❌ This might timeout on iOS
Future<bool> slowCleanup(Map<String, dynamic>? input) async {
  // Processing 10,000 files - too slow!
  for (final file in await getAllFiles()) {
    await processFile(file);  // 30+ seconds
  }
  return true;
}

// ✅ Batch processing
Future<bool> fastCleanup(Map<String, dynamic>? input) async {
  // Process only recent files
  final files = await getRecentFiles(limit: 100);
  for (final file in files) {
    await processFile(file);
  }
  return true;
}
```

### 2. ❌ Not Registering Callback

```dart
// ❌ Forgot to register
await NativeWorkManager.initialize();
await NativeWorkManager.enqueue(
  taskId: 'cleanup',
  worker: DartWorker(callbackId: 'cleanup'),  // Not registered!
);

// ✅ Register callback
await NativeWorkManager.initialize(
  dartWorkers: {
    'cleanup': cleanupCallback,  // Register first
  },
);
```

### 3. ❌ Deleting Active Files

```dart
// ❌ Might delete files in use
await _cleanOldFiles(
  await getApplicationDocumentsDirectory(),  // Entire app directory!
  maxAge: Duration(days: 7),
);

// ✅ Only clean specific directories
await _cleanOldFiles(
  Directory('${appDir.path}/cache'),  // Just cache
  maxAge: Duration(days: 7),
);
await _cleanOldFiles(
  Directory('${appDir.path}/temp'),   // Just temp
  maxAge: Duration(days: 1),
);
```

---

## Advanced: Selective Cleanup

Clean only when storage is low:

```dart
import 'package:disk_space/disk_space.dart';

Future<bool> smartCleanup(Map<String, dynamic>? input) async {
  // Check available storage
  final freeSpace = await DiskSpace.getFreeDiskSpace;

  if (freeSpace! < 100) {  // Less than 100MB free
    print('⚠️ Low storage detected, running aggressive cleanup');

    // Aggressive cleanup
    await _cleanOldFiles(cacheDir, maxAge: Duration(days: 7));
    await _cleanOldFiles(tempDir, maxAge: Duration(hours: 24));
  } else if (freeSpace < 500) {  // Less than 500MB
    print('📊 Moderate storage, running normal cleanup');

    // Normal cleanup
    await _cleanOldFiles(cacheDir, maxAge: Duration(days: 30));
  } else {
    print('✅ Storage OK, skipping cleanup');
  }

  return true;
}
```

---

## Related

- **Periodic sync:** [Periodic API Sync](01-periodic-api-sync.md)
- **Dart + Native mix:** [Hybrid Workflow](05-hybrid-workflow.md)
- **API Reference:** See main [README.md](../../README.md)

---

## Checklist

- [ ] Register Dart worker in `initialize()`
- [ ] Keep cleanup logic under 30 seconds (iOS limit)
- [ ] Use `deviceIdle` and `charging` constraints
- [ ] Only clean specific directories (not entire app folder)
- [ ] Test with manual trigger first
- [ ] Verify files are actually deleted
- [ ] Check iOS doesn't timeout (30s limit)
- [ ] Handle errors gracefully (return false)

---

*Last updated: 2026-01-27*
