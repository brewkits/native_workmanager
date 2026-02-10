# Native WorkManager Example App

Comprehensive demonstration of all Native WorkManager features including v1.0.0 additions.

## Overview

This example app showcases the complete Native WorkManager API through an interactive 6-tab interface:

1. **Basic Tasks** - Native Workers (HTTP, File I/O, Database)
2. **BackoffPolicy** - v1.0.0 retry logic (exponential & linear)
3. **ContentUri** - v1.0.0 content observation (Android)
4. **Advanced Constraints** - isHeavyTask & QoS
5. **Task Chains** - Sequential & parallel workflows
6. **Scheduled Tasks** - Periodic, exact, and windowed scheduling

## Features Demonstrated

### ✅ v1.0.0 Features

- **BackoffPolicy** - Automatic retry with exponential or linear backoff
- **ContentUri Trigger** - React to MediaStore/Contacts changes (Android)
- **Advanced Constraints** - Heavy task classification & Quality of Service

### ✅ Core Features

- **5 Built-in Native Workers** - HTTP, FileDownload, FileUpload, DatabaseSync, CustomNative
- **5 Trigger Types** - OneTime, Periodic, Exact, Windowed, ContentUri
- **12 Constraints** - Network, charging, battery, storage, device idle, QoS, etc.
- **Task Chains** - Sequential and parallel execution
- **Event Streaming** - Real-time task completion events
- **Dual-Mode Architecture** - Native (fast) vs Dart (flexible) workers

## Running the Example

### Prerequisites

- Flutter 3.0+
- Android 8.0+ (API 26+) or iOS 13+
- Real device or emulator

### Installation

```bash
cd example
flutter pub get
flutter run
```

### Platform-Specific Setup

#### Android
No additional setup required. All features work on Android 8.0+.

**ContentUri Testing:**
- Triggers when you add/modify/delete photos in MediaStore
- Test by taking a photo or downloading an image

#### iOS
Background tasks require entitlements:

1. Open `ios/Runner.xcodeproj` in Xcode
2. Enable "Background Modes" capability
3. Check "Background fetch" and "Background processing"

**Note:** ContentUri is Android-only (not available on iOS).

## Tab-by-Tab Guide

### 1. Basic Tasks (Native Workers)

Demonstrates the 5 built-in native workers that execute without Flutter Engine overhead.

#### HTTP Request Worker

```dart
await NativeWorkManager.enqueue(
  taskId: 'http-task',
  trigger: TaskTrigger.oneTime(),
  worker: HttpRequestWorker(
    url: 'https://httpbin.org/get',
    method: HttpMethod.get,
  ),
);
```

**Performance:** ~3MB RAM, <50ms startup

#### File Download Worker

```dart
await NativeWorkManager.enqueue(
  taskId: 'download-task',
  trigger: TaskTrigger.oneTime(),
  worker: FileDownloadWorker(
    url: 'https://example.com/file.zip',
    destinationPath: '/path/to/file.zip',
  ),
  constraints: const Constraints(requiresNetwork: true),
);
```

**Features:**
- Automatic retry on network failure
- Progress tracking via event stream
- Respects network constraints

#### Database Sync Worker

```dart
await NativeWorkManager.enqueue(
  taskId: 'db-sync',
  trigger: TaskTrigger.periodic(interval: Duration(hours: 6)),
  worker: DatabaseSyncWorker(
    databasePath: '/path/to/db.sqlite',
    syncEndpoint: 'https://api.example.com/sync',
  ),
);
```

**Use Cases:**
- Offline-first apps
- Background data synchronization
- Periodic cache updates

### 2. BackoffPolicy (v1.0.0)

Demonstrates automatic retry logic with exponential and linear backoff strategies.

#### Exponential Backoff

```dart
await NativeWorkManager.enqueue(
  taskId: 'backoff-exp',
  trigger: TaskTrigger.oneTime(),
  worker: HttpRequestWorker(
    url: 'https://httpbin.org/status/500', // Simulates failure
    method: HttpMethod.get,
  ),
  constraints: const Constraints(
    requiresNetwork: true,
    backoffPolicy: BackoffPolicy.exponential,
    backoffDelayMs: 10000, // Initial delay: 10s
  ),
);
```

**Retry Schedule:** 10s → 20s → 40s → 80s → 160s (doubles each time)

**Best For:**
- Network requests
- API calls
- External service integration

