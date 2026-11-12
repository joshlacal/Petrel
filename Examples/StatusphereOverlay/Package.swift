// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StatusphereOverlay",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "PetrelStatusphere",
            targets: ["PetrelStatusphere"]
        ),
        .executable(
            name: "StatusphereCLI",
            targets: ["StatusphereCLI"]
        ),
    ],
    dependencies: [
        .package(name: "Petrel", path: "../.."),
    ],
    targets: [
        .target(
            name: "PetrelStatusphere",
            dependencies: [
                .product(name: "Petrel", package: "Petrel"),
            ],
            path: "Sources/PetrelStatusphere"
        ),
        .executableTarget(
            name: "StatusphereCLI",
            dependencies: [
                "PetrelStatusphere",
                .product(name: "Petrel", package: "Petrel"),
            ],
            path: "Sources/StatusphereCLI"
        ),
    ]
)
