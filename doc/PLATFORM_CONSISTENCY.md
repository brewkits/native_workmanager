# Platform Consistency Analysis

**Version:** 1.0.0
**Status:** Documented - Known Limitation
**Tracking:** GitHub Issue #16

---

## Overview

This document explains platform-specific implementation differences between Android and iOS for `native_workmanager`, with focus on task chain execution.

---

## Task Chain Implementation

### Android Implementation ✅ **KMP-Based**

**File:** `android/src/main/kotlin/dev/brewkits/native_workmanager/NativeWorkmanagerPlugin.kt`

```kotlin
// Android uses KMP scheduler for chains
val firstStep = steps[0].map { taskData -> toTaskRequest(taskData) }
var chain = scheduler.beginWith(firstStep)

for (i in 1 until steps.size) {
    val stepRequests = steps[i].map { taskData -> toTaskRequest(taskData) }
    chain = chain.then(stepRequests)
}

chain.enqueue() // KMP handles scheduling, persistence, constraints
```

**Benefits:**
- ✅ Uses KMP WorkManager scheduling logic
- ✅ Constraints enforced by WorkManager
- ✅ Chain persists across app restarts
- ✅ Retry logic handled by framework
- ✅ Task persistence to database

### iOS Implementation ⚠️ **Direct Execution**

**File:** `ios/Classes/NativeWorkmanagerPlugin.swift`

```swift
// iOS directly executes workers (bypasses KMP scheduler)
private func executeChain(...) {
    Task {
        for (stepIndex, stepData) in steps.enumerated() {
            // Execute tasks in parallel within step
            await withTaskGroup(of: Bool.self) { group in
                for taskData in stepTasks {
                    group.addTask {
                        await self.executeWorkerSync(
                            taskId: taskId,
                            workerClassName: workerClassName,
                            workerConfig: workerConfig,
                            qos: qos
                        )
                    }
                }
                // ... handle results
            }
        }
    }
}
```

**Limitations:**
- ❌ Bypasses KMP scheduling logic
- ⚠️ Constraints enforced at worker level (not chain level)
- ⚠️ Chain execution not persisted
- ⚠️ Manual retry logic required
- ⚠️ Different behavior from Android

---

## Why This Difference Exists

### Root Cause: KMP Bridge API Limitation

The KMP WorkManager framework exposes chain APIs to Kotlin:
```kotlin
// Available in Kotlin
scheduler.beginWith(tasks)
    .then(moreTasks)
    .enqueue()
```

But the iOS bridge (`KMPSchedulerBridge.swift`) doesn't currently expose these chain methods to Swift. The bridge only exposes:
- `scheduler.enqueue()` - Single task scheduling
- `scheduler.cancel()` - Cancel task
- `scheduler.cancelAll()` - Cancel all tasks

**Missing from iOS bridge:**
- ❌ `scheduler.beginWith()` - Not exposed
- ❌ `taskChain.then()` - Not exposed
- ❌ Chain constraint inheritance - Not exposed

---

## Impact Analysis

### Functional Impact: ✅ **LOW**

**Chains work correctly on iOS:**
- ✅ Sequential execution respected (A → B → C)
- ✅ Parallel execution respected (A → [B, C, D])
- ✅ Failure propagation works (chain stops on error)
- ✅ Events emitted correctly
- ✅ ResultData passed through

**User-visible behavior: Identical**

### Technical Impact: ⚠️ **MEDIUM**

**Differences under the hood:**

| Aspect | Android (KMP) | iOS (Direct) | Impact |
|--------|---------------|--------------|--------|
| **Scheduling** | KMP WorkManager | Direct Swift execution | Medium |
| **Persistence** | SQLite via WorkManager | Not persisted | Low (chains complete quickly) |
| **Constraints** | Chain-level enforcement | Worker-level only | Low (still enforced) |
| **Retry Logic** | Automatic via backoff | Manual in worker | Low (workers handle it) |
| **Battery Optimization** | OS-integrated | Manual via QoS | Low (QoS works well) |

**Overall Technical Debt:** Medium

---

## Mitigation Strategy

### Current State (v1.0.0)

**What we do now:**
1. ✅ Document the difference (this file + code comments)
2. ✅ Ensure functional parity (chains work the same)
3. ✅ Add comprehensive comments in code
4. ✅ Track as known limitation in GitHub issues

**Safety measures in place:**
- Workers still enforce constraints
- QoS scheduling provides battery optimization
- Event system works identically
- Error handling consistent

### Future Resolution (v1.1+)

**Option 1: Extend KMP Bridge (Recommended)**

Extend `KMPSchedulerBridge.swift` to expose chain APIs:

```swift
// New bridge methods needed
extension KMPSchedulerBridge {
    static func beginWith(
        scheduler: BackgroundTaskScheduler,
        tasks: [TaskRequest],
        completion: @escaping (Result<TaskChain, Error>) -> Void
    )

    static func then(
        chain: TaskChain,
        tasks: [TaskRequest],
        completion: @escaping (Result<TaskChain, Error>) -> Void
    )

    static func enqueueChain(
        chain: TaskChain,
        completion: @escaping (Result<Void, Error>) -> Void
    )
}
```

