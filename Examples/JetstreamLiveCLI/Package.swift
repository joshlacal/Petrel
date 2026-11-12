// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "JetstreamLiveCLI",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(
            name: "JetstreamLiveCLI",
            targets: ["JetstreamLiveCLI"]
        ),
    ],
    dependencies: [
        .package(name: "Petrel", path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "JetstreamLiveCLI",
            dependencies: [
                .product(name: "Petrel", package: "Petrel"),
                .product(name: "PetrelJetstream", package: "Petrel"),
                .product(name: "PetrelFirehose", package: "Petrel"),
            ],
            path: "Sources/JetstreamLiveCLI"
        ),
    ]
)
