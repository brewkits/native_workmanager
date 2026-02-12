# Use Cases

Practical guides for common native_workmanager scenarios.

## 📚 Guides

### Getting Started
1. [Periodic API Sync](01-periodic-api-sync.md) - Most common use case
2. [File Upload with Retry](02-file-upload-with-retry.md) - Error handling patterns

### Advanced Features
3. [Background Cleanup](03-background-cleanup.md) - Scheduled maintenance tasks
4. [Photo Auto-Backup](04-photo-auto-backup.md) - ContentUri triggers (Android)
5. [Hybrid Workflow](05-hybrid-workflow.md) - Native + Dart workers combined
6. [Chain Processing](06-chain-processing.md) - Sequential workflows

---

## 🎯 Quick Navigation

**By Platform:**
- Android-specific: [Photo Auto-Backup](04-photo-auto-backup.md)
- iOS-specific: None (all cross-platform)
- Cross-platform: All others

**By Complexity:**
- Beginner: [Periodic API Sync](01-periodic-api-sync.md), [Background Cleanup](03-background-cleanup.md)
- Intermediate: [File Upload with Retry](02-file-upload-with-retry.md), [Photo Auto-Backup](04-photo-auto-backup.md)
- Advanced: [Hybrid Workflow](05-hybrid-workflow.md), [Chain Processing](06-chain-processing.md)

**By Feature:**
- HTTP operations: [Periodic API Sync](01-periodic-api-sync.md), [File Upload](02-file-upload-with-retry.md)
- Dart workers: [Background Cleanup](03-background-cleanup.md), [Hybrid Workflow](05-hybrid-workflow.md)
- Task chains: [Chain Processing](06-chain-processing.md)
- Triggers: [Photo Auto-Backup](04-photo-auto-backup.md)

---

## 💡 Usage Tips

### Reading Order

If you're new to native_workmanager:
1. Start with [Periodic API Sync](01-periodic-api-sync.md) to understand basics
2. Learn error handling with [File Upload](02-file-upload-with-retry.md)
3. Try Dart workers with [Background Cleanup](03-background-cleanup.md)
4. Explore advanced features with remaining guides

### Code Examples

All examples in these guides are:
- ✅ **Complete** - Copy-paste ready
- ✅ **Tested** - Verified on Android & iOS
- ✅ **Production-ready** - Include error handling
- ✅ **Commented** - Explain key concepts

### Platform Notes

Each guide includes:
- **Android-specific behavior** - How it works on Android
- **iOS-specific behavior** - How it works on iOS
- **Common pitfalls** - What to avoid
- **Best practices** - Recommended patterns

---

## 🚀 Getting Help

**In these guides, you'll learn:**
- How to schedule different types of tasks
- When to use native workers vs Dart workers
- How to handle errors and retries
- How to chain tasks together
- Platform-specific considerations
- Common mistakes to avoid

**Not covered here:**
- API reference - See main README.md
- API documentation - See doc/API_REFERENCE.md

---

## 📝 Contributing

Found an issue or have a suggestion? Please open an issue at:
https://github.com/user/native_workmanager/issues

---

*Last updated: 2026-01-27*
