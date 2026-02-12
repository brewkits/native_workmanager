# Use Case: Hybrid Workflow

**Difficulty:** Advanced
**Platform:** Android + iOS
**Features:** Native workers + Dart workers, Mixed workflows, Optimization

---

## Problem

Your app needs to combine native workers (for performance) and Dart workers (for flexibility) in a single workflow:
- Download large files using native worker (efficient, no Flutter overhead)
- Process downloaded data using Dart worker (access to app logic)
- Upload results using native worker (efficient)

**Why hybrid?**
- Native workers: Faster, lower memory (no Flutter Engine), but limited to built-in operations
- Dart workers: Full Flutter/Dart access, but requires Flutter Engine

---

## Solution

Combine `NativeWorker` for heavy I/O with `DartWorker` for business logic processing.

---

## Complete Example

```dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:path_provider/path_provider.dart';

/// Dart worker: Process downloaded data
Future<bool> processDataWorker(Map<String, dynamic>? input) async {
  print('🔄 Processing downloaded data...');

  try {
    final filePath = input?['downloaded_file'] as String?;
    if (filePath == null) {
      print('❌ No file path provided');
      return false;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      print('❌ File not found: $filePath');
      return false;
    }

    // Read and process data
    final content = await file.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;

    // Business logic processing
    final processed = await _processBusinessLogic(data);

    // Save processed result
    final outputPath = '${filePath}.processed';
    await File(outputPath).writeAsString(jsonEncode(processed));

    print('✅ Processing complete: $outputPath');
    return true;
  } catch (e) {
    print('❌ Processing failed: $e');
    return false;
  }
}

Future<Map<String, dynamic>> _processBusinessLogic(Map<String, dynamic> data) async {
  // Example: Apply business rules, transform data, etc.
  return {
    'processed': true,
    'timestamp': DateTime.now().toIso8601String(),
    'original_data': data,
    'calculated_field': data['value']! * 2,
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize with Dart workers
  await NativeWorkManager.initialize(
    dartWorkers: {
      'processData': processDataWorker,
    },
  );

  runApp(MyApp());
}

/// Hybrid workflow: Download → Process → Upload
class HybridWorkflow {
  /// Execute complete hybrid workflow
  static Future<void> execute() async {
    final tempDir = await getTemporaryDirectory();
    final downloadPath = '${tempDir.path}/data.json';
    final processedPath = '$downloadPath.processed';

    // Step 1: Download using native worker (efficient, <5MB RAM)
    print('📥 Step 1: Downloading data...');
    final downloadResult = await NativeWorkManager.enqueue(
      taskId: 'download-data',
      trigger: TaskTrigger.oneTime(),
      worker: NativeWorker.httpDownload(
        url: 'https://api.example.com/large-dataset.json',
        savePath: downloadPath,
        headers: {'Authorization': 'Bearer TOKEN'},
      ),
      constraints: Constraints.networkRequired,
      tag: 'hybrid-workflow',
    );

    if (downloadResult != ScheduleResult.accepted) {
      print('❌ Download scheduling failed');
      return;
    }

    // Step 2: Wait for download, then process using Dart worker
    print('🔄 Step 2: Processing data...');
    _waitForDownload(downloadPath).then((_) async {
      final processResult = await NativeWorkManager.enqueue(
        taskId: 'process-data',
        trigger: TaskTrigger.oneTime(),
        worker: DartWorker(
          callbackId: 'processData',
          input: {'downloaded_file': downloadPath},
        ),
        tag: 'hybrid-workflow',
      );

      if (processResult != ScheduleResult.accepted) {
        print('❌ Processing scheduling failed');
        return;
      }

      // Step 3: Wait for processing, then upload using native worker
      print('📤 Step 3: Uploading results...');
      _waitForProcessing(processedPath).then((_) async {
        await NativeWorkManager.enqueue(
          taskId: 'upload-results',
          trigger: TaskTrigger.oneTime(),
          worker: NativeWorker.httpUpload(
            url: 'https://api.example.com/results',
            filePath: processedPath,
            headers: {'Authorization': 'Bearer TOKEN'},
          ),
          constraints: Constraints.networkRequired,
          tag: 'hybrid-workflow',
        );
      });
    });
  }

  /// Wait for file to be downloaded
  static Future<void> _waitForDownload(String filePath) async {
    // In real app, use event stream
    await Future.delayed(Duration(seconds: 5));
  }

  /// Wait for processing to complete
  static Future<void> _waitForProcessing(String filePath) async {
    // In real app, use event stream
    await Future.delayed(Duration(seconds: 3));
  }
}

/// Better approach: Use event-driven coordination
class EventDrivenHybridWorkflow {
  static Future<void> execute() async {
    final tempDir = await getTemporaryDirectory();
    final downloadPath = '${tempDir.path}/data.json';
    final processedPath = '$downloadPath.processed';

    // Listen to task events
    NativeWorkManager.events.listen((event) {
      if (event.taskId == 'download-data' && event.success) {
        // Download complete, start processing
        _startProcessing(downloadPath);
      } else if (event.taskId == 'process-data' && event.success) {
        // Processing complete, start upload
        _startUpload(processedPath);
      } else if (event.taskId == 'upload-results' && event.success) {
        // Workflow complete
        print('✅ Hybrid workflow completed successfully!');
      }
    });

    // Start workflow with download
    await NativeWorkManager.enqueue(
      taskId: 'download-data',
      trigger: TaskTrigger.oneTime(),
      worker: NativeWorker.httpDownload(
        url: 'https://api.example.com/large-dataset.json',
        savePath: downloadPath,
      ),
      constraints: Constraints.networkRequired,
      tag: 'hybrid-workflow',
    );
  }

  static Future<void> _startProcessing(String downloadPath) async {
    await NativeWorkManager.enqueue(
      taskId: 'process-data',
      trigger: TaskTrigger.oneTime(),
      worker: DartWorker(
        callbackId: 'processData',
        input: {'downloaded_file': downloadPath},
      ),
      tag: 'hybrid-workflow',
    );
  }

  static Future<void> _startUpload(String processedPath) async {
    await NativeWorkManager.enqueue(
      taskId: 'upload-results',
      trigger: TaskTrigger.oneTime(),
      worker: NativeWorker.httpUpload(
        url: 'https://api.example.com/results',
        filePath: processedPath,
      ),
      constraints: Constraints.networkRequired,
      tag: 'hybrid-workflow',
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Hybrid Workflow')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sync_alt, size: 80, color: Colors.purple),
              SizedBox(height: 32),
              Text(
                'Native + Dart Hybrid',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Best of both worlds',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 48),
              _WorkflowDiagram(),
              SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: () => EventDrivenHybridWorkflow.execute(),
                icon: Icon(Icons.play_arrow),
                label: Text('Start Workflow'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowDiagram extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStep(
              '1. Download',
              'Native Worker',
              Colors.blue,
              'Fast, <5MB RAM',
            ),
            Icon(Icons.arrow_downward, color: Colors.grey),
            _buildStep(
              '2. Process',
              'Dart Worker',
              Colors.green,
              'Full app logic access',
            ),
            Icon(Icons.arrow_downward, color: Colors.grey),
            _buildStep(
              '3. Upload',
              'Native Worker',
              Colors.blue,
              'Fast, <5MB RAM',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String title, String worker, Color color, String note) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(worker, style: TextStyle(fontSize: 12, color: color)),
          Text(note, style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
```

