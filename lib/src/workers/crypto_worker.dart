import 'package:flutter/foundation.dart';
import '../worker.dart';

/// Hash algorithms supported by CryptoWorker.
enum HashAlgorithm {
  md5('MD5'),
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
/// Encrypts a file using AES-256 with PBKDF2 password-derived key.
///
/// **⚠️ Platform Compatibility Warning:**
/// Android uses AES-256-CBC mode; iOS uses AES-256-GCM mode.
/// Files encrypted on Android **cannot** be decrypted on iOS and vice versa.
/// Use this worker only for single-platform encryption, or when both
/// encrypt and decrypt operations happen on the same OS.
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
///
/// **⚠️ Platform Compatibility Warning:**
/// Decryption must happen on the same platform as encryption.
/// Android-encrypted files (AES-CBC) cannot be decrypted on iOS (AES-GCM)
/// and vice versa.
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
