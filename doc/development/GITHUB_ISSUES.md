# GitHub Issues - iOS TODOs and Critical Improvements

This document contains GitHub issue templates ready to be filed for the native_workmanager project.

---

## Issue #1: Implement task status query (iOS)

**Title:** Implement task status query on iOS

**Labels:** `enhancement`, `ios`, `todo`

**Description:**

### Problem
The `getTaskStatus` method is not implemented on iOS. Currently returns `nil` for all queries.

**File:** `ios/Classes/NativeWorkmanagerPlugin.swift:312-315`
```swift
private func handleGetTaskStatus(call: FlutterMethodCall, result: @escaping FlutterResult) {
    // TODO: Implement task status query
    result(nil)
}
```

### Expected Behavior
iOS should return task status similar to Android:
- `"pending"` - Task scheduled but not yet run
- `"running"` - Task currently executing
- `"completed"` - Task finished successfully
- `"failed"` - Task finished with error
- `"cancelled"` - Task was cancelled
- `null` - Task not found

### Proposed Solution
1. Maintain task status map in `NativeWorkmanagerPlugin.swift`
2. Update status when tasks execute via BGTaskScheduler
3. Query KMP scheduler for task status if available
4. Return status matching Android implementation

### Acceptance Criteria
- [ ] `getTaskStatus()` returns correct status for iOS tasks
- [ ] Status updates when tasks execute
- [ ] Platform parity with Android implementation
- [ ] Add unit tests for status tracking

---

## Issue #2: Subscribe to KMP TaskEventBus on iOS

**Title:** Subscribe to KMP TaskEventBus for event streaming (iOS)

**Labels:** `enhancement`, `ios`, `todo`, `kmp-integration`

**Description:**

### Problem
iOS doesn't subscribe to KMP TaskEventBus, leading to inconsistent event emission compared to Android.

**File:** `ios/Classes/NativeWorkmanagerPlugin.swift:575-580`
```swift
public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events

    // TODO: Subscribe to KMP TaskEventBus
    // Task {
    //     for await event in TaskEventBus.shared.events {
    //         events([...])
    //     }
    // }

    return nil
}
```

### Expected Behavior
iOS should emit events via TaskEventBus just like Android does.

**Android reference:** `android/.../NativeWorkmanagerPlugin.kt:152-218`
```kotlin
TaskEventBus.events.collect { event ->
    eventSink?.success(mapOf(
        "taskId" to event.taskName,
        "success" to event.success,
        "message" to event.message,
        "resultData" to event.outputData,
        "timestamp" to System.currentTimeMillis()
    ))
}
```

### Proposed Solution
1. Import TaskEventBus from kmpworkmanager
2. Subscribe to event stream in `onListen`
3. Map events to Flutter format
4. Ensure thread safety with Swift Concurrency
5. Handle subscription cleanup in `onCancel`

### Acceptance Criteria
- [ ] iOS emits events via TaskEventBus
- [ ] Event format matches Android (taskId, success, message, resultData, timestamp)
- [ ] Subscription properly cleaned up on cancel
- [ ] Add integration test verifying event emission

---

## Issue #3: Add progress update subscription (iOS)

**Title:** Implement progress update subscription on iOS

**Labels:** `enhancement`, `ios`, `todo`, `feature`

**Description:**

### Problem
Progress channel subscription is not implemented on iOS.

**File:** `ios/Classes/NativeWorkmanagerPlugin.swift:600-608`
```swift
func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    // TODO: Subscribe to progress updates
    return nil
}
```

### Expected Behavior
iOS should emit progress updates for long-running workers.

**Android reference:** `android/.../NativeWorkmanagerPlugin.kt:140-150`
```kotlin
scope.launch {
    try {
        ProgressReporter.progressFlow.collect { update ->
            progressSink?.success(update.toMap())
        }
    } catch (e: Exception) {
        Log.e(TAG, "Error in progress subscription", e)
    }
}
```

### Proposed Solution
1. Create iOS ProgressReporter similar to Android
2. Workers call ProgressReporter.emit(taskId, progress, message)
3. Subscribe to progress stream in ProgressStreamHandler
4. Emit to Flutter via progress channel

### Acceptance Criteria
- [ ] iOS emits progress updates via progress channel
- [ ] HttpDownloadWorker reports download progress
- [ ] HttpUploadWorker reports upload progress
- [ ] Event format matches Android
- [ ] Add example app demo of progress tracking

---

## Issue #4: Fix iOS chain execution to use KMP scheduler

**Title:** iOS task chains bypass KMP scheduler - fix platform inconsistency

**Labels:** `bug`, `ios`, `critical`, `architecture`

