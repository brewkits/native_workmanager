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

// --- Step 1: Annotate your worker functions (in your app's lib/workers.dart) ---
//
// part 'workers.g.dart';
//
// @WorkerCallback('sync_contacts')
// Future<bool> syncContacts(String? inputJson) async {
//   // background work
//   return true;
// }
//
// @WorkerCallback('backup_photos')
// Future<bool> backupPhotos(String? inputJson) async {
//   // background work
//   return true;
// }

// --- Step 2: Run code generation ---
//
//   dart run build_runner build --delete-conflicting-outputs

// --- Step 3: build_runner generates workers.g.dart ---
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

// --- Step 4: Use in your app ---
//
// await NativeWorkManager.initialize(
//   dartWorkers: generatedWorkerRegistry,
// );
//
// await NativeWorkManager.enqueue(
//   taskId: 'task-001',
//   trigger: TaskTrigger.oneTime(),
//   worker: DartWorker(callbackId: WorkerIds.syncContacts),
// );

Future<void> main() async {
  print('native_workmanager_gen — run build_runner to generate type-safe worker IDs.');
}
