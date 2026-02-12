# CryptoWorker Documentation

## Overview

The `CryptoWorker` performs cryptographic operations (hashing, encryption, decryption) in the background **without** starting the Flutter Engine. This provides native performance for file integrity verification, deduplication, and secure storage.

**Key Benefits:**
- **Native Performance:** Uses platform crypto libraries (no Flutter Engine)
- **Low Memory:** Streaming operations
- **Battery Efficient:** No Flutter Engine overhead
- **Background Execution:** Hash/encrypt files when app is closed
- **Security:** Hardware-accelerated crypto (CryptoKit on iOS, Cipher on Android)

---

## Operations

### 1. File Hashing

Compute cryptographic hash of files for integrity verification.

**Algorithms:** MD5, SHA-1, SHA-256, SHA-512

```dart
await NativeWorkManager.enqueue(
  taskId: 'verify-download',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.hashFile(
    filePath: '/downloads/file.zip',
    algorithm: HashAlgorithm.sha256,
  ),
);
```

### 2. String Hashing

Hash strings for passwords, tokens, or identifiers.

```dart
await NativeWorkManager.enqueue(
  taskId: 'hash-password',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.hashString(
    data: 'myPassword123',
    algorithm: HashAlgorithm.sha256,
  ),
);
```

### 3. File Encryption

Encrypt files with AES-256-GCM for secure storage.

```dart
await NativeWorkManager.enqueue(
  taskId: 'encrypt-backup',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.cryptoEncrypt(
    filePath: '/backups/data.db',
    outputPath: '/backups/data.db.enc',
    password: 'SecurePassword123!',
  ),
);
```

### 4. File Decryption

Decrypt encrypted files to restore data.

```dart
await NativeWorkManager.enqueue(
  taskId: 'decrypt-backup',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.cryptoDecrypt(
    filePath: '/backups/data.db.enc',
    outputPath: '/restored/data.db',
    password: 'SecurePassword123!',
  ),
);
```

---

## Hash Algorithms

### SHA-256 (Recommended)

**Use for:** General-purpose hashing, integrity verification

```dart
algorithm: HashAlgorithm.sha256  // 256-bit, secure, fast
```

**Characteristics:**
- ✅ Cryptographically secure
- ✅ Fast on modern hardware
- ✅ Industry standard
- 🔧 32-byte (64 hex chars) output

### SHA-512

**Use for:** Maximum security requirements

```dart
algorithm: HashAlgorithm.sha512  // 512-bit, most secure
```

**Characteristics:**
- ✅ Most secure
- ⚠️ Slower than SHA-256
- ⚠️ Larger output (64 bytes)
- 🔧 Best for high-security scenarios

### MD5 (Not Recommended)

**Use for:** Non-security checksums only

```dart
algorithm: HashAlgorithm.md5  // 128-bit, fast, NOT secure
```

**Characteristics:**
- ❌ NOT cryptographically secure
- ✅ Very fast
- ✅ Small output (16 bytes)
- 🔧 Use only for non-security purposes (deduplication, cache keys)

### SHA-1 (Deprecated)

**Use for:** Legacy compatibility only

```dart
algorithm: HashAlgorithm.sha1  // 160-bit, deprecated
```

**Characteristics:**
- ❌ Cryptographically broken
- ⚠️ Use only for legacy systems
- 🔧 20-byte output

---

## Common Use Cases

### 1. Download Integrity Verification

Verify downloaded files haven't been corrupted:

