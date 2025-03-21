// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "SwiftBeanCountCLI",
    products: [
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
            url: "https://github.com/Nef10/SwiftBeanCountTax.git",
            .exact("0.0.4")
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            .upToNextMinor(from: "1.5.0")
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
        .executableTarget(
            name: "SwiftBeanCountCLI",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParser",
                "SwiftBeanCountTax",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "SwiftyTextTable",
                "Rainbow",
            ]
        ),
        .testTarget(
            name: "SwiftBeanCountCLITests",
            dependencies: [
                "SwiftBeanCountCLI"
            ]
        ),
    ]
)
