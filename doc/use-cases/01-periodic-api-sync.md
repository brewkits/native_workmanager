# Use Case: Periodic API Sync

**Difficulty:** Beginner
**Platform:** Android + iOS
**Features:** Periodic triggers, Native workers, Network constraints

---

## Problem

Your app needs to sync data from a remote API every hour, even when the app is closed. The sync should:
- Run automatically in the background
- Only execute when network is available
- Use minimal battery and memory
- Continue across app restarts

Common scenarios:
- News apps refreshing articles
- Weather apps updating forecasts
- Social apps syncing notifications
- Messaging apps checking for new messages

---

## Solution

Use `TaskTrigger.periodic()` with `NativeWorker.httpSync()` for zero Flutter Engine overhead.

### Key Components

1. **Native Worker** - HTTP sync without starting Flutter Engine
2. **Periodic Trigger** - Automatic execution at regular intervals
3. **Network Constraint** - Only run when online
4. **Task Tag** - Group sync tasks for easy management

---

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize work manager
  await NativeWorkManager.initialize();

  // Schedule periodic API sync
  await schedulePeriodicSync();

  runApp(MyApp());
}

/// Schedule a periodic sync task that runs every hour
Future<void> schedulePeriodicSync() async {
  final result = await NativeWorkManager.enqueue(
    // Unique task ID
    taskId: 'api-sync',

    // Run every 1 hour (minimum is 15 minutes on Android)
    trigger: TaskTrigger.periodic(const Duration(hours: 1)),

    // Use native HTTP worker (no Flutter Engine needed)
    worker: NativeWorker.httpSync(
      url: 'https://api.example.com/sync',
      headers: {
        'Authorization': 'Bearer YOUR_TOKEN',
        'Content-Type': 'application/json',
      },
    ),

    // Only run when network is available
    constraints: Constraints.networkRequired,

    // Replace existing task if scheduling again
    existingPolicy: ExistingTaskPolicy.replace,

    // Tag for grouping (optional but recommended)
    tag: 'sync',
  );

  // Check if task was accepted
  if (result == ScheduleResult.accepted) {
    print('✅ Periodic sync scheduled successfully');
  } else if (result == ScheduleResult.rejectedOsPolicy) {
    print('⚠️ Task rejected by OS (Battery Saver mode on iOS?)');
  }
}

/// Cancel the periodic sync (e.g., when user logs out)
Future<void> cancelSync() async {
  await NativeWorkManager.cancel('api-sync');
  // Or cancel all sync tasks by tag:
  // await NativeWorkManager.cancelByTag('sync');
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('API Sync Example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: schedulePeriodicSync,
                child: Text('Start Sync'),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: cancelSync,
                child: Text('Stop Sync'),
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

1. **First execution:** ~15 minutes after scheduling (Android WorkManager optimization)
2. **Subsequent executions:** Every 1 hour (±15 minutes flexwindow)
3. **Doze mode:** Task deferred until maintenance window
4. **Battery Saver:** Task continues (unless aggressive battery saver)
5. **Network constraint:** Task waits until WiFi/mobile data available

**Timeline example:**
```
12:00 PM - Task scheduled
12:15 PM - First execution (initial delay)
01:15 PM - Second execution
02:15 PM - Third execution
... continues every hour
```

### iOS

1. **First execution:** System decides (usually within 1 hour)
2. **Subsequent executions:** Opportunistic (not guaranteed every hour)
3. **Low Power Mode:** Task throttled or skipped
4. **Background App Refresh disabled:** Task won't run
5. **Network constraint:** Task waits until network available

**Important:** iOS doesn't guarantee exact periodic intervals. Use `BGTaskScheduler` which runs tasks opportunistically.

**Timeline example:**
```
12:00 PM - Task scheduled
12:45 PM - First execution (system decided)
02:30 PM - Second execution (not exactly 1 hour)
04:15 PM - Third execution (opportunistic)
... system decides timing
```

---

## Platform Considerations

### Android Specific

**Minimum interval:**
```dart
// ❌ Too frequent - will fail
TaskTrigger.periodic(Duration(minutes: 10))  // Error!

// ✅ Minimum allowed
TaskTrigger.periodic(Duration(minutes: 15))  // OK

// ✅ Recommended for sync
TaskTrigger.periodic(Duration(hours: 1))     // Best
```

**Flex window:**
Android adds ±25% flex to periodic tasks for battery optimization:
- 1 hour interval → actual: 45-75 minutes
- 2 hour interval → actual: 90-150 minutes

**Doze mode:**
- Task deferred during deep Doze
- Runs during maintenance windows
- Use `Constraints.batteryNotLow` if urgent

### iOS Specific

**Background App Refresh:**
User must enable it in Settings:
```
Settings > General > Background App Refresh > Your App > ON
```

**Info.plist required:**
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>dev.brewkits.nativeworkmanager</string>
</array>
```

**Low Power Mode:**
- Tasks heavily throttled
- May not run until charged
- Return `ScheduleResult.rejectedOsPolicy` if blocked

**Best practice:**
Inform users that sync requires Background App Refresh enabled.

---

## Common Pitfalls

### 1. ❌ Interval Too Short (Android)

```dart
// ❌ Will throw error
await NativeWorkManager.enqueue(
  taskId: 'sync',
  trigger: TaskTrigger.periodic(Duration(minutes: 5)),  // Too short!
  worker: NativeWorker.httpSync(url: '...'),
);

// ✅ Correct
await NativeWorkManager.enqueue(
  taskId: 'sync',
  trigger: TaskTrigger.periodic(Duration(minutes: 15)),  // Minimum
  worker: NativeWorker.httpSync(url: '...'),
);
```

### 2. ❌ Not Checking Schedule Result

```dart
// ❌ Ignoring result
await NativeWorkManager.enqueue(
  taskId: 'sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpSync(url: '...'),
);
// What if it was rejected?

// ✅ Handle result
final result = await NativeWorkManager.enqueue(
  taskId: 'sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpSync(url: '...'),
);

if (result == ScheduleResult.rejectedOsPolicy) {
  // Show message to user
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Background Sync Unavailable'),
      content: Text('Please enable Background App Refresh in Settings.'),
    ),
  );
}
```

### 3. ❌ Hardcoded Credentials

```dart
// ❌ Never hardcode tokens
worker: NativeWorker.httpSync(
  url: 'https://api.example.com/sync',
  headers: {
    'Authorization': 'Bearer hardcoded_token_123',  // Security risk!
  },
)

