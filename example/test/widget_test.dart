import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for MethodChannel
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart'; // Import NativeWorkManager
import 'package:native_workmanager_example/main.dart';

// Define mock Dart worker callbacks for the test environment
@pragma('vm:entry-point')
Future<bool> customTaskCallback(Map<String, dynamic>? input) async => true;
@pragma('vm:entry-point')
Future<bool> heavyTaskCallback(Map<String, dynamic>? input) async => true;
@pragma('vm:entry-point')
Future<bool> benchHeavyComputeCallback(Map<String, dynamic>? input) async =>
    true;

void main() {
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Mock the MethodChannel for NativeWorkManager
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.brewkits/native_workmanager'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') {
          return null; // Return null for success
        }
        // You might need to mock other methods if your tests call them
        return null;
      },
    );

    await NativeWorkManager.initialize(
      dartWorkers: {
        'customTask': customTaskCallback,
        'heavyTask': heavyTaskCallback,
        'benchHeavyCompute': benchHeavyComputeCallback,
      },
    );
  });

  testWidgets('Verify Platform version', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that platform version is retrieved.
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text && widget.data!.contains('Native WorkManager v1.0.0 initialized'),
      ),
      findsOneWidget,
    );
  });
}
