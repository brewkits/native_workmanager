# Migration Guide: from workmanager to native_workmanager

**Estimated Time:** 30 minutes for typical app
**API Compatibility:** ~90%
**Difficulty:** Easy

---

## Why Migrate?

### ROI Calculation

**Memory Savings:**
```
Your current usage (workmanager):
- 85 MB per task
- 10 tasks per day
- = 850 MB daily memory consumption

After migration (native_workmanager with native workers):
- 35 MB per task (or 5 MB with pure native workers)
- 10 tasks per day
- = 350 MB daily (or 50 MB with native workers)

Savings: 500-800 MB per day
Impact: Fewer crashes on low-end devices, better user reviews
```

**Battery Savings:**
```
24-hour test (periodic task every 15 minutes):
- workmanager: 7% battery drain
- native_workmanager: 3% battery drain

Savings: ~50% battery improvement
Impact: Higher App Store ratings, fewer user complaints
```

**Performance Improvement:**
- Faster task startup (native workers don't load Flutter Engine)
- Better responsiveness
- Less UI jank during background execution

---

## API Compatibility Matrix

### ✅ Fully Compatible (90%)

These APIs work with minimal or no changes:

| workmanager | native_workmanager | Changes Needed |
|---------------------|-------------------|----------------|
| `Workmanager().initialize()` | `NativeWorkManager.initialize()` | ✅ Direct replacement |
| `registerOneOffTask()` | `enqueue()` with `oneTime()` | ⚠️ API structure change |
| `registerPeriodicTask()` | `enqueue()` with `periodic()` | ⚠️ API structure change |
| `cancelByUniqueName()` | `cancel(taskId)` | ✅ Direct replacement |
| `cancelAll()` | `cancelAll()` | ✅ Direct replacement |
| Constraints (network, battery) | `Constraints(...)` | ✅ Same concept, different syntax |

### ⚠️ Requires Changes (10%)

| workmanager | native_workmanager | Migration Path |
|---------------------|-------------------|----------------|
| `registerTask()` (generic) | `enqueue()` | Use specific trigger type |
| Task tags | Not yet supported | Use individual `cancel()` calls (v1.1 will add tagging) |
| Input data (Map) | `worker.input` or `DartWorker.input` | Restructure data passing |
| Callback dispatcher (switch/case) | Callback ID map | Refactor to map-based registration |

### ❌ Not Supported

| workmanager Feature | Alternative in native_workmanager |
|----------------------------|-----------------------------------|
| Background fetch (iOS specific) | Use `TaskTrigger.periodic()` |
| Custom callback dispatcher pattern | Use `dartWorkers` map registration |

---

## Migration Steps

### Step 1: Run Migration Analyzer (Optional)

We provide a tool to scan your codebase and generate a migration report:

```bash
# From your project root
dart run native_workmanager:migrate
```

**Output:**
```
📊 Migration Analysis Complete

Found: 12 background tasks
Compatibility: 90% (automatic migration possible)

Changes Required:
✅ 10 tasks → Automatic (registerOneOffTask, registerPeriodicTask)
⚠️ 2 tasks → Manual review needed (custom callbacks)

Generate migration code? (y/n)
> y

✅ Created: migration/
  ├── pubspec.yaml.new
  ├── main.dart.migrated
  ├── tasks.dart.migrated
  └── MIGRATION_CHECKLIST.md

Next Steps:
1. Review generated code
2. Test in debug mode
3. Follow MIGRATION_CHECKLIST.md
```

---

### Step 2: Update pubspec.yaml

**Before:**
```yaml
dependencies:
  workmanager: ^0.5.0
```

**After:**
```yaml
dependencies:
  native_workmanager: ^1.0.3
```

**Then run:**
```bash
flutter pub get
```

**Note:** You can keep both packages temporarily during migration for gradual transition.

---

### Step 3: Replace Initialization

#### Before (workmanager)

```dart
import 'package:workmanager/workmanager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(
    callbackDispatcher, // Top-level function
    isInDebugMode: true
  );
  runApp(MyApp());
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    switch (task) {
      case 'syncTask':
        return syncData();
      case 'uploadTask':
        return uploadFiles();
      default:
        return Future.value(false);
    }
  });
}
```

#### After (native_workmanager)

**Option A: Native Workers Only (No Dart code in background)**

```dart
import 'package:native_workmanager/native_workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize();
  runApp(MyApp());
}

// No callback dispatcher needed for native workers!
```

**Option B: With Dart Workers (Need Dart code in background)**

```dart
import 'package:native_workmanager/native_workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeWorkManager.initialize(
    dartWorkers: {
      'syncTask': _syncDataCallback,
      'uploadTask': _uploadFilesCallback,
    },
  );
  runApp(MyApp());
}

@pragma('vm:entry-point')
Future<bool> _syncDataCallback(Map<String, dynamic>? input) async {
  // Your sync logic
  return true;
}

@pragma('vm:entry-point')
Future<bool> _uploadFilesCallback(Map<String, dynamic>? input) async {
  // Your upload logic
  return true;
}
```

**Key Differences:**
- No `callbackDispatcher()` function
- Callbacks registered as map (`'taskId': callbackFunction`)
- Add `@pragma('vm:entry-point')` to prevent tree-shaking
- `async`/`await` supported natively

---

### Step 4: Update Task Registration

#### Pattern 1: One-Time Task

**Before (workmanager):**
```dart
Workmanager().registerOneOffTask(
  'task-1',
  'syncTask',
  inputData: {
    'userId': 123,
    'action': 'sync',
  },
  constraints: Constraints(
    networkType: NetworkType.connected,
  ),
);
```

**After (native_workmanager with Native Worker):**
```dart
await NativeWorkManager.enqueue(
  taskId: 'task-1',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.httpSync(
    url: 'https://api.example.com/sync?userId=123',
    method: HttpMethod.post,
  ),
  constraints: Constraints(
    requiresNetworkType: NetworkType.connected,
  ),
);
```

**After (native_workmanager with Dart Worker - if you need Dart code):**
```dart
await NativeWorkManager.enqueue(
  taskId: 'task-1',
  trigger: TaskTrigger.oneTime(),
  worker: DartWorker(
    callbackId: 'syncTask',
    input: {
      'userId': 123,
      'action': 'sync',
    },
    autoDispose: true, // Release Flutter Engine after task
  ),
  constraints: Constraints(
    requiresNetworkType: NetworkType.connected,
  ),
);
```

---

#### Pattern 2: Periodic Task

**Before (workmanager):**
```dart
Workmanager().registerPeriodicTask(
  'periodic-sync',
  'syncTask',
  frequency: Duration(hours: 1),
  constraints: Constraints(
    networkType: NetworkType.unmetered,
  ),
);
```

**After (native_workmanager with Native Worker):**
```dart
await NativeWorkManager.enqueue(
  taskId: 'periodic-sync',
  trigger: TaskTrigger.periodic(
    Duration(hours: 1),
  ),
  worker: NativeWorker.httpSync(
    url: 'https://api.example.com/sync',
    method: HttpMethod.post,
  ),
  constraints: Constraints(
    requiresNetworkType: NetworkType.unmetered,
  ),
);
```

**After (native_workmanager with Dart Worker):**
```dart
await NativeWorkManager.enqueue(
  taskId: 'periodic-sync',
  trigger: TaskTrigger.periodic(
    Duration(hours: 1),
  ),
  worker: DartWorker(
    callbackId: 'syncTask',
    autoDispose: true,
  ),
  constraints: Constraints(
    requiresNetworkType: NetworkType.unmetered,
  ),
);
```

---

#### Pattern 3: With Retry Policy

**Before (workmanager):**
```dart
Workmanager().registerOneOffTask(
  'upload-task',
  'uploadTask',
  backoffPolicy: BackoffPolicy.exponential,
  backoffPolicyDelay: Duration(seconds: 30),
);
```

**After (native_workmanager):**
```dart
await NativeWorkManager.enqueue(
  taskId: 'upload-task',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.httpUpload(
    url: 'https://api.example.com/upload',
    filePath: '/path/to/file',
  ),
  retryPolicy: RetryPolicy(
    backoffPolicy: BackoffPolicy.exponential,
    initialDelay: Duration(seconds: 30),
    maxAttempts: 3,
  ),
);
```

---

#### Pattern 4: Constraints

**Before (workmanager):**
```dart
constraints: Constraints(
  networkType: NetworkType.unmetered,
  requiresBatteryNotLow: true,
  requiresCharging: true,
),
```

**After (native_workmanager - Same!):**
```dart
constraints: Constraints(
  requiresNetworkType: NetworkType.unmetered,
  requiresBatteryNotLow: true,
  requiresCharging: true,
),
```

**Note:** Property name changed: `networkType` → `requiresNetworkType`

---

### Step 5: Replace Cancel Operations

**Before (workmanager):**
```dart
// Cancel specific task
Workmanager().cancelByUniqueName('task-1');

// Cancel all tasks
Workmanager().cancelAll();

// Cancel by tag (if you used tags)
Workmanager().cancelByTag('sync-group');
```

**After (native_workmanager):**
```dart
// Cancel specific task
await NativeWorkManager.cancel('task-1');

// Cancel all tasks
await NativeWorkManager.cancelAll();

// Cancel by tag - NOT YET SUPPORTED (coming in v1.1)
// Workaround: Track task IDs yourself and cancel individually
List<String> syncTasks = ['task-1', 'task-2', 'task-3'];
for (var taskId in syncTasks) {
  await NativeWorkManager.cancel(taskId);
}
```

---

### Step 6: Test Thoroughly

**Testing Checklist:**

- [ ] All tasks schedule successfully
- [ ] Tasks execute in background (kill app and wait)
- [ ] Constraints work as expected (test Wi-Fi, charging, etc.)
- [ ] Retry logic works (simulate failures)
- [ ] Task cancellation works
- [ ] No crashes or memory leaks
- [ ] Monitor memory usage (should be lower)
- [ ] Test on low-end Android devices (biggest impact)
- [ ] Test on iOS (verify 30-second limit compliance)

**Debug Tools:**

```dart
// Monitor all task events
NativeWorkManager.events.listen((event) {
  print('📊 Task: ${event.taskId} - State: ${event.state}');
});

// Get all scheduled tasks
final tasks = await NativeWorkManager.getAllTasks();
print('Scheduled tasks: ${tasks.length}');
```

---

## Side-by-Side Code Examples

### Example 1: Simple HTTP Request

**Before (workmanager):**
```dart
// 1. Register callback
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    if (task == 'apiSync') {
      final response = await http.post(
        Uri.parse('https://api.example.com/sync'),
        headers: {'Authorization': 'Bearer TOKEN'},
      );
      return response.statusCode == 200;
    }
    return false;
  });
}

// 2. Schedule task
Workmanager().registerPeriodicTask(
  'sync',
  'apiSync',
  frequency: Duration(hours: 1),
);
```

**After (native_workmanager - Native Worker):**
```dart
// 1. No callback needed!

// 2. Schedule task
await NativeWorkManager.enqueue(
  taskId: 'sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpRequest(
    url: 'https://api.example.com/sync',
    method: HttpMethod.post,
    headers: {'Authorization': 'Bearer TOKEN'},
  ),
);
```

**Savings:** 50 MB RAM, 400ms startup time, simpler code

---

### Example 2: File Upload

**Before (workmanager):**
```dart
// Complex: Manual HTTP multipart, retry logic, etc.
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'upload') {
      final file = File(inputData!['filePath']);
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.example.com/upload'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      var response = await request.send();
      return response.statusCode == 200;
    }
    return false;
  });
}
```

**After (native_workmanager - Native Worker):**
```dart
await NativeWorkManager.enqueue(
  taskId: 'upload',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.httpUpload(
    url: 'https://api.example.com/upload',
    filePath: '/path/to/file.jpg',
    headers: {'Authorization': 'Bearer TOKEN'},
  ),
  retryPolicy: RetryPolicy(maxAttempts: 3), // Built-in retry!
);
```

**Savings:** 50 MB RAM, 80 lines of code → 10 lines

---

### Example 3: Complex Dart Logic (Keep as Dart Worker)

**Before (workmanager):**
```dart
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'processData') {
      final db = await openDatabase('my_db.db');
      final data = await db.query('items');
      // Complex processing...
      await db.close();
      return true;
    }
    return false;
  });
}

Workmanager().registerOneOffTask('process', 'processData');
```

**After (native_workmanager - Dart Worker):**
```dart
// 1. Register callback in main()
await NativeWorkManager.initialize(
  dartWorkers: {
    'processData': _processDataCallback,
  },
);

@pragma('vm:entry-point')
Future<bool> _processDataCallback(Map<String, dynamic>? input) async {
  final db = await openDatabase('my_db.db');
  final data = await db.query('items');
  // Complex processing...
  await db.close();
  return true;
}

// 2. Schedule task
await NativeWorkManager.enqueue(
  taskId: 'process',
  trigger: TaskTrigger.oneTime(),
  worker: DartWorker(
    callbackId: 'processData',
    autoDispose: true, // NEW: Release engine after task
  ),
);
```

**Benefits:** Same functionality, better memory management with `autoDispose`

---

## Common Migration Patterns

### Pattern: Migrating Multiple Tasks

**Before:**
```dart
// Schedule multiple tasks
Workmanager().registerPeriodicTask('sync-1', 'syncTask');
Workmanager().registerPeriodicTask('sync-2', 'syncTask');
Workmanager().registerOneOffTask('upload-1', 'uploadTask');
```

**After:**
```dart
// Use native workers for I/O tasks
final tasks = [
  ('sync-1', 'https://api.example.com/sync1'),
  ('sync-2', 'https://api.example.com/sync2'),
];

for (var (taskId, url) in tasks) {
  await NativeWorkManager.enqueue(
    taskId: taskId,
    trigger: TaskTrigger.periodic(Duration(hours: 1)),
    worker: NativeWorker.httpSync(url: url, method: HttpMethod.post),
  );
}

// Dart worker for complex task
await NativeWorkManager.enqueue(
  taskId: 'upload-1',
  trigger: TaskTrigger.oneTime(),
  worker: DartWorker(callbackId: 'uploadTask'),
);
```

---

### Pattern: Task Tags (Workaround)

**Before:**
```dart
Workmanager().registerPeriodicTask('sync-1', 'syncTask', tag: 'sync-group');
Workmanager().registerPeriodicTask('sync-2', 'syncTask', tag: 'sync-group');

// Cancel all tasks with tag
Workmanager().cancelByTag('sync-group');
```

**After (Workaround until v1.1):**
```dart
// Track task IDs manually
class TaskGroups {
  static const syncGroup = ['sync-1', 'sync-2', 'sync-3'];
  static const uploadGroup = ['upload-1', 'upload-2'];
}

// Schedule tasks
for (var taskId in TaskGroups.syncGroup) {
  await NativeWorkManager.enqueue(taskId: taskId, /* ... */);
}

// Cancel by group
Future<void> cancelGroup(List<String> taskIds) async {
  for (var taskId in taskIds) {
    await NativeWorkManager.cancel(taskId);
  }
}

await cancelGroup(TaskGroups.syncGroup);
```

**Note:** v1.1 will add native task tagging support.

---

## Performance Optimization Tips

### Tip 1: Prefer Native Workers Over Dart Workers

**When possible, convert Dart workers to native workers:**

❌ **Suboptimal (Dart Worker - 50 MB):**
```dart
DartWorker(callbackId: 'httpRequest')
```

✅ **Optimal (Native Worker - 5 MB):**
```dart
NativeWorker.httpRequest(url: '...') // 10x improvement!
```

**When to use each:**
- **Native Worker:** HTTP requests, file operations, simple I/O
- **Dart Worker:** Complex business logic, need Dart packages, existing code reuse

---

### Tip 2: Use `autoDispose` for Dart Workers

**Enable automatic Flutter Engine disposal:**

```dart
DartWorker(
  callbackId: 'processData',
  autoDispose: true, // 👈 Releases engine after task completes
)
```

**Impact:** Prevents memory accumulation, especially for periodic tasks.

---

### Tip 3: Use Task Chains for Workflows

**Before (Manual coordination):**
```dart
// Task 1: Download
Workmanager().registerOneOffTask('download', 'downloadTask');

// Manually check in callback if download succeeded, then:
// Task 2: Process (requires custom state management)

// Task 3: Upload (requires even more state management)
```

**After (Automated with Task Chains):**
```dart
NativeWorkManager.beginWith(
  TaskRequest(id: 'download', worker: NativeWorker.httpDownload(/* ... */)),
)
.then(TaskRequest(id: 'process', worker: DartWorker(callbackId: 'process')))
.then(TaskRequest(id: 'upload', worker: NativeWorker.httpUpload(/* ... */)))
.enqueue();
```

**Benefits:** Automatic dependency management, built-in retry, failure isolation.

---

## Migration Checklist

Use this checklist to track your migration progress:

- [ ] **Pre-Migration**
  - [ ] Run migration analyzer tool
  - [ ] Review generated report
  - [ ] Backup current codebase
  - [ ] Read this migration guide

- [ ] **Code Changes**
  - [ ] Update pubspec.yaml
  - [ ] Replace initialization code
  - [ ] Convert task registration calls
  - [ ] Update callback structure
  - [ ] Replace cancel operations
  - [ ] Add `@pragma` annotations to Dart callbacks

- [ ] **Optimization**
  - [ ] Identify tasks that can use native workers
  - [ ] Convert I/O tasks to native workers
  - [ ] Add `autoDispose` to remaining Dart workers
  - [ ] Consider task chains for complex workflows

- [ ] **Testing**
  - [ ] Test all tasks in debug mode
  - [ ] Test background execution (kill app)
  - [ ] Test constraints (Wi-Fi, charging, battery)
  - [ ] Test retry logic (simulate failures)
  - [ ] Profile memory usage (before/after)
  - [ ] Test on low-end Android device
  - [ ] Test on iOS (30-second limit)

- [ ] **Deployment**
  - [ ] Gradual rollout (10% → 50% → 100%)
  - [ ] Monitor crash rates
  - [ ] Monitor memory metrics
  - [ ] Monitor battery complaints
  - [ ] Collect user feedback

- [ ] **Post-Migration**
  - [ ] Remove workmanager dependency
  - [ ] Update documentation
  - [ ] Train team on new APIs
  - [ ] Celebrate improved performance! 🎉

---

## Troubleshooting Migration Issues

### Issue: Tasks Not Scheduling

**Symptoms:** `enqueue()` succeeds but tasks never run.

**Solutions:**
1. Check task ID uniqueness (duplicate IDs cancel previous)
2. Verify constraints aren't too restrictive
3. Check Android battery optimization settings
4. Enable verbose logging:
   ```dart
   await NativeWorkManager.initialize(debugMode: true);
   ```

---

### Issue: Dart Callbacks Not Found

**Symptoms:** "Callback not found" error at runtime.

**Solutions:**
1. Verify callback ID matches map key:
   ```dart
   dartWorkers: {
     'myTask': _myTaskCallback, // Key must match callbackId
   }

   DartWorker(callbackId: 'myTask') // Must match key above
   ```
2. Add `@pragma('vm:entry-point')` annotation
3. Ensure callback is top-level or static function

---

### Issue: Memory Usage Still High

**Symptoms:** Memory not improving after migration.

**Solutions:**
1. Verify you're using **native workers** (not Dart workers)
2. Enable `autoDispose: true` for Dart workers
3. Check for memory leaks in callbacks
4. Use profiler to identify actual source

---

### Issue: iOS Tasks Failing

**Symptoms:** Works on Android, fails on iOS.

**Solutions:**
1. Check 30-second execution limit - split long tasks
2. Verify Info.plist permissions
3. Enable background modes in Xcode
4. Test with iOS-specific constraints

---

## FAQ

### Q: Can I keep both libraries during migration?

**A:** Yes! You can run both workmanager and native_workmanager side-by-side:

```yaml
dependencies:
  workmanager: ^0.5.0
  native_workmanager: ^1.0.3
```

Migrate tasks one at a time, then remove workmanager when done.

---

### Q: What if I need task tagging NOW?

**A:** Implement manual grouping (see "Task Tags Workaround" above) currently not supported natively.

---

### Q: Will this break my production app?

**A:** No, if you follow the testing checklist. The APIs are similar enough that migration is low-risk. Test thoroughly before deploying.

---

### Q: How long does migration take?

**A:** Typical app: 30-60 minutes
- 10 minutes: Update dependencies and initialization
- 20 minutes: Convert task registration calls
- 30 minutes: Testing and verification

Large apps (50+ tasks): 2-4 hours

---

### Q: What if I encounter bugs?

**A:** Report on GitHub Issues: https://github.com/brewkits/native_workmanager/issues

Include:
- workmanager code (before)
- native_workmanager code (after)
- Error messages or unexpected behavior
- Android/iOS version

---

## Get Help

**Need assistance with migration?**

- 💬 [Discord Community](https://discord.gg/native-workmanager) - Ask questions, get help
- 📧 [GitHub Discussions](https://github.com/brewkits/native_workmanager/discussions) - Community support
- 🎯 [Early Adopter Program](https://forms.gle/...) - Priority migration support

---

**🎉 Congratulations on migrating to native_workmanager! Enjoy 10x better performance!**
