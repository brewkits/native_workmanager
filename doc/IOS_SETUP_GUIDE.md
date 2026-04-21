# iOS Setup Guide (KMP & Framework Integration)

This guide covers the necessary steps to properly configure your iOS project for `native_workmanager`, specifically focusing on the integration of the Kotlin Multiplatform (KMP) framework.

---

## 1. Prerequisites

- **Xcode 14.0+**
- **CocoaPods 1.12.0+**
- **iOS Deployment Target: 14.0+**
- **Apple Silicon Mac (M1/M2/M3)**: Requires specific Podfile configuration for simulators.

---

## 2. Podfile Configuration

The `native_workmanager` plugin includes a pre-compiled `.xcframework`. To ensure it works across all architectures (including simulators on Apple Silicon), you **must** add the following `post_install` hook to your `ios/Podfile`:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    target.build_configurations.each do |config|
      # 1. Ensure deployment target matches (minimum 14.0 for KMP compatibility)
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      
      # 2. Fix Apple Silicon Simulator architecture issues
      # This prevents "Undefined symbol: _OBJC_CLASS_$_..." errors when running on M1/M2/M3 Macs
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'i386 arm64'
    end
  end
end
```

### Why is this necessary?
The `KMPWorkManager.xcframework` is a binary dependency. By default, Xcode might try to build it for `arm64` simulators on Intel Macs or vice versa, causing linker errors. The configuration above ensures that the simulator only uses the compatible architecture.

---

## 3. Info.plist Setup

You must register the background task identifiers used by the plugin. Open `ios/Runner/Info.plist` and add:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <!-- Used for standard background tasks -->
  <string>dev.brewkits.native_workmanager.refresh</string>
  <!-- Used for heavy background tasks (Processing tasks) -->
  <string>dev.brewkits.native_workmanager.task</string>
</array>

<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>processing</string>
</array>
```

---

## 4. AppDelegate Integration

To handle background task completion and URLSession events, update your `AppDelegate.swift`:

```swift
import UIKit
import Flutter
import native_workmanager

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // REQUIRED: Handle Background URLSession events (for downloads/uploads)
  override func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    NativeWorkmanagerPlugin.handleBackgroundURLSession(
      identifier: identifier,
      completionHandler: completionHandler
    )
  }
}
```

---

## 5. Troubleshooting KMP Integration

### Error: `Undefined symbol: _OBJC_CLASS_$_KMPWorkManager`
- **Solution:** Ensure you have run `pod install` in the `ios` directory.
- **Solution:** Check if the `KMPWorkManager.xcframework` exists in `ios/Pods/native_workmanager/Frameworks/`.
- **Solution:** Verify your `IPHONEOS_DEPLOYMENT_TARGET` is at least `14.0` in BOTH the project and the Podfile.

### Error: `Incompatible architectures (arm64 vs x86_64)`
- **Solution:** This usually happens on Apple Silicon Macs. Ensure you have added the `EXCLUDED_ARCHS` setting in the `post_install` hook shown above.
- **Solution:** Try running Xcode using Rosetta (Right-click Xcode.app -> Get Info -> Open using Rosetta), though the Podfile fix is the preferred modern approach.

### Task never fires in Simulator
- **Reason:** iOS Simulator does **not** support automatic `BGTaskScheduler` firing.
- **Solution:** Use the debugger command in Xcode's LLDB console:
  ```bash
  e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"dev.brewkits.native_workmanager.refresh"]
  ```

### Other plugins not working in DartWorker

**Symptoms:** Your `DartWorker` runs, but other plugins like `flutter_local_notifications` or `shared_preferences` don't seem to work or throw errors.

**Solution:**
Enable plugin registration during initialization in Dart:
```dart
await NativeWorkManager.initialize(
  registerPlugins: true,
  dartWorkers: { ... },
);
```
By default, the background engine does **not** register plugins to save RAM and avoid side-effects.

### Selective Plugin Registration (Recommended)

To maintain peak performance and avoid side-effects (like Audio/Bluetooth drops), we recommend keeping `registerPlugins: false` and manually registering only the necessary plugins for your background tasks.

In your `AppDelegate.swift`:

```swift
import native_workmanager
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        NativeWorkmanagerPlugin.setPluginRegistrantCallback { registry in
            // Manually register specific plugins for the background engine
            FlutterLocalNotificationsPlugin.register(with: registry.registrar(forPlugin: "FlutterLocalNotificationsPlugin")!)
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

---

## 6. App Store Submission (Privacy Info)

The plugin includes a `PrivacyInfo.xcprivacy` file as required by Apple (effective May 2024). It declares the use of:
- **Background Tasks API**: Used for scheduling work.
- **File System API**: Used for `FileWorker` and `ImageProcessWorker`.

No additional action is needed; CocoaPods will automatically merge this into your app's privacy manifest.
