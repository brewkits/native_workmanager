# native_workmanager

**The Missing Production-Ready Background Engine for Flutter.**
Zero Flutter Engine overhead · 25+ native workers · Built on Android WorkManager & Apple BGTaskScheduler.

---

## 🔬 The Science of native_workmanager

Most Flutter background libraries force you to spawn a Flutter Engine (~50MB RAM, 1-2s delay) for every background task. `native_workmanager` eliminates this overhead by using **Native Workers** written in Kotlin and Swift that handle I/O and data processing without waking Dart.

### Performance Benchmarks
| Metric | Standard Flutter Plugins | native_workmanager (Native) |
| :--- | :--- | :--- |
| **Memory Footprint** | ~50MB - 80MB | **~2MB - 5MB** |
| **Cold Start Latency** | 1,000ms - 2,500ms | **< 50ms** |
| **Battery Impact** | High (Engine overhead) | **Ultra Low** |
| **Execution Limit** | 30s (iOS) / 10m (Android) | **Optimized for OS limits** |

---

## 🚀 Key Architectural Pillars

### 1. Duality of Execution
- **Native Workers:** Run directly on Kotlin/Swift. Perfect for HTTP, Crypto, Image/Video processing, and File I/O.
- **Dart Workers:** Use for complex business logic. Features **Smart Isolate Caching** (keeps engine warm for 5 minutes) to eliminate repeat cold-starts.

### 2. Enterprise-Grade Security
- **Hardened Path Traversal:** Uses canonical path validation at the native layer.
- **Archive Safety:** Built-in protection against Zip-bomb (500MB limit) and Zip-slip.
- **SSRF Prevention:** Optional blocking of private/loopback IP addresses for background network tasks.
- **Secure Auth:** Automatic **Token Refresh** coordination and **Certificate Pinning**.

### 3. Deterministic Task Chaining
Build complex work graphs (A -> B -> [C1, C2] -> D). Every step is persisted in a **Native SQLite Store**, allowing the engine to resume precisely where it left off after an app kill or device reboot.

---

## 📦 25+ Built-in Native Workers

No third-party code. No Flutter Engine. Pure native performance.

### 🌐 Networking
- **HttpDownload:** Resume support, checksum verification, progress notifications.
- **HttpUpload:** Multi-file support, raw bytes, progress tracking.
- **HttpSync:** Light-weight API synchronization.
- **WebSocket:** Long-running background connections with persistence.

### 🔐 Security & Crypto
- **AES-256-GCM:** Authenticated encryption for files and data.
- **HashFile:** MD5, SHA-1, SHA-256, SHA-512 support.
- **CertificatePinning:** Hardened SSL/TLS trust.

### 🖼 Processing
- **ImageProcess:** Resize, compress, EXIF-correction, format conversion.
- **VideoCompress:** Native hardware-accelerated video compression.
- **PdfWorker:** Generate, merge, and protect PDF documents.

### 📁 File System
- **FileArchive:** ZIP/Unzip with security guards.
- **FileSystem:** Atomic move, recursive copy, secure delete, directory management.

---

## Quick Start

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize();
  runApp(MyApp());
}

// Schedule a native download (No Flutter Engine used!)
await NativeWorkManager.enqueue(
  taskId: 'sync-assets',
  worker: NativeWorker.httpDownload(
    url: 'https://api.example.com/data.zip',
    savePath: '/storage/data.zip',
    enableResume: true,
  ),
  constraints: Constraints(requiresNetwork: true, requiresWifi: true),
);
```

---

## Roadmap & Community

We are building the standard for Flutter background execution. See our [Roadmap](ROADMAP.md) for Phase 2 (Remote Triggers & DAG) and Phase 3 (Cloud Coordination).

- [Full Documentation](doc/README.md)
- [Best Practices](doc/WORKER_BEST_PRACTICES.md)
- [Architecture Deep-Dive](doc/ARCHITECTURE_ANALYSIS.md)

---

MIT License · **Nguyễn Tuấn Việt** · [BrewKits](https://brewkits.dev)

---

## Requirements

| Platform | Minimum |
|----------|---------|
| Android | API 26 (Android 8.0) |
| iOS | 14.0 |
| Flutter | 3.10+ |

---

## Installation

```bash
flutter pub add native_workmanager
```

Platform setup: [Android](doc/ANDROID_SETUP.md) · [iOS](doc/IOS_BACKGROUND_LIMITS.md)

---

## Platform Setup

### Android — `AndroidManifest.xml`

The plugin declares the permissions it needs in its own manifest. **No manual entries are required for basic use.** The following are merged automatically:

```xml
<!-- Allows WorkManager to reschedule tasks after device reboot -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<!-- Required for long-running foreground-service workers (download, upload) -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />

