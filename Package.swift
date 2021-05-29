// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "SwiftBeanCountImporter",
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
    ],
    targets: [
        .target(
            name: "SwiftBeanCountImporter",
            dependencies: ["SwiftBeanCountModel", .product(name: "CSV", package: "CSV.swift")]),
        .testTarget(
            name: "SwiftBeanCountImporterTests",
            dependencies: ["SwiftBeanCountImporter"]),
    ]
)
