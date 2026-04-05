import 'package:flutter/foundation.dart';

/// Base class for all background task middleware.
///
/// Middleware allows you to intercept and modify task configurations
/// globally before they are executed by the native engine.
@immutable
abstract class Middleware {
  const Middleware();

  /// Convert to map for platform channel.
  Map<String, dynamic> toMap();
}

/// Middleware that adds HTTP headers to all matching requests.
///
/// Use this to globally inject authentication tokens or custom
/// user-agent strings into native HTTP workers.
class HeaderMiddleware extends Middleware {
  const HeaderMiddleware({
    required this.headers,
    this.urlPattern,
  });

  /// Map of headers to add.
  final Map<String, String> headers;

  /// Optional regex pattern to match URLs.
  ///
  /// If provided, headers are only added to HTTP workers whose URL
  /// matches this pattern. If null, applies to all HTTP workers.
  final String? urlPattern;

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'header',
      'headers': headers,
      'urlPattern': urlPattern,
    };
  }
}

/// Middleware that POSTs task execution metadata to a custom endpoint
/// after each task completes (success or failure).
///
/// Unlike [HeaderMiddleware] and [RemoteConfigMiddleware] (which modify worker
/// config before execution), `LoggingMiddleware` is a **post-execution hook**.
/// It fires a fire-and-forget HTTP POST and never affects the worker result.
///
/// ## Payload
///
/// ```json
/// {
///   "taskId": "my-sync-task",
///   "workerClassName": "HttpDownloadWorker",
///   "success": true,
///   "timestamp": 1712345678000,
///   "durationMs": 1234,
///   "message": "Downloaded 5.2 MB",
///   "workerConfig": { ... }   // only when includeConfig: true
/// }
/// ```
///
/// ## Usage
///
/// ```dart
/// await NativeWorkManager.registerMiddleware(
///   LoggingMiddleware(
///     logUrl: 'https://logs.example.com/tasks',
///     includeConfig: false,
///   ),
/// );
/// ```
///
/// Network errors from the log POST are silently swallowed — a logging
/// failure never causes a task to be marked as failed.
class LoggingMiddleware extends Middleware {
  const LoggingMiddleware({
    required this.logUrl,
    this.includeConfig = false,
  });

  /// URL to POST execution logs to after each task completes.
  final String logUrl;

  /// Whether to include the worker configuration map in the log payload.
  ///
  /// Disable (default) to avoid leaking sensitive config values (URLs,
  /// credentials, file paths) to your logging endpoint.
  final bool includeConfig;

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'logging',
      'logUrl': logUrl,
      'includeConfig': includeConfig,
    };
  }
}

/// Middleware that injects remote configuration values into worker configs
/// at execution time.
///
/// Use this to control worker behaviour dynamically at runtime — no app
/// update required. Values can come from any source: Firebase Remote Config,
/// AWS AppConfig, LaunchDarkly, or a plain REST endpoint.
///
/// ## Usage
///
/// ```dart
/// // 1. Fetch values from your config source (e.g. Firebase Remote Config)
/// final rc = FirebaseRemoteConfig.instance;
/// await rc.fetchAndActivate();
///
/// // 2. Register middleware once at startup (or refresh on config change)
/// await NativeWorkManager.registerMiddleware(
///   RemoteConfigMiddleware(
///     values: {
///       'timeout': rc.getInt('download_timeout_seconds'),
///       'maxRetries': rc.getInt('max_retries'),
///     },
///     workerType: 'HttpDownload', // optional: only targets HttpDownloadWorker
///   ),
/// );
/// ```
///
/// To refresh the config (e.g. after a Remote Config fetch), simply call
/// `registerMiddleware` again with updated [values] — the native side
/// replaces the previous entry for the `remoteConfig` type.
///
/// ## How it works
///
/// Each key in [values] is injected directly into the native worker config
/// map, overriding any existing value with the same name. If [workerType]
/// is provided, the middleware only applies to workers whose class name
/// contains that string (case-insensitive substring match).
class RemoteConfigMiddleware extends Middleware {
  const RemoteConfigMiddleware({
    required this.values,
    this.workerType,
  });

  /// Config values to inject into matching worker configurations.
  ///
  /// Keys map directly to worker config fields. Supported value types:
  /// `String`, `int`, `double`, `bool`. Nested maps are not supported.
  final Map<String, dynamic> values;

  /// Optional worker class name filter (case-insensitive substring match).
  ///
  /// When set, only workers whose class name contains this string receive
  /// the injected values. For example, `'HttpDownload'` targets only
  /// `HttpDownloadWorker`. When `null`, all workers are affected.
  final String? workerType;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'remoteConfig',
        'values': values,
        if (workerType != null) 'workerType': workerType,
      };
}
