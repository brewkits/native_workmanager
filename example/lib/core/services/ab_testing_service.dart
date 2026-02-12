/// A/B Testing Service for comparing native_workmanager vs workmanager
library;

import 'dart:async';
import 'dart:math';
import '../models/task_metrics.dart';
import 'metrics_collector.dart';

/// Test scenario type
enum TestScenario {
  quickTest('Quick Test', 'Simple HTTP request task'),
  httpOperations('HTTP Operations', 'Multiple API requests'),
  fileTransfer('File Transfer', 'Download and process files'),
  periodicTasks('Periodic Tasks', 'Recurring background work'),
  chainedTasks('Chained Tasks', 'Sequential task dependencies'),
  stressTest('Stress Test', 'High-load scenario'),
  batteryTest('Battery Test', 'Long-running battery impact');

  final String title;
  final String description;

  const TestScenario(this.title, this.description);
}

/// Package under test
enum TestPackage {
  nativeWorkmanager('native_workmanager'),
  flutterWorkmanager('workmanager');

  final String packageName;

  const TestPackage(this.packageName);
}

/// Test configuration
class ABTestConfig {
  /// Scenario to test
  final TestScenario scenario;

  /// Number of tasks to execute
  final int taskCount;

  /// Delay between tasks (ms)
  final int taskDelayMs;

  /// Whether to test both packages
  final bool testBothPackages;

  /// Timeout per task (ms)
  final int timeoutMs;

  const ABTestConfig({
    required this.scenario,
    this.taskCount = 10,
    this.taskDelayMs = 1000,
    this.testBothPackages = true,
    this.timeoutMs = 30000,
  });

  factory ABTestConfig.quickTest() {
    return const ABTestConfig(
      scenario: TestScenario.quickTest,
      taskCount: 5,
      taskDelayMs: 500,
    );
  }

  factory ABTestConfig.httpTest() {
    return const ABTestConfig(
      scenario: TestScenario.httpOperations,
      taskCount: 10,
      taskDelayMs: 1000,
    );
  }

  factory ABTestConfig.stressTest() {
    return const ABTestConfig(
      scenario: TestScenario.stressTest,
      taskCount: 50,
      taskDelayMs: 100,
      timeoutMs: 60000,
    );
  }
}

/// A/B Testing orchestration service
class ABTestingService {
  final _metricsCollector = MetricsCollector();
  final _recorder = TaskMetricsRecorder();

  /// Stream controller for test progress
  final _progressController = StreamController<ABTestProgress>.broadcast();

  /// Stream controller for live metrics
  final _liveMetricsController = StreamController<LiveMetrics>.broadcast();

  /// Currently running test
  ABTestRun? _currentTest;

  /// Test history
  final List<ABTestComparison> _testHistory = [];

  /// Get test history
  List<ABTestComparison> get testHistory => List.unmodifiable(_testHistory);

  /// Get progress stream
  Stream<ABTestProgress> get progressStream => _progressController.stream;

  /// Get live metrics stream
  Stream<LiveMetrics> get liveMetricsStream => _liveMetricsController.stream;

  /// Check if test is running
  bool get isTestRunning => _currentTest != null;

