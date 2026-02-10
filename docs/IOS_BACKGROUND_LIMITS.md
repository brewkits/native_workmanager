# iOS Background Execution Time Limits

**Date:** 2026-01-31
**Status:** Task #7 - Document iOS Background Time Limits
**iOS Version:** 13.0+
**Audience:** Plugin users and contributors

---

## Overview

iOS has **strict time limits** for background task execution. Unlike Android's WorkManager (which can run for hours), iOS background tasks have very short execution windows. Understanding these limits is **critical** for designing reliable background workflows.

---

## Background Task Types & Time Limits

### 1. BGAppRefreshTask (Most Common)

**Use Case:** Lightweight periodic updates

**Time Limit:** **~30 seconds** ⏱️

**Characteristics:**
- Scheduled by iOS (not guaranteed)
- Runs opportunistically (when device idle, plugged in, connected to WiFi)
- iOS decides WHEN to run (you only specify earliest time)
- May not run for days if conditions not met

**Example:**
```swift
// Schedule app refresh
let request = BGAppRefreshTaskRequest(
    identifier: "dev.brewkits.native_workmanager.refresh"
)
request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

try BGTaskScheduler.shared.submit(request)
```

**What Fits in 30 Seconds:**
- ✅ Fetch small JSON from API (<100KB)
- ✅ Update local database (few records)
- ✅ Send analytics ping
- ✅ Check for app updates
- ❌ Download large files (>1MB)
- ❌ Process videos or images
- ❌ Complex data transformations

**Expiration Handling:**
```swift
task.expirationHandler = {
    // Called after ~25-28 seconds
    // Must clean up immediately!
    print("Task about to be killed by iOS")
    cleanupResources()
}
```

---

### 2. BGProcessingTask (Heavy Work)

**Use Case:** Longer-running maintenance tasks

**Time Limit:** **~60 seconds** ⏱️ (sometimes up to 2-3 minutes)

**Characteristics:**
- Still opportunistic (iOS decides when)
- Requires device plugged in + idle (most of the time)
- More likely to run overnight
- Can specify network/power requirements

**Example:**
```swift
// Schedule processing task
let request = BGProcessingTaskRequest(
    identifier: "dev.brewkits.native_workmanager.task"
)
request.requiresNetworkConnectivity = true
request.requiresExternalPower = true
request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour

try BGTaskScheduler.shared.submit(request)
```

**What Fits in 60 Seconds:**
- ✅ Download medium files (1-5MB)
- ✅ Process moderate datasets
- ✅ Sync user data
- ✅ Backup to cloud
- ❌ Download videos (>10MB)
- ❌ Train ML models
- ❌ Bulk data processing

**Requirements:**
```xml
<!-- Info.plist -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>dev.brewkits.native_workmanager.task</string>
    <string>dev.brewkits.native_workmanager.refresh</string>
</array>
```

---

### 3. URLSession Background Downloads/Uploads

**Use Case:** Large file transfers

**Time Limit:** **No hard limit** (hours to days) ⏱️

**Characteristics:**
- Handled by iOS **outside your app process**
- Can complete even if app terminated
- Continues in background indefinitely
- Only for HTTP transfers (not custom logic)

**Example:**
```swift
// Background URLSession
let config = URLSessionConfiguration.background(
    withIdentifier: "com.example.background-downloads"
)
let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

let task = session.downloadTask(with: url)
task.resume()

// iOS handles the download even if app is killed!
```

**native_workmanager Support (v2.3.0+):**
- ✅ HttpDownloadWorker with `useBackgroundSession: true` - Background URLSession
- ✅ HttpUploadWorker with `useBackgroundSession: true` - Background URLSession
- ⏳ Can run for hours (no 30-second limit!)
- ⏳ Survives app termination (iOS relaunches app when complete)
- 📱 iOS-only feature (Android already handles this via WorkManager)

**Usage Example:**
```dart
// Large file download that survives app termination
await NativeWorkManager.enqueue(
  taskId: 'large-download',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.httpDownload(
    url: 'https://cdn.example.com/large-video.mp4',
    savePath: '/path/to/save/video.mp4',
    useBackgroundSession: true,  // 🚀 NEW in v2.3.0
  ),
);

// Large file upload that survives app termination
await NativeWorkManager.enqueue(
  taskId: 'large-upload',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.httpUpload(
    url: 'https://api.example.com/videos',
    filePath: '/path/to/video.mp4',
    useBackgroundSession: true,  // 🚀 NEW in v2.3.0
  ),
);
```

