#
# Native WorkManager for Flutter - iOS
# Uses KMP WorkManager as the native engine
#
Pod::Spec.new do |s|
  s.name             = 'native_workmanager'
  s.version          = '1.4.1'
  s.summary          = 'Background task manager for Flutter using platform-native APIs.'
  s.description      = <<-DESC
Native WorkManager is a Flutter plugin that provides native background task scheduling
using Kotlin Multiplatform. It runs tasks without waking up the Flutter Engine,
saving battery and memory.

Features:
- Zero Flutter Engine overhead for native workers
- Task chains (A → B → C workflows)
- Auto iOS configuration (reads Info.plist)
- Built-in HTTP workers (request, upload, download, sync)
                       DESC
  s.homepage         = 'https://github.com/brewkits/native_workmanager'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Brewkits' => 'vietnguyentuan@gmail.com' }
  s.source           = { :path => '.' }
  # Sources now live in the SPM-compatible location (shared with Package.swift).
  # native_workmanager_objc holds the +load BGTask registrar (Issue #36) — in the
  # CocoaPods build it compiles into the same mixed-language pod target, so the
  # Swift side sees NWMBGTaskRegistrar through the umbrella header (no import).
  s.source_files     = 'native_workmanager/Sources/native_workmanager/**/*.{swift,h,m}',
                       'native_workmanager/Sources/native_workmanager_objc/**/*.{h,m}'
  s.frameworks       = 'BackgroundTasks'
  s.dependency 'Flutter'
  s.platform         = :ios, '14.0'

  # Ensure Swift files are included
  s.ios.deployment_target = '14.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'

  # KMP WorkManager Framework (kmpworkmanager v3.1.0)
  # Downloaded from GitHub Releases to stay under the pub.dev 100 MB package limit.
  # RELEASE STEP: attach the rebuilt 3.1.0 KMPWorkManager.xcframework.zip to the v1.4.0
  # release (the framework changed 3.0.1 -> 3.1.0, so the asset must be re-uploaded — earlier
  # releases reused the v1.3.2 asset). The git-tracked copy under ios/Frameworks/ is already
  # 3.1.0 for local/CI builds; this download only fires for pub.dev installs where
  # .pubignore strips ios/Frameworks/.
  s.prepare_command = <<-CMD
    set -e
    if [ ! -d "Frameworks/KMPWorkManager.xcframework" ]; then
      echo "Downloading KMPWorkManager.xcframework v3.1.0..."
      mkdir -p Frameworks
      curl -L --retry 3 -o /tmp/KMPWorkManager.xcframework.zip \
        "https://github.com/brewkits/native_workmanager/releases/download/v1.4.0/KMPWorkManager.xcframework.zip"
      rm -rf /tmp/kmpwm_extract
      unzip -o /tmp/KMPWorkManager.xcframework.zip -d /tmp/kmpwm_extract
      # Release zip may be flat or wrapped in a Frameworks/ dir - handle both.
      SRC=$(find /tmp/kmpwm_extract -maxdepth 2 -type d -name 'KMPWorkManager.xcframework' | head -1)
      rm -rf Frameworks/KMPWorkManager.xcframework
      mv "$SRC" Frameworks/KMPWorkManager.xcframework
      rm -rf /tmp/KMPWorkManager.xcframework.zip /tmp/kmpwm_extract
    fi
  CMD
  s.vendored_frameworks = 'Frameworks/KMPWorkManager.xcframework'

  # Privacy manifest for background task APIs (iOS 17+ App Store requirement)
  s.resource_bundles = {'native_workmanager_privacy' => ['native_workmanager/Sources/native_workmanager/PrivacyInfo.xcprivacy']}
end