#### Linear Backoff

```dart
await NativeWorkManager.enqueue(
  taskId: 'backoff-linear',
  trigger: TaskTrigger.oneTime(),
  worker: HttpRequestWorker(
    url: 'https://httpbin.org/status/503',
    method: HttpMethod.get,
  ),
  constraints: const Constraints(
    backoffPolicy: BackoffPolicy.linear,
    backoffDelayMs: 30000, // 30 seconds
  ),
);
```

**Retry Schedule:** 30s → 60s → 90s → 120s (adds 30s each time)

**Best For:**
- Database operations
- File I/O
- Internal processing tasks

### 3. ContentUri Trigger (v1.0.0 - Android Only)

Reacts to changes in Android content providers (MediaStore, Contacts, etc.).

#### Photos Observer

```dart
await NativeWorkManager.enqueue(
  taskId: 'photos-observer',
  trigger: TaskTrigger.contentUri(
    uri: Uri.parse('content://media/external/images/media'),
    triggerForDescendants: true,
  ),
  worker: HttpRequestWorker(
    url: 'https://api.example.com/backup-photo',
    method: HttpMethod.post,
  ),
  constraints: const Constraints(
    requiresNetwork: true,
    requiresCharging: true,
  ),
);
```

**Triggered When:**
- User takes a photo
- User downloads an image
- Gallery app adds/modifies images

**Testing:**
1. Enqueue the task
2. Take a photo with the camera
3. Check event log for task execution

#### Contacts Observer

```dart
await NativeWorkManager.enqueue(
  taskId: 'contacts-observer',
  trigger: TaskTrigger.contentUri(
    uri: Uri.parse('content://com.android.contacts/contacts'),
    triggerForDescendants: true,
  ),
  worker: DatabaseSyncWorker(
    databasePath: '/path/to/contacts.db',
    syncEndpoint: 'https://api.example.com/sync-contacts',
  ),
);
```

**Triggered When:**
- Contact added/modified/deleted
- Contact photo changed
- Contact details updated

**Use Cases:**
- Photo backup apps
- Contact sync services
- Media cataloging
- Document management

### 4. Advanced Constraints

Demonstrates Quality of Service (QoS) and heavy task classification.

#### Quality of Service (QoS)

```dart
// User-initiated task (highest priority)
await NativeWorkManager.enqueue(
  taskId: 'qos-user-initiated',
  trigger: TaskTrigger.oneTime(),
  worker: HttpRequestWorker(
    url: 'https://httpbin.org/get',
    method: HttpMethod.get,
  ),
  constraints: const Constraints(
    qos: QualityOfService.userInitiated,
  ),
);

// Background task (low priority)
await NativeWorkManager.enqueue(
  taskId: 'qos-background',
  trigger: TaskTrigger.oneTime(),
  worker: DatabaseSyncWorker(
    databasePath: '/path/to/db',
    syncEndpoint: 'https://api.example.com/sync',
  ),
  constraints: const Constraints(
    qos: QualityOfService.background,
  ),
);
```

**QoS Levels:**
- `userInitiated` - High priority, runs immediately
- `utility` - Medium priority, user-visible but not urgent
- `background` - Low priority, deferred to optimal times

#### Heavy Task Classification

```dart
await NativeWorkManager.enqueue(
  taskId: 'heavy-task',
  trigger: TaskTrigger.oneTime(),
  worker: CustomNativeWorker(
    taskType: 'video-encoding',
    parameters: {'inputPath': '/video.mp4', 'quality': 'high'},
  ),
  constraints: const Constraints(
    isHeavyTask: true,
    requiresCharging: true,
    requiresDeviceIdle: true,
    requiresBatteryNotLow: true,
  ),
);
```

**Heavy Task Behavior:**
- System defers execution to optimal conditions
- Won't drain battery during active use
- Runs when device is charging + idle
- Throttled to prevent overheating

**Best For:**
- Video processing
- Large file compression
- AI model inference
- Batch photo processing

### 5. Task Chains

Demonstrates sequential and parallel task execution workflows.

#### Sequential Chain (A → B → C)

