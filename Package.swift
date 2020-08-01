// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "SwiftBeanCountWealthsimpleMapper",
    products: [
        .library(
            name: "SwiftBeanCountWealthsimpleMapper",
            targets: ["SwiftBeanCountWealthsimpleMapper"]),
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
            url: "https://github.com/Nef10/WealthsimpleDownloader.git",
            .upToNextMajor(from: "1.0.0")
        ),
    ],
    targets: [
        .target(
            name: "SwiftBeanCountWealthsimpleMapper",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParser",
                .product(name: "Wealthsimple", package: "WealthsimpleDownloader")
            ]),
        .testTarget(
            name: "SwiftBeanCountWealthsimpleMapperTests",
            dependencies: ["SwiftBeanCountWealthsimpleMapper"]),
    ]
)