**Description:**

### Problem
**Platform Inconsistency:** Android uses KMP scheduler for chains, iOS executes workers directly.

**iOS:** `ios/Classes/NativeWorkmanagerPlugin.swift:343-405`
```swift
private func executeChain(steps: [[Any]], ...) {
    // Directly executes workers, bypassing KMP scheduler
    await self.executeWorkerSync(...)
}
```

**Android:** `android/.../NativeWorkmanagerPlugin.kt:389-418`
```kotlin
val firstStep = steps[0].map { taskData -> toTaskRequest(taskData) }
var chain = scheduler.beginWith(firstStep)
for (i in 1 until steps.size) {
    val stepRequests = steps[i].map { taskData -> toTaskRequest(taskData) }
    chain = chain.then(stepRequests)
}
chain.enqueue()
```

### Impact
- ❌ iOS chains don't benefit from KMP scheduling logic
- ❌ Constraints may not be enforced correctly
- ❌ Task persistence differs between platforms
- ❌ Different behavior on Android vs iOS

### Proposed Solution
1. Refactor `handleEnqueueChain` to use KMP scheduler on iOS
2. Remove direct worker execution in `executeChain`
3. Match Android implementation (beginWith → then → enqueue)
4. Ensure platform parity

### Acceptance Criteria
- [ ] iOS chains use KMP scheduler like Android
- [ ] Constraints properly enforced on iOS chains
- [ ] Platform behavior is consistent
- [ ] Add integration test for cross-platform chain parity

---

## Issue #5: Add comprehensive test suite

**Title:** Add unit, widget, and integration tests (CRITICAL for v1.0)

**Labels:** `critical`, `testing`, `v1.0-blocker`

**Priority:** **P0 - Blocker**

**Description:**

### Problem
**Current test coverage: ~2%**
- ❌ NO unit tests in `test/` directory
- ❌ NO widget tests
- ✅ Only 3 basic integration tests in `example/integration_test/`

**This is the #1 blocker for v1.0 release.**

### Required Test Coverage

#### Unit Tests (`test/`)
```dart
// test/task_trigger_test.dart
- TaskTrigger.oneTime() creates correct JSON
- TaskTrigger.periodic() validates minimum interval
- TaskTrigger.exact() validates future timestamp
- TaskTrigger.windowed() validates window constraints

// test/constraints_test.dart
- Constraints validation (negative values should throw)
- JSON serialization correctness
- Platform-specific constraint handling

// test/worker_test.dart
- Worker factory creation
- JSON serialization for each worker type
- Custom worker input validation
```

#### Widget Tests (`test/`)
```dart
// test/native_work_manager_test.dart
- enqueue() returns SUCCESS on valid input
- enqueue() returns ERROR on invalid input
- cancel() works correctly
- cancelAll() clears all tasks
```

#### Integration Tests (`example/integration_test/`)
```dart
// workers_test.dart
- All 8 built-in workers execute successfully
- Workers return correct resultData
- Error handling scenarios
- Constraint enforcement

// chains_test.dart
- Sequential chain execution
- Parallel step execution
- Chain failure handling
- Cross-platform parity
```

### Acceptance Criteria
- [ ] Unit test coverage ≥ 80%
- [ ] All public APIs have widget tests
- [ ] All workers have integration tests
- [ ] CI/CD runs tests automatically
- [ ] Code coverage report uploaded to codecov

### Timeline
**Estimate:** 3 weeks
- Week 1: Unit tests
- Week 2: Widget tests
- Week 3: Integration tests + CI/CD

---

## Issue #6: Create PRODUCTION_GUIDE.md

**Title:** Add production deployment guide with error handling patterns

**Labels:** `documentation`, `v1.0-blocker`

**Priority:** **P0 - Blocker**

**Description:**

### Problem
Developers don't know how to:
- Handle errors from workers
- Debug background tasks
- Monitor task execution
- Deploy safely to production

### Required Content

**PRODUCTION_GUIDE.md should cover:**

1. **Error Handling Patterns**
   - How to handle HTTP errors (timeouts, 404, 500)
   - File operation errors (permissions, disk full)
   - Network unavailable scenarios
   - Retry strategies

2. **Testing Strategies**
   - How to test background workers
   - Mocking native workers
   - Testing task chains
   - Testing constraints

3. **Platform-Specific Gotchas**
   - iOS 30s time limit for appRefresh tasks
   - Android Doze mode behavior
   - Battery optimization settings
   - Network constraint differences

4. **Monitoring & Observability**
   - Logging best practices
   - Tracking task success rates
   - Performance monitoring
   - Error reporting integration

