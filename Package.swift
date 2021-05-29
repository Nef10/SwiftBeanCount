// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "SwiftBeanCountCLI",
    products: [
        .library(
            name: "SwiftBeanCountCLILibrary",
            targets: ["SwiftBeanCountCLILibrary"]
        ),
        .executable(
            name: "swiftbeancount",
            targets: ["SwiftBeanCountCLI"]
        ),
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
            url: "https://github.com/apple/swift-argument-parser",
            .upToNextMinor(from: "0.3.1")
        ),
        .package(
            url: "https://github.com/scottrhoyt/SwiftyTextTable.git",
            .upToNextMinor(from: "0.9.0")
        ),
        .package(
            url: "https://github.com/onevcat/Rainbow",
            .upToNextMajor(from: "4.0.0")
        ),
    ],
    targets: [
        .target(
            name: "SwiftBeanCountCLILibrary",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParser",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "SwiftyTextTable",
                "Rainbow",
            ]
        ),
        .testTarget(
            name: "SwiftBeanCountCLILibraryTests",
            dependencies: [
                "SwiftBeanCountCLILibrary"
            ]
        ),
        .target(
            name: "SwiftBeanCountCLI",
            dependencies: [
                "SwiftBeanCountCLILibrary"
            ]
        ),
    ]
)
