import 'package:flutter/foundation.dart';

/// SHA-256 pins for one hostname's TLS certificate chain.
///
/// A pin is the base64 SHA-256 of a certificate's **SubjectPublicKeyInfo**, in
/// the `sha256/BASE64` form OkHttp, TrustKit, openssl and most pin-generating
/// tools use. Pinning the public key rather than the whole certificate is what
/// lets a server renew its certificate — same key, new expiry — without
/// shipping an app update.
///
/// ```dart
/// NativeWorker.httpRequest(
///   url: 'https://api.example.com/data',
///   certificatePinning: CertificatePinning([
///     CertificatePin(
///       hostname: 'api.example.com',
///       sha256Pins: [
///         'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', // current
///         'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=', // backup
///       ],
///     ),
///   ]),
/// )
/// ```
///
/// ### Always ship a backup pin
///
/// This is the failure that makes teams abandon pinning, and it is not
/// recoverable remotely: pin only the key you are using today, rotate that
/// key (or have your CA rotate it for you), and every installed copy of the
/// app loses the ability to reach the server — there is no server-side fix,
/// because the app will not talk to the server. Pin at least one key you are
/// not using yet — typically the intermediate CA, or a backup key held
/// offline — and treat the pin list as something that must be updated
/// *before* a rotation, not after.
///
/// Reaching the pinned host is also the only way to find out the pins are
/// wrong, so verify against a build that actually performs a request before
/// shipping.
@immutable
final class CertificatePin {
  /// Creates a pin entry for [hostname].
  ///
  /// Throws [ArgumentError] if [hostname] is blank, [sha256Pins] is empty, or
  /// any entry does not start with `sha256/` — each is an unambiguous misuse
  /// that would silently reject every connection to this host, not a
  /// legitimate combination the platform could otherwise handle.
  CertificatePin({required this.hostname, required this.sha256Pins}) {
    if (hostname.trim().isEmpty) {
      throw ArgumentError.value(hostname, 'hostname', 'cannot be blank');
    }
    if (sha256Pins.isEmpty) {
      throw ArgumentError.value(
        sha256Pins,
        'sha256Pins',
        'cannot be empty — a pin entry with no pins would reject every '
            'connection to $hostname',
      );
    }
    for (final pin in sha256Pins) {
      if (!pin.startsWith(_pinPrefix)) {
        throw ArgumentError.value(
          pin,
          'sha256Pins',
          "must start with '$_pinPrefix' — the value is the base64 SHA-256 "
              'of the SubjectPublicKeyInfo, not of the whole certificate '
              'and not hex',
        );
      }
      if (pin.length <= _pinPrefix.length) {
        throw ArgumentError.value(
            pin, 'sha256Pins', 'has no digest after the prefix');
      }
    }
  }

  static const _pinPrefix = 'sha256/';

  /// Host to pin, e.g. `api.example.com`. Matched exactly on iOS; on Android
  /// OkHttp additionally supports a `*.` wildcard prefix.
  final String hostname;

  /// One or more `sha256/BASE64` pins. Any single match accepts the chain.
  final List<String> sha256Pins;
}

/// TLS certificate pinning for one worker's requests.
///
/// **Opt-in, and that is load-bearing.** A worker that never sets this uses
/// the platform's normal certificate validation, unaffected — this is not a
/// process-wide switch, and pinning one host leaves every other host,
/// including other hosts this same worker's redirects might visit, on
/// default validation.
///
/// Pinning is **additional to** the system's own chain validation, never a
/// replacement for it: on both Android (OkHttp's `CertificatePinner`) and iOS
/// (a `URLSessionDelegate` that checks the pin and then defers to
/// `performDefaultHandling`), a matching pin still results in the OS
/// performing its own expiry, hostname and trust-store checks.
///
/// See [CertificatePin] before using this — in particular, ship a backup pin.
@immutable
final class CertificatePinning {
  /// Pins one or more hosts. Hosts absent from [pins] are not pinned.
  const CertificatePinning(this.pins);

  final List<CertificatePin> pins;

  /// Convert to the wire format both platform bridges parse:
  /// `{"pins": {"<hostname>": ["sha256/...", ...]}}`.
  Map<String, dynamic> toMap() => {
        'pins': {for (final pin in pins) pin.hostname: pin.sha256Pins},
      };
}
