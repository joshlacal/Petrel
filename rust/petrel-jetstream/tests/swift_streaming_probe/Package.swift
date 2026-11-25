// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "petrel-swift-stream-probe",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "petrel-swift-stream-probe", targets: ["petrel-swift-stream-probe"])
    ],
    dependencies: [
        .package(name: "Petrel", path: "../../../.."),
        .package(url: "https://github.com/apple/swift-crypto.git", "3.15.1" ..< "6.0.0"),
        .package(url: "https://github.com/facebook/zstd.git", .upToNextMinor(from: "1.5.7")),
    ],
    targets: [
        .executableTarget(
            name: "petrel-swift-stream-probe",
            dependencies: [
                .product(name: "Petrel", package: "Petrel"),
                .product(name: "PetrelFirehose", package: "Petrel"),
                .product(name: "PetrelJetstream", package: "Petrel"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "libzstd", package: "zstd"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
