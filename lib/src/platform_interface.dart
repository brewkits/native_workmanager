import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'constraints.dart';
import 'events.dart';
import 'method_channel.dart';
import 'remote_trigger.dart';
import 'task_trigger.dart';
import 'worker.dart';

/// Platform interface for native_workmanager plugin.
abstract class NativeWorkManagerPlatform extends PlatformInterface {
  NativeWorkManagerPlatform() : super(token: _token);

  static final Object _token = Object();

  static NativeWorkManagerPlatform _instance = MethodChannelNativeWorkManager();

  /// The default instance of [NativeWorkManagerPlatform].
  static NativeWorkManagerPlatform get instance => _instance;

  /// Platform-specific implementations should set this.
  static set instance(NativeWorkManagerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initialize the work manager.
  ///
  /// [callbackHandle] - Handle of the Dart callback dispatcher for Dart workers.
  /// If null, only native workers can be used.
  ///
  /// [debugMode] - Enable debug notifications for task events.
  /// Only works in debug builds.
  ///
  /// [maxConcurrentTasks] - Maximum number of worker tasks that may run
  /// simultaneously. Defaults to 4. On iOS this is enforced by a semaphore
  /// in the plugin; on Android WorkManager's own thread pool handles it.
  ///
  /// [diskSpaceBufferMB] - Minimum free disk space (in MB) the OS must have
  /// before any download worker is allowed to run. Defaults to 20 MB.
  ///
  /// [cleanupAfterDays] - Automatically delete completed/failed/cancelled task
  /// records older than this many days on each initialize(). 0 = disabled.
  /// Defaults to 30 days to prevent unbounded SQLite growth.
  ///
  /// [enforceHttps] - When true, all HTTP workers reject plain-HTTP URLs and
  /// only allow HTTPS. Defaults to false for backward compatibility.
  ///
  /// [blockPrivateIPs] - When true, HTTP workers block requests to
  /// private/loopback IP ranges (10.x, 172.16-31.x, 192.168.x, 127.x, ::1)
  /// to prevent SSRF attacks. Defaults to false for backward compatibility.
  Future<void> initialize({
    int? callbackHandle,
    bool debugMode = false,
    int maxConcurrentTasks = 4,
    int diskSpaceBufferMB = 20,
    int cleanupAfterDays = 30,
    bool enforceHttps = false,
    bool blockPrivateIPs = false,
  }) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Schedule a task.
  Future<ScheduleResult> enqueue({
    required String taskId,
    required TaskTrigger trigger,
    required Worker worker,
    required Constraints constraints,
    required ExistingTaskPolicy existingPolicy,
    String? tag,
  }) {
    throw UnimplementedError('enqueue() has not been implemented.');
  }

  /// Cancel all tasks with a specific tag.
  Future<void> cancelByTag({required String tag}) {
    throw UnimplementedError('cancelByTag() has not been implemented.');
  }

  /// Get all tasks with a specific tag.
  Future<List<String>> getTasksByTag({required String tag}) {
    throw UnimplementedError('getTasksByTag() has not been implemented.');
  }

  /// Get all tags currently in use.
  Future<List<String>> getAllTags() {
    throw UnimplementedError('getAllTags() has not been implemented.');
  }

  /// Cancel a task by ID.
  Future<void> cancel({required String taskId}) {
    throw UnimplementedError('cancel() has not been implemented.');
  }

  /// Cancel all tasks.
  Future<void> cancelAll() {
    throw UnimplementedError('cancelAll() has not been implemented.');
  }

  /// Get task status.
  Future<TaskStatus?> getTaskStatus({required String taskId}) {
    throw UnimplementedError('getTaskStatus() has not been implemented.');
  }

  /// Get detailed task record.
  Future<TaskRecord?> getTaskRecord({required String taskId}) {
    throw UnimplementedError('getTaskRecord() has not been implemented.');
  }

  /// Schedule a task chain.
  Future<ScheduleResult> enqueueChain(Map<String, dynamic> chainData) {
    throw UnimplementedError('enqueueChain() has not been implemented.');
  }

  /// Stream of task completion events.
  Stream<TaskEvent> get events {
    throw UnimplementedError('events has not been implemented.');
  }

  /// Stream of task progress updates.
  Stream<TaskProgress> get progress {
    throw UnimplementedError('progress has not been implemented.');
  }

  /// Pause a running task (best-effort; saves resume data where possible).
  Future<void> pauseTask({required String taskId}) {
    throw UnimplementedError('pauseTask() has not been implemented.');
  }

  /// Resume a previously paused task.
  Future<void> resumeTask({required String taskId}) {
    throw UnimplementedError('resumeTask() has not been implemented.');
  }

  /// Return all tasks from the persistent task store.
  Future<List<TaskRecord>> allTasks() {
    throw UnimplementedError('allTasks() has not been implemented.');
  }

  /// Fetch the server-suggested filename for a URL by sending a HEAD request
  /// and parsing the Content-Disposition header (RFC 6266).
  ///
  /// Returns the sanitized filename, or `null` if the server did not provide one.
  Future<String?> getServerFilename({
    required String url,
    Map<String, String>? headers,
    int timeoutMs = 30000,
  }) {
    throw UnimplementedError('getServerFilename() has not been implemented.');
  }

  /// Open a file with the OS default viewer/handler.
  ///
  /// On Android, uses `Intent.ACTION_VIEW` via `FileProvider`.
  /// On iOS, presents a `UIDocumentInteractionController`.
  ///
  /// [path] — absolute path to the file.
  /// [mimeType] — optional MIME type hint. If null, the OS infers from extension.
  Future<void> openFile(String path, {String? mimeType}) {
    throw UnimplementedError('openFile() has not been implemented.');
  }

  /// Set the maximum number of concurrent downloads per host.
  ///
  /// When multiple downloads target the same host, this limits how many run
  /// simultaneously. Defaults to 2.
  Future<void> setMaxConcurrentPerHost(int max) {
    throw UnimplementedError(
        'setMaxConcurrentPerHost() has not been implemented.');
  }

  /// Register a remote trigger for background task execution.
  ///
  /// This allows the plugin to automatically enqueue native workers when a
  /// remote message (FCM/APNs) is received, without waking the Flutter Engine.
  ///
  /// Rules are persisted on the native side.
  Future<void> registerRemoteTrigger({
    required RemoteTriggerSource source,
    required RemoteTriggerRule rule,
  }) {
    throw UnimplementedError(
        'registerRemoteTrigger() has not been implemented.');
  }

  /// Enqueue a task graph for native execution.
  ///
  /// This moves graph orchestration to the native layer, allowing it to
  /// survive app termination.
  Future<String> enqueueGraph(Map<String, dynamic> graphMap) {
    throw UnimplementedError('enqueueGraph() has not been implemented.');
  }

  /// Enqueue a task to the native offline queue.
  ///
  /// This moves queue management to the native layer, allowing tasks to
  /// be enqueued while offline and automatically processed when network
  /// is restored, even if the app is killed.
  Future<void> offlineQueueEnqueue(
      String queueId, Map<String, dynamic> entryMap) {
    throw UnimplementedError('offlineQueueEnqueue() has not been implemented.');
  }

  /// Register a middleware for background tasks.
  ///
  /// Middleware allows you to intercept and modify tasks globally on the
  /// native side.
  Future<void> registerMiddleware(Map<String, dynamic> middlewareMap) {
    throw UnimplementedError('registerMiddleware() has not been implemented.');
  }

  /// Set the Dart callback executor.
  void setCallbackExecutor(
      Future<bool> Function(String callbackId, Map<String, dynamic>? input)
          executor) {
    throw UnimplementedError('setCallbackExecutor() has not been implemented.');
  }

  /// Get real-time metrics from the native task store for DevTools.
  /// Returns a map with activeTasks, offlineQueueSize, failedTasks, completedTasks.
  Future<Map<String, dynamic>> getMetrics() {
    throw UnimplementedError('getMetrics() has not been implemented.');
  }

  /// Manually trigger processing of the native offline queue.
  Future<bool> syncOfflineQueue() {
    throw UnimplementedError('syncOfflineQueue() has not been implemented.');
  }
}
