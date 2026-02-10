import Foundation

/// Result type for Worker execution.
///
/// This struct provides a rich return type for workers, allowing them to:
/// - Return success/failure status
/// - Include optional messages
/// - Pass output data back to the caller
///
/// v2.3.0+: Introduced to support returning data from workers
///
/// Example:
/// ```swift
/// func doWork(input: String?) async throws -> WorkerResult {
///     do {
///         let data = try await fetchData()
///         return WorkerResult.success(
///             message: "Fetched \(data.count) items",
///             data: [
///                 "count": data.count,
///                 "items": data
///             ]
///         )
///     } catch {
///         return WorkerResult.failure(
///             message: "Failed: \(error.localizedDescription)"
///         )
///     }
/// }
/// ```
public struct WorkerResult {
    /// Whether the worker succeeded
    public let success: Bool

    /// Optional message (error message if failed, or success message)
    public let message: String?

    /// Optional output data to be passed to listeners
    public let data: [String: Any]?

    private init(success: Bool, message: String?, data: [String: Any]?) {
        self.success = success
        self.message = message
        self.data = data
    }

    /// Create a successful result.
    ///
    /// - Parameters:
    ///   - message: Optional success message
    ///   - data: Optional output data
    /// - Returns: WorkerResult indicating success
    public static func success(message: String? = nil, data: [String: Any]? = nil) -> WorkerResult {
        return WorkerResult(success: true, message: message, data: data)
    }

    /// Create a failure result.
    ///
    /// - Parameters:
    ///   - message: Error message describing the failure
    /// - Returns: WorkerResult indicating failure
    public static func failure(message: String) -> WorkerResult {
        return WorkerResult(success: false, message: message, data: nil)
    }
}