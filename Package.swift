// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SwiftBeanCountRogersBankMapper",
    products: [
        .library(
            name: "SwiftBeanCountRogersBankMapper",
            targets: ["SwiftBeanCountRogersBankMapper"]),
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
            url: "https://github.com/Nef10/RogersBankDownloader.git",
            .exact("0.0.3")
        ),
    ],
    targets: [
        .target(
            name: "SwiftBeanCountRogersBankMapper",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParser",
                "RogersBankDownloader",
            ]),
        .testTarget(
            name: "SwiftBeanCountRogersBankMapperTests",
            dependencies: ["SwiftBeanCountRogersBankMapper"]),
    ]
)
