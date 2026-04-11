# native_workmanager_gen

Code generator for [native_workmanager](https://pub.dev/packages/native_workmanager).

Generates type-safe Dart callback IDs and a worker registry from `@WorkerCallback` annotations, eliminating manual string registration and enabling compile-time validation.

## Installation

```yaml
dev_dependencies:
  native_workmanager_gen: ^1.0.3
  build_runner: ^2.4.0
```

## Usage

Annotate your top-level background callback functions:

```dart
import 'package:native_workmanager/native_workmanager.dart';

@WorkerCallback('uploadSync')
Future<bool> uploadSyncCallback(String? inputData) async {
  // background work
  return true;
}
```

Run the code generator:

```sh
dart run build_runner build
```

This generates a `workers.g.dart` file with type-safe callback IDs.

## Additional information

- [native_workmanager on pub.dev](https://pub.dev/packages/native_workmanager)
- [Source code](https://github.com/brewkits/native_workmanager/tree/main/native_workmanager_gen)
- [Issue tracker](https://github.com/brewkits/native_workmanager/issues)
