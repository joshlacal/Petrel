// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PostCLIDemo",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(name: "Petrel", path: "../.."), // Petrel library
    ],
    targets: [
        .executableTarget(
            name: "PostCLIDemo",
            dependencies: [
                .product(name: "Petrel", package: "Petrel"),
            ],
            path: "Sources"
        ),
    ]
)
