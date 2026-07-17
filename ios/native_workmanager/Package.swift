// swift-tools-version: 5.9
// This Package.swift enables Swift Package Manager support alongside CocoaPods.
// Both build systems are supported and kept in sync.

import PackageDescription

let package = Package(
    name: "native_workmanager",
    platforms: [
        .iOS("14.0"),
    ],
    products: [
        // The library PRODUCT must be the hyphenated plugin name (issue #52).
        // Flutter's generated FlutterGeneratedPluginSwiftPackage references
        // plugins as .product(name: plugin.name.replaceAll('_', '-'),
        // package: plugin.name) — see flutter_tools swift_package_manager.dart.
        // SPM uses the product name as CFBundleIdentifier when linked
        // dynamically, and CFBundleIdentifier cannot contain underscores.
        // Package name and target names keep their underscores.
        .library(name: "native-workmanager", targets: ["native_workmanager"]),
    ],
    dependencies: [
        // No third-party dependencies. Uses Apple Archive for ZIP operations.
    ],
    targets: [
        // KMPWorkManager (kmpworkmanager v3.1.0) as a REMOTE binary target.
        //
        // Must be remote, not a local `path:`, for Swift Package Manager: on a
        // pub.dev install `.pubignore` strips `ios/Frameworks/`, and SPM has no
        // installation hook (unlike CocoaPods' `prepare_command`) that can
        // populate a local binary target before artifact resolution — a `path:`
        // target then resolves to nothing and xcodebuild aborts (issue #49).
        // This URL/checksum points at the SAME GitHub-release zip the podspec's
        // `prepare_command` downloads for CocoaPods installs.
        //
        // The asset version tracks `kmpworkmanager`, not this plugin — it only
        // changes when the bundled framework changes, so it can lag the plugin
        // version. `checksum` is the SHA-256 of the ZIP bytes
        // (`swift package compute-checksum KMPWorkManager.xcframework.zip`); the
        // `.xcframework` must sit at the archive ROOT (SPM requirement — the zip
        // must not double-nest it, cf. issue #33). Never mutate a published
        // release asset: it invalidates this checksum. Keep this URL and the
        // podspec's `prepare_command` URL pointing at the same asset.
        .binaryTarget(
            name: "KMPWorkManager",
            url: "https://github.com/brewkits/native_workmanager/releases/download/v1.4.0/KMPWorkManager.xcframework.zip",
            checksum: "561d5b3417358f9f14e845af34bfb5fcceddc57d2e1bf2ea500ddd3a320005f8"
        ),
        // Issue #36: ObjC target that registers BGTask launch handlers in +load,
        // before the app finishes launching. Required because on the Flutter 3.38+
        // UIScene template plugin registration happens too late for
        // BGTaskScheduler.register, and because only ObjC can catch the
        // NSExceptions it throws. Must stay a separate target: SPM targets are
        // single-language, so the .m/.h files cannot live in the Swift target.
        .target(
            name: "native_workmanager_objc",
            path: "Sources/native_workmanager_objc",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("BackgroundTasks"),
            ]
        ),
        .target(
            name: "native_workmanager",
            dependencies: [
                "KMPWorkManager",
                "native_workmanager_objc",
            ],
            path: "Sources/native_workmanager",
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
        // NOTE: no .testTarget here — deliberately. The Swift unit tests live in
        // ios/Tests/ (outside this package root) and a testTarget with
        // path: "../Tests" makes some SwiftPM toolchains reject the ENTIRE
        // manifest at load time with "target 'NativeWorkManagerTests' in package
        // 'native_workmanager' is outside the package root" — which breaks
        // dependency resolution for every SPM-enabled consumer app on those
        // toolchains (newer SwiftPM tolerates it, so local builds can pass while
        // consumers fail). Consumer-facing plugin manifests must not declare test
        // targets; run the Swift tests through the example app's Xcode workspace
        // (RunnerTests) or a dev-only manifest instead.
    ]
)
