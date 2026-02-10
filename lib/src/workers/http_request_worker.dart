import 'package:flutter/foundation.dart';
import '../worker.dart';

/// HTTP request worker configuration.
@immutable
final class HttpRequestWorker extends Worker {
  const HttpRequestWorker({
    required this.url,
    this.method = HttpMethod.get,
    this.headers = const {},
    this.body,
    this.timeout = const Duration(seconds: 30),
  });

  final String url;
  final HttpMethod method;
  final Map<String, String> headers;
  final String? body;
  final Duration timeout;

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
      };
}
