import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:native_workmanager/src/method_channel.dart';
import 'package:native_workmanager/src/platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelNativeWorkManager Session Management', () {
    late MethodChannelNativeWorkManager platform;
    const MethodChannel channel = MethodChannel('dev.brewkits/native_workmanager');
    const EventChannel eventChannel = EventChannel('dev.brewkits/native_workmanager/events');
    const EventChannel progressChannel = EventChannel('dev.brewkits/native_workmanager/progress');

    // Helper to simulate native event emission
    void emitNativeEvent(Map<String, dynamic> data) {
      ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        eventChannel.name,
        const StandardMethodCodec().encodeSuccessEnvelope(data),
        (_) {},
      );
    }

    void emitNativeProgress(Map<String, dynamic> data) {
      ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        progressChannel.name,
        const StandardMethodCodec().encodeSuccessEnvelope(data),
        (_) {},
      );
    }

    setUp(() {
      platform = MethodChannelNativeWorkManager();
      
      // Mock the initialize method on the method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') {
          return null;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      platform.dispose();
    });

    test('should drop zombie events from previous sessions', () async {
      final startTime = DateTime.now().millisecondsSinceEpoch;
      await platform.initialize();

      final events = <TaskEvent>[];
      final subscription = platform.events.listen(events.add);

      // 1. Emit an event with a timestamp BEFORE initialization (Zombie)
      emitNativeEvent({
        'taskId': 'zombie-task',
        'success': true,
        'timestamp': startTime - 1000, // 1 second before
      });

      // 2. Emit a valid event with a timestamp AFTER initialization
      emitNativeEvent({
        'taskId': 'fresh-task',
        'success': true,
        'timestamp': startTime + 1000, // 1 second after
      });

      // Give it a microtask to process
      await Future.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first.taskId, 'fresh-task');
      
      await subscription.cancel();
    });

    test('should drop zombie progress updates from previous sessions', () async {
      final startTime = DateTime.now().millisecondsSinceEpoch;
      await platform.initialize();

      final updates = <TaskProgress>[];
      final subscription = platform.progress.listen(updates.add);

      // 1. Emit progress with timestamp BEFORE initialization
      emitNativeProgress({
        'taskId': 'zombie-task',
        'progress': 50,
        'timestamp': startTime - 500,
      });

      // 2. Emit valid progress
      emitNativeProgress({
        'taskId': 'fresh-task',
        'progress': 50,
        'timestamp': startTime + 500,
      });

      await Future.delayed(Duration.zero);

      expect(updates.length, 1);
      expect(updates.first.taskId, 'fresh-task');

      await subscription.cancel();
    });

    test('should cancel old subscriptions on re-initialization (Hot Restart simulation)', () async {
      await platform.initialize();
      
      int eventCount = 0;
      final sub1 = platform.events.listen((_) => eventCount++);

      // Re-initialize (simulating hot restart or engine re-attach)
      await platform.initialize();
      
      final sub2 = platform.events.listen((_) => eventCount++);

      // Emit one event
      emitNativeEvent({
        'taskId': 'test-task',
        'success': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch + 1000,
      });

      await Future.delayed(Duration.zero);

      // If cleanup works, ONLY the new subscription should trigger.
      // If it leaks, BOTH would trigger, resulting in eventCount = 2.
      expect(eventCount, 1, reason: 'Old subscription should have been cancelled');

      await sub1.cancel();
      await sub2.cancel();
    });
  });
}