5. **Common Failure Modes**
   - Engine initialization failures
   - Permission denied errors
   - Timeout scenarios
   - Recovery strategies

6. **Production Deployment Checklist**
   - [ ] Test on low-end devices
   - [ ] Test with poor network
   - [ ] Test with battery saver enabled
   - [ ] Add error logging
   - [ ] Set up monitoring
   - [ ] etc.

### Acceptance Criteria
- [ ] PRODUCTION_GUIDE.md created with all sections
- [ ] Code examples for each error scenario
- [ ] Platform-specific notes clearly marked
- [ ] Checklist ready to copy-paste

---

## Issue #7: Security audit - Add file size limits and URL validation

**Title:** Security enhancements: file size limits and URL scheme whitelist

**Labels:** `security`, `enhancement`, `v1.0`

**Priority:** **P1**

**Description:**

### Security Issues Found

#### 1. No File Size Limits (OOM Risk)
**HttpUploadWorker.kt** - Missing file size validation
```kotlin
// CURRENT (vulnerable):
val file = File(filePath)
// User can upload arbitrary size file → OOM risk

// PROPOSED:
private const val MAX_UPLOAD_SIZE = 100 * 1024 * 1024 // 100MB
if (file.length() > MAX_UPLOAD_SIZE) {
    return WorkerResult.Failure("File too large (max 100MB)")
}
```

**HttpDownloadWorker** - Missing Content-Length check
```kotlin
// PROPOSED:
val contentLength = response.header("Content-Length")?.toLong() ?: 0
if (contentLength > MAX_DOWNLOAD_SIZE) {
    return WorkerResult.Failure("File too large (max 100MB)")
}
```

#### 2. No URL Scheme Whitelist (Security Risk)
**HttpRequestWorker.kt** - Accepts any URL scheme
```kotlin
// CURRENT (vulnerable):
val url = URL(urlString) // file://, ftp://, data:// all allowed!

// PROPOSED:
if (!url.protocol.matches("^https?$")) {
    return WorkerResult.Failure("Only HTTP/HTTPS allowed")
}
```

#### 3. FileCompressionWorker - Potential Command Injection
Review excludePatterns sanitization to prevent shell command injection.

### Proposed Changes

**Add SecurityValidator.kt (Android):**
```kotlin
object SecurityValidator {
    const val MAX_FILE_SIZE = 100 * 1024 * 1024 // 100MB
    val ALLOWED_SCHEMES = setOf("http", "https")

    fun validateURL(urlString: String): URL? {
        val url = URL(urlString)
        if (url.protocol !in ALLOWED_SCHEMES) return null
        return url
    }

    fun validateFileSize(file: File): Boolean {
        return file.length() <= MAX_FILE_SIZE
    }
}
```

**Add SecurityValidator.swift (iOS):**
```swift
struct SecurityValidator {
    static let maxFileSize: Int64 = 100 * 1024 * 1024 // 100MB
    static let allowedSchemes = Set(["http", "https"])

    static func validateURL(_ urlString: String) -> URL? {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              allowedSchemes.contains(scheme) else {
            return nil
        }
        return url
    }
}
```

### Acceptance Criteria
- [ ] All upload/download workers enforce 100MB limit
- [ ] All HTTP workers only accept HTTP/HTTPS URLs
- [ ] FileCompressionWorker sanitizes excludePatterns
- [ ] Security best practices documented
- [ ] Add security section to README
- [ ] Add integration tests for security validation

---

## Priority Summary

| Priority | Issue | Estimate | Impact |
|----------|-------|----------|--------|
| **P0** | #5 - Comprehensive test suite | 3 weeks | CRITICAL - v1.0 blocker |
| **P0** | #6 - PRODUCTION_GUIDE.md | 1 week | CRITICAL - v1.0 blocker |
| **P1** | #4 - iOS chain KMP integration | 2 weeks | High - Platform consistency |
| **P1** | #7 - Security enhancements | 1 week | High - Security risk |
| **P2** | #1 - Task status query (iOS) | 3 days | Medium - Feature parity |
| **P2** | #2 - KMP TaskEventBus (iOS) | 1 week | Medium - Event consistency |
| **P3** | #3 - Progress subscription (iOS) | 1 week | Low - Nice to have |

**Total estimate for v1.0:** 5-6 weeks

---

## How to File These Issues

1. Go to https://github.com/brewkits/native_workmanager/issues
2. Click "New Issue"
3. Copy the title and description from above
4. Add appropriate labels
5. Set priority (P0, P1, P2, P3)
6. Assign to milestone (v1.0 or v1.1)

---

**Generated:** 2026-02-07
**Review Status:** Ready to file
