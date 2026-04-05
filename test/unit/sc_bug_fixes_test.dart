// Tests for Security & Cryptography bug fixes (SC-C-001..SC-L-003).
//
// Most SC fixes live in native code (Android/iOS) and are verified by the
// integration-test suite. This file covers the Dart-layer contracts:
//   • SC-H-007: AES-GCM (not CBC) docstrings + cross-platform note
//   • SC-L-003: md5/sha1 deprecation annotations
//   • Serialisation round-trips for all crypto workers
//   • Password validation enforced at construction time

import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // CryptoHashWorker serialisation
  // ──────────────────────────────────────────────────────────────────────────

  group('CryptoHashWorker.file serialisation', () {
    test('defaults to SHA-256', () {
      const w = CryptoHashWorker.file(filePath: '/tmp/file.bin');
      final map = w.toMap();
      expect(map['operation'], 'hash');
      expect(map['filePath'], '/tmp/file.bin');
      expect(map['algorithm'], 'SHA-256');
      expect(map['workerType'], 'crypto');
      expect(map.containsKey('data'), false);
    });

    test('SHA-512 serialises', () {
      const w = CryptoHashWorker.file(
        filePath: '/tmp/file.bin',
        algorithm: HashAlgorithm.sha512,
      );
      expect(w.toMap()['algorithm'], 'SHA-512');
    });

    // SC-L-003: md5 and sha1 are deprecated but still serialise correctly
    // (existing data must continue to round-trip; deprecation is a compile warning only).
    // ignore: deprecated_member_use
    test('MD5 serialises (deprecated but still works)', () {
      // ignore: deprecated_member_use
      const w = CryptoHashWorker.file(
          filePath: '/tmp/f', algorithm: HashAlgorithm.md5);
      expect(w.toMap()['algorithm'], 'MD5');
    });

    // ignore: deprecated_member_use
    test('SHA-1 serialises (deprecated but still works)', () {
      // ignore: deprecated_member_use
      const w = CryptoHashWorker.file(
          filePath: '/tmp/f', algorithm: HashAlgorithm.sha1);
      expect(w.toMap()['algorithm'], 'SHA-1');
    });
  });

  group('CryptoHashWorker.string serialisation', () {
    test('defaults to SHA-256', () {
      const w = CryptoHashWorker.string(data: 'hello');
      final map = w.toMap();
      expect(map['operation'], 'hash');
      expect(map['data'], 'hello');
      expect(map['algorithm'], 'SHA-256');
      expect(map.containsKey('filePath'), false);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // CryptoEncryptWorker serialisation
  // ──────────────────────────────────────────────────────────────────────────

  group('CryptoEncryptWorker serialisation', () {
    test('serialises all fields', () {
      const w = CryptoEncryptWorker(
        inputPath: '/tmp/input.txt',
        outputPath: '/tmp/output.enc',
        password: 'str0ngP@ss',
      );
      final map = w.toMap();
      expect(map['operation'], 'encrypt');
      expect(map['filePath'], '/tmp/input.txt');
      expect(map['outputPath'], '/tmp/output.enc');
      expect(map['password'], 'str0ngP@ss');
      expect(map['algorithm'], 'AES');
      expect(map['workerType'], 'crypto');
    });

    test('workerClassName is CryptoWorker', () {
      const w = CryptoEncryptWorker(
        inputPath: '/tmp/a',
        outputPath: '/tmp/b',
        password: 'pass1234',
      );
      expect(w.workerClassName, 'CryptoWorker');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // CryptoDecryptWorker serialisation
  // ──────────────────────────────────────────────────────────────────────────

  group('CryptoDecryptWorker serialisation', () {
    test('serialises all fields', () {
      const w = CryptoDecryptWorker(
        inputPath: '/tmp/output.enc',
        outputPath: '/tmp/decrypted.txt',
        password: 'str0ngP@ss',
      );
      final map = w.toMap();
      expect(map['operation'], 'decrypt');
      expect(map['filePath'], '/tmp/output.enc');
      expect(map['outputPath'], '/tmp/decrypted.txt');
      expect(map['password'], 'str0ngP@ss');
      expect(map['algorithm'], 'AES');
      expect(map['workerType'], 'crypto');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // NativeWorker.hashFile / hashString convenience constructors
  // ──────────────────────────────────────────────────────────────────────────

  group('NativeWorker.hashFile convenience constructor', () {
    test('produces correct workerType, className, and operation', () {
      final w = NativeWorker.hashFile(filePath: '/tmp/file.bin');
      expect(w.workerClassName, 'CryptoWorker');
      expect(w.toMap()['workerType'], 'crypto');
      expect(w.toMap()['operation'], 'hash');
    });

    test('empty filePath throws ArgumentError', () {
      expect(
        () => NativeWorker.hashFile(filePath: ''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('NativeWorker.hashString convenience constructor', () {
    test('produces correct workerType and operation', () {
      final w = NativeWorker.hashString(data: 'hello world');
      expect(w.workerClassName, 'CryptoWorker');
      expect(w.toMap()['operation'], 'hash');
      expect(w.toMap()['data'], 'hello world');
    });

    test('empty data throws ArgumentError', () {
      expect(
        () => NativeWorker.hashString(data: ''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // NativeWorker.cryptoEncrypt / cryptoDecrypt convenience constructors
  // ──────────────────────────────────────────────────────────────────────────

  group('NativeWorker.cryptoEncrypt convenience constructor', () {
    test('produces correct workerType, className, and operation', () {
      final w = NativeWorker.cryptoEncrypt(
        inputPath: '/tmp/a.txt',
        outputPath: '/tmp/a.enc',
        password: 'str0ngPass',
      );
      expect(w.workerClassName, 'CryptoWorker');
      expect(w.toMap()['workerType'], 'crypto');
      expect(w.toMap()['operation'], 'encrypt');
    });

    test('empty password throws ArgumentError', () {
      expect(
        () => NativeWorker.cryptoEncrypt(
          inputPath: '/tmp/a.txt',
          outputPath: '/tmp/a.enc',
          password: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('password shorter than 8 chars throws ArgumentError', () {
      expect(
        () => NativeWorker.cryptoEncrypt(
          inputPath: '/tmp/a.txt',
          outputPath: '/tmp/a.enc',
          password: 'short',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('password exactly 8 chars is accepted', () {
      final w = NativeWorker.cryptoEncrypt(
        inputPath: '/tmp/a.txt',
        outputPath: '/tmp/a.enc',
        password: '12345678',
      );
      expect(w.toMap()['password'], '12345678');
    });

    test('empty inputPath throws ArgumentError', () {
      expect(
        () => NativeWorker.cryptoEncrypt(
          inputPath: '',
          outputPath: '/tmp/a.enc',
          password: 'str0ngPass',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('empty outputPath throws ArgumentError', () {
      expect(
        () => NativeWorker.cryptoEncrypt(
          inputPath: '/tmp/a.txt',
          outputPath: '',
          password: 'str0ngPass',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('NativeWorker.cryptoDecrypt convenience constructor', () {
    test('produces correct workerType, className, and operation', () {
      final w = NativeWorker.cryptoDecrypt(
        inputPath: '/tmp/a.enc',
        outputPath: '/tmp/a.txt',
        password: 'str0ngPass',
      );
      expect(w.workerClassName, 'CryptoWorker');
      expect(w.toMap()['operation'], 'decrypt');
    });

    test('empty password throws ArgumentError', () {
      expect(
        () => NativeWorker.cryptoDecrypt(
          inputPath: '/tmp/a.enc',
          outputPath: '/tmp/a.txt',
          password: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('empty inputPath throws ArgumentError', () {
      expect(
        () => NativeWorker.cryptoDecrypt(
          inputPath: '',
          outputPath: '/tmp/a.txt',
          password: 'str0ngPass',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // SC-H-007: Verify AES algorithm value in toMap() is 'AES' (not 'AES-CBC')
  // ──────────────────────────────────────────────────────────────────────────

  group('SC-H-007: AES algorithm value', () {
    test('EncryptionAlgorithm.aes serialises as "AES"', () {
      expect(EncryptionAlgorithm.aes.value, 'AES');
    });

    test('CryptoEncryptWorker uses AES algorithm value', () {
      const w = CryptoEncryptWorker(
        inputPath: '/tmp/in',
        outputPath: '/tmp/out',
        password: 'password123',
      );
      expect(w.toMap()['algorithm'], 'AES');
    });

    test('CryptoDecryptWorker uses AES algorithm value', () {
      const w = CryptoDecryptWorker(
        inputPath: '/tmp/in.enc',
        outputPath: '/tmp/out',
        password: 'password123',
      );
      expect(w.toMap()['algorithm'], 'AES');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // HashAlgorithm enum values
  // ──────────────────────────────────────────────────────────────────────────

  group('HashAlgorithm enum values', () {
    test('sha256 value is "SHA-256"', () {
      expect(HashAlgorithm.sha256.value, 'SHA-256');
    });

    test('sha512 value is "SHA-512"', () {
      expect(HashAlgorithm.sha512.value, 'SHA-512');
    });

    // ignore: deprecated_member_use
    test('md5 value is "MD5" (deprecated)', () {
      // ignore: deprecated_member_use
      expect(HashAlgorithm.md5.value, 'MD5');
    });

    // ignore: deprecated_member_use
    test('sha1 value is "SHA-1" (deprecated)', () {
      // ignore: deprecated_member_use
      expect(HashAlgorithm.sha1.value, 'SHA-1');
    });
  });
}
