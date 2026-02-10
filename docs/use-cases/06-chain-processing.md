# Use Case: Chain Processing

**Difficulty:** Advanced
**Platform:** Android + iOS
**Features:** Task chains, Sequential processing, Parallel execution, Error handling

---

## Problem

Your app needs to execute a complex workflow where tasks must run in a specific order, with some tasks running in parallel:
- Download multiple files in parallel
- Process them sequentially
- Upload results in parallel
- Handle failures gracefully

Common scenarios:
- Data pipeline: Fetch → Transform → Load
- Media processing: Download → Thumbnail → Upload
- Batch operations: Fetch list → Process each → Aggregate
- Multi-step syncs

---

## Solution

Use `NativeWorkManager.beginWith()` to create task chains with sequential and parallel execution.

---

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize with Dart workers
  await NativeWorkManager.initialize(
    dartWorkers: {
      'processImage': processImageWorker,
      'aggregate': aggregateWorker,
    },
  );

  runApp(MyApp());
}

/// Dart worker: Process image
Future<bool> processImageWorker(Map<String, dynamic>? input) async {
  final imagePath = input?['image_path'] as String?;
  print('🖼️ Processing image: $imagePath');
  // Image processing logic
  await Future.delayed(Duration(seconds: 2));
  return true;
}

/// Dart worker: Aggregate results
Future<bool> aggregateWorker(Map<String, dynamic>? input) async {
  print('📊 Aggregating results...');
  // Aggregate logic
  await Future.delayed(Duration(seconds: 1));
  return true;
}

/// Example 1: Simple Sequential Chain
class SimpleChain {
  static Future<void> execute() async {
    await NativeWorkManager.beginWith(
      // Step 1: Download
      TaskRequest(
        id: 'download',
        worker: NativeWorker.httpDownload(
          url: 'https://api.example.com/data.json',
          savePath: '/tmp/data.json',
        ),
      ),
    )
        .then(
      // Step 2: Process
      TaskRequest(
        id: 'process',
        worker: DartWorker(
          callbackId: 'processImage',
          input: {'image_path': '/tmp/data.json'},
        ),
      ),
    )
        .then(
      // Step 3: Upload
      TaskRequest(
        id: 'upload',
        worker: NativeWorker.httpUpload(
          url: 'https://api.example.com/results',
          filePath: '/tmp/processed.json',
        ),
      ),
    )
        .named('simple-chain')
        .withConstraints(Constraints.networkRequired)
        .enqueue();

    print('✅ Simple chain scheduled');
  }
}

/// Example 2: Parallel Downloads → Sequential Processing
class ParallelToSequential {
  static Future<void> execute() async {
    await NativeWorkManager.beginWithAll([
      // Parallel: Download 3 files simultaneously
      TaskRequest(
        id: 'download-1',
        worker: NativeWorker.httpDownload(
          url: 'https://api.example.com/file1.jpg',
          savePath: '/tmp/file1.jpg',
        ),
      ),
      TaskRequest(
        id: 'download-2',
        worker: NativeWorker.httpDownload(
          url: 'https://api.example.com/file2.jpg',
          savePath: '/tmp/file2.jpg',
        ),
      ),
      TaskRequest(
        id: 'download-3',
        worker: NativeWorker.httpDownload(
          url: 'https://api.example.com/file3.jpg',
          savePath: '/tmp/file3.jpg',
        ),
      ),
    ])
        .then(
      // Sequential: Process file 1
      TaskRequest(
        id: 'process-1',
        worker: DartWorker(
          callbackId: 'processImage',
          input: {'image_path': '/tmp/file1.jpg'},
        ),
      ),
    )
        .then(
      // Sequential: Process file 2
      TaskRequest(
        id: 'process-2',
        worker: DartWorker(
          callbackId: 'processImage',
          input: {'image_path': '/tmp/file2.jpg'},
        ),
      ),
    )
        .then(
      // Sequential: Process file 3
      TaskRequest(
        id: 'process-3',
        worker: DartWorker(
          callbackId: 'processImage',
          input: {'image_path': '/tmp/file3.jpg'},
        ),
      ),
    )
        .then([
      // Parallel: Upload all processed files
      TaskRequest(
        id: 'upload-1',
        worker: NativeWorker.httpUpload(
          url: 'https://api.example.com/upload',
          filePath: '/tmp/file1-processed.jpg',
        ),
      ),
      TaskRequest(
        id: 'upload-2',
        worker: NativeWorker.httpUpload(
          url: 'https://api.example.com/upload',
          filePath: '/tmp/file2-processed.jpg',
        ),
      ),
      TaskRequest(
        id: 'upload-3',
        worker: NativeWorker.httpUpload(
          url: 'https://api.example.com/upload',
          filePath: '/tmp/file3-processed.jpg',
        ),
      ),
    ])
        .named('parallel-to-sequential')
        .withConstraints(Constraints(
      networkType: NetworkType.unmetered,  // WiFi only
      batteryNotLow: true,
    ))
        .enqueue();

    print('✅ Complex chain scheduled');
  }
}

