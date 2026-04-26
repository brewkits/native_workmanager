/// Annotation for the native_workmanager_gen code generator.
///
/// Applied to a top-level function to mark it as a background worker callback.
class WorkerCallback {
  /// The unique ID for this worker callback.
  final String id;

  /// Optional: The type of the input parameter for this worker.
  ///
  /// If provided, the generator will attempt to create a type-safe enqueue
  /// wrapper for this worker. The type should have a `toMap()` method or be
  /// a primitive type.
  final Type? inputType;

  /// Creates a [WorkerCallback] with the given [id] and optional [inputType].
  const WorkerCallback(this.id, {this.inputType});
}
