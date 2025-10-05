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
        ),
        .library(
            name: "PicoResponsesSwiftUI",
            targets: ["PicoResponsesSwiftUI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/mattt/EventSource", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "PicoResponsesCore",
            dependencies: [
                .product(name: "EventSource", package: "EventSource")
            ]
        ),
        .target(
            name: "PicoResponsesSwiftUI",
            dependencies: [
                "PicoResponsesCore"
            ]
        ),
        .testTarget(
            name: "PicoResponsesCoreTests",
            dependencies: ["PicoResponsesCore"]
        ),
        .testTarget(
            name: "PicoResponsesSwiftUITests",
            dependencies: ["PicoResponsesSwiftUI"]
        )
    ]
)
