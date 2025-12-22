// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "SwiftBeanCountModel",
    products: [
        .library(
            name: "SwiftBeanCountModel",
            targets: ["SwiftBeanCountModel"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SwiftBeanCountModel",
            dependencies: []),
        .testTarget(
            name: "SwiftBeanCountModelTests",
            dependencies: ["SwiftBeanCountModel"]),
    ]
)
