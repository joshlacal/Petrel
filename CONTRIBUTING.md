# Contributing to Petrel

Petrel is a Swift 6 SDK for the AT Protocol (Authenticated Transfer Protocol). This guide covers building the project, running tests, modifying lexicons, working with the code generator, and preparing changes for review.

## Prerequisites

- **Swift**: Swift 6.0 toolchain or later (macOS 15+, iOS 18+, or Linux).
- **Python**: Python 3.12+ for code generation.
- **SwiftFormat**: `swiftformat` for formatting generated and hand-written Swift sources.

## Building and testing

To build the library and executables:

```bash
swift build
```

To run the test suite:

```bash
swift test
```

To run a specific test suite or test case:

```bash
swift test --filter ATProtoClientSimpleTests
```

To generate and preview local DocC API documentation:

```bash
swift package generate-documentation
```

## Generated code and architecture boundary

Petrel separates hand-written runtime architecture from schema-generated models and client endpoints.

- **Hand-written sources** live in `Sources/Petrel/` outside `Generated/` (such as `Auth/`, `Core/`, `Storage/`, and `Types/`). These files contain the networking transport, authentication state machines, token lifecycle, DPoP key management, and secure storage adapters.
- **Generated sources** live in `Sources/Petrel/Generated/`. These files are generated from AT Protocol Lexicon JSON definitions.

**Never edit files in `Sources/Petrel/Generated/` directly.** Hand-written edits to generated files will be overwritten on subsequent generator runs and will cause schema desynchronization. If a generated type or method needs changes:

1. Update the Lexicon JSON schema in `generator/lexicons/`, or
2. Update the generator template or Python generation logic in `generator/`.

## Code generation workflow

Petrel uses a manifest-driven generator written in Python. The canonical manifest is `generator/manifests/petrel-core.json`.

### Setting up the generator environment

Set up a Python virtual environment with development dependencies:

```bash
python3 -m venv .build/generator-dev
.build/generator-dev/bin/pip install -r generator/requirements.txt
```

To run the generator test suite:

```bash
.build/generator-dev/bin/python -m unittest discover -s generator/tests -v
```

### Regenerating Swift sources

To project Swift sources from the manifest:

```bash
.build/generator-dev/bin/python run.py \
    --manifest generator/manifests/petrel-core.json \
    --language swift
```

To project both Swift and Kotlin sources:

```bash
.build/generator-dev/bin/python run.py \
    --manifest generator/manifests/petrel-core.json \
    --language both
```

### Formatting generated code

After code generation, you must run SwiftFormat over the generated sources:

```bash
swiftformat Sources/Petrel/Generated
```

In automated release environments, `Scripts/regenerate-generated.sh` runs the generator and applies the pinned SwiftFormat version.

## Adding or updating a lexicon

To add a new lexicon or update an existing lexicon:

1. Place or update the Lexicon JSON definition under `generator/lexicons/` in a directory hierarchy matching its NSID (for example, `generator/lexicons/app/bsky/feed/getPostThread.json`).
2. Verify that the namespace is not excluded in `generator/manifests/petrel-core.json`.
3. Run the generator for Swift (or both languages).
4. Run `swiftformat Sources/Petrel/Generated`.
5. Run `swift build` and `swift test` to confirm compilation and test pass.
6. Commit the lexicon JSON file alongside the updated generated Swift files in `Sources/Petrel/Generated/`.

## Code style

Petrel uses SwiftFormat with the settings defined in `.swiftformat`:

- **Indentation**: 4 spaces (`--indent 4`, `--tabwidth 4`).
- **Argument wrapping**: Wrap arguments before the first argument (`--wraparguments before-first`).
- **Collection wrapping**: Wrap collections before the first element (`--wrapcollections before-first`).
- **Unused arguments**: Strip unused closure argument names (`--stripunusedargs closure-only`).

General Swift guidelines:

- Write Swift 6 compliant code with complete concurrency safety.
- Model types using `Sendable`, actors, and immutable value semantics where appropriate.
- Use explicit types for domain primitives: `ATIdentifier`, `DID`, `Handle`, `CID`, `URI`, `ATProtocolURI`, `ATProtocolDate`, and `NSID`.
- Handle errors with typed errors or thrown `KeychainError` / `NetworkError` instances rather than generic error wrappers.

## Writing tests

Test files reside in `Tests/PetrelTests/`. Petrel supports both Swift Testing (`import Testing`) and XCTest (`import XCTest`).

When writing tests:

- Use `@Suite` and `@Test` for new Swift Testing suites.
- Test async methods using `async throws` test functions.
- Verify both success paths and expected error throws using `#expect(throws:)`.

Example test structure using Swift Testing:

```swift
import Foundation
@testable import Petrel
import Testing

@Suite("Profile Retrieval Tests")
struct ProfileRetrievalTests {
    @Test("Unauthenticated client fetches public profile")
    func fetchPublicProfile() async throws {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)
        let actor = try ATIdentifier(string: "atproto.com")
        let (responseCode, profile) = try await client.app.bsky.actor.getProfile(
            input: AppBskyActorGetProfile.Parameters(actor: actor)
        )

        #expect(responseCode == 200)
        #expect(profile?.handle.description == "atproto.com")
    }

    @Test("Authenticated client initializes with OAuth config")
    func clientInitialization() async throws {
        let oauthConfig = OAuthConfig(
            clientId: "https://example.com/client-metadata.json",
            redirectUri: "https://example.com/callback",
            scope: "atproto transition:generic"
        )
        let client = try await ATProtoClient(
            oauthConfig: oauthConfig,
            namespace: "test-namespace"
        )

        let app = await client.app
        let com = await client.com
        let chat = await client.chat
        _ = (app, com, chat)
    }
}
```

## Submitting changes

Before opening a pull request:

1. Ensure all tests pass: `swift test`.
2. Ensure generator unit tests pass: `python3 -m unittest discover -s generator/tests -v`.
3. If you modified lexicons or generator templates, ensure the generated code is regenerated and formatted:
   ```bash
   python3 run.py --manifest generator/manifests/petrel-core.json --language swift
   swiftformat Sources/Petrel/Generated
   ```
4. Confirm that `git diff` shows no unintended formatting changes or stray files.
5. Provide a clear PR description explaining the motivation, changes made, and test commands executed.
