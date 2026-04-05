import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  // ──────────────────────────────────────────────────────────────
  // HeaderMiddleware
  // ──────────────────────────────────────────────────────────────
  group('HeaderMiddleware', () {
    test('type field is "header"', () {
      const m = HeaderMiddleware(headers: {});
      expect(m.toMap()['type'], 'header');
    });

    test('stores headers map', () {
      const m = HeaderMiddleware(headers: {'X-Foo': 'bar', 'X-Baz': 'qux'});
      expect(m.headers, {'X-Foo': 'bar', 'X-Baz': 'qux'});
    });

    test('toMap contains all header entries', () {
      const m = HeaderMiddleware(
        headers: {
          'Authorization': 'Bearer tok',
          'Content-Type': 'application/json'
        },
      );
      final map = m.toMap();
      final headers = map['headers'] as Map;
      expect(headers['Authorization'], 'Bearer tok');
      expect(headers['Content-Type'], 'application/json');
    });

    test('urlPattern is null when not provided', () {
      const m = HeaderMiddleware(headers: {'A': 'B'});
      expect(m.urlPattern, isNull);
      expect(m.toMap()['urlPattern'], isNull);
    });

    test('urlPattern stored and serialized', () {
      const m = HeaderMiddleware(
        headers: {'X-Token': 'abc'},
        urlPattern: r'https://api\.example\.com/.*',
      );
      expect(m.urlPattern, r'https://api\.example\.com/.*');
      expect(m.toMap()['urlPattern'], r'https://api\.example\.com/.*');
    });

    test('empty headers map is serialized', () {
      const m = HeaderMiddleware(headers: {});
      final map = m.toMap();
      expect(map['headers'], isEmpty);
    });

    test('headers with special characters round-trip', () {
      const m = HeaderMiddleware(
        headers: {'X-Custom': 'value with spaces & symbols = true'},
      );
      final map = m.toMap();
      expect((map['headers'] as Map)['X-Custom'],
          'value with spaces & symbols = true');
    });

    test('toMap has type, headers, urlPattern keys', () {
      const m = HeaderMiddleware(headers: {'A': 'B'}, urlPattern: 'p');
      expect(m.toMap().keys.toSet(), {'type', 'headers', 'urlPattern'});
    });
  });

  // ──────────────────────────────────────────────────────────────
  // LoggingMiddleware
  // ──────────────────────────────────────────────────────────────
  group('LoggingMiddleware', () {
    test('type field is "logging"', () {
      const m = LoggingMiddleware(logUrl: 'https://logs.example.com');
      expect(m.toMap()['type'], 'logging');
    });

    test('logUrl is stored and serialized', () {
      const m = LoggingMiddleware(logUrl: 'https://my-log-endpoint.io/ingest');
      expect(m.logUrl, 'https://my-log-endpoint.io/ingest');
      expect(m.toMap()['logUrl'], 'https://my-log-endpoint.io/ingest');
    });

    test('includeConfig defaults to false', () {
      const m = LoggingMiddleware(logUrl: 'https://x.com');
      expect(m.includeConfig, isFalse);
      expect(m.toMap()['includeConfig'], isFalse);
    });

    test('includeConfig=true is stored and serialized', () {
      const m = LoggingMiddleware(logUrl: 'https://x.com', includeConfig: true);
      expect(m.includeConfig, isTrue);
      expect(m.toMap()['includeConfig'], isTrue);
    });

    test('toMap has type, logUrl, includeConfig keys', () {
      const m = LoggingMiddleware(logUrl: 'https://x.com');
      expect(m.toMap().keys.toSet(), {'type', 'logUrl', 'includeConfig'});
    });
  });

  // ──────────────────────────────────────────────────────────────
  // RemoteConfigMiddleware
  // ──────────────────────────────────────────────────────────────
  group('RemoteConfigMiddleware', () {
    test('type field is "remoteConfig"', () {
      const m = RemoteConfigMiddleware(values: {});
      expect(m.toMap()['type'], 'remoteConfig');
    });

    test('stores values map', () {
      const m = RemoteConfigMiddleware(
        values: {'timeout': 30, 'retries': 3},
      );
      expect(m.values['timeout'], 30);
      expect(m.values['retries'], 3);
    });

    test('toMap values contains all entries', () {
      const m = RemoteConfigMiddleware(
        values: {'maxRetries': 5, 'timeoutMs': 10000},
      );
      final vals = m.toMap()['values'] as Map;
      expect(vals['maxRetries'], 5);
      expect(vals['timeoutMs'], 10000);
    });

    test('workerType is null when not specified', () {
      const m = RemoteConfigMiddleware(values: {'k': 'v'});
      expect(m.workerType, isNull);
      expect(m.toMap().containsKey('workerType'), isFalse);
    });

    test('workerType is included in toMap when provided', () {
      const m = RemoteConfigMiddleware(
        values: {'timeout': 15},
        workerType: 'HttpDownload',
      );
      expect(m.toMap()['workerType'], 'HttpDownload');
    });

    test('String value round-trips', () {
      const m =
          RemoteConfigMiddleware(values: {'baseUrl': 'https://prod.api.com'});
      expect((m.toMap()['values'] as Map)['baseUrl'], 'https://prod.api.com');
    });

    test('int value round-trips', () {
      const m = RemoteConfigMiddleware(values: {'port': 8443});
      expect((m.toMap()['values'] as Map)['port'], 8443);
    });

    test('double value round-trips', () {
      const m = RemoteConfigMiddleware(values: {'factor': 1.5});
      expect((m.toMap()['values'] as Map)['factor'], 1.5);
    });

    test('bool value round-trips', () {
      const m = RemoteConfigMiddleware(values: {'enabled': true});
      expect((m.toMap()['values'] as Map)['enabled'], isTrue);
    });

    test('multiple value types in one middleware', () {
      const m = RemoteConfigMiddleware(
        values: {
          'timeout': 30,
          'factor': 2.0,
          'enabled': false,
          'tag': 'prod',
        },
      );
      final vals = m.toMap()['values'] as Map;
      expect(vals['timeout'], 30);
      expect(vals['factor'], 2.0);
      expect(vals['enabled'], false);
      expect(vals['tag'], 'prod');
    });

    test('empty values map serializes to empty map', () {
      const m = RemoteConfigMiddleware(values: {});
      expect((m.toMap()['values'] as Map), isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Polymorphism – Middleware base type
  // ──────────────────────────────────────────────────────────────
  group('Middleware – polymorphism', () {
    test('HeaderMiddleware is-a Middleware', () {
      const Middleware m = HeaderMiddleware(headers: {'A': 'B'});
      expect(m, isA<Middleware>());
    });

    test('LoggingMiddleware is-a Middleware', () {
      const Middleware m = LoggingMiddleware(logUrl: 'https://x.com');
      expect(m, isA<Middleware>());
    });

    test('RemoteConfigMiddleware is-a Middleware', () {
      const Middleware m = RemoteConfigMiddleware(values: {'k': 1});
      expect(m, isA<Middleware>());
    });

    test('list of mixed middleware serializes without error', () {
      final middlewares = <Middleware>[
        const HeaderMiddleware(headers: {'X-Auth': 'Bearer tok'}),
        const LoggingMiddleware(logUrl: 'https://logs.io'),
        const RemoteConfigMiddleware(
            values: {'timeout': 30}, workerType: 'HttpDownload'),
      ];
      final maps = middlewares.map((m) => m.toMap()).toList();
      expect(maps[0]['type'], 'header');
      expect(maps[1]['type'], 'logging');
      expect(maps[2]['type'], 'remoteConfig');
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Idempotent registration (upsert semantics)
  // registerMiddleware with same type twice must replace, not accumulate.
  // Verified at Dart serialisation level: toMap() 'type' field is the
  // identity key used by MiddlewareStore on both platforms.
  // ──────────────────────────────────────────────────────────────
  group('Middleware – idempotent registration (type as identity key)', () {
    test('HeaderMiddleware type key is stable across instances', () {
      const m1 = HeaderMiddleware(headers: {'X-A': '1'});
      const m2 = HeaderMiddleware(headers: {'X-B': '2'});
      // Same type → same store key → second registration replaces first.
      expect(m1.toMap()['type'], m2.toMap()['type']);
    });

    test('LoggingMiddleware type key is stable across instances', () {
      const m1 = LoggingMiddleware(logUrl: 'https://logs1.example.com');
      const m2 = LoggingMiddleware(
          logUrl: 'https://logs2.example.com', includeConfig: true);
      expect(m1.toMap()['type'], m2.toMap()['type']);
    });

    test('RemoteConfigMiddleware type key is stable across instances', () {
      const m1 = RemoteConfigMiddleware(values: {'a': 1});
      const m2 =
          RemoteConfigMiddleware(values: {'b': 2}, workerType: 'HttpDownload');
      expect(m1.toMap()['type'], m2.toMap()['type']);
    });

    test('different middleware types have distinct type keys', () {
      const header = HeaderMiddleware(headers: {});
      const logging = LoggingMiddleware(logUrl: 'https://x.com');
      const remote = RemoteConfigMiddleware(values: {});
      final types = {
        header.toMap()['type'],
        logging.toMap()['type'],
        remote.toMap()['type'],
      };
      // All three types must be distinct (no collision = correct upsert keys).
      expect(types.length, 3);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // LoggingMiddleware – post-execution semantics
  // Dart-side: toMap() must carry the fields needed by the native
  // applyLoggingMiddleware() implementation.
  // ──────────────────────────────────────────────────────────────
  group('LoggingMiddleware – post-execution payload contract', () {
    test('toMap carries logUrl for native POST', () {
      const m =
          LoggingMiddleware(logUrl: 'https://telemetry.example.com/tasks');
      expect(m.toMap()['logUrl'], 'https://telemetry.example.com/tasks');
    });

    test('includeConfig=false does not include config in map keys', () {
      // The Dart map is the registration payload sent to native.
      // When includeConfig=false, the native side must NOT attach workerConfig.
      const m =
          LoggingMiddleware(logUrl: 'https://logs.io', includeConfig: false);
      expect(m.toMap()['includeConfig'], isFalse);
    });

    test('includeConfig=true is forwarded to native', () {
      const m =
          LoggingMiddleware(logUrl: 'https://logs.io', includeConfig: true);
      expect(m.toMap()['includeConfig'], isTrue);
    });

    test(
        'type is "logging" so native skips applyMiddleware (pre-exec) correctly',
        () {
      // applyMiddleware() on both platforms has a case "logging": break/skip.
      // This test documents the contract: type must be exactly "logging".
      const m = LoggingMiddleware(logUrl: 'https://x.com');
      expect(m.toMap()['type'], 'logging');
    });
  });
}
