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
        // Authenticated Lexicon resolution for `include:` permission sets
        // (DNS → DID → com.atproto.sync.getRecord → repository proof).
        .library(
            name: "PetrelOAuthServerLexicon",
            targets: ["PetrelOAuthServerLexicon"]
        ),
        // Needs the OAuthServerNIO trait; without it the module's types are
        // declared unavailable and none of its dependencies build.
        .library(
            name: "PetrelOAuthServerNIO",
            targets: ["PetrelOAuthServerNIO"]
        ),
        // Needs the OAuthServerHummingbird trait (which enables OAuthServerNIO);
        // without it the module's types are declared unavailable and none of its
        // dependencies build.
        .library(
            name: "PetrelOAuthServerHummingbird",
            targets: ["PetrelOAuthServerHummingbird"]
        ),
        .library(
            name: "PetrelOzone",
            targets: ["PetrelOzone"]
        ),
        .library(
            name: "PetrelLexicon",
            targets: ["PetrelLexicon"]
        ),
        // `swift package petrel-lexgen`: generate Swift types from your own lexicons.
        .plugin(
            name: "PetrelLexgen",
            targets: ["PetrelLexgen"]
        ),
    ],
    traits: [
        .trait(
            name: "OAuthServerNIO",
            description: """
            Builds PetrelOAuthServerNIO, the pinned SwiftNIO transport that PetrelOAuthServer's \
            remote document fetcher requires, for any server framework. Brings in swift-nio and \
            swift-nio-ssl.
            """
        ),
        .trait(
            name: "OAuthServerHummingbird",
            description: """
            Builds PetrelOAuthServerHummingbird, the Hummingbird adapter for PetrelOAuthServer, \
            and enables OAuthServerNIO. Brings in hummingbird, swift-nio and swift-nio-ssl.
            """,
            enabledTraits: ["OAuthServerNIO"]
        ),
        .default(enabledTraits: []),
    ],
    dependencies: [
        .package(url: "https://github.com/valpackett/SwiftCBOR.git", .upToNextMinor(from: "0.6.0")),
        .package(
            url: "https://github.com/apple/swift-async-dns-resolver",
            .upToNextMinor(from: "0.8.1")
        ),
        // 3.15.1 is the lowest release tested and the version a sibling consumer
        // pins exactly. 5.x declares swift-tools-version 6.2, so the
        // committed pin is 4.5.2, the newest release the 6.1 floor resolves.
        .package(url: "https://github.com/apple/swift-crypto.git", "3.15.1" ..< "6.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.15.1")),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0"),
        // 0.x: every minor may change API, so the range stops at the next
        // minor. Only Sources/PetrelCrypto/K256Backend.swift uses the module.
        .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1.git", .upToNextMinor(from: "0.25.0")),
        // Pinned to 1.5.7: release tag ships Package.swift with the `libzstd` product.
        .package(url: "https://github.com/facebook/zstd.git", .upToNextMinor(from: "1.5.7")),
        // Used only with the OAuthServerNIO and OAuthServerHummingbird traits
        // (see the PetrelOAuthServerNIO and PetrelOAuthServerHummingbird
        // targets). Swift 6.2 and later do not fetch them when the traits are
        // off; Swift 6.1 fetches them but builds nothing from them.
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.26.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.105.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.37.6"),
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
            name: "PetrelOAuthServerLexicon",
            dependencies: [
                "Petrel",
                "PetrelCrypto",
                "PetrelLexicon",
                "PetrelOAuthScopes",
                "PetrelOAuthServer",
                "PetrelRepo",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "PetrelOAuthServerNIO",
            dependencies: [
                "PetrelOAuthServer",
                .product(name: "NIOCore", package: "swift-nio", condition: .when(traits: ["OAuthServerNIO"])),
                .product(name: "NIOPosix", package: "swift-nio", condition: .when(traits: ["OAuthServerNIO"])),
                .product(name: "NIOHTTP1", package: "swift-nio", condition: .when(traits: ["OAuthServerNIO"])),
                .product(name: "NIOSSL", package: "swift-nio-ssl", condition: .when(traits: ["OAuthServerNIO"])),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "PetrelOAuthServerHummingbird",
            dependencies: [
                "PetrelOAuthServer",
                "PetrelOAuthServerNIO",
                .product(name: "Hummingbird", package: "hummingbird", condition: .when(traits: ["OAuthServerHummingbird"])),
                .product(name: "NIOCore", package: "swift-nio", condition: .when(traits: ["OAuthServerHummingbird"])),
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
            dependencies: ["Petrel", "PetrelCrypto", .product(name: "Logging", package: "swift-log")],
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
            dependencies: ["PetrelRepo", "PetrelRepoTestSupport"],
            resources: [.copy("Vectors")]
        ),
        // Test support only (not a product): builds repository proof CARs, valid and
        // deliberately broken, for the PetrelRepo and authenticated Lexicon resolver tests.
        .target(
            name: "PetrelRepoTestSupport",
            dependencies: [
                "Petrel",
                "PetrelCrypto",
                "PetrelRepo",
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Tests/PetrelRepoTestSupport",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
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
                "PetrelOAuthServerLexicon",
                "PetrelCrypto",
                "PetrelRepo",
                "PetrelRepoTestSupport",
                "Petrel",
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