<!-- Required to post download-progress notifications (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

You only need to add `POST_NOTIFICATIONS` to your own manifest **if** you target SDK 33+ and want to show download-progress notifications — Android 13 requires a runtime permission request for notifications:

```dart
// Request notification permission on Android 13+
import 'package:permission_handler/permission_handler.dart';
await Permission.notification.request();
```

> **Note on `FOREGROUND_SERVICE_DATA_SYNC`:** This data-sync service type is required on Android 14+ for background download/upload workers. It is declared in the plugin's manifest and merged automatically.

---

### iOS — `Info.plist`

Add the following keys to `ios/Runner/Info.plist` before using background tasks:

**1. Register background task identifiers** (required for `BGTaskScheduler`):

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <!-- Native WorkManager uses these two identifiers internally -->
  <string>dev.brewkits.native_workmanager.refresh</string>
  <string>dev.brewkits.native_workmanager.processing</string>
</array>
```

**2. Declare background execution modes** (required for download resumption and periodic tasks):

```xml
<key>UIBackgroundModes</key>
<array>
  <!-- Enables URLSession background transfers (HttpDownloadWorker, HttpUploadWorker) -->
  <string>fetch</string>
  <string>processing</string>
</array>
```

**3. Restore background sessions in `AppDelegate`** (required for download/upload to survive app restart):

```swift
// ios/Runner/AppDelegate.swift
import native_workmanager

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    // Hand the completion handler to the plugin so URLSession can finish.
    NativeWorkmanagerPlugin.handleBackgroundURLSession(
      identifier: identifier,
      completionHandler: completionHandler
    )
  }
}
```

Without this `AppDelegate` hook, background downloads and uploads will silently fail to deliver results when the app is not in the foreground.

---

## Quick Start

**1. Initialize once in `main()`:**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize();
  runApp(MyApp());
}
```

**2. Schedule a task — that's it:**

```dart
// Periodic API sync — pure Kotlin/Swift, no Flutter Engine
await NativeWorkManager.enqueue(
  taskId: 'hourly-sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  constraints: Constraints(requiresNetwork: true),
);
```

**3. Listen for results:**

```dart
NativeWorkManager.events.listen((event) {
  print('${event.taskId}: ${event.success ? "done" : event.message}');
});
```

---

## 11 Built-in Workers

No third-party code. No Flutter Engine. Every worker runs natively in Kotlin (Android) and Swift (iOS).

### HTTP

```dart
// Fire-and-forget API ping
NativeWorker.httpSync(
  url: 'https://api.example.com/heartbeat',
  method: HttpMethod.post,
  headers: {'Authorization': 'Bearer $token'},
)

// Download with automatic resume on failure
NativeWorker.httpDownload(
  url: 'https://cdn.example.com/update.zip',
  savePath: '${docsDir.path}/update.zip',
  enableResume: true,
  expectedChecksum: 'a3b2c1...',   // SHA-256 verified after download
)

// Upload a file with additional form fields
NativeWorker.httpUpload(
  url: 'https://api.example.com/photos',
  filePath: '/tmp/photo1.jpg',
  additionalFields: {'albumId': '42'},
)

// Full request with response validation
NativeWorker.httpRequest(
  url: 'https://api.example.com/order',
  method: HttpMethod.post,
  body: jsonEncode({'itemId': 99}),
)
```

### File

```dart
// Compress a folder to ZIP
NativeWorker.fileCompress(
  inputPath: '${docsDir.path}/logs/',
  outputPath: '${cacheDir.path}/logs_2026.zip',
  level: CompressionLevel.high,
  deleteOriginal: true,
)

// Extract ZIP — zip-slip and zip-bomb protected
NativeWorker.fileDecompress(
  zipPath: '${cacheDir.path}/model.zip',
  targetDir: '${docsDir.path}/model/',
  deleteAfterExtract: true,
)

// Move, copy, delete, list, mkdir
NativeWorker.fileMove(
  sourcePath: '/tmp/raw.bin',
  destinationPath: '${docsDir.path}/processed.bin',
)
```

### Image

```dart
// Resize and compress — EXIF-aware, 10× faster than Dart image packages
NativeWorker.imageProcess(
  inputPath: '${cacheDir.path}/raw.heic',
  outputPath: '${docsDir.path}/thumb.jpg',
  maxWidth: 1280,
  maxHeight: 720,
  quality: 85,
  outputFormat: ImageFormat.jpeg,
)
```

