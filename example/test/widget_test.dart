import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';
import 'package:native_workmanager_example/main.dart';

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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.brewkits/native_workmanager'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'initialize') {
              return null;
            }
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

  testWidgets('Verify Home Page Title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that the initial page title is shown.
    expect(find.text('Quick Demo'), findsAtLeast(1));
  });
}
