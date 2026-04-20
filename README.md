<p align="center">
  <img src="https://raw.githubusercontent.com/brewkits/native_workmanager/main/assets/logo.svg" height="108" alt="native_workmanager" />
</p>

<h1 align="center">native_workmanager</h1>

<p align="center">
  Background tasks for Flutter — <strong>25+ built-in workers, zero Flutter Engine overhead.</strong><br/>
  HTTP, file ops, image processing, encryption — all in pure Kotlin & Swift.
</p>

<p align="center">
  <a href="https://pub.dev/packages/native_workmanager"><img src="https://img.shields.io/pub/v/native_workmanager.svg" alt="pub.dev"></a>
  <a href="https://pub.dev/packages/native_workmanager/score"><img src="https://img.shields.io/pub/points/native_workmanager?label=pub%20points" alt="Pub Points"></a>
  <a href="https://github.com/brewkits/native_workmanager/actions"><img src="https://github.com/brewkits/native_workmanager/workflows/ci/badge.svg" alt="CI"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT"></a>
  <img src="https://img.shields.io/badge/Android-8.0%2B-brightgreen.svg" alt="Android 8.0+">
  <img src="https://img.shields.io/badge/iOS-13.0%2B-lightgrey.svg" alt="iOS 13.0+">
</p>

---

## The 30-second pitch

```dart
// Download → resize → upload — survives app kill, device reboot, low memory
await NativeWorkManager
  .beginWith(TaskRequest(id: 'dl',
    worker: NativeWorker.httpDownload(url: photoUrl, savePath: '/tmp/raw.jpg')))
  .then(TaskRequest(id: 'resize',
    worker: NativeWorker.imageResize(inputPath: '/tmp/raw.jpg',
      outputPath: '/tmp/thumb.jpg', maxWidth: 512)))
  .then(TaskRequest(id: 'upload',
    worker: NativeWorker.httpUpload(url: uploadUrl, filePath: '/tmp/thumb.jpg')))
  .named('photo-pipeline')
  .enqueue();
```

No boilerplate. No native code to write. No `AndroidManifest.xml` changes. Each step retries independently — if the upload fails, only the upload retries.

---

## Quick Start

**1. Add the dependency:**

```yaml
dependencies:
  native_workmanager: ^1.2.2
```

**2. Initialize once in `main()`:**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize();
  runApp(MyApp());
}
```

**3. Schedule a background task:**

```dart
await NativeWorkManager.enqueue(
  taskId: 'daily-sync',
  worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  constraints: const Constraints(requiresNetwork: true),
);
```

**iOS only** — run once to configure `BGTaskScheduler` automatically:

```bash
dart run native_workmanager:setup_ios
```

---

## Why developers switch from `workmanager`

The dominant `workmanager` plugin spins up a **full Flutter Engine per background task**: ~50–100 MB RAM, up to 3 seconds cold start, a Dart isolate the OS kills the moment memory gets tight. On Xiaomi/Samsung/Huawei devices with aggressive battery optimization, the engine never even starts.

`native_workmanager` runs tasks as pure Kotlin coroutines and Swift async functions — **no engine, no isolate, no cold-start penalty**.

| | `workmanager` | `native_workmanager` |
|---|:---:|:---:|
| Memory per task | ~50–100 MB | **~2–5 MB** |
| Task startup | 1,500–3,000 ms | **< 50 ms** |
| Built-in HTTP workers | ❌ | ✅ (resumable download, chunked upload, parallel) |
| Built-in image workers | ❌ | ✅ (resize, crop, convert, thumbnail — EXIF-aware) |
| Built-in crypto workers | ❌ | ✅ (AES-256-GCM, SHA-256/512, HMAC) |
| Task chains (A→B→C) | ❌ | ✅ (persist across reboots) |
| Per-task progress stream | ❌ | ✅ |
| Survives device reboot | ✅ | ✅ |
| Remote Trigger (Push) | ❌ | ✅ (FCM/APNs + HMAC Security) |
| Custom Dart workers | ✅ | ✅ (opt-in via `DartWorker`) |

> **If you only do HTTP syncs and file ops, you probably don't need Dart workers at all.** Use the native workers directly — they're production-hardened and need zero engine overhead.

---

## 25+ Built-in Workers

All workers run natively. No Flutter Engine. No setup beyond `initialize()`.

| Category | Workers |
|----------|---------|
| **HTTP** | `httpDownload` (resumable), `httpUpload` (multipart), `parallelDownload` (chunked), `httpSync`, `httpRequest` |
| **Image** | `imageResize`, `imageCrop`, `imageConvert`, `imageThumbnail` — all EXIF-aware |
| **PDF** | `pdfMerge`, `pdfCompress`, `imagesToPdf` |
| **Crypto** | `cryptoEncrypt` (AES-256-GCM), `cryptoDecrypt`, `cryptoHash` (SHA-256/512), `hmacSign` |
| **File** | `fileCopy`, `fileMove`, `fileDelete`, `fileList` |
| **Storage** | `moveToSharedStorage` (Android MediaStore / iOS Files app) |
| **Real-time** | `webSocket` — Android |

---

## Track progress in real time

`enqueue()` returns a `TaskHandler` that streams progress and completion events for that specific task — no manual filtering required.

```dart
final handler = await NativeWorkManager.enqueue(
  taskId: 'big-download',
  worker: NativeWorker.httpDownload(
    url: 'https://cdn.example.com/video.mp4',
    savePath: '/tmp/video.mp4',
  ),
);

