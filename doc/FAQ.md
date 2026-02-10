# Frequently Asked Questions (FAQ)

## General Questions

### Q: Will my task run if the app is force-closed?

**A:** Yes! Tasks are registered with the OS (Android WorkManager / iOS BGTaskScheduler), not your Flutter app. They survive:
- App force-close
- Phone reboot
- App uninstall → reinstall (if task IDs are consistent)

---

### Q: How much memory does a task actually use?

**A:** It depends on the worker type:

| Worker Type | Memory Usage | Startup Time |
|-------------|--------------|--------------|
| **Native Workers** | 2-5 MB | <100ms |
| **Dart Workers** | ~50 MB | 200-500ms |
| **Custom Native Workers** | Varies (typically 1-10 MB) | <100ms |

**Why the difference?**
- Native workers execute without starting Flutter engine
- Dart workers need full Flutter engine initialization

---

### Q: Can I chain 100 tasks together?

**A:** Technically yes, but **not recommended** for several reasons:

**iOS Limitation:**
- Each task in chain must complete within 30 seconds
- iOS may cancel long chains
- **Recommendation:** Keep chains to 3-5 tasks max on iOS

**Android:**
- No strict limit, but very long chains can be fragile
- **Recommendation:** Keep chains to 5-10 tasks max

**Better approach:**
```dart
// Instead of: Task1 → Task2 → ... → Task100
// Use: Periodic task that processes batches
NativeWorkManager.enqueue(
  taskId: 'batch-processor',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: DartWorker(callbackId: 'processBatch'),
);
```

---

### Q: What happens if a task in a chain fails?

**A:** The chain stops at the failed task:

1. **Tasks before failure:** ✅ Completed successfully
2. **Failed task:** ❌ Marked as failed
3. **Tasks after failure:** ⏸️ Not executed (cancelled)

**Example:**
```
TaskA (✅) → TaskB (❌ FAILS) → TaskC (⏸️ Skipped) → TaskD (⏸️ Skipped)
```

**Retry behavior:**
- If you configured retry policy, the failed task retries
- Chain continues only if retry succeeds
- If all retries fail, chain stops permanently

---

### Q: Is this compatible with flutter_workmanager?

**A:** ~90% API compatible with minor syntax changes required.

**Main differences:**
1. **Import:** `import 'package:native_workmanager/native_workmanager.dart';`
2. **Initialization:** `NativeWorkManager.initialize()` vs `Workmanager.initialize()`
3. **Enqueue syntax:** Different trigger API
4. **Native workers:** New capability not in flutter_workmanager

[See full migration guide →](MIGRATION_GUIDE.md)

---

### Q: Can I use this for continuous location tracking?

**A:** No, background tasks are for **periodic work**, not continuous tracking.

**Why?**
- Tasks run at intervals (minimum 15 minutes on iOS, 15-30 minutes on Android)
- Tasks have execution time limits (30 seconds on iOS, 10 minutes on Android)
- OS may defer tasks to save battery

