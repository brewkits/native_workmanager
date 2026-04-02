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

/// Middleware that logs task execution metadata to a custom endpoint.
class LoggingMiddleware extends Middleware {
  const LoggingMiddleware({
    required this.logUrl,
    this.includeConfig = false,
  });

  /// URL to POST execution logs to.
  final String logUrl;

  /// Whether to include the full worker configuration in the log.
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
