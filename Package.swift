// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Petrel",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Petrel",
            targets: ["Petrel"]),
    ],
    dependencies: [
        .package(url: "https://github.com/michaeleisel/ZippyJSON.git", from: "1.2.15"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "4.13.4")
    ],
    targets: [
        .target(
            name: "Petrel",
            dependencies: [
                .product(name: "ZippyJSON", package: "ZippyJSON"),
                .product(name: "JWTKit", package: "jwt-kit")
            ]
        ),
        .testTarget(
            name: "PetrelTests",
            dependencies: ["Petrel"]
        )
    ]
)
