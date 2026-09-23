part of '../worker.dart';

Worker _buildWebSocket({
  required String url,
  List<String> messages = const [],
  Map<String, String> headers = const {},
  int timeoutSeconds = 30,
  int receiveMessages = 1,
  String? storeResponseAt,
  int? pingIntervalSeconds,
}) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    throw UnsupportedError(
      'NativeWorker.webSocket() is not supported on iOS. '
      'Use a DartWorker with dart:io WebSocket for cross-platform WebSocket support.',
    );
  }
  // Was a bare scheme-prefix check until the 2026-09-23 lib/ audit — url
  // content (injection chars, null bytes) went unchecked, enforceHttps(true)
  // had no effect on ws:// vs wss://, and blockPrivateIPs didn't apply here.
  NativeWorker._validateWebSocketUrl(url);
  if (storeResponseAt != null) {
    NativeWorker._validateFilePath(storeResponseAt, 'storeResponseAt');
  }
  if (timeoutSeconds <= 0) {
    throw ArgumentError('timeoutSeconds must be > 0, got $timeoutSeconds');
  }
  if (receiveMessages < 0) {
    throw ArgumentError('receiveMessages must be >= 0, got $receiveMessages');
  }
  return WebSocketWorker(
    url: url,
    messages: messages,
    headers: headers,
    timeoutSeconds: timeoutSeconds,
    receiveMessages: receiveMessages,
    storeResponseAt: storeResponseAt,
    pingIntervalSeconds: pingIntervalSeconds,
  );
}