// ✅ Load from secure storage
final token = await secureStorage.read(key: 'auth_token');
worker: NativeWorker.httpSync(
  url: 'https://api.example.com/sync',
  headers: {
    'Authorization': 'Bearer $token',
  },
)
```

### 4. ❌ Not Canceling on Logout

```dart
// ❌ Sync continues after logout
void logout() async {
  await clearUserData();
  // Forgot to cancel background tasks!
}

// ✅ Cancel all sync tasks
void logout() async {
  await clearUserData();
  await NativeWorkManager.cancelByTag('sync');  // Stop all sync tasks
  // Or: await NativeWorkManager.cancelAll();
}
```

### 5. ❌ Expecting Exact Timing

```dart
// ❌ Wrong expectation
// "The task will run at 12:00 PM, 1:00 PM, 2:00 PM exactly"

// ✅ Correct expectation
// Android: "The task will run approximately every hour (±15 minutes)"
// iOS: "The system will run the task opportunistically around every hour"
```

---

## Advanced: Listen to Completion Events

Monitor when sync tasks complete:

```dart
import 'package:native_workmanager/native_workmanager.dart';

class SyncMonitor {
  StreamSubscription? _subscription;

  void startMonitoring() {
    _subscription = NativeWorkManager.events.listen((event) {
      if (event.taskId == 'api-sync') {
        if (event.success) {
          print('✅ Sync completed: ${event.timestamp}');
          // Update UI: "Last synced: 2 minutes ago"
        } else {
          print('❌ Sync failed: ${event.message}');
          // Show retry button
        }
      }
    });
  }

  void stopMonitoring() {
    _subscription?.cancel();
  }
}
```

---

## Advanced: Dynamic Sync Interval

Adjust interval based on user activity:

```dart
import 'package:native_workmanager/native_workmanager.dart';

class AdaptiveSync {
  static Future<void> scheduleSync({required bool userActive}) async {
    // Active users: sync every 15 minutes
    // Inactive users: sync every 2 hours
    final interval = userActive
        ? Duration(minutes: 15)
        : Duration(hours: 2);

    await NativeWorkManager.enqueue(
      taskId: 'api-sync',
      trigger: TaskTrigger.periodic(interval),
      worker: NativeWorker.httpSync(
        url: 'https://api.example.com/sync',
        headers: {'Authorization': 'Bearer ${await getToken()}'},
      ),
      constraints: Constraints.networkRequired,
      existingPolicy: ExistingTaskPolicy.replace,  // Update interval
      tag: 'sync',
    );
  }
}

// Usage:
await AdaptiveSync.scheduleSync(userActive: true);   // Every 15 min
await AdaptiveSync.scheduleSync(userActive: false);  // Every 2 hours
```

---

## Related

- **File uploads:** [File Upload with Retry](02-file-upload-with-retry.md)
- **Dart workers:** [Background Cleanup](03-background-cleanup.md)
- **Task chains:** [Chain Processing](06-chain-processing.md)
- **API Reference:** See main [README.md](../../README.md)

---

## Checklist

- [ ] Initialize `NativeWorkManager` in `main()`
- [ ] Schedule periodic task with minimum 15-minute interval
- [ ] Add network constraint with `Constraints.networkRequired`
- [ ] Check `ScheduleResult` and handle `rejectedOsPolicy`
- [ ] Cancel task on logout with `cancelByTag()` or `cancel()`
- [ ] Test on both Android and iOS
- [ ] Verify task runs in background (close app and wait)
- [ ] Handle token refresh for authenticated APIs
- [ ] Inform users about iOS Background App Refresh requirement

---

*Last updated: 2026-01-27*
