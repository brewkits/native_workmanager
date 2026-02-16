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

## Installation

### 1. Add Dependency

Add to your `pubspec.yaml`:

```yaml
dependencies:
  native_workmanager: ^1.0.1
```

Run:
```bash
flutter pub get
```

### 2. No Additional Android Configuration Needed!

Unlike some Flutter plugins, `native_workmanager` **does NOT require**:
- ❌ Custom Application class
- ❌ AndroidManifest.xml modifications
- ❌ Gradle plugin additions
- ❌ ProGuard rules (unless heavily obfuscating)

The plugin automatically:
- ✅ Initializes Koin dependency injection
- ✅ Registers all native workers
- ✅ Configures WorkManager
- ✅ Sets up notification channels (for debug mode)

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
  );

  runApp(MyApp());
}

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

## Verification

### 1. Check Build Configuration

Run the following to verify your setup:

```bash
# Clean build
flutter clean

# Verify dependencies
flutter pub get

# Build Android app
flutter build apk --debug
```

### 2. Check Logcat

After scheduling a task, check Android Logcat for initialization logs:

```bash
adb logcat -s NativeWorkmanagerPlugin
```

**Expected output:**
```
✅ Koin initialized with kmpworkmanager v2.3.0 from Maven Central
✅ Task scheduled: your-task-id
[NativeWorkManager] Task started: your-task-id
[NativeWorkManager] Task completed: your-task-id (success)
```

### 3. Force Run Task (Debug Only)

To test immediately without waiting:

```bash
# List all scheduled jobs
adb shell dumpsys jobscheduler | grep -A 20 "your.package.name"

# Force run next job
adb shell cmd jobscheduler run -f your.package.name 1
```

---

## Troubleshooting

### Error: "KmpWorkManager not initialized"

**Cause:** `NativeWorkManager.initialize()` was not called or failed.

**Solution:**
1. Ensure `initialize()` is called in `main()` before `runApp()`
2. Check that it completes (use `await`)
3. Check Logcat for initialization errors

```dart
// ❌ Wrong - missing await
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NativeWorkManager.initialize();  // Not awaited!
  runApp(MyApp());
}

// ✅ Correct
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize();  // Awaited!
  runApp(MyApp());
}
```

---

### Error: "Unresolved reference: kmpworkmanager"

**Cause:** Build cache corruption or dependency resolution issue.

**Solution:**
```bash
# Clean everything
flutter clean
cd android
./gradlew clean
cd ..

# Remove build folders
rm -rf android/build
rm -rf android/app/build

# Rebuild
flutter pub get
flutter build apk --debug
```

---

### Error: "Minimum SDK version is X but should be 26"

**Cause:** Your app's `minSdk` is below 26.

**Solution:**
Edit `android/app/build.gradle`:
```gradle
defaultConfig {
    minSdk 26  // Change from lower version to 26
}
```

**Impact:** This drops support for Android 7.1 and below (released 2016).

**Market share (2024):** Android 8.0+ covers >95% of devices.

---

### Error: "WorkManager initialization failed"

**Cause:** Conflicting WorkManager versions or initialization.

**Solution:**
1. Check for custom WorkManager initialization in your Android code
2. Remove any manual WorkManager initialization - the plugin handles it
3. Ensure no other plugins are initializing WorkManager

---

### Tasks Not Running in Background

**Possible causes:**
1. **Battery optimization:** Android may throttle background work
2. **Doze mode:** Tasks deferred during deep sleep
3. **App standby:** Inactive apps have restricted background access

**Solutions:**

**1. Add Constraints**
```dart
await NativeWorkManager.enqueue(
  taskId: 'my-task',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  constraints: Constraints(
    requiresNetworkType: NetworkType.connected,
    requiresBatteryNotLow: true,
  ),
);
```

**2. Test Without Battery Optimization**
```bash
# Disable battery optimization for your app (testing only)
adb shell dumpsys deviceidle whitelist +your.package.name
```

**3. Check Battery Optimization Settings**
- Settings → Apps → Your App → Battery → Unrestricted

---

### High Memory Usage

**Cause:** Using Dart workers instead of native workers.

**Solution:**
```dart
// ❌ Dart worker - 50 MB RAM
DartWorker(callbackId: 'httpRequest')

// ✅ Native worker - 5 MB RAM
NativeWorker.httpRequest(url: '...')
```

Use native workers for I/O tasks, Dart workers only for complex logic.

---

## Advanced Configuration

### Custom Native Workers

If you need to register custom native workers:

**1. Create worker class:**
```kotlin
// android/app/src/main/kotlin/com/example/yourapp/workers/CustomWorker.kt
package com.example.yourapp.workers

import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorkerResult

class CustomWorker : AndroidWorker {
    override suspend fun doWork(inputJson: String?): AndroidWorkerResult {
        // Your custom logic here
        return AndroidWorkerResult.success(outputJson = """{"status":"done"}""")
    }
}
```