```dart
// Step 1: Download file
await NativeWorkManager.enqueue(
  taskId: 'download',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.httpDownload(
    url: 'https://cdn.example.com/update.zip',
    savePath: '/downloads/update.zip',
  ),
);

// Step 2: Verify hash
await NativeWorkManager.enqueue(
  taskId: 'verify',
  trigger: TaskTrigger.contentUri(taskId: 'download'),
  worker: NativeWorker.hashFile(
    filePath: '/downloads/update.zip',
    algorithm: HashAlgorithm.sha256,
  ),
);

// Step 3: Check result
NativeWorkManager.results.listen((result) {
  if (result.taskId == 'verify' && result.success) {
    final hash = result.data?['hash'] as String?;
    final expectedHash = 'abc123...';

    if (hash == expectedHash) {
      print('✅ File integrity verified');
    } else {
      print('❌ File corrupted, re-download');
    }
  }
});
```

### 2. File Deduplication

Check if files are identical before uploading:

```dart
// Hash file before upload
final result = await NativeWorkManager.enqueueAndWait(
  taskId: 'hash-file',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.hashFile(
    filePath: '/photos/IMG_4032.jpg',
    algorithm: HashAlgorithm.sha256,
  ),
);

final fileHash = result.data?['hash'] as String;

// Check if hash exists on server
final exists = await checkHashExists(fileHash);

if (exists) {
  print('✅ File already exists, skip upload');
} else {
  print('⬆️ Upload new file');
  // ... upload logic
}
```

### 3. Secure Cloud Backup

Encrypt files before uploading to cloud:

```dart
// Step 1: Encrypt local file
await NativeWorkManager.enqueue(
  taskId: 'encrypt-backup',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.cryptoEncrypt(
    filePath: '/data/user_data.db',
    outputPath: '/temp/encrypted.bin',
    password: userPassword,
  ),
);

// Step 2: Upload encrypted file
await NativeWorkManager.enqueue(
  taskId: 'upload-backup',
  trigger: TaskTrigger.contentUri(taskId: 'encrypt-backup'),
  worker: NativeWorker.httpUpload(
    url: 'https://api.example.com/backup',
    files: [UploadFile(filePath: '/temp/encrypted.bin', fieldName: 'backup')],
  ),
  constraints: Constraints(requiresWifi: true),
);

// Step 3: Cleanup
await NativeWorkManager.enqueue(
  taskId: 'cleanup',
  trigger: TaskTrigger.contentUri(taskId: 'upload-backup'),
  worker: NativeWorker.fileDelete(path: '/temp/encrypted.bin'),
);
```

### 4. Password Hashing

Hash passwords for secure storage:

```dart
await NativeWorkManager.enqueue(
  taskId: 'hash-password',
  trigger: TaskTrigger.oneTime(),
  worker: NativeWorker.hashString(
    data: userPassword,
    algorithm: HashAlgorithm.sha256,
  ),
);
```

---

## Result Data

### Hash Operations

```dart
{
  "hash": "abc123def456...",  // Hex-encoded hash
  "algorithm": "SHA-256",     // Algorithm used
  "fileSize": 1234567,        // File size (hash file only)
  "duration": 1250            // Processing time (ms)
}
```

### Encryption Operations

```dart
{
  "inputPath": "/data/file.db",
  "outputPath": "/data/file.db.enc",
  "algorithm": "AES-256-GCM",
  "originalSize": 5242880,    // bytes
  "encryptedSize": 5242896,   // bytes (slightly larger due to IV/tag)
  "duration": 850             // Processing time (ms)
}
```

### Decryption Operations

```dart
{
  "inputPath": "/data/file.db.enc",
  "outputPath": "/data/file.db",
  "algorithm": "AES-256-GCM",
  "encryptedSize": 5242896,   // bytes
  "decryptedSize": 5242880,   // bytes
  "duration": 820             // Processing time (ms)
}
```

---

## Security Best Practices

### Password Requirements

**Minimum Length:** 8 characters (enforced in v1.0+)

```dart
// ❌ Will fail
password: 'short'  // Error: "Password too weak: 5 characters"

// ✅ Valid
password: 'SecurePass123!'  // 15 characters
```

### Key Management

**Don't:**
- ❌ Hardcode passwords in source code
- ❌ Store passwords in SharedPreferences
- ❌ Use weak passwords ('123456', 'password')

