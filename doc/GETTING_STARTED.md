# Getting Started in 3 Minutes

**Goal:** Schedule your first background task in under 3 minutes.

---

## Prerequisites

- Flutter SDK 3.0+ installed
- Basic understanding of background tasks concept
- Android Studio or VS Code with Flutter extension

### Platform Requirements

- **Android:** API 26+ (Android 8.0+) required
  - Set `minSdk 26` in `android/app/build.gradle`
  - [Full Android setup guide →](ANDROID_SETUP.md)

- **iOS:** iOS 12.0+ required
  - Background tasks have 30-second execution limit
  - [Full iOS setup guide →](IOS_BACKGROUND_LIMITS.md)

---

## Step 1: Installation (30 seconds)

Add native_workmanager to your `pubspec.yaml`:

```bash
flutter pub add native_workmanager
```

Or manually:

```yaml
dependencies:
  native_workmanager: ^1.0.3
```

Then run:

```bash
flutter pub get
```

---

## Step 2: Initialize (1 minute)

### Basic Initialization (Native Workers Only)

If you only need native workers (HTTP, file operations), use basic initialization:

```dart
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize native_workmanager
  await NativeWorkManager.initialize();

  runApp(MyApp());
}
```

### Advanced Initialization (With Dart Workers)

If you need to run Dart code in background tasks:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize with Dart worker callbacks
  await NativeWorkManager.initialize(
    dartWorkers: {
      'processData': _processDataCallback,
      'syncDatabase': _syncDatabaseCallback,
    },
  );

  runApp(MyApp());
}

// Dart worker callbacks
@pragma('vm:entry-point')
Future<bool> _processDataCallback(Map<String, dynamic>? input) async {
  // Your Dart logic here
  print('Processing data: $input');
  return true; // Success
}

@pragma('vm:entry-point')
Future<bool> _syncDatabaseCallback(Map<String, dynamic>? input) async {
  // Database sync logic
  return true;
}
```

---

## Step 3: Schedule Your First Task (1 minute)

### Example 1: Simple HTTP Sync (Native Worker - Recommended)

For periodic API calls, data sync, webhooks:

```dart
import 'package:native_workmanager/native_workmanager.dart';

// Somewhere in your app (e.g., after login)
Future<void> schedulePeriodicSync() async {
  await NativeWorkManager.enqueue(
    taskId: 'periodic-sync', // Unique identifier
    trigger: TaskTrigger.periodic(
      Duration(hours: 1), // Run every hour
    ),
    worker: NativeWorker.httpSync(
      url: 'https://api.example.com/sync',
      method: HttpMethod.post,
      headers: {
        'Authorization': 'Bearer YOUR_TOKEN',
        'Content-Type': 'application/json',
      },
      body: '{"userId": "123"}',
    ),
    constraints: Constraints(
      requiresNetworkType: NetworkType.connected, // Any network
    ),
  );

  print('✅ Periodic sync scheduled!');
}
```

### Example 2: File Upload (Native Worker)

Upload files in the background with automatic retry:

```dart
Future<void> scheduleFileUpload(String filePath) async {
  await NativeWorkManager.enqueue(
    taskId: 'upload-${DateTime.now().millisecondsSinceEpoch}',
    trigger: TaskTrigger.oneTime(),
    worker: NativeWorker.httpUpload(
      url: 'https://api.example.com/upload',
      filePath: filePath,
      headers: {'Authorization': 'Bearer YOUR_TOKEN'},
    ),
    constraints: Constraints(
      requiresNetworkType: NetworkType.unmetered, // Wi-Fi only
      requiresBatteryNotLow: true, // Wait for sufficient battery
    ),
  );

  print('✅ File upload scheduled!');
}
```

### Example 3: Complex Dart Logic (Dart Worker)

Run Flutter/Dart code when you need access to packages:

```dart
// 1. Register callback in main()
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize(
    dartWorkers: {
      'complexTask': _complexTaskCallback,
    },
  );
  runApp(MyApp());
}

// 2. Define callback
@pragma('vm:entry-point')
Future<bool> _complexTaskCallback(Map<String, dynamic>? input) async {
  try {
    // Access to all Dart packages
    final db = await openDatabase('my_database.db');
    final data = await db.query('tasks');

    // Process data
    for (var item in data) {
      // Complex logic here
    }

    await db.close();
    return true; // Success
  } catch (e) {
    print('Error: $e');
    return false; // Failure (will retry if configured)
  }
}

