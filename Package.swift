// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SwiftBeanCountTangerineMapper",
    products: [
        .library(
            name: "SwiftBeanCountTangerineMapper",
            targets: ["SwiftBeanCountTangerineMapper"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountParserUtils.git",
            from: "1.0.0"
        ),
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountModel.git",
            .exact("0.2.0")
        )
    ],
    targets: [
        .target(
            name: "SwiftBeanCountTangerineMapper",
            dependencies: [
                "SwiftBeanCountParserUtils",
                "SwiftBeanCountModel",
            ]
        ),
        .testTarget(
            name: "SwiftBeanCountTangerineMapperTests",
            dependencies: ["SwiftBeanCountTangerineMapper"]
        ),
    ]
)
