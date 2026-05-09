import 'package:flutter/foundation.dart';

/// Configuration for the mandatory system notification displayed when a task
/// runs as a Foreground Service (FGS) on Android.
///
/// Android requires all foreground services to show a notification to inform
/// the user that the app is performing a background task. This class allows
/// you to customize the appearance and behavior of that notification.
///
/// **Note:** This configuration is only used on Android. iOS does not support
/// Foreground Services and handles background execution differently.
@immutable
class ForegroundNotificationConfig {
  /// The title of the notification (e.g., 'Uploading Video').
  final String title;

  /// The main text content of the notification (e.g., 'Please do not close the app').
  final String body;

  /// The name of the drawable resource in the Android project's `res/drawable` folder.
  /// Example: 'ic_notification_upload' (without the .xml or .png extension).
  ///
  /// If null, the plugin will attempt to use the app's default launcher icon.
  final String? iconName;

  /// Hex color code for the notification icon background (e.g., '#FF0000').
  /// This is used on modern Android versions to tint the icon.
  final String? colorHex;

  /// Whether to show a 'Cancel' action button directly on the notification.
  /// Clicking this button will immediately cancel the background task via WorkManager.
  final bool showCancelButton;

  /// The text to display on the cancel button (e.g., 'Cancel').
  /// Defaults to 'Cancel'.
  final String cancelText;

  const ForegroundNotificationConfig({
    required this.title,
    required this.body,
    this.iconName,
    this.colorHex,
    this.showCancelButton = true,
    this.cancelText = 'Cancel',
  });

  /// Converts the configuration to a Map for serialization to the native bridge.
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      if (iconName != null) 'iconName': iconName,
      if (colorHex != null) 'colorHex': colorHex,
      'showCancelButton': showCancelButton,
      'cancelText': cancelText,
    };
  }

  /// Creates a configuration from a Map.
  factory ForegroundNotificationConfig.fromMap(Map<String, dynamic> map) {
    return ForegroundNotificationConfig(
      title: map['title'] as String? ?? 'Background Task',
      body: map['body'] as String? ?? 'Running...',
      iconName: map['iconName'] as String?,
      colorHex: map['colorHex'] as String?,
      showCancelButton: map['showCancelButton'] as bool? ?? true,
      cancelText: map['cancelText'] as String? ?? 'Cancel',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ForegroundNotificationConfig &&
        other.title == title &&
        other.body == body &&
        other.iconName == iconName &&
        other.colorHex == colorHex &&
        other.showCancelButton == showCancelButton &&
        other.cancelText == cancelText;
  }

  @override
  int get hashCode => Object.hash(
        title,
        body,
        iconName,
        colorHex,
        showCancelButton,
        cancelText,
      );

  @override
  String toString() {
    return 'ForegroundNotificationConfig(title: $title, body: $body, iconName: $iconName, colorHex: $colorHex, showCancelButton: $showCancelButton)';
  }
}
