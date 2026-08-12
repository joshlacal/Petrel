// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PetrelURLConsumer",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        // Placeholder pin. The release workflow's tagged-clean-consumer job copies
        // this package to a scratch directory and rewrites the version to the tag
        // being released, so this literal is never the version under test.
        .package(url: "https://github.com/joshlacal/Petrel.git", exact: "0.0.0"),
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
