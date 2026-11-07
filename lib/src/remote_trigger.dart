import 'package:flutter/foundation.dart';
import 'worker.dart';

/// Sources for remote triggers.
enum RemoteTriggerSource {
  /// Firebase Cloud Messaging (Android/iOS)
  fcm,

  /// Apple Push Notification service (iOS only)
  apns,
}

/// A rule for matching and executing a remote trigger.
///
/// When a remote message arrives, the plugin looks for a field
/// in the payload named [payloadKey]. If the value of that field matches
/// a key in [workerMappings], the corresponding worker is enqueued.
///
/// Use `{{key}}` syntax in worker parameters to substitute values from the
/// remote payload.
@immutable
class RemoteTriggerRule {
  /// Create a rule for matching remote triggers.
  const RemoteTriggerRule({
    required this.payloadKey,
    required this.workerMappings,
    this.secretKey,
    this.rejectUnsignedCommands = false,
  });

  /// The key in the remote message payload to look for.
  ///
  /// For example, if your FCM data is `{"type": "download_update"}`,
  /// set [payloadKey] to `"type"`.
  final String payloadKey;

  /// Map of payload values to their corresponding worker templates.
  ///
  /// For example:
  /// ```dart
  /// workerMappings: {
  ///   'download_update': NativeWorker.httpDownload(
  ///     url: '{{url}}', // Substitutes from payload['url']
  ///     savePath: '{{path}}',
  ///   ),
  /// }
  /// ```
  final Map<String, Worker> workerMappings;

  /// Optional secret key for HMAC SHA-256 signature verification.
  ///
  /// If provided, the plugin will verify that the remote payload contains
  /// a valid `x-native-wm-signature` header/key computed using this secret.
  /// This prevents malicious actors from spoofing pushes to drain battery.
  ///
  /// Prefer the **v2** scheme (`v2=<hex>` + `x-native-wm-timestamp` +
  /// `x-native-wm-nonce`): it rejects replayed and stale messages and uses a
  /// collision-free canonical form. The bare-hex v1 form is still accepted but
  /// deprecated. See `doc/REMOTE_TRIGGER_SIGNING.md`.
  ///
  /// Without a secret, `native_wm` direct commands are accepted unauthenticated.
  final String? secretKey;

  /// When `true` and this rule has **no** [secretKey], `native_wm` direct commands arriving for
  /// this source are rejected instead of executed.
  ///
  /// Default `false` keeps the historical behaviour (unsigned commands are accepted, with a
  /// warning in the log). Set it to `true` if you only use rule-based mappings and never send
  /// `native_wm` commands unsigned. Has no effect when a [secretKey] is set (signatures are
  /// always enforced then).
  final bool rejectUnsignedCommands;

  /// Convert to a map for the platform channel.
  Map<String, dynamic> toMap() {
    return {
      'payloadKey': payloadKey,
      'workerMappings': workerMappings.map((key, worker) => MapEntry(key, {
            'workerClassName': worker.workerClassName,
            'workerConfig': worker.toMap(),
          })),
      if (secretKey != null) 'secretKey': secretKey,
      if (rejectUnsignedCommands) 'rejectUnsignedCommands': true,
    };
  }
}
