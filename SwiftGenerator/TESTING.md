# Testing Guide for Swift Generator

## Prerequisites

- Swift 6.0 or later
- macOS 14+ or Linux with Swift toolchain

## Build and Test Steps

### 1. Build the Generator

```bash
cd SwiftGenerator
swift build -c release
```

Expected output:
```
Building for production...
Build complete!
```

### 2. Run on Sample Lexicon

Test with a simple lexicon first:

```bash
mkdir -p test-output
.build/release/swift-generator ../Generator/lexicons/app/bsky/actor test-output
```

This should generate files like:
- `AppBskyActorGetProfile.swift`
- `AppBskyActorGetPreferences.swift`
- etc.

### 3. Compare with Python Generator Output

```bash
# Generate with Python
python ../run.py ../Generator/lexicons test-output-python

# Generate with Swift
.build/release/swift-generator ../Generator/lexicons test-output-swift

# Compare (should be identical or better formatted)
diff -r test-output-python test-output-swift
```

### 4. Verify Generated Code Compiles

```bash
# Copy generated files to Petrel
cp test-output-swift/* ../Sources/Petrel/Generated/

# Build Petrel
cd ..
swift build
```

Expected: No compilation errors

### 5. Run Petrel Tests

```bash
swift test
```

Expected: All tests pass

## Validation Checklist

### Generated Files
- [ ] All lexicon files are processed
- [ ] Ozone lexicons are excluded
- [ ] File names match pattern: `{LexiconId}.swift`

### Generated Code Structure
- [ ] Import Foundation at top
- [ ] Header comment with lexicon version and ID
- [ ] Main type (struct/enum) is generated
- [ ] Nested types are generated correctly

### Type Definitions
- [ ] Structs have all properties with correct types
- [ ] Required vs optional properties are correct
- [ ] Union types are generated as enums
- [ ] Circular references use IndirectBox (if needed)

### Protocol Conformance
- [ ] ATProtocolCodable conformance
- [ ] ATProtocolValue conformance
- [ ] Equatable via isEqual(to:)
- [ ] Hashable via hash(into:)
- [ ] Codable with proper CodingKeys

### Methods
- [ ] Standard initializer with all properties
- [ ] Codable init(from decoder:) with error handling
- [ ] encode(to encoder:) with $type field
- [ ] toCBORValue() for CBOR encoding
- [ ] isEqual(to:) for value comparison
- [ ] hash(into:) for hashing

### API Methods (Query/Procedure)
- [ ] Extension on correct namespace (ATProtoClient.X.Y.Z)
- [ ] Method name matches endpoint
- [ ] Parameters struct for queries
- [ ] Input struct for procedures
- [ ] Output typealias or struct
- [ ] Async function signature
- [ ] Proper error handling
- [ ] Return type: (responseCode: Int, data: Output?)

### Special Files
- [ ] ATProtoClientGeneratedMain.swift exists
- [ ] Namespace hierarchy is correct
- [ ] ATProtocolValueContainer.swift exists
- [ ] All types registered in type factory

## Manual Testing

### Test Case 1: Simple Object

Input: `app.bsky.actor.defs#profileView`

Expected Output:
```swift
public struct AppBskyActorDefs {
    public struct ProfileView: ATProtocolCodable, ATProtocolValue {
        public static let typeIdentifier = "app.bsky.actor.defs#profileView"
        public let did: DID
        public let handle: Handle
        public let displayName: String?
        // ... etc
    }
}
```

### Test Case 2: Query

Input: `app.bsky.actor.getProfile`

Expected Output:
```swift
public enum AppBskyActorGetProfile {
    public static let typeIdentifier = "app.bsky.actor.getProfile"

    public struct Parameters: Parametrizable {
        public let actor: ATIdentifier
    }

    public typealias Output = AppBskyActorDefs.ProfileViewDetailed
}

public extension ATProtoClient.App.Bsky.Actor {
    func getProfile(input: AppBskyActorGetProfile.Parameters) async throws -> (responseCode: Int, data: AppBskyActorGetProfile.Output?) {
        // ... implementation
    }
}
```

### Test Case 3: Union Type

Input: Property with union of refs

Expected Output:
```swift
public enum SomeUnion: Codable, ATProtocolCodable, ATProtocolValue, Sendable, Equatable {
    case type1(Type1)
    case type2(Type2)
    case unexpected(ATProtocolValueContainer)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(String.self, forKey: .type)

        switch typeValue {
        case "type.id.1":
            let value = try Type1(from: decoder)
            self = .type1(value)
        // ... etc
        }
    }
}
```

## Performance Testing

Test generation speed:

```bash
time .build/release/swift-generator ../Generator/lexicons ../Sources/Petrel/Generated
```

Target: < 5 seconds for full generation

## Known Issues to Check

1. **Escaping**: Special characters in descriptions and strings
2. **Reserved keywords**: Properties named `class`, `struct`, etc.
3. **Empty arrays**: Optional array properties
4. **Binary encoding**: Non-JSON input/output handling
5. **Circular references**: Proper IndirectBox usage

## Debugging

If generation fails:

```bash
# Verbose output
.build/release/swift-generator ../Generator/lexicons output --verbose

# Check specific lexicon
.build/release/swift-generator ../Generator/lexicons/app/bsky/actor output
```

## Success Criteria

✅ All lexicons processed without errors
✅ Generated code compiles without warnings
✅ All Petrel tests pass
✅ Generated code is formatted consistently
✅ Output matches or improves upon Python generator
✅ Performance is acceptable (< 5 seconds)
