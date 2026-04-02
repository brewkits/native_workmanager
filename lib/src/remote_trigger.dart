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
/// When a remote message arrives from [source], the plugin looks for a field
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

  /// Convert to a map for the platform channel.
  Map<String, dynamic> toMap() {
    return {
      'payloadKey': payloadKey,
      'workerMappings': workerMappings.map((key, worker) => MapEntry(key, {
            'workerClassName': worker.workerClassName,
            'workerConfig': worker.toMap(),
          })),
    };
  }
}
