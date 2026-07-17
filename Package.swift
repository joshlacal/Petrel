// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Petrel",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "Petrel",
            targets: ["Petrel"]
        ),
        .executable(
            name: "PetrelLoad",
            targets: ["PetrelLoad"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/beatt83/jose-swift.git", .upToNextMajor(from: "6.0.0")),
        .package(url: "https://github.com/valpackett/SwiftCBOR.git", .upToNextMinor(from: "0.6.0")),
        .package(
            url: "https://github.com/apple/swift-async-dns-resolver",
            .upToNextMinor(from: "0.7.0")
        ),
        .package(url: "https://github.com/apple/swift-crypto.git", .upToNextMajor(from: "3.0.0")),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.5"),
    ],
    targets: [
        // System library for libsecret (Linux only, ignored on other platforms)
        .systemLibrary(
            name: "CLibSecret",
            pkgConfig: "libsecret-1",
            providers: [
                .apt(["libsecret-1-dev", "libglib2.0-dev", "pkg-config"]),
                .yum(["libsecret-devel", "glib2-devel", "pkg-config"]),
            ]
        ),
        .target(
            name: "CLibSecretShim",
            dependencies: ["CLibSecret"],
            publicHeadersPath: "."
        ),

        .target(
            name: "Petrel",
            dependencies: [
                "jose-swift",
                "SwiftCBOR",
                .product(name: "AsyncDNSResolver", package: "swift-async-dns-resolver"),
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
                .product(name: "Logging", package: "swift-log"),
                .target(name: "CLibSecretShim", condition: .when(platforms: [.linux])),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .executableTarget(
            name: "PetrelLoad",
            dependencies: ["Petrel"]
        ),
        .testTarget(
            name: "PetrelTests",
            dependencies: ["Petrel"]
        ),
        .testTarget(
            name: "PetrelLoadTests",
            dependencies: ["PetrelLoad"]
        ),
    ]
)
