# native_workmanager

> **Background task manager for Flutter — native workers, task chains, zero Flutter Engine overhead.**

[![pub package](https://img.shields.io/pub/v/native_workmanager.svg?color=blueviolet)](https://pub.dev/packages/native_workmanager)
[![pub points](https://img.shields.io/pub/points/native_workmanager?color=green)](https://pub.dev/packages/native_workmanager/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-blue.svg)](https://pub.dev/packages/native_workmanager)

Schedule background tasks that **survive app restarts, phone reboots, and force-quits** — with native Kotlin/Swift workers that run without loading the Flutter Engine.

---

## Why native_workmanager?

Most Flutter background task plugins execute Dart code, which means spawning a full Flutter Engine just to make an HTTP request or move a file. **native_workmanager** takes a different approach:

| | workmanager | native_workmanager |
|---|---|---|
| HTTP sync without Flutter Engine | ❌ | ✅ |
| File operations without Flutter Engine | ❌ | ✅ |
| Task chains (A → B → C) | ❌ | ✅ |
| Built-in workers (HTTP, file, crypto, image) | ❌ | ✅ 11 workers |
| Dart callbacks for custom logic | ✅ | ✅ |
| Periodic tasks (actually working) | ✅ | ✅ v1.0.5 |

---

## Features

- **11 Built-in Native Workers** — HTTP request/download/upload/sync, file compress/decompress/system, image processing, AES-256 encryption, file hashing — all running in native Kotlin/Swift without the Flutter Engine
- **Task Chains** — Wire tasks together: `Download → Decrypt → Extract → Notify`. Each step starts only when the previous succeeds; data flows between steps automatically
- **Dart Workers** — For logic that needs Flutter packages or complex Dart code, with smart engine lifecycle management
- **Constraints** — `requiresNetwork`, `requiresCharging`, `requiresBatteryNotLow`, `requiresDeviceIdle`, backoff policies — correctly enforced on both platforms
- **Event & Progress Streams** — Real-time status updates and byte-level progress for long-running workers
- **SPM + CocoaPods** — iOS integration works with both Swift Package Manager and CocoaPods

---

## Quick Start

### 1. Platform requirements

- **Android:** API 26+ (Android 8.0+) — [Android Setup →](doc/ANDROID_SETUP.md)
- **iOS:** iOS 14.0+ — [iOS Background Limits →](doc/IOS_BACKGROUND_LIMITS.md)

### 2. Install

```bash
flutter pub add native_workmanager
```

### 3. Initialize

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize();
  runApp(MyApp());
}
```

### 4. Schedule your first task

**Periodic API sync (native worker — no Flutter Engine):**
```dart
await NativeWorkManager.enqueue(
  taskId: 'hourly-sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpSync(
    url: 'https://api.example.com/sync',
    method: HttpMethod.post,
    headers: {'Authorization': 'Bearer $token'},
  ),
  constraints: Constraints(requiresNetwork: true),
);
// ✓ Runs every hour even when app is closed
// ✓ No Flutter Engine spawned
```

**Custom Dart logic:**
```dart
await NativeWorkManager.enqueue(
  taskId: 'process-data',
  trigger: TaskTrigger.oneTime(initialDelay: Duration(minutes: 5)),
  worker: DartWorker(callbackId: 'processData'),
  constraints: Constraints(requiresNetwork: true, requiresCharging: true),
);
// ✓ Dart code executes with full package access
// ✓ Constraints are enforced — task waits for network + charger
```

[Full getting started guide →](doc/GETTING_STARTED.md)

---

## Built-in Workers

### HTTP Workers
```dart
// Download a file with resume support
NativeWorker.httpDownload(
  url: 'https://cdn.example.com/dataset.zip',
  savePath: '/data/dataset.zip',
  enableResume: true,          // Resumes from last byte on retry
  expectedChecksum: 'sha256:...', // Integrity check after download
)

// Upload files with progress
NativeWorker.httpUpload(
  url: 'https://api.example.com/upload',
  files: [
    FileUploadConfig(filePath: '/photos/img1.jpg', fileFieldName: 'photo'),
    FileUploadConfig(filePath: '/photos/img2.jpg', fileFieldName: 'photo'),
  ],
)

// Fire-and-forget API call
NativeWorker.httpSync(url: 'https://api.example.com/ping', method: HttpMethod.post)
```

### File Workers
```dart
// Compress files into a ZIP
NativeWorker.fileCompress(sourcePath: '/data/logs/', outputPath: '/backup/logs.zip')

// Extract ZIP with zip-slip + zip-bomb protection
NativeWorker.fileDecompress(zipPath: '/downloads/assets.zip', targetDir: '/data/assets/')

// Copy, move, delete, list, mkdir
NativeWorker.fileMove(sourcePath: '/tmp/file.zip', destinationPath: '/downloads/file.zip')
```

### Crypto Worker
```dart
// Hash a file (MD5, SHA-1, SHA-256, SHA-512)
NativeWorker.hashFile(filePath: '/downloads/firmware.bin', algorithm: HashAlgorithm.sha256)

// Encrypt with AES-256-GCM (random salt, PBKDF2 key derivation)
NativeWorker.cryptoEncrypt(
  inputPath: '/data/backup.db',
  outputPath: '/data/backup.db.enc',
  password: 'secret',
)
```

### Image Worker
```dart
// Resize + compress, EXIF-aware, native performance
NativeWorker.imageProcess(
  inputPath: '/DCIM/IMG_4032.jpg',
  outputPath: '/processed/thumb.jpg',
  maxWidth: 1280,
  maxHeight: 720,
  quality: 85,
  outputFormat: ImageFormat.jpeg,
)
```

---

## Task Chains

Chain workers so each step starts only when the previous one succeeds:

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
// ✓ Pure native — zero Flutter Engine involved
// ✓ Each step retries independently
// ✓ Chain stops and cleans up if any step fails
```

---

## Constraints & Triggers

```dart
// All constraints are enforced — task waits until conditions are met
await NativeWorkManager.enqueue(
  taskId: 'nightly-backup',
  trigger: TaskTrigger.periodic(
    Duration(hours: 24),
    flexInterval: Duration(hours: 2),  // Run anytime in 2hr flex window
  ),
  worker: NativeWorker.fileCompress(
    sourcePath: '/data/user/',
    outputPath: '/backup/user.zip',
  ),
  constraints: Constraints(
    requiresNetwork: false,
    requiresCharging: true,          // Only run while charging
    requiresBatteryNotLow: true,     // Skip if battery < 20%
    requiresDeviceIdle: true,        // Run when phone is idle
    backoffPolicy: BackoffPolicy.exponential,
    backoffDelay: Duration(minutes: 5),
  ),
);
```

---

## Events & Progress

```dart
// Listen for task completion
NativeWorkManager.events.listen((event) {
  print('${event.taskId}: ${event.success ? "done" : event.message}');
});

// Track download progress
NativeWorkManager.progress.listen((update) {
  print('${update.taskId}: ${update.progress}% — ${update.bytesDownloaded} bytes');
});
```

---

## Migrating from workmanager

~90% API compatible. Most migrations take under 10 minutes.

**Before:**
```dart
Workmanager().registerPeriodicTask('sync', 'apiSync', frequency: Duration(hours: 1));
// → Callback fires, Flutter Engine starts, Dart code runs
```

**After:**
```dart
NativeWorkManager.enqueue(
  taskId: 'sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  // → Pure native: no Flutter Engine, lower memory, lower battery
);
```

[Full migration guide →](doc/MIGRATION_GUIDE.md) · [Migration CLI tool →](tool/migrate.dart)

---

## Platform Support

| Platform | Status | Min Version |
|----------|:------:|:-----------:|
| Android | ✅ | API 26 (Android 8.0+) |
| iOS | ✅ | iOS 14.0+ |

**iOS note:** Background tasks must complete within **30 seconds**. Use task chains to split long work into steps, or native workers (which run faster than Dart workers). `HttpDownloadWorker` uses Background URLSession and has no time limit.

**Android note:** Constraints (`requiresCharging`, `requiresNetwork`, etc.) are correctly enforced since v1.0.5. Earlier versions silently ignored them.

---

## What's New in v1.0.5

This release fixes the most impactful correctness bugs since launch:

- **Periodic tasks work correctly** — trigger type was hardcoded to `OneTime`; periodic tasks only ran once (fixed)
- **Constraints are enforced** — `requiresNetwork`, `requiresCharging`, `initialDelay`, and all other constraints were silently ignored on Android (fixed)
- **ExistingTaskPolicy works** — `replace` was silently treated as `keep` (fixed)
- **iOS flex window applied** — `flexMs` key mismatch meant flex interval was never set (fixed)
- **Chain resume preserves config** — all worker config was lost after app kill/resume (fixed)
- **Custom iOS worker registration** — `IosWorker` protocol is now `public`; registration no longer silently skipped (fixed)
- **HttpDownload resume** — partial downloads are preserved on network error so retries use `Range` header (fixed)
- **Swift Package Manager support** — works with both SPM and CocoaPods

[Full changelog →](CHANGELOG.md)

---

## Documentation

| | |
|---|---|
| [Quick Start](doc/GETTING_STARTED.md) | Get running in 3 minutes |
| [API Reference](doc/API_REFERENCE.md) | Complete API docs |
| [FAQ](doc/FAQ.md) | Common questions |
| [Android Setup](doc/ANDROID_SETUP.md) | AndroidManifest, ProGuard, minSdk |
| [iOS Background Limits](doc/IOS_BACKGROUND_LIMITS.md) | 30-second limit workarounds |
| [Migration Guide](doc/MIGRATION_GUIDE.md) | From workmanager |
| [Security Policy](doc/SECURITY.md) | Report vulnerabilities |

**Worker guides:**
[Crypto](doc/workers/CRYPTO_OPERATIONS.md) · [Image Processing](doc/workers/IMAGE_PROCESSING.md) · [File System](doc/workers/FILE_SYSTEM.md) · [File Decompression](doc/workers/FILE_DECOMPRESSION.md)

**Use cases:**
[Periodic API Sync](doc/use-cases/01-periodic-api-sync.md) · [File Upload with Retry](doc/use-cases/02-file-upload-with-retry.md) · [Photo Backup Pipeline](doc/use-cases/04-photo-auto-backup.md) · [Task Chain Processing](doc/use-cases/06-chain-processing.md) · [Custom Native Workers](doc/use-cases/07-custom-native-workers.md)

---

## Support

- 🐛 [Issue Tracker](https://github.com/brewkits/native_workmanager/issues) — bug reports and feature requests
- 💬 [GitHub Discussions](https://github.com/brewkits/native_workmanager/discussions) — questions and use cases
- 📧 Email: datacenter111@gmail.com

---

## License

MIT — see [LICENSE](LICENSE).

**Author:** Nguyễn Tuấn Việt · [BrewKits](https://brewkits.dev)

---

**If this library saves you time, a ⭐ on GitHub goes a long way.**
