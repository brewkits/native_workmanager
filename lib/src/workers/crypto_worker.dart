import 'package:flutter/foundation.dart';
import '../worker.dart';

/// Hash algorithms supported by CryptoWorker.
///
/// **⚠️ Security Notice:**
/// `md5` and `sha1` are cryptographically broken and should not be used for
/// security-sensitive purposes (e.g., password hashing, integrity verification).
/// Use [sha256] or [sha512] instead.
enum HashAlgorithm {
  /// **Deprecated for security use.** MD5 is cryptographically broken.
  /// Use [sha256] or [sha512] for integrity checks.
  @Deprecated('MD5 is cryptographically broken. Use sha256 or sha512 instead.')
  md5('MD5'),

  /// **Deprecated for security use.** SHA-1 is cryptographically broken.
  /// Use [sha256] or [sha512] for integrity checks.
  @Deprecated(
      'SHA-1 is cryptographically broken. Use sha256 or sha512 instead.')
  sha1('SHA-1'),

  sha256('SHA-256'),
  sha512('SHA-512');

  const HashAlgorithm(this.value);
  final String value;
}

/// Encryption algorithms supported by CryptoWorker.
enum EncryptionAlgorithm {
  aes('AES');

  const EncryptionAlgorithm(this.value);
  final String value;
}

/// Crypto worker configuration for file hashing.
///
/// Computes cryptographic hash of a file or string.
@immutable
final class CryptoHashWorker extends Worker {
  const CryptoHashWorker.file({
    required this.filePath,
    this.algorithm = HashAlgorithm.sha256,
  }) : data = null;

  const CryptoHashWorker.string({
    required this.data,
    this.algorithm = HashAlgorithm.sha256,
  }) : filePath = null;

  /// Path to file to hash (null if hashing string data).
  final String? filePath;

  /// String data to hash (null if hashing file).
  final String? data;

  /// Hash algorithm to use.
  final HashAlgorithm algorithm;

  @override
  String get workerClassName => 'CryptoWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'crypto',
        'operation': 'hash',
        if (filePath != null) 'filePath': filePath,
        if (data != null) 'data': data,
        'algorithm': algorithm.value,
      };
}

/// Crypto worker configuration for file encryption.
///
/// Encrypts a file using AES-256-GCM (authenticated encryption) with a
/// PBKDF2-derived key (100,000 iterations, HMAC-SHA256).
///
/// File format: `SALT(16) || NONCE(12) || CIPHERTEXT || GCM_TAG(16)`
///
/// Both Android and iOS use AES-256-GCM with the same on-disk format, so
/// files encrypted on one platform can be decrypted on the other.
@immutable
final class CryptoEncryptWorker extends Worker {
  const CryptoEncryptWorker({
    required this.inputPath,
    required this.outputPath,
    required this.password,
    this.algorithm = EncryptionAlgorithm.aes,
  });

  /// Path to file to encrypt.
  final String inputPath;

  /// Path where encrypted file will be saved.
  final String outputPath;

  /// Password for encryption (will be used to derive key).
  final String password;

  /// Encryption algorithm (currently only AES supported).
  final EncryptionAlgorithm algorithm;

  @override
  String get workerClassName => 'CryptoWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'crypto',
        'operation': 'encrypt',
        'filePath': inputPath,
        'outputPath': outputPath,
        'password': password,
        'algorithm': algorithm.value,
      };
}

/// Crypto worker configuration for file decryption.
///
/// Decrypts a file previously encrypted by [CryptoEncryptWorker].
/// Both Android and iOS use AES-256-GCM with the same on-disk format, so
/// cross-platform decryption is fully supported.
@immutable
final class CryptoDecryptWorker extends Worker {
  const CryptoDecryptWorker({
    required this.inputPath,
    required this.outputPath,
    required this.password,
    this.algorithm = EncryptionAlgorithm.aes,
  });

  /// Path to encrypted file.
  final String inputPath;

  /// Path where decrypted file will be saved.
  final String outputPath;

  /// Password used for encryption.
  final String password;

  /// Encryption algorithm used (currently only AES supported).
  final EncryptionAlgorithm algorithm;

  @override
  String get workerClassName => 'CryptoWorker';

  @override
  Map<String, dynamic> toMap() => {
        'workerType': 'crypto',
        'operation': 'decrypt',
        'filePath': inputPath,
        'outputPath': outputPath,
        'password': password,
        'algorithm': algorithm.value,
      };
}