### Crypto

```dart
// AES-256 encrypt (random IV + PBKDF2 key derivation)
NativeWorker.cryptoEncrypt(
  inputPath: '${docsDir.path}/report.pdf',
  outputPath: '${docsDir.path}/report.pdf.enc',
  password: 'secret',
)

// Verify file integrity
NativeWorker.hashFile(
  filePath: '${docsDir.path}/firmware.bin',
  algorithm: HashAlgorithm.sha256,
)
```

---

## Task Chains

Chain workers sequentially — each step retries independently, and output from one step flows into the next. Pure native, zero Flutter Engine.

```dart
await NativeWorkManager.beginWith(
  TaskRequest(
    id: 'download',
    worker: NativeWorker.httpDownload(
      url: 'https://cdn.example.com/model.zip',
      savePath: '/tmp/model.zip',
    ),
  ),
).then(
  TaskRequest(
    id: 'extract',
    worker: NativeWorker.fileDecompress(
      zipPath: '/tmp/model.zip',
      targetDir: '/data/model/',
      deleteAfterExtract: true,
    ),
  ),
).then(
  TaskRequest(
    id: 'verify',
    worker: NativeWorker.hashFile(
      filePath: '/data/model/weights.bin',
      algorithm: HashAlgorithm.sha256,
    ),
  ),
).named('update-model').enqueue();
```

Each step only runs if the previous one succeeded. If a step fails and exhausts retries, the chain stops and emits a failure event. See [Chain Processing guide →](doc/use-cases/06-chain-processing.md)

---

## Custom Native Workers

Need to use Android Keystore, TensorFlow Lite, Core ML, or any platform API not covered by the built-ins? Write a native worker — no forking, no MethodChannel boilerplate.

**Android (Kotlin):**

```kotlin
class MLInferenceWorker : AndroidWorker {
    override suspend fun doWork(input: String?): WorkerResult {
        val imagePath = JSONObject(input!!).getString("imagePath")
        val result = TFLiteModel.run(imagePath)   // TensorFlow Lite, Core ML, Room…
        return WorkerResult.Success(data = mapOf("label" to result.label))
    }
}

// Register once in MainActivity.kt
SimpleAndroidWorkerFactory.setUserFactory { name ->
    if (name == "MLInferenceWorker") MLInferenceWorker() else null
}
```

**iOS (Swift):**

```swift
class MLInferenceWorker: IosWorker {
    func doWork(input: String?) async throws -> WorkerResult {
        let imagePath = try JSONDecoder().decode(Config.self, from: input!.data(using: .utf8)!).imagePath
        let result = try await CoreMLModel.run(imagePath)   // Core ML, CryptoKit, CoreData…
        return .success(data: ["label": result.label])
    }
}

// Register once in AppDelegate.swift
IosWorkerFactory.registerWorker(className: "MLInferenceWorker") { MLInferenceWorker() }
```

**Dart (same API on both platforms):**

```dart
await NativeWorkManager.enqueue(
  taskId: 'run-inference',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.custom(
    className: 'MLInferenceWorker',
    input: {'imagePath': '/photos/IMG_001.jpg'},
  ),
);
```

[Full extensibility guide →](doc/EXTENSIBILITY.md) · [Use-case walkthrough →](doc/use-cases/07-custom-native-workers.md)

---

## Dart Callbacks

For logic that must run in Dart (database writes, state management, push notifications), use `DartWorker`. The Flutter Engine is reused when the app is in the foreground — no cold-start penalty.

```dart
// 1. Register top-level callbacks at startup
await NativeWorkManager.initialize(
  dartWorkers: {
    'syncContacts': syncContactsCallback,  // must be top-level or static
    'cleanCache':  cleanCacheCallback,
  },
);

// 2. Schedule
await NativeWorkManager.enqueue(
  taskId: 'nightly-sync',
  trigger: TaskTrigger.periodic(Duration(hours: 24)),
  worker: DartWorker(
    callbackId: 'syncContacts',
    input: {'lastSyncTs': timestamp},
  ),
  constraints: Constraints(requiresCharging: true, requiresNetwork: true),
);

// 3. Implement — top-level function required
@pragma('vm:entry-point')
Future<bool> syncContactsCallback(Map<String, dynamic>? input) async {
  final since = input?['lastSyncTs'] as int?;
  await ContactsService.sync(since: since);
  return true;   // true = success, false = retry
}
```

