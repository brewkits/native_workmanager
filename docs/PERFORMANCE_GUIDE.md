# Performance Guide

**Version:** 0.8.1
**Last Updated:** 2026-02-07

---

## Overview

This guide provides best practices, optimization strategies, and profiling tools for achieving optimal performance with `native_workmanager`.

**Key Performance Advantages:**
- ✅ **~50MB less memory** vs Flutter-based background workers (no Flutter Engine)
- ✅ **5x faster startup** (native workers start in ~100ms vs ~500ms)
- ✅ **Zero Flutter overhead** for simple HTTP/file operations
- ✅ **Built on KMP WorkManager** (battle-tested, production-ready)

---

## Table of Contents

1. [Performance Monitoring](#performance-monitoring)
2. [Memory Optimization](#memory-optimization)
3. [Battery Optimization](#battery-optimization)
4. [Task Scheduling Optimization](#task-scheduling-optimization)
5. [Chain Optimization](#chain-optimization)
6. [Profiling Tools](#profiling-tools)
7. [Benchmarking](#benchmarking)
8. [Platform-Specific Tips](#platform-specific-tips)

---

## Performance Monitoring

### Enable Performance Monitoring

```dart
import 'package:native_workmanager/native_workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable performance monitoring
  PerformanceMonitor.instance.enable();

  await NativeWorkManager.initialize();
  runApp(MyApp());
}
```

### Get Performance Statistics

```dart
// Get current statistics
final stats = PerformanceMonitor.instance.getStatistics();

print('Average task duration: ${stats.averageTaskDuration}ms');
print('Success rate: ${(stats.successRate * 100).toStringAsFixed(1)}%');
print('Throughput: ${stats.tasksPerMinute} tasks/min');
print('Event latency: ${stats.averageEventDispatchLatency}ms');

// Per-worker statistics
for (final entry in stats.workerTypeStatistics.entries) {
  print('${entry.key}: ${entry.value.averageDuration}ms avg');
}
```

### Track Specific Tasks

```dart
// Monitor automatically tracks all tasks
await NativeWorkManager.enqueue(
  taskId: 'my-task',
  trigger: TaskTrigger.oneTime(),
  worker: DartWorker(callbackId: 'myCallback'),
);

// Get metrics for specific task
final metrics = PerformanceMonitor.instance.getTaskMetrics('my-task');
print('Task duration: ${metrics?.duration.inMilliseconds}ms');
```

---

## Memory Optimization

### 1. Use Native Workers Instead of Dart Workers

**Bad (50MB+ memory):**
```dart
// DartWorker requires Flutter Engine (~50MB)
worker: DartWorker(callbackId: 'processData'),
```

**Good (2-5MB memory):**
```dart
// Native workers run without Flutter Engine
worker: HttpRequestWorker(
  url: 'https://api.example.com/data',
  method: HttpMethod.get,
),
```

**Memory Comparison:**

| Worker Type | Memory Usage | Startup Time |
|-------------|--------------|--------------|
| DartWorker | ~50MB | ~500ms |
| HttpRequestWorker | ~3MB | ~100ms |
| HttpDownloadWorker | ~3-5MB | ~100ms |
| HttpUploadWorker | ~5-7MB | ~150ms |

### 2. Avoid Large Data in ResultData

**Bad:**
```dart
// Don't return large data in result
return {
  'data': largeJsonString, // 10MB JSON!
  'image': base64Image,     // 5MB image!
};
```

**Good:**
```dart
// Return file paths instead
return {
  'filePath': '/tmp/data.json',
  'fileSize': 1024000,
  'statusCode': 200,
};
```

### 3. Clean Up Temporary Files

```dart
// Chain pattern: Process → Cleanup
await NativeWorkManager.beginWith(
  TaskRequest(
    id: 'download',
    worker: HttpDownloadWorker(
      url: 'https://example.com/file.zip',
      savePath: '/tmp/download.zip',
    ),
  ),
).then(
  TaskRequest(
    id: 'cleanup',
    worker: DartWorker(callbackId: 'deleteTemp'),
  ),
).enqueue();
```

---

## Battery Optimization

### 1. Use Constraints Wisely

**Optimize battery by deferring non-urgent tasks:**

```dart
await NativeWorkManager.enqueue(
  taskId: 'backup',
  trigger: TaskTrigger.periodic(const Duration(hours: 24)),
  worker: HttpUploadWorker(...),
  constraints: const Constraints(
    requiresCharging: true,         // Wait for charging
    requiresDeviceIdle: true,        // Wait for idle
    requiresUnmeteredNetwork: true,  // Wait for WiFi
  ),
);
```

### 2. Batch Operations

**Bad (frequent tasks):**
```dart
// Uploads every file immediately (drains battery)
for (final file in files) {
  await NativeWorkManager.enqueue(
    taskId: 'upload-$file',
    trigger: TaskTrigger.oneTime(),
    worker: HttpUploadWorker(...),
  );
}
```

**Good (batched):**
```dart
// Compress all files, upload once (battery efficient)
await NativeWorkManager.beginWith(
  TaskRequest(
    id: 'compress',
    worker: FileCompressionWorker(...),
  ),
).then(
  TaskRequest(
    id: 'upload',
    worker: HttpUploadWorker(...),
    constraints: const Constraints(
      requiresCharging: true,
      requiresUnmeteredNetwork: true,
    ),
  ),
).enqueue();
```

### 3. Use Appropriate QoS (iOS)

```dart
// Low priority background tasks
constraints: const Constraints(
  qos: QoS.background,  // iOS: lowest priority, max battery saving
),

// User-visible tasks
constraints: const Constraints(
  qos: QoS.utility,  // iOS: balanced performance/battery
),

// Critical tasks
constraints: const Constraints(
  qos: QoS.userInitiated,  // iOS: high priority
),
```

---

## Task Scheduling Optimization

### 1. Avoid Frequent One-Time Tasks

**Bad:**
```dart
// Scheduling every second (inefficient!)
Timer.periodic(Duration(seconds: 1), (timer) {
  NativeWorkManager.enqueue(...);
});
```

**Good:**
```dart
// Use periodic task (system-optimized)
await NativeWorkManager.enqueue(
  taskId: 'sync',
  trigger: TaskTrigger.periodic(const Duration(minutes: 15)),
  worker: HttpSyncWorker(...),
);
```

### 2. Use Exact Triggers Sparingly

```dart
// Only use exact timing when truly needed
await NativeWorkManager.enqueue(
  taskId: 'alarm',
  trigger: TaskTrigger.exact(
    DateTime.now().add(const Duration(hours: 8)),
  ),
  worker: DartWorker(callbackId: 'alarm'),
);

// For most tasks, OneTime with delay is sufficient
await NativeWorkManager.enqueue(
  taskId: 'reminder',
  trigger: TaskTrigger.oneTime(const Duration(hours: 1)),
  worker: DartWorker(callbackId: 'reminder'),
);
```

### 3. Set Appropriate Backoff Policies

```dart
// For critical tasks that must retry
constraints: const Constraints(
  backoffPolicy: BackoffPolicy.exponential,
  backoffDelayMs: 30000,  // 30s, 60s, 120s, 240s...
),

// For less critical tasks
constraints: const Constraints(
  backoffPolicy: BackoffPolicy.linear,
  backoffDelayMs: 60000,  // 60s, 120s, 180s, 240s...
),
```

---

## Chain Optimization

### 1. Use Parallel Execution When Possible

**Sequential (slow):**
```dart
// 3 tasks × 2s each = 6s total
await NativeWorkManager.beginWith(task1)
  .then(task2)
  .then(task3)
  .enqueue();
```

**Parallel (fast):**
```dart
// 3 tasks in parallel = 2s total
await NativeWorkManager.beginWith(prepare)
  .thenAll([task1, task2, task3])  // Parallel!
  .then(finalize)
  .enqueue();
```

### 2. Keep Chains Short

**Bad (long chain):**
```dart
// 10-step chain (if one fails, all 10 fail)
await NativeWorkManager.beginWith(step1)
  .then(step2)
  .then(step3)
  // ... 7 more steps
  .enqueue();
```

**Good (split into smaller chains):**
```dart
// Split into 2 chains
await NativeWorkManager.beginWith(step1)
  .then(step2)
  .then(step3)
  .enqueue();

// Second chain triggered by event
NativeWorkManager.events.listen((event) {
  if (event.taskId == 'step3' && event.success) {
    NativeWorkManager.beginWith(step4)
      .then(step5)
      .enqueue();
  }
});
```

### 3. Use Chain Constraints

```dart
// Apply constraints to entire chain
await NativeWorkManager.beginWith(download)
  .then(process)
  .then(upload)
  .withConstraints(const Constraints(
    requiresNetwork: true,
    requiresUnmeteredNetwork: true,
  ))
  .enqueue();
```

---

## Profiling Tools

### 1. Performance Monitor

```dart
import 'package:native_workmanager/native_workmanager.dart';

// Enable monitoring
PerformanceMonitor.instance.enable();

// Get statistics
final stats = PerformanceMonitor.instance.getStatistics();

print('''
Performance Report:
  Total tasks: ${stats.totalTasksScheduled}
  Completed: ${stats.totalTasksCompleted}
  Success rate: ${(stats.successRate * 100).toFixed(1)}%
  Avg duration: ${stats.averageTaskDuration.toFixed(1)}ms
  Throughput: ${stats.tasksPerMinute.toFixed(2)} tasks/min
''');
```

### 2. Task Metrics

```dart
// Get metrics for specific task
final metrics = PerformanceMonitor.instance.getTaskMetrics('my-task');

if (metrics != null) {
  print('Task: ${metrics.taskId}');
  print('Worker: ${metrics.workerType}');
  print('Duration: ${metrics.duration.inMilliseconds}ms');
  print('Success: ${metrics.success}');
  print('Result data: ${metrics.resultData}');
}
```

### 3. Real-Time Monitoring

```dart
// Listen to all performance events
for (final event in PerformanceMonitor.instance.getStatistics().recentEvents) {
  print('${event.type}: ${event.taskId} at ${event.timestamp}');
}
```

---

## Benchmarking

### Run Performance Benchmarks

```dart
import 'package:your_app/utils/performance_benchmark.dart';

// Run all benchmarks
final results = await PerformanceBenchmark.runAll();

print(results); // Prints detailed benchmark results
```

**Benchmark Results Example:**
```
=== Performance Benchmark Results ===

Task Startup Latency:
  Average: 127.45 ms
  Median: 125.00 ms
  Min: 98 ms
  Max: 156 ms
  Samples: 10

Chain Execution (3 steps):
  Average: 6234.80 ms
  Median: 6201.00 ms
  Min: 6012 ms
  Max: 6523 ms
  Samples: 5

Event Dispatch Latency:
  Average: 12.34 μs
  Median: 11.50 μs
  Min: 8 μs
  Max: 18 μs
  Samples: 10

Throughput:
  Average: 245.67 tasks/sec
  Median: 248.00 tasks/sec
  Min: 231 tasks/sec
  Max: 258 tasks/sec
  Samples: 3
======================================
```

### Interpret Results

**Good Performance:**
- Task startup < 200ms
- Event dispatch < 50μs
- Success rate > 95%
- Throughput > 100 tasks/sec

**Poor Performance (investigate):**
- Task startup > 500ms
- Event dispatch > 100μs
- Success rate < 80%
- Throughput < 50 tasks/sec

---

## Platform-Specific Tips

### Android

**1. Use WorkManager Constraints:**
```dart
// Android respects all constraint types
constraints: const Constraints(
  requiresNetwork: true,
  requiresUnmeteredNetwork: true,
  requiresCharging: true,
  requiresBatteryNotLow: true,
  requiresStorageNotLow: true,
  requiresDeviceIdle: true,
),
```

**2. Battery Optimization:**
- Use `isHeavyTask: true` for CPU-intensive work
- Avoid frequent alarms (use periodic tasks)
- Respect Doze mode (Android 6+)

**3. Background Execution Limits:**
- Android 8+: Background execution limits apply
- Use constraints to work within system limits
- Test on real devices with battery saver enabled

### iOS

**1. Use Appropriate QoS:**
```dart
// Background processing
qos: QoS.background,  // Max battery saving

// User-visible updates
qos: QoS.utility,  // Balanced

// Critical tasks
qos: QoS.userInitiated,  // High priority
```

**2. Background Task Limits:**
- iOS limits background task duration (30s for app refresh)
- Use `isHeavyTask: true` for longer tasks
- Test with Background App Refresh disabled

**3. Memory Limits:**
- iOS terminates apps exceeding memory limits
- Use native workers to minimize memory usage
- Avoid loading large files into memory

---

## Best Practices Summary

### ✅ DO

- Use native workers for HTTP/file operations
- Enable performance monitoring in development
- Use constraints to optimize battery
- Batch operations when possible
- Keep chains short (2-4 steps)
- Use parallel execution in chains
- Set appropriate backoff policies
- Monitor success rate and fix failures
- Test on real devices

### ❌ DON'T

- Use DartWorker for simple HTTP requests
- Schedule tasks every second
- Create long chains (>5 steps)
- Return large data in resultData
- Ignore constraint violations
- Use exact timing for everything
- Skip error handling
- Test only on emulators

---

## Performance Checklist

**Before Production:**

- [ ] Performance monitoring enabled in development
- [ ] Benchmarks run and results analyzed
- [ ] Success rate > 95%
- [ ] Memory usage < 10MB per worker
- [ ] No memory leaks detected
- [ ] Battery impact tested (real device)
- [ ] Constraints optimized for battery
- [ ] Error handling implemented
- [ ] Backoff policies configured
- [ ] Real device testing completed

---

## Troubleshooting

### High Memory Usage

**Symptom:** Workers using >20MB memory
**Solution:**
1. Switch to native workers (HttpRequestWorker, etc.)
2. Avoid large data in resultData
3. Clean up temporary files
4. Check for memory leaks

### Slow Task Startup

**Symptom:** Tasks taking >500ms to start
**Solution:**
1. Use native workers instead of DartWorkers
2. Reduce initialization overhead
3. Check device performance
4. Avoid heavy constraints

### Low Success Rate

**Symptom:** Success rate <80%
**Solution:**
1. Add backoff policy for retries
2. Check network connectivity constraints
3. Increase timeout values
4. Handle errors properly
5. Monitor logs for failures

### Poor Battery Life

**Symptom:** High battery drain
**Solution:**
1. Add `requiresCharging` constraint
2. Use periodic tasks instead of frequent one-time tasks
3. Batch operations
4. Use appropriate QoS (iOS)
5. Respect device idle state

---

## Additional Resources

- [Production Guide](PRODUCTION_GUIDE.md) - Deployment best practices
- [Platform Consistency](PLATFORM_CONSISTENCY.md) - Platform differences
- [Security Audit](SECURITY_AUDIT.md) - Security best practices
- [Example App](../example/) - Reference implementation

---

**Last Updated:** 2026-02-07
**Version:** 0.8.1

