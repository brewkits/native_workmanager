# FileSystemWorker Documentation

## Overview

The `FileSystemWorker` performs file system operations (copy, move, delete, list, mkdir) in the background **without** starting the Flutter Engine. This enables pure-native task chains for file organization, cleanup, and preprocessing.

**Key Benefits:**
- **Pure-Native Chains:** Build complete workflows without Dart callbacks
- **Battery Efficient:** No Flutter Engine overhead (~50MB saved)
- **Background Execution:** Organize files when app is closed
- **Atomic Operations:** Safe file moves and copies
- **Security:** Built-in path traversal protection

---

## Operations

### 1. Copy Files/Directories

```dart
await NativeWorkManager.enqueue(
  taskId: 'copy-file',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.fileCopy(
    sourcePath: '/downloads/photo.jpg',
    destinationPath: '/backups/photo.jpg',
  ),
);
```

### 2. Move Files/Directories

```dart
await NativeWorkManager.enqueue(
  taskId: 'move-file',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.fileMove(
    sourcePath: '/temp/download.zip',
    destinationPath: '/downloads/file.zip',
  ),
);
```

### 3. Delete Files/Directories

```dart
await NativeWorkManager.enqueue(
  taskId: 'cleanup',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.fileDelete(
    path: '/temp/cache',
    recursive: true,
  ),
);
```

### 4. List Directory Contents

```dart
await NativeWorkManager.enqueue(
  taskId: 'list-files',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.fileList(
    path: '/photos',
    pattern: '*.jpg',
    recursive: true,
  ),
);
```

### 5. Create Directories

```dart
await NativeWorkManager.enqueue(
  taskId: 'create-dir',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.fileMkdir(
    path: '/backups/2024-02-07',
    createParents: true,
  ),
);
```

---

## Common Use Cases

### 1. Pure-Native Task Chain

Complete workflow without Dart: Download → Move → Unzip → Process

```dart
// Step 1: Download file
await NativeWorkManager.enqueue(
  taskId: 'download',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.httpDownload(
    url: 'https://cdn.example.com/update.zip',
    savePath: '/temp/update.zip',
  ),
);

// Step 2: Move to final location (native, no Dart callback)
await NativeWorkManager.enqueue(
  taskId: 'move',
  trigger: TaskTrigger.contentUri(taskId: 'download'),
  worker: NativeWorker.fileMove(
    sourcePath: '/temp/update.zip',
    destinationPath: '/downloads/update.zip',
  ),
);

// Step 3: Extract (native)
await NativeWorkManager.enqueue(
  taskId: 'extract',
  trigger: TaskTrigger.contentUri(taskId: 'move'),
  worker: NativeWorker.fileDecompress(
    zipPath: '/downloads/update.zip',
    targetDir: '/app/extracted/',
  ),
);

// Step 4: Process files (native)
await NativeWorkManager.enqueue(
  taskId: 'process',
  trigger: TaskTrigger.contentUri(taskId: 'extract'),
  worker: NativeWorker.imageProcess(
    inputPath: '/app/extracted/photo.jpg',
    outputPath: '/app/processed/photo_1080p.jpg',
    maxWidth: 1920,
    maxHeight: 1080,
  ),
);
```

### 2. Backup Organization

Organize backups into dated folders:

```dart
final date = DateTime.now().toIso8601String().split('T')[0];

// Step 1: Create backup directory
await NativeWorkManager.enqueue(
  taskId: 'create-backup-dir',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.fileMkdir(
    path: '/backups/$date',
  ),
);

// Step 2: Copy files to backup
await NativeWorkManager.enqueue(
  taskId: 'backup-data',
  trigger: TaskTrigger.contentUri(taskId: 'create-backup-dir'),
  worker: NativeWorker.fileCopy(
    sourcePath: '/data/user_data.db',
    destinationPath: '/backups/$date/user_data.db',
  ),
);

// Step 3: Compress backup
await NativeWorkManager.enqueue(
  taskId: 'compress-backup',
  trigger: TaskTrigger.contentUri(taskId: 'backup-data'),
  worker: NativeWorker.fileCompress(
    sourcePath: '/backups/$date',
    zipPath: '/backups/$date.zip',
    deleteOriginal: true,
  ),
);
```

