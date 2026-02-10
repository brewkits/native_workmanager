# Use Case: File Upload with Retry

**Difficulty:** Intermediate
**Platform:** Android + iOS
**Features:** One-time triggers, File upload, Error handling, Retry logic, Task tagging

---

## Problem

Your app needs to upload files (photos, documents, videos) to a server in the background. The upload should:
- Continue even if app is closed
- Retry automatically on failure
- Only upload when network is available
- Handle large files efficiently
- Support batch uploads with tags

Common scenarios:
- Photo backup apps
- Document sharing
- Video uploads
- Log file submissions
- Crash report uploads

---

## Solution

Use `TaskTrigger.oneTime()` with `NativeWorker.httpUpload()` and implement retry logic using task tags.

### Key Components

1. **Native Worker** - Upload files without Flutter Engine overhead
2. **One-Time Trigger** - Execute once per file
3. **Network Constraint** - Wait for connectivity
4. **Task Tags** - Group related uploads for batch management
5. **Event Monitoring** - Track success/failure and implement retries

---

## Complete Example

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize work manager
  await NativeWorkManager.initialize();

  // Monitor upload events
  UploadManager.startMonitoring();

  runApp(MyApp());
}

class UploadManager {
  static const String uploadTag = 'uploads';
  static const int maxRetries = 3;
  static final Map<String, int> _retryCount = {};

  /// Upload a single file
  static Future<void> uploadFile(File file) async {
    final taskId = 'upload_${file.path.hashCode}';

    final result = await NativeWorkManager.enqueue(
      taskId: taskId,

      // Execute as soon as conditions are met
      trigger: TaskTrigger.oneTime(),

      // Native HTTP upload worker
      worker: NativeWorker.httpUpload(
        url: 'https://api.example.com/upload',
        filePath: file.path,
        headers: {
          'Authorization': 'Bearer YOUR_TOKEN',
          'Content-Type': 'multipart/form-data',
        },
        // Optional: Custom field name (default is 'file')
        fieldName: 'photo',
      ),

      // Wait for network, battery not critically low
      constraints: Constraints(
        networkType: NetworkType.connected,
        batteryNotLow: true,
      ),

      // Don't reschedule if already exists
      existingPolicy: ExistingTaskPolicy.keep,

      // Tag for batch operations
      tag: uploadTag,
    );

    // Initialize retry counter
    _retryCount[taskId] = 0;

    if (result == ScheduleResult.accepted) {
      print('✅ Upload scheduled: ${file.path}');
    } else {
      print('❌ Upload rejected: ${file.path}');
    }
  }

  /// Upload multiple files at once
  static Future<void> uploadBatch(List<File> files) async {
    for (final file in files) {
      await uploadFile(file);
    }
    print('📦 Scheduled ${files.length} uploads');
  }

  /// Cancel all pending uploads
  static Future<void> cancelAllUploads() async {
    await NativeWorkManager.cancelByTag(uploadTag);
    _retryCount.clear();
    print('🛑 All uploads cancelled');
  }

  /// Get count of pending uploads
  static Future<int> getPendingUploadCount() async {
    final tasks = await NativeWorkManager.getTasksByTag(uploadTag);
    return tasks.length;
  }

  /// Monitor upload events and implement retry logic
  static void startMonitoring() {
    NativeWorkManager.events.listen((event) {
      // Only process upload events
      if (event.taskId.startsWith('upload_')) {
        if (event.success) {
          _handleUploadSuccess(event);
        } else {
          _handleUploadFailure(event);
        }
      }
    });
  }

  static void _handleUploadSuccess(TaskEvent event) {
    print('✅ Upload completed: ${event.taskId}');

    // Clean up retry counter
    _retryCount.remove(event.taskId);

    // Notify UI
    // You can use a StreamController or StateNotifier here
  }

  static void _handleUploadFailure(TaskEvent event) {
    final taskId = event.taskId;
    final currentRetries = _retryCount[taskId] ?? 0;

    print('❌ Upload failed: $taskId (${event.message})');

    if (currentRetries < maxRetries) {
      // Retry with exponential backoff
      _retryCount[taskId] = currentRetries + 1;
      _scheduleRetry(taskId, currentRetries + 1);
    } else {
      // Max retries reached
      print('⛔ Upload failed permanently: $taskId');
      _retryCount.remove(taskId);

      // Notify user or move to failed queue
      _handlePermanentFailure(taskId);
    }
  }

  static void _scheduleRetry(String taskId, int retryCount) {
    // Exponential backoff: 30s, 60s, 120s
    final delaySeconds = 30 * (1 << (retryCount - 1));

    print('🔄 Retry #$retryCount scheduled in ${delaySeconds}s');

    // Re-schedule with delay
    Future.delayed(Duration(seconds: delaySeconds), () async {
      // Extract file path from taskId (you might need better mapping)
      // For this example, we'll reschedule the same task
      await NativeWorkManager.enqueue(
        taskId: '$taskId-retry-$retryCount',
        trigger: TaskTrigger.oneTime(
          initialDelay: Duration(seconds: delaySeconds),
        ),
        worker: NativeWorker.httpUpload(
          url: 'https://api.example.com/upload',
          filePath: '/path/from/mapping',  // Get from storage
          headers: {
            'Authorization': 'Bearer YOUR_TOKEN',
          },
        ),
        constraints: Constraints(
          networkType: NetworkType.connected,
          batteryNotLow: true,
        ),
        tag: uploadTag,
      );
    });
  }