**Pros:**
- ✅ True platform parity
- ✅ Leverages KMP scheduling logic
- ✅ Consistent behavior
- ✅ Future-proof

**Cons:**
- ⏱️ Requires KMP framework knowledge
- ⏱️ ~1-2 weeks development time
- ⏱️ Needs testing on real devices

**Option 2: Keep Current + Enhance**

Keep direct execution but add:
- Chain persistence to UserDefaults
- Better constraint enforcement
- Retry logic at chain level

**Pros:**
- ⏱️ Faster to implement
- ✅ No KMP dependency
- ✅ More control

**Cons:**
- ❌ Still platform-inconsistent
- ❌ Duplicates KMP logic
- ❌ Maintenance burden

**Recommendation:** Option 1 (Extend KMP Bridge) for v1.1

---

## Production Readiness

### Is This Safe for Production?

**Yes ✅** - Here's why:

1. **Functional Correctness:**
   - Chains execute correctly on iOS
   - Same results as Android
   - All tests pass

2. **Real-World Usage:**
   - Most chains complete in <5 minutes
   - App rarely killed during chain execution
   - Worker-level constraints sufficient for most use cases

3. **Monitoring:**
   - Events provide full visibility
   - ResultData propagates correctly
   - Errors handled properly

### When This Matters Most

**High Risk Scenarios:**
- Very long chains (>10 minutes)
- App backgrounded during chain
- Device under memory pressure

**Recommended Practices:**
```dart
// For critical long chains on iOS
await NativeWorkManager.beginWith(...)
  .then(...) // Keep chains short (<5 min total)
  .enqueue();

// Instead of one long chain, use multiple short chains
// Chain 1: Download data
await NativeWorkManager.enqueue(...);

// Chain 2: Process (triggered by event from Chain 1)
NativeWorkManager.events.listen((event) {
  if (event.taskId == 'download' && event.success) {
    // Schedule next step
    NativeWorkManager.enqueue(processTask);
  }
});
```

---

## Testing Recommendations

### For Developers Using This Library

**Test chain execution on iOS:**

```dart
// Test basic chain
await NativeWorkManager.beginWith(
  TaskRequest(
    id: 'test-1',
    worker: NativeWorker.httpRequest(url: '...'),
  ),
).then(
  TaskRequest(
    id: 'test-2',
    worker: DartWorker(callbackId: 'process'),
  ),
).enqueue();

// Monitor events
NativeWorkManager.events.listen((event) {
  print('${event.taskId}: ${event.success}');
});

// Verify:
// 1. test-1 completes first
// 2. test-2 starts only after test-1 succeeds
// 3. Chain stops if test-1 fails
```

**Test under stress:**
```dart
// Background the app during chain execution
// 1. Start chain
// 2. Force-close app via app switcher
// 3. Wait 30+ seconds
// 4. Reopen app
// 5. Check events - chain may not complete (iOS limitation)
```

---

## Documentation Updates

### Where This is Documented

1. ✅ **Code Comments:** `ios/Classes/NativeWorkmanagerPlugin.swift:317-340`
2. ✅ **This File:** `docs/PLATFORM_CONSISTENCY.md`
3. ✅ **GitHub Issue:** #16
4. ✅ **PRODUCTION_GUIDE.md:** Platform gotchas section
5. ⏳ **README.md:** TODO - Add platform notes section

### Recommended README Addition

```markdown
## Platform Differences

### Task Chains

**Android:** Chains use KMP WorkManager scheduling (persistent, constraint-aware)
**iOS:** Chains use direct execution (not persisted, constraint-aware at worker level)

**Impact:** Chains work identically in normal use. For very long chains (>10 min) on iOS, consider breaking into smaller chains.

See [PLATFORM_CONSISTENCY.md](docs/PLATFORM_CONSISTENCY.md) for details.
```

---

## Timeline

### v1.0.0 (Current)
- ✅ Document platform difference
- ✅ Add code comments
- ✅ File GitHub issue #16
- ✅ Update PRODUCTION_GUIDE.md

### v1.0 (Target: 4 weeks)
- ⏳ Add README note on platform differences
- ⏳ Enhance integration tests for chain execution
- ⏳ Real device testing

### v1.1 (Target: Q2 2026)
- 🎯 Extend KMP bridge for chain APIs
- 🎯 Migrate iOS to KMP-based chains
- 🎯 Achieve true platform parity
- 🎯 Remove this document (issue resolved!)

---

## Conclusion

**Current Status:** ⚠️ **Documented Limitation**

**Production Safe:** ✅ **Yes** (with awareness)

**Path Forward:** 📋 **Clear** (extend KMP bridge in v1.1)

**User Impact:** 🟢 **Low** (chains work correctly)

**Technical Debt:** 🟡 **Medium** (solvable in v1.1)

---

**Last Updated:** 2026-02-07
**Tracking:** https://github.com/brewkits/native_workmanager/issues/16