  /// Run A/B test with given configuration
  Future<ABTestComparison> runTest(ABTestConfig config) async {
    if (_currentTest != null) {
      throw StateError('Test already running');
    }

    final testId = _generateTestId();
    _currentTest = ABTestRun(testId: testId, config: config);

    try {
      final startTime = DateTime.now();

      // Reset battery baseline for accurate drain measurement
      _metricsCollector.resetBatteryBaseline();

      // Start monitoring
      _metricsCollector.startMonitoring(interval: const Duration(seconds: 1));

      // Listen to metrics for live updates
      final metricsSubscription = _startLiveMetricsMonitoring();

      ABTestResult? nativeResult;
      ABTestResult? flutterResult;

      try {
        // Test native_workmanager
        _emitProgress(
          ABTestProgress(
            testId: testId,
            phase: TestPhase.testingNative,
            progress: 0.0,
            message: 'Testing native_workmanager...',
          ),
        );

        nativeResult = await _runPackageTest(
          testId,
          TestPackage.nativeWorkmanager,
          config,
        );

        // Small delay between tests
        await Future.delayed(Duration(milliseconds: config.taskDelayMs * 2));

        // Test workmanager if configured
        if (config.testBothPackages) {
          _emitProgress(
            ABTestProgress(
              testId: testId,
              phase: TestPhase.testingFlutter,
              progress: 0.5,
              message: 'Testing workmanager...',
            ),
          );

          flutterResult = await _runPackageTest(
            testId,
            TestPackage.flutterWorkmanager,
            config,
          );
        }

        // Analysis phase
        _emitProgress(
          ABTestProgress(
            testId: testId,
            phase: TestPhase.analyzing,
            progress: 0.9,
            message: 'Analyzing results...',
          ),
        );

        final endTime = DateTime.now();

        // Create comparison
        final comparison = ABTestComparison(
          testId: testId,
          scenario: config.scenario,
          nativeResult: nativeResult,
          flutterResult: flutterResult,
          testDuration: endTime.difference(startTime),
          timestamp: startTime,
        );

        // Save to history
        _testHistory.insert(0, comparison);

        // Complete
        _emitProgress(
          ABTestProgress(
            testId: testId,
            phase: TestPhase.completed,
            progress: 1.0,
            message: 'Test completed successfully',
          ),
        );

        return comparison;
      } finally {
        // Stop monitoring
        await metricsSubscription.cancel();
        _metricsCollector.stopMonitoring();
      }
    } finally {
      _currentTest = null;
    }
  }

  /// Run test for a specific package
  Future<ABTestResult> _runPackageTest(
    String testId,
    TestPackage package,
    ABTestConfig config,
  ) async {
    final taskMetrics = <TaskMetrics>[];
    final startTime = DateTime.now();

    for (var i = 0; i < config.taskCount; i++) {
      final taskId = '${testId}_${package.packageName}_task_$i';

      // Update progress
      final progress = (i / config.taskCount) * 0.5;
      _emitProgress(
        ABTestProgress(
          testId: testId,
          phase: package == TestPackage.nativeWorkmanager
              ? TestPhase.testingNative
              : TestPhase.testingFlutter,
          progress: progress,
          message:
              'Running ${package.packageName} task ${i + 1}/${config.taskCount}',
          currentTaskCount: i + 1,
          totalTaskCount: config.taskCount,
        ),
      );

      try {
        // Record task execution with metrics
        final metrics = await _recorder.recordTask(
          taskId: taskId,
          task: () => _executeScenarioTask(config.scenario, package, taskId),
        );

        taskMetrics.add(metrics);
      } catch (e) {
        // Record failed task
        taskMetrics.add(
          TaskMetrics(
            taskId: taskId,
            executionTimeMs: 0,
            success: false,
            errorMessage: e.toString(),
            timestamp: DateTime.now(),
          ),
        );
      }

      // Delay before next task
      if (i < config.taskCount - 1) {
        await Future.delayed(Duration(milliseconds: config.taskDelayMs));
      }
    }

    final endTime = DateTime.now();

    // Calculate aggregated metrics
    final successfulTasks = taskMetrics.where((m) => m.success).toList();
    final successRate = successfulTasks.length / taskMetrics.length;

    final avgExecutionTime = successfulTasks.isEmpty
        ? 0.0
        : successfulTasks
                  .map((m) => m.executionTimeMs)
                  .reduce((a, b) => a + b) /
              successfulTasks.length;

    final memoryDeltas = successfulTasks
        .where((m) => m.memoryDeltaMB != null)
        .map((m) => m.memoryDeltaMB!)
        .toList();
    final avgMemoryDelta = memoryDeltas.isEmpty
        ? 0.0
        : memoryDeltas.reduce((a, b) => a + b) / memoryDeltas.length;

    final peakMemoryMB = successfulTasks
        .where((m) => m.memoryEnd != null)
        .map((m) => m.memoryEnd!.appRAMMB)
        .fold<double>(0.0, (max, value) => value > max ? value : max);

    final cpuUsages = successfulTasks
        .where((m) => m.cpuMetrics != null)
        .map((m) => m.cpuMetrics!.cpuUsage)
        .toList();
    final avgCpuUsage = cpuUsages.isEmpty
        ? 0.0
        : cpuUsages.reduce((a, b) => a + b) / cpuUsages.length;

    // Get last battery metrics for drain rate
    final batteryDrainRate =
        taskMetrics
            .lastWhere(
              (m) => m.batteryMetrics != null,
              orElse: () => taskMetrics.last,
            )
            .batteryMetrics
            ?.drainRate ??
        0.0;

    return ABTestResult(
      testId: testId,
      package: package.packageName,
      scenario: config.scenario.title,
      taskCount: taskMetrics.length,
      successRate: successRate,
      avgExecutionTime: avgExecutionTime,
      peakMemoryMB: peakMemoryMB,
      avgMemoryDelta: avgMemoryDelta,
      avgCpuUsage: avgCpuUsage,
      batteryDrainRate: batteryDrainRate,
      taskMetrics: taskMetrics,
      startTime: startTime,
      endTime: endTime,
    );
  }