// Stream progress for this task only
handler.progress.listen((p) {
  print('${p.progress}% — ${p.networkSpeedHuman} — ETA ${p.timeRemainingHuman}');
});

// Await completion
final result = await handler.result;
print(result.success ? 'Done!' : 'Failed: ${result.message}');
```

Or drop in the built-in widget:

```dart
TaskProgressCard(handler: handler, title: 'Downloading video')
```

---

## Task Chains

Chain workers into persistent pipelines. Each step only runs when the previous one succeeds, and the entire chain survives app kills and device reboots (SQLite-backed state).

```dart
await NativeWorkManager
  .beginWith(TaskRequest(
    id: 'download',
    worker: NativeWorker.httpDownload(
      url: 'https://cdn.example.com/report.pdf',
      savePath: '/tmp/report.pdf',
    ),
  ))
  .then(TaskRequest(
    id: 'encrypt',
    worker: NativeWorker.cryptoEncrypt(
      inputPath: '/tmp/report.pdf',
      outputPath: '/tmp/report.enc',
      password: vaultKey,
    ),
  ))
  .then(TaskRequest(
    id: 'upload',
    worker: NativeWorker.httpUpload(
      url: 'https://vault.example.com/store',
      filePath: '/tmp/report.enc',
    ),
  ))
  .named('secure-report-pipeline')
  .enqueue();
```

Use `.thenAll([...])` to run tasks in parallel, then continue the chain when all finish.

---

## Custom Dart Workers

For app-specific logic that must run in Dart, register a top-level function as a background worker:

```dart
@pragma('vm:entry-point')
Future<bool> syncHealthData(Map<String, dynamic>? input) async {
  final userId = input?['userId'] as String?;
  await uploadHealthMetrics(userId);
  return true;
}

// Register once at startup
NativeWorkManager.registerDartWorker('health-sync', syncHealthData);

// Schedule it
await NativeWorkManager.enqueue(
  taskId: 'sync-user-42',
  worker: DartWorker(callbackId: 'health-sync', input: {'userId': '42'}),
);
```

Dart workers boot a headless Flutter isolate (~50 MB, 1–2 s cold start). The isolate is cached for 5 minutes so back-to-back tasks pay the boot cost only once. For HTTP and file tasks, use native workers instead.

> **Android killed-app support** — When Android kills your app and WorkManager later fires a `DartWorker`, the process restarts without Flutter. The plugin automatically restores the `callbackHandle` from `SharedPreferences`, but your `Application` class must implement `Configuration.Provider` so WorkManager uses the plugin's `WorkerFactory`. One-time setup — see **[Android Setup Guide](doc/ANDROID_SETUP.md)**.

### Code generation for DartWorker

The companion [`native_workmanager_gen`](https://pub.dev/packages/native_workmanager_gen) package generates type-safe callback IDs and a worker registry from `@WorkerCallback` annotations, eliminating string-based registration and magic IDs:

```dart
@WorkerCallback('health-sync')
Future<bool> syncHealthData(Map<String, dynamic>? input) async { ... }

