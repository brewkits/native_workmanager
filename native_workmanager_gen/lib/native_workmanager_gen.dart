/// Code generator for native_workmanager.
///
/// Reads [@WorkerCallback] annotations and generates:
/// - A `WorkerIds` abstract final class with `static const String` fields
///   (one per annotated function).
/// - A `generatedWorkerRegistry` map for use with
///   `NativeWorkManager.initialize(dartWorkers: ...)`.
///
/// ## Setup
///
/// Add to `pubspec.yaml`:
/// ```yaml
/// dev_dependencies:
///   native_workmanager_gen: ^1.0.4
///   build_runner: ^2.4.0
/// ```
///
/// ## Usage
///
/// ```dart
/// // lib/workers.dart
/// import 'package:native_workmanager/native_workmanager.dart';
///
/// part 'workers.g.dart';
///
/// @WorkerCallback('sync_contacts')
/// Future<bool> syncContacts(Map<String, dynamic>? input) async {
///   // your logic
///   return true;
/// }
///
/// @WorkerCallback('backup_photos')
/// Future<bool> backupPhotos(Map<String, dynamic>? input) async {
///   // your logic
///   return true;
/// }
/// ```
///
/// Run:
/// ```sh
/// dart run build_runner build --delete-conflicting-outputs
/// ```
///
/// This produces `lib/workers.g.dart`:
/// ```dart
/// abstract final class WorkerIds {
///   static const String syncContacts = 'sync_contacts';
///   static const String backupPhotos = 'backup_photos';
/// }
///
/// final Map<String, DartWorkerCallback> generatedWorkerRegistry = {
///   'sync_contacts': syncContacts,
///   'backup_photos': backupPhotos,
/// };
/// ```
///
/// Initialize with the registry:
/// ```dart
/// await NativeWorkManager.initialize(
///   dartWorkers: generatedWorkerRegistry,
/// );
/// ```
///
/// Schedule with a type-safe ID:
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'task-001',
///   trigger: TaskTrigger.oneTime(),
///   worker: DartWorker(callbackId: WorkerIds.syncContacts),
/// );
/// ```
library;

export 'src/worker_callback_generator.dart' show WorkerCallbackGenerator;
