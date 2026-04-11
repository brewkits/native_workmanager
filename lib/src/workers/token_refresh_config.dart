import 'package:flutter/foundation.dart';

/// Configuration for automatic token refresh.
///
/// When a worker receives a 401 Unauthorized response, it can automatically
/// attempt to refresh the access token using this configuration.
@immutable
final class TokenRefreshConfig {
  /// Create a token refresh configuration.
  const TokenRefreshConfig({
    required this.url,
    this.method = 'POST',
    this.headers = const {},
    this.body = const {},
    this.responseKey = 'access_token',
    this.tokenHeaderName = 'Authorization',
    this.tokenPrefix = 'Bearer ',
  });

  /// The URL to call for token refresh.
  final String url;

  /// HTTP method for the refresh request (default: POST).
  final String method;

  /// HTTP headers for the refresh request.
  final Map<String, String> headers;

  /// HTTP body for the refresh request (usually containing refresh_token).
  final Map<String, dynamic> body;

  /// Key in the JSON response that contains the new access token.
  /// Supports nested keys using dot notation (e.g. "auth.access_token").
  final String responseKey;

  /// Name of the header where the new token should be placed in retried requests.
  final String tokenHeaderName;

  /// Prefix for the token in the header (default: "Bearer ").
  final String tokenPrefix;

  /// Convert to map for platform channel.
  Map<String, dynamic> toMap() => {
        'url': url,
        'method': method,
        'headers': headers,
        'body': body,
        'responseKey': responseKey,
        'tokenHeaderName': tokenHeaderName,
        'tokenPrefix': tokenPrefix,
      };

  @override
  String toString() => 'TokenRefreshConfig(url: $url, method: $method)';
}
