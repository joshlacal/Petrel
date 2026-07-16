# Getting Started

Learn how to integrate Petrel into your Swift project and make your first API calls.

## Installation

Add Petrel to your Swift package dependencies and target:

<!-- compile-example: package-manifest -->
```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "YourApp",
    dependencies: [
        .package(url: "https://github.com/joshlacal/Petrel.git", from: "0.2.0"),
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: ["Petrel"]
        ),
    ]
)
```

## Basic Setup

Import Petrel and create a client instance:

<!-- compile-example: getting-started-basic -->
```swift
import Petrel

func fetchProfileExample() async throws {
    let client = await ATProtoClient(baseURL: ATProtoClient.defaultBaseURL)
    let actor = try ATIdentifier(string: "alice.bsky.social")
    let result = try await client.app.bsky.actor.getProfile(
        input: .init(actor: actor)
    )
    print("Display name: \(result.data?.displayName ?? "No display name")")
}
```

## Next Steps

- Learn about <doc:Authentication> to access protected endpoints.
