// swift-tools-version:5.3

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
            .exact("0.2.0")
        ),
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountParserUtils.git",
            from: "1.0.0"
        ),
    ],
    targets: [
        .target(
            name: "SwiftBeanCountParser",
            dependencies: ["SwiftBeanCountModel", "SwiftBeanCountParserUtils"]),
        .testTarget(
            name: "SwiftBeanCountParserTests",
            dependencies: ["SwiftBeanCountParser"],
            resources: [.copy("Resources")]),
    ]
)