**2. Register in MainActivity:**
```kotlin
// android/app/src/main/kotlin/com/example/yourapp/MainActivity.kt
package com.example.yourapp

import dev.brewkits.native_workmanager.SimpleAndroidWorkerFactory
import dev.brewkits.kmpworkmanager.background.domain.AndroidWorkerFactory
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Register custom workers BEFORE Flutter engine starts
        SimpleAndroidWorkerFactory.setUserFactory(object : AndroidWorkerFactory {
            override fun createWorker(workerClassName: String): AndroidWorker? {
                return when (workerClassName) {
                    "CustomWorker" -> CustomWorker()
                    else -> null
                }
            }
        })
    }
}
```

**3. Use in Dart:**
```dart
await NativeWorkManager.enqueue(
  taskId: 'custom-task',
  trigger: TaskTrigger.oneTime(),
  worker: CustomWorker(
    input: {'key': 'value'},
  ),
);
```

[See full custom workers guide →](use-cases/07-custom-native-workers.md)

---

## ProGuard / R8 Configuration

If you're using code obfuscation, add these rules to `android/app/proguard-rules.pro`:

```proguard
# Keep native_workmanager classes
-keep class dev.brewkits.native_workmanager.** { *; }
-keep class dev.brewkits.kmpworkmanager.** { *; }

# Keep worker classes
-keep class * implements dev.brewkits.kmpworkmanager.background.domain.AndroidWorker { *; }

# Keep Koin
-keep class org.koin.** { *; }
-keep interface org.koin.** { *; }

# Keep WorkManager
-keep class androidx.work.** { *; }
```

---

## Testing

### Unit Testing

No special Android configuration needed for unit tests.

### Integration Testing

For integration tests on real devices:

```bash
# Run tests on connected device
flutter test integration_test/app_test.dart
```

### Debug Mode

Enable debug notifications to see task events:

```dart
await NativeWorkManager.initialize(
  debugMode: true,  // Shows notifications for all task events
);
```

**Note:** Debug notifications only show on debug builds.

---

## Performance Tips

### 1. Use Native Workers for I/O
```dart
// ✅ Fast - native worker (5 MB)
NativeWorker.httpSync(url: '...')

// ❌ Slow - Dart worker (50 MB)
DartWorker(callbackId: 'httpSync')
```

### 2. Enable autoDispose for Dart Workers
```dart
DartWorker(
  callbackId: 'processData',
  autoDispose: true,  // ✅ Releases Flutter Engine after task
)
```

### 3. Use Constraints to Reduce Battery Impact
```dart
constraints: Constraints(
  requiresCharging: true,     // Only run when charging
  requiresDeviceIdle: true,   // Only run when device idle
)
```

---

## Production Checklist

Before releasing to production:

- [ ] Verify `minSdk` is 26 or higher
- [ ] Test on multiple Android versions (8.0, 9.0, 10, 11, 12, 13, 14)
- [ ] Test with battery optimization enabled
- [ ] Test in Doze mode (simulate: `adb shell dumpsys battery unplug && adb shell dumpsys deviceidle force-idle`)
- [ ] Verify tasks run after app force-close
- [ ] Verify tasks run after device reboot
- [ ] Test task chains with failures
- [ ] Monitor memory usage (use Android Profiler)
- [ ] Check ProGuard/R8 doesn't break workers (if using obfuscation)
- [ ] Add error handling and retry policies
- [ ] Set up monitoring/analytics for background tasks

[See full production guide →](PRODUCTION_GUIDE.md)

---

## Platform-Specific Behavior

### Doze Mode (Android 6.0+)

Tasks may be deferred during Doze mode. To ensure execution:

```dart
// For critical tasks
constraints: Constraints(
  requiresNetworkType: NetworkType.connected,
)

// For non-critical tasks
constraints: Constraints(
  requiresDeviceIdle: false,  // Run even when active
)
```

### App Standby (Android 6.0+)

Inactive apps have restricted background access. Tasks will run but may be delayed.

**Solution:** Use appropriate trigger intervals (15+ minutes recommended).

### Battery Optimization (Android 8.0+)

Background execution limits affect all apps. Native workers help by reducing overhead.

---

## Next Steps

- [Getting Started Guide](GETTING_STARTED.md)
- [API Reference](API_REFERENCE.md)
- [iOS Setup Guide](IOS_SETUP.md)
- [Production Deployment](PRODUCTION_GUIDE.md)
- [Custom Native Workers](use-cases/07-custom-native-workers.md)

---

## Support

**Need help?**
- 📧 Email: datacenter111@gmail.com
- 🐛 Issues: [GitHub Issues](https://github.com/brewkits/native_workmanager/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/brewkits/native_workmanager/discussions)

---

**Last Updated:** February 2026 (v1.0.1)
