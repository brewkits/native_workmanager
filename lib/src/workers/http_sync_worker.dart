import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../worker.dart';

/// HTTP sync worker configuration.
@immutable
final class HttpSyncWorker extends Worker {
  const HttpSyncWorker({
    required this.url,
    this.method = HttpMethod.post,
    this.headers = const {},
    this.requestBody,
    this.timeout = const Duration(seconds: 60),
  });

  final String url;
  final HttpMethod method;
  final Map<String, String> headers;
  final Map<String, dynamic>? requestBody;
  final Duration timeout;

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
      };
}
