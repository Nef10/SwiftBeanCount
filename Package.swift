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
            .exact("0.1.0")
        ),
    ],
    targets: [
        .target(
            name: "SwiftBeanCountParser",
            dependencies: ["SwiftBeanCountModel"]),
        .testTarget(
            name: "SwiftBeanCountParserTests",
            dependencies: ["SwiftBeanCountParser"]),
    ]
)
