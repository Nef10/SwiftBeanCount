// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "SwiftBeanCount",
    platforms: [
        .macOS(.v12),
        .iOS(.v16)
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
        .package(url: "https://github.com/Nef10/GoogleAuthentication.git", from: "1.1.0"),
        .package(url: "https://github.com/Nef10/TangerineDownloader.git", exact: "0.1.0"),
        .package(url: "https://github.com/Nef10/CompassCardDownloader.git", exact: "0.0.2"),
        .package(url: "https://github.com/yaslab/CSV.swift.git", from: "2.5.2"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.6.1"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.2.0"),
        .package(url: "https://github.com/scottrhoyt/SwiftyTextTable.git", exact: "0.9.0"),
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.62.2"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.5"),
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
            exclude: ["README.md"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountModel",
            exclude: ["README.md"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountParser",
            dependencies: ["SwiftBeanCountModel", "SwiftBeanCountParserUtils"],
            exclude: ["README.md"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountParserUtils",
            exclude: ["README.md"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountTax",
            dependencies: ["SwiftBeanCountModel"],
            exclude: ["README.md"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountRogersBankMapper",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParserUtils",
                "RogersBankDownloader",
            ],
            exclude: ["README.md"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountCompassCardMapper",
            dependencies: [
                "SwiftBeanCountParserUtils",
                "SwiftBeanCountModel",
                .product(name: "CSV", package: "CSV.swift"),
            ],
            exclude: ["README.md"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountTangerineMapper",
            dependencies: [
                "SwiftBeanCountParserUtils",
                "SwiftBeanCountModel",
            ],
            exclude: ["README.md"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountWealthsimpleMapper",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParserUtils",
                .product(name: "Wealthsimple", package: "WealthsimpleDownloader")
            ],
            exclude: ["README.md"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountSheetSync",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParser",
                "GoogleAuthentication"
            ],
            exclude: ["README.md"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
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
            exclude: ["README.md"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountCLITests",
            dependencies: ["SwiftBeanCountCLI"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountModelTests",
            dependencies: ["SwiftBeanCountModel"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountParserTests",
            dependencies: ["SwiftBeanCountParser"],
            resources: [.copy("Resource")],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountParserUtilsTests",
            dependencies: ["SwiftBeanCountParserUtils"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountTaxTests",
            dependencies: ["SwiftBeanCountTax"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountRogersBankMapperTests",
            dependencies: ["SwiftBeanCountRogersBankMapper"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountCompassCardMapperTests",
            dependencies: ["SwiftBeanCountCompassCardMapper"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountTangerineMapperTests",
            dependencies: ["SwiftBeanCountTangerineMapper"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountWealthsimpleMapperTests",
            dependencies: ["SwiftBeanCountWealthsimpleMapper"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountSheetSyncTests",
            dependencies: ["SwiftBeanCountSheetSync"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountImporterTests",
            dependencies: ["SwiftBeanCountImporter"],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
    ]
)
