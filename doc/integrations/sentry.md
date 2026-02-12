# Sentry Integration Guide

Integration guide for using native_workmanager with **Sentry** - Error tracking, performance monitoring, and diagnostics.

---

## Overview

Sentry provides:
- **Error Tracking** - Automatic crash reporting
- **Performance Monitoring** - Transaction tracing
- **Breadcrumbs** - Context for debugging
- **Release Health** - Track app stability
- **Custom Context** - User, device, and custom data

This guide shows how to integrate Sentry with native_workmanager for background task monitoring.

---

## Installation

```yaml
dependencies:
  native_workmanager: ^1.0.0
  sentry_flutter: ^7.14.0
```

```bash
flutter pub get
```

---

## Setup

### Initialize Sentry

```dart
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:native_workmanager/native_workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SentryFlutter.init(
    (options) {
      options.dsn = 'YOUR_SENTRY_DSN';
      options.environment = 'production';
      options.release = '1.0.0';
      options.tracesSampleRate = 1.0; // Capture 100% of transactions
      options.enableAutoSessionTracking = true;
      options.attachScreenshot = true;
      options.attachViewHierarchy = true;
    },
    appRunner: () async {
      await NativeWorkManager.initialize();

      // Register callbacks
      NativeWorkManager.registerCallback('syncWithSentry', syncWithSentryCallback);

      runApp(MyApp());
    },
  );
}
```

---

## Pattern 1: Basic Error Tracking

Capture errors and exceptions in background tasks.

### Implementation

```dart
@pragma('vm:entry-point')
Future<void> syncWithSentryCallback(String? input) async {
  // Create Sentry transaction for monitoring
  final transaction = Sentry.startTransaction(
    'background-sync',
    'task',
    bindToScope: true,
  );

  try {
    // Set context
    Sentry.configureScope((scope) {
      scope.setTag('task_type', 'background_sync');
      scope.setTag('task_id', 'sync-1');
      scope.setExtra('input', input ?? 'none');
      scope.setContexts('task', {
        'triggered_at': DateTime.now().toIso8601String(),
        'worker_type': 'dart',
      });
    });

    // Add breadcrumb
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Starting background sync',
      category: 'task',
      level: SentryLevel.info,
    ));

    // Your background task logic
    await performSync();

    // Mark transaction as success
    transaction.status = SpanStatus.ok();
  } catch (error, stackTrace) {
    // Mark transaction as error
    transaction.status = SpanStatus.internalError();

    // Capture exception with context
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: Hint.withMap({
        'task_id': 'sync-1',
        'input': input,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    // Re-throw to trigger retry
    rethrow;
  } finally {
    // Finish transaction
    await transaction.finish();
  }
}

Future<void> performSync() async {
  // Your sync logic
}
```

---

## Pattern 2: Performance Monitoring

Track performance of background tasks with spans.

### Implementation

```dart
@pragma('vm:entry-point')
Future<void> performanceMonitoredCallback(String? input) async {
  final transaction = Sentry.startTransaction(
    'complex-sync',
    'task',
  );

  try {
    // Span 1: Fetch data
    final fetchSpan = transaction.startChild('fetch-data');
    Sentry.addBreadcrumb(Breadcrumb(message: 'Fetching data from API'));

    final data = await fetchDataFromAPI();
    fetchSpan.status = SpanStatus.ok();
    await fetchSpan.finish();

    // Span 2: Process data
    final processSpan = transaction.startChild('process-data');
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Processing ${data.length} items',
    ));

    final processed = await processData(data);
    processSpan.status = SpanStatus.ok();
    await processSpan.finish();

    // Span 3: Save to database
    final saveSpan = transaction.startChild('save-to-db');
    Sentry.addBreadcrumb(Breadcrumb(message: 'Saving to database'));

    await saveToDatabase(processed);
    saveSpan.status = SpanStatus.ok();
    await saveSpan.finish();

    transaction.status = SpanStatus.ok();
  } catch (error, stackTrace) {
    transaction.status = SpanStatus.internalError();
    await Sentry.captureException(error, stackTrace: stackTrace);
    rethrow;
  } finally {
    await transaction.finish();
  }
}

Future<List<dynamic>> fetchDataFromAPI() async {
  // Fetch logic
  return [];
}

Future<List<dynamic>> processData(List<dynamic> data) async {
  // Process logic
  return data;
}

Future<void> saveToDatabase(List<dynamic> data) async {
  // Save logic
}
```

---

## Pattern 3: Breadcrumbs for Debugging

Add detailed breadcrumbs for context when errors occur.

### Implementation