  static void _handlePermanentFailure(String taskId) {
    // Save to failed uploads database
    // Show notification to user
    // Or move file to failed queue
  }
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _pendingUploads = 0;

  @override
  void initState() {
    super.initState();
    _updatePendingCount();
  }

  Future<void> _updatePendingCount() async {
    final count = await UploadManager.getPendingUploadCount();
    setState(() => _pendingUploads = count);
  }

  Future<void> _uploadPhoto() async {
    // For demo: create a test file
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/test_photo.jpg');

    // In real app, use image_picker to select file
    // final pickedFile = await ImagePicker().pickImage(...);

    await UploadManager.uploadFile(file);
    await _updatePendingCount();
  }

  Future<void> _uploadBatch() async {
    final tempDir = await getTemporaryDirectory();
    final files = List.generate(
      5,
      (i) => File('${tempDir.path}/photo_$i.jpg'),
    );

    await UploadManager.uploadBatch(files);
    await _updatePendingCount();
  }

  Future<void> _cancelAll() async {
    await UploadManager.cancelAllUploads();
    await _updatePendingCount();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('File Upload Example'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Pending Uploads: $_pendingUploads',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _uploadPhoto,
                icon: Icon(Icons.upload_file),
                label: Text('Upload Photo'),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _uploadBatch,
                icon: Icon(Icons.upload_multiple),
                label: Text('Upload 5 Photos'),
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _cancelAll,
                icon: Icon(Icons.cancel),
                label: Text('Cancel All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Expected Behavior

### Android

**Upload process:**
1. Task scheduled immediately
2. Waits for network constraint (if offline)
3. Starts upload in background worker
4. Progress tracked (via `NativeWorkManager.progress` stream)
5. Emits `TaskEvent` on completion/failure

**Network handling:**
- WiFi-only: Set `NetworkType.unmetered`
- Any network: Set `NetworkType.connected`
- Automatic retry when network returns

**Large files:**
- No size limit (handled by native URLSession/OkHttp)
- Resumable uploads NOT automatic (need server support)
- Progress updates every ~1% completed

### iOS

**Upload process:**
1. Task scheduled via `BGTaskScheduler`
2. System decides when to start (usually within minutes)
3. Upload runs with 30-second time limit
4. For large files, may need multiple chunks

**Important:** iOS background tasks have 30-second execution limit. For large files:
- Split into chunks
- Use `URLSession` background configuration (future enhancement)
- Or use foreground upload with background indicator

**Low Power Mode:**
- Uploads deferred until charging
- Return `ScheduleResult.rejectedOsPolicy`

---

## Platform Considerations

### Android Specific

**Network constraints:**
```dart
// WiFi only (recommended for large files)
constraints: Constraints(
  networkType: NetworkType.unmetered,  // WiFi
)

// Any network (mobile data OK)
constraints: Constraints(
  networkType: NetworkType.connected,  // WiFi or mobile
)

// Metered network with battery check
constraints: Constraints(
  networkType: NetworkType.connected,
  batteryNotLow: true,  // Don't drain battery on mobile data
)
```

**File size limits:**
- Practical limit: ~100MB per task
- Larger files: Split into chunks
- Android WorkManager handles large data efficiently

### iOS Specific

**Background upload configuration:**

For truly large file uploads, use `URLSessionConfiguration.background`:

```swift
// In native iOS code (future enhancement)
let config = URLSessionConfiguration.background(
    withIdentifier: "com.yourapp.upload"
)
let session = URLSession(configuration: config)
```

**Info.plist:**
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>dev.brewkits.nativeworkmanager</string>
</array>

<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

**Execution time:**
- Standard tasks: 30 seconds max
- For longer uploads, chunk the file
- Or use background URLSession (native implementation)

---

## Common Pitfalls

### 1. ❌ Not Handling Failures

```dart
// ❌ Fire and forget
await NativeWorkManager.enqueue(
  taskId: 'upload',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.httpUpload(
    url: '...',
    filePath: file.path,
  ),
);
// What if it fails?

// ✅ Monitor and retry
NativeWorkManager.events.listen((event) {
  if (!event.success && event.taskId == 'upload') {
    // Implement retry logic
    scheduleRetry(event.taskId);
  }
});
```

### 2. ❌ No Network Constraint

```dart
// ❌ Will try to upload even offline
await NativeWorkManager.enqueue(
  taskId: 'upload',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.httpUpload(url: '...', filePath: '...'),
  // No constraints! Will fail immediately if offline
);

// ✅ Wait for network
await NativeWorkManager.enqueue(
  taskId: 'upload',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.httpUpload(url: '...', filePath: '...'),
  constraints: Constraints(networkType: NetworkType.connected),
);
```

### 3. ❌ Duplicate Task IDs

```dart
// ❌ Same task ID for different files
for (final file in files) {
  await NativeWorkManager.enqueue(
    taskId: 'upload',  // Same ID! Only last file will be uploaded
    trigger: TaskTrigger.oneTime(),
    worker: NativeWorker.httpUpload(url: '...', filePath: file.path),
  );
}

// ✅ Unique task ID per file
for (final file in files) {
  await NativeWorkManager.enqueue(
    taskId: 'upload_${file.path.hashCode}',  // Unique per file
    trigger: TaskTrigger.oneTime(),
    worker: NativeWorker.httpUpload(url: '...', filePath: file.path),
    tag: 'uploads',  // Use tag for batch operations
  );
}
```

### 4. ❌ File Deleted Before Upload

```dart
// ❌ Delete file immediately
final file = await camera.takePicture();
await UploadManager.uploadFile(File(file.path));
await File(file.path).delete();  // Upload will fail!

// ✅ Keep file until upload completes
final file = await camera.takePicture();
await UploadManager.uploadFile(File(file.path));

// Listen for completion before deleting
NativeWorkManager.events.listen((event) {
  if (event.taskId == uploadTaskId && event.success) {
    File(filePath).delete();  // Safe to delete now
  }
});
```

### 5. ❌ Not Using Tags for Batch Operations

```dart
// ❌ Hard to manage multiple uploads
await NativeWorkManager.enqueue(taskId: 'upload1', ...);
await NativeWorkManager.enqueue(taskId: 'upload2', ...);
await NativeWorkManager.enqueue(taskId: 'upload3', ...);
// How to cancel all at once?

// ✅ Use tags
await NativeWorkManager.enqueue(
  taskId: 'upload1',
  ...,
  tag: 'batch_001',  // Group by batch
);
await NativeWorkManager.enqueue(
  taskId: 'upload2',
  ...,
  tag: 'batch_001',
);

// Cancel entire batch
await NativeWorkManager.cancelByTag('batch_001');
```

---

## Advanced: Progress Monitoring

Track upload progress in real-time:

```dart
import 'package:native_workmanager/native_workmanager.dart';

class UploadProgress extends ChangeNotifier {
  final Map<String, double> _progress = {};

  void startMonitoring() {
    NativeWorkManager.progress.listen((update) {
      _progress[update.taskId] = update.progress.toDouble();
      notifyListeners();
    });
  }

  double getProgress(String taskId) {
    return _progress[taskId] ?? 0.0;
  }
}

// UI Widget
class UploadProgressIndicator extends StatelessWidget {
  final String taskId;

  const UploadProgressIndicator({required this.taskId});

  @override
  Widget build(BuildContext context) {
    return Consumer<UploadProgress>(
      builder: (context, progress, child) {
        final value = progress.getProgress(taskId);
        return LinearProgressIndicator(value: value / 100.0);
      },
    );
  }
}
```

---

## Advanced: Persistent Retry Queue

Store failed uploads for later retry:

```dart
import 'package:hive/hive.dart';

class FailedUpload {
  final String filePath;
  final int retryCount;
  final DateTime lastAttempt;

  FailedUpload(this.filePath, this.retryCount, this.lastAttempt);
}

class PersistentUploadQueue {
  static late Box<FailedUpload> _failedBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _failedBox = await Hive.openBox<FailedUpload>('failed_uploads');
  }

  static void addFailed(String filePath) {
    _failedBox.put(filePath, FailedUpload(
      filePath,
      (_failedBox.get(filePath)?.retryCount ?? 0) + 1,
      DateTime.now(),
    ));
  }

  static Future<void> retryAll() async {
    for (final entry in _failedBox.values) {
      if (entry.retryCount < 3) {
        await UploadManager.uploadFile(File(entry.filePath));
      }
    }
  }

  static void removeFailed(String filePath) {
    _failedBox.delete(filePath);
  }
}
```

---

## Related

- **API sync:** [Periodic API Sync](01-periodic-api-sync.md)
- **Background cleanup:** [Background Cleanup](03-background-cleanup.md)
- **Task chains:** [Chain Processing](06-chain-processing.md)
- **API Reference:** See main [README.md](../../README.md)

---

## Checklist

- [ ] Use unique task IDs for each file
- [ ] Add network constraint (`NetworkType.connected`)
- [ ] Implement retry logic with exponential backoff
- [ ] Use tags for batch operations
- [ ] Monitor events for success/failure
- [ ] Handle permanent failures (max retries)
- [ ] Keep file until upload completes
- [ ] Cancel uploads on logout
- [ ] Test with large files (>10MB)
- [ ] Test with no network (should wait)
- [ ] Test iOS 30-second limit (chunk large files)

---

*Last updated: 2026-01-27*
