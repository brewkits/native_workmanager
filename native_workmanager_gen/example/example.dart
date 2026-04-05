// ignore_for_file: avoid_print

/// Example showing how to use native_workmanager_gen.
///
/// 1. Annotate top-level background functions with @WorkerCallback.
/// 2. Run `dart run build_runner build` to generate workers.g.dart.
/// 3. Use the generated WorkerIds constants and generatedWorkerRegistry.
library;

// In a real project you would add:
//   part 'example.g.dart';
// and run build_runner to generate the .g.dart file.
//
// For illustration purposes the generated output is shown below as comments.

import 'package:native_workmanager/native_workmanager.dart';

// --- Annotated worker functions ---

@WorkerCallback('sync_contacts')
Future<bool> syncContacts(String? inputJson) async {
  print('Syncing contacts: $inputJson');
  return true;
}

@WorkerCallback('backup_photos')
Future<bool> backupPhotos(String? inputJson) async {
  print('Backing up photos: $inputJson');
  return true;
}

// --- What build_runner generates (example.g.dart) ---
//
// abstract final class WorkerIds {
//   static const String syncContacts = 'sync_contacts';
//   static const String backupPhotos = 'backup_photos';
// }
//
// final Map<String, DartWorkerCallback> generatedWorkerRegistry = {
//   'sync_contacts': syncContacts,
//   'backup_photos': backupPhotos,
// };

// --- Usage in main ---

Future<void> main() async {
  // Initialize with the generated registry.
  // await NativeWorkManager.initialize(
  //   dartWorkers: generatedWorkerRegistry,
  // );

  // Schedule a task using a type-safe ID.
  // await NativeWorkManager.enqueue(
  //   taskId: 'task-001',
  //   trigger: TaskTrigger.oneTime(),
  //   worker: DartWorker(callbackId: WorkerIds.syncContacts),
  // );

  print('native_workmanager_gen example — run build_runner to generate code.');
}
