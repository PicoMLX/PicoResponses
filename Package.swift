// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PicoResponses",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PicoResponsesCore",
            targets: ["PicoResponsesCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PicoResponsesCore",
            dependencies: []
        ),
        .testTarget(
            name: "PicoResponsesCoreTests",
            dependencies: ["PicoResponsesCore"]
        )
    ]
)
