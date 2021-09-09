// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "SwiftBeanCountParser",
    products: [
        .library(
            name: "SwiftBeanCountParser",
            targets: ["SwiftBeanCountParser"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountModel.git",
            .exact("0.1.6")
        ),
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountParserUtils.git",
            .exact("0.0.1")
        ),
    ],
    targets: [
        .target(
            name: "SwiftBeanCountParser",
            dependencies: ["SwiftBeanCountModel", "SwiftBeanCountParserUtils"]),
        .testTarget(
            name: "SwiftBeanCountParserTests",
            dependencies: ["SwiftBeanCountParser"]),
    ]
)
