// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "SwiftBeanCountParserUtils",
    products: [
        .library(
            name: "SwiftBeanCountParserUtils",
            targets: ["SwiftBeanCountParserUtils"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SwiftBeanCountParserUtils",
            dependencies: []),
        .testTarget(
            name: "SwiftBeanCountParserUtilsTests",
            dependencies: ["SwiftBeanCountParserUtils"]),
    ]
)
