// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SpotterShared",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "SpotterShared",
            targets: ["SpotterShared"]
        )
    ],
    targets: [
        .target(name: "SpotterShared")
    ]
)
