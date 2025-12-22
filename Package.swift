// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SwiftBeanCount",
    products: [
        .library(
            name: "SwiftBeanCountModel",
            targets: ["SwiftBeanCountModel"]
        ),
        .library(
            name: "SwiftBeanCountParser",
            targets: ["SwiftBeanCountParser"]
        ),
        .library(
            name: "SwiftBeanCountParserUtils",
            targets: ["SwiftBeanCountParserUtils"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SwiftBeanCountModel",
            dependencies: [],
            exclude: ["README.md"]
        ),
        .target(
            name: "SwiftBeanCountParser",
            dependencies: ["SwiftBeanCountModel", "SwiftBeanCountParserUtils"],
            exclude: ["README.md"]
        ),
        .target(
            name: "SwiftBeanCountParserUtils",
            dependencies: [],
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "SwiftBeanCountModelTests",
            dependencies: ["SwiftBeanCountModel"]
        ),
        .testTarget(
            name: "SwiftBeanCountParserTests",
            dependencies: ["SwiftBeanCountParser"],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "SwiftBeanCountParserUtilsTests",
            dependencies: ["SwiftBeanCountParserUtils"]
        ),
    ]
)
