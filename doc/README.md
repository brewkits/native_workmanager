# Documentation

native_workmanager v1.2.2 documentation index.

## Getting Started

| File | Description |
|------|-------------|
| [GETTING_STARTED.md](GETTING_STARTED.md) | 3-minute quick start with copy-paste examples |
| [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) | Migrate from `workmanager` step-by-step |

## Platform Guides

| File | Description |
|------|-------------|
| [ANDROID_SETUP.md](ANDROID_SETUP.md) | Android minSdk 26+, ProGuard, permissions |
| [IOS_BACKGROUND_LIMITS.md](IOS_BACKGROUND_LIMITS.md) | iOS 30-second rule, BGTaskScheduler, periodic limitations |
| [PLATFORM_CONSISTENCY.md](PLATFORM_CONSISTENCY.md) | Cross-platform behavior differences and guarantees |

## API & Technical Reference

| File | Description |
|------|-------------|
| [API_REFERENCE.md](API_REFERENCE.md) | Complete API documentation for all public types |
| [EXTENSIBILITY.md](EXTENSIBILITY.md) | Writing custom Kotlin/Swift workers |
| [SECURITY.md](SECURITY.md) | Security policy, path traversal, URL validation |
| [PRODUCTION_GUIDE.md](PRODUCTION_GUIDE.md) | Production checklist, monitoring, reliability |
| [FAQ.md](FAQ.md) | Frequently asked questions |

## Use Cases

| File | Description |
|------|-------------|
| [use-cases/01-periodic-api-sync.md](use-cases/01-periodic-api-sync.md) | Periodic background sync |
| [use-cases/02-file-upload-with-retry.md](use-cases/02-file-upload-with-retry.md) | Reliable file upload with backoff |
| [use-cases/03-background-cleanup.md](use-cases/03-background-cleanup.md) | Scheduled cache/temp file cleanup |
| [use-cases/04-photo-auto-backup.md](use-cases/04-photo-auto-backup.md) | Photo library backup workflow |
| [use-cases/05-hybrid-workflow.md](use-cases/05-hybrid-workflow.md) | Mixing native workers with Dart callbacks |
| [use-cases/06-chain-processing.md](use-cases/06-chain-processing.md) | Multi-step task chains (Download → Process → Upload) |
| [use-cases/07-custom-native-workers.md](use-cases/07-custom-native-workers.md) | Writing and registering custom Kotlin/Swift workers |

## Worker Guides

| File | Description |
|------|-------------|
| [workers/CRYPTO_OPERATIONS.md](workers/CRYPTO_OPERATIONS.md) | AES-256 encryption, PBKDF2, file hashing |
| [workers/FILE_SYSTEM.md](workers/FILE_SYSTEM.md) | Copy, move, delete, list, mkdir |
| [workers/FILE_DECOMPRESSION.md](workers/FILE_DECOMPRESSION.md) | ZIP extraction with zip-slip/bomb protection |
| [workers/IMAGE_PROCESSING.md](workers/IMAGE_PROCESSING.md) | Resize, compress, format conversion |

## Integration Guides

| File | Description |
|------|-------------|
| [integrations/dio.md](integrations/dio.md) | Use Dio interceptors with native workers |
| [integrations/firebase.md](integrations/firebase.md) | Firebase + background sync |
| [integrations/hive.md](integrations/hive.md) | Hive database background operations |
| [integrations/sentry.md](integrations/sentry.md) | Error tracking for background tasks |

## Technical Analysis

| File | Description |
|------|-------------|
| [BUG_FIX_VERIFICATION.md](BUG_FIX_VERIFICATION.md) | WorkManager 2.10.0+ bug root cause & verification (v1.0.4) |

## Quick Navigation

- **[../README.md](../README.md)** — Package overview and feature table
- **[../CHANGELOG.md](../CHANGELOG.md)** — Version history
- **[../CONTRIBUTING.md](../CONTRIBUTING.md)** — Contributing guidelines
- **[../example/](../example/)** — Working example app

Last updated: 2026-04-16 (v1.2.1)
