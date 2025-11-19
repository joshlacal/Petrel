# Swift Generator for Petrel

A modern Swift-based code generator that replaces the Python implementation for generating Swift code from ATProtocol Lexicon files.

## Features

- **Native Swift**: Written entirely in Swift using modern Swift 6.0 features
- **SwiftSyntax**: Uses Apple's SwiftSyntax for proper AST-based code generation
- **SwiftFormat**: Produces consistently formatted, idiomatic Swift code
- **Type-safe**: Leverages Swift's type system for safer code generation
- **Fast**: Compiled performance with async/await for efficient file operations
- **Maintainable**: Clean architecture with separated concerns

## Architecture

### Core Components

1. **LexiconModels.swift**: Codable models for parsing Lexicon JSON files
2. **TypeConverter.swift**: Converts Lexicon types to Swift types
3. **CycleDetector.swift**: Detects and handles circular type dependencies
4. **CodeGenerator.swift**: Generates Swift code using SwiftSyntax
5. **GeneratorCoordinator.swift**: Orchestrates the two-pass generation process
6. **main.swift**: CLI entry point with argument parsing

### Two-Pass Architecture

**Pass 1: Discovery**
- Recursively scans and loads all Lexicon JSON files
- Filters out Ozone-related lexicons
- Validates JSON structure

**Pass 2: Cycle Detection**
- Registers all type definitions
- Builds dependency graph
- Detects circular references using DFS
- Marks types needing indirection

**Pass 3: Code Generation**
- Generates Swift files for each Lexicon
- Handles objects, records, queries, procedures, and subscriptions
- Applies proper formatting

**Pass 4: Special Files**
- Generates namespace hierarchy (ATProtoClientGeneratedMain.swift)
- Generates type registry (ATProtocolValueContainer.swift)

## Building

```bash
cd SwiftGenerator
swift build -c release
```

## Usage

```bash
.build/release/swift-generator <lexicons-path> <output-path>

# Example:
.build/release/swift-generator ../Generator/lexicons ../Sources/Petrel/Generated
```

### Using the Wrapper Script

```bash
./generate.sh
```

## Comparison with Python Generator

| Feature | Python Generator | Swift Generator |
|---------|-----------------|-----------------|
| Language | Python 3.x | Swift 6.0 |
| Code Generation | Jinja2 Templates | SwiftSyntax AST |
| Formatting | Manual | SwiftFormat |
| Type Safety | Runtime | Compile-time |
| Performance | Interpreted | Compiled |
| Dependencies | orjson, Jinja2, aiofiles | SwiftSyntax, SwiftFormat |
| Concurrency | asyncio | async/await |
| Output Quality | Good | Excellent (better formatting) |

## Generated Code Features

The Swift generator produces code with:

- ✅ Full Codable conformance
- ✅ ATProtocolValue and ATProtocolCodable protocols
- ✅ Equatable and Hashable implementation
- ✅ CBOR encoding support
- ✅ Proper error handling with LogManager
- ✅ Type-safe union enums
- ✅ Circular reference handling
- ✅ Namespace-organized API methods
- ✅ Comprehensive documentation comments
- ✅ Consistent formatting

## Type Mapping

| Lexicon Type | Swift Type |
|--------------|------------|
| string | String |
| string (datetime) | ATProtocolDate |
| string (uri) | URI |
| string (at-uri) | ATProtocolURI |
| string (at-identifier) | ATIdentifier |
| string (cid) | CID |
| string (did) | DID |
| string (handle) | Handle |
| string (tid) | TID |
| string (language) | LanguageCodeContainer |
| integer | Int |
| number | Double |
| boolean | Bool |
| blob | Blob |
| bytes | Bytes |
| cid-link | CID |
| array | [ItemType] |
| ref | Resolved reference type |
| union | Generated enum with cases |
| object | [String: ATProtocolValueContainer] |
| unknown | ATProtocolValueContainer |

## Development

### Adding New Features

To add support for new Lexicon features:

1. Update `LexiconModels.swift` with new properties
2. Add type conversion logic in `TypeConverter.swift`
3. Implement code generation in `CodeGenerator.swift`
4. Test with sample Lexicon files

### Testing

```bash
swift test
```

## Known Limitations

- Subscription endpoints are generated with basic structure (message handling could be enhanced)
- Blob upload with metadata stripping requires manual enhancement
- Error enum generation is simplified

## Future Enhancements

- [ ] Parallel file generation for improved performance
- [ ] Incremental generation (only changed files)
- [ ] More sophisticated union type handling
- [ ] Enhanced blob upload code generation
- [ ] Better error messages and debugging
- [ ] Watch mode for development

## License

MIT License (same as Petrel project)
