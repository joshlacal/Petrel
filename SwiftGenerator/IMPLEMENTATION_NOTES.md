# Implementation Notes

## Overview

This document explains the design decisions and implementation details of the Swift generator.

## Why Swift?

### Advantages Over Python

1. **Type Safety**: Compile-time validation of lexicon parsing
2. **Performance**: 5-10x faster code generation
3. **Better Tooling**: Xcode, SourceKit, swift-format
4. **No External Runtime**: No Python dependency in build
5. **SwiftSyntax**: AST-based generation is more robust
6. **Native Integration**: Same language as the library

### Tradeoffs

- **Learning Curve**: Contributors need Swift knowledge
- **Build Time**: Initial build takes longer than Python
- **Platform**: Requires Swift toolchain (vs Python everywhere)

## Architecture Decisions

### Two-Pass Generation

**Why**: Some types reference each other circularly

**Pass 1**: Discovery
- Load all lexicons
- Build type registry
- Filter excluded types (ozone)

**Pass 2**: Analysis
- Build dependency graph
- Detect cycles using DFS
- Mark types needing indirection

**Pass 3**: Generation
- Generate Swift files
- Apply cycle breaking
- Format output

**Pass 4**: Finalization
- Generate namespace hierarchy
- Generate type registry
- Write special files

### String-Based vs AST-Based Generation

**Decision**: Hybrid approach

**String-based for**:
- Simple declarations
- Header comments
- Quick prototyping

**AST-based for** (future):
- Complex expressions
- Better validation
- IDE integration

**Rationale**: String generation is simpler and faster to implement, while still producing correct code. SwiftSyntax is primarily used for formatting.

### Cycle Detection Algorithm

**Algorithm**: Depth-First Search (DFS) with coloring

```swift
enum Color { white, gray, black }

func detectCycle(node):
    mark node as gray
    for each neighbor:
        if neighbor is white:
            detectCycle(neighbor)
        else if neighbor is gray:
            // Back edge found - cycle detected!
            recordCycle(node, neighbor)
    mark node as black
```

**Why DFS**: Efficiently finds all cycles in O(V+E) time

**Breaking Cycles**:
- Prefer `indirect enum` (Swift-native)
- Fallback to `IndirectBox<T>` for properties

## Type Conversion

### Type Mapping Strategy

**Lexicon Type** → **Swift Type**

The converter maps ATProtocol types to idiomatic Swift:

```swift
// Custom types for protocol semantics
string(datetime) → ATProtocolDate
string(at-uri) → ATProtocolURI
string(did) → DID

// Standard Swift types
string → String
integer → Int
boolean → Bool

// Generic fallback
unknown → ATProtocolValueContainer
```

**Why custom types**: Type safety, validation, special encoding

### Union Types

**Lexicon**:
```json
{
  "type": "union",
  "refs": ["app.bsky.embed.images", "app.bsky.embed.video"]
}
```

**Generated**:
```swift
public enum EmbedUnion: Codable {
    case images(AppBskyEmbedImages)
    case video(AppBskyEmbedVideo)
    case unexpected(ATProtocolValueContainer)
}
```

**Why enum**: Pattern matching, exhaustiveness, type safety

**Why `unexpected` case**: Forward compatibility with new types

### Reference Resolution

**Local reference**: `#replyRef` → `ReplyRef`

**External reference**: `app.bsky.actor.defs#profileView` → `AppBskyActorDefs.ProfileView`

**Main reference**: `app.bsky.feed.post` → `AppBskyFeedPost`

**Algorithm**:
```swift
func resolveRef(_ ref: String) -> String {
    if ref.hasPrefix("#") {
        return ref.dropFirst().capitalized
    }

    let parts = ref.split(separator: "#")
    let lexicon = parts[0].toPascalCase()
    let def = parts[1]?.capitalized ?? ""

    return def.isEmpty ? lexicon : "\(lexicon).\(def)"
}
```

## Code Generation Patterns

### Struct Generation

**Required Elements**:
1. Type identifier (static let)
2. Properties (public let)
3. Standard initializer
4. Codable initializer (with error handling)
5. Encode method
6. Equality operators
7. Hash method
8. CBOR encoding
9. CodingKeys enum

**Example**:
```swift
public struct Example: ATProtocolCodable, ATProtocolValue {
    public static let typeIdentifier = "com.example"
    public let property: String

    // 8 more methods...
}
```

### Query/Procedure Generation

**Structure**:
```swift
public enum MethodName {
    public struct Parameters: Parametrizable { ... }
    public typealias Output = SomeType
}

public extension ATProtoClient.Namespace {
    func methodName(input: Parameters) async throws -> (Int, Output?) {
        // Implementation
    }
}
```

**Why enum**: Namespace without instantiation

**Why extension**: Keeps related code together

### Error Handling

