import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:native_workmanager/native_workmanager.dart';

/// Guards a real gap found by the 2026-09-23 lib/ audit: `multiUpload`,
/// `moveToSharedStorage`, `webSocket`, and `ParallelHttpUploadWorker`'s
/// constructor (which has no `NativeWorker.*` factory) all reached native
/// with none of the URL/path validation every sibling HTTP/file worker
/// enforces — no HTTPS enforcement, no SSRF/private-IP blocking, no
/// path-traversal blocking.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('dev.brewkits/native_workmanager');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'initialize':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    NativeWorkManager.resetSecurityFlags();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('multiUpload() validators', () {
    test('rejects a private-IP URL when blockPrivateIPs is set', () async {
      NativeWorkManager.resetInitializedState();
      try {
        await NativeWorkManager.initialize(blockPrivateIPs: true);
      } catch (_) {}

      expect(
        () => NativeWorker.multiUpload(
          url: 'https://10.0.0.5/upload',
          files: const [UploadFile(filePath: '/tmp/a.jpg')],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a file path with ".." traversal', () {
      expect(
        () => NativeWorker.multiUpload(
          url: 'https://upload.example.com/batch',
          files: const [UploadFile(filePath: '/tmp/../../etc/passwd')],
        ),
        throwsArgumentError,
      );
    });

    test('accepts a normal https URL and absolute file paths', () {
      final w = NativeWorker.multiUpload(
        url: 'https://upload.example.com/batch',
        files: const [UploadFile(filePath: '/tmp/a.jpg')],
      );
      expect(w.toMap()['url'], 'https://upload.example.com/batch');
    });
  });

  group('moveToSharedStorage() validators', () {
    test('rejects a sourcePath with ".." traversal', () {
      expect(
        () => NativeWorker.moveToSharedStorage(
          sourcePath: '/tmp/../../etc/passwd',
          storageType: SharedStorageType.downloads,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a subDir with ".." traversal', () {
      expect(
        () => NativeWorker.moveToSharedStorage(
          sourcePath: '/tmp/photo.jpg',
          storageType: SharedStorageType.photos,
          subDir: '../../OtherApp/Camera',
        ),
        throwsArgumentError,
      );
    });

    test('accepts a normal relative subDir', () {
      final w = NativeWorker.moveToSharedStorage(
        sourcePath: '/tmp/photo.jpg',
        storageType: SharedStorageType.photos,
        subDir: 'Holidays',
      );
      expect(w.toMap()['subDir'], 'Holidays');
    });
  });

  group('webSocket() validators', () {
    test('rejects ws:// when enforceHttps is set', () async {
      NativeWorkManager.resetInitializedState();
      try {
        await NativeWorkManager.initialize(enforceHttps: true);
      } catch (_) {}

      expect(
        () => NativeWorker.webSocket(url: 'ws://insecure.example.com'),
        throwsArgumentError,
      );
    });

    test('rejects a storeResponseAt path with ".." traversal', () {
      expect(
        () => NativeWorker.webSocket(
          url: 'wss://api.example.com',
          storeResponseAt: '../../etc/hosts',
        ),
        throwsArgumentError,
      );
    });
  });

  group('ParallelHttpUploadWorker constructor validators', () {
    test('rejects a private-IP URL when blockPrivateIPs is set', () async {
      NativeWorkManager.resetInitializedState();
      try {
        await NativeWorkManager.initialize(blockPrivateIPs: true);
      } catch (_) {}

      expect(
        () => ParallelHttpUploadWorker(
          url: 'https://192.168.1.1/upload',
          files: const [UploadFile(filePath: '/tmp/a.jpg')],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a file path with ".." traversal', () {
      expect(
        () => ParallelHttpUploadWorker(
          url: 'https://upload.example.com',
          files: const [UploadFile(filePath: '/tmp/../../etc/passwd')],
        ),
        throwsArgumentError,
      );
    });
  });
}