**When to Use:**
- ✅ Large files (>10MB)
- ✅ Unreliable networks (automatic retry)
- ✅ Must complete even if user force-quits app
- ❌ Small files (<1MB) - foreground session is faster
- ❌ Immediate transfers - foreground session has less overhead

**AppDelegate Integration Required:**
For background sessions to work, add this to your iOS AppDelegate:
```swift
import native_workmanager

@available(iOS 13.0, *)
override func application(
  _ application: UIApplication,
  handleEventsForBackgroundURLSession identifier: String,
  completionHandler: @escaping () -> Void
) {
  if identifier == "dev.brewkits.native_workmanager.background" {
    BackgroundSessionManager.shared.backgroundCompletionHandler = completionHandler
  } else {
    completionHandler()
  }
}
```

**Limitations:**
- ❌ Cannot run custom Dart code during transfer
- ❌ Cannot process download incrementally
- ✅ Can process when download completes (in 30s window)
- ✅ iOS automatically retries on network failures

---

## Comparison: iOS vs Android

| Feature | iOS | Android WorkManager |
|---------|-----|---------------------|
| **Max Time (Light)** | 30s | 10 minutes (default) |
| **Max Time (Heavy)** | 60s | Unlimited (with constraints) |
| **Scheduling** | Opportunistic | Guaranteed (eventually) |
| **Periodicity** | iOS decides | Exact intervals (min 15min) |
| **Network/Power** | Recommendations | Hard constraints |
| **Foreground Service** | No equivalent | Can run indefinitely |
| **Background Downloads** | Yes (unlimited) | Yes (limited OS support) |

**Key Difference:**
- **Android:** "Run this task when constraints are met"
- **iOS:** "iOS will run this task when it wants to"

---

## Best Practices for iOS

### 1. Design for 30-Second Execution ⏱️

**Rule:** Assume you only have 30 seconds. Anything beyond that is a bonus.

**Pattern:**
```dart
// ✅ Good - Completes in <30s
@pragma('vm:entry-point')
Future<bool> quickSync(Map<String, dynamic>? input) async {
  // 1. Fetch data (5-10s)
  final response = await http.get(Uri.parse('https://api.example.com/quick'));

  // 2. Parse and save (5-10s)
  final data = jsonDecode(response.body);
  await saveToLocalDB(data);

  // 3. Cleanup (1-2s)
  await cleanupOldData();

  return true; // Total: ~20s
}

// ❌ Bad - Takes 5+ minutes
@pragma('vm:entry-point')
Future<bool> heavyProcessing(Map<String, dynamic>? input) async {
  // Will be killed by iOS!
  for (var i = 0; i < 1000; i++) {
    await processImage(i); // 10s each = 10,000s total
  }
  return true;
}
```

### 2. Use Chunking for Large Work

**Pattern:** Break large tasks into multiple small executions

```dart
// ✅ Good - Process in chunks
@pragma('vm:entry-point')
Future<bool> processChunk(Map<String, dynamic>? input) async {
  final chunkId = input?['chunkId'] ?? 0;
  final totalChunks = input?['totalChunks'] ?? 10;

  // Process 1/10th of data (within 30s limit)
  await processBatch(chunkId, batchSize: 100);

  // If more chunks, schedule next task
  if (chunkId < totalChunks - 1) {
    await NativeWorkManager.enqueue(
      taskId: 'chunk-${chunkId + 1}',
      worker: DartWorker(
        callbackId: 'processChunk',
        input: {
          'chunkId': chunkId + 1,
          'totalChunks': totalChunks,
        },
      ),
      trigger: TaskTrigger.oneTime(Duration(minutes: 15)),
    );
  }

  return true;
}
```

### 3. Prioritize Critical Work

**Pattern:** Do critical work first, optional work last

```dart
@pragma('vm:entry-point')
Future<bool> syncData(Map<String, dynamic>? input) async {
  // CRITICAL: Must complete (10s)
  await uploadCriticalUserData();

  // IMPORTANT: Try to complete (10s)
  try {
    await syncSettings();
  } catch (e) {
    // Log error but don't fail task
  }

  // OPTIONAL: Best effort (remaining time)
  try {
    await cleanupCache();
  } catch (e) {
    // Will retry next time
  }

  return true;
}
```

