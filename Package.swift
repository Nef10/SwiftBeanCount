// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "SwiftBeanCountCLI",
    products: [
        .executable(
            name: "swiftbeancount",
            targets: ["SwiftBeanCountCLI"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountModel.git",
            .exact("0.1.0")
        ),
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountParser.git",
            .exact("0.1.0")
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            .upToNextMinor(from: "0.1.0")
        ),
        .package(
            url: "https://github.com/scottrhoyt/SwiftyTextTable.git",
            .upToNextMinor(from: "0.9.0")
        )
    ],
    targets: [
        .target(
            name: "SwiftBeanCountCLI",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParser",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "SwiftyTextTable",
            ]),
    ]
)
