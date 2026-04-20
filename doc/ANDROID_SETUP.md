# Android Setup Guide

This guide covers Android-specific configuration for `native_workmanager`.

---

## Prerequisites

- Android Studio Arctic Fox (2020.3.1) or later
- Kotlin 1.9.0+
- Gradle 7.0+
- Flutter SDK 3.0+

---

## Minimum Requirements

### 1. Minimum SDK Version

The plugin requires **Android API 26 (Android 8.0)** as the minimum SDK version.

**Edit `android/app/build.gradle`:**

```gradle
android {
    compileSdk 34

    defaultConfig {
        applicationId "com.example.yourapp"
        minSdk 26  // ⚠️ REQUIRED: Must be 26 or higher
        targetSdk 34
        versionCode 1
        versionName "1.0"
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}
```

**Why API 26?**
- Android WorkManager requires API 23+ for basic functionality
- Native workers use advanced features requiring API 26+
- Ensures consistent behavior across Android versions

---

### 2. Android 14+ (API 34) Compatibility

Starting with Android 14 (API 34), you **must** declare a `foregroundServiceType` for any service that runs in the foreground. The plugin defaults to `dataSync`.

If your background tasks involve operations other than data synchronization (e.g., location tracking, media playback), you must override the service declaration in your app's `android/app/src/main/AndroidManifest.xml`:

```xml
<service
    android:name="androidx.work.impl.foreground.SystemForegroundService"
    android:foregroundServiceType="yourTypeHere"
    tools:node="replace" />
```

---

## Installation

### 1. Add Dependency

Add to your `pubspec.yaml`:

```yaml
dependencies:
  native_workmanager: ^1.2.1
```

Run:
```bash
flutter pub get
```

### 2. Basic Setup (Native Workers Only)

For **native workers** (HTTP, file, crypto, image, PDF, etc.) no extra Android configuration is
needed. The plugin automatically:

- ✅ Registers all built-in native workers
- ✅ Initializes WorkManager with the plugin's `WorkerFactory`
- ✅ Sets up notification channels (for debug mode)

---

### 3. Required: Killed-App Support for Dart Workers

> **This section only applies if you use `DartWorker`.** Native-worker-only apps can skip it.

When Android kills your app (low memory, user swipe) and WorkManager fires a scheduled
`DartWorker`, the process restarts **without Flutter**. Two things must happen for the task
to succeed:

| Requirement | Who handles it |
|---|---|
| Restore `callbackHandle` so `FlutterEngineManager` can boot Dart | **Plugin** — persisted automatically to SharedPreferences during `initialize()` |
| Provide `KmpWorkerFactory` so WorkManager can create `KmpWorker` | **Host app** — must implement `Configuration.Provider` on the `Application` class |

The second requirement cannot be automated by the plugin: Android's `Configuration.Provider`
interface must be on the host app's `Application` class.

#### Step 1 — Create (or update) your `Application` class

```kotlin
// android/app/src/main/kotlin/com/example/myapp/MyApplication.kt
package com.example.myapp

import android.content.Context
import androidx.work.Configuration
import androidx.work.DelegatingWorkerFactory
import dev.brewkits.kmpworkmanager.background.KmpWorkerFactory
import dev.brewkits.native_workmanager.SimpleAndroidWorkerFactory
import dev.brewkits.native_workmanager.engine.FlutterEngineManager
import io.flutter.app.FlutterApplication

class MyApplication : FlutterApplication(), Configuration.Provider {

    override fun onCreate() {
        super.onCreate()

        // Restore callbackHandle that the plugin persisted during Dart-side initialize().
        // SharedPreferences name and key mirror the plugin's internal constants.
        val handle = getSharedPreferences(
            "dev.brewkits.native_workmanager", Context.MODE_PRIVATE
        ).getLong("callback_handle", -1L)

        if (handle != -1L) {
            FlutterEngineManager.setCallbackHandle(handle)
        }
    }

    // WorkManager calls this when the process is restarted after being killed,
    // before any Flutter engine or plugin is loaded.
    // It is NOT called during a normal app launch (plugin already initialized WorkManager first).
    override fun getWorkManagerConfiguration(): Configuration {
        val factory = DelegatingWorkerFactory().apply {
            addFactory(KmpWorkerFactory(SimpleAndroidWorkerFactory(this@MyApplication)))
        }
        return Configuration.Builder()
            .setWorkerFactory(factory)
            .build()
    }
}
```

