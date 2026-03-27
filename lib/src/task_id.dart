/// A compile-time–typed wrapper around a task ID string.
///
/// Using `TaskId` instead of raw `String` makes accidental parameter swaps
/// (e.g. `taskId` vs `tag`) a compile error rather than a silent runtime bug.
///
/// ```dart
/// const id = TaskId('daily-sync');
///
/// await NativeWorkManager.cancel(taskId: id.value);
/// // or — because TaskId implements String, it works wherever String is accepted:
/// await NativeWorkManager.cancel(taskId: id);
/// ```
///
/// `TaskId` is a Dart 3 *extension type* — it has zero runtime overhead and
/// erases to `String` at compile time.
extension type const TaskId(String value) implements String {
  /// Returns true if the raw value is non-empty.
  bool get isValid => value.isNotEmpty;
}
