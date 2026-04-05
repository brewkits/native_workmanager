part of '../worker.dart';

/// Custom native worker for user-defined implementations.
///
/// Allows users to implement their own native workers (in Kotlin/Swift)
/// without modifying the plugin source code. This is the extensibility
/// escape hatch for advanced use cases not covered by built-in workers.
///
/// ## Prerequisites
///
/// **You must implement the native worker first:**
///
/// **Android (Kotlin):**
/// ```kotlin
/// package com.myapp.workers
///
/// import dev.brewkits.kmpworkmanager.background.domain.AndroidWorker
///
/// class ImageCompressWorker : AndroidWorker {
///     override suspend fun doWork(input: String?): Boolean {
///         // Parse input JSON
///         val config = parseJson(input)
///         val imagePath = config["imagePath"] as String
///
///         // Compress image (native code)
///         compressImage(imagePath, quality = 85)
///
///         return true
///     }
/// }
/// ```
///
/// **iOS (Swift):**
/// ```swift
/// import Foundation
///
/// class ImageCompressWorker: IosWorker {
///     func doWork(input: String?) async throws -> Bool {
///         // Parse input JSON
///         let config = parseJson(input)
///         let imagePath = config["imagePath"]
///
///         // Compress image (native code)
///         compressImage(imagePath, quality: 85)
///
///         return true
///     }
/// }
/// ```
///
/// ## Registration
///
/// **Android:** Register in `MainActivity.kt` before `initialize()`:
/// ```kotlin
/// NativeWorkManager.registerWorkerFactory { className ->
///     when (className) {
///         "ImageCompressWorker" -> ImageCompressWorker()
///         else -> null
///     }
/// }
/// ```
///
/// **iOS:** Register in `AppDelegate.swift`:
/// ```swift
/// NativeWorkManager.registerWorker(
///     className: "ImageCompressWorker",
///     factory: { ImageCompressWorker() }
/// )
/// ```
///
/// ## Dart Usage
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'compress-photo',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.custom(
///     className: 'ImageCompressWorker',
///     input: {
///       'imagePath': '/storage/photo.jpg',
///       'quality': 85,
///       'outputPath': '/storage/compressed.jpg',
///     },
///   ),
/// );
/// ```
///
/// ## Parameters
///
/// **[className]** *(required)* - The worker class name.
/// - Must match the class name you implemented in Kotlin/Swift
/// - Must be registered before calling enqueue
/// - Case-sensitive exact match
///
/// **[input]** *(optional)* - Configuration data for the worker.
/// - Will be JSON encoded and passed to `doWork(input)`
/// - Can contain any JSON-serializable data
///
/// ## When to Use
///
/// ✅ **Use CustomNativeWorker when:**
/// - You need native processing not covered by built-in workers
/// - Image/video compression, encoding, encryption
/// - Native database operations (Room, Core Data)
/// - Platform-specific APIs (camera, sensors, etc.)
/// - You want maximum performance (native execution)
///
/// ❌ **Don't use CustomNativeWorker when:**
/// - Built-in workers already cover your use case
/// - Simple HTTP operations → Use built-in HTTP workers
/// - You need Dart/Flutter APIs → Use `DartWorker` instead
///
/// ## Performance
///
/// - RAM: ~2-5MB (same as built-in native workers)
/// - Startup: <50ms (no Flutter Engine)
/// - Same benefits as built-in native workers
///
/// ## See Also
///
/// - [DartWorker] - For Dart-based custom logic
/// - Built-in workers: [NativeWorker.httpRequest], [NativeWorker.httpUpload],
///   [NativeWorker.httpDownload], [NativeWorker.httpSync]
Worker _buildCustom({
  required String className,
  Map<String, dynamic>? input,
}) {
  if (className.isEmpty) {
    throw ArgumentError(
      'className cannot be empty.\n'
      'Provide the name of your custom worker class (e.g., "ImageCompressWorker")',
    );
  }

  return CustomNativeWorker(className: className, input: input);
}