If you also register custom native workers, pass your user factory to `SimpleAndroidWorkerFactory`:

```kotlin
addFactory(KmpWorkerFactory(SimpleAndroidWorkerFactory(this, myUserFactory)))
```

#### Step 2 — Register the Application class in `AndroidManifest.xml`

```xml
<application
    android:name=".MyApplication"
    ...>
```

#### Step 3 — Disable WorkManager's default auto-initializer

WorkManager ships a `ContentProvider`-based initializer that runs before `Application.onCreate()`
and initializes WorkManager with the **default** (no custom factory) configuration. If it fires
first, your `Configuration.Provider` is ignored and `KmpWorker` creation fails.

Remove it in `android/app/src/main/AndroidManifest.xml`:

```xml
<provider
    android:name="androidx.startup.InitializationProvider"
    android:authorities="${applicationId}.androidx-startup"
    android:exported="false"
    tools:node="merge">
    <!-- Remove the default WorkManager initializer so Configuration.Provider is used instead -->
    <meta-data
        android:name="androidx.work.WorkManagerInitializer"
        android:value="androidx.startup"
        tools:node="remove" />
</provider>
```

Add the `tools` namespace to the `<manifest>` tag if not already present:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
```

#### How the two startup paths interact

```
Normal launch:
  Application.onCreate() → restore callbackHandle only
  Flutter plugin onAttachedToEngine() → KmpWorkManager.initialize() → WorkManager initialized ✅
  Configuration.Provider.getWorkManagerConfiguration() → NOT called (already initialized)

Killed-app restart (WorkManager fires a task):
  Application.onCreate() → restore callbackHandle ✅
  WorkManager not yet initialized → calls getWorkManagerConfiguration() ✅
  KmpWorkerFactory creates KmpWorker → DartCallbackWorker runs
  FlutterEngineManager uses restored callbackHandle to boot Dart engine ✅
```

#### Battery optimisation (OS constraint)

On most Android devices users must **exempt your app from battery optimisation** for WorkManager
to run tasks reliably after the app is killed. This is an OS constraint, not a plugin limitation.

Prompt the user from your settings screen:
```dart
import 'package:flutter/services.dart';

// Android-only — check and request battery optimisation exemption
const _channel = MethodChannel('your_app/battery');
await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
```

On the Kotlin side:
```kotlin
val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
    data = Uri.parse("package:${packageName}")
}
startActivity(intent)
```

---

## Initialization

### Basic Initialization

```dart
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize before runApp()
  await NativeWorkManager.initialize();

  runApp(MyApp());
}
```

### Advanced Initialization (with Dart Workers)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NativeWorkManager.initialize(
    dartWorkers: {
      'processData': _processDataCallback,
      'syncDatabase': _syncDatabaseCallback,
    },
    // When using other plugins (like flutter_local_notifications) in the background
    registerPlugins: true,
    // Security options
    enforceHttps: true,
    blockPrivateIPs: true,
    // Maintenance
    cleanupAfterDays: 30,
  );

  runApp(MyApp());
}

// Must be top-level or static — NOT a closure or instance method
@pragma('vm:entry-point')
Future<bool> _processDataCallback(Map<String, dynamic>? input) async {
  // Your Dart logic here
  return true;
}

@pragma('vm:entry-point')
Future<bool> _syncDatabaseCallback(Map<String, dynamic>? input) async {
  // Database sync logic
  return true;
}
```

---

## Custom Native Workers

If you need to register custom native workers:

**1. Create your worker:**
```kotlin
// android/app/src/main/kotlin/com/example/yourapp/workers/AnalyticsFlushWorker.kt
package com.example.yourapp.workers

import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorkerResult

class AnalyticsFlushWorker : AndroidWorker {
    override suspend fun doWork(inputJson: String?): AndroidWorkerResult {
        // flush analytics
        return AndroidWorkerResult.success()
    }
}
```

