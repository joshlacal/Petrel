// swift-tools-version: 6.0
// Release-mode differential harness for the leaf-scanner fast paths (no latency
// timing): exhaustive + fuzz equivalence against verbatim legacy copies, official
// atproto syntax vectors, fixture fast-path coverage, and instruction counts.
import PackageDescription

let package = Package(
    name: "LeafEquiv",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(name: "Petrel", path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "LeafEquiv",
            dependencies: [
                .product(name: "Petrel", package: "Petrel"),
                .product(name: "PetrelCore", package: "Petrel"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)] // top-level harness globals; the library under test builds in Swift 6 mode
        ),
    ]
)
