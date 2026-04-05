import 'package:flutter/foundation.dart';

/// Authentication configuration for HTTP workers.
///
/// Provides a declarative way to configure auth headers for download and
/// upload workers. The [accessToken] is injected into the [headerTemplate]
/// wherever `{accessToken}` appears.
///
/// ## Example — Bearer token
/// ```dart
/// worker: NativeWorker.httpDownload(
///   url: 'https://api.example.com/files/secret.pdf',
///   savePath: '/tmp/secret.pdf',
///   authToken: myToken,
/// ),
/// ```
///
/// ## Example — Custom header format
/// ```dart
/// worker: NativeWorker.httpDownload(
///   url: 'https://api.example.com/files/secret.pdf',
///   savePath: '/tmp/secret.pdf',
///   authToken: myApiKey,
///   authHeaderTemplate: 'ApiKey {accessToken}',
/// ),
/// ```
@immutable
class AuthConfig {
  const AuthConfig({
    required this.accessToken,
    this.headerTemplate = 'Bearer {accessToken}',
  });

  /// The access token value.
  final String accessToken;

  /// Template string for the `Authorization` header value.
  ///
  /// `{accessToken}` is replaced with [accessToken] at request time.
  /// Default: `"Bearer {accessToken}"`
  final String headerTemplate;

  /// Resolved header value with [accessToken] substituted.
  String get resolvedHeader =>
      headerTemplate.replaceAll('{accessToken}', accessToken);
}
