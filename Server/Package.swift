// swift-tools-version: 6.1
import PackageDescription

let package = Package(
  name: "petrel-cab-server",
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "petrel-cab-server", targets: ["petrel-cab-server"]),
    .executable(name: "petrel-cab-demo", targets: ["petrel-cab-demo"]),
    .library(name: "PetrelCABServerCore", targets: ["PetrelCABServerCore"]),
    .library(name: "PetrelOAuthServerHummingbird", targets: ["PetrelOAuthServerHummingbird"]),
    .executable(name: "petrel-oauth-server-example", targets: ["petrel-oauth-server-example"]),
  ],
  dependencies: [
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.26.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.15.1"),
    .package(url: "https://github.com/apple/swift-crypto.git", "3.15.1" ..< "6.0.0"),
    // Already in the graph through Hummingbird; named so the pinned transport
    // can use them directly.
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.105.0"),
    .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.37.6"),
    .package(url: "https://github.com/apple/swift-certificates.git", from: "1.21.1"),
    .package(name: "Petrel", path: ".."),
  ],
  targets: [
    .target(
      name: "PetrelCABServerCore",
      dependencies: [
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "PetrelCrypto", package: "Petrel"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
      ],
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
    .executableTarget(
      name: "petrel-cab-server",
      dependencies: [
        "PetrelCABServerCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
    .executableTarget(
      name: "petrel-cab-demo",
      dependencies: [
        "PetrelCABServerCore",
        .product(name: "Petrel", package: "Petrel"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Hummingbird", package: "hummingbird"),
      ],
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
    .target(
      name: "PetrelOAuthServerHummingbird",
      dependencies: [
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "PetrelOAuthServer", package: "Petrel"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOPosix", package: "swift-nio"),
        .product(name: "NIOHTTP1", package: "swift-nio"),
        .product(name: "NIOSSL", package: "swift-nio-ssl"),
      ],
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
    .executableTarget(
      name: "petrel-oauth-server-example",
      dependencies: [
        "PetrelOAuthServerHummingbird",
        .product(name: "PetrelOAuthServer", package: "Petrel"),
        .product(name: "PetrelOAuthServerLexicon", package: "Petrel"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Hummingbird", package: "hummingbird"),
      ],
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
    .testTarget(
      name: "PetrelOAuthServerHummingbirdTests",
      dependencies: [
        "PetrelOAuthServerHummingbird",
        "petrel-oauth-server-example",
        .product(name: "PetrelOAuthServer", package: "Petrel"),
        .product(name: "HummingbirdTesting", package: "hummingbird"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOPosix", package: "swift-nio"),
        .product(name: "NIOHTTP1", package: "swift-nio"),
        .product(name: "NIOSSL", package: "swift-nio-ssl"),
        .product(name: "X509", package: "swift-certificates"),
        .product(name: "Crypto", package: "swift-crypto"),
      ]
    ),
    .testTarget(
      name: "PetrelCABServerCoreTests",
      dependencies: [
        "PetrelCABServerCore",
        .product(name: "HummingbirdTesting", package: "hummingbird"),
      ]
    ),
    .testTarget(
      name: "PetrelCABIntegrationTests",
      dependencies: [
        "PetrelCABServerCore",
        .product(name: "Petrel", package: "Petrel"),
        .product(name: "HummingbirdTesting", package: "hummingbird"),
      ]
    ),
  ]
)
