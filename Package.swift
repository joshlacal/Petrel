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
        .package(url: "https://github.com/beatt83/jose-swift.git", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/valpackett/SwiftCBOR.git", branch: "master"),
        .package(
            url: "https://github.com/apple/swift-async-dns-resolver",
            .upToNextMajor(from: "0.1.0")
        ),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "Petrel",
            dependencies: [
                "jose-swift",
                "SwiftCBOR",
                .product(name: "AsyncDNSResolver", package: "swift-async-dns-resolver"),
            ]
        ),
        .testTarget(
            name: "PetrelTests",
            dependencies: ["Petrel"]
        ),
    ]
)
