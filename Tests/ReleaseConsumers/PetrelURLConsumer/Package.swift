// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PetrelURLConsumer",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(url: "https://github.com/joshlacal/Petrel.git", exact: "0.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "PetrelURLConsumer",
            dependencies: [
                .product(name: "Petrel", package: "Petrel"),
            ]
        ),
    ]
)
