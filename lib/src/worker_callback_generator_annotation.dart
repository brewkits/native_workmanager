/// Annotation for the native_workmanager_gen code generator.
///
/// Applied to a top-level function to mark it as a background worker callback.
class WorkerCallback {
  /// The unique ID for this worker callback.
  final String id;

  /// Creates a [WorkerCallback] with the given [id].
  const WorkerCallback(this.id);
}