**For location tracking, use:**
- [`geolocator`](https://pub.dev/packages/geolocator) with background modes
- [`background_location`](https://pub.dev/packages/background_location)
- Foreground service on Android

**Use native_workmanager for:**
- Upload location batches every hour
- Process and sync location logs
- Periodic geofence checks

---

### Q: Do tasks run when device is in Doze mode?

**A:** It depends on constraints:

**Android Doze Mode:**
- Tasks **are deferred** during Doze mode by default
- Use constraints to wait for appropriate conditions:

```dart
constraints: Constraints(
  requiresNetwork: true,        // Wait for network
  requiresCharging: true,        // Wait for charging
  requiresBatteryNotLow: true,  // Wait until battery is OK
)
```

**iOS Low Power Mode:**
- Background tasks have lower priority
- May be delayed or skipped
- Use `requiresCharging: true` for critical tasks

---

### Q: Can I schedule exact-time tasks (e.g., alarm at 7:00 AM)?

**A:** No, native_workmanager is for **flexible background tasks**, not exact alarms.

**Why?**
- iOS doesn't support exact-time background tasks
- Android Doze mode defers tasks anyway
- Background tasks are designed for flexibility

**For exact alarms, use:**
- [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications)
- [`android_alarm_manager_plus`](https://pub.dev/packages/android_alarm_manager_plus) (Android only)
- Platform channels to native alarm APIs

**Use native_workmanager for:**
- Periodic work that can be flexible (±15 minutes is OK)
- Background data sync
- File processing tasks

---

### Q: How do I debug background tasks?

**A:** Follow these strategies:

**1. Use logging:**
```dart
worker: DartWorker(
  callbackId: 'myTask',
  onProgress: (progress) {
    print('Task progress: $progress'); // Won't show in release
    // Use proper logging instead:
    developer.log('Task progress: $progress', name: 'NativeWorkManager');
  },
)
```

**2. Listen to task events:**
```dart
NativeWorkManager.events.listen((event) {
  print('Task ${event.taskId}: ${event.success ? "✅" : "❌"}');
  print('Message: ${event.message}');
});
```

**3. Check native logs:**

**iOS:** Use Xcode Console while device is connected
**Android:** Use `adb logcat` or Android Studio Logcat

**4. Test in foreground first:**
```dart
// Test task logic in foreground before background
await myTaskLogic();  // Test this works
// Then schedule as background task
```

---

### Q: Can I pass data between tasks in a chain?

**A:** Currently, data passing between tasks is **not directly supported** in v1.0.0.

**Workaround (v1.0.0):**
Use shared storage:

```dart
// Task 1: Save result
await NativeWorkManager.enqueue(
  taskId: 'task1',
  worker: DartWorker(callbackId: 'saveData'),
);

// In callback:
void saveData() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('task1_result', jsonEncode(result));
}

// Task 2: Read result
await NativeWorkManager.beginWith(
  TaskRequest(id: 'task1', worker: DartWorker(callbackId: 'saveData')),
).then(
  TaskRequest(id: 'task2', worker: DartWorker(callbackId: 'useData')),
).enqueue();

// In callback:
void useData() async {
  final prefs = await SharedPreferences.getInstance();
  final data = jsonDecode(prefs.getString('task1_result')!);
  // Use data...
}
```

**Coming in v1.1:**
- Native variable passing between tasks
- Automatic data serialization

---

### Q: What's the minimum interval for periodic tasks?

**A:** Platform-specific minimums:

| Platform | Minimum Interval | Notes |
|----------|------------------|-------|
| **Android** | 15 minutes | WorkManager API limitation |
| **iOS** | 15 minutes | BGTaskScheduler limitation |

**Example:**
```dart
// ✅ Works (1 hour)
trigger: TaskTrigger.periodic(Duration(hours: 1))

// ⚠️ Will be clamped to 15 minutes
trigger: TaskTrigger.periodic(Duration(minutes: 5))

// ❌ Will fail
trigger: TaskTrigger.periodic(Duration(seconds: 30))
```

---

### Q: Do I need internet permission?

**A:** Only if your tasks use network:

**Android (`android/app/src/main/AndroidManifest.xml`):**
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

**iOS (`ios/Runner/Info.plist`):**
- Network access allowed by default
- If using HTTP (not HTTPS), configure App Transport Security

**Permissions for workers:**
- HTTP workers: Need INTERNET permission
- File workers: No special permissions
- Crypto workers: No special permissions

---

### Q: Can I use this with other background plugins?

**A:** Yes, but avoid conflicts:

**Compatible:**
- ✅ `flutter_local_notifications` - Different use case (notifications vs tasks)
- ✅ `geolocator` - Can coexist (use geolocator for continuous, native_workmanager for periodic)
- ✅ `shared_preferences` - Perfect for task data storage

**Potential conflicts:**
- ⚠️ `flutter_workmanager` - Same underlying APIs, choose one
- ⚠️ `workmanager` - Same underlying APIs, choose one

**Best practice:**
Use native_workmanager as your primary background task solution.

---

### Q: How do I handle task failures?

**A:** Use retry policies and constraints:

```dart
await NativeWorkManager.enqueue(
  taskId: 'critical-sync',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  constraints: Constraints(
    requiresNetwork: true,
    backoffPolicy: BackoffPolicy.exponential,  // Exponential backoff
    backoffDelayMs: 30000,  // Start with 30s delay
    maxAttempts: 5,  // Retry up to 5 times
  ),
);
```

**Retry strategies:**
- `BackoffPolicy.linear`: Fixed delay (30s, 30s, 30s, ...)
- `BackoffPolicy.exponential`: Growing delay (30s, 60s, 120s, 240s, ...)

---

### Q: Where can I get help?

**Support channels:**
- 💬 [GitHub Discussions](https://github.com/brewkits/native_workmanager/discussions) - Ask questions
- 🐛 [Issue Tracker](https://github.com/brewkits/native_workmanager/issues) - Report bugs
- 📖 [Documentation](../README.md) - Comprehensive guides
- 📧 Email: support@brewkits.dev - Direct support

**Before asking:**
1. Check this FAQ
2. Read [Getting Started Guide](GETTING_STARTED.md)
3. Review [Use Cases](use-cases/) for similar scenarios
4. Search [existing issues](https://github.com/brewkits/native_workmanager/issues)

---

## Platform-Specific Questions

### iOS: Why isn't my task running?

**Common reasons:**

1. **Task not triggered yet**
   - iOS defers background tasks
   - Test by backgrounding app, waiting 30+ seconds

2. **30-second limit exceeded**
   - Tasks must complete in 30 seconds
   - Use native workers (5x faster)
   - Split into chains

3. **Low Power Mode active**
   - iOS deprioritizes background tasks
   - Add `requiresCharging: true` constraint

4. **BGTaskScheduler not configured**
   - Check `Info.plist` has `BGTaskSchedulerPermittedIdentifiers`
   - See [iOS Guide](IOS_BACKGROUND_LIMITS.md)

---

### Android: Why is my task delayed?

**Common reasons:**

1. **Doze Mode**
   - Android defers tasks in Doze
   - Use `requiresCharging: true` or wait for idle window

2. **Battery Saver Mode**
   - Tasks have lower priority
   - Use `requiresBatteryNotLow: true`

3. **Network constraint not met**
   - Task waits for network
   - Check `requiresNetwork: true` constraint

4. **Minimum interval not met**
   - Periodic tasks minimum: 15 minutes
   - Check your trigger interval

---

## Advanced Questions

### Q: Can I create custom native workers in Kotlin/Swift?

**A:** Yes! See [Custom Native Workers Guide](EXTENSIBILITY.md)

**Quick example:**

**Kotlin:**
```kotlin
class MyCustomWorker : AndroidWorker {
    override suspend fun doWork(input: String?): WorkerResult {
        // Your Kotlin code here
        return WorkerResult.success("Done!")
    }
}
```

**Swift:**
```swift
class MyCustomWorker: IosWorker {
    func doWork(input: String?) async throws -> WorkerResult {
        // Your Swift code here
        return WorkerResult.success(data: "Done!")
    }
}
```

---

### Q: What's the performance impact on app startup?

**A:** Minimal impact:

**Initialization:**
- Native platform APIs (WorkManager, BGTaskScheduler)
- **Time:** <10ms on modern devices
- **Memory:** <1MB

**Background task execution:**
- No impact on app foreground performance
- Tasks run in separate process/thread

---

### Q: Is this suitable for enterprise apps?

**A:** Yes! Production-ready features:

- ✅ **Security audited** - No critical vulnerabilities
- ✅ **462 tests passing** - 100% pass rate
- ✅ **Used in production** - Apps with 1M+ users
- ✅ **MIT licensed** - Commercial use allowed
- ✅ **Comprehensive docs** - 20+ guides

[See Production Guide →](PRODUCTION_GUIDE.md)

---

**Didn't find your question?**
- [Ask in Discussions](https://github.com/brewkits/native_workmanager/discussions)
- [Check documentation](../README.md)
- [Email support](mailto:support@brewkits.dev)
