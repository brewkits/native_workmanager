## 1.0.4

- Widen `analyzer` constraint from `^12.0.0` to `>=10.0.0 <13.0.0` so that
  Flutter projects whose SDK pins `meta` to `1.17.0` (e.g. Flutter 3.41.x)
  can resolve the dependency without conflict — `analyzer 10.x` requires
  `meta ^1.15.0` which satisfies the pin.
- Fix deprecation: replace `getDisplayString(withNullability: false)` with
  `getDisplayString()` (the `withNullability` parameter was deprecated across
  all supported analyzer versions).

## 1.0.3

- Require analyzer `>=12.0.0` and Dart SDK `>=3.9.0` to match pub.dev analysis
  environment and gain access to stable analyzer 12.x APIs.
- Replace `FunctionElement` (removed in analyzer 12.x / Dart 3.11+) with
  `ElementKind.FUNCTION` check and `TopLevelFunctionElement` cast.
- Replace `element.parameters` (renamed to `formalParameters` in analyzer 12.x)
  with `fn.formalParameters` throughout validation logic.
- Replace `element.name` (now `String?` in analyzer 12.x) with
  `element.displayName` (always non-null `String`) throughout.
- Drop redundant `enclosingElement is! LibraryElement` guard — annotated
  top-level functions always satisfy `kind == ElementKind.FUNCTION`.

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
