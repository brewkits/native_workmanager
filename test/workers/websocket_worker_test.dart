// Tests for WebSocketWorker — Dart serialisation contract.

import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  // ── WebSocketWorker ────────────────────────────────────────────────────────

  group('WebSocketWorker', () {
    test('workerClassName is WebSocketWorker', () {
      const w = WebSocketWorker(url: 'wss://example.com/ws');
      expect(w.workerClassName, 'WebSocketWorker');
    });

    test('toMap() has correct workerType and defaults', () {
      const w = WebSocketWorker(url: 'wss://example.com/ws');
      final map = w.toMap();
      expect(map['workerType'], 'webSocket');
      expect(map['url'], 'wss://example.com/ws');
      expect(map['messages'], isEmpty);
      expect(map['timeoutSeconds'], 30);
      expect(map['receiveMessages'], 1);
      expect(map.containsKey('storeResponseAt'), false);
      expect(map.containsKey('pingIntervalSeconds'), false);
      expect(map.containsKey('headers'), false);
    });

    test('messages are preserved', () {
      const w = WebSocketWorker(
        url: 'wss://example.com/ws',
        messages: ['{"type":"subscribe"}', 'ping'],
      );
      expect(w.toMap()['messages'], ['{"type":"subscribe"}', 'ping']);
    });

    test('headers are included when non-empty', () {
      const w = WebSocketWorker(
        url: 'wss://example.com/ws',
        headers: {'Authorization': 'Bearer token123'},
      );
      expect(w.toMap()['headers'], {'Authorization': 'Bearer token123'});
    });

    test('empty headers map is omitted', () {
      const w = WebSocketWorker(url: 'wss://example.com/ws', headers: {});
      expect(w.toMap().containsKey('headers'), false);
    });

    test('storeResponseAt is included when set', () {
      const w = WebSocketWorker(
        url: 'wss://example.com/ws',
        storeResponseAt: '/data/responses.json',
      );
      expect(w.toMap()['storeResponseAt'], '/data/responses.json');
    });

    test('pingIntervalSeconds is included when set', () {
      const w = WebSocketWorker(
        url: 'wss://example.com/ws',
        pingIntervalSeconds: 15,
      );
      expect(w.toMap()['pingIntervalSeconds'], 15);
    });

    test('custom timeout and receiveMessages', () {
      const w = WebSocketWorker(
        url: 'wss://example.com/ws',
        timeoutSeconds: 60,
        receiveMessages: 5,
      );
      final map = w.toMap();
      expect(map['timeoutSeconds'], 60);
      expect(map['receiveMessages'], 5);
    });

    test('ws:// scheme is valid', () {
      const w = WebSocketWorker(url: 'ws://localhost:8080/ws');
      expect(w.toMap()['url'], 'ws://localhost:8080/ws');
    });
  });

  group('NativeWorker.webSocket()', () {
    test('returns WebSocketWorker', () {
      final w = NativeWorker.webSocket(url: 'wss://example.com/ws');
      expect(w, isA<WebSocketWorker>());
    });

    test('empty url throws ArgumentError', () {
      expect(
        () => NativeWorker.webSocket(url: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('http:// url throws ArgumentError', () {
      expect(
        () => NativeWorker.webSocket(url: 'https://example.com/ws'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('invalid url throws ArgumentError', () {
      expect(
        () => NativeWorker.webSocket(url: 'not-a-url'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('timeoutSeconds = 0 throws ArgumentError', () {
      expect(
        () => NativeWorker.webSocket(
          url: 'wss://example.com/ws',
          timeoutSeconds: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('negative receiveMessages throws ArgumentError', () {
      expect(
        () => NativeWorker.webSocket(
          url: 'wss://example.com/ws',
          receiveMessages: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('receiveMessages = 0 is valid (fire-and-forget)', () {
      final w = NativeWorker.webSocket(
        url: 'wss://example.com/ws',
        receiveMessages: 0,
      );
      expect(w.toMap()['receiveMessages'], 0);
    });

    test('full configuration round-trips', () {
      final w = NativeWorker.webSocket(
        url: 'wss://api.example.com/ws',
        messages: ['{"action":"subscribe","channel":"prices"}'],
        headers: {'Authorization': 'Bearer tok'},
        timeoutSeconds: 45,
        receiveMessages: 3,
        storeResponseAt: '/data/prices.json',
        pingIntervalSeconds: 20,
      );
      final map = w.toMap();
      expect(map['url'], 'wss://api.example.com/ws');
      expect(map['messages'], ['{"action":"subscribe","channel":"prices"}']);
      expect(map['headers'], {'Authorization': 'Bearer tok'});
      expect(map['timeoutSeconds'], 45);
      expect(map['receiveMessages'], 3);
      expect(map['storeResponseAt'], '/data/prices.json');
      expect(map['pingIntervalSeconds'], 20);
    });
  });
}
