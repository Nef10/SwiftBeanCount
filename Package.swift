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
        .library(
            name: "SwiftBeanCountParserUtils",
            targets: ["SwiftBeanCountParserUtils"]
        ),
        .library(
            name: "SwiftBeanCountTax",
            targets: ["SwiftBeanCountTax"]
        ),
        .library(
            name: "SwiftBeanCountRogersBankMapper",
            targets: ["SwiftBeanCountRogersBankMapper"]
        ),
        .library(
            name: "SwiftBeanCountCompassCardMapper",
            targets: ["SwiftBeanCountCompassCardMapper"]
        ),
        .library(
            name: "SwiftBeanCountTangerineMapper",
            targets: ["SwiftBeanCountTangerineMapper"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/yaslab/CSV.swift.git",
            from: "2.5.2"
        ),
        .package(
            url: "https://github.com/Nef10/RogersBankDownloader.git",
            .exact("0.2.2")
        ),
    ],
    targets: [
        .target(
            name: "SwiftBeanCountModel",
            exclude: ["README.md"]
        ),
        .target(
            name: "SwiftBeanCountParser",
            dependencies: ["SwiftBeanCountModel", "SwiftBeanCountParserUtils"],
            exclude: ["README.md"]
        ),
        .target(
            name: "SwiftBeanCountParserUtils",
            exclude: ["README.md"]
        ),
        .target(
            name: "SwiftBeanCountTax",
            dependencies: ["SwiftBeanCountModel"],
            exclude: ["README.md"]
        ),
        .target(
            name: "SwiftBeanCountRogersBankMapper",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParserUtils",
                "RogersBankDownloader",
            ],
            exclude: ["README.md"]
        ),
        .target(
            name: "SwiftBeanCountCompassCardMapper",
            dependencies: [
                "SwiftBeanCountParserUtils",
                "SwiftBeanCountModel",
                .product(name: "CSV", package: "CSV.swift"),
            ],
            exclude: ["README.md"]
        ),
        .target(
            name: "SwiftBeanCountTangerineMapper",
            dependencies: [
                "SwiftBeanCountParserUtils",
                "SwiftBeanCountModel",
            ],
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
        .testTarget(
            name: "SwiftBeanCountParserUtilsTests",
            dependencies: ["SwiftBeanCountParserUtils"]
        ),
        .testTarget(
            name: "SwiftBeanCountTaxTests",
            dependencies: ["SwiftBeanCountTax"]
        ),
        .testTarget(
            name: "SwiftBeanCountRogersBankMapperTests",
            dependencies: ["SwiftBeanCountRogersBankMapper"]
        ),
        .testTarget(
            name: "SwiftBeanCountCompassCardMapperTests",
            dependencies: ["SwiftBeanCountCompassCardMapper"]
        ),
        .testTarget(
            name: "SwiftBeanCountTangerineMapperTests",
            dependencies: ["SwiftBeanCountTangerineMapper"]
        ),
    ]
)
