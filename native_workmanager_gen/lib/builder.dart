import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/worker_callback_generator.dart';

/// Creates the [WorkerCallbackGenerator] builder registered in `build.yaml`.
///
/// Generates a `.g.dart` part file for every Dart library that contains
/// top-level functions annotated with `@WorkerCallback`.
///
/// This function is the entry point invoked by `build_runner` — it is not
/// called directly by application code.
Builder workerCallbackBuilder(BuilderOptions options) => SharedPartBuilder(
      [WorkerCallbackGenerator()],
      'worker_callback',
    );
