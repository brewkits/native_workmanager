import 'package:flutter/foundation.dart';
import '../worker.dart';

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

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILDER-STYLE copyWith + convenience methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns a copy with the given fields replaced.
  HttpRequestWorker copyWith({
    String? url,
    HttpMethod? method,
    Map<String, String>? headers,
    String? body,
    Duration? timeout,
    RequestSigning? requestSigning,
  }) =>
      HttpRequestWorker(
        url: url ?? this.url,
        method: method ?? this.method,
        headers: headers ?? this.headers,
        body: body ?? this.body,
        timeout: timeout ?? this.timeout,
        requestSigning: requestSigning ?? this.requestSigning,
      );

  /// Convenience: add or merge HTTP headers.
  HttpRequestWorker withHeaders(Map<String, String> extra) =>
      copyWith(headers: {...headers, ...extra});

  /// Convenience: add `Authorization` header.
  HttpRequestWorker withAuth({
    required String token,
    String template = 'Bearer {accessToken}',
  }) =>
      withHeaders({
        'Authorization': template.replaceAll('{accessToken}', token),
      });

  /// Convenience: set a JSON body (also sets `Content-Type: application/json`
  /// if not already present).
  HttpRequestWorker withBody(String jsonBody) => copyWith(
        body: jsonBody,
        headers: {
          'Content-Type': 'application/json',
          ...headers,
        },
      );

  /// Convenience: sign requests with HMAC-SHA256.
  HttpRequestWorker withSigning(RequestSigning signing) =>
      copyWith(requestSigning: signing);

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