### 3. Cleanup Old Files

Find and delete old cache files:

```dart
// Step 1: List old files
await NativeWorkManager.enqueue(
  taskId: 'list-cache',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.fileList(
    path: '/cache',
    pattern: '*.tmp',
    recursive: true,
  ),
);

// Step 2: Delete old files (check results, then delete)
NativeWorkManager.results.listen((result) async {
  if (result.taskId == 'list-cache' && result.success) {
    final files = result.data?['files'] as List?;
    final now = DateTime.now();

    for (final fileInfo in files ?? []) {
      final path = fileInfo['path'] as String;
      final lastModified = DateTime.fromMillisecondsSinceEpoch(
        (fileInfo['lastModified'] as num).toInt() * 1000,
      );

      // Delete files older than 7 days
      if (now.difference(lastModified).inDays > 7) {
        await NativeWorkManager.enqueue(
          taskId: 'delete-${path.hashCode}',
          trigger: TaskTrigger.oneTime(),
          worker: NativeWorker.fileDelete(path: path),
        );
      }
    }
  }
});
```

### 4. Duplicate File for Processing

Copy file before processing (preserve original):

```dart
// Step 1: Copy to temp location
await NativeWorkManager.enqueue(
  taskId: 'copy-photo',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.fileCopy(
    sourcePath: '/DCIM/IMG_4032.jpg',
    destinationPath: '/temp/photo_copy.jpg',
  ),
);

// Step 2: Process copy (native)
await NativeWorkManager.enqueue(
  taskId: 'process-photo',
  trigger: TaskTrigger.contentUri(taskId: 'copy-photo'),
  worker: NativeWorker.imageProcess(
    inputPath: '/temp/photo_copy.jpg',
    outputPath: '/processed/photo_1080p.jpg',
    maxWidth: 1920,
    maxHeight: 1080,
    deleteOriginal: true,  // Delete copy after processing
  ),
);
```

---

## Result Data

### Copy Operation

```dart
{
  "operation": "copy",
  "sourcePath": "/downloads/photo.jpg",
  "destinationPath": "/backups/photo.jpg",
  "fileCount": 1,
  "totalSize": 2097152,  // bytes
  "files": [
    "/backups/photo.jpg"
  ]
}
```

### Move Operation

```dart
{
  "operation": "move",
  "sourcePath": "/temp/file.zip",
  "destinationPath": "/downloads/file.zip",
  "fileCount": 1
}
```

### Delete Operation

```dart
{
  "operation": "delete",
  "path": "/temp/cache",
  "fileCount": 42  // Number of files deleted
}
```

### List Operation

```dart
{
  "operation": "list",
  "path": "/photos",
  "pattern": "*.jpg",
  "recursive": true,
  "fileCount": 15,
  "totalSize": 52428800,  // bytes
  "files": [
    {
      "path": "/photos/IMG_4032.jpg",
      "name": "IMG_4032.jpg",
      "size": 3145728,
      "lastModified": 1707264000000,
      "isDirectory": false
    },
    // ... more files
  ]
}
```

### Mkdir Operation

```dart
{
  "operation": "mkdir",
  "path": "/backups/2024-02-07",
  "created": true  // false if directory already existed
}
```

---

## Parameters

### Copy Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `sourcePath` | String | required | Source file or directory path |
| `destinationPath` | String | required | Destination path |
| `overwrite` | bool | `false` | Overwrite existing files |
| `recursive` | bool | `true` | Copy directories recursively |

### Move Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `sourcePath` | String | required | Source file or directory path |
| `destinationPath` | String | required | Destination path |
| `overwrite` | bool | `false` | Overwrite existing files |

