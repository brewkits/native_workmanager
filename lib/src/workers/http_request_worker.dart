import 'package:flutter/foundation.dart';
import '../worker.dart';
import 'request_signing.dart';

export 'request_signing.dart';

/// HTTP request worker configuration.
@immutable
final class HttpRequestWorker extends Worker {
  const HttpRequestWorker({
    required this.url,
    this.method = HttpMethod.get,
    this.headers = const {},
    this.body,
    this.timeout = const Duration(seconds: 30),
    this.requestSigning,
  });

  final String url;
  final HttpMethod method;
  final Map<String, String> headers;
  final String? body;
  final Duration timeout;

  /// HMAC-SHA256 request signing configuration.
  ///
  /// When set, each request is signed with the specified secret key and the
  /// signature is injected as a request header (default: `X-Signature`).
  final RequestSigning? requestSigning;

  @override
  String get workerClassName => 'HttpRequestWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'httpRequest',
        'url': url,
        'method': method.name,
        'headers': headers,
        'body': body,
        'timeoutMs': timeout.inMilliseconds,
        if (requestSigning != null) 'requestSigning': requestSigning!.toMap(),
      };
}
