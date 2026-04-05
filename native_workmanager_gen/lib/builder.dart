import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/worker_callback_generator.dart';

/// Entry point registered in build.yaml.
///
/// Generates a `.g.dart` part file for every library that contains functions
/// annotated with `@WorkerCallback`.
Builder workerCallbackBuilder(BuilderOptions options) => SharedPartBuilder(
      [WorkerCallbackGenerator()],
      'worker_callback',
    );