**2. Register the factory — two patterns depending on your setup:**

*Without killed-app support (no custom Application):*
```kotlin
// In MainActivity.kt, before super.onCreate()
SimpleAndroidWorkerFactory.setUserFactory { workerClassName ->
    when (workerClassName) {
        "AnalyticsFlushWorker" -> AnalyticsFlushWorker()
        else -> null
    }
}
```

*With killed-app support (custom Application from §3):*

Pass the factory in `getWorkManagerConfiguration()` and also set it at launch:
```kotlin
// MyApplication.kt
private val userFactory = AndroidWorkerFactory { workerClassName ->
    when (workerClassName) {
        "AnalyticsFlushWorker" -> AnalyticsFlushWorker()
        else -> null
    }
}

override fun onCreate() {
    super.onCreate()
    // ... restore callbackHandle ...
    // Make the factory available before Flutter loads
    SimpleAndroidWorkerFactory.setUserFactory(userFactory)
}

override fun getWorkManagerConfiguration(): Configuration {
    val factory = DelegatingWorkerFactory().apply {
        addFactory(KmpWorkerFactory(SimpleAndroidWorkerFactory(this@MyApplication, userFactory)))
    }
    return Configuration.Builder().setWorkerFactory(factory).build()
}
```

**3. Use in Dart:**
```dart
await NativeWorkManager.enqueue(
  taskId: 'flush-analytics',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.custom(
    workerClassName: 'AnalyticsFlushWorker',
    input: {'batchSize': 100},
  ),
);
```

[See full custom workers guide →](use-cases/07-custom-native-workers.md)

---

## Verification

### Check Logcat

After scheduling a task, check Android Logcat:

```bash
adb logcat -s NativeWorkmanagerPlugin,FlutterEngineManager,DartCallbackWorker
```

**Expected on first launch:**
```
NativeWorkmanagerPlugin: ✅ Scheduler initialized with kmpworkmanager
NativeWorkmanagerPlugin: callbackHandle persisted for cold-start: 12345678
```

**Expected on killed-app restart:**
```
MyApplication: Restored callbackHandle from prefs: 12345678
FlutterEngineManager: Initializing Flutter engine... (cold process start)
FlutterEngineManager: Dart ready signal received
```

### Force-Run a Task (Debug)

```bash
# List scheduled jobs
adb shell dumpsys jobscheduler | grep -A 20 "your.package.name"

# Force-run the next pending job
adb shell cmd jobscheduler run -f your.package.name 1
```

---

## Troubleshooting

### DartWorker fails after app kill

**Symptoms:** Native workers run fine; `DartWorker` silently fails after process death.

**Checklist:**
1. Did you add the custom `Application` class? (§3, Step 1)
2. Is the Application class registered in `AndroidManifest.xml`? (§3, Step 2)
3. Did you remove the default WorkManager initializer? (§3, Step 3)
4. Is battery optimisation disabled for your app during testing?
5. Check Logcat for `getWorkManagerConfiguration() called` — if missing, Step 3 is incomplete.

### Other plugins (notifications, etc.) not working in DartWorker

**Symptoms:** Your `DartWorker` runs, but other plugins like `flutter_local_notifications` or `shared_preferences` don't seem to work or throw errors.

**Solution:**
Enable plugin registration during initialization:
```dart
await NativeWorkManager.initialize(
  registerPlugins: true,
  dartWorkers: { ... },
);
```
By default, the background engine does **not** register plugins to save RAM and avoid side-effects (like disconnecting Bluetooth).

**Selective Plugin Registration (Alternative)**
If you want to keep `registerPlugins: false` to avoid side-effects but still need a specific plugin, use the native callback in `MainApplication.kt`:

```kotlin
NativeWorkmanagerPlugin.setPluginRegistrantCallback(object : NativeWorkmanagerPlugin.Companion.PluginRegistrantCallback {
    override fun registerWith(engine: io.flutter.embedding.engine.FlutterEngine) {
        // Use the new embedding API to add specific plugins
        engine.plugins.add(com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin())
    }
})
```

---

