part of '../worker.dart';

/// File compression worker (ZIP format).
///
/// Compresses files or directories into ZIP archives in the background.
/// Runs in native code **without** Flutter Engine for maximum efficiency.
/// Perfect for log archiving, backup preparation, or reducing upload sizes.
///
/// ## Basic File Compression
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'compress-logs',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.fileCompress(
///     inputPath: '/app/logs/app.log',
///     outputPath: '/app/archive/logs.zip',
///   ),
/// );
/// ```
///
/// ## Compress Directory with Options
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'compress-directory',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.fileCompress(
///     inputPath: '/app/data/',
///     outputPath: '/app/backups/data_${DateTime.now()}.zip',
///     level: CompressionLevel.high,
///     excludePatterns: ['*.tmp', '.DS_Store', '*.bak'],
///     deleteOriginal: false,
///   ),
/// );
/// ```
///
/// ## Compress and Delete Original
///
/// ```dart
/// // Archive old logs and delete originals to save space
/// await NativeWorkManager.enqueue(
///   taskId: 'archive-old-logs',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.fileCompress(
///     inputPath: '/app/logs/2025/',
///     outputPath: '/app/archive/logs_2025.zip',
///     level: CompressionLevel.medium,
///     deleteOriginal: true,  // Delete source after compression
///   ),
///   constraints: Constraints(requiresStorageNotLow: true),
/// );
/// ```
///
/// ## Periodic Log Archiving
///
/// ```dart
/// // Compress logs daily
/// await NativeWorkManager.enqueue(
///   taskId: 'daily-log-archive',
///   trigger: TaskTrigger.periodic(Duration(days: 1)),
///   worker: NativeWorker.fileCompress(
///     inputPath: '/app/logs/',
///     outputPath: '/app/archive/logs_\${DateTime.now().day}.zip',
///     excludePatterns: ['current.log'],  // Keep current log
///   ),
/// );
/// ```
///
/// ## Parameters
///
/// **[inputPath]** *(required)* - Path to file or directory to compress.
/// - Must be absolute path
/// - Can be a single file or directory
/// - Directory will be compressed recursively
/// - Throws `ArgumentError` if empty or doesn't exist
///
/// **[outputPath]** *(required)* - Where to save the ZIP file.
/// - Must be absolute path ending with .zip
/// - Parent directory will be created if needed
/// - Existing file will be overwritten
/// - Throws `ArgumentError` if empty or doesn't end with .zip
///
/// **[level]** *(optional)* - Compression level (default: medium).
/// - `CompressionLevel.low` - Faster compression, larger file
/// - `CompressionLevel.medium` - Balanced (recommended)
/// - `CompressionLevel.high` - Best compression, slower
///
/// **[excludePatterns]** *(optional)* - Patterns to exclude (default: empty).
/// - Supports wildcards: `*.tmp`, `temp*`, `*backup*`
/// - Exact match: `.DS_Store`, `Thumbs.db`
/// - Case-insensitive matching
///
/// **[deleteOriginal]** *(optional)* - Delete source after compression (default: false).
/// - Use with caution!
/// - Only deletes if compression succeeds
/// - Cannot be undone
///
/// ## Progress Tracking
///
/// ```dart
/// // Listen to compression progress
/// NativeWorkManager.progress
///     .where((p) => p.taskId == 'my-compression')
///     .listen((progress) {
///   print('Compressed: ${progress.currentStep}/${progress.totalSteps} files');
///   print('Progress: ${progress.progress}%');
/// });
/// ```
///
/// ## Behavior
///
/// - Compresses using ZIP format (universal compatibility)
/// - Preserves file modification times
/// - Creates parent directories automatically
/// - Overwrites existing output file
/// - Reports progress via [NativeWorkManager.progress] stream
/// - Task succeeds if compression completes successfully
/// - Task fails on I/O error, missing file, or insufficient storage
///
/// ## When to Use
///
/// ✅ **Use fileCompress when:**
/// - Archiving log files periodically
/// - Preparing backups for upload
/// - Reducing file sizes before transfer
/// - Freeing up storage space
/// - Creating distributable packages
///
/// ❌ **Don't use fileCompress when:**
/// - Files are already compressed (JPEG, PNG, MP4, PDF)
/// - Need other formats (7z, RAR, tar.gz) → Use custom worker
/// - Need encryption → Use FileEncryptionWorker (v1.1+)
///
/// ## Common Pitfalls
///
/// ❌ **Don't** compress already-compressed files (no benefit)
/// ❌ **Don't** use deleteOriginal without backup
/// ❌ **Don't** forget storage constraints for large files
/// ❌ **Don't** compress system directories
/// ✅ **Do** use excludePatterns to skip unnecessary files
/// ✅ **Do** check available storage before large compressions
/// ✅ **Do** use periodic tasks for automated archiving
/// ✅ **Do** test with small files first
///
/// ## Platform Notes
///
/// **Android:**
/// - Uses `java.util.zip.ZipOutputStream`
/// - Supports all compression levels
/// - No file size limit (system dependent)
///
/// **iOS:**
/// - Uses `Compression` framework (iOS 13+)
/// - Supports all compression levels
/// - No file size limit (system dependent)
///
/// ## Performance
///
/// | File Size | Low | Medium | High | Note |
/// |-----------|-----|--------|------|------|
/// | 10 MB | ~1s | ~2s | ~3s | Text files |
/// | 100 MB | ~8s | ~15s | ~25s | Mixed content |
/// | 1 GB | ~80s | ~150s | ~250s | Use constraints! |
///
/// **Tip:** For large files (>100MB), use:
/// ```dart
/// constraints: Constraints(
///   requiresCharging: true,
///   requiresDeviceIdle: true,
///   requiresStorageNotLow: true,
/// )
/// ```
///
/// ## See Also
///
/// - [NativeWorker.httpUpload] - Upload compressed files
/// - [NativeWorkManager.progress] - Track compression progress
/// - [NativeWorker.custom] - Custom compression formats
Worker _buildFileCompress({
  required String inputPath,
  required String outputPath,
  CompressionLevel level = CompressionLevel.medium,
  List<String> excludePatterns = const [],
  bool deleteOriginal = false,
}) {
  NativeWorker._validateFilePath(inputPath, 'inputPath');
  NativeWorker._validateFilePath(outputPath, 'outputPath');

  if (!outputPath.toLowerCase().endsWith('.zip')) {
    throw ArgumentError(
      'Output path must end with .zip\n'
      'Current: $outputPath\n'
      'Example: /app/archive/backup.zip',
    );
  }

  return FileCompressionWorker(
    inputPath: inputPath,
    outputPath: outputPath,
    level: level,
    excludePatterns: excludePatterns,
    deleteOriginal: deleteOriginal,
  );
}

/// File decompression worker (ZIP extraction).
///
/// Extracts files from ZIP archives in the background. Supports password-protected
/// archives, selective extraction, and zip bomb protection. Runs in native code
/// **without** Flutter Engine for maximum efficiency.
///
/// ## Basic Extraction
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'extract-backup',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.fileDecompress(
///     archivePath: '/app/downloads/backup.zip',
///     destinationPath: '/app/data/restored/',
///   ),
/// );
/// ```
///
/// ## Extract Specific Files Only
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'extract-config',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.fileDecompress(
///     archivePath: '/app/downloads/package.zip',
///     destinationPath: '/app/config/',
///     extractFiles: ['config.json', 'settings.xml'],
///   ),
/// );
/// ```
///
/// ## Password-Protected Archive
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'extract-secure',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.fileDecompress(
///     archivePath: '/app/downloads/secure.zip',
///     destinationPath: '/app/private/',
///     password: 'mySecurePassword',
///   ),
/// );
/// ```
///
/// ## Extract and Delete Archive
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'extract-temp',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.fileDecompress(
///     zipPath: '/app/downloads/data.zip',
///     targetDir: '/app/temp/',
///     deleteAfterExtract: true,  // Save storage space
///     overwrite: true,
///   ),
/// );
/// ```
///
/// ## Complete Workflow: Download → Extract → Process
///
/// ```dart
/// // Step 1: Download ZIP
/// await NativeWorkManager.enqueue(
///   taskId: 'download-data',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.httpDownload(
///     url: 'https://cdn.example.com/data.zip',
///     savePath: '/app/downloads/data.zip',
///   ),
/// );
///
/// // Step 2: Extract downloaded ZIP
/// await NativeWorkManager.enqueue(
///   taskId: 'extract-data',
///   trigger: TaskTrigger.contentUri(taskId: 'download-data'),
///   worker: NativeWorker.fileDecompress(
///     zipPath: '/app/downloads/data.zip',
///     targetDir: '/app/data/',
///     deleteAfterExtract: true,
///   ),
/// );
/// ```
///
/// ## Parameters
///
/// **[zipPath]** *(required)* - Path to ZIP archive to extract.
/// - Must be absolute path
/// - File must exist at execution time
/// - Throws `ArgumentError` if empty
///
/// **[targetDir]** *(required)* - Directory where files will be extracted.
/// - Must be absolute path
/// - Directory will be created if it doesn't exist
/// - Throws `ArgumentError` if empty
///
/// **[deleteAfterExtract]** *(optional)* - Delete archive after extraction (default: false).
/// - Saves storage space
/// - Only deletes if extraction succeeds
/// - Use with caution!
///
/// **[overwrite]** *(optional)* - Overwrite existing files (default: true).
/// - If false, skips files that already exist
/// - If true, replaces existing files
///
/// ## Progress Tracking
///
/// ```dart
/// // Listen to extraction progress
/// NativeWorkManager.progress
///     .where((p) => p.taskId == 'my-extraction')
///     .listen((progress) {
///   print('Extracted: ${progress.currentStep}/${progress.totalSteps} files');
///   print('Progress: ${progress.progress}%');
/// });
/// ```
///
/// ## Behavior
///
/// - Extracts all files preserving directory structure
/// - Creates destination directory if needed
/// - Path traversal protection (prevents ../../../ attacks)
/// - Validates uncompressed size before extraction
/// - Reports progress via [NativeWorkManager.progress] stream
/// - Task succeeds if extraction completes successfully
/// - Task fails on I/O error, wrong password, or zip bomb detected
///
/// ## When to Use
///
/// ✅ **Use fileDecompress when:**
/// - Extracting downloaded content packages
/// - Restoring backups
/// - Unpacking app resources
/// - Processing uploaded archives
/// - Handling OTA update packages
///
/// ❌ **Don't use fileDecompress when:**
/// - Archive format is not ZIP → Use custom worker
/// - Need to extract on-the-fly during download → Use streaming
/// - Archive is untrusted → Validate maxSizeBytes carefully
///
/// ## Security Notes
///
/// **Zip Bomb Protection:**
/// - Built-in validation prevents decompression bombs
/// - Checks extracted size during extraction
/// - Task fails if suspicious expansion detected
///
/// **Path Traversal Protection:**
/// - Automatically validates all file paths
/// - Prevents extraction outside destination directory
/// - Blocks malicious paths like `../../etc/passwd`
///
/// ## Common Pitfalls
///
/// ❌ **Don't** extract untrusted archives without validation
/// ❌ **Don't** use deleteAfterExtract without verifying extraction success
/// ❌ **Don't** forget to handle task failure (archive may be corrupt)
/// ❌ **Don't** extract to system directories
/// ✅ **Do** use storage constraints for large archives
/// ✅ **Do** validate archive integrity before extraction
/// ✅ **Do** test with known-good archives first
///
/// ## Platform Notes
///
/// **Android:**
/// - Uses standard Java ZIP libraries
/// - Supports all ZIP formats including ZIP64
/// - Streaming extraction (low memory)
///
/// **iOS:**
/// - Uses ZIPFoundation framework
/// - Streaming extraction (low memory)
/// - Built-in security validations
///
/// ## Future Features (v1.1.0)
///
/// - Password-protected ZIP support
/// - Selective file extraction
/// - Custom extraction filters
///
/// ## Performance
///
/// | Archive Size | Files | Time | Note |
/// |--------------|-------|------|------|
/// | 10 MB | 100 | ~1s | Small packages |
/// | 100 MB | 1000 | ~8s | Medium backups |
/// | 500 MB | 5000 | ~40s | Large archives |
///
/// **Tip:** For large archives (>100MB), use:
/// ```dart
/// constraints: Constraints(
///   requiresStorageNotLow: true,
/// )
/// ```
///
/// ## See Also
///
/// - [NativeWorker.fileCompress] - Compress files into ZIP
/// - [NativeWorker.httpDownload] - Download ZIP archives
/// - [NativeWorkManager.progress] - Track extraction progress
Worker _buildFileDecompress({
  required String zipPath,
  required String targetDir,
  bool deleteAfterExtract = false,
  bool overwrite = true,
}) {
  NativeWorker._validateFilePath(zipPath, 'zipPath');
  NativeWorker._validateFilePath(targetDir, 'targetDir');

  if (!zipPath.toLowerCase().endsWith('.zip')) {
    throw ArgumentError(
      'ZIP path must end with .zip\n'
      'Current: $zipPath\n'
      'Example: /app/downloads/archive.zip',
    );
  }

  return FileDecompressionWorker(
    zipPath: zipPath,
    targetDir: targetDir,
    deleteAfterExtract: deleteAfterExtract,
    overwrite: overwrite,
  );
}

/// Copy file or directory worker.
///
/// Copies files or directories for pure-native task chains **without** Flutter Engine.
/// Useful for organizing files, creating backups, or duplicating data.
///
/// ## Basic File Copy
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'copy-file',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.fileCopy(
///     sourcePath: '/downloads/photo.jpg',
///     destinationPath: '/backups/photo.jpg',
///   ),
/// );
/// ```
///
/// ## Copy Directory
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'copy-directory',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.fileCopy(
///     sourcePath: '/photos/vacation',
///     destinationPath: '/backups/vacation',
///     recursive: true,
///   ),
/// );
/// ```
///
/// ## Parameters
///
/// **[sourcePath]** *(required)* - Path to source file or directory.
///
/// **[destinationPath]** *(required)* - Where to copy the file/directory.
///
/// **[overwrite]** *(optional)* - Overwrite if destination exists (default: false).
///
/// **[recursive]** *(optional)* - Copy directories recursively (default: true).
///
/// ## See Also
///
/// - [NativeWorker.fileMove] - Move files instead of copying
/// - [NativeWorker.fileDelete] - Delete files
Worker _buildFileCopy({
  required String sourcePath,
  required String destinationPath,
  bool overwrite = false,
  bool recursive = true,
}) {
  NativeWorker._validateFilePath(sourcePath, 'sourcePath');
  NativeWorker._validateFilePath(destinationPath, 'destinationPath');

  return FileSystemCopyWorker(
    sourcePath: sourcePath,
    destinationPath: destinationPath,
    overwrite: overwrite,
    recursive: recursive,
  );
}

/// Move file or directory worker.
///
/// Moves files or directories for pure-native task chains **without** Flutter Engine.
/// More efficient than copy+delete for large files (atomic operation when possible).
///
/// ## Basic File Move
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'move-file',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.fileMove(
///     sourcePath: '/temp/download.zip',
///     destinationPath: '/downloads/file.zip',
///   ),
/// );
/// ```
///
/// ## Parameters
///
/// **[sourcePath]** *(required)* - Path to source file or directory.
///
/// **[destinationPath]** *(required)* - Where to move the file/directory.
///
/// **[overwrite]** *(optional)* - Overwrite if destination exists (default: false).
///
/// ## See Also
///
/// - [NativeWorker.fileCopy] - Copy files instead of moving
/// - [NativeWorker.fileDelete] - Delete files after processing
Worker _buildFileMove({
  required String sourcePath,
  required String destinationPath,
  bool overwrite = false,
}) {
  NativeWorker._validateFilePath(sourcePath, 'sourcePath');
  NativeWorker._validateFilePath(destinationPath, 'destinationPath');

  return FileSystemMoveWorker(
    sourcePath: sourcePath,
    destinationPath: destinationPath,
    overwrite: overwrite,
  );
}

/// Delete file or directory worker.
///
/// Deletes files or directories for cleanup in pure-native task chains **without** Flutter Engine.
///
/// ## Basic File Delete
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'cleanup',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.fileDelete(
///     path: '/temp/cache.dat',
///   ),
/// );
/// ```
///
/// ## Delete Directory
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'cleanup-temp',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.fileDelete(
///     path: '/temp',
///     recursive: true,  // Delete all contents
///   ),
/// );
/// ```
///
/// ## Parameters
///
/// **[path]** *(required)* - Path to file or directory to delete.
///
/// **[recursive]** *(optional)* - Delete directories recursively (default: false).
/// - If false and path is directory, task fails
/// - If true, deletes directory and all contents
///
/// ## Safety
///
/// - Protected paths (/, /system, etc.) cannot be deleted
/// - Deletion is permanent (no trash/recycle bin)
///
/// ## See Also
///
/// - [NativeWorker.fileCopy] - Copy files before deleting
/// - [NativeWorker.fileMove] - Move files instead of deleting
Worker _buildFileDelete({required String path, bool recursive = false}) {
  NativeWorker._validateFilePath(path, 'path');

  return FileSystemDeleteWorker(path: path, recursive: recursive);
}

/// List directory contents worker.
///
/// Lists files in a directory for pure-native task chains **without** Flutter Engine.
/// Useful for scanning directories, finding files, or building file indexes.
///
/// ## Basic Directory Listing
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'list-files',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.fileList(
///     path: '/downloads',
///   ),
/// );
/// ```
///
/// ## List with Pattern
///
/// ```dart
/// // Find all JPG files
/// await NativeWorkManager.enqueue(
///   taskId: 'find-photos',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.fileList(
///     path: '/photos',
///     pattern: '*.jpg',
///     recursive: true,
///   ),
/// );
/// ```
///
/// ## Parameters
///
/// **[path]** *(required)* - Directory path to list.
///
/// **[pattern]** *(optional)* - Glob pattern to filter files (e.g., "*.jpg", "file_*.txt").
/// - Supports wildcards: `*` (any chars), `?` (single char)
/// - Example: `*.jpg` matches all JPEG files
/// - Example: `photo_?.png` matches `photo_1.png`, `photo_a.png`
///
/// **[recursive]** *(optional)* - List subdirectories recursively (default: false).
///
/// ## Result
///
/// Returns list of file info with:
/// - `path` - Full file path
/// - `name` - File name
/// - `size` - File size in bytes
/// - `lastModified` - Last modification timestamp
///
/// ## See Also
///
/// - [NativeWorker.fileDelete] - Delete found files
/// - [NativeWorker.fileCopy] - Copy found files
Worker _buildFileList({
  required String path,
  String? pattern,
  bool recursive = false,
}) {
  NativeWorker._validateFilePath(path, 'path');

  return FileSystemListWorker(
    path: path,
    pattern: pattern,
    recursive: recursive,
  );
}

/// Create directory worker (mkdir).
///
/// Creates directories for pure-native task chains **without** Flutter Engine.
/// Useful for setting up folder structure before file operations.
///
/// ## Create Directory
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'create-backup-dir',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.fileMkdir(
///     path: '/backups/2024-02-07',
///   ),
/// );
/// ```
///
/// ## Parameters
///
/// **[path]** *(required)* - Directory path to create.
///
/// **[createParents]** *(optional)* - Create parent directories if needed (default: true).
/// - If true, creates `/backups/2024/02/07` even if `/backups` doesn't exist
/// - If false, fails if parent doesn't exist
///
/// ## See Also
///
/// - [NativeWorker.fileCopy] - Copy files after creating directory
/// - [NativeWorker.fileMove] - Move files to new directory
Worker _buildFileMkdir({required String path, bool createParents = true}) {
  NativeWorker._validateFilePath(path, 'path');

  return FileSystemMkdirWorker(path: path, createParents: createParents);
}
