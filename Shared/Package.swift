// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SpotterShared",
    platforms: [
        .iOS("26.0"),
        .watchOS("26.0")
    ],
    products: [
        .library(
            name: "SpotterShared",
            targets: ["SpotterShared"]
        )
    ],
    targets: [
        .target(name: "SpotterShared"),
        .testTarget(
            name: "SpotterSharedTests",
            dependencies: ["SpotterShared"]
        )
    ]
)
