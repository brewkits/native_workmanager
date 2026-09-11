import 'package:flutter/foundation.dart';

import '../worker.dart';

export 'certificate_pinning.dart';

/// Connect to a WebSocket endpoint, send messages, and receive responses.
///
/// The worker connects to [url], sends each string in [messages] after the
/// connection is established, waits for [receiveMessages] server responses,
/// then closes the connection cleanly.
///
/// **Platform support:** Android only. Calling this on iOS will return a
/// failure result with message `"WebSocketWorker is not supported on iOS"`.
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'ws-ping',
///   worker: NativeWorker.webSocket(
///     url: 'wss://api.example.com/ws',
///     messages: ['{"type":"ping"}'],
///     receiveMessages: 1,
///   ),
/// );
/// ```
///
/// **Result data (success):**
/// ```json
/// {
///   "connected": true,
///   "messagesSent": 1,
///   "messagesReceived": 1,
///   "messages": ["{\"type\":\"pong\"}"]
/// }
/// ```
///
/// Optionally persist received messages to disk via [storeResponseAt].
@immutable
final class WebSocketWorker extends Worker {
  const WebSocketWorker({
    required this.url,
    this.messages = const [],
    this.headers = const {},
    this.timeoutSeconds = 30,
    this.receiveMessages = 1,
    this.storeResponseAt,
    this.pingIntervalSeconds,
    this.certificatePinning,
  });

  /// WebSocket endpoint URL. Must use `ws://` or `wss://` scheme.
  final String url;

  /// Messages to send after the connection is established.
  final List<String> messages;

  /// Optional HTTP upgrade headers (e.g. `Authorization: Bearer …`).
  final Map<String, String> headers;

  /// Total connection timeout in seconds. Default `30`.
  final int timeoutSeconds;

  /// Number of server messages to wait for before closing. Default `1`.
  final int receiveMessages;

  /// Optional absolute path to write received messages as a JSON array.
  final String? storeResponseAt;

  /// Optional WebSocket ping interval in seconds (keep-alive).
  final int? pingIntervalSeconds;

  /// Opt-in TLS certificate pinning (`wss://` connections). Android only,
  /// matching this worker's overall platform support. See [CertificatePinning].
  final CertificatePinning? certificatePinning;

  @override
  String get workerClassName => 'WebSocketWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'webSocket',
        'url': url,
        'messages': messages,
        if (headers.isNotEmpty) 'headers': headers,
        'timeoutSeconds': timeoutSeconds,
        'receiveMessages': receiveMessages,
        if (storeResponseAt != null) 'storeResponseAt': storeResponseAt,
        if (pingIntervalSeconds != null)
          'pingIntervalSeconds': pingIntervalSeconds,
        if (certificatePinning != null)
          'certificatePinning': certificatePinning!.toMap(),
      };
}
