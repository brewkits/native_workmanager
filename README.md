<p align="center">
  <img src="https://raw.githubusercontent.com/brewkits/native_workmanager/main/assets/logo.svg" height="108" alt="native_workmanager" />
</p>

<h1 align="center">native_workmanager</h1>

<p align="center">
  Background tasks for Flutter that run in <strong>pure Kotlin &amp; Swift</strong> — no Flutter Engine boot, no 50 MB RAM hit, no 2-second cold-start penalty.
</p>

<p align="center">
  <a href="https://pub.dev/packages/native_workmanager"><img src="https://img.shields.io/pub/v/native_workmanager.svg" alt="pub.dev"></a>
  <a href="https://pub.dev/packages/native_workmanager/score"><img src="https://img.shields.io/pub/points/native_workmanager?label=pub%20points" alt="Pub Points"></a>
  <a href="https://github.com/brewkits/native_workmanager/actions"><img src="https://github.com/brewkits/native_workmanager/workflows/ci/badge.svg" alt="CI"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT"></a>
  <img src="https://img.shields.io/badge/Android-8.0%2B-brightgreen.svg" alt="Android 8.0+">
  <img src="https://img.shields.io/badge/iOS-14.0%2B-lightgrey.svg" alt="iOS 14.0+">
</p>

---

## Quick Start

**1. Add the dependency:**

```yaml
dependencies:
  native_workmanager: ^1.1.0
```

**2. Initialize once in `main()`:**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize();
  runApp(MyApp());
}
```

**3. Schedule your first background task:**

```dart
await NativeWorkManager.enqueue(
  taskId: 'daily-sync',
  worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  constraints: Constraints(requiresWifi: true),
);
```

**iOS only** — run once to configure `BGTaskScheduler` in your Xcode project automatically:

```bash
dart run native_workmanager:setup_ios
```

---

## Why native_workmanager?

The popular `workmanager` plugin boots a **full Flutter Engine for every background task** — ~50 MB RAM, up to 3 seconds startup, and a process that the OS kills aggressively on battery-constrained devices.

`native_workmanager` skips the engine entirely. Workers run as pure Kotlin coroutines or Swift async tasks.

| Metric | workmanager (Dart-based) | native_workmanager |
| :--- | :---: | :---: |
| Memory per task | ~50–100 MB | **~2–5 MB** |
| Task startup | 1,500–3,000 ms | **< 50 ms** |
| Battery impact | High | **Ultra-low** |
| Survives OS task kill | ❌ Engine crash | ✅ Native resilience |
| Custom Dart workers | ✅ | ✅ (opt-in via `DartWorker`) |

---

## Platform Support

| Feature | Android | iOS |
|---------|:-------:|:---:|
| One-time tasks | ✅ | ✅ |
| Periodic tasks | ✅ | ✅ (BGAppRefresh) |
| Task chains | ✅ | ✅ |
| Constraints (Wi-Fi, charging, storage) | ✅ | ✅ |
| Foreground service (long tasks) | ✅ | — |
| Custom Dart workers | ✅ | ✅ |
| Min OS version | Android 8.0 (API 26) | iOS 14.0 |

---

## Built-in Native Workers

25+ production-grade workers, zero engine overhead:

| Category | Workers |
|----------|---------|
| **HTTP / Network** | `httpDownload` (resumable), `httpUpload` (multipart), `parallelDownload` (chunked), `httpSync`, `httpRequest` |
| **Media** | `imageResize`, `imageCrop`, `imageConvert`, `imageThumbnail` (all EXIF-aware) |
| **PDF** | `pdfMerge`, `pdfCompress`, `imagesToPdf` |
| **Crypto** | `cryptoEncrypt` (AES-256-GCM), `cryptoDecrypt`, `cryptoHash` (SHA-256/512), `hmacSign` |
| **File System** | `fileCopy`, `fileMove`, `fileDelete`, `fileCompress` (ZIP), `fileDecompress`, `fileList` |
| **Storage** | `moveToSharedStorage` (Android MediaStore / iOS Files) |
| **Real-time** | `webSocket` (connect / send / receive) — Android |

---

## Secure Task Chains

Chain workers into persistent pipelines. Each step only runs when the previous one succeeds. Data flows automatically between steps.

```dart
await NativeWorkManager
  .beginWith(TaskRequest(
    id: 'download',
    worker: NativeWorker.httpDownload(
      url: 'https://cdn.example.com/photo.jpg',
      savePath: '/tmp/raw.jpg',
    ),
  ))
  .then(TaskRequest(
    id: 'resize',
    worker: NativeWorker.imageResize(
      inputPath: '/tmp/raw.jpg',
      outputPath: '/tmp/thumb.jpg',
      maxWidth: 512,
    ),
  ))
  .then(TaskRequest(
    id: 'upload',
    worker: NativeWorker.httpUpload(
      url: 'https://api.example.com/photos',
      filePath: '/tmp/thumb.jpg',
    ),
  ))
  .named('photo-pipeline')
  .enqueue();
