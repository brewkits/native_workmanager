# CI/CD Infrastructure Guide

This document explains the automated pipeline configured for `native_workmanager` using GitHub Actions.

## Workflow: Native WorkManager CI

Located at: `.github/workflows/native_workmanager_ci.yml`

### Jobs and Steps

1.  **Dart Linting & Unit Tests (ubuntu-latest)**
    *   Analyzes code for potential bugs and style violations.
    *   Runs 500+ unit and integration tests using `FakeWorkManager`.
    *   **Blocking:** Failure here stops the build validation for Android/iOS.

2.  **Build Validation (Android)**
    *   Runs an actual Gradle build in the `example/` project.
    *   Verifies that the Kotlin code, Koin isolation, and ProGuard rules are correct.

3.  **Build Validation (iOS)**
    *   Runs an `xcodebuild` in the `example/` project.
    *   Verifies that the Swift code, SQLite stores, and Podspec are correctly configured.

## Best Practices for Developers

- **Pre-commit Check:** Always run `flutter analyze` and `flutter test` locally before pushing code.
- **Breaking Changes:** If you modify a Native API, ensure you update the corresponding `FakeWorkManager` implementation in `lib/testing.dart` to keep the CI green.
- **Hot Restarts:** The CI specifically checks for "Bridge accumulation" (memory leaks) during hot restarts—ensure any new EventChannels are properly disposed.

---

# Test Coverage Report

Measuring how much of the codebase is exercised by tests is critical for long-term maintainability.

## Local Coverage Generation

1.  **Install LCOV** (macOS):
    ```bash
    brew install lcov
    ```

2.  **Run Tests with Coverage**:
    ```bash
    flutter test --coverage
    ```

3.  **Generate HTML Report**:
    ```bash
    genhtml coverage/lcov.info -o coverage/html
    ```

4.  **View Report**:
    Open `coverage/html/index.html` in your browser.

## CI Integration (Roadmap)

We recommend integrating with **Codecov** or **Coveralls**:
1.  Add `CODECOV_TOKEN` to GitHub Secrets.
2.  Add a step in the CI YAML:
    ```yaml
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v4
      with:
        token: ${{ secrets.CODECOV_TOKEN }}
    ```

## Coverage Targets

- **Core Logic (`lib/src/`):** > 90%
- **Native Bridges:** Verified via integration tests.
- **Workers:** Each worker must have at least one success and one failure test case.