---

## Events & Progress

```dart
// Task completion
NativeWorkManager.events.listen((event) {
  print('${event.taskId}: ${event.success ? "done" : "failed — ${event.message}"}');
  if (event.resultData != null) print('  data: ${event.resultData}');
});

// Download / upload progress
NativeWorkManager.progress.listen((update) {
  print('${update.taskId}: ${update.progress}%'
        '${update.message != null ? " — ${update.message}" : ""}');
});
```

---

## Constraints & Triggers

```dart
// Run only on Wi-Fi while charging
await NativeWorkManager.enqueue(
  taskId: 'heavy-backup',
  trigger: TaskTrigger.oneTime(Duration(minutes: 30)),
  worker: NativeWorker.httpUpload(
    url: 'https://backup.example.com/upload',
    filePath: backupPath,
  ),
  constraints: Constraints(
    requiresUnmeteredNetwork: true,   // Wi-Fi only
    requiresCharging: true,
    isHeavyTask: true,                // Android: foreground service (no 10-min limit)
  ),
);

// Cancel when user logs out
await NativeWorkManager.cancelByTag('user-session');
```

Available triggers: `oneTime()`, `oneTime(Duration)`, `periodic(Duration)`, `exact(DateTime)`, `windowed`, `contentUri`, `batteryOkay`, `batteryLow`, `deviceIdle`, `storageLow`.

---

## Migrating from `workmanager`

~90% API compatible. Common patterns translate directly:

```dart
// Before
Workmanager().registerPeriodicTask(
  'sync', 'apiSync',
  frequency: Duration(hours: 1),
  constraints: Constraints(networkType: NetworkType.connected),
);

// After — and the task actually repeats this time
await NativeWorkManager.enqueue(
  taskId: 'sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  constraints: Constraints(requiresNetwork: true),
);
```

[Step-by-step migration guide →](doc/MIGRATION_GUIDE.md) · [Automated migration CLI →](tool/migrate.dart)

---

## What's New in v1.2.0

- **DartWorker works in debug / integration-test mode on iOS** — `FlutterCallbackCache` returns nil in JIT builds; fixed by routing through the existing main method channel instead of a secondary engine. All 37 iOS integration tests now pass.
- **DartWorker callback input now correctly decoded** — input was being passed as `{'raw': '...'}` wrapper instead of the actual decoded map; callbacks now receive `{'key': 'value'}` as expected.
- **Path traversal hardened across all Android workers** — `HttpUpload`, `FileDecompression`, `FileSystem`, `ImageProcess`, `FileCompression`, `Crypto` all now use `File.canonicalPath` (replaces bypassable `contains("..")` check).
- **HttpDownloadWorker null-body NPE fixed** — `response.body!!` force-unwrap replaced with explicit null check.
- **Version alignment** — `pubspec.yaml`, podspec, `build.gradle` all corrected to `1.0.8`.

[Full changelog →](CHANGELOG.md)

---

## Documentation

| Guide | Description |
|-------|-------------|
| [Getting Started](doc/GETTING_STARTED.md) | 3-minute setup with copy-paste examples |
| [API Reference](doc/API_REFERENCE.md) | Complete API for all public types |
| [Android Setup](doc/ANDROID_SETUP.md) | ProGuard, permissions, foreground service |
| [iOS Background Limits](doc/IOS_BACKGROUND_LIMITS.md) | BGTaskScheduler, 30-second rule, periodic limitations |
| [Migration Guide](doc/MIGRATION_GUIDE.md) | Migrate from `workmanager` step-by-step |
| [Extensibility](doc/EXTENSIBILITY.md) | Writing custom Kotlin/Swift workers |
| [Security](doc/SECURITY.md) | Path traversal, URL validation, sandboxing |
| [FAQ](doc/FAQ.md) | Common questions and troubleshooting |

**Use cases:** [Periodic Sync](doc/use-cases/01-periodic-api-sync.md) · [File Upload with Retry](doc/use-cases/02-file-upload-with-retry.md) · [Background Cleanup](doc/use-cases/03-background-cleanup.md) · [Photo Backup](doc/use-cases/04-photo-auto-backup.md) · [Chain Processing](doc/use-cases/06-chain-processing.md) · [Custom Workers](doc/use-cases/07-custom-native-workers.md)

---

## Troubleshooting

### iOS: task never fires / fires only once

**Root cause — BGTaskScheduler simulator limitation:**
BGTaskScheduler does **not** fire in the iOS Simulator. Always test background tasks on a physical device.