**Do:**
- ✅ Use platform secure storage (Keychain/Keystore)
- ✅ Derive keys from user passwords with PBKDF2
- ✅ Use strong, random passwords for encryption

**Example:**
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Store encryption key securely
final storage = FlutterSecureStorage();
await storage.write(key: 'backup_key', value: randomKey);

// Retrieve for encryption
final key = await storage.read(key: 'backup_key');
if (key != null) {
  await NativeWorkManager.enqueue(
    taskId: 'encrypt',
    worker: NativeWorker.cryptoEncrypt(filePath: file, password: key),
  );
}
```

### Hash Verification

Always use timing-safe comparison:

```dart
// ❌ Vulnerable to timing attacks
if (hash1 == hash2) { ... }

// ✅ Timing-safe comparison
bool secureCompare(String a, String b) {
  if (a.length != b.length) return false;

  int result = 0;
  for (int i = 0; i < a.length; i++) {
    result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return result == 0;
}
```

---

## Performance

### Native Performance Benefits

CryptoWorker uses platform-native crypto libraries without loading the Flutter Engine:
- Hardware-accelerated cryptography (CryptoKit on iOS, Android Cipher)
- Streaming operations (low memory usage)
- Native performance (no Dart VM overhead)

### Performance Tips

✅ **Do:**
- Use SHA-256 for general hashing (best balance)
- Use streaming for large files (>10MB)
- Encrypt before upload (save bandwidth)
- Hash downloaded files for verification

❌ **Don't:**
- Use MD5 for security purposes
- Hash files > 1GB without progress monitoring
- Encrypt already-compressed files (minimal benefit)

---

## Platform Differences

### Android

**Implementation:**
- `MessageDigest` for hashing
- `Cipher` with AES/GCM/NoPadding for encryption

**Features:**
- ✅ All algorithms supported
- ✅ Hardware acceleration
- ✅ Streaming operations

### iOS

**Implementation:**
- `CryptoKit` (iOS 13+)
- `CommonCrypto` fallback (iOS <13)

**Features:**
- ✅ All algorithms supported
- ✅ Hardware-accelerated (Secure Enclave)
- ✅ Streaming operations
- ✅ Best performance on Apple Silicon

---

## Error Handling

### Common Errors

#### "Password too weak"
**Cause:** Password < 8 characters

**Solution:**
```dart
if (password.length < 8) {
  throw ArgumentError('Password must be at least 8 characters');
}
```

#### "File not found"
**Cause:** File doesn't exist

**Solution:**
```dart
if (!File(filePath).existsSync()) {
  print('File not found: $filePath');
  return;
}
```

#### "Decryption failed"
**Cause:** Wrong password or corrupted file

**Solution:**
```dart
// Ensure correct password is used
final storedPassword = await secureStorage.read(key: 'encryption_key');
if (userPassword != storedPassword) {
  print('❌ Incorrect password');
  return;
}
```

---

## See Also

- **[HttpDownloadWorker](./HTTP_DOWNLOAD.md)** - Download files before hashing
- **[HttpUploadWorker](./HTTP_UPLOAD.md)** - Upload encrypted files
- **[FileCompressionWorker](./FILE_COMPRESSION.md)** - Compress before encryption
- **[Task Chains Guide](../use-cases/06-chain-processing.md)** - Build secure workflows

---

## Changelog

### v1.0.0 (2026-02-07)
- ✅ File hashing (MD5, SHA-1, SHA-256, SHA-512)
- ✅ String hashing
- ✅ File encryption (AES-256-GCM)
- ✅ File decryption
- ✅ Password validation (8 char minimum)
- ✅ Streaming operations (low memory)

### Planned for v1.1.0
- Advanced key derivation (PBKDF2 iterations configurable)
- Public key encryption (RSA)
- Digital signatures
- Key management documentation
