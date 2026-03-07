# native_workmanager

> Background task manager for Flutter — native workers, task chains, zero Flutter Engine overhead.

[![pub package](https://img.shields.io/pub/v/native_workmanager.svg?color=blueviolet)](https://pub.dev/packages/native_workmanager)
[![pub points](https://img.shields.io/pub/points/native_workmanager?color=green)](https://pub.dev/packages/native_workmanager/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-blue.svg)](https://pub.dev/packages/native_workmanager)

Schedule background tasks that survive app restarts, reboots, and force-quits. Native Kotlin/Swift workers handle I/O without spawning the Flutter Engine.

---

## Why native_workmanager?

| | workmanager | native_workmanager |
|---|---|---|
| HTTP/file tasks without Flutter Engine | ❌ | ✅ |
| Task chains (A → B → C) | ❌ | ✅ |
| 11 built-in workers | ❌ | ✅ |
| Constraints enforced (network, charging…) | ✅ | ✅ fixed in v1.0.5 |
| Periodic tasks that actually repeat | ✅ | ✅ fixed in v1.0.5 |
| Dart callbacks for custom logic | ✅ | ✅ |
| Custom Kotlin/Swift workers (no fork) | ❌ | ✅ |

---

## Quick Start

**Requirements:** Android API 26+ · iOS 14.0+

```bash
flutter pub add native_workmanager
```

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize();
  runApp(MyApp());
}
```

**Periodic sync — no Flutter Engine:**
```dart
await NativeWorkManager.enqueue(
  taskId: 'hourly-sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  constraints: Constraints(requiresNetwork: true),
);
```

**Custom Dart logic:**
```dart
await NativeWorkManager.enqueue(
  taskId: 'process-data',
  trigger: TaskTrigger.oneTime(initialDelay: Duration(minutes: 5)),
  worker: DartWorker(callbackId: 'processData'),
  constraints: Constraints(requiresNetwork: true, requiresCharging: true),
);
```

---

## 11 Built-in Workers

| Worker | What it does |
|--------|-------------|
| `httpSync` | Fire-and-forget API call |
| `httpDownload` | Download with resume + checksum |
| `httpUpload` | Single or multi-file upload with progress |
| `httpRequest` | Full HTTP request with response validation |
| `fileCompress` | ZIP a folder or file list |
| `fileDecompress` | Extract ZIP (zip-slip + zip-bomb protected) |
| `fileSystem` | Copy, move, delete, list, mkdir |
| `imageProcess` | Resize/compress/convert, EXIF-aware |
| `cryptoEncrypt` | AES-256-GCM encrypt (random salt, PBKDF2) |
| `cryptoDecrypt` | AES-256-GCM decrypt |
| `hashFile` | MD5, SHA-1, SHA-256, SHA-512 |

---

## Custom Native Workers

Extend with your own Kotlin or Swift workers — no forking, no MethodChannel boilerplate. Runs on native thread, zero Flutter Engine overhead.

```kotlin
// Android — implement AndroidWorker
class EncryptWorker : AndroidWorker {
    override suspend fun doWork(input: String?): WorkerResult {
        val path = Json.parseToJsonElement(input!!).jsonObject["path"]!!.jsonPrimitive.content
        // Android Keystore, Room, TensorFlow Lite — any native API
        return WorkerResult.Success()
    }
}
// Register in MainActivity.kt (once):
// SimpleAndroidWorkerFactory.setUserFactory { name -> if (name == "EncryptWorker") EncryptWorker() else null }
```

```swift
// iOS — implement IosWorker
class EncryptWorker: IosWorker {
    func doWork(input: String?) async throws -> WorkerResult {
        // CryptoKit, Core Data, Core ML — any native API
        return .success()
    }
}
// Register in AppDelegate.swift (once):
// IosWorkerFactory.registerWorker(className: "EncryptWorker") { EncryptWorker() }
```

```dart
// Dart — identical call on both platforms
await NativeWorkManager.enqueue(
  taskId: 'encrypt-file',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.custom(
    className: 'EncryptWorker',
    input: {'path': '/data/document.pdf'},
  ),
);
```

[Full guide →](doc/use-cases/07-custom-native-workers.md) · [Architecture →](doc/EXTENSIBILITY.md)

---

## Task Chains

```dart
await NativeWorkManager.beginWith(
  TaskRequest(
    id: 'download',
    worker: NativeWorker.httpDownload(url: 'https://cdn.example.com/model.zip', savePath: '/tmp/model.zip'),
  ),
).then(
  TaskRequest(
    id: 'extract',
    worker: NativeWorker.fileDecompress(zipPath: '/tmp/model.zip', targetDir: '/data/model/', deleteAfterExtract: true),
  ),
).then(
  TaskRequest(
    id: 'verify',
    worker: NativeWorker.hashFile(filePath: '/data/model/weights.bin', algorithm: HashAlgorithm.sha256),
  ),
).enqueue(chainName: 'update-model');
// Pure native — zero Flutter Engine, each step retries independently
```

---

## Events & Progress

```dart
NativeWorkManager.events.listen((e) => print('${e.taskId}: ${e.success ? "done" : e.message}'));

NativeWorkManager.progress.listen((u) => print('${u.taskId}: ${u.progress}% — ${u.bytesDownloaded}B'));
```

---

## Migrating from workmanager

**Before:**
```dart
Workmanager().registerPeriodicTask('sync', 'apiSync', frequency: Duration(hours: 1));
```

**After:**
```dart
NativeWorkManager.enqueue(
  taskId: 'sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
);
```

~90% API compatible. [Migration guide →](doc/MIGRATION_GUIDE.md) · [Migration CLI →](tool/migrate.dart)

---

## What's New in v1.0.8

- **iOS DartWorker now works in debug/test mode** — `FlutterCallbackCache` returns `nil` in JIT builds; fixed by invoking `executeDartCallback` on the existing main channel instead of a secondary engine
- **iOS 37/37 integration tests** — all DartWorker, `isHeavyTask`, delay, and network constraint tests pass on real device
- **Path traversal hardened** — Android workers now use `File.canonicalPath` comparison (replaces bypassable `contains("..")` check)
- **Chain cancel, chain blocking, and data race fixes** — iOS chain cancel, non-blocking accept, and thread-safe `taskStartTimes`
- **Null-safe `fromMap` deserialization** — `TaskEvent` and `TaskProgress` no longer throw on malformed platform data
- **Version alignment** — `pubspec.yaml`, podspec, and `build.gradle` corrected to `1.0.8`

[Full changelog →](CHANGELOG.md)

---

## Documentation

[Quick Start](doc/GETTING_STARTED.md) · [API Reference](doc/API_REFERENCE.md) · [FAQ](doc/FAQ.md) · [Android Setup](doc/ANDROID_SETUP.md) · [iOS Background Limits](doc/IOS_BACKGROUND_LIMITS.md) · [Migration Guide](doc/MIGRATION_GUIDE.md) · [Security](doc/SECURITY.md)

**Use cases:** [Periodic Sync](doc/use-cases/01-periodic-api-sync.md) · [File Upload](doc/use-cases/02-file-upload-with-retry.md) · [Photo Backup](doc/use-cases/04-photo-auto-backup.md) · [Chain Processing](doc/use-cases/06-chain-processing.md) · [Custom Workers](doc/use-cases/07-custom-native-workers.md)

---

## Support

- 🐛 [Issues](https://github.com/brewkits/native_workmanager/issues)
- 💬 [Discussions](https://github.com/brewkits/native_workmanager/discussions)
- 📧 datacenter111@gmail.com

---

MIT License · **Author:** Nguyễn Tuấn Việt · [BrewKits](https://brewkits.dev)

**If this saves you time, a ⭐ on GitHub helps a lot.**
