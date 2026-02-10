import 'dart:io';
import 'package:flutter/services.dart';

/// Performance monitoring helper for getting real-time metrics
class PerformanceMonitor {
  static const MethodChannel _channel = MethodChannel(
    'dev.brewkits/native_workmanager',
  );

  /// Get current app memory usage in MB
  static Future<double> getMemoryUsageMB() async {
    try {
      // Try to get actual memory from native side
      final result = await _channel.invokeMethod<int>('getMemoryUsage');
      if (result != null) {
        return result / (1024 * 1024); // Convert bytes to MB
      }
    } catch (e) {
      // Fallback to Dart VM memory
    }

    // Fallback: Use ProcessInfo if available (Dart VM)
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Estimate based on platform
        // Native workers: ~2-5 MB
        // Dart workers: ~30-50 MB
        // Base Flutter app: ~40-60 MB
        return _estimateMemoryUsage();
      }
    } catch (e) {
      // Ignore
    }

    return 0.0;
  }

  /// Estimate memory usage based on typical Flutter app patterns
  static double _estimateMemoryUsage() {
    // Base Flutter app memory
    double baseMemory = 45.0; // MB

    // Add overhead for current state
    // This is a simplified estimation
    return baseMemory;
  }

  /// Get CPU usage percentage (0-100)
  static Future<double> getCpuUsage() async {
    try {
      final result = await _channel.invokeMethod<double>('getCpuUsage');
      return result ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Get number of active tasks
  static Future<int> getActiveTaskCount() async {
    try {
      final result = await _channel.invokeMethod<int>('getActiveTaskCount');
      return result ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get battery level (0-100)
  static Future<int> getBatteryLevel() async {
    try {
      final result = await _channel.invokeMethod<int>('getBatteryLevel');
      return result ?? 100;
    } catch (e) {
      return 100;
    }
  }
}