### 4. Monitor Expiration

**Pattern:** Listen for task expiration and gracefully cleanup

```swift
// iOS native code
task.expirationHandler = { [weak self] in
    print("Task expiring - cleaning up!")

    // Stop ongoing work
    self?.cancelOngoingRequests()

    // Save state for next run
    self?.saveProgress()

    // Mark task as complete
    task.setTaskCompleted(success: false)
}
```

### 5. Use Background URLSession for Large Transfers

**Pattern:** Offload file transfers to iOS background URLSession

```dart
// ✅ Good - Large download using background URLSession
await NativeWorkManager.enqueue(
  taskId: 'download-update',
  worker: NativeWorker.httpDownload(
    url: 'https://cdn.example.com/app-update.zip',  // 50MB file
    savePath: savePath,
  ),
  // iOS handles this independently (can take hours)
);

// Process downloaded file in separate task
await NativeWorkManager.enqueue(
  taskId: 'process-update',
  worker: DartWorker(
    callbackId: 'processDownloadedFile',
    input: {'filePath': savePath},
  ),
  trigger: TaskTrigger.oneTime(Duration(minutes: 1)),
  // Will run AFTER download completes
);
```

---

## Common Pitfalls

### ❌ Pitfall #1: Assuming Guaranteed Execution

**Problem:**
```dart
// ❌ Bad - assumes this will run every hour
await NativeWorkManager.enqueue(
  taskId: 'hourly-sync',
  worker: DartWorker(callbackId: 'sync'),
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
);
// iOS may run this every 6 hours, once a day, or never!
```

**Solution:**
```dart
// ✅ Good - Design for unpredictable schedule
// Use server-side tracking to detect missed syncs
// Implement catch-up logic when app launches
```

### ❌ Pitfall #2: Long-Running Operations

**Problem:**
```dart
// ❌ Bad - will be killed after 30-60s
@pragma('vm:entry-point')
Future<bool> processAllPhotos(Map<String, dynamic>? input) async {
  final photos = await getPhotos(); // 1000 photos

  for (final photo in photos) {
    await processPhoto(photo); // 5s each = 5000s total
  }

  return true;
}
```

**Solution:**
```dart
// ✅ Good - chunk into batches
@pragma('vm:entry-point')
Future<bool> processBatchOfPhotos(Map<String, dynamic>? input) async {
  final batch = await getNextBatch(limit: 5); // Process 5 photos only

  for (final photo in batch) {
    await processPhoto(photo); // 5s each = 25s total
  }

  return true;
}
```

### ❌ Pitfall #3: Ignoring Background Restrictions

**Problem:**
```dart
// ❌ Bad - requires device idle + plugged in (rare!)
await NativeWorkManager.enqueue(
  worker: SomeWorker(),
  constraints: Constraints(
    requiresCharging: true,  // iOS: "requiresExternalPower"
    requiresDeviceIdle: true, // iOS: BGProcessingTask only
  ),
);
// May not run for days!
```

**Solution:**
```dart
// ✅ Good - minimal constraints
await NativeWorkManager.enqueue(
  worker: SomeWorker(),
  constraints: Constraints(
    requiresNetwork: true, // Only essential constraint
  ),
);
```

---

## Testing on iOS

### Testing in Simulator

**Problem:** BGTaskScheduler doesn't work in Simulator normally.

**Solution:** Use debugger commands

```bash
# 1. Run app in Xcode debugger

# 2. Pause app (breakpoint or pause button)

# 3. Execute in LLDB console:
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"dev.brewkits.native_workmanager.task"]

# 4. Continue execution

# Task will execute immediately!
```

### Testing on Device

**Process:**
1. Enable background processing in Xcode: Product → Scheme → Edit Scheme → Run → Options → Background Fetch ✅
2. Install app on device
3. Schedule task
4. Background the app
5. Wait... (could be hours or days)

**Force Execution:**
```bash
# After backgrounding app, wait a few minutes, then:
# In Terminal on Mac:

# List devices
xcrun simctl list devices

# Trigger background fetch (device must be unlocked initially)
xcrun simctl launch --terminate-running-process booted com.example.yourapp

# Trigger in Xcode debugger (better):
# Pause app → LLDB → execute command above
```

---

## Platform Detection

Detect iOS restrictions at runtime:

