// swift-tools-version:6.2

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v5),
    .treatAllWarnings(as: .error),
    .treatWarning("SendableClosureCaptures", as: .warning),
]

let package = Package(
    name: "SwiftBeanCount",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
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
        .package(url: "https://github.com/Nef10/RogersBankDownloader.git", exact: "0.3.0"),
        .package(url: "https://github.com/Nef10/WealthsimpleDownloader.git", from: "3.0.0"),
        .package(url: "https://github.com/Nef10/GoogleAuthentication.git", from: "1.1.0"),
        .package(url: "https://github.com/Nef10/TangerineDownloader.git", exact: "0.1.0"),
        .package(url: "https://github.com/Nef10/CompassCardDownloader.git", exact: "0.0.2"),
        .package(url: "https://github.com/yaslab/CSV.swift.git", from: "2.5.2"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.2.1"),
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
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountModel",
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountParser",
            dependencies: ["SwiftBeanCountModel", "SwiftBeanCountParserUtils"],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountParserUtils",
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountTax",
            dependencies: ["SwiftBeanCountModel"],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountStatements",
            dependencies: ["SwiftBeanCountModel"],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountRogersBankMapper",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParserUtils",
                "RogersBankDownloader",
            ],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountCompassCardMapper",
            dependencies: [
                "SwiftBeanCountParserUtils",
                "SwiftBeanCountModel",
                .product(name: "CSV", package: "CSV.swift"),
            ],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountTangerineMapper",
            dependencies: [
                "SwiftBeanCountParserUtils",
                "SwiftBeanCountModel",
            ],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountWealthsimpleMapper",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParserUtils",
                .product(name: "Wealthsimple", package: "WealthsimpleDownloader")
            ],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .target(
            name: "SwiftBeanCountSheetSync",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParser",
                .product(name: "GoogleAuthentication", package: "GoogleAuthentication", condition: .when(platforms: [.macOS, .iOS])),
            ],
            swiftSettings: swiftSettings,
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
                "SwiftBeanCountTangerineMapper",
                .product(name: "Wealthsimple", package: "WealthsimpleDownloader"),
                .byName(name: "SwiftBeanCountSheetSync", condition: .when(platforms: [.macOS, .iOS])),
                .product(name: "CompassCardDownloader", package: "CompassCardDownloader", condition: .when(platforms: [.macOS, .iOS])),
                .product(name: "TangerineDownloader", package: "TangerineDownloader", condition: .when(platforms: [.macOS, .iOS])),
            ],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountCLITests",
            dependencies: ["SwiftBeanCountCLI"],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountModelTests",
            dependencies: ["SwiftBeanCountModel"],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountParserTests",
            dependencies: ["SwiftBeanCountParser"],
            resources: [.copy("Resource")],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountParserUtilsTests",
            dependencies: ["SwiftBeanCountParserUtils"],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountTaxTests",
            dependencies: ["SwiftBeanCountTax"],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountStatementsTests",
            dependencies: ["SwiftBeanCountStatements"],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountRogersBankMapperTests",
            dependencies: ["SwiftBeanCountRogersBankMapper"],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountCompassCardMapperTests",
            dependencies: ["SwiftBeanCountCompassCardMapper"],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountTangerineMapperTests",
            dependencies: ["SwiftBeanCountTangerineMapper"],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountWealthsimpleMapperTests",
            dependencies: ["SwiftBeanCountWealthsimpleMapper"],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountSheetSyncTests",
            dependencies: ["SwiftBeanCountSheetSync"],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SwiftBeanCountImporterTests",
            dependencies: ["SwiftBeanCountImporter"],
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
    ]
)
