// swift-tools-version: 5.9
// This Package.swift enables Swift Package Manager support alongside CocoaPods.
// Both build systems are supported and kept in sync.

import PackageDescription

let package = Package(
    name: "native_workmanager",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "native_workmanager", targets: ["native_workmanager"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/weichsel/ZIPFoundation.git",
            from: "0.9.19"
        ),
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
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ],
            path: "Sources/native_workmanager",
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)
