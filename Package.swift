// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "SwiftBeanCount",
    platforms: [
        .macOS(.v11),
        .iOS(.v14)
    ],
    products: [
        .executable(name: "swiftbeancount", targets: ["SwiftBeanCountCLI"]),
        .library(name: "SwiftBeanCountModel", targets: ["SwiftBeanCountModel"]),
        .library(name: "SwiftBeanCountParser", targets: ["SwiftBeanCountParser"]),
        .library(name: "SwiftBeanCountParserUtils", targets: ["SwiftBeanCountParserUtils"]),
        .library(name: "SwiftBeanCountTax", targets: ["SwiftBeanCountTax"]),
        .library(name: "SwiftBeanCountRogersBankMapper", targets: ["SwiftBeanCountRogersBankMapper"]),
        .library(name: "SwiftBeanCountCompassCardMapper", targets: ["SwiftBeanCountCompassCardMapper"]),
        .library(name: "SwiftBeanCountTangerineMapper", targets: ["SwiftBeanCountTangerineMapper"]),
        .library(name: "SwiftBeanCountWealthsimpleMapper", targets: ["SwiftBeanCountWealthsimpleMapper"]),
        .library(name: "SwiftBeanCountSheetSync", targets: ["SwiftBeanCountSheetSync"]),
        .library(name: "SwiftBeanCountImporter", targets: ["SwiftBeanCountImporter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Nef10/RogersBankDownloader.git", exact: "0.2.2"),
        .package(url: "https://github.com/Nef10/WealthsimpleDownloader.git", from: "3.0.0"),
        .package(url: "https://github.com/Nef10/GoogleAuthentication.git", from: "1.0.3"),
        .package(url: "https://github.com/Nef10/TangerineDownloader.git", exact: "0.1.0"),
        .package(url: "https://github.com/Nef10/CompassCardDownloader.git", exact: "0.0.2"),
        .package(url: "https://github.com/yaslab/CSV.swift.git", from: "2.5.2"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.6.1"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.2.0"),
        .package(url: "https://github.com/scottrhoyt/SwiftyTextTable.git", exact: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftBeanCountCLI",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParser",
                "SwiftBeanCountTax",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "SwiftyTextTable",
                "Rainbow",
            ],
            exclude: ["README.md"]
        ),
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
        .target(
            name: "SwiftBeanCountWealthsimpleMapper",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParserUtils",
                .product(name: "Wealthsimple", package: "WealthsimpleDownloader")
            ],
            exclude: ["README.md"]
        ),
        .target(
            name: "SwiftBeanCountSheetSync",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParser",
                "GoogleAuthentication"
            ],
            exclude: ["README.md"]
        ),
        .target(
            name: "SwiftBeanCountImporter",
            dependencies: [
                .product(name: "CSV", package: "CSV.swift"),
                "RogersBankDownloader",
                "SwiftBeanCountModel",
                "SwiftBeanCountParserUtils",
                "SwiftBeanCountRogersBankMapper",
                "SwiftBeanCountWealthsimpleMapper",
                "SwiftBeanCountCompassCardMapper",
                "CompassCardDownloader",
                "TangerineDownloader",
                "SwiftBeanCountTangerineMapper",
                "SwiftBeanCountSheetSync",
                .product(name: "Wealthsimple", package: "WealthsimpleDownloader"),
            ],
            exclude: ["README.md"]
        ),
        .testTarget(name: "SwiftBeanCountCLITests", dependencies: ["SwiftBeanCountCLI"]),
        .testTarget(name: "SwiftBeanCountModelTests", dependencies: ["SwiftBeanCountModel"]),
        .testTarget(name: "SwiftBeanCountParserTests", dependencies: ["SwiftBeanCountParser"], resources: [.copy("Resource")]),
        .testTarget(name: "SwiftBeanCountParserUtilsTests", dependencies: ["SwiftBeanCountParserUtils"]),
        .testTarget(name: "SwiftBeanCountTaxTests", dependencies: ["SwiftBeanCountTax"]),
        .testTarget(name: "SwiftBeanCountRogersBankMapperTests", dependencies: ["SwiftBeanCountRogersBankMapper"]),
        .testTarget(name: "SwiftBeanCountCompassCardMapperTests", dependencies: ["SwiftBeanCountCompassCardMapper"]),
        .testTarget(name: "SwiftBeanCountTangerineMapperTests", dependencies: ["SwiftBeanCountTangerineMapper"]),
        .testTarget(name: "SwiftBeanCountWealthsimpleMapperTests", dependencies: ["SwiftBeanCountWealthsimpleMapper"]),
        .testTarget(name: "SwiftBeanCountSheetSyncTests", dependencies: ["SwiftBeanCountSheetSync"]),
        .testTarget(name: "SwiftBeanCountImporterTests", dependencies: ["SwiftBeanCountImporter"]),
    ]
)
