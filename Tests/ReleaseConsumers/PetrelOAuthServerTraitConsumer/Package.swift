// swift-tools-version: 6.1

import PackageDescription

// A server that depends on Petrel by URL with a package trait, the way the
// OAuth server guide tells users to. Scripts/tests/oauth-server-traits-contract.sh
// copies it to a scratch directory, points the URL and version at a snapshot of
// the commit under test, and swaps the trait list for each case it checks.
let package = Package(
    name: "PetrelOAuthServerTraitConsumer",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(url: "https://github.com/joshlacal/Petrel.git", exact: "0.0.0", traits: ["OAuthServerNIO"]),
    ],
    targets: [
        .executableTarget(
            name: "PetrelOAuthServerTraitConsumer",
            dependencies: [
                .product(name: "PetrelOAuthServer", package: "Petrel"),
                .product(name: "PetrelOAuthServerLexicon", package: "Petrel"),
                .product(name: "PetrelOAuthServerNIO", package: "Petrel"),
                // Without OAuthServerHummingbird this module holds only the
                // stubs that name the trait; the contract checks both.
                .product(name: "PetrelOAuthServerHummingbird", package: "Petrel"),
            ]
        ),
    ]
)
