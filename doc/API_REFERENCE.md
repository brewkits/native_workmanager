# API Reference

> Complete API documentation for native_workmanager v1.0.0

## Core Classes

### NativeWorkManager

Main entry point for scheduling and managing background tasks.

#### Methods

##### `initialize()`

Initializes the work manager. Must be called before any other methods.

```dart
static Future<void> initialize()
```

**Example:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize();
  runApp(MyApp());
}
```

---

##### `enqueue()`

Schedules a single background task.

```dart
static Future<void> enqueue({
  required String taskId,
  required TaskTrigger trigger,
  required Worker worker,
  Constraints? constraints,
  Map<String, dynamic>? inputData,
})
```

**Parameters:**
- `taskId` - Unique identifier for the task
- `trigger` - When/how the task should run (one-time, periodic, etc.)
- `worker` - The worker that executes the task logic
- `constraints` - Optional execution constraints (network, battery, etc.)
- `inputData` - Optional input data passed to worker

**Example:**
```dart
await NativeWorkManager.enqueue(
  taskId: 'api-sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpSync(
    url: 'https://api.example.com/sync',
  ),
  constraints: Constraints(requiresNetwork: true),
);
```

---

##### `beginWith()` / Task Chains

Creates a task chain for sequential or parallel execution.

```dart
static TaskChainBuilder beginWith(TaskRequest firstTask)
```

**Returns:** `TaskChainBuilder` for chaining more tasks

**Example:**
```dart
await NativeWorkManager.beginWith(
  TaskRequest(id: 'download', worker: HttpDownloadWorker(...)),
).then(
  TaskRequest(id: 'process', worker: ImageProcessWorker(...)),
).then(
  TaskRequest(id: 'upload', worker: HttpUploadWorker(...)),
).enqueue();
```

---

##### `cancel()`

Cancels a scheduled task by ID.

```dart
static Future<void> cancel(String taskId)
```

**Example:**
```dart
await NativeWorkManager.cancel('api-sync');
```

---

##### `cancelAll()`

Cancels all scheduled tasks.

```dart
static Future<void> cancelAll()
```

**Example:**
```dart
await NativeWorkManager.cancelAll();
```

---

##### `events` Stream

Stream of task completion events.

```dart
static Stream<TaskEvent> get events
```

**Returns:** Stream emitting `TaskEvent` for each completed task

**Example:**
```dart
NativeWorkManager.events.listen((event) {
  print('Task ${event.taskId}: ${event.success ? "✅" : "❌"}');
  print('Message: ${event.message}');
});
```

---

## Workers

### NativeWorker

Factory for creating built-in native workers (no Flutter engine overhead).

#### HTTP Workers

##### `httpRequest()`

Simple HTTP request worker.

```dart
static HttpRequestWorker httpRequest({
  required String url,
  required HttpMethod method,
  Map<String, String>? headers,
  String? body,
  int? timeoutMs,
})
```

---

##### `httpUpload()`

Multipart file upload worker.

```dart
static HttpUploadWorker httpUpload({
  required String url,
  required String filePath,
  String? fileFieldName,
  Map<String, String>? additionalFields,
  Map<String, String>? headers,
  bool useBackgroundSession = false,
})
```

---

##### `httpDownload()`

File download worker with resume support.

```dart
static HttpDownloadWorker httpDownload({
  required String url,
  required String savePath,
  Map<String, String>? headers,
  bool enableResume = false,
  bool useBackgroundSession = false,
  String? checksumAlgorithm,
  String? expectedChecksum,
})
```

---

##### `httpSync()`

Bidirectional sync worker with retry.

```dart
static HttpSyncWorker httpSync({
  required String url,
  required HttpMethod method,
  Map<String, dynamic>? requestBody,
  Map<String, String>? headers,
})
```

---

#### File Workers

##### `fileCompress()`

Compress files/directories to ZIP.

```dart
static FileCompressionWorker fileCompress({
  required String inputPath,
  required String outputPath,
  CompressionLevel level = CompressionLevel.medium,
  bool deleteOriginal = false,
  List<String>? excludePatterns,
})
```

---

##### `fileDecompress()`

Extract ZIP archives.

```dart
static FileDecompressionWorker fileDecompress({
  required String zipPath,
  required String targetDir,
  bool overwrite = false,
  bool deleteAfterExtract = false,
  String? password,
})
```

---

##### `fileCopy()`

Copy files or directories.

```dart
static FileSystemWorker fileCopy({
  required String sourcePath,
  required String destinationPath,
  bool overwrite = false,
  bool recursive = false,
})
```

---

##### `fileMove()`

Move files or directories.

```dart
static FileSystemWorker fileMove({
  required String sourcePath,
  required String destinationPath,
  bool overwrite = false,
})
```

---

##### `fileDelete()`

Delete files or directories.

```dart
static FileSystemWorker fileDelete({
  required String path,
  bool recursive = false,
})
```

---

##### `fileList()`

List files in directory with pattern matching.

```dart
static FileSystemWorker fileList({
  required String path,
  String? pattern,
  bool recursive = false,
})
```

---

##### `fileMkdir()`

Create directory.

```dart
static FileSystemWorker fileMkdir({
  required String path,
  bool createParents = true,
})
```

---

#### Image Workers

##### `imageProcess()`

Process images (resize, compress, convert).

```dart
static ImageProcessWorker imageProcess({
  required String inputPath,
  required String outputPath,
  int? maxWidth,
  int? maxHeight,
  int? quality,
  ImageFormat? outputFormat,
  bool maintainAspectRatio = true,
  ImageCropRect? cropRect,
})
```

---

#### Crypto Workers

##### `hashFile()`

Calculate file hash.

```dart
static CryptoHashWorker hashFile({
  required String filePath,
  HashAlgorithm algorithm = HashAlgorithm.sha256,
})
```

---

##### `hashString()`

Calculate string hash.

```dart
static CryptoHashWorker hashString({
  required String data,
  HashAlgorithm algorithm = HashAlgorithm.sha256,
})
```

---

##### `cryptoEncrypt()`

Encrypt file with AES-256-GCM.

```dart
static CryptoEncryptWorker cryptoEncrypt({
  required String inputPath,
  required String outputPath,
  required String password,
})
```

---

##### `cryptoDecrypt()`

Decrypt AES-256-GCM encrypted file.

```dart
static CryptoDecryptWorker cryptoDecrypt({
  required String inputPath,
  required String outputPath,
  required String password,
})
```

---

### DartWorker

Worker for custom Dart logic (uses Flutter engine).

```dart
DartWorker({
  required String callbackId,
  Map<String, dynamic>? inputData,
  bool autoDispose = true,
})
```

**Parameters:**
- `callbackId` - Identifier for registered callback function
- `inputData` - Optional data passed to callback
- `autoDispose` - Whether to dispose Flutter engine after execution

**Example:**
```dart
// Register callback (in main.dart)
NativeWorkManager.registerCallback('processData', () async {
  // Your Dart logic here
  print('Processing data...');
});