```dart
import 'dart:io' show Platform;

Future<void> scheduleBackgroundTask() async {
  if (Platform.isIOS) {
    // iOS: Use short-running tasks only
    await scheduleQuickSync();
  } else if (Platform.isAndroid) {
    // Android: Can run longer tasks
    await scheduleFullSync();
  }
}

Future<void> scheduleQuickSync() async {
  // Design for 30s execution
  await NativeWorkManager.enqueue(
    taskId: 'quick-sync',
    worker: DartWorker(
      callbackId: 'quickSyncCallback',
    ),
    trigger: TaskTrigger.periodic(Duration(hours: 1)),
  );
}
```

---

## Debugging Time Limits

### Logging Execution Time

```dart
@pragma('vm:entry-point')
Future<bool> timedCallback(Map<String, dynamic>? input) async {
  final stopwatch = Stopwatch()..start();

  try {
    // Your work here
    await doWork();

    stopwatch.stop();
    print('⏱️ Execution time: ${stopwatch.elapsedMilliseconds}ms');

    return true;
  } catch (e) {
    stopwatch.stop();
    print('❌ Failed after ${stopwatch.elapsedMilliseconds}ms: $e');
    return false;
  }
}
```

### Monitoring in Production

```dart
// Track task completion rates
class TaskMetrics {
  static int scheduled = 0;
  static int completed = 0;
  static int expired = 0;

  static double get completionRate =>
      scheduled > 0 ? (completed / scheduled) : 0.0;
}

// Log to analytics
NativeWorkManager.events.listen((event) {
  if (event.success) {
    TaskMetrics.completed++;
  } else {
    TaskMetrics.expired++;
  }

  // Send to Firebase/analytics
  analytics.logEvent(name: 'background_task_result', parameters: {
    'task_id': event.taskId,
    'success': event.success,
    'completion_rate': TaskMetrics.completionRate,
  });
});
```

---

## FAQ

### Q: Can I run a task for 10 minutes on iOS?
**A:** No. iOS limits:
- BGAppRefreshTask: ~30 seconds
- BGProcessingTask: ~60 seconds (maybe 2-3 minutes rarely)
- Only background URLSession can run for hours

Use chunking to break work into 30-second pieces.

### Q: Will periodic tasks run every hour like Android?
**A:** No. iOS schedules tasks opportunistically. You specify "earliest" time, but iOS decides actual execution time based on:
- Battery level
- Network connectivity
- Device usage patterns
- User behavior
- Power state

A "1-hour periodic" task might run every 6 hours or once per day.

### Q: Can I guarantee task execution?
**A:** No. iOS makes no guarantees. Design your app to:
- Sync when app launches
- Use server-side push notifications for critical updates
- Handle missed tasks gracefully

### Q: What happens if my task takes longer than 30s?
**A:** iOS kills your task. The `expirationHandler` is called ~3-5 seconds before termination. You must:
1. Stop all work immediately
2. Save progress
3. Call `task.setTaskCompleted(success: false)`

### Q: Can I show UI during background task?
**A:** No. Background tasks run when app is in background. No UI access.

### Q: How do I test if task was killed?
**A:** Check logs after backgrounding app. If you see "Task expiring" message, it hit time limit.

---

## Decision Tree: Task Type Selection

```
Do you need to run custom Dart code?
├─ No → Use HttpDownloadWorker/HttpUploadWorker
│        (can run for hours)
│
└─ Yes → How long does it take?
    ├─ <20 seconds → Use BGAppRefreshTask ✅
    │                (most reliable)
    │
    ├─ 20-50 seconds → Use BGProcessingTask
    │                  (requires charging usually)
    │
    └─ >50 seconds → Chunk into multiple tasks
                     (or redesign workflow)
```

---

## Resources

**Apple Documentation:**
- [BGTaskScheduler](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler)
- [Background Execution](https://developer.apple.com/documentation/backgroundtasks)
- [Energy Efficiency Guide](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/)

**WWDC Sessions:**
- WWDC 2019: Advances in Background Execution
- WWDC 2020: Background Execution and Updates

**Testing:**
- [Testing Background Tasks](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/simulating_background_tasks)

---

**Document Version:** 1.0.0
**Last Updated:** 2026-01-31
**iOS Version:** 13.0 - 18.0
**Maintained By:** Principal Mobile Solutions Architect