```dart
@pragma('vm:entry-point')
Future<void> breadcrumbCallback(String? input) async {
  final transaction = Sentry.startTransaction('sync-with-breadcrumbs', 'task');

  try {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Task started',
      category: 'task.lifecycle',
      level: SentryLevel.info,
      data: {'input': input},
    ));

    // Step 1: Check network
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Checking network connectivity',
      category: 'network',
    ));

    final isOnline = await checkNetwork();
    if (!isOnline) {
      throw Exception('No network connection');
    }

    // Step 2: Authenticate
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Authenticating user',
      category: 'auth',
    ));

    final token = await authenticate();

    // Step 3: Fetch data
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Fetching data with token',
      category: 'api',
      data: {'token_length': token.length},
    ));

    final data = await fetchData(token);

    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Data fetched successfully',
      category: 'api',
      level: SentryLevel.info,
      data: {'data_count': data.length},
    ));

    // Step 4: Process
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Processing data',
      category: 'processing',
    ));

    await process(data);

    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Task completed successfully',
      category: 'task.lifecycle',
      level: SentryLevel.info,
    ));

    transaction.status = SpanStatus.ok();
  } catch (error, stackTrace) {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Task failed: ${error.toString()}',
      category: 'task.lifecycle',
      level: SentryLevel.error,
    ));

    transaction.status = SpanStatus.internalError();
    await Sentry.captureException(error, stackTrace: stackTrace);
    rethrow;
  } finally {
    await transaction.finish();
  }
}

Future<bool> checkNetwork() async => true;
Future<String> authenticate() async => 'token';
Future<List<dynamic>> fetchData(String token) async => [];
Future<void> process(List<dynamic> data) async {}
```

---

## Pattern 4: User Context & Custom Data

Add user and custom context to background tasks.

### Implementation

```dart
@pragma('vm:entry-point')
Future<void> contextAwareCallback(String? input) async {
  final transaction = Sentry.startTransaction('user-sync', 'task');

  try {
    // Load user data
    final user = await getCurrentUser();

    // Set user context
    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: user.id,
        email: user.email,
        username: user.username,
        ipAddress: '{{auto}}',
        data: {'subscription': user.subscription},
      ));

      // Set tags
      scope.setTag('user_type', user.type);
      scope.setTag('subscription_tier', user.subscription);
      scope.setTag('platform', Platform.operatingSystem);

      // Set custom context
      scope.setContexts('device', {
        'battery_level': '80%',
        'storage_free': '2.5GB',
        'network_type': 'wifi',
      });

      scope.setContexts('app_state', {
        'last_sync': user.lastSync.toIso8601String(),
        'items_pending': user.pendingItems,
      });
    });

    // Perform sync
    await performUserSync(user);

    transaction.status = SpanStatus.ok();
  } catch (error, stackTrace) {
    transaction.status = SpanStatus.internalError();
    await Sentry.captureException(error, stackTrace: stackTrace);
    rethrow;
  } finally {
    await transaction.finish();
  }
}

class User {
  final String id;
  final String email;
  final String username;
  final String type;
  final String subscription;
  final DateTime lastSync;
  final int pendingItems;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.type,
    required this.subscription,
    required this.lastSync,
    required this.pendingItems,
  });
}

Future<User> getCurrentUser() async {
  return User(
    id: '123',
    email: 'user@example.com',
    username: 'user',
    type: 'premium',
    subscription: 'pro',
    lastSync: DateTime.now(),
    pendingItems: 5,
  );
}

Future<void> performUserSync(User user) async {
  // Sync logic
}
```

---

## Pattern 5: Rate Limiting & Sampling

Control error reporting rate to avoid quota issues.

### Implementation

```dart
// In main.dart initialization
await SentryFlutter.init(
  (options) {
    options.dsn = 'YOUR_SENTRY_DSN';

    // Sample only 10% of successful transactions
    options.tracesSampleRate = 0.1;

    // Custom sampler for more control
    options.tracesSampler = (samplingContext) {
      // Always sample errors
      if (samplingContext.transactionContext.name == 'error-task') {
        return 1.0; // 100%
      }

      // Sample background tasks at 10%
      if (samplingContext.transactionContext.operation == 'task') {
        return 0.1; // 10%
      }

      // Default: 1%
      return 0.01;
    };

    // Filter before sending
    options.beforeSend = (event, hint) {
      // Don't send network errors (too common)
      if (event.exceptions?.any((e) => e.type == 'SocketException') ?? false) {
        return null; // Drop event
      }

      // Add custom tag
      event.tags = {
        ...?event.tags,
        'source': 'background_task',
      };

      return event;
    };
  },
);
```

