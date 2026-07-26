# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.4.4] - 2026-07-26

- Version bump synchronized with `native_workmanager` 1.4.4 (Fix DevTools extension packaging #55).

---

## [1.4.3] - 2026-07-17

- Version bump synchronized with `native_workmanager` 1.4.3. No codegen changes —
  the 1.4.3 fix (iOS SwiftPM manifest: test target outside the package root) is
  entirely in the main package's `Package.swift`.

---

## [1.4.2] - 2026-07-17

- Version bump synchronized with `native_workmanager` 1.4.2. No codegen changes — the
  1.4.2 fixes (iOS SwiftPM hyphenated library product #52, explicit UIKit imports)
  are entirely in the main package's iOS build configuration and Swift sources.

---

## [1.4.1] - 2026-07-16

- Version bump synchronized with `native_workmanager` 1.4.1. No codegen changes — the
  1.4.1 fixes (iOS Swift Package Manager remote binary target #49, Android
  `CancellationException` handling, `work-runtime-ktx` 2.11.2) are runtime/build-only and
  do not affect `@WorkerCallback` code generation.

## [1.4.0] - 2026-07-16

- Version bump synchronized with `native_workmanager` 1.4.0. No codegen changes — the
  1.4.0 changes (DartWorker retry-on-false and `Constraints.maxRetries` enforcement via
  kmpworkmanager 3.1.0) are runtime-only and do not affect `@WorkerCallback` code generation.

## [1.3.3] - 2026-07-14

- Version bump synchronized with `native_workmanager` 1.3.3. No codegen changes — the
  1.3.3 fixes (DartWorker progress events and persisted TaskStore status, #38/#39) are
  runtime-only and do not affect `@WorkerCallback` code generation.

## [1.3.2] - 2026-07-07

- Version bump synchronized with `native_workmanager` 1.3.2. No codegen changes — the
  1.3.2 fixes (iOS BGTask launch-window crash, kmpworkmanager core upgrade) are runtime-only
  and do not affect `@WorkerCallback` code generation.

## [1.3.1] - 2026-06-07

- Version bump synchronized with `native_workmanager` 1.3.1.

## [1.3.0] - 2026-06-04

### Changed
- Version bump synchronized with `native_workmanager` 1.3.0.

## [1.2.7] - 2026-05-11

- Synchronized version bump with `native_workmanager` 1.2.7.

## [1.2.6] - 2026-05-08

- Synchronized version bump with `native_workmanager` 1.2.6.

## [1.2.5] - 2026-05-06

### Changed
- Version bump to match `native_workmanager` 1.2.5 release.

---

## [1.2.3] - 2026-04-24

### Changed
- Version bump to match `native_workmanager` 1.2.3 release.

---

## [1.0.4] - 2026-04-20

### Fixed
- Widened `analyzer` constraint from `^12.0.0` to `>=10.0.0 <13.0.0` to resolve
  `meta` version conflict on Flutter 3.41.x (`analyzer 10.x` requires `meta ^1.15.0`).
- Replaced deprecated `getDisplayString(withNullability: false)` with `getDisplayString()`.

---

## [1.0.3]

### Changed
- Require `analyzer >=12.0.0` and Dart SDK `>=3.9.0`.
- Replaced `FunctionElement` (removed in analyzer 12.x) with `ElementKind.FUNCTION` check
  and `TopLevelFunctionElement` cast.
- Replaced `element.parameters` with `fn.formalParameters` (renamed in analyzer 12.x).
- Replaced `element.name` with `element.displayName` (now `String?` in analyzer 12.x).

---

## [1.0.2]

### Fixed
- Replaced `TypeChecker.fromRuntime` (removed in source_gen 4.x) with `TypeChecker.fromUrl` —
  removes `dart:mirrors` dependency and fixes static analysis on pub.dev.
- Removed `native_workmanager` from runtime dependencies (only needed at build time via URI).

---

## [1.0.1]

### Changed
- Widened dependency constraints: `build <5`, `source_gen <5`, `analyzer <13`, `build_runner <4`.

### Added
- Dartdoc to `workerCallbackBuilder` and `WorkerCallbackGenerator` constructor.
- Example demonstrating codegen setup.

---

## [1.0.0]

### Added
- Initial release: `@WorkerCallback` annotation code generator for `native_workmanager`.
- Generates type-safe callback IDs and worker registry from annotated top-level functions.
- Validates callback signature (`Future<bool>` return type, `String?` parameter).
