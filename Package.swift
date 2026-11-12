// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Petrel",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
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
        .library(
            name: "PetrelPLCPDS",
            targets: ["PetrelPLCPDS"]
        ),
        .library(
            name: "PetrelJetstream",
            targets: ["PetrelJetstream"]
        ),
        .library(
            name: "PetrelOAuthScopes",
            targets: ["PetrelOAuthScopes"]
        ),
        .library(
            name: "PetrelOAuthServer",
            targets: ["PetrelOAuthServer"]
        ),
        .library(
            name: "PetrelOzone",
            targets: ["PetrelOzone"]
        ),
        .library(
            name: "PetrelLexicon",
            targets: ["PetrelLexicon"]
        ),
        .executable(
            name: "PetrelLoad",
            targets: ["PetrelLoad"]
        ),
        // `swift package petrel-lexgen`: generate Swift types from your own lexicons.
        .plugin(
            name: "PetrelLexgen",
            targets: ["PetrelLexgen"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/valpackett/SwiftCBOR.git", .upToNextMinor(from: "0.6.0")),
        .package(
            url: "https://github.com/apple/swift-async-dns-resolver",
            .upToNextMinor(from: "0.7.0")
        ),
        .package(url: "https://github.com/apple/swift-crypto.git", .upToNextMajor(from: "3.0.0")),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.5"),
        // 0.x: every minor may change API, so the range stops at the next
        // minor. Only Sources/PetrelCrypto/K256Backend.swift uses the module.
        .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1.git", .upToNextMinor(from: "0.24.0")),
        // Pinned to 1.5.7: release tag ships Package.swift with the `libzstd` product.
        .package(url: "https://github.com/facebook/zstd.git", .upToNextMinor(from: "1.5.7")),
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
            name: "CPetrelBLAKE3",
            exclude: ["README.md", "LICENSE_CC0", "LICENSE_A2LLVM", "LICENSE_A2"],
            publicHeadersPath: "include",
            cSettings: [
                .define("BLAKE3_NO_SSE2"), .define("BLAKE3_NO_SSE41"),
                .define("BLAKE3_NO_AVX2"), .define("BLAKE3_NO_AVX512"),
                .define("BLAKE3_USE_NEON", to: "0"),
            ]
        ),
        .target(
            name: "PetrelCrypto",
            dependencies: [
                "CPetrelBLAKE3",
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "P256K", package: "swift-secp256k1"),
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
                "PetrelOAuthScopes",
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
            name: "PetrelJetstream",
            dependencies: [
                "Petrel",
                "PetrelCore",
                "PetrelFirehose",
                "SwiftCBOR",
                .product(name: "libzstd", package: "zstd"),
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
        .target(
            name: "PetrelOAuthScopes",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "PetrelOAuthServer",
            dependencies: [
                "PetrelOAuthScopes",
                "PetrelCrypto",
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "PetrelPLCPDS",
            dependencies: [
                "Petrel",
                "PetrelPLC",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        // The tools.ozone lexicons, generated as an overlay on Petrel
        // (generator/manifests/petrel-ozone.json).
        .target(
            name: "PetrelOzone",
            dependencies: ["Petrel"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "PetrelLexicon",
            dependencies: [
                "Petrel",
                "PetrelCore",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .executableTarget(
            name: "PetrelLoad",
            dependencies: ["Petrel"]
        ),
        // Compiled example for the event-stream consumers: `swift run FirehoseDemo`.
        .executableTarget(
            name: "FirehoseDemo",
            dependencies: ["Petrel", "PetrelFirehose", "PetrelJetstream"],
            path: "Examples",
            exclude: ["README.md", "SimplePostCLI.swift", "PostCLIDemo"],
            sources: ["FirehoseDemo.swift"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .plugin(
            name: "PetrelLexgen",
            capability: .command(
                intent: .custom(
                    verb: "petrel-lexgen",
                    description: "Generate Swift types and XRPC calls from Lexicon JSON files"
                ),
                permissions: [
                    .writeToPackageDirectory(
                        reason: "Writes the generated Swift sources into the output directory the manifest names"
                    ),
                    .allowNetworkConnections(
                        scope: .all(ports: [443]),
                        reason: "Installs the generator's Python dependencies from PyPI on first use"
                    ),
                ]
            )
        ),
        .testTarget(
            name: "PetrelTests",
            dependencies: ["Petrel", "PetrelCrypto"],
            resources: [.copy("Vectors")]
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
        // Test support only (not a product): a loopback WebSocket server on a real socket and an
        // independent DAG-CBOR fixture encoder, shared by the two streaming test targets.
        .target(
            name: "PetrelStreamingTestSupport",
            dependencies: [
                "PetrelFirehose",
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Tests/PetrelStreamingTestSupport",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "PetrelFirehoseTests",
            dependencies: ["PetrelFirehose", "PetrelRepo", "PetrelStreamingTestSupport"],
            resources: [.copy("Vectors")]
        ),
        .testTarget(
            name: "PetrelJetstreamTests",
            dependencies: ["PetrelJetstream", "PetrelFirehose", "PetrelStreamingTestSupport"]
        ),
        .testTarget(
            name: "PetrelPLCTests",
            dependencies: ["PetrelPLC", "PetrelPLCPDS", "Petrel", "PetrelCrypto", "PetrelCore"],
            resources: [.copy("Vectors")]
        ),
        .testTarget(
            name: "PetrelOAuthScopesTests",
            dependencies: ["PetrelOAuthScopes"],
            exclude: ["UpstreamGoldens"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "PetrelOAuthServerTests",
            dependencies: [
                "PetrelOAuthServer",
                "PetrelCrypto",
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
        .testTarget(
            name: "PetrelLexiconTests",
            dependencies: ["PetrelLexicon", "Petrel", "PetrelCore"],
            resources: [.copy("Vectors")]
        ),
        .testTarget(
            name: "PetrelLoadTests",
            dependencies: ["PetrelLoad"]
        ),
        // A module generated from third-party lexicons with the overlay manifest in
        // Tests/LexiconFixture/lexgen.json. It is not a product: it exists so that every
        // build and test run compiles generator output for lexicons Petrel does not ship.
        // Its test target also covers PetrelOzone, the overlay module that is a product.
        .target(
            name: "PetrelLexiconFixture",
            dependencies: ["Petrel"],
            path: "Tests/LexiconFixture/Generated",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "PetrelLexiconFixtureTests",
            dependencies: ["PetrelLexiconFixture", "PetrelOzone", "Petrel"],
            resources: [.copy("Vectors")]
        ),
    ]
)
