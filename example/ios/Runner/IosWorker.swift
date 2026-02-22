import native_workmanager

/// Re-export the plugin's IosWorker protocol for use in the Runner target.
///
/// Custom worker classes in this Runner target should conform to this typealias,
/// which maps directly to `native_workmanager.IosWorker`.
///
/// Example:
/// ```swift
/// class MyWorker: IosWorker {
///     func doWork(input: String?) async throws -> WorkerResult {
///         // ...
///     }
/// }
/// ```
public typealias IosWorker = native_workmanager.IosWorker