---

## Pattern 6: Integration with native_workmanager Events

Monitor task lifecycle with Sentry.

### Implementation

```dart
void setupTaskMonitoring() {
  NativeWorkManager.events.listen((event) {
    // Add breadcrumb for task state changes
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Task ${event.taskId}: ${event.state}',
      category: 'task.lifecycle',
      level: _sentryLevelFromState(event.state),
      data: {
        'task_id': event.taskId,
        'state': event.state.toString(),
        'progress': event.progress,
        'attempt': event.attemptCount,
      },
    ));

    // Capture failed tasks
    if (event.state == TaskState.failed) {
      Sentry.captureMessage(
        'Background task failed: ${event.taskId}',
        level: SentryLevel.error,
        hint: Hint.withMap({
          'task_id': event.taskId,
          'error': event.error,
          'attempt': event.attemptCount,
        }),
      );
    }
  });
}

SentryLevel _sentryLevelFromState(TaskState state) {
  switch (state) {
    case TaskState.enqueued:
      return SentryLevel.info;
    case TaskState.running:
      return SentryLevel.info;
    case TaskState.succeeded:
      return SentryLevel.info;
    case TaskState.failed:
      return SentryLevel.error;
    case TaskState.cancelled:
      return SentryLevel.warning;
    default:
      return SentryLevel.debug;
  }
}
```

---

## Best Practices

### 1. Always Finish Transactions

```dart
@pragma('vm:entry-point')
Future<void> callback(String? input) async {
  final transaction = Sentry.startTransaction('task', 'task');

  try {
    await work();
    transaction.status = SpanStatus.ok();
  } catch (e, s) {
    transaction.status = SpanStatus.internalError();
    await Sentry.captureException(e, stackTrace: s);
    rethrow;
  } finally {
    await transaction.finish();  // Always finish!
  }
}
```

### 2. Use Descriptive Transaction Names

```dart
// ❌ Bad (too generic)
final transaction = Sentry.startTransaction('task', 'task');

// ✅ Good (descriptive)
final transaction = Sentry.startTransaction('user-data-sync', 'task');
```

### 3. Add Relevant Context

```dart
Sentry.configureScope((scope) {
  // Tags (indexed, filterable)
  scope.setTag('task_type', 'sync');
  scope.setTag('environment', 'production');

  // Extra (not indexed, detailed data)
  scope.setExtra('input_data', input);
  scope.setExtra('config', appConfig);

  // Contexts (structured data)
  scope.setContexts('device', {'battery': '50%'});
});
```

### 4. Handle Offline Scenarios

```dart
@pragma('vm:entry-point')
Future<void> offlineAwareCallback(String? input) async {
  final transaction = Sentry.startTransaction('offline-sync', 'task');

  try {
    await sync();
  } on SocketException {
    // Don't spam Sentry with network errors
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Network unavailable, will retry',
      level: SentryLevel.warning,
    ));
    transaction.status = SpanStatus.unavailable();
    // Don't rethrow, just skip
  } catch (e, s) {
    transaction.status = SpanStatus.internalError();
    await Sentry.captureException(e, stackTrace: s);
    rethrow;
  } finally {
    await transaction.finish();
  }
}
```

---

## Performance Considerations

### Memory Impact

| Feature | Memory Overhead | Notes |
|---------|----------------|-------|
| **Basic error tracking** | ~5MB | Lightweight |
| **Performance monitoring** | ~10MB | Transaction tracking |
| **Breadcrumbs (100)** | ~2MB | Circular buffer |
| **Screenshots** | ~15MB | Attach on crash |
| **View hierarchy** | ~8MB | UI tree snapshot |

**Optimization:** Disable screenshots in background tasks:

```dart
Sentry.configureScope((scope) {
  scope.setContexts('app', {'background_task': true});
});

// In beforeSend:
options.beforeSend = (event, hint) {
  if (event.contexts?['app']?['background_task'] == true) {
    event.screenshots?.clear(); // Remove screenshots
  }
  return event;
};
```

### Battery Impact

- **Error tracking only:** Minimal (<1% impact)
- **Performance monitoring:** Low (~2% impact)
- **With screenshots:** Moderate (~5% impact)

**Best Practice:** Use sampling for background tasks:

```dart
options.tracesSampler = (context) {
  return context.transactionContext.operation == 'task' ? 0.1 : 1.0;
};
```

---

## Troubleshooting

### Issue: Events not appearing in Sentry

**Solution:** Check DSN and network:

