import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Dart-side unit coverage for [CertificatePin]/[CertificatePinning].
///
/// The actual pin verification (SPKI digest computation, chain validation)
/// runs entirely on the native side — Android's OkHttp `CertificatePinner`
/// and iOS's `PinningDelegate` — and is covered by the `TLS Certificate
/// Pinning` group in `example/integration_test/device_integration_test.dart`,
/// device-verified on both platforms per the CLAUDE.md mandatory-device-test
/// rule. What belongs here is the Dart-side contract: construction
/// validation and the exact wire shape both native bridges parse.
void main() {
  group('CertificatePin – construction validation', () {
    test('accepts a valid hostname and pin', () {
      final pin = CertificatePin(
        hostname: 'api.example.com',
        sha256Pins: ['sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='],
      );
      expect(pin.hostname, 'api.example.com');
      expect(pin.sha256Pins,
          ['sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=']);
    });

    test('accepts multiple pins for the same host (current + backup)', () {
      final pin = CertificatePin(
        hostname: 'api.example.com',
        sha256Pins: [
          'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
          'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
        ],
      );
      expect(pin.sha256Pins, hasLength(2));
    });

    test('throws ArgumentError on blank hostname', () {
      expect(
        () => CertificatePin(hostname: '', sha256Pins: ['sha256/AAAA=']),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError on whitespace-only hostname', () {
      expect(
        () => CertificatePin(hostname: '   ', sha256Pins: ['sha256/AAAA=']),
        throwsArgumentError,
      );
    });

    test(
        'throws ArgumentError on empty sha256Pins — the config would reject '
        'every connection to this host', () {
      expect(
        () => CertificatePin(hostname: 'api.example.com', sha256Pins: []),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when a pin is missing the sha256/ prefix', () {
      expect(
        () => CertificatePin(
          hostname: 'api.example.com',
          // A bare base64 digest without the prefix — the classic mistake of
          // pasting an OkHttp/openssl pin without its "sha256/" marker.
          sha256Pins: ['AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='],
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when a pin is hex instead of base64', () {
      expect(
        () => CertificatePin(
          hostname: 'api.example.com',
          sha256Pins: ['sha1/deadbeef'], // wrong prefix entirely
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when a pin has no digest after the prefix', () {
      expect(
        () => CertificatePin(
            hostname: 'api.example.com', sha256Pins: ['sha256/']),
        throwsArgumentError,
      );
    });

    test('one bad pin in a list of several still throws', () {
      expect(
        () => CertificatePin(
          hostname: 'api.example.com',
          sha256Pins: [
            'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
            'not-a-valid-pin',
          ],
        ),
        throwsArgumentError,
      );
    });

    test('accepts a wildcard hostname pattern', () {
      // Android/OkHttp supports "*." wildcards; construction itself doesn't
      // validate the pattern shape, only that it's non-blank.
      final pin = CertificatePin(
        hostname: '*.example.com',
        sha256Pins: ['sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='],
      );
      expect(pin.hostname, '*.example.com');
    });
  });

  group('CertificatePinning.toMap — wire shape both native bridges parse', () {
    test('single pin serializes to {"pins": {hostname: [pins]}}', () {
      final pinning = CertificatePinning([
        CertificatePin(
          hostname: 'api.example.com',
          sha256Pins: ['sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='],
        ),
      ]);

      expect(pinning.toMap(), {
        'pins': {
          'api.example.com': [
            'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
          ],
        },
      });
    });

    test('multiple hosts each get their own entry', () {
      final pinning = CertificatePinning([
        CertificatePin(
          hostname: 'api.example.com',
          sha256Pins: ['sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='],
        ),
        CertificatePin(
          hostname: 'cdn.example.com',
          sha256Pins: ['sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB='],
        ),
      ]);

      final map = pinning.toMap();
      expect((map['pins'] as Map).keys, {'api.example.com', 'cdn.example.com'});
    });

    test(
        'empty pins list serializes to an empty pins map, not omitted — '
        'both native bridges treat an empty/absent "pins" object as '
        '"nothing configured", so this is not a functional gap, just '
        'documenting the round-trip shape', () {
      expect(
          const CertificatePinning([]).toMap(), {'pins': <String, dynamic>{}});
    });
  });

  group(
      'HttpRequestWorker.toMap — certificatePinning end-to-end field propagation',
      () {
    // Per CLAUDE.md's issue #30 rule: a round-trip serialization test alone
    // does not prove a field reaches the native bridge. This asserts the key
    // actually appears in the map every worker's toMap() sends over the
    // MethodChannel — the same map the Android/iOS bridges parse
    // "certificatePinning" out of (see HttpSecurityHelper.kt /
    // KMPBridge.swift's CertificatePinningConfig.from). The bridges
    // themselves genuinely forwarding it into OkHttp's CertificatePinner /
    // iOS's PinningDelegate is covered by the device-run "TLS Certificate
    // Pinning" group in device_integration_test.dart.
    test('certificatePinning key is present when set', () {
      final worker = HttpRequestWorker(
        url: 'https://api.example.com',
        certificatePinning: CertificatePinning([
          CertificatePin(
            hostname: 'api.example.com',
            sha256Pins: ['sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='],
          ),
        ]),
      );

      final map = worker.toMap();
      expect(map.containsKey('certificatePinning'), isTrue);
      expect(map['certificatePinning'], {
        'pins': {
          'api.example.com': [
            'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
          ],
        },
      });
    });

    test(
        'certificatePinning key is omitted when unset — opt-in, unaffected '
        'by default', () {
      final worker = HttpRequestWorker(url: 'https://api.example.com');
      expect(worker.toMap().containsKey('certificatePinning'), isFalse);
    });

    test('withCertificatePinning convenience method sets the field', () {
      final worker = HttpRequestWorker(url: 'https://api.example.com')
          .withCertificatePinning(
        CertificatePinning([
          CertificatePin(
            hostname: 'api.example.com',
            sha256Pins: ['sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='],
          ),
        ]),
      );
      expect(worker.toMap().containsKey('certificatePinning'), isTrue);
    });
  });

  group('every HTTP-ish worker propagates certificatePinning', () {
    // Guards against the exact shape of gap this feature started as: the
    // native-side config field existed on some workers and not others, with
    // no Dart field on any of them. One test per worker so a future worker
    // added to this family without wiring pinning is a visible gap, not a
    // silent one.
    final pinning = CertificatePinning([
      CertificatePin(
        hostname: 'api.example.com',
        sha256Pins: ['sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='],
      ),
    ]);

    test('HttpDownloadWorker', () {
      final worker = HttpDownloadWorker(
        url: 'https://api.example.com/file',
        savePath: '/tmp/file',
        certificatePinning: pinning,
      );
      expect(worker.toMap().containsKey('certificatePinning'), isTrue);
    });

    test('HttpUploadWorker', () {
      final worker = HttpUploadWorker(
        url: 'https://api.example.com/upload',
        filePath: '/tmp/file',
        certificatePinning: pinning,
      );
      expect(worker.toMap().containsKey('certificatePinning'), isTrue);
    });

    test('HttpSyncWorker', () {
      final worker = HttpSyncWorker(
        url: 'https://api.example.com/sync',
        certificatePinning: pinning,
      );
      expect(worker.toMap().containsKey('certificatePinning'), isTrue);
    });

    test('ParallelHttpDownloadWorker', () {
      final worker = ParallelHttpDownloadWorker(
        url: 'https://api.example.com/file',
        savePath: '/tmp/file',
        certificatePinning: pinning,
      );
      expect(worker.toMap().containsKey('certificatePinning'), isTrue);
    });

    test('ParallelHttpUploadWorker', () {
      final worker = ParallelHttpUploadWorker(
        url: 'https://api.example.com/upload',
        files: [UploadFile(filePath: '/tmp/file')],
        certificatePinning: pinning,
      );
      expect(worker.toMap().containsKey('certificatePinning'), isTrue);
    });

    test('WebSocketWorker', () {
      final worker = WebSocketWorker(
        url: 'wss://api.example.com/ws',
        certificatePinning: pinning,
      );
      expect(worker.toMap().containsKey('certificatePinning'), isTrue);
    });
  });
}
