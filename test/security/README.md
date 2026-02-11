# Security Test Suite

This directory contains security-focused tests to ensure the library properly validates inputs and protects against common vulnerabilities.

## Test Categories

### 1. URL Validation Tests (`url_validation_test.dart`)

Tests that URL scheme validation prevents SSRF (Server-Side Request Forgery) attacks:

- ✅ Allows `https://` and `http://` schemes
- ❌ Blocks `file://`, `javascript:`, `data:`, `ftp://`, `content://` schemes
- ❌ Blocks malformed or missing URLs

**Threat mitigated:** Attackers cannot use workers to access local files or execute JavaScript.

### 2. Path Traversal Tests (`path_traversal_test.dart`)

Tests that file path validation prevents path traversal attacks:

- ✅ Allows normal absolute paths
- ❌ Blocks paths containing `..`
- ❌ Blocks relative paths
- ❌ Blocks empty paths

**Threat mitigated:** Attackers cannot use `../../../etc/passwd` to escape sandbox.

### 3. Resource Exhaustion Tests (`resource_exhaustion_test.dart`)

Tests that resource limits prevent DoS attacks:

- ✅ Validates timeout durations (prevents indefinite hangs)
- ✅ Limits additional form fields (max 50 fields)
- ✅ Validates image quality (0-100)
- ✅ Validates image dimensions (positive numbers)
- ✅ Enforces password minimum length (8+ chars)
- ✅ Validates file extensions

**Threat mitigated:** Attackers cannot cause OOM errors or exhaust system resources.

## Running Security Tests

### Run all security tests:
```bash
flutter test test/security/
```

### Run specific test file:
```bash
flutter test test/security/url_validation_test.dart
flutter test test/security/path_traversal_test.dart
flutter test test/security/resource_exhaustion_test.dart
```

### Run with verbose output:
```bash
flutter test test/security/ --reporter expanded
```

## Expected Results

All tests should pass:
```
✓ URL Scheme Validation (12 tests passed)
✓ Path Traversal Protection (15 tests passed)
✓ Resource Exhaustion Protection (18 tests passed)

Total: 45 tests passed
```

## Coverage

These tests cover:
- **Workers tested:** All 11 native workers
- **Attack vectors:** SSRF, Path Traversal, DoS, Input Validation
- **Validation points:** URL schemes, file paths, timeouts, field counts, dimensions, passwords

## Adding New Security Tests

When adding new workers or features, add corresponding security tests:

1. **Create test file:** `test/security/your_feature_test.dart`
2. **Test positive cases:** Valid inputs should work
3. **Test negative cases:** Invalid/malicious inputs should be rejected
4. **Document threat:** Explain what attack is prevented

## Security Test Checklist

For each worker, verify:
- [ ] URL scheme validation (if applicable)
- [ ] File path validation (if applicable)
- [ ] Input size limits
- [ ] Timeout validation
- [ ] Empty/null input handling
- [ ] Boundary value testing (min/max values)
- [ ] Error message clarity (no sensitive data leaked)

## Continuous Integration

These tests are run on every commit via GitHub Actions (when configured).

## Reporting Security Issues

If you find a security vulnerability:
1. **DO NOT** create a public GitHub issue
2. Email: security@brewkits.dev
3. Include: Vulnerability description, steps to reproduce, impact assessment

We'll respond within 48 hours and credit you in security advisories.

---

**Note:** These tests validate Dart-level input validation. For full security coverage, also run platform-specific tests on Android and iOS.
