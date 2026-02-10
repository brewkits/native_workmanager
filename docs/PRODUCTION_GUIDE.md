# Production Deployment Guide

**Version:** 0.8.1
**Last Updated:** 2026-02-07
**Status:** Beta - Production-ready for non-critical background tasks

This guide helps you deploy `native_workmanager` to production safely and effectively.

---

## 📋 Table of Contents

1. [Pre-Deployment Checklist](#-pre-deployment-checklist)
2. [Error Handling Patterns](#-error-handling-patterns)
3. [Testing Strategies](#-testing-strategies)
4. [Platform-Specific Gotchas](#-platform-specific-gotchas)
5. [Monitoring & Observability](#-monitoring--observability)
6. [Common Failure Modes](#-common-failure-modes)
7. [Performance Optimization](#-performance-optimization)
8. [Security Best Practices](#-security-best-practices)

---

## ✅ Pre-Deployment Checklist

### Before Production Release

- [ ] **Tested on low-end devices**
  - Test on Android devices with <2GB RAM
  - Test on iPhone 7 or older (iOS 13+)
  - Verify memory usage stays within limits

- [ ] **Tested with poor network**
  - Simulate network timeouts (use Charles Proxy or similar)
  - Test offline scenarios
  - Verify retry logic works correctly

- [ ] **Tested with battery saver enabled**
  - Enable battery saver mode on Android
  - Enable Low Power Mode on iOS
  - Verify tasks still execute (with delays)

- [ ] **Added error logging**
  - Implement error tracking (Sentry, Firebase Crashlytics)
  - Log all task failures with context
  - Track success rates

- [ ] **Set up monitoring**
  - Track task completion rates
  - Monitor execution times
  - Alert on failure spikes

- [ ] **Reviewed constraints**
  - Ensure constraints match use case
  - Don't over-constrain (tasks won't run)
  - Don't under-constrain (battery drain)

- [ ] **Tested background execution**
  - Force-close app and verify tasks run
  - Test after device reboot
  - Verify on both Android and iOS

- [ ] **Documented worker inputs**
  - Document expected JSON format for each worker
  - Add input validation
  - Handle missing fields gracefully

- [ ] **Reviewed permissions**
  - Android: Check AndroidManifest.xml permissions
  - iOS: Verify Info.plist BGTaskScheduler identifiers
  - Request runtime permissions if needed

- [ ] **Load tested**
  - Test with realistic task volumes
  - Verify queue processing performance
  - Check memory usage under load

---

## 🛡️ Error Handling Patterns

### 1. HTTP Workers - Network Errors

**Common Scenarios:**
- Network timeout
- Server errors (500, 502, 503)
- Client errors (404, 401)
- DNS resolution failure

**Recommended Pattern:**

```dart
void initWorkManager() {
  NativeWorkManager.events.listen((event) {
    if (!event.success) {
      // Parse error message
      final message = event.message ?? 'Unknown error';

      // Log error with context
      logger.error(
        'Task ${event.taskId} failed: $message',
        extra: {
          'taskId': event.taskId,
          'timestamp': event.timestamp,
          'errorMessage': message,
        },
      );

      // Handle specific error types
      if (message.contains('timeout')) {
        // Network timeout - will retry automatically
        _handleNetworkTimeout(event.taskId);
      } else if (message.contains('HTTP 401') || message.contains('HTTP 403')) {
        // Auth error - don't retry, fix credentials
        _handleAuthError(event.taskId);
      } else if (message.contains('HTTP 404')) {
        // Not found - don't retry, cancel task
        NativeWorkManager.cancel(event.taskId);
      } else if (message.contains('HTTP 5')) {
        // Server error - will retry with backoff
        _handleServerError(event.taskId);
      }
    }
  });
}

void _handleNetworkTimeout(String taskId) {
  // Maybe increase timeout for this task type
  logger.warn('Network timeout for $taskId - consider increasing timeout');
}

void _handleAuthError(String taskId) {
  // Refresh auth token and reschedule
  logger.error('Auth error for $taskId - refreshing token');
  authService.refreshToken().then((_) {
    // Reschedule with new token
  });
}

void _handleServerError(String taskId) {
  // Server error - backoff policy will handle retry
  logger.warn('Server error for $taskId - will retry with backoff');
}
```

### 2. File Operation Errors

**Common Scenarios:**
- File not found
- Permission denied
- Disk full
- Path traversal attempt

**Recommended Pattern:**

```dart
// BEFORE scheduling upload/download
Future<void> scheduleFileUpload(String filePath) async {
  // ✅ Validate file exists
  final file = File(filePath);
  if (!await file.exists()) {
    logger.error('File not found: $filePath');
    return; // Don't schedule
  }

  // ✅ Check file size
  final fileSize = await file.length();
  if (fileSize > 100 * 1024 * 1024) { // 100MB
    logger.error('File too large: ${fileSize ~/ 1024 / 1024}MB');
    return; // Don't schedule
  }

  // ✅ Verify read permissions
  try {
    await file.readAsBytes();
  } catch (e) {
    logger.error('Cannot read file: $e');
    return;
  }

  // Now safe to schedule
  await NativeWorkManager.enqueue(
    taskId: 'upload-${DateTime.now().millisecondsSinceEpoch}',
    trigger: TaskTrigger.oneTime(),
    worker: NativeWorker.httpUpload(
      url: 'https://api.example.com/upload',
      filePath: filePath,
    ),
    constraints: Constraints.heavyTask,
  );
}

// AFTER task completes
void handleUploadResult(TaskCompletionEvent event) {
  if (!event.success) {
    final message = event.message ?? '';

    if (message.contains('File not found')) {
      logger.error('File was deleted before upload: ${event.taskId}');
      // Don't retry
    } else if (message.contains('Permission denied')) {
      logger.error('No permission to read file: ${event.taskId}');
      // Request permissions
    } else if (message.contains('Path outside')) {
      logger.error('Security: Path traversal attempt blocked');
      // Security incident - investigate
    }
  }
}
```

### 3. Dart Worker Errors

**Common Scenarios:**
- FlutterEngine initialization failure
- Callback timeout
- Uncaught exception in Dart code
- Memory limit exceeded

**Recommended Pattern:**

```dart
// ✅ Wrap Dart worker callbacks in try-catch
@pragma('vm:entry-point')
Future<bool> backgroundSyncCallback(Map<String, dynamic>? input) async {
  try {
    // Validate input
    if (input == null) {
      logger.error('Sync callback: null input');
      return false;
    }

    // Extract parameters with defaults
    final userId = input['userId'] as String? ?? 'unknown';
    final syncType = input['type'] as String? ?? 'full';

    logger.info('Starting sync: user=$userId, type=$syncType');

    // Execute with timeout
    final result = await syncService
        .performSync(userId, syncType)
        .timeout(Duration(minutes: 4)); // iOS limit is 5min

    logger.info('Sync completed: $result');
    return true;

  } on TimeoutException catch (e) {
    logger.error('Sync timeout: $e');
    return false; // Will retry with backoff

  } catch (e, stackTrace) {
    logger.error('Sync error: $e', stackTrace: stackTrace);

    // Report to crash analytics
    crashlytics.recordError(e, stackTrace, reason: 'Background sync failed');

    return false; // Will retry
  }
}
```

### 4. Constraint Failures

**Common Scenarios:**
- Network unavailable
- Battery low
- Device not charging
- Storage low

**Recommended Pattern:**

```dart
// ✅ Monitor tasks that are waiting for constraints
void monitorPendingTasks() {
  Timer.periodic(Duration(minutes: 15), (timer) async {
    // Check if important tasks are stuck
    final status = await NativeWorkManager.getTaskStatus('critical-sync');

    if (status == 'pending') {
      final waitingTime = _calculateWaitingTime('critical-sync');

      if (waitingTime > Duration(hours: 6)) {
        // Task stuck for 6+ hours
        logger.warn(
          'Task waiting too long: critical-sync (${waitingTime.inHours}h)',
          extra: {'taskId': 'critical-sync'},
        );

        // Maybe relax constraints
        await NativeWorkManager.cancel('critical-sync');
        await _rescheduleWithRelaxedConstraints('critical-sync');
      }
    }
  });
}

Future<void> _rescheduleWithRelaxedConstraints(String taskId) async {
  // Instead of requiring WiFi, allow cellular
  await NativeWorkManager.enqueue(
    taskId: taskId,
    trigger: TaskTrigger.oneTime(),
    worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
    constraints: Constraints(
      requiresNetwork: true, // Changed from requiresUnmeteredNetwork
    ),
  );
}
```

---

## 🧪 Testing Strategies

### Unit Testing Background Workers

```dart
// Create mock workers for testing
class MockHttpRequestWorker extends HttpRequestWorker {
  final Future<Map<String, dynamic>> Function(String url) mockResponse;

  MockHttpRequestWorker(this.mockResponse);

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> config) async {
    return mockResponse(config['url'] as String);
  }
}

// Test your task scheduling logic
void main() {
  testWidgets('schedules sync task correctly', (tester) async {
    // Setup
    final scheduledTasks = <String>[];

    // Mock NativeWorkManager.enqueue
    when(() => mockWorkManager.enqueue(
      taskId: any(named: 'taskId'),
      trigger: any(named: 'trigger'),
      worker: any(named: 'worker'),
    )).thenAnswer((invocation) {
      scheduledTasks.add(invocation.namedArguments[#taskId] as String);
      return Future.value(ScheduleResult.accepted);
    });

    // Execute
    await myService.scheduleSyncTask();

    // Verify
    expect(scheduledTasks, contains('daily-sync'));
  });
}
```

### Integration Testing on Real Devices

**Android Testing:**

```bash
# 1. Build release APK
flutter build apk --release

# 2. Install on device
adb install build/app/outputs/flutter-apk/app-release.apk

# 3. Force-close app
adb shell am force-stop com.example.app

# 4. Trigger Doze mode (Android 6+)
adb shell dumpsys deviceidle force-idle

# 5. Check WorkManager queue
adb shell dumpsys jobscheduler | grep com.example.app

# 6. Monitor logs
adb logcat | grep WorkManager
```

**iOS Testing:**

```bash
# 1. Build release IPA
flutter build ios --release

# 2. Install via Xcode or TestFlight

# 3. Force-close app via app switcher

# 4. Wait 30+ minutes with screen off

# 5. Check Console.app logs
# Filter: process:com.example.app subsystem:BGTaskScheduler

# 6. Simulate background fetch (only in Simulator)
xcrun simctl launch booted e -BGTaskScheduler -- simulate_fetch com.example.app
```

### Load Testing

```dart
// Test with realistic task volumes
Future<void> loadTest() async {
  final stopwatch = Stopwatch()..start();

  // Schedule 100 tasks
  for (int i = 0; i < 100; i++) {
    await NativeWorkManager.enqueue(
      taskId: 'load-test-$i',
      trigger: TaskTrigger.oneTime(),
      worker: NativeWorker.httpRequest(
        url: 'https://httpbin.org/get',
        method: HttpMethod.get,
      ),
    );
  }

  print('Scheduled 100 tasks in ${stopwatch.elapsedMilliseconds}ms');

  // Monitor completion
  int completed = 0;
  final subscription = NativeWorkManager.events.listen((event) {
    if (event.taskId.startsWith('load-test')) {
      completed++;
      print('Progress: $completed/100');
    }
  });

  // Wait for all to complete (max 10 minutes)
  await Future.delayed(Duration(minutes: 10));
  subscription.cancel();

  print('Load test completed: $completed/100 tasks');
}
```

---

## 🔧 Platform-Specific Gotchas

### Android

#### 1. Doze Mode & App Standby

**Problem:** Android 6+ delays background tasks aggressively.

**Solution:**
```dart
// For critical tasks, use setExpedited (requires additional setup)
// Most apps should just accept the delays - it's good for battery!

// DON'T request battery optimization exemption unless absolutely necessary
// It's against Google Play policy for most app categories
```

#### 2. WorkManager Minimum Intervals

**Problem:** Periodic tasks must be ≥15 minutes.

**Solution:**
```dart
// ❌ BAD - Will throw error
TaskTrigger.periodic(Duration(minutes: 10))

// ✅ GOOD
TaskTrigger.periodic(Duration(minutes: 15))

// For more frequent updates, use other mechanisms:
// - Foreground service (requires notification)
// - AlarmManager (exact timing but not background work)
```

#### 3. Android 14+ Foreground Service Types

**Problem:** Android 14 requires explicit service types.

**Solution:**
```dart
// ✅ Always specify foreground service type for heavy tasks
await NativeWorkManager.enqueue(
  taskId: 'location-track',
  trigger: TaskTrigger.periodic(Duration(minutes: 15)),
  worker: DartWorker(callbackId: 'trackLocation'),
  constraints: Constraints(
    isHeavyTask: true,
    foregroundServiceType: ForegroundServiceType.location, // REQUIRED
  ),
);

// Add to AndroidManifest.xml:
// <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
```

#### 4. Exact Alarms Permission

**Problem:** Android 12+ requires special permission for exact alarms.

**Solution:**
```dart
// Check permission before scheduling
if (Platform.isAndroid) {
  // Use permission_handler package
  final status = await Permission.scheduleExactAlarm.status;

  if (!status.isGranted) {
    // Show explanation dialog
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Exact Alarm Permission'),
        content: Text('Required for scheduled reminders at exact times'),
        actions: [
          TextButton(
            onPressed: () async {
              await Permission.scheduleExactAlarm.request();
              Navigator.pop(context);
            },
            child: Text('Grant'),
          ),
        ],
      ),
    );
  }
}
```

### iOS

#### 1. BGTaskScheduler Time Limits

**Problem:** iOS strictly enforces time limits.

| Task Type | Time Limit | Recommendation |
|-----------|------------|----------------|
| BGAppRefreshTask | ~30 seconds | Most tasks |
| BGProcessingTask | 5-10 minutes | Heavy tasks only |

**Solution:**
```dart
// ✅ Always add timeout to Dart workers
@pragma('vm:entry-point')
Future<bool> syncCallback(Map<String, dynamic>? input) async {
  try {
    // Use 80% of available time as timeout
    final timeout = (input?['bgTaskType'] == 'processing')
        ? Duration(minutes: 4) // 80% of 5min
        : Duration(seconds: 24); // 80% of 30sec

    final result = await syncService
        .performSync()
        .timeout(timeout);

    return result;
  } on TimeoutException {
    // Save progress and schedule continuation
    await saveProgress();
    return true; // Return success to avoid retry
  }
}
```

#### 2. BGTaskScheduler Unreliability

**Problem:** iOS may not run tasks when you expect.

**Solution:**
```dart
// ✅ Accept that iOS background tasks are "best effort"
// ❌ Don't rely on periodic tasks running exactly every N hours
// ✅ Do implement manual sync when app becomes active

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - check if sync needed
      final lastSync = prefs.getInt('lastSyncTime') ?? 0;
      final hoursSinceSync =
          (DateTime.now().millisecondsSinceEpoch - lastSync) / 3600000;

      if (hoursSinceSync > 6) {
        // Background task didn't run - do it now
        syncService.performSync();
      }
    }
  }
}
```

#### 3. Info.plist Configuration

**Problem:** Missing Info.plist entries prevent tasks from running.

**Solution:**
```xml
<!-- ios/Runner/Info.plist -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <string>dev.brewkits.kmpworkmanager.refresh</string>
  <string>dev.brewkits.kmpworkmanager.processing</string>
</array>

<!-- Enable background modes -->
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>processing</string>
</array>
```

**Verify configuration:**
```dart
// native_workmanager auto-validates on startup
// Check logs for validation errors:
// "✅ BGTaskScheduler configured correctly"
// or
// "❌ Missing BGTaskScheduler identifiers in Info.plist"
```

#### 4. Low Power Mode

**Problem:** iOS disables most background activity in Low Power Mode.

**Solution:**
```dart
// ✅ Accept that tasks won't run in Low Power Mode
// ❌ Don't try to bypass this - it's intentional for battery saving

// Inform users when Low Power Mode is enabled
void checkLowPowerMode() async {
  // Use battery_plus package
  final batteryLevel = await Battery().batteryLevel;
  final isInBatterySaveMode = await Battery().isInBatterySaveMode;

  if (isInBatterySaveMode) {
    // Show user-friendly message
    showSnackBar(
      'Background sync paused in Low Power Mode. '
      'Syncing when app is open.',
    );
  }
}
```

---

## 📊 Monitoring & Observability

### 1. Task Success Rate Tracking

```dart
class WorkManagerAnalytics {
  final Map<String, int> _taskAttempts = {};
  final Map<String, int> _taskSuccesses = {};

  void init() {
    NativeWorkManager.events.listen((event) {
      _taskAttempts[event.taskId] = (_taskAttempts[event.taskId] ?? 0) + 1;

      if (event.success) {
        _taskSuccesses[event.taskId] = (_taskSuccesses[event.taskId] ?? 0) + 1;
      }

      // Calculate success rate
      final attempts = _taskAttempts[event.taskId]!;
      final successes = _taskSuccesses[event.taskId] ?? 0;
      final successRate = (successes / attempts * 100).toStringAsFixed(1);

      // Log to analytics
      analytics.logEvent(
        name: 'task_completed',
        parameters: {
          'task_id': event.taskId,
          'success': event.success,
          'success_rate': successRate,
          'message': event.message ?? '',
        },
      );

      // Alert on low success rate
      if (attempts >= 10 && (successes / attempts) < 0.7) {
        logger.warn(
          'Low success rate for ${event.taskId}: $successRate% '
          '($successes/$attempts)',
        );
      }
    });
  }
}
```

### 2. Execution Time Monitoring

```dart
class TaskTimingMonitor {
  final Map<String, DateTime> _taskStartTimes = {};

  void init() {
    // Track when tasks start (use custom metadata)
    // When tasks complete, calculate duration
    NativeWorkManager.events.listen((event) {
      final startTime = _taskStartTimes[event.taskId];
      if (startTime != null) {
        final duration = event.timestamp.difference(startTime);

        analytics.logEvent(
          name: 'task_duration',
          parameters: {
            'task_id': event.taskId,
            'duration_ms': duration.inMilliseconds,
            'success': event.success,
          },
        );

        // Alert on slow tasks
        if (duration.inSeconds > 60) {
          logger.warn('Slow task: ${event.taskId} took ${duration.inSeconds}s');
        }

        _taskStartTimes.remove(event.taskId);
      }
    });
  }

  void recordTaskStart(String taskId) {
    _taskStartTimes[taskId] = DateTime.now();
  }
}
```

### 3. Error Rate Alerting

```dart
class ErrorRateMonitor {
  final List<DateTime> _recentErrors = [];

  void init() {
    NativeWorkManager.events.listen((event) {
      if (!event.success) {
        _recentErrors.add(event.timestamp);

        // Keep only last hour of errors
        final oneHourAgo = DateTime.now().subtract(Duration(hours: 1));
        _recentErrors.removeWhere((time) => time.isBefore(oneHourAgo));

        // Alert if error rate > 10 errors/hour
        if (_recentErrors.length > 10) {
          logger.error(
            'HIGH ERROR RATE: ${_recentErrors.length} errors in last hour',
            extra: {
              'recent_errors': _recentErrors.length,
              'threshold': 10,
            },
          );

          // Send alert to monitoring service
          monitoringService.sendAlert(
            severity: 'high',
            title: 'High background task error rate',
            description: '${_recentErrors.length} errors in last hour',
          );
        }
      }
    });
  }
}
```

---

## 🐛 Common Failure Modes

### 1. FlutterEngine Initialization Failure

**Symptoms:**
- DartWorker tasks fail immediately
- Error: "Failed to initialize FlutterEngine"

**Causes:**
- Callback handle not set correctly
- Callback not registered
- Memory limit exceeded

**Solution:**
```dart
// ✅ Ensure callback dispatcher is registered
await NativeWorkManager.initialize(
  dartWorkers: {
    'myTask': myTaskCallback, // Must be registered!
  },
);

// ✅ Ensure callback is top-level function
@pragma('vm:entry-point')
Future<bool> myTaskCallback(Map<String, dynamic>? input) async {
  // Implementation
  return true;
}

// ❌ DON'T use instance methods or closures
class MyClass {
  Future<bool> myCallback(Map<String, dynamic>? input) async { // ❌ Won't work!
    return true;
  }
}
```

### 2. Task Stuck in "Pending" State

**Symptoms:**
- Task never executes
- Stays in queue indefinitely

**Causes:**
- Constraints never met (WiFi, charging, etc.)
- Doze mode on Android
- Low Power Mode on iOS
- Task quota exceeded

**Solution:**
```dart
// ✅ Use appropriate constraints
Constraints(
  requiresNetwork: true, // Will run on WiFi OR cellular
  // DON'T use requiresUnmeteredNetwork unless truly needed
)

// ✅ Monitor pending tasks
void checkStuckTasks() async {
  final status = await NativeWorkManager.getTaskStatus('important-sync');
  if (status == 'pending') {
    // Check how long it's been pending
    final scheduledTime = taskScheduleTimes['important-sync'];
    if (scheduledTime != null) {
      final waitTime = DateTime.now().difference(scheduledTime);
      if (waitTime > Duration(hours: 12)) {
        logger.warn('Task stuck for ${waitTime.inHours} hours');

        // Cancel and reschedule with relaxed constraints
        await NativeWorkManager.cancel('important-sync');
        await rescheduleWithRelaxedConstraints();
      }
    }
  }
}
```

### 3. Task Queue Overflow

**Symptoms:**
- New tasks rejected
- ScheduleResult.throttled returned

**Causes:**
- Scheduling too many tasks
- Tasks not completing
- OS queue limit reached

**Solution:**
```dart
// ✅ Use unique IDs to prevent duplicates
final taskId = 'sync-${userId}'; // NOT 'sync-${DateTime.now()}'

await NativeWorkManager.enqueue(
  taskId: taskId,
  trigger: TaskTrigger.oneTime(),
  worker: worker,
);

// ✅ Cancel old tasks before scheduling new ones
await NativeWorkManager.cancel('old-sync');
await NativeWorkManager.enqueue(
  taskId: 'new-sync',
  trigger: TaskTrigger.oneTime(),
  worker: worker,
);

// ✅ Use periodic tasks instead of one-time tasks in loops
// ❌ DON'T DO THIS:
for (int i = 0; i < 24; i++) {
  await NativeWorkManager.enqueue(
    taskId: 'hourly-sync-$i', // Creates 24 tasks!
    ...
  );
}

// ✅ DO THIS:
await NativeWorkManager.enqueue(
  taskId: 'hourly-sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)), // 1 task
  ...
);
```

---

## ⚡ Performance Optimization

### 1. Choose the Right Worker Type

```dart
// ✅ Use Native Workers for I/O
NativeWorker.httpRequest(...) // 2-5MB RAM, <50ms startup

// ❌ Don't use Dart Workers for simple HTTP
DartWorker(...) // 30-50MB RAM, 500-1000ms startup

// ✅ Use Dart Workers only when you need Dart code
DartWorker(
  callbackId: 'processData', // Complex business logic
  autoDispose: true, // Free memory immediately after
)
```

### 2. Optimize Dart Worker Memory

```dart
// For infrequent tasks: Use autoDispose
await NativeWorkManager.enqueue(
  taskId: 'daily-cleanup',
  trigger: TaskTrigger.periodic(Duration(days: 1)),
  worker: DartWorker(
    callbackId: 'cleanup',
    autoDispose: true, // Kills engine, frees 50MB
  ),
);

// For frequent tasks: Keep engine warm
await NativeWorkManager.enqueue(
  taskId: 'frequent-check',
  trigger: TaskTrigger.periodic(Duration(minutes: 15)),
  worker: DartWorker(
    callbackId: 'check',
    autoDispose: false, // Keep engine alive, faster startup
  ),
);

// For task chains: Keep engine warm
await NativeWorkManager.beginWith(...)
  .then(DartWorker(autoDispose: false)) // Don't kill between tasks
  .then(...)
  .enqueue();
```

### 3. Use Task Chains for Dependent Operations

```dart
// ❌ BAD: Schedule independently, no ordering
await NativeWorkManager.enqueue(taskId: 'download', ...);
await NativeWorkManager.enqueue(taskId: 'process', ...); // May run before download!

// ✅ GOOD: Use chains for guaranteed ordering
await NativeWorkManager.beginWith(
  TaskRequest(
    id: 'download',
    worker: NativeWorker.httpDownload(...),
  ),
).then(
  TaskRequest(
    id: 'process',
    worker: DartWorker(callbackId: 'processFile'),
  ),
).enqueue();
```

---

## 🔒 Security Best Practices

### 1. Input Validation

```dart
// ✅ Always validate worker inputs
@pragma('vm:entry-point')
Future<bool> uploadCallback(Map<String, dynamic>? input) async {
  // Validate input exists
  if (input == null) {
    logger.error('Upload callback: null input');
    return false;
  }

  // Validate required fields
  final url = input['url'] as String?;
  if (url == null || url.isEmpty) {
    logger.error('Upload callback: missing URL');
    return false;
  }

  // Validate URL scheme
  if (!url.startsWith('https://')) {
    logger.error('Upload callback: insecure URL scheme');
    return false;
  }

  // Validate file path
  final filePath = input['filePath'] as String?;
  if (filePath == null) {
    logger.error('Upload callback: missing file path');
    return false;
  }

  // Check file exists
  final file = File(filePath);
  if (!await file.exists()) {
    logger.error('Upload callback: file not found');
    return false;
  }

  // Proceed with upload
  ...
}
```

### 2. Secrets Management

```dart
// ❌ DON'T hardcode secrets
await NativeWorkManager.enqueue(
  taskId: 'upload',
  worker: NativeWorker.httpUpload(
    url: 'https://api.example.com/upload',
    headers: {
      'Authorization': 'Bearer sk_live_abc123', // ❌ NEVER DO THIS!
    },
  ),
);

// ✅ DO retrieve secrets at runtime
await NativeWorkManager.enqueue(
  taskId: 'upload',
  worker: NativeWorker.httpUpload(
    url: 'https://api.example.com/upload',
    headers: {
      'Authorization': 'Bearer ${await getAuthToken()}', // ✅ Runtime retrieval
    },
  ),
);
```

### 3. Prevent Path Traversal

```dart
// ✅ Validate file paths are within app directory
Future<bool> isPathSafe(String path) async {
  final appDir = await getApplicationDocumentsDirectory();
  final file = File(path);
  final canonicalPath = file.absolute.path;

  // Ensure path is within app directory
  if (!canonicalPath.startsWith(appDir.path)) {
    logger.error('Security: Path traversal attempt blocked: $path');
    return false;
  }

  return true;
}

// Use before scheduling file operations
Future<void> scheduleFileUpload(String filePath) async {
  if (!await isPathSafe(filePath)) {
    logger.error('Rejecting upload: unsafe path');
    return;
  }

  await NativeWorkManager.enqueue(...);
}
```

---

## 📈 Success Metrics

Track these metrics in production:

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| **Task Success Rate** | >95% | <90% |
| **Task Completion Time** | <30s (native), <5min (Dart) | >2x expected |
| **Error Rate** | <5 errors/hour | >10 errors/hour |
| **Queue Depth** | <10 pending | >50 pending |
| **Memory Usage** | <50MB per task | >100MB |
| **Battery Impact** | <2% per day | >5% per day |

---

## 🆘 Getting Help

- **GitHub Issues:** https://github.com/brewkits/native_workmanager/issues
- **Documentation:** https://pub.dev/packages/native_workmanager
- **Discussions:** https://github.com/brewkits/native_workmanager/discussions

---

**Last Updated:** 2026-02-07
**Version:** 0.8.1
**Status:** Beta - Production-ready for non-critical tasks
