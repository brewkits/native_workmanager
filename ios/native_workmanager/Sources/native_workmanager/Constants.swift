import Foundation

// MARK: - Plugin defaults

/// Default values injected by Flutter's NativeWorkManager.initialize().
/// Centralised here so both the plugin and KMPBridge agree on the same defaults.
enum NWMDefaults {
    /// Maximum number of concurrent download/worker tasks when no limit is supplied by Dart.
    static let maxConcurrentTasks = 4
    /// Minimum free disk space (MB) that must remain after a download.
    static let diskSpaceBufferMB = 20
}

// MARK: - HTTP constants

/// HTTP status codes and header names shared by HttpDownloadWorker and related utilities.
enum HttpConstants {
    // MARK: Status codes
    /// HTTP 200 OK — full content response.
    static let httpOk = 200
    /// HTTP 206 Partial Content — server honours a Range request; resume is possible.
    static let partialContent = 206
    /// HTTP 416 Range Not Satisfiable — resume position exceeds server file size.
    static let rangeNotSatisfiable = 416

    // MARK: Request/response headers
    static let headerRange = "Range"
    static let headerIfRange = "If-Range"
    static let headerETag = "ETag"
    static let headerLastModified = "Last-Modified"
    static let headerCookie = "Cookie"
    static let headerAuthorization = "Authorization"
    static let headerContentDisposition = "Content-Disposition"
    static let headerContentType = "Content-Type"

    // MARK: File suffixes
    /// Sidecar file that stores the ETag/Last-Modified value for If-Range validation.
    static let etagSidecarSuffix = ".tmp.etag"
    /// Sentinel temp filename used in directory-mode downloads before the real filename is known.
    static let pendingTmpFilename = "__pending__.tmp"

    // MARK: Defaults
    /// Default download timeout (300 seconds / 5 minutes).
    static let downloadTimeoutMs: Int64 = 300_000
    /// Default checksum hash algorithm.
    static let defaultChecksumAlgorithm = "SHA-256"
    /// Default Authorization header template; `{accessToken}` is replaced at runtime.
    static let defaultAuthHeaderTemplate = "Bearer {accessToken}"
    /// Read buffer size for streaming resume appends (64 KB).
    static let resumeChunkSize = 65_536
}