To force a background task to launch immediately during debugging, pause the app in Xcode and run:
```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"dev.brewkits.native_workmanager.refresh"]
```

**Root cause — minimum 15-minute periodic interval:**
iOS BGTaskScheduler enforces a hard minimum of ~15 minutes between periodic launches regardless of the interval you specify. Intervals shorter than 15 minutes are silently clamped.

```dart
// ✅ Reliable — respects the OS minimum
trigger: TaskTrigger.periodic(Duration(hours: 1))

// ⚠️ Silently clamped to ~15 min by iOS
trigger: TaskTrigger.periodic(Duration(minutes: 5))
```

**Root cause — 30-second execution budget:**
Each `BGAppRefreshTask` has roughly 30 seconds to complete. A `DartWorker` consumes ~200–500 ms just starting the Flutter engine, leaving less than 30 seconds for actual work. Prefer **native workers** (`NativeWorker.httpDownload`, `NativeWorker.httpSync`, etc.) for background tasks — they start in <100 ms with ~2 MB RAM.

**Root cause — `BGTaskSchedulerPermittedIdentifiers` missing:**
Verify your `ios/Runner/Info.plist` contains the task identifier:
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <string>dev.brewkits.native_workmanager.refresh</string>
  <string>dev.brewkits.native_workmanager.processing</string>
</array>
```

---

### Android: task is delayed or never runs

**Battery optimization (OEM restrictions):**
Samsung, Xiaomi, Huawei, and OnePlus devices apply aggressive background kill policies. Direct the user to disable battery optimization for your app:
```dart
// Guide users to Android battery settings
const platform = MethodChannel('your.channel');
await platform.invokeMethod('openBatterySettings');
```
Or include a one-time prompt at install time pointing to **Settings → Battery → App Launch / Unrestricted**.

**Doze mode defers tasks:**
Android Doze mode can delay tasks by minutes to hours. Use constraints to defer execution until conditions are met rather than fighting the OS:
```dart
constraints: Constraints(
  requiresNetwork: true,
  requiresBatteryNotLow: true,
),
```

**Minimum 15-minute periodic interval:**
`PeriodicWorkRequest` enforces a minimum repeat interval of **15 minutes**. Intervals below this are clamped. For higher-frequency work, use a foreground service instead.

**Minimum SDK version:**
The plugin requires `minSdk 26` (Android 8.0). Lower values produce a crash at startup.

**Debug with adb logcat:**
```bash
adb logcat -s NativeWorkmanagerPlugin KmpWorkManager WorkManager
```

---

### Chain behavior differences: iOS vs Android

| Behaviour | Android | iOS |
|-----------|---------|-----|
| Chain persisted across app restart | ✅ `ChainStore` (SQLite) | ✅ `TaskStore` (SQLite) |
| Chain resumed after device reboot | ✅ WorkManager re-enqueues | ✅ `resumePendingChains()` on plugin attach |
| Max reliable chain length | 5–10 tasks | 3–5 tasks (30-second budget per step) |
| Step-level retry | ✅ per-step `Constraints.maxAttempts` | ✅ BGProcessingTask retry |
| Data passing between steps | Via shared storage (SQLite / `SharedPreferences`) | Same |
| Failure propagation | Downstream tasks cancelled | Downstream tasks cancelled |

**iOS chain length warning:**
Each step in a chain is a separate `BGAppRefreshTask` with its own 30-second budget. If step N times out, the chain stalls. Keep each step lightweight; use `NativeWorker.*` whenever possible to avoid Flutter engine start-up time.

**Android chain resume:**
`ChainStore.kt` (SQLite) persists pending chains. On engine attach, `resumePendingChains()` re-enqueues any steps whose predecessor already completed. This makes chains durable across process death and device reboot.

**Recommendation — large file processing:**
Instead of one long chain, use a `DartWorker` that reads from a queue (e.g., `OfflineQueue`) and dispatches individual native tasks. This avoids the chain-length limit and gives you fine-grained retry control.

---

## Support

- [Issues](https://github.com/brewkits/native_workmanager/issues) — bug reports and feature requests
- [Discussions](https://github.com/brewkits/native_workmanager/discussions) — questions and ideas
- datacenter111@gmail.com — direct contact

---

MIT License · **Nguyễn Tuấn Việt** · [BrewKits](https://brewkits.dev)

If `native_workmanager` saves you time, a star on GitHub goes a long way — it helps other developers find the package.
