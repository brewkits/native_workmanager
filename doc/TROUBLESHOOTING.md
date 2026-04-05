# Troubleshooting Guide

Common issues, root causes, and fixes for **native_workmanager**.

---

## Table of Contents

1. [General Setup](#1-general-setup)
2. [Tasks Not Executing](#2-tasks-not-executing)
3. [Background Execution](#3-background-execution)
4. [HTTP Workers](#4-http-workers)
5. [Chain Differences: iOS vs Android](#5-chain-differences-ios-vs-android)
6. [Custom Workers](#6-custom-workers)
7. [Notifications & Permissions](#7-notifications--permissions)
8. [Debugging Tips](#8-debugging-tips)

---

## 1. General Setup

### `NativeWorkManager.initialize()` not called

**Symptom:** `StateError: NativeWorkManager not initialized` thrown on first API call.

**Fix:** Call `await NativeWorkManager.initialize(...)` in `main()` before `runApp()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize(
    dartWorkers: { /* Dart callbacks */ },
  );
  runApp(const MyApp());
}
```

---

### Android: `KmpWorkManager.initialize()` not called (v1.0.2 regression)

**Symptom:** Tasks enqueued but never execute on Android.

**Cause:** Plugin calls Koin DI initialisation but forgets to call `KmpWorkManager.initialize()`. Fixed in v1.0.2.

**Fix:** Update to `native_workmanager >= 1.0.2`. No user-side change needed.

---

### Android: Hot-restart skips module reload (`isKoinInitialized` stuck)

**Symptom:** After hot-restart in debug mode, new workers are not registered / old config is re-used.

**Cause:** `isKoinInitialized` flag was never cleared in `onDetachedFromEngine()` (audit fix H2, v1.0.7).

**Fix:** Update to `native_workmanager >= 1.0.7`.

---

## 2. Tasks Not Executing

### Task stays in `enqueued` state forever

**Possible causes:**

| Cause | Fix |
|-------|-----|
| Network constraint active but no connectivity | Remove `requiresNetwork: true` or wait for network |
| Android battery optimization kills WorkManager | Exempt your app in device Battery settings |
| iOS BGTask not registered in `Info.plist` | Add `BGTaskSchedulerPermittedIdentifiers` — see [iOS Setup](ANDROID_SETUP.md) |
| Task delay `> 15 minutes` on iOS | iOS BGAppRefresh fires opportunistically; delay is a hint only |

---

### Task cancelled immediately after enqueue

**Symptom:** `TaskStatus.cancelled` shortly after calling `enqueue()`.

**Fix:** Check `ScheduleResult` returned by `enqueue()`:

```dart
final result = await NativeWorkManager.enqueue(...);
if (result != ScheduleResult.accepted) {
  print('Rejected: $result');
}
```

Possible values: `accepted`, `replaced`, `dropped` (duplicate policy conflict).

---

### `ScheduleResult.dropped` for periodic tasks

**Symptom:** Periodic task is silently rejected.

**Cause:** A task with the same `taskId` already exists and `existingPolicy` defaults to `KEEP`.

**Fix:** Use a unique `taskId` per periodic task, or pass `existingPolicy: ExistingWorkPolicy.replace`.

---

## 3. Background Execution

### iOS: Task does not run in the background after app is killed

**Cause:** `BGAppRefreshTask` fires only when the OS decides — it cannot be triggered manually.

**Required setup:**

1. Add `BGTaskSchedulerPermittedIdentifiers` to `Info.plist` with your task identifier.
2. Call `BGTaskScheduler.shared.register(...)` in `AppDelegate.swift` (the plugin does this automatically for built-in workers).
3. Enable **Background Modes → Background fetch** in Xcode Capabilities.

**iOS note:** Periodic tasks that use `while !Task.isCancelled { ... }` in-process **stop when the app is killed**. Use BGAppRefreshTask for true background periodic execution (the plugin logs a warning for this case).

---

### Android: Battery optimisation blocks WorkManager

**Symptom:** Tasks run fine on a fresh test device but not on a user's production device.

**Fix:** Guide users to exempt your app from battery optimization:

```
Settings → Apps → [Your App] → Battery → Unrestricted
```

Or request `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission (requires justification on Google Play).

---

### Android: Exact alarm not firing

**Symptom:** `TaskTrigger.atTime(...)` task fires late or not at all.

**Cause:** Android 12+ restricts `SCHEDULE_EXACT_ALARM`. WorkManager falls back to inexact alarms.

**Fix:**

1. Declare `<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>` in `AndroidManifest.xml`.
2. Direct users to **Settings → Apps → Special app access → Alarms & reminders**.
3. The plugin uses a corrected delta delay for the WorkManager fallback (kmpworkmanager v2.3.6 fix AND-1).

---

## 4. HTTP Workers

### Download stuck at 0% / no progress events

**Possible causes:**

| Cause | Fix |
|-------|-----|
| `showNotification: false` (default) | Progress is still emitted via `NativeWorkManager.events` — listen to the stream |
| Server does not send `Content-Length` header | Progress % cannot be calculated; `bytesDownloaded` is still updated |
| Task not yet started | Check `TaskStatus` — it may be queued waiting for a network constraint |

---

### Resume download fails with "416 Range Not Satisfiable"

**Cause:** The server-side file was updated between attempts (ETag/Last-Modified changed). The `.tmp` sidecar is stale.

**Fix:** This is intentional — the plugin deletes the stale `.tmp` and signals a retry, which re-downloads from the beginning. No user action needed.

---

### Checksum verification fails after successful download

**Possible causes:**

- Wrong `checksumAlgorithm` (default is `SHA-256`)
- Checksum computed on compressed content but HTTP transparently decompresses
- Server returned partial 206 content and checksum covers only the chunk

**Fix:** Verify checksums on the final decompressed file. Use the same algorithm on both sides.

---

### Request signing: `X-Signature` header missing

**Symptom:** Server rejects requests as unsigned.

**Checklist:**

- `secretKey` must be at least 16 characters.
- `includeTimestamp: true` (default) — server must accept the `X-Timestamp` header.
- For GitHub-style webhooks: set `signaturePrefix: 'sha256='` and `headerName: 'X-Hub-Signature-256'`.
- `signBody: true` (default) — make sure server reads raw body before any parsing.

---

### Bandwidth throttling not working on iOS 14

**Expected behaviour:** `bandwidthLimitBytesPerSecond` is silently ignored on iOS 14 (logged as a warning). The download proceeds at full speed.

**Fix:** iOS 15+ is required for streaming throttle. For iOS 14, no error is raised.

---

## 5. Chain Differences: iOS vs Android

Understanding platform behavioural differences is essential for reliable chain usage.

### How chains work on each platform

| Aspect | Android | iOS |
|--------|---------|-----|
| **Mechanism** | WorkManager chain API — each step is a separate Work item | Sequential BGTask scheduling — state tracked in `ChainStateManager` |
| **Persistence** | Work items persisted by WorkManager in Room DB | Chain state persisted in `ChainStateManager` (UserDefaults-backed) |
| **Step failure** | Remaining steps are cancelled automatically | Plugin cancels remaining steps; `isCancelled` checked between steps |
| **App restart mid-chain** | WorkManager resumes from the next pending step automatically | `resumePendingChains()` is called on `applicationDidBecomeActive` |
| **Background execution** | Steps run as background WorkManager tasks | Steps run as BGProcessingTask requests |
| **Constraints** | Applied per-step or to the whole chain | Applied to the whole chain via `BGProcessingTaskRequest` |
| **Cancel by chain ID** | All Work items in chain share a tag — cancel by tag | Chain ID tracked; `ChainStateManager.cancelChain(id:)` |

---

### Chain cancel

**Android:**
```kotlin
// Cancel by tag (assigned automatically to all steps)
NativeWorkManager.cancelByTag(tag: chainName)
```

**iOS:**

Chains are assigned a `chainCancelId` when enqueued. Cancel via the chain name used in `.named("myChain")`:
```dart
await NativeWorkManager.cancel(taskId: 'myChain');
```

**Known iOS issue (fixed v1.0.7 — C1):** Before v1.0.7, chain tasks were not stored in `activeTasks`, so `cancel()` had no effect on iOS chains. Update to v1.0.7+.

---

### Chain resume after app restart

**Android:** Handled transparently by WorkManager. No action needed.

**iOS:** `resumePendingChains()` is called automatically in `applicationDidBecomeActive`. However:

- If the app is **force-killed** (not just backgrounded), BGTasks that were running are restarted by the OS.
- If the chain step was mid-execution when killed, it restarts from that step (not the beginning of the chain).
- Steps that completed before the kill are **not** re-run (state is persisted).

**If chains do not resume on iOS:** Check that `BGTaskSchedulerPermittedIdentifiers` includes all worker identifiers and that Background Modes is enabled.

---

### Chain step ordering guarantees

**Android:** WorkManager guarantees strict sequential ordering. Step B does not start until step A's `ListenableWorker.Result.success()` is returned.

**iOS:** Steps are dispatched sequentially within `executeChain()`. The ordering is guaranteed within a single BGTask execution window. If the OS terminates the BGTask mid-chain, the persisted `nextStepIndex` ensures the chain resumes at the correct step.

---

### Parallel chain steps

**Android:** Supported natively — WorkManager runs parallel steps concurrently.

**iOS:** Parallel steps are run with `async let` / `withTaskGroup` inside `executeChain`. All parallel steps must complete before the next sequential step begins.

---

### Chain timeout

**Android:** Each step has its own WorkManager timeout (default: 10 minutes). WorkManager retries if a step times out (depending on `BackoffPolicy`).

**iOS:** The entire chain must complete within the BGProcessingTask time limit (typically ~30 seconds for BGAppRefreshTask, minutes for BGProcessingTask). If the OS expires the task, the in-progress step is cancelled via `Task.isCancelled` checks.

---

### Recommended chain patterns

```dart
// ✅ Good: short steps that finish quickly
await NativeWorkManager.beginWith(
  TaskRequest(id: 'step-a', worker: HttpRequestWorker(url: apiUrl)),
).then(
  TaskRequest(id: 'step-b', worker: FileCompressionWorker(sourcePath: '/tmp/data')),
).enqueue();

// ⚠️ Risky on iOS: long-running step in a chain
await NativeWorkManager.beginWith(
  TaskRequest(
    id: 'big-download',
    worker: HttpDownloadWorker(url: largeFileUrl, savePath: '/tmp/file.zip'),
  ),
).then(
  TaskRequest(id: 'extract', worker: FileDecompressionWorker(zipPath: '/tmp/file.zip')),
).enqueue();
// → Use useBackgroundSession: true for the download step on iOS
```

---

## 6. Custom Workers

### Custom worker not found: "Unknown worker class"

**Symptom:** `WorkerResult.Failure("Unknown worker class: 'MyWorker'")`.

**Fix (Android):** Register before `NativeWorkManager.initialize()`:

```kotlin
// MainActivity.kt
SimpleAndroidWorkerFactory.registerWorker("MyWorker") { MyWorker() }
```

**Fix (iOS):**

```swift
// AppDelegate.swift
IosWorkerFactory.registerWorker(className: "MyWorker") { MyWorker() }
```

**Fix (Dart):** Ensure `NativeWorker.custom(className: 'MyWorker', ...)` spells the class name exactly as registered on the native side.

---

### iOS: Custom worker receives wrong input

**Symptom:** Custom worker receives `{"input": "..."}` wrapper instead of the actual input map.

**Cause:** Before v1.0.6, `executeWorkerSync()` passed the full `workerConfig` including the `"input"` key wrapper.

**Fix:** Update to `native_workmanager >= 1.0.6`. The plugin now extracts `workerConfig["input"]` before passing to custom workers.

---

## 7. Notifications & Permissions

### Android: No download notification (API 33+)

**Symptom:** `showNotification: true` has no effect on Android 13+.

**Fix:** Request `POST_NOTIFICATIONS` permission at runtime before enqueuing the task:

```dart
// Using permission_handler package:
await Permission.notification.request();
```

---

### iOS: Progress notification not updating

**Symptom:** Completion notification appears but progress percentage is always 0%.

**Cause:** iOS suspends the app during background downloads (`URLSessionConfiguration.background`). Progress KVO updates do not fire while suspended.

**Fix:** This is an OS limitation. Progress is reliably emitted during **foreground** downloads. For background downloads, only the completion notification is guaranteed.

---

## 8. Debugging Tips

### Enable verbose logging

```dart
await NativeWorkManager.initialize(
  dartWorkers: { ... },
  enableDebugNotifications: true,  // Shows per-step debug notifications
);
```

### Listen to all task events

```dart
final sub = NativeWorkManager.events.listen((event) {
  print('[${event.taskId}] success=${event.success} msg=${event.message}');
  if (event.progress != null) {
    print('  progress=${event.progress}% speed=${event.networkSpeed}');
  }
});
```

### Check task status

```dart
final tasks = await NativeWorkManager.allTasks();
for (final t in tasks) {
  print('${t.taskId}: ${t.status}');
}
```

### Android: Inspect WorkManager state

```
adb shell am broadcast -a androidx.work.diagnostics.REQUEST_DIAGNOSTICS --receiver-foreground -n <package>/.WorkManagerDiagnosticsActivity
```

Or use [WorkManager Inspector](https://developer.android.com/studio/inspect/task) in Android Studio.

### iOS: Force BGTask execution in simulator

```swift
// In Xcode console (lldb):
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"dev.brewkits.native_workmanager.refresh"]
```

Or use the **Background Tasks** instrument in Instruments.

---

## See Also

- [iOS Background Execution Limits](IOS_BACKGROUND_LIMITS.md)
- [Platform Consistency](PLATFORM_CONSISTENCY.md)
- [Security Guide](SECURITY.md)
- [Custom Workers](use-cases/07-custom-native-workers.md)
- [Chain Processing Use Case](use-cases/06-chain-processing.md)
