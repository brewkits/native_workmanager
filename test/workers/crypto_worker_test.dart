import 'package:flutter_test/flutter_test.dart';
import 'package:native_workmanager/native_workmanager.dart';

void main() {
  group('Crypto Workers', () {
    group('HashAlgorithm Enum', () {
      test('should have MD5 algorithm', () {
        expect(HashAlgorithm.md5.value, 'MD5');
      });

      test('should have SHA-1 algorithm', () {
        expect(HashAlgorithm.sha1.value, 'SHA-1');
      });

      test('should have SHA-256 algorithm', () {
        expect(HashAlgorithm.sha256.value, 'SHA-256');
      });

      test('should have SHA-512 algorithm', () {
        expect(HashAlgorithm.sha512.value, 'SHA-512');
      });
    });

    group('EncryptionAlgorithm Enum', () {
      test('should have AES algorithm', () {
        expect(EncryptionAlgorithm.aes.value, 'AES');
      });
    });

    group('CryptoHashWorker - File Hashing', () {
      test('should create hash worker for file with default algorithm', () {
        final worker = const CryptoHashWorker.file(
          filePath: '/data/document.pdf',
        );

        expect(worker.filePath, '/data/document.pdf');
        expect(worker.data, isNull);
        expect(worker.algorithm, HashAlgorithm.sha256); // default
      });

      test('should create hash worker for file with MD5', () {
        final worker = const CryptoHashWorker.file(
          filePath: '/downloads/file.zip',
          algorithm: HashAlgorithm.md5,
        );

        expect(worker.filePath, '/downloads/file.zip');
        expect(worker.algorithm, HashAlgorithm.md5);
      });

      test('should create hash worker for file with SHA-1', () {
        final worker = const CryptoHashWorker.file(
          filePath: '/data/image.jpg',
          algorithm: HashAlgorithm.sha1,
        );

        expect(worker.algorithm, HashAlgorithm.sha1);
      });

      test('should create hash worker for file with SHA-256', () {
        final worker = const CryptoHashWorker.file(
          filePath: '/data/file.txt',
          algorithm: HashAlgorithm.sha256,
        );

        expect(worker.algorithm, HashAlgorithm.sha256);
      });

      test('should create hash worker for file with SHA-512', () {
        final worker = const CryptoHashWorker.file(
          filePath: '/data/archive.tar.gz',
          algorithm: HashAlgorithm.sha512,
        );

        expect(worker.algorithm, HashAlgorithm.sha512);
      });

      test('should have correct workerClassName', () {
        final worker = const CryptoHashWorker.file(
          filePath: '/file.txt',
        );

        expect(worker.workerClassName, 'CryptoWorker');
      });

      test('should serialize file hash to map correctly', () {
        final worker = const CryptoHashWorker.file(
          filePath: '/data/file.bin',
          algorithm: HashAlgorithm.sha256,
        );

        final map = worker.toMap();

        expect(map['workerType'], 'crypto');
        expect(map['operation'], 'hash');
        expect(map['filePath'], '/data/file.bin');
        expect(map['data'], isNull);
        expect(map['algorithm'], 'SHA-256');
      });

      test('should serialize with different algorithms correctly', () {
        final workers = [
          const CryptoHashWorker.file(filePath: '/f', algorithm: HashAlgorithm.md5),
          const CryptoHashWorker.file(filePath: '/f', algorithm: HashAlgorithm.sha1),
          const CryptoHashWorker.file(filePath: '/f', algorithm: HashAlgorithm.sha256),
          const CryptoHashWorker.file(filePath: '/f', algorithm: HashAlgorithm.sha512),
        ];

        expect(workers[0].toMap()['algorithm'], 'MD5');
        expect(workers[1].toMap()['algorithm'], 'SHA-1');
        expect(workers[2].toMap()['algorithm'], 'SHA-256');
        expect(workers[3].toMap()['algorithm'], 'SHA-512');
      });
    });

    group('CryptoHashWorker - String Hashing', () {
      test('should create hash worker for string with default algorithm', () {
        final worker = const CryptoHashWorker.string(
          data: 'Hello, World!',
        );

        expect(worker.data, 'Hello, World!');
        expect(worker.filePath, isNull);
        expect(worker.algorithm, HashAlgorithm.sha256); // default
      });

      test('should create hash worker for string with MD5', () {
        final worker = const CryptoHashWorker.string(
          data: 'test data',
          algorithm: HashAlgorithm.md5,
        );

        expect(worker.data, 'test data');
        expect(worker.algorithm, HashAlgorithm.md5);
      });

      test('should create hash worker for string with SHA-1', () {
        final worker = const CryptoHashWorker.string(
          data: 'password123',
          algorithm: HashAlgorithm.sha1,
        );

        expect(worker.algorithm, HashAlgorithm.sha1);
      });

      test('should create hash worker for string with SHA-256', () {
        final worker = const CryptoHashWorker.string(
          data: 'sensitive data',
          algorithm: HashAlgorithm.sha256,
        );

        expect(worker.algorithm, HashAlgorithm.sha256);
      });

      test('should create hash worker for string with SHA-512', () {
        final worker = const CryptoHashWorker.string(
          data: 'very long string data',
          algorithm: HashAlgorithm.sha512,
        );

        expect(worker.algorithm, HashAlgorithm.sha512);
      });

      test('should serialize string hash to map correctly', () {
        final worker = const CryptoHashWorker.string(
          data: 'my secret data',
          algorithm: HashAlgorithm.sha256,
        );

        final map = worker.toMap();

        expect(map['workerType'], 'crypto');
        expect(map['operation'], 'hash');
        expect(map['data'], 'my secret data');
        expect(map['filePath'], isNull);
        expect(map['algorithm'], 'SHA-256');
      });

      test('should handle empty string', () {
        final worker = const CryptoHashWorker.string(
          data: '',
        );

        expect(worker.data, '');
        expect(worker.toMap()['data'], '');
      });

      test('should handle unicode strings', () {
        final worker = const CryptoHashWorker.string(
          data: 'Hello 世界 🌍',
        );

        expect(worker.data, 'Hello 世界 🌍');
        expect(worker.toMap()['data'], 'Hello 世界 🌍');
      });

      test('should handle very long strings', () {
        final longString = 'a' * 10000;
        final worker = CryptoHashWorker.string(
          data: longString,
        );

        expect(worker.data, longString);
      });

      test('should handle strings with special characters', () {
        final worker = const CryptoHashWorker.string(
          data: 'Line1\nLine2\tTabbed\r\nWindows',
        );

        expect(worker.data, contains('\n'));
        expect(worker.data, contains('\t'));
      });
    });

    group('NativeWorker.hashFile Factory', () {
      test('should create file hash worker through factory', () {
        final worker = NativeWorker.hashFile(
          filePath: '/documents/contract.pdf',
        );

        expect(worker, isA<CryptoHashWorker>());
        expect((worker as CryptoHashWorker).filePath, '/documents/contract.pdf');
      });

      test('should create file hash worker with custom algorithm', () {
        final worker = NativeWorker.hashFile(
          filePath: '/data/file.bin',
          algorithm: HashAlgorithm.md5,
        );

        expect((worker as CryptoHashWorker).algorithm, HashAlgorithm.md5);
      });

      test('should throw ArgumentError for empty filePath', () {
        expect(
          () => NativeWorker.hashFile(filePath: ''),
          throwsArgumentError,
        );
      });
    });

    group('NativeWorker.hashString Factory', () {
      test('should create string hash worker through factory', () {
        final worker = NativeWorker.hashString(
          data: 'password123',
        );

        expect(worker, isA<CryptoHashWorker>());
        expect((worker as CryptoHashWorker).data, 'password123');
      });

      test('should create string hash worker with custom algorithm', () {
        final worker = NativeWorker.hashString(
          data: 'test',
          algorithm: HashAlgorithm.sha512,
        );

        expect((worker as CryptoHashWorker).algorithm, HashAlgorithm.sha512);
      });

      test('should throw ArgumentError for empty data', () {
        expect(
          () => NativeWorker.hashString(data: ''),
          throwsArgumentError,
        );
      });
    });

    group('CryptoEncryptWorker', () {
      test('should create encrypt worker with required fields', () {
        final worker = const CryptoEncryptWorker(
          inputPath: '/data/sensitive.txt',
          outputPath: '/data/sensitive.enc',
          password: 'my_secure_password',
        );

        expect(worker.inputPath, '/data/sensitive.txt');
        expect(worker.outputPath, '/data/sensitive.enc');
        expect(worker.password, 'my_secure_password');
        expect(worker.algorithm, EncryptionAlgorithm.aes); // default
      });

      test('should create encrypt worker with explicit algorithm', () {
        final worker = const CryptoEncryptWorker(
          inputPath: '/file.txt',
          outputPath: '/file.enc',
          password: 'pass',
          algorithm: EncryptionAlgorithm.aes,
        );

        expect(worker.algorithm, EncryptionAlgorithm.aes);
      });

      test('should have correct workerClassName', () {
        final worker = const CryptoEncryptWorker(
          inputPath: '/in.txt',
          outputPath: '/out.enc',
          password: 'pass',
        );

        expect(worker.workerClassName, 'CryptoWorker');
      });

      test('should serialize to map correctly', () {
        final worker = const CryptoEncryptWorker(
          inputPath: '/documents/report.docx',
          outputPath: '/encrypted/report.enc',
          password: 'SuperSecure123!',
        );

        final map = worker.toMap();

        expect(map['workerType'], 'crypto');
        expect(map['operation'], 'encrypt');
        expect(map['filePath'], '/documents/report.docx');
        expect(map['outputPath'], '/encrypted/report.enc');
        expect(map['password'], 'SuperSecure123!');
        expect(map['algorithm'], 'AES');
      });

      test('should handle short passwords', () {
        final worker = const CryptoEncryptWorker(
          inputPath: '/file.txt',
          outputPath: '/file.enc',
          password: '123',
        );

        expect(worker.password, '123');
      });

      test('should handle long passwords', () {
        final longPassword = 'a' * 1000;
        final worker = CryptoEncryptWorker(
          inputPath: '/file.txt',
          outputPath: '/file.enc',
          password: longPassword,
        );

        expect(worker.password, longPassword);
      });

      test('should handle passwords with special characters', () {
        final worker = const CryptoEncryptWorker(
          inputPath: '/file.txt',
          outputPath: '/file.enc',
          password: 'P@ssw0rd!#\$%^&*()[]{}',
        );

        expect(worker.password, 'P@ssw0rd!#\$%^&*()[]{}');
      });

      test('should handle unicode passwords', () {
        final worker = const CryptoEncryptWorker(
          inputPath: '/file.txt',
          outputPath: '/file.enc',
          password: 'пароль密码🔒',
        );

        expect(worker.password, 'пароль密码🔒');
      });
    });

    group('NativeWorker.cryptoEncrypt Factory', () {
      test('should create encrypt worker through factory', () {
        final worker = NativeWorker.cryptoEncrypt(
          inputPath: '/data/secret.pdf',
          outputPath: '/data/secret.enc',
          password: 'myPassword123',
        );

        expect(worker, isA<CryptoEncryptWorker>());
        final encrypt = worker as CryptoEncryptWorker;
        expect(encrypt.inputPath, '/data/secret.pdf');
        expect(encrypt.outputPath, '/data/secret.enc');
        expect(encrypt.password, 'myPassword123');
      });

      test('should throw ArgumentError for empty inputPath', () {
        expect(
          () => NativeWorker.cryptoEncrypt(
            inputPath: '',
            outputPath: '/out.enc',
            password: 'pass',
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for empty outputPath', () {
        expect(
          () => NativeWorker.cryptoEncrypt(
            inputPath: '/in.txt',
            outputPath: '',
            password: 'pass',
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for empty password', () {
        expect(
          () => NativeWorker.cryptoEncrypt(
            inputPath: '/in.txt',
            outputPath: '/out.enc',
            password: '',
          ),
          throwsArgumentError,
        );
      });
    });

    group('CryptoDecryptWorker', () {
      test('should create decrypt worker with required fields', () {
        final worker = const CryptoDecryptWorker(
          inputPath: '/data/encrypted.enc',
          outputPath: '/data/decrypted.txt',
          password: 'my_secure_password',
        );

        expect(worker.inputPath, '/data/encrypted.enc');
        expect(worker.outputPath, '/data/decrypted.txt');
        expect(worker.password, 'my_secure_password');
        expect(worker.algorithm, EncryptionAlgorithm.aes); // default
      });

      test('should create decrypt worker with explicit algorithm', () {
        final worker = const CryptoDecryptWorker(
          inputPath: '/file.enc',
          outputPath: '/file.txt',
          password: 'pass',
          algorithm: EncryptionAlgorithm.aes,
        );

        expect(worker.algorithm, EncryptionAlgorithm.aes);
      });

      test('should have correct workerClassName', () {
        final worker = const CryptoDecryptWorker(
          inputPath: '/in.enc',
          outputPath: '/out.txt',
          password: 'pass',
        );

        expect(worker.workerClassName, 'CryptoWorker');
      });

      test('should serialize to map correctly', () {
        final worker = const CryptoDecryptWorker(
          inputPath: '/encrypted/report.enc',
          outputPath: '/documents/report.docx',
          password: 'SuperSecure123!',
        );

        final map = worker.toMap();

        expect(map['workerType'], 'crypto');
        expect(map['operation'], 'decrypt');
        expect(map['filePath'], '/encrypted/report.enc');
        expect(map['outputPath'], '/documents/report.docx');
        expect(map['password'], 'SuperSecure123!');
        expect(map['algorithm'], 'AES');
      });

      test('should match password format with encrypt worker', () {
        const password = 'TestPassword123!';
        final encryptWorker = const CryptoEncryptWorker(
          inputPath: '/original.txt',
          outputPath: '/encrypted.enc',
          password: password,
        );
        final decryptWorker = const CryptoDecryptWorker(
          inputPath: '/encrypted.enc',
          outputPath: '/decrypted.txt',
          password: password,
        );

        expect(encryptWorker.password, decryptWorker.password);
      });
    });

    group('NativeWorker.cryptoDecrypt Factory', () {
      test('should create decrypt worker through factory', () {
        final worker = NativeWorker.cryptoDecrypt(
          inputPath: '/data/secret.enc',
          outputPath: '/data/secret.pdf',
          password: 'myPassword123',
        );

        expect(worker, isA<CryptoDecryptWorker>());
        final decrypt = worker as CryptoDecryptWorker;
        expect(decrypt.inputPath, '/data/secret.enc');
        expect(decrypt.outputPath, '/data/secret.pdf');
        expect(decrypt.password, 'myPassword123');
      });

      test('should throw ArgumentError for empty inputPath', () {
        expect(
          () => NativeWorker.cryptoDecrypt(
            inputPath: '',
            outputPath: '/out.txt',
            password: 'pass',
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for empty outputPath', () {
        expect(
          () => NativeWorker.cryptoDecrypt(
            inputPath: '/in.enc',
            outputPath: '',
            password: 'pass',
          ),
          throwsArgumentError,
        );
      });

      test('should throw ArgumentError for empty password', () {
        expect(
          () => NativeWorker.cryptoDecrypt(
            inputPath: '/in.enc',
            outputPath: '/out.txt',
            password: '',
          ),
          throwsArgumentError,
        );
      });
    });

    group('Edge Cases', () {
      test('should handle very long file paths for hash', () {
        final longPath = '/data/${'very_long_directory/' * 20}file.bin';
        final worker = CryptoHashWorker.file(filePath: longPath);

        expect(worker.filePath, longPath);
      });

      test('should handle paths with special characters', () {
        final worker = const CryptoEncryptWorker(
          inputPath: '/data/file (copy 1).txt',
          outputPath: '/encrypted/file-encrypted.enc',
          password: 'pass',
        );

        expect(worker.inputPath, '/data/file (copy 1).txt');
      });

      test('should handle unicode file paths', () {
        final worker = const CryptoDecryptWorker(
          inputPath: '/文件/зашифровано.enc',
          outputPath: '/файлы/расшифровано.txt',
          password: 'пароль',
        );

        expect(worker.inputPath, '/文件/зашифровано.enc');
        expect(worker.outputPath, '/файлы/расшифровано.txt');
      });

      test('should handle binary data representation in string hash', () {
        final worker = const CryptoHashWorker.string(
          data: '\x00\x01\x02\xFF',
        );

        expect(worker.data, isNotEmpty);
      });
    });

    group('Real-world Scenarios', () {
      test('should configure for file integrity verification (SHA-256)', () {
        final worker = NativeWorker.hashFile(
          filePath: '/downloads/installer-v2.0.exe',
          algorithm: HashAlgorithm.sha256,
        );

        expect((worker as CryptoHashWorker).algorithm, HashAlgorithm.sha256);
      });

      test('should configure for password hashing (SHA-512)', () {
        final worker = NativeWorker.hashString(
          data: 'user_password_plain',
          algorithm: HashAlgorithm.sha512,
        );

        expect((worker as CryptoHashWorker).algorithm, HashAlgorithm.sha512);
      });

      test('should configure for legacy MD5 checksums', () {
        final worker = NativeWorker.hashFile(
          filePath: '/archives/old_backup.tar.gz',
          algorithm: HashAlgorithm.md5,
        );

        expect((worker as CryptoHashWorker).algorithm, HashAlgorithm.md5);
      });

      test('should configure for encrypting sensitive documents', () {
        final worker = NativeWorker.cryptoEncrypt(
          inputPath: '/documents/tax_return_2024.pdf',
          outputPath: '/secure/tax_return_2024.enc',
          password: 'VeryStrongPassword123!@#',
        );

        final encrypt = worker as CryptoEncryptWorker;
        expect(encrypt.inputPath, contains('tax_return'));
        expect(encrypt.outputPath, endsWith('.enc'));
      });

      test('should configure for decrypting backup files', () {
        final worker = NativeWorker.cryptoDecrypt(
          inputPath: '/backups/database_backup.enc',
          outputPath: '/restore/database.sql',
          password: 'BackupPassword2024',
        );

        final decrypt = worker as CryptoDecryptWorker;
        expect(decrypt.inputPath, endsWith('.enc'));
        expect(decrypt.outputPath, endsWith('.sql'));
      });

      test('should configure for API token hashing', () {
        final worker = NativeWorker.hashString(
          data: 'sk-1234567890abcdefghijklmnop',
          algorithm: HashAlgorithm.sha256,
        );

        expect((worker as CryptoHashWorker).data, startsWith('sk-'));
      });
    });

    group('Encrypt-Decrypt Round Trip', () {
      test('should use same password for encrypt and decrypt', () {
        const password = 'SharedPassword123!';
        const inputFile = '/data/original.pdf';
        const encryptedFile = '/data/encrypted.enc';
        const decryptedFile = '/data/decrypted.pdf';

        final encryptWorker = CryptoEncryptWorker(
          inputPath: inputFile,
          outputPath: encryptedFile,
          password: password,
        );

        final decryptWorker = CryptoDecryptWorker(
          inputPath: encryptedFile,
          outputPath: decryptedFile,
          password: password,
        );

        expect(encryptWorker.password, decryptWorker.password);
        expect(encryptWorker.outputPath, decryptWorker.inputPath);
      });

      test('should use same algorithm for encrypt and decrypt', () {
        final encryptWorker = const CryptoEncryptWorker(
          inputPath: '/file.txt',
          outputPath: '/file.enc',
          password: 'pass',
          algorithm: EncryptionAlgorithm.aes,
        );

        final decryptWorker = const CryptoDecryptWorker(
          inputPath: '/file.enc',
          outputPath: '/file.txt',
          password: 'pass',
          algorithm: EncryptionAlgorithm.aes,
        );

        expect(encryptWorker.algorithm, decryptWorker.algorithm);
      });
    });

    group('Hash Algorithm Comparison', () {
      test('should create workers with different hash algorithms', () {
        const filePath = '/data/test.bin';

        final md5Worker = NativeWorker.hashFile(
          filePath: filePath,
          algorithm: HashAlgorithm.md5,
        );
        final sha1Worker = NativeWorker.hashFile(
          filePath: filePath,
          algorithm: HashAlgorithm.sha1,
        );
        final sha256Worker = NativeWorker.hashFile(
          filePath: filePath,
          algorithm: HashAlgorithm.sha256,
        );
        final sha512Worker = NativeWorker.hashFile(
          filePath: filePath,
          algorithm: HashAlgorithm.sha512,
        );

        expect((md5Worker as CryptoHashWorker).algorithm, HashAlgorithm.md5);
        expect((sha1Worker as CryptoHashWorker).algorithm, HashAlgorithm.sha1);
        expect((sha256Worker as CryptoHashWorker).algorithm, HashAlgorithm.sha256);
        expect((sha512Worker as CryptoHashWorker).algorithm, HashAlgorithm.sha512);
      });

      test('should serialize all hash algorithms correctly', () {
        const data = 'test';

        final workers = [
          NativeWorker.hashString(data: data, algorithm: HashAlgorithm.md5),
          NativeWorker.hashString(data: data, algorithm: HashAlgorithm.sha1),
          NativeWorker.hashString(data: data, algorithm: HashAlgorithm.sha256),
          NativeWorker.hashString(data: data, algorithm: HashAlgorithm.sha512),
        ];

        final algorithms = workers
            .map((w) => (w as CryptoHashWorker).toMap()['algorithm'])
            .toList();

        expect(algorithms, ['MD5', 'SHA-1', 'SHA-256', 'SHA-512']);
      });
    });
  });
}
