// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SwiftBeanCountSheetSync",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "SwiftBeanCountSheetSync",
            targets: ["SwiftBeanCountSheetSync"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountModel.git",
            .exact("0.1.6")
        ),
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountParser.git",
            .exact("0.1.8")
        ),
        .package(
            url: "https://github.com/Nef10/GoogleAuthentication.git",
            .upToNextMajor(from: "1.0.1")
        ),
    ],
    targets: [
        .target(
            name: "SwiftBeanCountSheetSync",
            dependencies: ["SwiftBeanCountModel", "SwiftBeanCountParser", "GoogleAuthentication"]),
        .testTarget(
            name: "SwiftBeanCountSheetSyncTests",
            dependencies: ["SwiftBeanCountSheetSync"]),
    ]
)