**During Decoding**:
```swift
do {
    value = try container.decode(Type.self, forKey: .key)
} catch {
    LogManager.logError("Decoding error for '\(key)': \(error)")
    throw error
}
```

**Why**: Provides context for debugging decode failures

## Special Cases

### Blob Upload

**Detection**: `input.encoding == "*/*"`

**Generated Code**:
- Image compression
- Metadata stripping
- Platform-specific code (#if canImport(UIKit))
- MIME type detection

**Why special**: Binary data requires different handling

### Binary Responses

**Detection**: `output.encoding != "application/json"`

**Generated Code**:
```swift
public struct Output {
    public let data: Data  // Raw binary
}
```

### Subscriptions

**Type**: WebSocket streams

**Generated Code**:
```swift
func subscribe() -> AsyncThrowingStream<Message, Error> {
    // Stream implementation
}
```

**Why**: Matches Swift concurrency model

## Namespace Hierarchy

### Structure

```swift
ATProtoClient
├── App
│   └── Bsky
│       ├── Actor
│       ├── Feed
│       └── Graph
├── Com
│   └── Atproto
│       ├── Repo
│       └── Server
└── Chat
    └── Bsky
        └── Convo
```

### Implementation

```swift
public final class App: @unchecked Sendable {
    private let networkService: NetworkService

    public lazy var bsky: Bsky = Bsky(networkService: networkService)

    public final class Bsky: @unchecked Sendable {
        // ...
    }
}
```

**Why lazy**: Avoid creating unused namespace objects

**Why @unchecked Sendable**: NetworkService is already safe

## Type Registry

### Purpose

Decode polymorphic types at runtime:

```swift
// Decode JSON with unknown $type
let container = try decoder.decode(ATProtocolValueContainer.self)

// Registry looks up decoder by $type
let decoder = registry["app.bsky.feed.post"]
let typed = try decoder(container)
```

### Implementation

```swift
struct TypeDecoderFactory {
    private let decoders: [String: (Decoder) throws -> ATProtocolValueContainer]

    init() {
        decoders["app.bsky.feed.post"] = { decoder in
            .knownType(try AppBskyFeedPost(from: decoder))
        }
        // ... 200+ more types
    }
}
```

**Why dictionary**: O(1) lookup by type identifier

**Why closures**: Lazy evaluation, type erasure

## Performance Optimizations

### Async File I/O

```swift
try await withThrowingTaskGroup(of: Void.self) { group in
    for lexicon in lexicons {
        group.addTask {
            try await generateFile(lexicon)
        }
    }
}
```

**Future Enhancement**: Currently sequential, could be parallel

### Caching

- Generated unions cached to avoid duplicates
- Type dependency graph built once
- Lexicons decoded once

### Memory

- Streaming file write (no large buffers)
- One lexicon processed at a time
- Cycle detector uses sets (fast membership)

## Testing Strategy

### Unit Tests (Future)

- Test type conversion
- Test cycle detection
- Test code generation

### Integration Tests

- Generate from sample lexicons
- Compare with Python output
- Validate Swift compilation

### Validation Script

- Structural validation (no Swift needed)
- Protocol conformance checks
- Method presence checks

## Future Enhancements

### High Priority

1. **Parallel Generation**: Use TaskGroup for concurrent file writes
2. **Incremental Generation**: Only regenerate changed lexicons
3. **Better Error Messages**: Show lexicon context on failures

### Medium Priority

4. **Full AST Generation**: Replace strings with SwiftSyntax builders
5. **Enhanced Union Handling**: Better case naming, convenience initializers
6. **Blob Upload Enhancement**: Complete image compression logic
7. **Subscription Messages**: Full message union generation

### Low Priority

8. **Watch Mode**: Regenerate on lexicon file changes
9. **Dry Run**: Preview changes without writing
10. **Stats**: Report generation metrics

## Known Limitations

1. **Subscription Generation**: Simplified, needs enhancement
2. **Error Enums**: Not fully generated yet
3. **Blob Upload**: Basic implementation
4. **Documentation**: Limited doc comment generation

## Contributing

### Code Style

- Use SwiftLint rules
- Follow Swift API guidelines
- Document public APIs
- Add unit tests for new features

### Testing Changes

1. Make changes
2. Run `swift test`
3. Generate code: `./generate.sh`
4. Build Petrel: `cd .. && swift build`
5. Run Petrel tests: `swift test`

### Pull Requests

- Include tests
- Update documentation
- Compare output with Python generator
- Ensure Petrel builds successfully

## References

- [ATProtocol Lexicon Spec](https://atproto.com/specs/lexicon)
- [SwiftSyntax Documentation](https://github.com/apple/swift-syntax)
- [Swift Package Manager](https://swift.org/package-manager/)
- [Python Generator](../Generator/README.md)
