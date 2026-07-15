// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PetrelTwoOverlayConsumer",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "../Petrel"),
        .package(path: "../PetrelCatbird"),
        .package(path: "../PetrelBluemoji"),
    ],
    targets: [
        .executableTarget(
            name: "PetrelTwoOverlayConsumer",
            dependencies: [
                .product(name: "Petrel", package: "Petrel"),
                .product(name: "PetrelCatbird", package: "PetrelCatbird"),
                .product(name: "PetrelBluemoji", package: "PetrelBluemoji"),
            ]
        )
    ]
)
