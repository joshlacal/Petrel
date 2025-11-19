// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftGenerator",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "swift-generator",
            targets: ["SwiftGenerator"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/apple/swift-format.git", from: "600.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftGenerator",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftFormat", package: "swift-format"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "SwiftGeneratorTests",
            dependencies: ["SwiftGenerator"]
        ),
    ]
)
