// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "SwiftBeanCountStatements",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "SwiftBeanCountStatements",
            targets: ["SwiftBeanCountStatements"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountModel.git",
            exact: "0.1.6"
        )
    ],
    targets: [
        .target(
            name: "SwiftBeanCountStatements",
            dependencies: ["SwiftBeanCountModel"]),
        .testTarget(
            name: "SwiftBeanCountStatementsTests",
            dependencies: ["SwiftBeanCountStatements"]
        ),
    ]
)