// Generated: WorkerCallbacks.healthSync, auto-registered in WorkerRegistry
```

---

## Platform Support

| Feature | Android | iOS |
|---------|:-------:|:---:|
| One-time tasks | ✅ | ✅ |
| Periodic tasks | ✅ | ✅ (BGAppRefresh) |
| Exact-time triggers | ✅ | ✅ |
| Task chains (persistent) | ✅ | ✅ |
| Network / charging constraints | ✅ | ✅ |
| Per-task progress stream | ✅ | ✅ |
| Foreground service (long tasks) | ✅ | — |
| Custom Dart workers | ✅ | ✅ |
| Min OS version | Android 8.0 (API 26) | iOS 14.0 |

---

## Migrating from `workmanager`

Most migrations take under 10 minutes. The conceptual model is the same; the API is a strict superset.

| `workmanager` | `native_workmanager` |
|---|---|
| `Workmanager().initialize(...)` | `NativeWorkManager.initialize()` |
| `Workmanager().registerOneOffTask(...)` | `NativeWorkManager.enqueue(worker: NativeWorker.httpSync(...))` |
| `Workmanager().registerPeriodicTask(...)` | `NativeWorkManager.enqueue(trigger: TaskTrigger.periodic(...))` |
| Custom Dart callback | `DartWorker(callbackId: ...)` |

See [Migration Guide](doc/MIGRATION_GUIDE.md) for a step-by-step walkthrough.

---

## Common Use Cases

<details>
<summary><strong>📥 Resumable large file download</strong></summary>

```dart
await NativeWorkManager.enqueue(
  taskId: 'download-dataset',
  worker: NativeWorker.httpDownload(
    url: 'https://data.example.com/dataset.zip',
    savePath: '/tmp/dataset.zip',
    headers: {'Authorization': 'Bearer $token'},
    allowResume: true,
  ),
  constraints: const Constraints(requiresUnmeteredNetwork: true),
);
```
</details>

<details>
<summary><strong>🔐 Encrypt &amp; upload sensitive file</strong></summary>

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
<summary><strong>⏱ Periodic background sync</strong></summary>

```dart
await NativeWorkManager.enqueue(
  taskId: 'hourly-sync',
  worker: NativeWorker.httpSync(url: 'https://api.example.com/sync'),
  trigger: TaskTrigger.periodic(const Duration(hours: 1)),
  constraints: const Constraints(requiresNetwork: true),
  existingPolicy: ExistingTaskPolicy.keep,
);
```
</details>

<details>
<summary><strong>📸 Photo backup pipeline</strong></summary>

```dart
await NativeWorkManager
  .beginWith(TaskRequest(
    id: 'compress',
    worker: NativeWorker.imageResize(
      inputPath: photoPath,
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

---

## Listen to task events

```dart
NativeWorkManager.events.listen((event) {
  if (event.isStarted) {
    print('▶ ${event.taskId} started (${event.workerType})');
    return;
  }
  if (event.success) {
    print('✅ ${event.taskId} — ${event.resultData}');
  } else {
    print('❌ ${event.taskId} — ${event.message}');
  }
});
```

---

## Documentation

| Guide | Description |
|---|---|
| [Getting Started](doc/GETTING_STARTED.md) | Full setup walkthrough |
| [API Reference](doc/API_REFERENCE.md) | All public types and methods |
| [Android Setup Guide](doc/ANDROID_SETUP.md) | DartWorker killed-app persistence |
| [iOS Setup Guide](doc/IOS_SETUP_GUIDE.md) | BGTaskScheduler details |
| [Migration from workmanager](doc/MIGRATION_GUIDE.md) | Switch in under 10 minutes |
| [Security](doc/SECURITY.md) | SSRF, path traversal, data redaction |
| [native_workmanager_gen](https://pub.dev/packages/native_workmanager_gen) | Code generator for type-safe DartWorker callbacks |

---

## Support

- [GitHub Issues](https://github.com/brewkits/native_workmanager/issues) — bugs and feature requests
- [Discussions](https://github.com/brewkits/native_workmanager/discussions) — questions and community help

---

MIT License · Made by [BrewKits](https://brewkits.dev)

*Found this useful? A ⭐ on [GitHub](https://github.com/brewkits/native_workmanager) helps others discover it.*