### Delete Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `path` | String | required | File or directory to delete |
| `recursive` | bool | `false` | Delete directories recursively |

### List Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `path` | String | required | Directory to list |
| `pattern` | String? | `null` | Glob pattern (e.g., "*.jpg") |
| `recursive` | bool | `false` | List subdirectories |

### Mkdir Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `path` | String | required | Directory path to create |
| `createParents` | bool | `true` | Create parent directories |

---

## Security Features

### Path Traversal Protection

Prevents operations from escaping intended directory:

```
❌ Blocked: ../../etc/passwd
❌ Blocked: /system/app/
✅ Allowed: /data/user/0/com.example.app/...
✅ Allowed: subdirectory/file.txt
```

### Protected Paths

Cannot delete critical system paths:

**Android:**
```
❌ Cannot delete: /, /system, /data, /storage
```

**iOS:**
```
❌ Cannot delete: /, /System, /Library, /usr, /var
```

### Sandbox Enforcement

All operations must be within app sandbox:

```
✅ Allowed: App's document directory
✅ Allowed: App's cache directory
❌ Blocked: Other apps' directories
❌ Blocked: System directories
```

---

## Pattern Matching

The `pattern` parameter supports glob-style wildcards:

### Wildcard Syntax

| Pattern | Matches | Example |
|---------|---------|---------|
| `*` | Any characters | `*.jpg` matches all JPEG files |
| `?` | Single character | `photo_?.jpg` matches `photo_1.jpg` |
| `**` | Not supported | Use `recursive: true` instead |

### Pattern Examples

```dart
// All JPEG files
pattern: '*.jpg'

// Files starting with 'photo_'
pattern: 'photo_*'

// Files ending with '_backup'
pattern: '*_backup.*'

// Single-character variation
pattern: 'file_?.txt'  // Matches file_1.txt, file_a.txt
```

---

## Performance Tips

✅ **Do:**
- Use `fileMove` instead of copy+delete (more efficient)
- Use `deleteOriginal` in processing workers (avoid extra delete tasks)
- Use `createParents: true` to avoid mkdir failures
- Use `pattern` to filter files before processing

❌ **Don't:**
- Copy very large directories without monitoring progress
- Delete root directories accidentally (`recursive: true` is dangerous)
- Move files across different filesystems (falls back to copy+delete)

---

## Platform Differences

### Android

**Implementation:** Standard Java `File` APIs

**Features:**
- ✅ Atomic move when same filesystem
- ✅ Progress reporting for large copies
- ✅ All operations supported

### iOS

**Implementation:** `FileManager` APIs

**Features:**
- ✅ Atomic move when same filesystem
- ✅ Progress reporting for large copies
- ✅ File permission preservation
- ✅ All operations supported

---

## Error Handling

### Common Errors

#### "Source not found"
```dart
if (!File(sourcePath).existsSync()) {
  print('Source not found: $sourcePath');
  return;
}
```

#### "Destination already exists"
```dart
worker: NativeWorker.fileCopy(
  sourcePath: source,
  destinationPath: dest,
  overwrite: true,  // Allow overwriting
)
```

#### "Path traversal detected"
```dart
// Automatically blocked by security validation
// This error indicates malicious or incorrect path
```

---

## See Also

- **[FileCompressionWorker](./FILE_COMPRESSION.md)** - Compress files after copying
- **[FileDecompressionWorker](./FILE_DECOMPRESSION.md)** - Extract before organizing
- **[Task Chains Guide](../TASK_CHAINS.md)** - Build pure-native workflows

---

## Changelog

### v1.0.0 (2026-02-07)
- ✅ Copy files and directories
- ✅ Move files and directories
- ✅ Delete files and directories
- ✅ List directory contents with pattern matching
- ✅ Create directories
- ✅ Security validations (path traversal, protected paths)
- ✅ Atomic operations when possible

### Planned for v1.1.0
- Batch operations (multiple operations in one task)
- File attribute modification (permissions, dates)
- Symbolic link support
- Advanced pattern matching (regex)