// 3. Schedule the task
Future<void> scheduleComplexTask() async {
  await NativeWorkManager.enqueue(
    taskId: 'complex-task',
    trigger: TaskTrigger.oneTime(),
    worker: DartWorker(
      callbackId: 'complexTask',
      input: {'userId': 123, 'action': 'process'},
      autoDispose: true, // Dispose Flutter Engine after task
    ),
  );
}
```

---

## Step 4: Verify It Works (30 seconds)

### Check Logs

Run your app and look for these logs:

```
✅ Periodic sync scheduled!
[NativeWorkManager] Task enqueued: periodic-sync
[NativeWorkManager] Task started: periodic-sync
[NativeWorkManager] Task completed: periodic-sync (success)
```

### Test Background Execution

1. **Android:**
   ```bash
   # Force run background task immediately (debug only)
   adb shell cmd jobscheduler run -f YOUR_PACKAGE_NAME 1
   ```

2. **iOS:**
   - Debug → Simulate Background Fetch (Xcode)
   - Or wait for next scheduled execution

### Monitor with Event Stream

Add real-time monitoring to your app:

```dart
NativeWorkManager.events.listen((event) {
  print('Task event: ${event.taskId} - ${event.state}');

  if (event.state == TaskState.succeeded) {
    print('✅ Task completed successfully!');
  } else if (event.state == TaskState.failed) {
    print('❌ Task failed: ${event.error}');
  }
});
```

---

## Next Steps

### Add Constraints

Make tasks smarter by adding conditions:

```dart
constraints: Constraints(
  requiresNetworkType: NetworkType.unmetered, // Wi-Fi only
  requiresCharging: true,                     // Only when charging
  requiresBatteryNotLow: true,                // Skip if battery low
  requiresDeviceIdle: true,                   // Android: When device idle
  requiresStorageNotLow: true,                // Skip if storage low
),
```

[See all constraints →](PLATFORM_CONSISTENCY.md#constraints)

### Create Task Chains

Automate multi-step workflows:

```dart
NativeWorkManager.beginWith(
  TaskRequest(
    id: 'download',
    worker: NativeWorker.httpDownload(/* ... */),
  ),
)
.then(TaskRequest(
  id: 'process',
  worker: DartWorker(callbackId: 'processFile'),
))
.then(TaskRequest(
  id: 'upload',
  worker: NativeWorker.httpUpload(/* ... */),
))
.named('photo-backup-pipeline')
.enqueue();
```

[See task chains guide →](use-cases/06-chain-processing.md)

### Optimize with Native Workers

Replace Dart workers with native workers where possible:

**Before (Dart Worker - 50 MB RAM):**
```dart
DartWorker(callbackId: 'httpRequest')
```

**After (Native Worker - 5 MB RAM):**
```dart
NativeWorker.httpRequest(url: '...') // 10x less memory!
```

[See performance guide →](PERFORMANCE_GUIDE.md)

### Explore Use Cases

Learn from real-world examples:

- [Periodic API Sync](use-cases/01-periodic-api-sync.md)
- [File Upload with Retry](use-cases/02-file-upload-with-retry.md)
- [Photo Backup Pipeline](use-cases/04-photo-auto-backup.md)
- [Hybrid Workflows](use-cases/05-hybrid-workflow.md)

[See all 7 use cases →](use-cases/)

---

## Troubleshooting

### Android: "KmpWorkManager not initialized" Error

**Problem:** Getting initialization errors on Android.

**Solutions:**
1. **Verify minimum SDK version** - Edit `android/app/build.gradle`:
   ```gradle
   defaultConfig {
       minSdk 26  // Must be 26 or higher!
   }
   ```
2. Ensure `await NativeWorkManager.initialize()` is called in `main()` before `runApp()`
3. Clean and rebuild:
   ```bash
   flutter clean
   rm -rf android/build android/app/build
   flutter pub get
   flutter build apk --debug
   ```
4. Check logcat: `adb logcat -s NativeWorkmanagerPlugin`

[Full Android troubleshooting →](ANDROID_SETUP.md#troubleshooting)

### Task Not Running

**Problem:** Task scheduled but never executes.

**Solutions:**
1. **Android:** Verify `minSdk` is 26+ in `android/app/build.gradle`
2. Check constraints - task may be waiting for conditions (Wi-Fi, charging, etc.)
3. Check device battery optimization settings (Android)
4. Verify task ID is unique
5. Check logs for errors

```dart
// Debug: Remove all constraints
constraints: Constraints(), // No conditions
```

### Task Fails Immediately

**Problem:** Task starts but fails instantly.

**Solutions:**
1. Check logs for error messages
2. Verify worker configuration (URL, file paths, etc.)
3. Test API endpoint separately
4. For Dart workers: Verify callback is registered and has `@pragma('vm:entry-point')`

### iOS Task Not Running

**Problem:** Works on Android, not on iOS.

**Solutions:**
1. iOS requires app to be in background for 30+ minutes before first execution
2. Check Info.plist permissions
3. iOS has 30-second execution limit - split long tasks
4. Enable background modes in Xcode (Background fetch, Background processing)

[See iOS-specific guide →](IOS_BACKGROUND_LIMITS.md)

### High Memory Usage

**Problem:** Background tasks using too much memory.

**Solutions:**
1. Use native workers instead of Dart workers (10x improvement)
2. Enable `autoDispose: true` for Dart workers
3. Check for memory leaks in callbacks
4. Use constraints to limit concurrent tasks

```dart
// Good: Native worker (5 MB)
NativeWorker.httpSync(url: '...')

// Also good: Dart worker with autoDispose (50 MB, then released)
DartWorker(callbackId: '...', autoDispose: true)

// Bad: Dart worker without autoDispose (50 MB stays in memory)
DartWorker(callbackId: '...') // No autoDispose!
```

---

## Summary

You've learned how to:
- ✅ Install and initialize native_workmanager
- ✅ Schedule your first background task
- ✅ Use native workers (low memory) vs Dart workers (flexible)
- ✅ Verify tasks are running
- ✅ Troubleshoot common issues

**What's Next?**
- Read [use case examples](use-cases/) for real-world patterns
- Learn [task chains](use-cases/06-chain-processing.md) for complex workflows
- Review [production guide](PRODUCTION_GUIDE.md) before deploying

---

**Questions?** Join our [Discord community](https://discord.gg/native-workmanager) for help!
