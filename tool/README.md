# Migration Tools

Tools to help migrate from workmanager to native_workmanager.

---

## 🔧 migrate.dart - Automated Migration Tool

Analyzes your codebase and generates migration code automatically.

### Quick Start

```bash
# Run from your Flutter project root
dart run path/to/native_workmanager/tools/migrate.dart
```

### Usage

```bash
# Basic usage (current directory)
dart run tools/migrate.dart

# Dry run (analyze only, don't generate files)
dart run tools/migrate.dart --dry-run

# Specify project path
dart run tools/migrate.dart --path /path/to/your/project
```

---

## What It Does

### 1. Scans Your Project

- ✅ Checks pubspec.yaml for workmanager dependency
- ✅ Finds all Dart files in lib/
- ✅ Analyzes workmanager usage patterns
- ✅ Counts tasks and callbacks

### 2. Generates Report

Shows detailed analysis:
- Files with imports
- Initialize calls
- One-off tasks
- Periodic tasks
- Callback functions
- Compatibility percentage

### 3. Creates Migration Files

Generates complete migration package:
- `pubspec.yaml.new` - Updated dependencies
- `MIGRATION_GUIDE.md` - Step-by-step instructions
- `CODE_SAMPLES.md` - Before/after examples
- `CHECKLIST.md` - Task-by-task migration checklist

---

## Example Output

```
╔═══════════════════════════════════════════════════════════╗
║   native_workmanager Migration Tool                      ║
║   workmanager → native_workmanager               ║
╚═══════════════════════════════════════════════════════════╝

📁 Project path: /Users/you/my_app
🔍 Scanning for workmanager usage...

📄 Found 15 Dart files

╔═══════════════════════════════════════════════════════════╗
║   Migration Analysis Report                              ║
╚═══════════════════════════════════════════════════════════╝

📊 Summary:
   Files with import: 3
   Initialize calls: 1
   One-off tasks: 5
   Periodic tasks: 2
   Callback files: 1

✅ Compatibility: 90%
   7 tasks → Automatic migration possible
   ⚠️  1 callback(s) → Manual review needed

📄 Files with workmanager import:
   • lib/main.dart
   • lib/services/sync_service.dart
   • lib/utils/background_tasks.dart

🔧 Files with Workmanager().initialize():
   • lib/main.dart

⚡ Files with registerOneOffTask():
   • lib/services/sync_service.dart

🔄 Files with registerPeriodicTask():
   • lib/services/sync_service.dart

⚠️  Callback files (manual review needed):
   • lib/main.dart

Generate migration code? (y/n): y

📝 Generating migration files...

   ✅ Generated pubspec.yaml.new
   ✅ Generated MIGRATION_GUIDE.md
   ✅ Generated CODE_SAMPLES.md
   ✅ Generated CHECKLIST.md

✅ Migration files generated in: migration/

📁 Generated files:
   • pubspec.yaml.new        - Updated dependencies
   • MIGRATION_GUIDE.md      - Step-by-step guide
   • CODE_SAMPLES.md         - Before/after examples
   • CHECKLIST.md            - Migration checklist

📖 Next steps:
   1. Review migration/MIGRATION_GUIDE.md
   2. Update pubspec.yaml:
      cp migration/pubspec.yaml.new pubspec.yaml
      flutter pub get
   3. Follow migration/CHECKLIST.md
   4. Test thoroughly before deploying
```

---

## Generated Files

### 1. pubspec.yaml.new

