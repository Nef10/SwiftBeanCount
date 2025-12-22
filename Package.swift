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
    ],
    dependencies: [
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountParserUtils.git",
            from: "1.0.0"
        ),
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
        .testTarget(
            name: "SwiftBeanCountModelTests",
            dependencies: ["SwiftBeanCountModel"]
        ),
        .testTarget(
            name: "SwiftBeanCountParserTests",
            dependencies: ["SwiftBeanCountParser"],
            resources: [.copy("Resources")]
        ),
    ]
)
