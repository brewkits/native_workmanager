import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../worker.dart';

/// Custom native worker configuration.
///
/// Allows users to register and use their own native worker implementations
/// without modifying the plugin source code.
@immutable
final class CustomNativeWorker extends Worker {
  const CustomNativeWorker({
    required this.className,
    this.input,
  }) : assert(
          className.length > 0,
          'className cannot be empty. '
          'Provide the name of your custom worker class.',
        );

  /// The native worker class name (must be registered on native side).
  final String className;

  /// Optional input data (will be JSON encoded).
  final Map<String, dynamic>? input;

  @override
  String get workerClassName => className;

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'custom',
        'className': className,
        'input': input != null ? jsonEncode(input) : null,
      };
}
