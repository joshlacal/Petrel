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
        .library(
            name: "PetrelCore",
            targets: ["PetrelCore"]
        ),
        .library(
            name: "PetrelCrypto",
            targets: ["PetrelCrypto"]
        ),
        .library(
            name: "PetrelRepo",
            targets: ["PetrelRepo"]
        ),
        .library(
            name: "PetrelFirehose",
            targets: ["PetrelFirehose"]
        ),
        .library(
            name: "PetrelPLC",
            targets: ["PetrelPLC"]
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
        .package(url: "https://github.com/GigaBitcoin/secp256k1.swift.git", exact: "0.15.0"),
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
            name: "PetrelCrypto",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "secp256k1", package: "secp256k1.swift"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "PetrelCore",
            dependencies: [
                "PetrelCrypto",
                "SwiftCBOR",
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "Petrel",
            dependencies: [
                "PetrelCore",
                "PetrelCrypto",
                "jose-swift",
                "SwiftCBOR",
                .product(name: "AsyncDNSResolver", package: "swift-async-dns-resolver"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Logging", package: "swift-log"),
                .target(name: "CLibSecretShim", condition: .when(platforms: [.linux])),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "PetrelRepo",
            dependencies: [
                "Petrel",
                "PetrelCrypto",
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "PetrelFirehose",
            dependencies: [
                "Petrel",
                "PetrelCrypto",
                "PetrelRepo",
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "PetrelPLC",
            dependencies: [
                "PetrelCore",
                "PetrelCrypto",
                .product(name: "Crypto", package: "swift-crypto"),
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
            dependencies: ["Petrel", "PetrelCrypto"]
        ),
        .testTarget(
            name: "PetrelCryptoTests",
            dependencies: ["PetrelCrypto"]
        ),
        .testTarget(
            name: "PetrelCoreTests",
            dependencies: ["PetrelCore", "PetrelCrypto"]
        ),
        .testTarget(
            name: "PetrelRepoTests",
            dependencies: ["PetrelRepo"]
        ),
        .testTarget(
            name: "PetrelFirehoseTests",
            dependencies: ["PetrelFirehose", "PetrelRepo"]
        ),
        .testTarget(
            name: "PetrelPLCTests",
            dependencies: ["PetrelPLC", "PetrelCrypto", "PetrelCore"]
        ),
        .testTarget(
            name: "PetrelLoadTests",
            dependencies: ["PetrelLoad"]
        ),
    ]
)
