import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../worker.dart';

export 'request_signing.dart';

/// HTTP sync worker configuration.
@immutable
final class HttpSyncWorker extends Worker {
  const HttpSyncWorker({
    required this.url,
    this.method = HttpMethod.post,
    this.headers = const {},
    this.requestBody,
    this.timeout = const Duration(seconds: 60),
    this.requestSigning,
    this.tokenRefresh,
  });

  final String url;
  final HttpMethod method;
  final Map<String, String> headers;
  final Map<String, dynamic>? requestBody;
  final Duration timeout;

  /// HMAC-SHA256 request signing configuration.
  ///
  /// When set, each sync request is signed with the specified secret key and
  /// the signature is injected as a request header (default: `X-Signature`).
  final RequestSigning? requestSigning;

  /// Automatic token refresh configuration.
  final TokenRefreshConfig? tokenRefresh;

  @override
  String get workerClassName => 'HttpSyncWorker';

  @override
  Map<String, dynamic> toMap() {
    // NET-016: validate requestBody is JSON-serializable before the task is
    // dispatched to the native layer.  jsonEncode already throws on circular
    // references / non-serializable objects, but wrapping with a clear message
    // avoids a cryptic JsonUnsupportedObjectError at enqueue time.
    String? encodedBody;
    if (requestBody != null) {
      try {
        encodedBody = jsonEncode(requestBody);
      } on JsonUnsupportedObjectError catch (e) {
        throw ArgumentError(
          'HttpSyncWorker.requestBody must be JSON-serializable: $e',
        );
      }
    }
    return {
      'workerType': 'httpSync',
      'url': url,
      'method': method.name,
      'headers': headers,
      'requestBody': encodedBody,
      'timeoutMs': timeout.inMilliseconds,
      if (requestSigning != null) 'requestSigning': requestSigning!.toMap(),
      if (tokenRefresh != null) 'tokenRefresh': tokenRefresh!.toMap(),
    };
  }
}
