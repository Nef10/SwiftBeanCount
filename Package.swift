// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SwiftBeanCountImporter",
    platforms: [.iOS(.v14), .macOS(.v11)],
    products: [
        .library(
            name: "SwiftBeanCountImporter",
            targets: ["SwiftBeanCountImporter"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountModel.git",
            .exact("0.1.6")
        ),
        .package(
            url: "https://github.com/yaslab/CSV.swift.git",
            .upToNextMinor(from: "2.4.3")
        ),
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountParserUtils.git",
            .exact("0.0.1")
        ),
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountWealthsimpleMapper.git",
            .upToNextMajor(from: "1.4.2")
        ),
        .package(
            url: "https://github.com/Nef10/WealthsimpleDownloader.git",
            .upToNextMajor(from: "2.0.1")
        ),
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountRogersBankMapper.git",
            .exact("0.0.7")
        ),
        .package(
            url: "https://github.com/Nef10/RogersBankDownloader.git",
            .exact("0.0.7")
        ),
        .package(
            url: "https://github.com/Nef10/TangerineDownloader.git",
            .exact("0.0.2")
        ),
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountTangerineMapper.git",
            .exact("0.0.2")
        )
    ],
    targets: [
        .target(
            name: "SwiftBeanCountImporter",
            dependencies: [
                .product(name: "CSV", package: "CSV.swift"),
                "RogersBankDownloader",
                "SwiftBeanCountModel",
                "SwiftBeanCountParserUtils",
                "SwiftBeanCountRogersBankMapper",
                "SwiftBeanCountWealthsimpleMapper",
                .product(name: "TangerineDownloader", package: "TangerineDownloader", condition: .when(platforms: [.macOS, .iOS])),
                .product(name: "SwiftBeanCountTangerineMapper", package: "TangerineDownloader", condition: .when(platforms: [.macOS, .iOS])),
                .product(name: "Wealthsimple", package: "WealthsimpleDownloader"),
            ]
        ),
        .testTarget(
            name: "SwiftBeanCountImporterTests",
            dependencies: ["SwiftBeanCountImporter"]
        ),
    ]
)
