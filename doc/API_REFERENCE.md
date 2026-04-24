# API Reference

> Complete API documentation for native_workmanager v1.2.2

## Core Classes

### NativeWorkManager

Main entry point for scheduling and managing background tasks.

#### Methods

##### `initialize()`

Initializes the work manager. Must be called before any other methods.

```dart
static Future<void> initialize({
  Map<String, DartWorkerCallback>? dartWorkers,
  bool debugMode = false,
  int maxConcurrentTasks = 4,
  int diskSpaceBufferMB = 20,
  int cleanupAfterDays = 30,
  bool enforceHttps = false,
  bool blockPrivateIPs = false,
  bool registerPlugins = false,
})
```

**Parameters:**
- `dartWorkers` - Optional map of `DartWorkerCallback` for executing Dart code in the background.
- `debugMode` - Enable verbose logging (defaults to `false`).
- `maxConcurrentTasks` - Maximum number of background tasks running simultaneously (defaults to 4).
- `diskSpaceBufferMB` - Required free disk space before I/O tasks run (defaults to 20MB).
- `cleanupAfterDays` - Days to keep completed task records in SQLite (defaults to 30, use 0 to disable).
- `enforceHttps` - When true, all HTTP workers reject plain HTTP URLs (defaults to `false`).
- `blockPrivateIPs` - When true, HTTP workers reject requests to private IP ranges to prevent SSRF (defaults to `false`).
- `registerPlugins` - When true, registers all plugins in the background Flutter Engine. Defaults to `false` to maintain the **Zero-Engine I/O** principle. 
  - **Caution:** Enabling this increases RAM usage and may cause hardware side-effects (e.g., Bluetooth disconnects).
  - **Recommendation:** Keep this `false` and use `setPluginRegistrantCallback` on the native side for selective registration.

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
static Worker httpRequest({
  required String url,
  HttpMethod method = HttpMethod.get,
  Map<String, String> headers = const {},
  String? body,
  Duration timeout = const Duration(seconds: 30),
  TokenRefreshConfig? tokenRefresh,
})
```

---

##### `httpUpload()`

Multipart file upload worker.

```dart
static Worker httpUpload({
  required String url,
  required String filePath,
  String fileFieldName = 'file',
  String? fileName,
  String? mimeType,
  Map<String, String> headers = const {},
  Map<String, String> additionalFields = const {},
  Duration timeout = const Duration(minutes: 5),
  bool useBackgroundSession = false,
})
```

---

##### `httpDownload()`

File download worker with resume support.

```dart
static Worker httpDownload({
  required String url,
  required String savePath,
  Map<String, String> headers = const {},
  Duration timeout = const Duration(minutes: 5),
  bool enableResume = true,
  String? expectedChecksum,
  String checksumAlgorithm = 'SHA-256',
  bool useBackgroundSession = false,
  bool skipExisting = false,
  bool allowPause = false,
  Map<String, String>? cookies,
  String? authToken,
  String authHeaderTemplate = 'Bearer {accessToken}',
  DuplicatePolicy onDuplicate = DuplicatePolicy.overwrite,
  bool moveToPublicDownloads = false,
  bool saveToGallery = false,
})
```

---

##### `httpSync()`

Bidirectional sync worker with retry.

```dart
static Worker httpSync({
  required String url,
  HttpMethod method = HttpMethod.post,
  Map<String, String> headers = const {},
  Map<String, dynamic>? requestBody,
  Duration timeout = const Duration(seconds: 60),
  TokenRefreshConfig? tokenRefresh,
})
```

---

#### File Workers

##### `fileCompress()`

Compress files/directories to ZIP.

```dart
static Worker fileCompress({
  required String inputPath,
  required String outputPath,
  CompressionLevel level = CompressionLevel.medium,
  List<String> excludePatterns = const [],
  bool deleteOriginal = false,
})
```

---

##### `fileDecompress()`

Extract ZIP archives.

```dart
static Worker fileDecompress({
  required String zipPath,
  required String targetDir,
  bool deleteAfterExtract = false,
  bool overwrite = true,
})
```

---

##### `fileCopy()`

Copy files or directories.

```dart
static Worker fileCopy({
  required String sourcePath,
  required String destinationPath,
  bool overwrite = false,
  bool recursive = true,
})
```

---

##### `fileMove()`

Move files or directories.

```dart
static Worker fileMove({
  required String sourcePath,
  required String destinationPath,
  bool overwrite = false,
})
```

---

##### `fileDelete()`

Delete files or directories.

```dart
static Worker fileDelete({
  required String path,
  bool recursive = false,
})
```

---

##### `fileList()`

List files in directory with pattern matching.

```dart
static Worker fileList({
  required String path,
  String? pattern,
  bool recursive = false,
})
```

---

##### `fileMkdir()`

Create directory.

```dart
static Worker fileMkdir({
  required String path,
  bool createParents = true,
})
```

---

#### Image Workers

##### `imageProcess()`

Process images (resize, compress, convert).

```dart
static Worker imageProcess({
  required String inputPath,
  required String outputPath,
  int? maxWidth,
  int? maxHeight,
  bool maintainAspectRatio = true,
  int? quality,
  ImageFormat? outputFormat,
  ImageCropRect? cropRect,
  bool deleteOriginal = false,
})
```

---

#### Crypto Workers

##### `hashFile()`

Calculate file hash.

```dart
static Worker hashFile({
  required String filePath,
  HashAlgorithm algorithm = HashAlgorithm.sha256,
})
```

---

##### `hashString()`

Calculate string hash.

```dart
static Worker hashString({
  required String data,
  HashAlgorithm algorithm = HashAlgorithm.sha256,
})
```

---

##### `cryptoEncrypt()`

Encrypt file with AES-256-GCM.

```dart
static Worker cryptoEncrypt({
  required String inputPath,
  required String outputPath,
  required String password,
})
```

---

##### `cryptoDecrypt()`

Decrypt AES-256-GCM encrypted file.

```dart
static Worker cryptoDecrypt({
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
  Map<String, dynamic>? input,
  bool autoDispose = false,
  int? timeoutMs,
})
```

**Parameters:**
- `callbackId` - Identifier for registered callback function
- `input` - Optional data passed to callback
- `autoDispose` - Whether to dispose Flutter engine after execution (default: `false`)
- `timeoutMs` - Optional execution timeout in milliseconds

**Example:**
```dart
// Register callback (in main.dart during initialize)
@WorkerCallback('processData')
Future<bool> myProcessData(String? inputData) async {
  // Your Dart logic here
  print('Processing data...');
  return true;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize(
    dartWorkers: {
      'processData': myProcessData,
    }
  );
  runApp(MyApp());
}

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
static TaskTrigger periodic(
  Duration interval, {
  Duration? flexInterval,
  Duration? initialDelay,
})
```

**Parameters:**
- `interval`: Time between executions (minimum 15 minutes).
- `flexInterval`: (Android only) Flex window for OS optimization.
- `initialDelay`: (New in v1.2.3) Delay before the very first execution.

**Example:**
```dart
// Run every hour, but wait 30 mins before first run
TaskTrigger.periodic(
  Duration(hours: 1),
  initialDelay: Duration(minutes: 30),
)
```

**Note:** Minimum interval is 15 minutes on both iOS and Android. `initialDelay` ensures the task doesn't run immediately upon registration.

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

**Version:** 1.2.2
**Last Updated:** 2026-04-20