### Error: "KmpWorkManager not initialized"

**Cause:** `NativeWorkManager.initialize()` was not called or failed.

**Solution:**
```dart
// ❌ Wrong — missing await
void main() {
  NativeWorkManager.initialize();  // Not awaited!
  runApp(MyApp());
}

// ✅ Correct
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize();
  runApp(MyApp());
}
```

---

### Error: "Unresolved reference: kmpworkmanager"

```bash
flutter clean
cd android && ./gradlew clean && cd ..
flutter pub get
flutter build apk --debug
```

---

### Error: "Minimum SDK version is X but should be 26"

Edit `android/app/build.gradle`:
```gradle
defaultConfig {
    minSdk 26
}
```

---

### Error: "WorkManager already initialized" / crash on hot-restart

This was a known v1.0.7 bug (H-2). Fixed by resetting `isSchedulerInitialized = false` in
`onDetachedFromEngine`. Ensure you are on v1.0.7 or later.

---

### Tasks not running in background

1. **Battery optimisation** — request exemption (see §3 above)
2. **Doze mode** — use `Constraints(requiresNetwork: true)` to let WorkManager reschedule
3. **App standby** — use periodic intervals ≥ 15 minutes
4. **Simulate Doze mode:**
   ```bash
   adb shell dumpsys battery unplug
   adb shell dumpsys deviceidle force-idle
   ```

---

### High memory usage

Use native workers for I/O — they don't spin up a Flutter engine:

```dart
// ❌ Dart worker — ~50 MB RAM, 1–2 s cold start
DartWorker(callbackId: 'httpRequest')

// ✅ Native worker — ~2–5 MB RAM, <50 ms cold start
NativeWorker.httpRequest(url: '...')
```

---

## ProGuard / R8 Configuration

```proguard
# native_workmanager
-keep class dev.brewkits.native_workmanager.** { *; }
-keep class dev.brewkits.kmpworkmanager.** { *; }

# Keep WorkManager worker classes
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class * implements dev.brewkits.kmpworkmanager.background.domain.AndroidWorker { *; }

# WorkManager
-keep class androidx.work.** { *; }
```

---

## Production Checklist

- [ ] `minSdk` is 26 or higher
- [ ] Tested on Android 8, 10, 12, 14+
- [ ] If using `DartWorker`: custom Application + `Configuration.Provider` in place
- [ ] If using `DartWorker`: WorkManager default initializer removed from manifest
- [ ] Battery optimisation exemption UI implemented and tested
- [ ] Tested: tasks run after app force-close (with battery opt disabled)
- [ ] Tested: tasks run after device reboot
- [ ] Tested: task chains with mid-chain failure
- [ ] Memory profiled (Android Profiler) — no engine leak after `autoDispose`
- [ ] ProGuard/R8 tested if using obfuscation
- [ ] `debugMode: false` (or omitted) in release builds

---

## Platform-Specific Behaviour

### Doze Mode (Android 6.0+)

Tasks can be deferred during Doze. WorkManager handles rescheduling automatically. For
time-sensitive work use `Constraints(requiresCharging: false)` and accept eventual execution.

### App Standby (Android 6.0+)

Inactive apps get background-access buckets (Active → Working set → Frequent → Rare → Restricted).
Use intervals ≥ 15 minutes and constrained tasks to stay in higher buckets.

### Exact Alarms (Android 12+)

`TaskTrigger.exact()` requires `SCHEDULE_EXACT_ALARM` permission on Android 12+. WorkManager falls
back to an inexact trigger if the permission is not granted (`ScheduleResult.rejectedOsPolicy`).
Check the result:
```dart
final handler = await NativeWorkManager.enqueue(...);
if (handler.scheduleResult == ScheduleResult.rejectedOsPolicy) {
  // prompt user to grant exact alarm permission
}
```

---

## Next Steps

- [Getting Started Guide](GETTING_STARTED.md)
- [API Reference](API_REFERENCE.md)
- [iOS Setup Guide](IOS_SETUP.md)
- [Custom Native Workers](use-cases/07-custom-native-workers.md)

---

**Last Updated:** April 2026 (v1.2.1)
