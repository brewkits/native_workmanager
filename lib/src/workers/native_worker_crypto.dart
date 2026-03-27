part of '../worker.dart';

/// Cryptographic hash worker (MD5, SHA-1, SHA-256, SHA-512).
///
/// Computes cryptographic hash of a file for integrity verification,
/// deduplication, or content-addressable storage. Runs in native code
/// **without** Flutter Engine for optimal performance.
///
/// ## Hash File
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'verify-download',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.hashFile(
///     filePath: '/downloads/file.zip',
///     algorithm: HashAlgorithm.sha256,
///   ),
/// );
/// ```
///
/// ## Hash String
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'hash-password',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.hashString(
///     data: 'myPassword123',
///     algorithm: HashAlgorithm.sha256,
///   ),
/// );
/// ```
///
/// ## Parameters
///
/// **[filePath]** or **[data]** *(required)* - File path or string to hash.
///
/// **[algorithm]** *(optional)* - Hash algorithm (default: SHA-256).
/// - `HashAlgorithm.md5` - MD5 (fast, 128-bit, not cryptographically secure)
/// - `HashAlgorithm.sha1` - SHA-1 (160-bit, deprecated for security)
/// - `HashAlgorithm.sha256` - SHA-256 (256-bit, recommended)
/// - `HashAlgorithm.sha512` - SHA-512 (512-bit, most secure)
///
/// ## Behavior
///
/// - Returns hash as hex string in result data
/// - Streaming computation for large files (low memory)
/// - Task succeeds with hash in result
/// - Task fails if file not found or I/O error
///
/// ## When to Use
///
/// ✅ **Use hashFile when:**
/// - Verifying download integrity
/// - Checking for duplicate files
/// - Content-addressable storage
/// - File change detection
///
/// ## See Also
///
/// - [NativeWorker.cryptoEncrypt] - Encrypt files with AES-256
/// - [NativeWorker.cryptoDecrypt] - Decrypt encrypted files
Worker _buildHashFile({
  required String filePath,
  HashAlgorithm algorithm = HashAlgorithm.sha256,
}) {
  NativeWorker._validateFilePath(filePath, 'filePath');
  return CryptoHashWorker.file(filePath: filePath, algorithm: algorithm);
}

/// Hash string data.
///
/// See [NativeWorker.hashFile] for full documentation.
Worker _buildHashString({
  required String data,
  HashAlgorithm algorithm = HashAlgorithm.sha256,
}) {
  if (data.isEmpty) {
    throw ArgumentError('data cannot be empty');
  }
  return CryptoHashWorker.string(data: data, algorithm: algorithm);
}

/// File encryption worker (AES-256-GCM).
///
/// Encrypts files using AES-256-GCM with password-derived key.
/// Runs in native code **without** Flutter Engine for optimal performance.
///
/// ## Basic Encryption
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'encrypt-backup',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.cryptoEncrypt(
///     inputPath: '/data/backup.db',
///     outputPath: '/data/backup.db.enc',
///     password: 'mySecretPassword',
///   ),
/// );
/// ```
///
/// ## Parameters
///
/// **[inputPath]** *(required)* - Path to file to encrypt.
///
/// **[outputPath]** *(required)* - Where encrypted file will be saved.
///
/// **[password]** *(required)* - Password for encryption.
/// - Used to derive AES-256 key via PBKDF2
/// - Minimum 8 characters recommended
/// - Store securely (use Flutter Secure Storage)
///
/// ## Security Notes
///
/// - Uses AES-256-GCM (authenticated encryption)
/// - Random IV generated per encryption
/// - PBKDF2 key derivation (100,000 iterations)
/// - Password never stored, only used to derive key
///
/// ## See Also
///
/// - [NativeWorker.cryptoDecrypt] - Decrypt encrypted files
/// - [NativeWorker.hashFile] - Hash files for integrity
Worker _buildCryptoEncrypt({
  required String inputPath,
  required String outputPath,
  required String password,
}) {
  NativeWorker._validateFilePath(inputPath, 'inputPath');
  NativeWorker._validateFilePath(outputPath, 'outputPath');

  if (password.isEmpty) {
    throw ArgumentError('password cannot be empty');
  }

  if (password.length < 8) {
    throw ArgumentError(
      'Password too weak: ${password.length} characters\n'
      'Minimum required: 8 characters for security\n'
      'Recommendation: Use 12+ characters with mixed case, numbers, and symbols',
    );
  }

  return CryptoEncryptWorker(
    inputPath: inputPath,
    outputPath: outputPath,
    password: password,
  );
}

/// File decryption worker (AES-256-GCM).
///
/// Decrypts files previously encrypted by [NativeWorker.cryptoEncrypt].
/// Runs in native code **without** Flutter Engine.
///
/// ## Basic Decryption
///
/// ```dart
/// await NativeWorkManager.enqueue(
///   taskId: 'decrypt-backup',
///   trigger: TaskTrigger.oneTime(),
///   worker: NativeWorker.cryptoDecrypt(
///     inputPath: '/data/backup.db.enc',
///     outputPath: '/data/backup.db',
///     password: 'mySecretPassword',
///   ),
/// );
/// ```
///
/// ## Parameters
///
/// **[inputPath]** *(required)* - Path to encrypted file.
///
/// **[outputPath]** *(required)* - Where decrypted file will be saved.
///
/// **[password]** *(required)* - Password used for encryption.
/// - Must match the password used in [NativeWorker.cryptoEncrypt]
/// - Decryption fails with wrong password
///
/// ## See Also
///
/// - [NativeWorker.cryptoEncrypt] - Encrypt files
/// - [NativeWorker.hashFile] - Hash files for integrity
Worker _buildCryptoDecrypt({
  required String inputPath,
  required String outputPath,
  required String password,
}) {
  NativeWorker._validateFilePath(inputPath, 'inputPath');
  NativeWorker._validateFilePath(outputPath, 'outputPath');

  if (password.isEmpty) {
    throw ArgumentError('password cannot be empty');
  }

  // Note: For decryption, we accept any password length since it must match
  // the original encryption password (which was already validated)
  return CryptoDecryptWorker(
    inputPath: inputPath,
    outputPath: outputPath,
    password: password,
  );
}
