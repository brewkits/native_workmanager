/// Data models for performance metrics collection and A/B testing
library;

/// Memory usage metrics collected from the platform
class MemoryMetrics {
  /// Total physical RAM on device (bytes)
  final int totalRAM;

  /// Currently used RAM system-wide (bytes)
  final int usedRAM;

  /// Available RAM for apps (bytes)
  final int availableRAM;

  /// Current app's memory usage (bytes)
  /// - Android: PSS (Proportional Set Size)
  /// - iOS: resident_size
  final int appRAM;

  /// Dart heap memory usage (bytes)
  final int dartHeap;

  /// Native heap memory usage (bytes)
  final int nativeHeap;

  /// Timestamp when metrics were collected
  final DateTime timestamp;

  const MemoryMetrics({
    required this.totalRAM,
    required this.usedRAM,
    required this.availableRAM,
    required this.appRAM,
    required this.dartHeap,
    required this.nativeHeap,
    required this.timestamp,
  });

  factory MemoryMetrics.fromMap(Map<String, dynamic> map) {
    return MemoryMetrics(
      totalRAM: map['totalRAM'] as int,
      usedRAM: map['usedRAM'] as int,
      availableRAM: map['availableRAM'] as int,
      appRAM: map['appRAM'] as int,
      dartHeap: map['dartHeap'] as int,
      nativeHeap: map['nativeHeap'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalRAM': totalRAM,
      'usedRAM': usedRAM,
      'availableRAM': availableRAM,
      'appRAM': appRAM,
      'dartHeap': dartHeap,
      'nativeHeap': nativeHeap,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  /// Get total RAM in MB
  double get totalRAMMB => totalRAM / 1024 / 1024;

  /// Get app RAM usage in MB
  double get appRAMMB => appRAM / 1024 / 1024;

  /// Get available RAM in MB
  double get availableRAMMB => availableRAM / 1024 / 1024;

  /// Get memory usage percentage
  double get memoryUsagePercent => (usedRAM / totalRAM) * 100;

  @override
  String toString() {
    return 'MemoryMetrics(app: ${appRAMMB.toStringAsFixed(1)}MB, '
        'available: ${availableRAMMB.toStringAsFixed(1)}MB, '
        'total: ${totalRAMMB.toStringAsFixed(0)}MB, '
        'usage: ${memoryUsagePercent.toStringAsFixed(1)}%)';
  }
}

/// CPU usage metrics
class CPUMetrics {
  /// CPU usage percentage (0-100)
  final double cpuUsage;

  /// Number of CPU cores
  final int cpuCores;

  /// Timestamp when metrics were collected
  final DateTime timestamp;

  const CPUMetrics({
    required this.cpuUsage,
    required this.cpuCores,
    required this.timestamp,
  });

  factory CPUMetrics.fromMap(Map<String, dynamic> map) {
    return CPUMetrics(
      cpuUsage: (map['cpuUsage'] as num).toDouble(),
      cpuCores: map['cpuCores'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cpuUsage': cpuUsage,
      'cpuCores': cpuCores,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() {
    return 'CPUMetrics(usage: ${cpuUsage.toStringAsFixed(1)}%, cores: $cpuCores)';
  }
}

/// Battery metrics and drain rate
class BatteryMetrics {
  /// Current battery level (0-100)
  final double level;

  /// Battery drain rate (% per hour)
  final double drainRate;

  /// Duration monitored for drain calculation
  final Duration monitorDuration;

  /// Is device charging
  final bool isCharging;

  /// Timestamp when metrics were collected
  final DateTime timestamp;

  const BatteryMetrics({
    required this.level,
    required this.drainRate,
    required this.monitorDuration,
    required this.isCharging,
    required this.timestamp,
  });

  factory BatteryMetrics.fromMap(Map<String, dynamic> map) {
    return BatteryMetrics(
      level: (map['level'] as num).toDouble(),
      drainRate: (map['drainRate'] as num).toDouble(),
      monitorDuration: Duration(milliseconds: map['monitorDuration'] as int),
      isCharging: map['isCharging'] as bool,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'drainRate': drainRate,
      'monitorDuration': monitorDuration.inMilliseconds,
      'isCharging': isCharging,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() {
    return 'BatteryMetrics(level: ${level.toStringAsFixed(1)}%, '
        'drain: ${drainRate.toStringAsFixed(2)}%/h, '
        'charging: $isCharging)';
  }
}

/// Complete task execution metrics
class TaskMetrics {
  /// Task identifier
  final String taskId;

  /// Execution time in milliseconds
  final int executionTimeMs;

  /// Was task successful
  final bool success;

  /// Error message if failed
  final String? errorMessage;

  /// Memory metrics at start
  final MemoryMetrics? memoryStart;

  /// Memory metrics at end
  final MemoryMetrics? memoryEnd;

  /// CPU metrics during execution
  final CPUMetrics? cpuMetrics;

  /// Battery metrics during execution
  final BatteryMetrics? batteryMetrics;

  /// Timestamp when task started
  final DateTime timestamp;

  const TaskMetrics({
    required this.taskId,
    required this.executionTimeMs,
    required this.success,
    this.errorMessage,
    this.memoryStart,
    this.memoryEnd,
    this.cpuMetrics,
    this.batteryMetrics,
    required this.timestamp,
  });

  /// Memory delta in MB
  double? get memoryDeltaMB {
    if (memoryStart == null || memoryEnd == null) return null;
    return (memoryEnd!.appRAM - memoryStart!.appRAM) / 1024 / 1024;
  }

  factory TaskMetrics.fromMap(Map<String, dynamic> map) {
    return TaskMetrics(
      taskId: map['taskId'] as String,
      executionTimeMs: map['executionTimeMs'] as int,
      success: map['success'] as bool,
      errorMessage: map['errorMessage'] as String?,
      memoryStart: map['memoryStart'] != null
          ? MemoryMetrics.fromMap(map['memoryStart'] as Map<String, dynamic>)
          : null,
      memoryEnd: map['memoryEnd'] != null
          ? MemoryMetrics.fromMap(map['memoryEnd'] as Map<String, dynamic>)
          : null,
      cpuMetrics: map['cpuMetrics'] != null
          ? CPUMetrics.fromMap(map['cpuMetrics'] as Map<String, dynamic>)
          : null,
      batteryMetrics: map['batteryMetrics'] != null
          ? BatteryMetrics.fromMap(
              map['batteryMetrics'] as Map<String, dynamic>,
            )
          : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'executionTimeMs': executionTimeMs,
      'success': success,
      'errorMessage': errorMessage,
      'memoryStart': memoryStart?.toMap(),
      'memoryEnd': memoryEnd?.toMap(),
      'cpuMetrics': cpuMetrics?.toMap(),
      'batteryMetrics': batteryMetrics?.toMap(),
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() {
    final delta = memoryDeltaMB;
    return 'TaskMetrics($taskId: ${executionTimeMs}ms, '
        'success: $success, '
        'memDelta: ${delta != null ? '${delta.toStringAsFixed(1)}MB' : 'N/A'})';
  }
}

/// Aggregated test results for A/B comparison
class ABTestResult {
  /// Test identifier
  final String testId;

  /// Package being tested (native_workmanager or workmanager)
  final String package;

  /// Test scenario name
  final String scenario;

  /// Number of tasks executed
  final int taskCount;

  /// Success rate (0-1)
  final double successRate;

  /// Average execution time (ms)
  final double avgExecutionTime;

  /// Peak memory usage (MB)
  final double peakMemoryMB;

  /// Average memory delta (MB)
  final double avgMemoryDelta;

  /// Average CPU usage (%)
  final double avgCpuUsage;

  /// Battery drain (% per hour)
  final double batteryDrainRate;

  /// Individual task metrics
  final List<TaskMetrics> taskMetrics;

  /// Test start time
  final DateTime startTime;

  /// Test end time
  final DateTime endTime;

  const ABTestResult({
    required this.testId,
    required this.package,
    required this.scenario,
    required this.taskCount,
    required this.successRate,
    required this.avgExecutionTime,
    required this.peakMemoryMB,
    required this.avgMemoryDelta,
    required this.avgCpuUsage,
    required this.batteryDrainRate,
    required this.taskMetrics,
    required this.startTime,
    required this.endTime,
  });

  /// Total test duration
  Duration get duration => endTime.difference(startTime);

  factory ABTestResult.fromMap(Map<String, dynamic> map) {
    return ABTestResult(
      testId: map['testId'] as String,
      package: map['package'] as String,
      scenario: map['scenario'] as String,
      taskCount: map['taskCount'] as int,
      successRate: (map['successRate'] as num).toDouble(),
      avgExecutionTime: (map['avgExecutionTime'] as num).toDouble(),
      peakMemoryMB: (map['peakMemoryMB'] as num).toDouble(),
      avgMemoryDelta: (map['avgMemoryDelta'] as num).toDouble(),
      avgCpuUsage: (map['avgCpuUsage'] as num).toDouble(),
      batteryDrainRate: (map['batteryDrainRate'] as num).toDouble(),
      taskMetrics: (map['taskMetrics'] as List)
          .map((e) => TaskMetrics.fromMap(e as Map<String, dynamic>))
          .toList(),
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'testId': testId,
      'package': package,
      'scenario': scenario,
      'taskCount': taskCount,
      'successRate': successRate,
      'avgExecutionTime': avgExecutionTime,
      'peakMemoryMB': peakMemoryMB,
      'avgMemoryDelta': avgMemoryDelta,
      'avgCpuUsage': avgCpuUsage,
      'batteryDrainRate': batteryDrainRate,
      'taskMetrics': taskMetrics.map((e) => e.toMap()).toList(),
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() {
    return 'ABTestResult($package - $scenario: '
        '$taskCount tasks, '
        '${(successRate * 100).toStringAsFixed(1)}% success, '
        '${avgExecutionTime.toStringAsFixed(0)}ms avg, '
        '${peakMemoryMB.toStringAsFixed(1)}MB peak)';
  }
}
