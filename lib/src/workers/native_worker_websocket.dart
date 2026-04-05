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
  if (url.isEmpty) {
    throw ArgumentError('url cannot be empty for webSocket');
  }
  final uri = Uri.tryParse(url);
  if (uri == null || (uri.scheme != 'ws' && uri.scheme != 'wss')) {
    throw ArgumentError(
      'Invalid WebSocket URL: "$url". Must start with ws:// or wss://',
    );
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