// Schedule task
await NativeWorkManager.enqueue(
  taskId: 'process',
  trigger: TaskTrigger.oneTime(),
  worker: DartWorker(callbackId: 'processData'),
);
```

---

## Triggers

### TaskTrigger

Defines when tasks should execute.

#### `oneTime()`

Execute task once after optional delay.

```dart
static TaskTrigger oneTime([Duration? initialDelay])
```

**Example:**
```dart
TaskTrigger.oneTime(Duration(seconds: 30))  // Run after 30 seconds
```

---

#### `periodic()`

Execute task repeatedly at fixed interval.

```dart
static TaskTrigger periodic(Duration interval)
```

**Example:**
```dart
TaskTrigger.periodic(Duration(hours: 1))  // Run every hour
```

**Note:** Minimum interval is 15 minutes on both iOS and Android.

---

#### `deviceIdle()`

Execute when device is idle (Android only).

```dart
static TaskTrigger deviceIdle()
```

---

#### `batteryOkay()`

Execute when battery is not low.

```dart
static TaskTrigger batteryOkay()
```

---

## Constraints

### Constraints

Execution constraints for tasks.

```dart
Constraints({
  bool requiresNetwork = false,
  bool requiresUnmeteredNetwork = false,
  bool requiresCharging = false,
  bool requiresBatteryNotLow = false,
  bool requiresStorageNotLow = false,
  bool requiresDeviceIdle = false,
  BackoffPolicy backoffPolicy = BackoffPolicy.exponential,
  int backoffDelayMs = 30000,
  int maxAttempts = 3,
  bool isHeavyTask = false,
})
```

**Example:**
```dart
Constraints(
  requiresNetwork: true,
  requiresUnmeteredNetwork: true,  // WiFi only
  requiresCharging: true,
  backoffPolicy: BackoffPolicy.exponential,
  maxAttempts: 5,
)
```

---

## Enums

### HttpMethod

```dart
enum HttpMethod {
  get,
  post,
  put,
  delete,
  patch,
}
```

---

### CompressionLevel

```dart
enum CompressionLevel {
  low,
  medium,
  high,
}
```

---

### ImageFormat

```dart
enum ImageFormat {
  jpeg,
  png,
  webp,
}
```

---

### HashAlgorithm

```dart
enum HashAlgorithm {
  md5,
  sha1,
  sha256,
  sha512,
}
```

---

### BackoffPolicy

```dart
enum BackoffPolicy {
  linear,
  exponential,
}
```

---

## Events

### TaskEvent

Emitted when task completes.

```dart
class TaskEvent {
  final String taskId;
  final bool success;
  final String? message;
  final DateTime timestamp;
  final Map<String, dynamic>? outputData;
}
```

**Example:**
```dart
NativeWorkManager.events.listen((event) {
  if (event.success) {
    print('✅ ${event.taskId} completed: ${event.message}');
  } else {
    print('❌ ${event.taskId} failed: ${event.message}');
  }
});
```

---

## Task Chains

### TaskChainBuilder

Builder for creating task chains.

#### `then()`

Add sequential task.

```dart
TaskChainBuilder then(TaskRequest task)
```

---

#### `thenAll()`

Add parallel tasks.

```dart
TaskChainBuilder thenAll(List<TaskRequest> tasks)
```

---

#### `enqueue()`

Schedule the chain.

```dart
Future<void> enqueue()
```

---

### TaskRequest

Represents a task in a chain.

```dart
TaskRequest({
  required String id,
  required Worker worker,
  Constraints? constraints,
  Map<String, dynamic>? inputData,
})
```

---

## Platform-Specific APIs

### iOS Background URLSession

For large file transfers that survive app termination.

```dart
// Use with httpDownload or httpUpload
NativeWorker.httpDownload(
  url: 'https://example.com/large-file.zip',
  savePath: '/path/to/save.zip',
  useBackgroundSession: true,  // ← iOS Background URLSession
)
```

**Benefits:**
- Survives app termination
- No time limits
- Automatic retry on network failure

---

## See Also

- [Getting Started Guide](GETTING_STARTED.md)
- [Use Cases](use-cases/)
- [Production Guide](PRODUCTION_GUIDE.md)
- [FAQ](FAQ.md)

---

**Version:** 1.0.0
**Last Updated:** February 2026
