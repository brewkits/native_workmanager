import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../worker.dart';

/// Custom native worker configuration.
///
/// Allows users to register and use their own native worker implementations
/// without modifying the plugin source code.
@immutable
final class CustomNativeWorker extends Worker {
  CustomNativeWorker({
    required this.className,
    this.input,
  }) {
    if (className.isEmpty) {
      throw ArgumentError.value(
        className,
        'className',
        'className cannot be empty. Provide the name of your custom worker class.',
      );
    }
    // Validate className format: only letters, digits, dots, underscores, and dollar signs.
    // Prevents injection of shell metacharacters or class-loading tricks.
    // Android: "com.example.MyWorker" — iOS: "MyWorker" or "MyModule.MyWorker"
    final validPattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9._$]*$');
    if (!validPattern.hasMatch(className)) {
      throw ArgumentError.value(
        className,
        'className',
        'className contains invalid characters. Use letters, digits, dots, underscores, '
        'or dollar signs only (e.g. "com.example.MyWorker" or "MyWorker").',
      );
    }
    // Guard against excessively long class names (> 256 chars is unrealistic and may indicate abuse).
    if (className.length > 256) {
      throw ArgumentError.value(
        className,
        'className',
        'className exceeds maximum allowed length of 256 characters.',
      );
    }
  }

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
