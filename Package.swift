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
            url: "https://github.com/Nef10/SwiftBeanCountParserUtils.git",
            from: "1.0.0"
        ),
        .package(
            url: "https://github.com/Nef10/RogersBankDownloader.git",
            .exact("0.1.0")
        ),
    ],
    targets: [
        .target(
            name: "SwiftBeanCountRogersBankMapper",
            dependencies: [
                "SwiftBeanCountModel",
                "SwiftBeanCountParserUtils",
                "RogersBankDownloader",
            ]),
        .testTarget(
            name: "SwiftBeanCountRogersBankMapperTests",
            dependencies: ["SwiftBeanCountRogersBankMapper"]),
    ]
)