/// Example 3: Diamond Pattern
/// ```
///       A (download)
///      / \
///     B   C (process in parallel)
///      \ /
///       D (aggregate)
/// ```
class DiamondChain {
  static Future<void> execute() async {
    await NativeWorkManager.beginWith(
      // Step 1: Download source data
      TaskRequest(
        id: 'download-source',
        worker: NativeWorker.httpDownload(
          url: 'https://api.example.com/source.json',
          savePath: '/tmp/source.json',
        ),
      ),
    )
        .then([
      // Step 2a: Process branch 1 (parallel)
      TaskRequest(
        id: 'process-branch-1',
        worker: DartWorker(
          callbackId: 'processImage',
          input: {'branch': '1'},
        ),
      ),
      // Step 2b: Process branch 2 (parallel)
      TaskRequest(
        id: 'process-branch-2',
        worker: DartWorker(
          callbackId: 'processImage',
          input: {'branch': '2'},
        ),
      ),
    ])
        .then(
      // Step 3: Aggregate results from both branches
      TaskRequest(
        id: 'aggregate-results',
        worker: DartWorker(
          callbackId: 'aggregate',
          input: {'sources': ['branch-1', 'branch-2']},
        ),
      ),
    )
        .named('diamond-chain')
        .enqueue();

    print('✅ Diamond chain scheduled');
  }
}

/// Example 4: Error Handling Chain
class ErrorHandlingChain {
  static Future<void> execute() async {
    // Monitor chain progress
    NativeWorkManager.events.listen((event) {
      if (event.taskId.contains('error-chain')) {
        if (event.success) {
          print('✅ ${event.taskId} completed');
        } else {
          print('❌ ${event.taskId} failed: ${event.message}');
          _handleChainFailure(event.taskId);
        }
      }
    });

    await NativeWorkManager.beginWith(
      TaskRequest(
        id: 'error-chain-download',
        worker: NativeWorker.httpDownload(
          url: 'https://api.example.com/data.json',
          savePath: '/tmp/data.json',
        ),
      ),
    )
        .then(
      TaskRequest(
        id: 'error-chain-process',
        worker: DartWorker(
          callbackId: 'processImage',
          input: {'file': '/tmp/data.json'},
        ),
      ),
    )
        .then(
      TaskRequest(
        id: 'error-chain-upload',
        worker: NativeWorker.httpUpload(
          url: 'https://api.example.com/results',
          filePath: '/tmp/processed.json',
        ),
      ),
    )
        .named('error-handling-chain')
        .enqueue();
  }

