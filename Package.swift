// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SwiftBeanCountTax",
    products: [
        .library(
            name: "SwiftBeanCountTax",
            targets: ["SwiftBeanCountTax"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/Nef10/SwiftBeanCountModel.git",
            .exact("0.1.6")
        )
    ],
    targets: [
        .target(
            name: "SwiftBeanCountTax",
            dependencies: ["SwiftBeanCountModel"]),
        .testTarget(
            name: "SwiftBeanCountTaxTests",
            dependencies: ["SwiftBeanCountTax"])
    ]
)