Updated dependencies file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  native_workmanager: ^1.0.0  # Replaced workmanager
```

**Usage:**
```bash
cp migration/pubspec.yaml.new pubspec.yaml
flutter pub get
```

### 2. MIGRATION_GUIDE.md

Comprehensive migration guide with:
- Step-by-step instructions
- Code examples (before/after)
- Common issues and solutions
- Testing guidelines

### 3. CODE_SAMPLES.md

Real code examples for:
- HTTP sync tasks
- File uploads
- Periodic tasks
- Constraints
- And more...

### 4. CHECKLIST.md

Interactive checklist with:
- Pre-migration steps
- File-by-file migration tasks
- Testing checklist
- Post-migration verification
- Rollback plan

---

## Migration Workflow

### Step 1: Analyze

```bash
dart run tools/migrate.dart --dry-run
```

Review the analysis report to understand:
- How many files need updating
- Task compatibility
- Estimated migration time

### Step 2: Generate

```bash
dart run tools/migrate.dart
# Answer 'y' when prompted
```

### Step 3: Review

```bash
cd migration/
cat MIGRATION_GUIDE.md
```

Read the guide to understand changes.

### Step 4: Update Dependencies

```bash
cp migration/pubspec.yaml.new pubspec.yaml
flutter pub get
```

### Step 5: Migrate Code

Follow `migration/CHECKLIST.md` line-by-line:
- Update imports
- Update initialization
- Migrate tasks
- Remove callbacks (if using native workers)

### Step 6: Test

```bash
flutter clean
flutter pub get
flutter run
```

Verify:
- ✅ App builds without errors
- ✅ Tasks execute correctly
- ✅ Background execution works
- ✅ Memory usage improved

### Step 7: Cleanup

```bash
rm -rf migration/
git add .
git commit -m "Migrate from workmanager to native_workmanager"
```

---

## Compatibility

The tool detects and handles:

### ✅ Fully Compatible (Automatic Migration)

- `Workmanager().initialize()`
- `Workmanager().registerOneOffTask()`
- `Workmanager().registerPeriodicTask()`
- Basic constraints (network, battery, charging)
- Task cancellation

### ⚠️  Requires Manual Review

- Custom callback logic (complex Dart code)
- Platform-specific code (iOS/Android differences)
- Custom constraints
- Advanced task chaining

---

## Common Scenarios

### Scenario 1: Simple HTTP Sync

**Before:**
```dart
Workmanager().registerPeriodicTask(
  "sync",
  "apiSync",
  frequency: Duration(hours: 1),
);
```

**After (Generated):**
```dart
await NativeWorkManager.enqueue(
  taskId: "sync",
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpRequest(
    url: 'https://api.example.com/sync',
  ),
);
```

### Scenario 2: File Upload

**Before:**
```dart
Workmanager().registerOneOffTask("upload", "fileUpload");
```

**After (Generated):**
```dart
await NativeWorkManager.enqueue(
  taskId: "upload",
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.httpUpload(
    url: 'https://api.example.com/upload',
    filePath: '/path/to/file',
  ),
);
```

### Scenario 3: Complex Dart Logic

**Before:**
```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Complex Dart logic
    final result = await processData();
    return Future.value(result);
  });
}
```

**After (Manual - Use DartWorker):**
```dart
void main() async {
  await NativeWorkManager.initialize();
  NativeWorkManager.registerCallback('process', processCallback);
}

@pragma('vm:entry-point')
Future<void> processCallback(String? input) async {
  // Your existing logic
  final result = await processData();
}

// Later:
await NativeWorkManager.enqueue(
  taskId: "process",
  trigger: TaskTrigger.oneTime(),
  worker: DartWorker(callbackId: 'process'),
);
```

---

## Troubleshooting

### Issue: Tool doesn't run

**Solution:** Make sure Dart is installed:
```bash
dart --version
```

If not installed, it comes with Flutter:
```bash
flutter doctor
```

### Issue: "pubspec.yaml not found"

**Solution:** Run from your Flutter project root:
```bash
cd /path/to/your/flutter/project
dart run path/to/migrate.dart
```

### Issue: No workmanager found

This is expected if you're not using workmanager. The tool is only for migrating existing projects.

### Issue: Permission denied

**Solution:** Make the script executable:
```bash
chmod +x tools/migrate.dart
./tools/migrate.dart
```

---

## Advanced Usage

### Custom Analysis

Edit `migrate.dart` to add custom patterns:

```dart
// In _analyzeFiles method:
if (content.contains('YourCustomPattern')) {
  analysis.customMatches.add(relativePath);
}
```

### Custom Templates

Edit the generated files in `_generateMigration` methods to customize output format.

---

## Limitations

The tool cannot automatically migrate:
1. **Complex Dart callbacks** - Requires manual review
2. **Platform-specific code** - May need adjustment
3. **Custom WorkManager plugins** - May not be compatible
4. **Third-party integrations** - Depends on library support

For these cases, the tool generates warnings and manual review sections in the migration guide.

---

## Feedback

Have suggestions for improving the migration tool?
- 🐛 [Report Issues](https://github.com/brewkits/native_workmanager/issues)
- 💡 [Feature Requests](https://github.com/brewkits/native_workmanager/discussions)

---

**Last Updated:** 2026-02-07
**Version:** 1.0.0
