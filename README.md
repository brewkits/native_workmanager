# native_workmanager

**Background tasks for Flutter that actually work — native speed, zero Flutter Engine overhead.**

[![pub package](https://img.shields.io/pub/v/native_workmanager.svg?color=blueviolet)](https://pub.dev/packages/native_workmanager)
[![pub points](https://img.shields.io/pub/points/native_workmanager?color=brightgreen)](https://pub.dev/packages/native_workmanager/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-informational.svg)](https://pub.dev/packages/native_workmanager)

HTTP syncs, file downloads, crypto operations, image processing — all running natively in Kotlin or Swift while your app is in the background, **without ever spawning a Flutter Engine**.

---

## The problem with existing solutions

Every Flutter background task library forces you to boot a Flutter Engine to run Dart code in the background. That costs **~50 MB of RAM**, **1–2 seconds of cold-start latency**, and drains battery. For simple I/O tasks like syncing data or downloading a file, this is completely unnecessary.

`native_workmanager` takes a different approach: **built-in Kotlin/Swift workers handle the most common tasks natively, with zero Flutter overhead.** Dart callbacks are still supported for custom logic — but you choose when to pay for them.

---

## Why native_workmanager?

|  | `workmanager` | `native_workmanager` |
|--|:--:|:--:|
| HTTP / file tasks without Flutter Engine | — | ✅ |
| Task chains (A → B → C, retries per step) | — | ✅ |
| 11 built-in workers (HTTP, file, crypto, image) | — | ✅ |
| Custom Kotlin/Swift workers (no fork required) | — | ✅ |
| Dart callbacks for custom logic | ✅ | ✅ |
| Constraints enforced (network, charging…) | ✅ | ✅ |
| Periodic tasks that actually repeat | ✅ | ✅ |
| RAM for a pure-native task | ~50 MB | **~2 MB** |

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
  method: 'POST',
  headers: {'Authorization': 'Bearer $token'},
)

// Download with automatic resume on failure
NativeWorker.httpDownload(
  url: 'https://cdn.example.com/update.zip',
  savePath: '${docsDir.path}/update.zip',
  enableResume: true,
  expectedChecksum: 'a3b2c1...',   // SHA-256 verified after download
)

// Multi-file upload with progress
NativeWorker.httpUpload(
  url: 'https://api.example.com/photos',
  files: ['/tmp/photo1.jpg', '/tmp/photo2.jpg'],
  fields: {'albumId': '42'},
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

// Copy, move, delete, list, mkdir
NativeWorker.fileSystem(
  operation: FileOperation.move,
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
// AES-256-CBC encrypt (random PBKDF2 salt per file)
NativeWorker.cryptoEncrypt(
  filePath: '${docsDir.path}/report.pdf',
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
).enqueue(chainName: 'update-model');
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
  print('${update.taskId}: ${update.progress}% '
        '(${update.bytesDownloaded}/${update.totalBytes} bytes)');
});
```

---

## Constraints & Triggers

```dart
// Run only on Wi-Fi while charging
await NativeWorkManager.enqueue(
  taskId: 'heavy-backup',
  trigger: TaskTrigger.oneTime(delay: Duration(minutes: 30)),
  worker: NativeWorker.httpUpload(
    url: 'https://backup.example.com/upload',
    files: photoPaths,
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

Available triggers: `oneTime`, `oneTime(delay:)`, `periodic(Duration)`, `exact`, `windowed`, `contentUri`, `batteryOkay`, `deviceIdle`.

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

## What's New in v1.0.8

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

## Support

- [Issues](https://github.com/brewkits/native_workmanager/issues) — bug reports and feature requests
- [Discussions](https://github.com/brewkits/native_workmanager/discussions) — questions and ideas
- datacenter111@gmail.com — direct contact

---

MIT License · **Nguyễn Tuấn Việt** · [BrewKits](https://brewkits.dev)

If `native_workmanager` saves you time, a star on GitHub goes a long way — it helps other developers find the package.
