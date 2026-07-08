// swift-tools-version: 6.1
import PackageDescription

let package = Package(
  name: "petrel-cab-server",
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "petrel-cab-server", targets: ["petrel-cab-server"]),
    .executable(name: "petrel-cab-demo", targets: ["petrel-cab-demo"]),
    .library(name: "PetrelCABServerCore", targets: ["PetrelCABServerCore"]),
  ],
  dependencies: [
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.25.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
    .package(url: "https://github.com/beatt83/jose-swift.git", .upToNextMajor(from: "6.0.0")),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    .package(name: "Petrel", path: ".."),
  ],
  targets: [
    .target(
      name: "PetrelCABServerCore",
      dependencies: [
        .product(name: "Hummingbird", package: "hummingbird"),
        .product(name: "jose-swift", package: "jose-swift"),
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