---

## Performance Comparison

### All-Native Workflow
```
Download (Native) → Process (Native❌) → Upload (Native)
RAM: 5MB total
Speed: ⚡⚡⚡ Fastest
Limitation: Can't run custom Dart logic
```

### All-Dart Workflow
```
Download (Dart) → Process (Dart) → Upload (Dart)
RAM: Higher (Flutter Engine for each worker)
Speed: 🐌 Slower
Benefit: Full Flutter access
```

### Hybrid Workflow (Best)
```
Download (Native) → Process (Dart) → Upload (Native)
RAM: Lower (Engine only for processing step)
Speed: ⚡⚡ Faster
Benefit: Efficiency + Flexibility
```

---

## When to Use Hybrid

### Use Native Workers For:
- ✅ HTTP requests (simple GET/POST)
- ✅ File downloads (large files)
- ✅ File uploads (large files)
- ✅ Data sync (simple JSON)

### Use Dart Workers For:
- ✅ Business logic processing
- ✅ Database operations (SQLite, Hive)
- ✅ Complex data transformation
- ✅ Encryption/decryption
- ✅ Image processing
- ✅ Notifications with custom logic

### Hybrid Examples:
1. **Download → Process → Upload**
2. **Sync → Transform → Store**
3. **Fetch → Encrypt → Upload**
4. **Download → Decode → Display**

---

## Common Pitfalls

### 1. ❌ Using Dart for Simple HTTP

```dart
// ❌ Unnecessary Dart worker for HTTP
worker: DartWorker(
  callbackId: 'downloadFile',  // Loads Flutter Engine
  input: {'url': 'https://...'},
)

// ✅ Use native worker
worker: NativeWorker.httpDownload(
  url: 'https://...',  // No Flutter Engine
  savePath: '/path',
)
```

### 2. ❌ Chaining Without Event Coordination

```dart
// ❌ Race condition
await NativeWorkManager.enqueue(taskId: 'download', ...);
await NativeWorkManager.enqueue(taskId: 'process', ...);  // May start before download!

// ✅ Event-driven
NativeWorkManager.events.listen((event) {
  if (event.taskId == 'download' && event.success) {
    _startProcessing();
  }
});
```

---

## Related

- **Task chains:** [Chain Processing](06-chain-processing.md)
- **File upload:** [File Upload with Retry](02-file-upload-with-retry.md)

---

*Last updated: 2026-01-27*
