# Dio Integration Guide

Integration guide for using native_workmanager with **Dio** - the powerful HTTP client for Dart.

---

## Overview

Dio is a popular HTTP client that provides:
- Interceptors for request/response handling
- FormData for file uploads
- Timeout configuration
- Request cancellation
- And more...

This guide shows how to use Dio with native_workmanager for background HTTP tasks.

---

## Installation

```yaml
dependencies:
  native_workmanager: ^1.4.1
  dio: ^5.4.0
```

```bash
flutter pub get
```

---

## Use Cases

### ✅ When to Use Dio with native_workmanager

1. **Complex API requests** requiring interceptors
2. **Authentication refresh** in background tasks
3. **Custom error handling** with retry logic
4. **File downloads** with progress tracking
5. **Multipart uploads** with custom headers

### ⚠️  When to Use Native Workers Instead

1. **Simple HTTP requests** → Use `NativeWorker.httpRequest()`
2. **File uploads** → Use `NativeWorker.httpUpload()`
3. **File downloads** → Use `NativeWorker.httpDownload()`

**Why?** Native workers don't require Flutter Engine (no Flutter Engine overhead).

---

## Pattern 1: Dio in Dart Worker

For complex requests requiring Dio features.

### Setup

```dart
import 'package:native_workmanager/native_workmanager.dart';
import 'package:dio/dio.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dart workers are registered via the `dartWorkers` map, not a separate
  // registration call — the map key is the `callbackId` used by DartWorker.
  await NativeWorkManager.initialize(
    dartWorkers: {
      'dioSync': dioSyncCallback,
    },
  );

  runApp(MyApp());
}

// DartWorkerCallback signature: Future<bool> Function(Map<String, dynamic>? input)
// — return true on success, false on failure (throwing also counts as failure).
@pragma('vm:entry-point')
Future<bool> dioSyncCallback(Map<String, dynamic>? input) async {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.example.com',
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
  ));

  // Add interceptors
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
  ));

  dio.interceptors.add(AuthInterceptor());

  try {
    final response = await dio.post('/sync', data: {
      'timestamp': DateTime.now().toIso8601String(),
    });

    print('Sync successful: ${response.data}');
    return true;
  } catch (e) {
    print('Sync failed: $e');
    return false;
  }
}
```

### Schedule Task

```dart
await NativeWorkManager.enqueue(
  taskId: 'dio-sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: DartWorker(
    callbackId: 'dioSync',
    autoDispose: true,  // Dispose Flutter Engine after completion
  ),
);
```

---

## Pattern 2: Authentication Refresh

Background token refresh using Dio interceptors.

### Implementation

```dart
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Get stored token
    final token = await getStoredToken();

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token expired, refresh it
      try {
        final newToken = await refreshToken();
        await saveToken(newToken);

        // Retry original request with new token
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';
        final response = await Dio().fetch(opts);

        handler.resolve(response);
        return;
      } catch (e) {
        handler.next(err);
        return;
      }
    }

    handler.next(err);
  }
}

@pragma('vm:entry-point')
Future<bool> authSyncCallback(Map<String, dynamic>? input) async {
  final dio = Dio();
  dio.interceptors.add(AuthInterceptor());

  final response = await dio.get('https://api.example.com/user/data');
  print('Data synced: ${response.data}');
  return response.statusCode == 200;
}
```

### Schedule

```dart
await NativeWorkManager.enqueue(
  taskId: 'auth-sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: DartWorker(callbackId: 'authSync'),
  constraints: Constraints(requiresNetwork: true),
);
```

---

## Pattern 3: File Download with Progress

Download files with Dio progress tracking.

### Implementation

```dart
@pragma('vm:entry-point')
Future<bool> downloadWithDioCallback(Map<String, dynamic>? input) async {
  final dio = Dio();

  await dio.download(
    'https://cdn.example.com/large-file.zip',
    '/downloads/file.zip',
    onReceiveProgress: (received, total) {
      if (total != -1) {
        final progress = (received / total * 100).toStringAsFixed(0);
        print('Download progress: $progress%');

        // Update progress (if needed for UI)
        // Note: Background tasks may not always be able to update UI
      }
    },
  );

  print('Download complete!');
  return true;
}
```