```

- **Persistent** — survives device reboots and app kills (SQLite-backed state)
- **Per-step retry** — Step 2 retries independently; Step 1 never re-runs
- **Parallel steps** — use `.thenAll([...])` to run tasks concurrently then join

---

## Custom Dart Workers

Need app-specific logic? Register a Dart function as a background worker:

```dart
@pragma('vm:entry-point')
Future<bool> myWorker(Map<String, dynamic> input) async {
  final userId = input['userId'] as String;
  await syncUserData(userId);
  return true;
}

// Register once at startup
NativeWorkManager.registerDartWorker('user-sync', myWorker);

// Schedule it
await NativeWorkManager.enqueue(
  taskId: 'sync-user-42',
  worker: DartWorker(workerName: 'user-sync', input: {'userId': '42'}),
);
```

---

## Listen to Task Events

```dart
NativeWorkManager.events.listen((event) {
  if (event.isStarted) return; // lifecycle event, not a result
  if (event.success) {
    print('✅ ${event.taskId} completed');
    print('   result: ${event.resultData}');
  } else {
    print('❌ ${event.taskId} failed: ${event.message}');
  }
});
```

---

## Common Use Cases

<details>
<summary><strong>📸 Photo Backup Pipeline</strong></summary>

```dart
await NativeWorkManager
  .beginWith(TaskRequest(
    id: 'fetch',
    worker: NativeWorker.httpDownload(url: photoUrl, savePath: '/tmp/photo.jpg'),
  ))
  .then(TaskRequest(
    id: 'compress',
    worker: NativeWorker.imageResize(
      inputPath: '/tmp/photo.jpg',
      outputPath: '/tmp/photo_compressed.jpg',
      maxWidth: 1920,
      quality: 85,
    ),
  ))
  .then(TaskRequest(
    id: 'upload',
    worker: NativeWorker.httpUpload(
      url: 'https://backup.example.com/upload',
      filePath: '/tmp/photo_compressed.jpg',
    ),
  ))
  .named('photo-backup')
  .enqueue();
```
</details>

<details>
<summary><strong>🔐 Encrypt &amp; Upload Sensitive File</strong></summary>

```dart
await NativeWorkManager
  .beginWith(TaskRequest(
    id: 'encrypt',
    worker: NativeWorker.cryptoEncrypt(
      inputPath: '/documents/report.pdf',
      outputPath: '/tmp/report.enc',
      password: securePassword,
    ),
  ))
  .then(TaskRequest(
    id: 'upload',
    worker: NativeWorker.httpUpload(
      url: 'https://vault.example.com/store',
      filePath: '/tmp/report.enc',
    ),
  ))
  .named('secure-backup')
  .enqueue();
```
</details>

<details>
<summary><strong>⏱ Periodic Background Sync</strong></summary>

```dart
await NativeWorkManager.enqueue(
  taskId: 'hourly-sync',
  worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  trigger: TaskTrigger.periodic(intervalMinutes: 60),
  constraints: Constraints(requiresNetworkConnectivity: true),
  policy: ExistingTaskPolicy.keep,
);
```
</details>

---

## Documentation

| Guide | Description |
|-------|-------------|
| [Getting Started](doc/GETTING_STARTED.md) | Full setup walkthrough with copy-paste examples |
| [API Reference](doc/API_REFERENCE.md) | Complete reference for all public types |
| [Migration from workmanager](doc/MIGRATION_GUIDE.md) | Switch in under 5 minutes |
| [iOS Setup Guide](doc/IOS_SETUP_GUIDE.md) | BGTaskScheduler configuration details |
| [Architecture](doc/ARCHITECTURE_ANALYSIS.md) | How zero-engine execution works |

---

## Support

- [GitHub Issues](https://github.com/brewkits/native_workmanager/issues) — bug reports and feature requests
- [Discussions](https://github.com/brewkits/native_workmanager/discussions) — community help and questions

---

MIT License · Made by [BrewKits](https://brewkits.dev)

*If `native_workmanager` saves you time, a ⭐ on GitHub goes a long way.*
