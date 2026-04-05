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
        .library(name: "native_workmanager", targets: ["native_workmanager"]),
    ],
    dependencies: [
        // No third-party dependencies. Uses Apple Archive for ZIP operations.
    ],
    targets: [
        // KMPWorkManager is bundled as a local XCFramework (kmpworkmanager v2.3.3)
        .binaryTarget(
            name: "KMPWorkManager",
            path: "../Frameworks/KMPWorkManager.xcframework"
        ),
        .target(
            name: "native_workmanager",
            dependencies: [
                "KMPWorkManager",
            ],
            path: "Sources/native_workmanager",
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
        .testTarget(
            name: "NativeWorkManagerTests",
            dependencies: ["native_workmanager"],
            path: "../Tests"
        ),
    ]
)
