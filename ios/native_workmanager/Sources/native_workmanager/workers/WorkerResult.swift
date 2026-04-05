import Foundation

/// Result type for Worker execution.
///
/// This struct provides a rich return type for workers, allowing them to:
/// - Return success/failure status
/// - Include optional messages
/// - Pass output data back to the caller
/// - Indicate whether the task should be retried
///
/// v2.3.0+: Introduced to support returning data from workers
public struct WorkerResult {
    /// Whether the worker succeeded
    public let success: Bool

    /// Optional message (error message if failed, or success message)
    public let message: String?

    /// Optional output data to be passed to listeners
    public let data: [String: Any]?
    
    /// Whether the task should be retried (hint for the scheduler)
    public let shouldRetry: Bool

    private init(success: Bool, message: String?, data: [String: Any]?, shouldRetry: Bool = false) {
        self.success = success
        self.message = message
        self.data = data
        self.shouldRetry = shouldRetry
    }

    /// Create a successful result.
    ///
    /// - Parameters:
    ///   - message: Optional success message
    ///   - data: Optional output data
    /// - Returns: WorkerResult indicating success
    public static func success(message: String? = nil, data: [String: Any]? = nil) -> WorkerResult {
        return WorkerResult(success: true, message: message, data: data, shouldRetry: false)
    }

    /// Create a failure result.
    ///
    /// - Parameters:
    ///   - message: Error message describing the failure
    ///   - shouldRetry: Whether the task should be retried (default: false)
    /// - Returns: WorkerResult indicating failure
    public static func failure(message: String, shouldRetry: Bool = false) -> WorkerResult {
        return WorkerResult(success: false, message: message, data: nil, shouldRetry: shouldRetry)
    }
}
