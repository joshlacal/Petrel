// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LoopbackOAuthSwiftUI",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "LoopbackOAuthFeature",
            targets: ["LoopbackOAuthFeature"]
        ),
        .executable(
            name: "LoopbackOAuthSwiftUI",
            targets: ["LoopbackOAuthSwiftUI"]
        ),
    ],
    dependencies: [
        .package(name: "Petrel", path: "../.."),
    ],
    targets: [
        .target(
            name: "LoopbackOAuthFeature",
            dependencies: [
                .product(name: "Petrel", package: "Petrel"),
            ],
            path: "Sources/LoopbackOAuthFeature"
        ),
        .executableTarget(
            name: "LoopbackOAuthSwiftUI",
            dependencies: [
                "LoopbackOAuthFeature",
                .product(name: "Petrel", package: "Petrel"),
            ],
            path: "Sources/LoopbackOAuthSwiftUI"
        ),
        .testTarget(
            name: "LoopbackOAuthFeatureTests",
            dependencies: [
                "LoopbackOAuthFeature",
            ],
            path: "Tests/LoopbackOAuthFeatureTests"
        ),
    ]
)
