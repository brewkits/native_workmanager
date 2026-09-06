# API Reference

> Complete API documentation for native_workmanager v1.3.3

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
static Future<TaskHandler> enqueue({
  required String taskId,
  TaskTrigger trigger = const TaskTrigger.oneTime(),
  required Worker worker,
  Constraints constraints = const Constraints(),
  ExistingTaskPolicy existingPolicy = ExistingTaskPolicy.replace,
  String? tag,
})
```

**Parameters:**
- `taskId` - Unique identifier for the task
- `trigger` - When/how the task should run. Defaults to `TaskTrigger.oneTime()`
- `worker` - The worker that executes the task logic. Any input data goes through the specific `Worker` subclass's own constructor (e.g. `NativeWorker.httpSync(...)`, `DartWorker(callbackId: ..., input: ...)`) — there is no separate `inputData` parameter
- `constraints` - Execution constraints (network, battery, etc.). Defaults to `Constraints()`
- `existingPolicy` - What to do if `taskId` already has a pending/running task. Defaults to `ExistingTaskPolicy.replace`
- `tag` - Optional tag for grouping tasks (see `cancelByTag`, `getTasksByTag`)

**Returns:** `TaskHandler` — streams progress/result events scoped to this task (see [Track progress in real time](../README.md#track-progress-in-real-time))

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
static Future<void> cancel({required String taskId})
```

**Example:**
```dart
await NativeWorkManager.cancel(taskId: 'api-sync');
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
  RequestSigning? requestSigning,
})
```

---

##### `parallelHttpDownload()`

Chunked parallel download — splits the file into `numChunks` ranged requests for faster downloads on high-bandwidth connections.

```dart
static Worker parallelHttpDownload({
  required String url,
  required String savePath,
  int numChunks = 4,
  Map<String, String> headers = const {},
  Duration timeout = const Duration(minutes: 10),
  String? expectedChecksum,
  String checksumAlgorithm = 'SHA-256',
  bool showNotification = false,
})
```

---

##### `custom()`

Invoke a custom native worker class you registered yourself (Android `SimpleAndroidWorkerFactory` / iOS `IosWorkerFactory`). See [Custom Native Workers](use-cases/07-custom-native-workers.md).

```dart
static Worker custom({
  required String className,
  Map<String, dynamic>? input,
})
```

---

#### File Workers

##### `fileCompress()` ⚠️ Deprecated

> **Deprecated since v1.1.0** — native ZIP support was removed. Do not use in new code.

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

##### `fileDecompress()` ⚠️ Deprecated

