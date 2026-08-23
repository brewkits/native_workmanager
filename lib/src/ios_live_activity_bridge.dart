import 'dart:async';
import 'package:flutter/foundation.dart';
import 'events.dart';
import 'platform_interface.dart';

/// Dart-side helper for feeding background task progress into an iOS
/// Live Activity / Dynamic Island.
///
/// ### What this actually is
///
/// This is a thin convenience filter over the plugin's existing progress
/// EventChannel — the same stream [NativeWorkManager.progress] exposes — scoped
/// to a single `taskId` so a Live Activity can subscribe to just the task it
/// renders. It does **not** talk to the KMP `IosLiveActivityBridge` in
/// `KMPWorkManager.xcframework`, and it does **not** call ActivityKit: starting,
/// updating and ending the `Activity<Attributes>` stays your app's job, because
/// the `ActivityAttributes` type lives in your target, not in this plugin.
///
/// Use this when the Flutter side owns the progress and pushes it to a Live
/// Activity through your own platform channel or an app-side Swift helper.
///
/// ### Dart usage
/// ```dart
/// NativeWorkManager.iosLiveActivity
///     .onProgress(taskId: 'download_video_1')
///     .listen((progress) {
///   // Forward to your own ActivityKit code.
///   print('Progress: ${progress.progress}%');
/// });
/// ```
///
/// ### Pure-Swift alternative
///
/// If the progress never needs to reach Dart, skip this class entirely and
/// observe the KMP bridge directly from your iOS target — it runs even when no
/// Flutter engine is attached, which is the better fit for a killed-app
/// background download:
/// ```swift
/// import KMPWorkManager
///
/// // Kotlin/Native exposes the singleton through the Companion object, so it is
/// // `.companion.shared` — a bare `IosLiveActivityBridge.shared` does not compile.
/// let bridge = IosLiveActivityBridge.companion.shared
///
/// bridge.startObserving(taskId: "download_video_1") { progress in
///     // Update Activity<Attributes>(contentState: ...)
/// }
/// // Later:
/// bridge.stopObserving(taskId: "download_video_1")
/// ```
class IosLiveActivityBridge {
  /// Const constructor for [IosLiveActivityBridge].
  const IosLiveActivityBridge();

  /// Whether Live Activities are available on the current platform (iOS only).
  ///
  /// When this is `false`, [onProgress] returns an already-closed stream.
  bool get isSupported => defaultTargetPlatform == TargetPlatform.iOS;

  /// Returns a stream of [TaskProgress] updates for the specified [taskId].
  ///
  /// If [taskId] is omitted or null, returns all background task progress
  /// updates — identical to [NativeWorkManager.progress].
  ///
  /// **On non-iOS platforms this returns an empty, already-closed stream** —
  /// listeners get `onDone` immediately and never receive an event. This class
  /// is an iOS Live Activity helper; for cross-platform progress use
  /// [NativeWorkManager.progress] (or [TaskHandler.progress]) instead, which
  /// works on every platform.
  Stream<TaskProgress> onProgress({String? taskId}) {
    if (!isSupported) {
      return const Stream.empty();
    }
    final stream = NativeWorkManagerPlatform.instance.progress;
    if (taskId == null) {
      return stream;
    }
    return stream.where((p) => p.taskId == taskId);
  }
}
