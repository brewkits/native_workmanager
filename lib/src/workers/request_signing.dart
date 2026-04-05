import 'package:flutter/foundation.dart';

/// HMAC-based request signing configuration for HTTP workers.
///
/// When set on an HTTP worker, each request is signed using HMAC-SHA256 and
/// the signature is added as a request header (default: `X-Signature`).
/// An optional `X-Timestamp` header is also added (in milliseconds since epoch)
/// so that servers can reject replayed requests that are too old.
///
/// ## What gets signed
///
/// The signature covers a canonical message composed of:
/// ```
/// METHOD\n
/// URL\n
/// BODY\n          ← only when signBody=true and there is a body
/// TIMESTAMP       ← only when includeTimestamp=true
/// ```
///
/// ## Example — download with server validation
///
/// ```dart
/// worker: HttpDownloadWorker(
///   url: 'https://api.example.com/protected/report.pdf',
///   savePath: '/tmp/report.pdf',
///   requestSigning: RequestSigning(
///     secretKey: env['API_SECRET']!,
///   ),
/// ),
/// ```
///
/// ## Example — upload with non-default header name
///
/// ```dart
/// worker: HttpUploadWorker(
///   url: 'https://api.example.com/upload',
///   filePath: '/tmp/data.csv',
///   requestSigning: RequestSigning(
///     secretKey: env['API_SECRET']!,
///     headerName: 'X-Hub-Signature-256',
///     signaturePrefix: 'sha256=',
///   ),
/// ),
/// ```
///
/// ## Server-side verification (example in Node.js)
///
/// ```js
/// const crypto = require('crypto');
/// function verify(req, secret) {
///   const ts    = req.headers['x-timestamp'] ?? '';
///   const sig   = req.headers['x-signature']  ?? '';
///   const body  = req.rawBody ?? '';
///   const msg   = `${req.method}\n${req.url}\n${body}\n${ts}`;
///   const expected = crypto.createHmac('sha256', secret).update(msg).digest('hex');
///   return crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected));
/// }
/// ```
@immutable
class RequestSigning {
  const RequestSigning({
    required this.secretKey,
    this.headerName = 'X-Signature',
    this.signaturePrefix = '',
    this.includeTimestamp = true,
    this.signBody = true,
  }) : assert(secretKey.length >= 16,
            'secretKey must be at least 16 characters for meaningful security');

  /// The shared secret used to compute the HMAC-SHA256 digest.
  ///
  /// Must be at least 16 characters. Keep this out of source control —
  /// read it from a secure secret store at runtime.
  final String secretKey;

  /// Name of the HTTP header that carries the signature.
  ///
  /// Default: `'X-Signature'`
  final String headerName;

  /// Optional string prepended to the raw hex digest in [headerName].
  ///
  /// GitHub-style webhooks use `'sha256='`. Leave empty for a bare hex string.
  ///
  /// Default: `''` (bare hex)
  final String signaturePrefix;

  /// When `true` (default), the current Unix timestamp in **milliseconds** is
  /// included in the signed message and sent as an `X-Timestamp` header.
  ///
  /// Servers should reject requests whose `X-Timestamp` is more than
  /// a configurable window (e.g. 5 minutes) in the past to prevent replay attacks.
  final bool includeTimestamp;

  /// When `true` (default), the request body bytes are included in the signed
  /// message.
  ///
  /// For GET/HEAD requests (no body), this has no effect.
  /// For large upload bodies this adds a small CPU cost.
  final bool signBody;

  Map<String, dynamic> toMap() => {
        'secretKey': secretKey,
        'headerName': headerName,
        'signaturePrefix': signaturePrefix,
        'includeTimestamp': includeTimestamp,
        'signBody': signBody,
      };
}