> **Deprecated since v1.1.0** — native ZIP support was removed. Do not use in new code.

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
  int quality = 85,
  ImageFormat? outputFormat,
  Rect? cropRect,
  bool deleteOriginal = false,
})
```

`cropRect` is `dart:ui`'s `Rect` (`import 'dart:ui' show Rect;`) — not a package-specific type.

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

#### PDF Workers

##### `pdfMerge()`

Merge multiple PDF files into one.

```dart
static Worker pdfMerge({
  required List<String> inputPaths,
  required String outputPath,
})
```

---

##### `pdfCompress()`

Re-render a PDF at lower quality to reduce file size.

```dart
static Worker pdfCompress({
  required String inputPath,
  required String outputPath,
  int quality = 80,
})
```

---

##### `pdfFromImages()`

Convert image files into a PDF (one image per page).

```dart
static Worker pdfFromImages({
  required List<String> imagePaths,
  required String outputPath,
  PdfPageSize pageSize = PdfPageSize.a4,
  int margin = 0,
})
```

---

#### Storage Workers

##### `moveToSharedStorage()`

Move a file into shared/public storage (Android `MediaStore` — Downloads/Pictures/Movies; iOS Files app).

```dart
static MoveToSharedStorageWorker moveToSharedStorage({
  required String sourcePath,
  required SharedStorageType storageType,
  String? fileName,
  String? mimeType,
  String? subDir,
})
```

---

#### Real-time Workers

##### `webSocket()`

Send a sequence of WebSocket messages and optionally capture responses. Android only.

```dart
static Worker webSocket({
  required String url,
  List<String> messages = const [],
  Map<String, String> headers = const {},
  int timeoutSeconds = 30,
  int receiveMessages = 1,
  String? storeResponseAt,
  int? pingIntervalSeconds,
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
Future<bool> myProcessData(Map<String, dynamic>? input) async {
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
static TaskTrigger oneTime([Duration initialDelay = Duration.zero])
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
  bool runImmediately = true,
})
```

**Parameters:**
- `interval`: Time between executions (minimum 15 minutes).
- `flexInterval`: (Android only) Flex window for OS optimization.
- `initialDelay`: (New in v1.2.3) Delay before the very first execution.
- `runImmediately`: Whether the first execution fires right away (subject to `initialDelay`) or waits a full `interval` before the first run. Defaults to `true`.

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
  bool requiresDeviceIdle = false,
  bool requiresBatteryNotLow = false,
  bool requiresStorageNotLow = false,
  bool allowWhileIdle = false,
  bool isHeavyTask = false,
  QoS qos = QoS.background,
  ExactAlarmIOSBehavior exactAlarmIOSBehavior = ExactAlarmIOSBehavior.showNotification,
  BackoffPolicy backoffPolicy = BackoffPolicy.exponential,
  int backoffDelayMs = 30000,
  int maxRetries = 3,
  Set<SystemConstraint> systemConstraints = const {},
  BGTaskType? bgTaskType,
  ForegroundServiceType? foregroundServiceType,
  ForegroundNotificationConfig? foregroundNotificationConfig,
})
```

- `allowWhileIdle`: (Android only) If true, uses **Expedited Work** to run tasks silently even when the device is locked or in Doze mode. **Warning:** Do not use simultaneously with `isHeavyTask: true`.

**Note on FGS Bypass**: Providing a `foregroundNotificationConfig` automatically promotes the task to an Android Foreground Service. This is the recommended way to bypass battery optimizations for critical, long-running tasks.

**Example:**
```dart
Constraints(
  requiresNetwork: true,
  foregroundServiceType: ForegroundServiceType.dataSync,
  foregroundNotificationConfig: ForegroundNotificationConfig(
    title: "Syncing Data",
    body: "Please wait...",
    showCancelButton: true,
  ),
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
  md5,     // ⚠️ Deprecated — cryptographically broken, use sha256/sha512
  sha1,    // ⚠️ Deprecated — cryptographically broken, use sha256/sha512
  sha256,
  sha512,
}
```

---

### BackoffPolicy

```dart
enum BackoffPolicy {
  exponential,
  linear,
}
```

---

### ForegroundServiceType

Used to specify the type of Foreground Service for Android 14+ compliance.

```dart
enum ForegroundServiceType {
  dataSync,      // Default — safe for most heavy tasks, no permissions required
  location,      // Requires ACCESS_FINE_LOCATION/ACCESS_COARSE_LOCATION
  mediaPlayback, // Requires FOREGROUND_SERVICE_MEDIA_PLAYBACK (Android 14+)
  camera,        // Requires CAMERA + FOREGROUND_SERVICE_CAMERA (Android 14+)
  microphone,    // Requires RECORD_AUDIO + FOREGROUND_SERVICE_MICROPHONE (Android 14+)
  health,        // Requires BODY_SENSORS + FOREGROUND_SERVICE_HEALTH (Android 14+)
}
```

---

## Classes

### ForegroundNotificationConfig

Configuration for the mandatory notification shown when a task runs as a Foreground Service on Android.

```dart
const ForegroundNotificationConfig({
  required String title,
  required String body,
  String? iconName,
  String? colorHex,
  bool showCancelButton = true,
  String cancelText = "Cancel",
})
```

**Parameters:**
- `title` - The primary title of the notification.
- `body` - The description text shown under the title.
- `iconName` - Name of the drawable resource to use as small icon (e.g., "ic_notification"). Defaults to app icon.
- `colorHex` - Hex color code for the notification (e.g., "#FF5722").
- `showCancelButton` - Whether to show a "Cancel" action button in the notification.
- `cancelText` - Label for the cancel button.

---

## Events

### TaskEvent

Emitted when task completes.

```dart
class TaskEvent {
  final String taskId;
  final bool success;
  final String? message;
  final String? errorCode;
  final Map<String, dynamic>? resultData;
  final DateTime timestamp;
  final bool isStarted;
  final String? workerType;
}
```

`isStarted` is `true` for the transient "worker began execution" event (see `enqueue()`'s progress stream); `resultData` carries worker-specific output (e.g. downloaded file size, hash value).

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
Future<ScheduleResult> enqueue()
```

---

### TaskRequest

Represents a task in a chain.

```dart
TaskRequest({
  required String id,
  required Worker worker,
  Constraints constraints = const Constraints(),
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

### Android battery restrictions

The most common real-world reason a periodic task runs late is the OS — or the device
manufacturer — deferring it. These report what the OS actually says.

```dart
final report = await NativeWorkManager.batteryRestriction();

if (report.isExempt == false) {
  await NativeWorkManager.openBatteryOptimizationSettings();
}
```

| Method | Returns | Notes |
| :--- | :--- | :--- |
| `batteryRestriction()` | `BatteryRestrictionReport` | Pure diagnostic. Does not require `initialize()`. |
| `openBatteryOptimizationSettings()` | `Future<bool>` | Opens the system list. **No permission needed.** |
| `requestDisableBatteryOptimization()` | `BatteryOptimizationRequestResult` | Direct dialog. Needs a host-app permission — see below. |

**`BatteryRestrictionReport`**

| Field | Type | Meaning |
| :--- | :--- | :--- |
| `isExempt` | `bool?` | `PowerManager.isIgnoringBatteryOptimizations()`. `null` = no answer (iOS, or an OEM build that threw). |
| `manufacturer` | `String?` | `Build.MANUFACTURER`, lowercased. `null` on iOS. |
| `canOpenSettings` | `bool` | Whether the settings screen resolves on this device — checked, not assumed. |
| `isSupported` | `bool` | `false` whenever `isExempt` is `null`. |

> **`isExempt: true` is not a guarantee.** It reflects one stock-Android list. Xiaomi
> (MIUI/HyperOS), Samsung, Huawei, Oppo and Vivo run their own task killer on top of it, so a
> device can report `true` and still stretch a 15-minute task into hours.

There are deliberately **no per-manufacturer settings deep links** — those screens are
undocumented internal activities that get renamed between firmware builds. Use `manufacturer`
to word your own guidance.

**`BatteryOptimizationRequestResult`**

`shown` · `alreadyExempt` · `missingPermission` · `unavailable` · `notSupported`

`requestDisableBatteryOptimization()` needs this in **your** manifest:

```xml
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

The plugin never declares it — it is Play-policy restricted and a library manifest merges into
every consumer app. Without it the call returns `missingPermission` rather than throwing. Unless
your app fits one of Google's eligible categories, prefer `openBatteryOptimizationSettings()`.

See [ANDROID_SETUP.md](ANDROID_SETUP.md) for the full guidance.

---

## See Also

- [Getting Started Guide](GETTING_STARTED.md)
- [Use Cases](use-cases/)
- [Production Guide](PRODUCTION_GUIDE.md)
- [FAQ](FAQ.md)

---

**Version:** 1.6.0
**Last Updated:** 2026-09-06
