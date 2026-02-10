import 'package:flutter/foundation.dart';
import '../worker.dart';

/// File system operations.
enum FileOperation {
  copy('copy'),
  move('move'),
  delete('delete'),
  exists('exists'),
  mkdir('mkdir'),
  list('list');

  const FileOperation(this.value);
  final String value;
}

/// File system worker configuration for copy operation.
@immutable
final class FileSystemCopyWorker extends Worker {
  const FileSystemCopyWorker({
    required this.sourcePath,
    required this.destinationPath,
    this.overwrite = false,
    this.recursive = true,
  });

  final String sourcePath;
  final String destinationPath;
  final bool overwrite;
  final bool recursive;

  @override
  String get workerClassName => 'FileSystemWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'fileSystem',
        'operation': 'copy',
        'sourcePath': sourcePath,
        'destinationPath': destinationPath,
        'overwrite': overwrite,
        'recursive': recursive,
      };
}

/// File system worker configuration for move operation.
@immutable
final class FileSystemMoveWorker extends Worker {
  const FileSystemMoveWorker({
    required this.sourcePath,
    required this.destinationPath,
    this.overwrite = false,
  });

  final String sourcePath;
  final String destinationPath;
  final bool overwrite;

  @override
  String get workerClassName => 'FileSystemWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'fileSystem',
        'operation': 'move',
        'sourcePath': sourcePath,
        'destinationPath': destinationPath,
        'overwrite': overwrite,
      };
}

/// File system worker configuration for delete operation.
@immutable
final class FileSystemDeleteWorker extends Worker {
  const FileSystemDeleteWorker({
    required this.path,
    this.recursive = false,
  });

  final String path;
  final bool recursive;

  @override
  String get workerClassName => 'FileSystemWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'fileSystem',
        'operation': 'delete',
        'path': path,
        'recursive': recursive,
      };
}

/// File system worker configuration for list operation.
@immutable
final class FileSystemListWorker extends Worker {
  const FileSystemListWorker({
    required this.path,
    this.pattern,
    this.recursive = false,
  });

  final String path;
  final String? pattern;
  final bool recursive;

  @override
  String get workerClassName => 'FileSystemWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'fileSystem',
        'operation': 'list',
        'path': path,
        if (pattern != null) 'pattern': pattern,
        'recursive': recursive,
      };
}

/// File system worker configuration for mkdir operation.
@immutable
final class FileSystemMkdirWorker extends Worker {
  const FileSystemMkdirWorker({
    required this.path,
    this.createParents = true,
  });

  final String path;
  final bool createParents;

  @override
  String get workerClassName => 'FileSystemWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'fileSystem',
        'operation': 'mkdir',
        'path': path,
        'createParents': createParents,
      };
}
