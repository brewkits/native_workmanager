import Flutter
import UIKit
import KMPWorkManager
import native_workmanager  // For IosWorkerFactory and BackgroundSessionManager

// The example app uses the Flutter 3.38+ UIScene lifecycle template
// (FlutterImplicitEngineDelegate + SceneDelegate + scene manifest in Info.plist).
// On this template plugins register in didInitializeImplicitFlutterEngine — AFTER
// application(_:didFinishLaunchingWithOptions:) has returned. This is exactly the
// lifecycle that crashed BGTaskScheduler registration in issue #36, so the device
// test suite must keep running on it as regression coverage.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register custom workers as early as possible (before any plugin code runs).
    // IosWorker and WorkerResult are re-exported from native_workmanager via typealiases
    // in Runner/IosWorker.swift and Runner/WorkerResult.swift.
    IosWorkerFactory.registerWorker(className: "ImageCompressWorker") {
        return ImageCompressWorker()
    }
    // Example-only fixture for device integration tests.
    IosWorkerFactory.registerWorker(className: "Issue84Probe") { Issue84Probe() }
    // Add more custom workers here following the same pattern.

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Setup metrics channel on the implicit engine's registry (the pre-3.38
    // self.registrar(forPlugin:) path is not available before the implicit
    // engine exists on this template).
    let registrar = engineBridge.pluginRegistry
      .registrar(forPlugin: "dev.brewkits.native_workmanager.example.MetricsPlugin")!
    let metricsChannel = FlutterMethodChannel(
      name: "dev.brewkits.native_workmanager.example/metrics",
      binaryMessenger: registrar.messenger()
    )

    metricsChannel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "getMemoryMetrics":
        result(self?.getMemoryMetrics())
      case "getCpuMetrics":
        result(self?.getCpuMetrics())
      case "getBatteryMetrics":
        result(self?.getBatteryMetrics())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Background URLSession Support (v2.3.0+)

  /// Called when background transfers complete while app is terminated.
  ///
  /// This method is invoked by iOS when background downloads/uploads finish
  /// and the app needs to be relaunched to handle the completion.
  ///
  /// **IMPORTANT:** The session identifier must match BackgroundSessionManager's identifier.
  /// See: BackgroundSessionManager.sessionIdentifier
  @available(iOS 13.0, *)
  override func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    NSLog("AppDelegate: Background URLSession event for identifier: \(identifier)")

    // Store completion handler in BackgroundSessionManager
    // The manager will call this when all transfers are done
    if identifier == "dev.brewkits.native_workmanager.background" {
      BackgroundSessionManager.shared.backgroundCompletionHandler = completionHandler
      NSLog("AppDelegate: Stored completion handler for background session")

      // Safety timeout: If BackgroundSessionManager doesn't call the handler within 30 seconds,
      // call it anyway to prevent iOS from terminating the app
      DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
        if BackgroundSessionManager.shared.backgroundCompletionHandler != nil {
          NSLog("AppDelegate: WARNING - Completion handler not called after 30s, calling now to prevent timeout")
          BackgroundSessionManager.shared.backgroundCompletionHandler?()
          BackgroundSessionManager.shared.backgroundCompletionHandler = nil
        }
      }
    } else {
      // Unknown session identifier - call completion handler immediately
      NSLog("AppDelegate: Warning - Unknown session identifier: \(identifier)")
      completionHandler()
    }
  }

  private func getMemoryMetrics() -> [String: Any] {
    // Get total physical memory
    let totalRAM = ProcessInfo.processInfo.physicalMemory

    // Get app memory usage (resident_size)
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }

    let appRAM = result == KERN_SUCCESS ? info.resident_size : 0

    // Get virtual memory statistics for system-wide info
    var vmStats = vm_statistics64()
    var vmStatsCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

    let vmResult = withUnsafeMutablePointer(to: &vmStats) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmStatsCount)) {
        host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmStatsCount)
      }
    }

    let pageSize = UInt64(vm_kernel_page_size)
    let freeRAM = vmResult == KERN_SUCCESS ? UInt64(vmStats.free_count) * pageSize : 0
    let activeRAM = vmResult == KERN_SUCCESS ? UInt64(vmStats.active_count) * pageSize : 0
    let inactiveRAM = vmResult == KERN_SUCCESS ? UInt64(vmStats.inactive_count) * pageSize : 0
    let wiredRAM = vmResult == KERN_SUCCESS ? UInt64(vmStats.wire_count) * pageSize : 0

    let usedRAM = activeRAM + inactiveRAM + wiredRAM
    let availableRAM = totalRAM - usedRAM

    // Get Dart heap (use app virtual size as approximation)
    let dartHeap = info.virtual_size

    // Native heap is part of resident size
    let nativeHeap = appRAM

    return [
      "totalRAM": totalRAM,
      "usedRAM": usedRAM,
      "availableRAM": availableRAM,
      "appRAM": appRAM,
      "dartHeap": dartHeap,
      "nativeHeap": nativeHeap,
      "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
    ]
  }

  private func getCpuMetrics() -> [String: Any] {
    let cpuUsage = getCurrentCpuUsage()
    let cpuCores = ProcessInfo.processInfo.processorCount

    return [
      "cpuUsage": cpuUsage,
      "cpuCores": cpuCores,
      "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
    ]
  }

  private func getBatteryMetrics() -> [String: Any] {
    UIDevice.current.isBatteryMonitoringEnabled = true

    let level = UIDevice.current.batteryLevel * 100.0
    let state = UIDevice.current.batteryState
    let isCharging = state == .charging || state == .full

    return [
      "level": Double(level),
      "isCharging": isCharging,
      "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
    ]
  }

  private func getCurrentCpuUsage() -> Double {
    var threadsList: thread_act_array_t?
    var threadsCount = mach_msg_type_number_t(0)

    let threadsResult = task_threads(mach_task_self_, &threadsList, &threadsCount)

    guard threadsResult == KERN_SUCCESS, let threads = threadsList else {
      return 0.0
    }

    var totalCpu: Double = 0.0

    for i in 0..<Int(threadsCount) {
      var threadInfo = thread_basic_info()
      var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

      let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
          thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
        }
      }

      guard infoResult == KERN_SUCCESS else { continue }

      if threadInfo.flags & TH_FLAGS_IDLE == 0 {
        totalCpu += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
      }
    }

    vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))

    return totalCpu
  }
}

/// Records actual execution intervals without network or OS scheduling timing assumptions.
private final class Issue84Probe: IosWorker {
    func doWork(input: String?, env: KMPWorkManager.WorkerEnvironment) async throws -> WorkerResult {
        guard let data = input?.data(using: .utf8),
              let config = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = config["path"] as? String else {
            return .failure(message: "Missing probe path")
        }
        let start = Int64(Date().timeIntervalSince1970 * 1000)
        try await Task.sleep(nanoseconds: 500_000_000)
        let interval = ["start": start, "end": Int64(Date().timeIntervalSince1970 * 1000)]
        try JSONSerialization.data(withJSONObject: interval).write(to: URL(fileURLWithPath: path))
        return .success()
    }
}
