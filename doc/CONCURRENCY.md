# Concurrency Model

This document defines the threading contract for both the Android (Kotlin) and iOS (Swift)
implementations of `native_workmanager`. Read this before touching any shared-state code.

---

## Table of Contents

1. [Guiding Principles](#guiding-principles)
2. [Android — Kotlin Coroutines + ConcurrentHashMap](#android)
3. [iOS — GCD DispatchQueue](#ios)
4. [Shared-State Ownership Table](#ownership-table)
5. [Safe vs Unsafe Patterns](#patterns)
6. [Dart Side — Stream & Isolate Model](#dart)
7. [Common Pitfalls & How to Avoid Them](#pitfalls)
8. [Testing Concurrent Code](#testing)

---

## 1. Guiding Principles <a name="guiding-principles"></a>

1. **One writer, many readers.** Each piece of mutable shared state has exactly
   one designated thread/queue that may write it. All other threads/queues are
   read-only.
2. **Readers acquire no lock.** `ConcurrentHashMap` (Android) and concurrent
   `DispatchQueue` (iOS) allow lock-free reads. Writes use barriers or
   `putIfAbsent` to ensure atomicity.
3. **Compound operations are never split.** A check-then-act (e.g.
   `containsKey` + `put`) is always a single atomic operation — use
   `putIfAbsent` / `compute` (Android) or `barrier` + inline guard (iOS).
4. **CancellationException propagates.** `kotlinx.coroutines.CancellationException`
   is never caught by a generic `catch (e: Exception)` block — it is always
   rethrown so that cooperative cancellation works end-to-end.
5. **No UI-thread blocking.** Native workers run on `Dispatchers.IO` (Android)
   or a concurrent background queue (iOS). Platform-channel callbacks are
   dispatched back to the main thread **after** the worker completes.

---

## 2. Android — Kotlin Coroutines + ConcurrentHashMap <a name="android"></a>

### 2.1 Coroutine Scopes

| Scope | Dispatcher | Used for |
|---|---|---|
| `mainScope` | `Dispatchers.Main` | Platform-channel method calls, UI-thread callbacks |
| `ioScope` | `Dispatchers.IO` | SQLite reads/writes, file I/O, HTTP |
| WorkManager internal | `Dispatchers.Default` | CPU-bound work inside `CoroutineWorker.doWork()` |

```kotlin
// NativeWorkmanagerPlugin.kt — scope declarations
private val mainScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
private val ioScope   = CoroutineScope(Dispatchers.IO  + SupervisorJob())
```

Scopes are cancelled in `onDetachedFromEngine()`. **Never** launch a coroutine
on a raw `GlobalScope` — lifecycle leaks.

### 2.2 Shared State

```
activeTasks: ConcurrentHashMap<String, WorkInfo>
```

**Write operations** (must be atomic):

```kotlin
// ✅ Correct — atomic insert-if-absent
activeTasks.putIfAbsent(taskId, workInfo)

// ✅ Correct — conditional update (compute is atomic)
activeTasks.compute(taskId) { _, existing ->
    if (existing == null) workInfo else existing
}

// ❌ Wrong — TOCTOU race
if (!activeTasks.containsKey(taskId)) {   // read
    activeTasks[taskId] = workInfo         // write — gap between these two lines
}
```

**Remove + read as a unit:**

```kotlin
// ✅ Correct
activeTasks.remove(taskId)?.let { info ->
    // use info — it was atomically removed
}
```

### 2.3 SQLite Access

All five `*Store` classes (`TaskStore`, `ChainStore`, `GraphStore`,
`OfflineQueueStore`, `MiddlewareStore`) run exclusively on **`ioScope`** /
`Dispatchers.IO`.

```kotlin
// ✅ Correct — DB work on IO dispatcher
ioScope.launch {
    taskStore.upsert(record)
    chainStore.markStepComplete(chainId, stepId)
}

// ❌ Wrong — blocking the main thread
mainScope.launch {
    taskStore.upsert(record)  // SQLite on Main thread → ANR risk
}
```

**Cross-store operations** that must be atomic wrap both stores in a single
SQLite transaction:

```kotlin
db.beginTransaction()
try {
    taskStore.insert(record, db)
    offlineQueueStore.enqueue(entry, db)
    db.setTransactionSuccessful()
} finally {
    db.endTransaction()
}
```

> **Rule:** If you write to more than one store in response to a single user
> action, use a shared transaction. If you don't, a crash between the two
> writes creates inconsistent state.

### 2.4 CancellationException Contract

```kotlin
// ✅ Always rethrow CancellationException before any generic catch
try {
    doSomeWork()
} catch (e: CancellationException) {
    throw e   // ← must be first
} catch (e: Exception) {
    log.warn("Worker failed", e)
}
```

WorkManager's cooperative cancellation relies on `CancellationException`
propagating up the call stack. Swallowing it causes tasks to appear stuck.

### 2.5 Koin DI Initialization

`isKoinInitialized: Boolean` is guarded by `@Synchronized` in
`onAttachedToEngine()` and reset to `false` in `onDetachedFromEngine()`.
Never read it outside these two lifecycle methods.

---

## 3. iOS — GCD DispatchQueue <a name="ios"></a>

### 3.1 Queue Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│  DispatchQueue.main (serial)                                │
│  Platform channel callbacks, FlutterEventSink calls        │
└─────────────────────────────────────────────────────────────┘
          ▲ always dispatch_async to main when emitting events

┌─────────────────────────────────────────────────────────────┐
│  stateQueue (concurrent, QoS: .userInitiated)              │
│  Owns: activeTasks, taskStartTimes, chainState             │
│  Reads: concurrent (no barrier)                             │
│  Writes: async(flags: .barrier)                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  workerQueue (concurrent, QoS: .background)                │
│  Runs worker execution (URLSession, file I/O, crypto)      │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  dbQueue (serial, QoS: .utility)                           │
│  Owns: SQLite TaskStore, ChainStateManager                  │
│  All reads AND writes go through this serial queue         │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 stateQueue Read/Write Pattern

```swift
// ✅ Read — concurrent, no barrier
var count: Int {
    stateQueue.sync { activeTasks.count }
}

// ✅ Write — barrier (exclusive access)
func register(_ task: Task, for id: String) {
    stateQueue.async(flags: .barrier) {
        self.activeTasks[id] = task
    }
}

// ✅ Read + conditional write — full barrier to prevent TOCTOU
// Note: `.barrier` is only valid with `async`, not `sync`.
// Use a serial queue or a dedicated write lock for synchronous exclusive access.
func registerIfAbsent(_ task: Task, for id: String) {
    stateQueue.async(flags: .barrier) {
        guard self.activeTasks[id] == nil else { return }
        self.activeTasks[id] = task
    }
}
// If you need to wait for the write to complete (e.g., in a test), use:
func registerIfAbsentSync(_ task: Task, for id: String) {
    // Use a serial private queue for synchronous exclusive writes.
    stateSerialQueue.sync {
        guard self.activeTasks[id] == nil else { return }
        self.activeTasks[id] = task
    }
}

// ❌ Wrong — separate read and write; race window between them
if activeTasks[id] == nil {          // concurrent read
    stateQueue.async(flags: .barrier) {
        self.activeTasks[id] = task  // too late — another thread may have inserted
    }
}
```

### 3.3 TaskStartTimes — Both Read and Remove Are Guarded

`taskStartTimes` is accessed from two call sites: `showDebugNotification`
(read) and the task-completion handler (remove). Both must be inside
`stateQueue`.

```swift
// ✅ Read inside stateQueue.sync
let start: Date? = stateQueue.sync { taskStartTimes[taskId] }

// ✅ Remove inside barrier
stateQueue.async(flags: .barrier) {
    self.taskStartTimes.removeValue(forKey: taskId)
}
```

### 3.4 Platform-Channel Event Emission

All `FlutterEventSink` calls **must** be dispatched to the main queue:

```swift
// ✅ Correct
DispatchQueue.main.async {
    self.eventSink?(result)
}

// ❌ Wrong — calling sink from background queue → runtime crash
workerQueue.async {
    self.eventSink?(result)  // UIKit/FlutterEventSink is not thread-safe
}
```

### 3.5 URLSession Background Delegate Lifetime

`BackgroundSessionManager` holds a **strong** reference to itself until
`urlSessionDidFinishEvents(forBackgroundURLSession:)` is called. Never let
the delegate become `nil` before that callback — iOS will wake the app but
find no delegate to invoke.

```swift
// In AppDelegate / FlutterAppDelegate
func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
) {
    // ← plugin stores completionHandler; called after all delegate methods finish
    NativeWorkmanagerPlugin.handleBackgroundSession(
        identifier: identifier,
        completionHandler: completionHandler
    )
}
```

### 3.6 BGTaskScheduler 30-Second Budget

`BGAppRefreshTask` has a ~30-second execution budget. Workers that might
exceed 25 seconds should use `BGProcessingTask` (`Constraints(bgTaskType: .processing)`).

All workers wrap their execution in a defensive timeout:

```swift
// 25s hard limit — leaves 5s buffer for cleanup
let timeoutTask = DispatchWorkItem {
    self.finishBGTask(success: false, reason: "timeout")
}
DispatchQueue.global().asyncAfter(deadline: .now() + 25, execute: timeoutTask)

// Cancel timeout if work finishes normally
defer { timeoutTask.cancel() }
```

### 3.7 resolvingSymlinksInPath() on Non-Existent Paths

`/var` → `/private/var` is a symlink. Output files don't exist yet, so calling
`.resolvingSymlinksInPath()` on them returns the unresolved path. Always walk
up to the deepest existing ancestor:

```swift
func resolvedPath(_ url: URL) -> URL {
    var candidate = url
    while !FileManager.default.fileExists(atPath: candidate.path) {
        candidate = candidate.deletingLastPathComponent()
        if candidate.path == "/" { return url } // safety — don't walk forever
    }
    let resolved = candidate.resolvingSymlinksInPath()
    return resolved.appendingPathComponent(
        url.path.dropFirst(candidate.path.count + 1) // re-append suffix
    )
}
```

---

## 4. Shared-State Ownership Table <a name="ownership-table"></a>

| State | Platform | Owner thread/queue | Read from | Write from |
|---|---|---|---|---|
| `activeTasks` | Android | any (ConcurrentHashMap) | any | `putIfAbsent` / `compute` |
| `activeTasks` | iOS | `stateQueue` | `stateQueue.sync {}` | `stateQueue.async(flags:.barrier) {}` |
| `taskStartTimes` | iOS | `stateQueue` | `stateQueue.sync {}` | `stateQueue.async(flags:.barrier) {}` |
| `TaskStore` (SQLite) | Android | `Dispatchers.IO` | `ioScope` | `ioScope` |
| `TaskStore` (SQLite) | iOS | `dbQueue` (serial) | `dbQueue.sync {}` | `dbQueue.sync {}` |
| `ChainStateManager` | iOS | `dbQueue` | `dbQueue.sync {}` | `dbQueue.sync {}` |
| `FlutterEventSink` | Both | `DispatchQueue.main` / `Dispatchers.Main` | main only | main only |
| `isKoinInitialized` | Android | main thread | `@Synchronized` | `@Synchronized` |
| `_dartWorkers` map | Dart | main isolate | main isolate | `initialize()` only |

---

## 5. Safe vs Unsafe Patterns <a name="patterns"></a>

### Android

```kotlin
// ✅ Safe — atomic ConcurrentHashMap operation
activeTasks.putIfAbsent(id, info)

// ✅ Safe — remove-and-use atomically
val removed = activeTasks.remove(id) ?: return

// ✅ Safe — CancellationException rethrown
try { work() } catch (e: CancellationException) { throw e } catch (e: Exception) { log(e) }

// ✅ Safe — cross-store atomic write
db.beginTransaction(); try { storeA.write(); storeB.write(); db.setTransactionSuccessful() }
finally { db.endTransaction() }

// ❌ Unsafe — TOCTOU
if (!activeTasks.containsKey(id)) { activeTasks[id] = info }

// ❌ Unsafe — CancellationException swallowed
try { work() } catch (e: Exception) { log(e) }

// ❌ Unsafe — DB on main thread
mainScope.launch { taskStore.insert(record) }
```

### iOS

```swift
// ✅ Safe — concurrent read
let task = stateQueue.sync { activeTasks[id] }

// ✅ Safe — exclusive write
stateQueue.async(flags: .barrier) { activeTasks[id] = task }

// ✅ Safe — atomic check-and-insert (async barrier, non-blocking caller)
stateQueue.async(flags: .barrier) {
    guard self.activeTasks[id] == nil else { return }
    self.activeTasks[id] = task
}
// ✅ Safe — synchronous exclusive write via serial queue
stateSerialQueue.sync {
    guard activeTasks[id] == nil else { return }
    activeTasks[id] = task
}

// ✅ Safe — event to Flutter
DispatchQueue.main.async { eventSink?(event) }

// ❌ Unsafe — write without barrier (concurrent queue allows simultaneous writes)
stateQueue.async { activeTasks[id] = task }  // missing .barrier flag

// ❌ Unsafe — event on background queue
workerQueue.async { eventSink?(event) }

// ❌ Unsafe — bare symlink resolution on non-existent path
let safe = url.resolvingSymlinksInPath()  // may return unresolved /var path
```

---

## 6. Dart Side — Stream & Isolate Model <a name="dart"></a>

### Streams

`NativeWorkManager.events` and `NativeWorkManager.progress` are
`StreamController.broadcast()` instances. They are fed from the
`EventChannel` on the main isolate. **All listeners run on the main isolate.**
Do not perform blocking I/O inside `.listen()` callbacks.

### DartWorker Isolate

`DartWorker` callbacks run inside a **secondary Flutter Engine** (separate
Dart isolate). The 5-minute warm-engine cache means the isolate may be
re-used across consecutive tasks — but each task invocation is serial within
that isolate.

**Cannot share mutable state** between the app isolate and the DartWorker
isolate. Use the `input`/`output` map for data exchange.

```dart
// ✅ Correct — communicate via input map
DartWorker(
  callbackId: WorkerIds.processData,
  input: {'ids': [1, 2, 3]},  // serialized through JSON
)

// ❌ Wrong — shared in-memory state won't work across isolates
var sharedList = [1, 2, 3];
DartWorker(callbackId: 'processData')
// the callback will NOT see sharedList
```

### Initialization Safety

`NativeWorkManager.initialize()` is protected by a `Completer<void>` so that
concurrent calls (e.g. `await Future.wait([init(), init()])`) wait on the
first in-flight initialization rather than racing past the `_initialized` flag.

```dart
// Safe — second call awaits the first Completer instead of racing
await Future.wait([
  NativeWorkManager.initialize(dartWorkers: workers),
  NativeWorkManager.initialize(dartWorkers: workers), // waits, does not double-init
]);
```

### DartWorker — FlutterEngineManager Lifecycle

`DartWorker` callbacks run inside a **secondary Flutter Engine** managed by
`FlutterEngineManager`. Understanding its lifecycle prevents memory leaks and
unexpected cold-start penalties.

```
First DartWorker task arrives
        │
        ▼
FlutterEngineManager.getEngine()
        │
        ├── Engine already warm (< 5 min since last use)?
        │       └── Return cached engine  ← ~100 ms warm-start
        │
        └── No warm engine?
                └── Boot new engine       ← ~500–2000 ms cold-start
                        │
                        ▼
                  Register 5-min eviction timer
```

**Warm retention window (5 minutes):**
- Every task completion resets the eviction timer.
- During the window the engine consumes ~50 MB RAM in the background.
- If `autoDispose: true` is set, the engine is torn down **immediately** after
  the callback returns — no warm window, no 50 MB overhead, but cold-start on
  the next task.

**Thread safety:**
- `FlutterEngineManager` is accessed from `workerQueue` (concurrent).
- Engine creation is serialised behind an internal `NSLock`/`Mutex` — only one
  engine is ever booted at a time.
- The eviction timer fires on a private serial queue; it acquires the same lock
  before tearing down the engine, so no race with in-flight callbacks.

**Key rules:**
- Never hold a strong reference to the `FlutterEngine` returned by
  `getEngine()` beyond the scope of the worker execution — the manager owns
  the engine lifetime.
- Do not call `FlutterEngine.run()` or `FlutterEngine.destroy()` manually.
- `autoDispose: true` is safe to combine with chained `DartWorker` steps, but
  each step pays the full cold-start cost.

---

## 7. Common Pitfalls <a name="pitfalls"></a>

| # | Pitfall | Root Cause | Fix |
|---|---|---|---|
| P-1 | Tasks appear stuck after cancel | `CancellationException` swallowed | Always rethrow before generic `catch` |
| P-2 | Duplicate task entry in `activeTasks` | TOCTOU `containsKey + put` | Use `putIfAbsent` / `compute` |
| P-3 | `FlutterEventSink` crash on iOS | Called from non-main queue | Wrap in `DispatchQueue.main.async` |
| P-4 | Sandbox violation on real iOS device | Symlink `/var` unresolved | Use `resolvedPath()` helper (walk ancestors) |
| P-5 | Download progress stops mid-way | `taskStartTimes` removed without `stateQueue` barrier | Read and remove inside `stateQueue` |
| P-6 | Hot-restart skips Koin re-init | `isKoinInitialized` not reset | Set to `false` in `onDetachedFromEngine()` |
| P-7 | Cross-store inconsistency after crash | Two store writes not in same transaction | Wrap in single `db.beginTransaction()` |
| P-8 | BGTask budget exceeded | DartWorker cold-start + logic exceeds 30 s | Add 25 s hard timeout; use `BGProcessingTask` |
| P-9 | DartWorker state not visible to app | Isolate memory is separate | Pass all data via `input`/result maps |

---

## 8. Testing Concurrent Code <a name="testing"></a>

### Android — Coroutine Test Rules

```kotlin
@get:Rule
val coroutineRule = MainCoroutineRule()   // replaces Dispatchers.Main with TestCoroutineDispatcher

@Test
fun `put if absent is atomic`() = runTest {
    val map = ConcurrentHashMap<String, String>()
    val jobs = (1..100).map {
        launch(Dispatchers.IO) { map.putIfAbsent("key", "value-$it") }
    }
    jobs.joinAll()
    assertEquals(1, map.size)
}
```

### iOS — XCTest + DispatchQueue

```swift
func testBarrierWriteIsExclusive() {
    let queue = DispatchQueue(label: "test", attributes: .concurrent)
    var dict = [String: Int]()
    let expectation = expectation(description: "all writes complete")
    expectation.expectedFulfillmentCount = 100

    for i in 0..<100 {
        queue.async(flags: .barrier) {
            dict["key-\(i)"] = i
            expectation.fulfill()
        }
    }

    waitForExpectations(timeout: 5)
    XCTAssertEqual(dict.count, 100)
}
```

### Dart — FakeWorkManager (unit tests)

Use `FakeWorkManager` from `package:native_workmanager/testing.dart` to test
business logic without a platform channel:

```dart
test('service cancels all on logout', () async {
  final wm = FakeWorkManager();
  final service = UserService(wm);

  await service.logout();

  expect(wm.cancelAllCalled, isTrue);
  wm.dispose();
});
```

---

*Last updated: 2026-04-03 — applies to native_workmanager v1.1.1*
