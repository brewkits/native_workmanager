# Contributing to native_workmanager

Thank you for your interest in contributing to **native_workmanager**! We welcome contributions from the community to help make this library even better.

---

## 🤝 How to Contribute

### 1. Fork and Clone

```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/native_workmanager.git
cd native_workmanager

# Add upstream remote
git remote add upstream https://github.com/brewkits/native_workmanager.git
```

### 2. Create a Feature Branch

```bash
git checkout -b feature/your-amazing-feature
```

### 3. Make Your Changes

- Write clean, readable code
- Follow the code style guidelines below
- Add tests for new features
- Update documentation as needed

### 4. Test Your Changes

```bash
# Run analyzer
flutter analyze

# Run tests
flutter test

# Test on both platforms
cd example
flutter run  # Test on Android/iOS
```

### 5. Commit and Push

```bash
git add .
git commit -m "feat: Add your amazing feature"
git push origin feature/your-amazing-feature
```

### 6. Open a Pull Request

- Go to the [original repository](https://github.com/brewkits/native_workmanager)
- Click "New Pull Request"
- Select your fork and branch
- Fill in the PR template with details

---

## 🐛 Reporting Bugs

Please use [GitHub Issues](https://github.com/brewkits/native_workmanager/issues) and include:

**Required Information:**
- Flutter version (`flutter --version`)
- Platform (Android/iOS version)
- Minimal reproducible example
- Expected behavior vs actual behavior
- Relevant logs/stack traces

**Issue Template:**
```markdown
## Bug Description
[Clear description of the bug]

## Environment
- Flutter version:
- Platform: Android X.X / iOS X.X
- native_workmanager version:

## Steps to Reproduce
1. Step 1
2. Step 2
3. ...

## Expected Behavior
[What you expected to happen]

## Actual Behavior
[What actually happened]

## Code Sample
```dart
// Minimal reproducible example
```

## Logs
```
[Paste relevant logs here]
```
```

---

## 💡 Suggesting Features

We love new ideas! Before suggesting a feature:

1. **Check existing issues** - Maybe someone already suggested it
2. **Consider the scope** - Does it fit the library's purpose?
3. **Provide use cases** - Real-world examples help us prioritize

**Feature Request Template:**
```markdown
## Feature Description
[Clear description of the feature]

## Use Case
[Why is this feature needed? What problem does it solve?]

## Proposed API
```dart
// Example of how the API might look
```

## Alternatives Considered
[Other approaches you've considered]
```

---

## 📋 Code Style Guidelines

### Dart Code

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use `flutter analyze` - must pass with 0 issues
- Maximum line length: 80 characters (relaxed to 100 for long strings)
- Always use `const` constructors where possible
- Prefer final over var/let

**Example:**
```dart
// ✅ Good
const MyWidget({
  required this.title,
  this.subtitle,
  super.key,
});

// ❌ Bad
MyWidget({
  this.title,
  this.subtitle,
  Key? key,
}) : super(key: key);
```

### Documentation

- **All public APIs must have DartDoc comments**
- Include examples in documentation
- Document parameters, return values, and exceptions
- Add `@deprecated` annotations when deprecating APIs

**Example:**
```dart
/// Downloads a file from a URL to local storage.
///
/// This worker runs in native code without Flutter Engine overhead.
///
/// ## Example
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'download',
///   worker: NativeWorker.httpDownload(
///     url: 'https://example.com/file.zip',
///     savePath: '/downloads/file.zip',
///   ),
/// );
/// ```
///
/// ## Parameters
///
/// - [url]: The HTTP/HTTPS URL to download from
/// - [savePath]: Absolute path where file will be saved
///
/// ## Throws
///
/// - [ArgumentError] if URL is invalid or path is empty
///
/// ## See Also
///
/// - [httpUpload] for uploading files
static Worker httpDownload({
  required String url,
  required String savePath,
}) { ... }
```

### Testing

- Write tests for all new features
- Aim for >80% code coverage
- Use descriptive test names
- Group related tests

**Example:**
```dart
group('HttpDownloadWorker', () {
  test('downloads file successfully', () async {
    // Arrange
    final worker = NativeWorker.httpDownload(
      url: 'https://example.com/file.zip',
      savePath: '/tmp/file.zip',
    );

    // Act
    final result = await NativeWorkManager.enqueue(
      taskId: 'test',
      trigger: TaskTrigger.oneTime(),
      worker: worker,
    );

    // Assert
    expect(result.success, isTrue);
  });

  test('fails with invalid URL', () {
    expect(
      () => NativeWorker.httpDownload(
        url: 'invalid-url',
        savePath: '/tmp/file.zip',
      ),
      throwsArgumentError,
    );
  });
});
```

---

## 🏗️ Project Structure

```
native_workmanager/
├── lib/src/                  # Dart implementation
│   ├── native_work_manager.dart  # Main API
│   ├── worker.dart               # Worker definitions
│   ├── workers/                  # Individual workers
│   └── ...
├── android/src/main/kotlin/  # Android implementation
│   ├── NativeWorkmanagerPlugin.kt
│   └── workers/                  # Android workers
├── ios/Classes/              # iOS implementation
│   ├── NativeWorkmanagerPlugin.swift
│   └── workers/                  # iOS workers
├── test/                     # Dart tests
├── doc/                      # Documentation
└── example/                  # Example app
```

---

## 🔧 Development Setup

### Prerequisites

- Flutter 3.3.0 or higher
- Dart 3.10.0 or higher
- Android Studio (for Android development)
- Xcode (for iOS development)

### Setup Steps

```bash
# 1. Install dependencies
flutter pub get

# 2. Run tests
flutter test

# 3. Run analyzer
flutter analyze

# 4. Run example app
cd example
flutter pub get
flutter run
```

---

## 🎯 Areas That Need Help

We're especially looking for contributions in these areas:

### High Priority
- 🔴 iOS security validation enhancements
- 🔴 Security test suite expansion
- 🔴 CI/CD pipeline setup (GitHub Actions)

### Medium Priority
- 🟡 Web platform support
- 🟡 Desktop platform support (Windows/macOS/Linux)
- 🟡 Additional worker types
- 🟡 Performance optimizations

### Low Priority
- 🟢 Documentation improvements
- 🟢 Example app enhancements
- 🟢 Translation to other languages

---

## 📜 Commit Message Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/):

**Format:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```bash
feat(http): Add resume support for downloads
fix(ios): Fix crash on iOS 12 devices
docs(readme): Update installation instructions
test(security): Add URL validation tests
```

---

## 🔍 Pull Request Process

1. **Update documentation** if you're changing APIs
2. **Add tests** for new features or bug fixes
3. **Run `flutter analyze`** and fix all issues
4. **Run `flutter test`** and ensure all tests pass
5. **Update CHANGELOG.md** with your changes
6. **Fill out the PR template** completely
7. **Wait for review** - we'll respond within 48 hours

### PR Checklist

Before submitting, ensure:

- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] Tests pass locally
- [ ] Analyzer passes with 0 issues
- [ ] CHANGELOG.md updated
- [ ] No merge conflicts

---

## 🏆 Recognition

Contributors will be:
- Listed in release notes
- Acknowledged in CHANGELOG.md
- Added to the contributors list

---

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

## 💬 Questions?

- Open a [GitHub Discussion](https://github.com/brewkits/native_workmanager/discussions)
- Email: support@brewkits.dev

---

**Thank you for contributing to native_workmanager!** 🎉
