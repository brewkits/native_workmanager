## 1.0.2

- Replace `TypeChecker.fromRuntime` (removed in source_gen 4.x) with `TypeChecker.fromUrl`
  — removes `dart:mirrors` dependency and fixes static analysis on pub.dev.
- Remove `native_workmanager` from runtime dependencies (only needed at build time via URI).

## 1.0.1

- Widen dependency constraints: `build <5`, `source_gen <5`, `analyzer <13`, `build_runner <4`.
- Add dartdoc to `workerCallbackBuilder` and `WorkerCallbackGenerator` constructor.
- Add example demonstrating codegen setup.

## 1.0.0

- Initial release: `@WorkerCallback` annotation code generator for `native_workmanager`.
- Generates type-safe callback IDs and worker registry from annotated top-level functions.
- Validates callback signature (`Future<bool>` return type, `String?` parameter).