  /// Execute a task based on scenario
  Future<void> _executeScenarioTask(
    TestScenario scenario,
    TestPackage package,
    String taskId,
  ) async {
    switch (scenario) {
      case TestScenario.quickTest:
        await _quickTestTask();
        break;
      case TestScenario.httpOperations:
        await _httpOperationsTask();
        break;
      case TestScenario.fileTransfer:
        await _fileTransferTask();
        break;
      case TestScenario.periodicTasks:
        await _periodicTask();
        break;
      case TestScenario.chainedTasks:
        await _chainedTask();
        break;
      case TestScenario.stressTest:
        await _stressTestTask();
        break;
      case TestScenario.batteryTest:
        await _batteryTestTask();
        break;
    }
  }

  // Scenario implementations
  Future<void> _quickTestTask() async {
    await Future.delayed(const Duration(milliseconds: 100));
    final random = Random();
    final data = List.generate(1000, (_) => random.nextInt(256));
    data.reduce((a, b) => a + b); // Simple computation
  }

  Future<void> _httpOperationsTask() async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Simulate HTTP operation
    final random = Random();
    final data = List.generate(5000, (_) => random.nextInt(256));
    data.reduce((a, b) => a + b);
  }

  Future<void> _fileTransferTask() async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Simulate file transfer
    final random = Random();
    final data = List.generate(10000, (_) => random.nextInt(256));
    data.reduce((a, b) => a + b);
  }

  Future<void> _periodicTask() async {
    await Future.delayed(const Duration(milliseconds: 150));
    final random = Random();
    final data = List.generate(2000, (_) => random.nextInt(256));
    data.reduce((a, b) => a + b);
  }

  Future<void> _chainedTask() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final random = Random();
    for (var i = 0; i < 3; i++) {
      final data = List.generate(1000, (_) => random.nextInt(256));
      data.reduce((a, b) => a + b);
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _stressTestTask() async {
    await Future.delayed(const Duration(milliseconds: 50));
    final random = Random();
    final data = List.generate(20000, (_) => random.nextInt(256));
    data.reduce((a, b) => a + b);
  }

  Future<void> _batteryTestTask() async {
    await Future.delayed(const Duration(seconds: 2));
    final random = Random();
    for (var i = 0; i < 5; i++) {
      final data = List.generate(5000, (_) => random.nextInt(256));
      data.reduce((a, b) => a + b);
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Start live metrics monitoring
  StreamSubscription<MemoryMetrics> _startLiveMetricsMonitoring() {
    return _metricsCollector.memoryStream.listen((memory) async {
      try {
        final cpu = await _metricsCollector.getCpuUsage();
        final battery = await _metricsCollector.getBatteryMetrics();

        _liveMetricsController.add(
          LiveMetrics(
            memory: memory,
            cpu: cpu,
            battery: battery,
            timestamp: DateTime.now(),
          ),
        );
      } catch (e) {
        // Silently handle errors during monitoring
      }
    });
  }

  /// Emit progress update
  void _emitProgress(ABTestProgress progress) {
    _progressController.add(progress);
  }

  /// Generate unique test ID
  String _generateTestId() {
    return 'test_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Clear test history
  void clearHistory() {
    _testHistory.clear();
  }

  /// Dispose resources
  void dispose() {
    _metricsCollector.dispose();
    _progressController.close();
    _liveMetricsController.close();
  }
}

/// Active test run
class ABTestRun {
  final String testId;
  final ABTestConfig config;

  ABTestRun({required this.testId, required this.config});
}

/// Test progress update
class ABTestProgress {
  final String testId;
  final TestPhase phase;
  final double progress; // 0.0 to 1.0
  final String message;
  final int? currentTaskCount;
  final int? totalTaskCount;

  const ABTestProgress({
    required this.testId,
    required this.phase,
    required this.progress,
    required this.message,
    this.currentTaskCount,
    this.totalTaskCount,
  });
}

/// Test phase
enum TestPhase {
  preparing,
  testingNative,
  testingFlutter,
  analyzing,
  completed,
  error,
}

/// Live metrics snapshot
class LiveMetrics {
  final MemoryMetrics memory;
  final CPUMetrics cpu;
  final BatteryMetrics battery;
  final DateTime timestamp;

  const LiveMetrics({
    required this.memory,
    required this.cpu,
    required this.battery,
    required this.timestamp,
  });
}

/// A/B test comparison result
class ABTestComparison {
  final String testId;
  final TestScenario scenario;
  final ABTestResult nativeResult;
  final ABTestResult? flutterResult;
  final Duration testDuration;
  final DateTime timestamp;

  const ABTestComparison({
    required this.testId,
    required this.scenario,
    required this.nativeResult,
    this.flutterResult,
    required this.testDuration,
    required this.timestamp,
  });

  /// Calculate speed improvement factor
  double get speedImprovement {
    if (flutterResult == null) return 1.0;
    if (nativeResult.avgExecutionTime == 0) return 1.0;
    return flutterResult!.avgExecutionTime / nativeResult.avgExecutionTime;
  }

  /// Calculate memory improvement factor
  double get memoryImprovement {
    if (flutterResult == null) return 1.0;
    if (nativeResult.peakMemoryMB == 0) return 1.0;
    return flutterResult!.peakMemoryMB / nativeResult.peakMemoryMB;
  }

  /// Calculate battery improvement factor
  double get batteryImprovement {
    if (flutterResult == null) return 1.0;
    if (nativeResult.batteryDrainRate == 0) return 1.0;
    return flutterResult!.batteryDrainRate / nativeResult.batteryDrainRate;
  }

  /// Get winner package
  String get winner {
    if (flutterResult == null) return nativeResult.package;

    // Score based on speed, memory, success rate
    final nativeScore =
        (1.0 / nativeResult.avgExecutionTime) * 1000 + // Speed
        (1.0 / nativeResult.peakMemoryMB) * 100 + // Memory
        nativeResult.successRate * 100; // Reliability

    final flutterScore =
        (1.0 / flutterResult!.avgExecutionTime) * 1000 +
        (1.0 / flutterResult!.peakMemoryMB) * 100 +
        flutterResult!.successRate * 100;

    return nativeScore > flutterScore
        ? nativeResult.package
        : flutterResult!.package;
  }
}