### Schedule

```dart
await NativeWorkManager.enqueue(
  taskId: 'dio-download',
  trigger: TaskTrigger.oneTime(),
  worker: DartWorker(callbackId: 'downloadWithDio'),
  constraints: Constraints(
    requiresUnmeteredNetwork: true,  // Large download, use WiFi only
  ),
);
```

**⚠️  Note:** For simple downloads without Dio features, use `NativeWorker.httpDownload()` instead (lower memory usage).

---

## Pattern 4: File Upload with FormData

Upload files with additional form fields using Dio.

### Implementation

```dart
@pragma('vm:entry-point')
Future<bool> uploadWithDioCallback(Map<String, dynamic>? input) async {
  final dio = Dio();

  final formData = FormData.fromMap({
    'file': await MultipartFile.fromFile(
      '/photos/image.jpg',
      filename: 'upload.jpg',
    ),
    'userId': '123',
    'description': 'My photo',
    'tags': ['nature', 'landscape'],
  });

  final response = await dio.post(
    'https://api.example.com/upload',
    data: formData,
    options: Options(
      headers: {
        'Authorization': 'Bearer token',
      },
    ),
    onSendProgress: (sent, total) {
      final progress = (sent / total * 100).toStringAsFixed(0);
      print('Upload progress: $progress%');
    },
  );

  print('Upload complete: ${response.data}');
  return response.statusCode == 200;
}
```

**⚠️  Alternative:** For simpler uploads, use `NativeWorker.httpUpload()` (no Flutter Engine required).

---

## Pattern 5: Retry Logic with Dio

Dio's built-in retry mechanism.

### Setup

```dart
import 'package:dio/dio.dart';
import 'package:dio_retry/dio_retry.dart';  // Add to pubspec.yaml

@pragma('vm:entry-point')
Future<bool> retryableRequestCallback(Map<String, dynamic>? input) async {
  final dio = Dio();

  // Add retry interceptor
  dio.interceptors.add(
    RetryInterceptor(
      dio: dio,
      logPrint: print,
      retries: 3,  // Max 3 retries
      retryDelays: const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 3),
      ],
    ),
  );

  final response = await dio.get('https://api.example.com/data');
  print('Data fetched: ${response.data}');
  return response.statusCode == 200;
}
```

**Note:** native_workmanager also has built-in retry with `BackoffPolicy`:

```dart
await NativeWorkManager.enqueue(
  taskId: 'sync',
  trigger: TaskTrigger.oneTime(),
  worker: DartWorker(callbackId: 'retryableRequest'),
  constraints: Constraints(
    backoffPolicy: BackoffPolicy.exponential,
    backoffDelayMs: 10000,
    maxRetries: 5,
  ),
);
```

---

## Best Practices

### 1. Use Native Workers When Possible

```dart
// ❌ Avoid (uses Dio in Dart worker - Flutter Engine overhead)
@pragma('vm:entry-point')
Future<bool> simpleSyncCallback(Map<String, dynamic>? input) async {
  final dio = Dio();
  final response = await dio.get('https://api.example.com/sync');
  return response.statusCode == 200;
}

// ✅ Better (native worker - no overhead)
await NativeWorkManager.enqueue(
  taskId: 'sync',
  trigger: TaskTrigger.periodic(Duration(hours: 1)),
  worker: NativeWorker.httpRequest(
    url: 'https://api.example.com/sync',
  ),
);
```

### 2. Dispose Dio Instances

```dart
@pragma('vm:entry-point')
Future<bool> dioCallback(Map<String, dynamic>? input) async {
  final dio = Dio();

  try {
    final response = await dio.get('https://api.example.com/data');
    return response.statusCode == 200;
  } finally {
    dio.close();  // Always close Dio instance
  }
}
```