```dart
final chain = TaskChainBuilder()
  .then(TaskRequest(
    id: 'download-file',
    worker: FileDownloadWorker(
      url: 'https://example.com/data.json',
      destinationPath: '/tmp/data.json',
    ),
    constraints: const Constraints(requiresNetwork: true),
  ))
  .then(TaskRequest(
    id: 'process-file',
    worker: CustomNativeWorker(
      taskType: 'process-json',
      parameters: {'filePath': '/tmp/data.json'},
    ),
  ))
  .then(TaskRequest(
    id: 'upload-result',
    worker: FileUploadWorker(
      filePath: '/tmp/result.json',
      url: 'https://example.com/upload',
    ),
    constraints: const Constraints(requiresNetwork: true),
  ))
  .build();

await NativeWorkManager.enqueueChain(chain);
```

**Flow:** Download → Process → Upload (each waits for previous)

#### Parallel Chain (A + B + C → D)

```dart
final chain = TaskChainBuilder()
  .parallel([
    TaskRequest(
      id: 'fetch-user-data',
      worker: HttpRequestWorker(
        url: 'https://api.example.com/user',
        method: HttpMethod.get,
      ),
    ),
    TaskRequest(
      id: 'fetch-settings',
      worker: HttpRequestWorker(
        url: 'https://api.example.com/settings',
        method: HttpMethod.get,
      ),
    ),
    TaskRequest(
      id: 'fetch-notifications',
      worker: HttpRequestWorker(
        url: 'https://api.example.com/notifications',
        method: HttpMethod.get,
      ),
    ),
  ])
  .then(TaskRequest(
    id: 'merge-data',
    worker: CustomNativeWorker(
      taskType: 'merge-json',
      parameters: {'outputPath': '/tmp/merged.json'},
    ),
  ))
  .build();

await NativeWorkManager.enqueueChain(chain);
```

**Flow:** Fetch 3 APIs concurrently → Merge results when all complete

### 6. Scheduled Tasks

Demonstrates periodic, exact, and windowed scheduling.

#### Periodic Task

```dart
await NativeWorkManager.enqueue(
  taskId: 'periodic-sync',
  trigger: TaskTrigger.periodic(
    interval: Duration(hours: 6),
  ),
  worker: DatabaseSyncWorker(
    databasePath: '/path/to/db',
    syncEndpoint: 'https://api.example.com/sync',
  ),
  constraints: const Constraints(
    requiresNetwork: true,
    requiresBatteryNotLow: true,
  ),
);
```

**Behavior:** Runs every 6 hours indefinitely

**Use Cases:**
- Background sync
- Cache refresh
- Health data upload

#### Exact Time Task

```dart
await NativeWorkManager.enqueue(
  taskId: 'exact-alarm',
  trigger: TaskTrigger.exact(
    triggerAt: DateTime.now().add(Duration(hours: 1)),
  ),
  worker: HttpRequestWorker(
    url: 'https://api.example.com/reminder',
    method: HttpMethod.post,
  ),
);
```

**Behavior:** Runs exactly at specified time (high precision)

**Android Note:** Requires `SCHEDULE_EXACT_ALARM` permission on Android 12+

#### Windowed Task

```dart
await NativeWorkManager.enqueue(
  taskId: 'windowed-backup',
  trigger: TaskTrigger.windowed(
    earliest: Duration(hours: 1),
    latest: Duration(hours: 2),
  ),
  worker: FileUploadWorker(
    filePath: '/backup.zip',
    url: 'https://backup.example.com/upload',
  ),
  constraints: const Constraints(
    requiresNetwork: true,
    requiresCharging: true,
  ),
);
```

**Behavior:** Runs within 1-2 hour window when constraints are met

**Best For:**
- Flexible backups
- Non-urgent syncs
- Battery-friendly uploads

## Event Streaming

All tasks emit real-time events that can be displayed in the app.

```dart
NativeWorkManager.eventStream.listen((event) {
  if (event is TaskCompletedEvent) {
    print('Task ${event.taskId} completed!');
    print('Result: ${event.result}');
  } else if (event is TaskFailedEvent) {
    print('Task ${event.taskId} failed: ${event.error}');
  }
});
```

**Event Types:**
- `TaskEnqueuedEvent` - Task scheduled
- `TaskStartedEvent` - Task began execution
- `TaskProgressEvent` - Progress update (0-100%)
- `TaskCompletedEvent` - Task succeeded
- `TaskFailedEvent` - Task failed
- `TaskCancelledEvent` - Task cancelled

## Testing Checklist

### Android Testing

