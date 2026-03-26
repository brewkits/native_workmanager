import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../worker.dart';
import 'request_signing.dart';

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

  @override
  String get workerClassName => 'HttpSyncWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'httpSync',
        'url': url,
        'method': method.name,
        'headers': headers,
        'requestBody': requestBody != null ? jsonEncode(requestBody) : null,
        'timeoutMs': timeout.inMilliseconds,
        if (requestSigning != null) 'requestSigning': requestSigning!.toMap(),
      };
}
