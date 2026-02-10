import Flutter
import UIKit
import Runner // Added to explicitly import the Runner module
import native_workmanager  // For BackgroundSessionManager access
#if canImport(ImageCompressWorker)
import ImageCompressWorker
#endif

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register custom workers BEFORE GeneratedPluginRegistrant
#if canImport(ImageCompressWorker)
      IosWorkerFactory.registerWorker(className: "ImageCompressWorker") {
          return ImageCompressWorker()
      }
#endif
    // Add more workers here

    GeneratedPluginRegistrant.register(with: self)

    // Setup metrics channel
    guard let controller = window?.rootViewController as? FlutterViewController else {
      NSLog("AppDelegate: Failed to get FlutterViewController")
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let metricsChannel = FlutterMethodChannel(
      name: "dev.brewkits.native_workmanager.example/metrics",
      binaryMessenger: controller.binaryMessenger
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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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