- [ ] Run on Android 8.0+ device or emulator
- [ ] Test Basic Tasks (all 5 workers)
- [ ] Test BackoffPolicy (watch retry delays)
- [ ] Test ContentUri (take a photo to trigger)
- [ ] Test QoS levels (observe execution priority)
- [ ] Test Heavy Task (should defer to charging+idle)
- [ ] Test Task Chains (verify sequential/parallel execution)
- [ ] Test Periodic Tasks (wait for 2+ executions)
- [ ] Check event log for all events

### iOS Testing

- [ ] Run on iOS 13+ device or simulator
- [ ] Test Basic Tasks (all workers except ContentUri)
- [ ] Test BackoffPolicy retry logic
- [ ] Test QoS levels (BGTaskScheduler priority)
- [ ] Test Heavy Task deferral
- [ ] Test Task Chains
- [ ] Test Scheduled Tasks
- [ ] Verify background execution (app in background)
- [ ] Check event log

**Note:** ContentUri is Android-only and will not work on iOS.

## Performance Comparison

Compare Native Workers vs Dart Workers in the same app:

### Native Worker (HttpRequestWorker)
- RAM Usage: ~3MB
- Startup Time: <50ms
- Battery Impact: Minimal
- Flutter Engine: Not required

### Dart Worker (equivalent)
- RAM Usage: ~50MB
- Startup Time: ~700ms
- Battery Impact: Moderate
- Flutter Engine: Required

**Improvement:** 94% less RAM, 14x faster startup

## Troubleshooting

### Android Issues

**Problem:** Tasks not executing
**Solution:**
- Check battery optimization settings
- Disable battery saver mode
- Ensure constraints are met (network, charging, etc.)
- Check Logcat: `adb logcat | grep WorkManager`

**Problem:** ContentUri not triggering
**Solution:**
- Verify URI is correct: `content://media/external/images/media`
- Ensure `triggerForDescendants: true`
- Take a photo or download an image to trigger
- Check app has storage permissions

### iOS Issues

**Problem:** Tasks not running in background
**Solution:**
- Enable Background Modes capability in Xcode
- Check "Background fetch" and "Background processing"
- Register task identifiers in Info.plist
- Test on real device (simulator has limitations)

**Problem:** Exact time tasks not firing
**Solution:**
- iOS may defer tasks to optimize battery
- Use Critical alerts for time-sensitive tasks
- Test with device plugged in

### General Issues

**Problem:** Events not appearing in log
**Solution:**
- Ensure `NativeWorkManager.initialize()` was called
- Check event stream subscription is active
- Verify tasks are actually executing (check platform logs)

**Problem:** Task stuck in "Running" state
**Solution:**
- Worker may have crashed (check native logs)
- Timeout may have occurred
- Cancel task: `NativeWorkManager.cancelTaskById('task-id')`

## Code Examples

All examples shown in the UI tabs are fully functional and can be copied directly into your app.

**Key Files:**
- `lib/main_enhanced.dart` - Full example app with all features
- `lib/main.dart` - Basic example (simple version)

## Additional Resources

- **Package Documentation:** See main README.md
- **API Reference:** See QUICK_REFERENCE.md
- **KMP Parity:** See COMPREHENSIVE_COMPARISON.md
- **Source Code Audit:** See SOURCE_CODE_AUDIT_REPORT.md
- **Test Coverage:** See TEST_SUMMARY_v1.0.0.md

## Next Steps

1. Run the example app
2. Try all 6 tabs
3. Watch the real-time event log
4. Modify examples for your use case
5. Test on both Android and iOS
6. Integrate into your production app

## Performance Tips

1. **Use Native Workers** for I/O tasks (HTTP, files, database)
2. **Use Dart Workers** only when you need Flutter UI access
3. **Set appropriate QoS** - don't use `userInitiated` for background sync
4. **Mark Heavy Tasks** - helps system optimize battery usage
5. **Use Constraints** - defer tasks to optimal conditions
6. **Chain Tasks** - more efficient than separate enqueueing
7. **Use BackoffPolicy** - automatic retry reduces code complexity

## Support

For issues, questions, or feedback:
- GitHub Issues: [Create an issue](https://github.com/yourusername/native_workmanager/issues)
- Discussions: [Join discussion](https://github.com/yourusername/native_workmanager/discussions)

---

**Last Updated:** 2026-01-24
**Version:** 0.7.0
**Platform Compatibility:** Android 8.0+, iOS 13+
