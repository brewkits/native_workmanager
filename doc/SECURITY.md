# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| 0.9.x   | :white_check_mark: |
| 0.8.x   | :x:                |
| < 0.8   | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please follow these steps:

### 1. **DO NOT** Create a Public Issue

Security vulnerabilities should **never** be reported via public GitHub issues, as this could put users at risk.

### 2. Report Privately

**Email:** security@example.com

**Subject:** `[SECURITY] native_workmanager - Brief Description`

**Include:**
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)
- Your contact information

### 3. What to Expect

| Timeline | Action |
|----------|--------|
| **24 hours** | Acknowledgment of your report |
| **3-5 days** | Initial assessment and severity classification |
| **7-14 days** | Fix developed and tested |
| **14-30 days** | Patch released and security advisory published |

### 4. Severity Levels

**Critical** - Immediate attention
- Remote code execution
- Data leaks
- Authentication bypass

**High** - Fast track (3 days)
- Authorization bypass
- SQL injection
- XSS vulnerabilities

**Medium** - Standard track (1 week)
- Input validation issues
- Path traversal
- Information disclosure

**Low** - Regular cycle (1 month)
- Minor information leaks
- DoS (local only)

## Security Best Practices

### Always Use HTTPS

```dart
// ✅ Good
NativeWorker.httpRequest(
  url: 'https://api.example.com/data',
)

// ❌ Bad - unencrypted
NativeWorker.httpRequest(
  url: 'http://api.example.com/data',
)
```

### Never Log Sensitive Data

```dart
// ❌ Bad - logs credentials
print('Token: $apiToken');

// ✅ Good - redacted
if (kDebugMode) {
  print('Token: <redacted>');
}
```

### Validate File Paths

```dart
// ✅ Good - use app directory
final appDir = await getApplicationDocumentsDirectory();
final savePath = path.join(appDir.path, 'file.zip');

NativeWorker.httpDownload(
  url: 'https://example.com/file.zip',
  savePath: savePath,
)

// ❌ Bad - arbitrary path
NativeWorker.httpDownload(
  url: 'https://example.com/file.zip',
  savePath: '/tmp/../../etc/passwd',  // Path traversal!
)
```

### Handle Secrets Properly

```dart
// ✅ Good - use environment variables or secure storage
final apiKey = dotenv.env['API_KEY'];

// ❌ Bad - hardcoded secrets
const apiKey = 'sk_live_1234567890';  // NEVER do this!
```

## Known Issues

### Current Vulnerabilities

| ID | Severity | Status | Affected Versions |
|----|----------|--------|-------------------|
| None | - | - | - |

### Fixed Vulnerabilities

| ID | Severity | Fixed In | Description |
|----|----------|----------|-------------|
| None yet | - | - | - |

## Security Updates

Subscribe to security advisories:
- Watch this repository
- Check [GitHub Security Advisories](https://github.com/user/native_workmanager/security/advisories)

## Responsible Disclosure

We follow a **90-day disclosure policy**:

1. **Day 0:** Vulnerability reported
2. **Day 1-7:** Assessment and fix development
3. **Day 7-30:** Testing and patch release
4. **Day 30:** Security advisory published
5. **Day 90:** Full details disclosed (if not critical)

## Hall of Fame

We recognize security researchers who help make native_workmanager more secure:

- *Your name could be here!*

## Contact

**Security Team:** security@example.com
**PGP Key:** [Download](https://example.com/pgp-key.asc)

## Additional Resources

- [Security Audit Report](SECURITY_AUDIT.md)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Flutter Security Best Practices](https://docs.flutter.dev/security)

---

**Last Updated:** 2026-01-31
