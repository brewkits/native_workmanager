package dev.brewkits.native_workmanager_example

import androidx.test.rule.ActivityTestRule
import dev.flutter.plugins.integration_test.FlutterTestRunner
import org.junit.Rule
import org.junit.runner.RunWith

/**
 * Wraps whichever `integration_test` Dart entrypoint was baked into the app
 * APK (via `flutter build apk --target=integration_test/<file>.dart`) as an
 * Android instrumentation test, so it can run on Firebase Test Lab.
 *
 * See `scripts/firebase-ftl-cancellation.sh` (issue #66/#69) and
 * `scripts/firebase-benchmark.sh` (weekly benchmark) for the two Dart
 * entrypoints this wrapper is used to drive.
 */
@RunWith(FlutterTestRunner::class)
class MainActivityTest {
    @Rule
    @JvmField
    val rule = ActivityTestRule(MainActivity::class.java, false, false)
}