  static void _handleChainFailure(String failedTaskId) {
    print('🔄 Retrying chain from: $failedTaskId');
    // Implement retry logic here
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Chain Processing')),
        body: ListView(
          padding: EdgeInsets.all(16),
          children: [
            _ChainCard(
              title: 'Simple Sequential',
              subtitle: 'Download → Process → Upload',
              icon: Icons.trending_flat,
              color: Colors.blue,
              onTap: SimpleChain.execute,
            ),
            SizedBox(height: 16),
            _ChainCard(
              title: 'Parallel to Sequential',
              subtitle: '3 Downloads || → 3 Process → → 3 Uploads ||',
              icon: Icons.call_split,
              color: Colors.green,
              onTap: ParallelToSequential.execute,
            ),
            SizedBox(height: 16),
            _ChainCard(
              title: 'Diamond Pattern',
              subtitle: 'Download → [Process A || Process B] → Aggregate',
              icon: Icons.diamond,
              color: Colors.purple,
              onTap: DiamondChain.execute,
            ),
            SizedBox(height: 16),
            _ChainCard(
              title: 'With Error Handling',
              subtitle: 'Chain with retry on failure',
              icon: Icons.error_outline,
              color: Colors.orange,
              onTap: ErrorHandlingChain.execute,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChainCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ChainCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: color, size: 40),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
        trailing: Icon(Icons.play_arrow),
        onTap: onTap,
      ),
    );
  }
}
```

---

## Chain Execution Flow

### Sequential (A → B → C)
```
Task A starts
Task A completes
  ↓
Task B starts
Task B completes
  ↓
Task C starts
Task C completes
```

### Parallel (A, B, C run together)
```
Task A starts ─┐
Task B starts ─┼─ All run simultaneously
Task C starts ─┘
    ↓
All complete before next step
```

### Mixed (A → [B || C] → D)
```
Task A starts
Task A completes
  ↓
Task B starts ─┐
Task C starts ─┤ Parallel
  ↓            ↓
B complete ────┤
C complete ────┘
  ↓
Task D starts
Task D completes
```

---

## Performance Optimization

### Scenario: Process 10 images

**Sequential (slow):**
```dart
// Total time: 10 × 2 seconds = 20 seconds
for (int i = 0; i < 10; i++) {
  .then(TaskRequest(id: 'process-$i', ...))
}
```

**Parallel (fast):**
```dart
// Total time: max(2 seconds) = 2 seconds
.then([
  TaskRequest(id: 'process-0', ...),
  TaskRequest(id: 'process-1', ...),
  // ... 10 tasks
])
```

**Balanced (optimal):**
```dart
// Process in batches of 3
.then([Task0, Task1, Task2])  // Batch 1: 2s
.then([Task3, Task4, Task5])  // Batch 2: 2s
.then([Task6, Task7, Task8])  // Batch 3: 2s
.then([Task9])                // Batch 4: 2s
// Total: 8 seconds (faster than sequential, controlled parallelism)
```

---

## Expected Behavior

### Android
- Chains execute in background workers
- Parallel tasks use thread pool
- Constraints applied to entire chain
- If any task fails, chain stops

### iOS
- Chains execute via BGTaskScheduler
- 30-second execution limit per task
- Long chains may need checkpointing
- System decides execution timing

---

## Common Pitfalls

### 1. ❌ Too Many Parallel Tasks

```dart
// ❌ 100 parallel tasks - resource exhaustion
.then(List.generate(100, (i) => TaskRequest(...)))

// ✅ Batch processing
.then(batch1)  // 10 tasks
.then(batch2)  // 10 tasks
...
```

### 2. ❌ No Error Handling

```dart
// ❌ Chain fails silently
await chain.enqueue();

// ✅ Monitor events
NativeWorkManager.events.listen((event) {
  if (!event.success) {
    handleFailure(event);
  }
});
```

### 3. ❌ Incorrect Dependencies

```dart
// ❌ Task B needs output from Task A, but runs in parallel
.then([TaskA, TaskB])  // B may start before A completes!

// ✅ Sequential dependencies
.then(TaskA)
.then(TaskB)  // B waits for A
```

---

## Related

- **Hybrid workflow:** [Hybrid Workflow](05-hybrid-workflow.md)
- **File operations:** [File Upload with Retry](02-file-upload-with-retry.md)

---

## Checklist

- [ ] Identify task dependencies
- [ ] Use parallel execution where possible
- [ ] Add error handling and monitoring
- [ ] Test chain failure scenarios
- [ ] Verify iOS 30-second limit (checkpoint if needed)
- [ ] Add constraints to entire chain
- [ ] Use meaningful task IDs for debugging

---

*Last updated: 2026-01-27*