### 3. Use autoDispose for Dart Workers

```dart
await NativeWorkManager.enqueue(
  taskId: 'dio-task',
  trigger: TaskTrigger.oneTime(),
  worker: DartWorker(
    callbackId: 'dioCallback',
    autoDispose: true,  // Dispose Flutter Engine after completion
  ),
);
```

### 4. Handle Errors Properly

```dart
@pragma('vm:entry-point')
Future<bool> dioCallback(Map<String, dynamic>? input) async {
  final dio = Dio();

  try {
    final response = await dio.get('https://api.example.com/data');
    print('Success: ${response.data}');
    return true;
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      print('Connection timeout');
    } else if (e.type == DioExceptionType.receiveTimeout) {
      print('Receive timeout');
    } else if (e.response?.statusCode == 401) {
      print('Unauthorized');
    }
    return false;  // native_workmanager retries based on Constraints.maxRetries
  }
}
```

---

## Performance Comparison

| Approach | Memory | Startup | Use When |
|----------|--------|---------|----------|
| **Native Worker** | Low | Fast | Simple HTTP GET/POST |
| **Dio in Dart Worker** | Higher | Slower | Complex requests with interceptors |
| **Dio with autoDispose** | Higher (temp) | Slower | One-off complex requests |

**Recommendation:** Use native workers for 80% of cases, Dio for complex scenarios.

---

## Example: Complete Sync Service

```dart
import 'package:native_workmanager/native_workmanager.dart';
import 'package:dio/dio.dart';

class SyncService {
  static Future<void> initialize() async {
    await NativeWorkManager.initialize(
      dartWorkers: {
        'dioSync': _dioSyncCallback,
        'dioUpload': _dioUploadCallback,
      },
    );

    // Schedule periodic sync (native worker - lightweight)
    await NativeWorkManager.enqueue(
      taskId: 'simple-sync',
      trigger: TaskTrigger.periodic(Duration(hours: 1)),
      worker: NativeWorker.httpRequest(
        url: 'https://api.example.com/simple-sync',
      ),
    );

    // Schedule complex sync (Dio - heavyweight)
    await NativeWorkManager.enqueue(
      taskId: 'complex-sync',
      trigger: TaskTrigger.periodic(Duration(hours: 6)),
      worker: DartWorker(
        callbackId: 'dioSync',
        autoDispose: true,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> _dioSyncCallback(Map<String, dynamic>? input) async {
    final dio = _createDio();

    try {
      final response = await dio.post('/sync', data: {
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('Complex sync complete: ${response.data}');
      return response.statusCode == 200;
    } finally {
      dio.close();
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> _dioUploadCallback(Map<String, dynamic>? input) async {
    final dio = _createDio();

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(input!['filePath'] as String),
      });
      final response = await dio.post('/upload', data: formData);
      print('Upload complete');
      return response.statusCode == 200;
    } finally {
      dio.close();
    }
  }

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://api.example.com',
      connectTimeout: Duration(seconds: 30),
      receiveTimeout: Duration(seconds: 30),
    ));

    dio.interceptors.add(AuthInterceptor());
    dio.interceptors.add(LogInterceptor());

    return dio;
  }
}
```

---

## Troubleshooting

### Issue: Dio timeout in background

**Solution:** Increase timeout for background tasks:
```dart
final dio = Dio(BaseOptions(
  connectTimeout: Duration(minutes: 2),  // Longer for background
  receiveTimeout: Duration(minutes: 5),
));
```

### Issue: High memory usage

**Solution:** Use native workers for simple requests:
```dart
// Instead of Dio for simple GET:
worker: NativeWorker.httpRequest(url: '...'),
```

### Issue: Auth token expired

**Solution:** Implement token refresh interceptor (see Pattern 2 above).

---

## Additional Resources

- [Dio Documentation](https://pub.dev/packages/dio)
- [native_workmanager Dart Workers](../EXTENSIBILITY.md)

---

**Last Updated:** 2026-02-07
