// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SwiftBeanCountCompassCardMapper",
    products: [
        .library(
            name: "SwiftBeanCountCompassCardMapper",
            targets: ["SwiftBeanCountCompassCardMapper"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountParserUtils.git",
            from: "1.0.0"
        ),
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountModel.git",
            .exact("0.1.6")
        ),
        .package(
            url: "https://github.com/yaslab/CSV.swift.git",
            from: "2.4.3"
        )
    ],
    targets: [
        .target(
            name: "SwiftBeanCountCompassCardMapper",
            dependencies: [
                "SwiftBeanCountParserUtils",
                "SwiftBeanCountModel",
                .product(name: "CSV", package: "CSV.swift"),
            ]
        ),
        .testTarget(
            name: "SwiftBeanCountCompassCardMapperTests",
            dependencies: ["SwiftBeanCountCompassCardMapper"]
        ),
    ]
)
