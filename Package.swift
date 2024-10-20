// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Petrel",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "Petrel",
            targets: ["Petrel"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/michaeleisel/ZippyJSON.git", from: "1.2.15"),
        .package(url: "https://github.com/beatt83/jose-swift.git", .upToNextMajor(from: "4.0.0")),
    ],
    targets: [
        .target(
            name: "Petrel",
            dependencies: [
                "jose-swift",
                .product(name: "ZippyJSON", package: "ZippyJSON"),
            ]
        ),
        .testTarget(
            name: "PetrelTests",
            dependencies: ["Petrel"]
        ),
    ]
)
