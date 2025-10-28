// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PostCLIDemo",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../..")  // Petrel library
    ],
    targets: [
        .executableTarget(
            name: "PostCLIDemo",
            dependencies: [
                .product(name: "Petrel", package: "Petrel")
            ],
            path: "Sources"
        )
    ]
)