```dart
// Test Sentry connection
await Sentry.captureMessage('Test from background task');
```

### Issue: Transactions never finish

**Solution:** Always use try-finally:

```dart
final transaction = Sentry.startTransaction('task', 'task');
try {
  await work();
} finally {
  await transaction.finish();  // Guaranteed to run
}
```

### Issue: Too many events, hitting quota

**Solution:** Use sampling and beforeSend filtering:

```dart
options.tracesSampleRate = 0.1; // 10% of transactions

options.beforeSend = (event, hint) {
  // Filter common errors
  if (event.exceptions?.any((e) => e.type == 'TimeoutException') ?? false) {
    return null; // Drop
  }
  return event;
};
```

---

## Example: Complete Monitoring Setup

```dart
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:native_workmanager/native_workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SentryFlutter.init(
    (options) {
      options.dsn = 'YOUR_SENTRY_DSN';
      options.environment = 'production';
      options.release = '1.0.0';
      options.tracesSampleRate = 0.1; // 10% sampling

      // Custom sampler
      options.tracesSampler = (context) {
        if (context.transactionContext.operation == 'task') {
          return 0.1; // 10% for background tasks
        }
        return 1.0; // 100% for everything else
      };

      // Filter before sending
      options.beforeSend = (event, hint) {
        // Skip network errors
        if (event.exceptions?.any((e) =>
            e.type == 'SocketException' ||
            e.type == 'TimeoutException') ?? false) {
          return null;
        }

        // Add source tag
        event.tags = {...?event.tags, 'source': 'background_task'};

        return event;
      };
    },
    appRunner: () async {
      await NativeWorkManager.initialize();

      // Register callbacks
      NativeWorkManager.registerCallback('monitoredSync', monitoredSyncCallback);

      // Setup task lifecycle monitoring
      _setupTaskMonitoring();

      // Schedule task
      await NativeWorkManager.enqueue(
        taskId: 'monitored-sync',
        trigger: TaskTrigger.periodic(Duration(hours: 1)),
        worker: DartWorker(
          callbackId: 'monitoredSync',
          autoDispose: true,
        ),
        constraints: Constraints(requiresNetwork: true),
      );

      runApp(MyApp());
    },
  );
}

void _setupTaskMonitoring() {
  NativeWorkManager.events.listen((event) {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Task ${event.taskId}: ${event.state}',
      category: 'task',
      level: _levelFromState(event.state),
      data: {
        'task_id': event.taskId,
        'state': event.state.toString(),
        'progress': event.progress,
      },
    ));

    if (event.state == TaskState.failed) {
      Sentry.captureMessage(
        'Task failed: ${event.taskId}',
        level: SentryLevel.error,
      );
    }
  });
}

SentryLevel _levelFromState(TaskState state) {
  switch (state) {
    case TaskState.failed:
      return SentryLevel.error;
    case TaskState.cancelled:
      return SentryLevel.warning;
    default:
      return SentryLevel.info;
  }
}

@pragma('vm:entry-point')
Future<void> monitoredSyncCallback(String? input) async {
  final transaction = Sentry.startTransaction(
    'background-sync',
    'task',
    bindToScope: true,
  );

  try {
    // Set context
    await Sentry.configureScope((scope) {
      scope.setTag('task_type', 'sync');
      scope.setExtra('input', input);
      scope.setContexts('task', {
        'started_at': DateTime.now().toIso8601String(),
      });
    });

    // Add breadcrumb
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Starting sync',
      category: 'task',
    ));

    // Fetch data span
    final fetchSpan = transaction.startChild('fetch-data');
    final data = await fetchData();
    await fetchSpan.finish();

    // Process data span
    final processSpan = transaction.startChild('process-data');
    await processData(data);
    await processSpan.finish();

    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Sync completed',
      level: SentryLevel.info,
    ));

    transaction.status = SpanStatus.ok();
  } catch (error, stackTrace) {
    transaction.status = SpanStatus.internalError();

    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: Hint.withMap({
        'task_id': 'monitored-sync',
        'input': input,
      }),
    );

    rethrow;
  } finally {
    await transaction.finish();
  }
}

Future<List<dynamic>> fetchData() async {
  await Future.delayed(Duration(seconds: 2));
  return [1, 2, 3];
}

Future<void> processData(List<dynamic> data) async {
  await Future.delayed(Duration(seconds: 1));
}
```

---

## Additional Resources

- [Sentry Flutter Documentation](https://docs.sentry.io/platforms/flutter/)
- [native_workmanager Events](../API_REFERENCE.md#events)

---

**Last Updated:** 2026-02-07
