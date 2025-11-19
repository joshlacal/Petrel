# Quick Start Guide

## Installation & Setup

### Prerequisites

- macOS 14+ or Linux
- Swift 6.0 toolchain installed
- Git

### Step 1: Build the Generator

```bash
cd SwiftGenerator
swift build -c release
```

This will download dependencies and compile the generator. First build may take a few minutes.

### Step 2: Run Code Generation

```bash
# Using the wrapper script (recommended)
./generate.sh

# Or manually
.build/release/swift-generator ../Generator/lexicons ../Sources/Petrel/Generated
```

### Step 3: Verify Generated Code

```bash
# Validate structure (works without Swift)
python3 validate.py ../Sources/Petrel/Generated

# Build Petrel to ensure code compiles
cd ..
swift build
```

### Step 4: Run Tests

```bash
swift test
```

## Comparison with Python Generator

### Running Both Generators

```bash
# Generate with Python (current)
python3 run.py Generator/lexicons Sources/Petrel/Generated.python

# Generate with Swift (new)
cd SwiftGenerator
./generate.sh
cd ..

# Compare outputs
diff -r Sources/Petrel/Generated.python Sources/Petrel/Generated
```

### Expected Differences

The Swift generator produces the **same** functionality with:

1. **Better Formatting**: Consistent indentation and spacing
2. **More Idiomatic Swift**: Uses modern Swift patterns
3. **Better Comments**: Clearer documentation
4. **Same Types**: All types, methods, and conformances match

## Troubleshooting

### Build Errors

**Error: Swift not found**
```bash
# Install Swift from swift.org
# Or use swiftenv:
swiftenv install 6.0
```

**Error: Cannot resolve dependencies**
```bash
# Clean and retry
swift package clean
swift package resolve
swift build
```

### Generation Errors

**Error: Lexicons path not found**
```bash
# Ensure path is correct
ls Generator/lexicons
```

**Error: Failed to decode lexicon**
- Check JSON syntax in the failing lexicon file
- Ensure file encoding is UTF-8

### Validation Errors

**Many warnings**
- Warnings are informational and can be ignored
- Errors should be investigated

## Development Workflow

### Making Changes

1. Edit Swift generator source code
2. Rebuild: `swift build`
3. Test on sample lexicon: `./test-single.sh app.bsky.actor.getProfile`
4. Run full generation: `./generate.sh`
5. Validate: `python3 validate.py ../Sources/Petrel/Generated`
6. Build Petrel: `cd .. && swift build`
7. Run tests: `swift test`

### Adding New Lexicon Types

1. Update `LexiconModels.swift` if needed
2. Add type mapping in `TypeConverter.swift`
3. Add code generation in `CodeGenerator.swift`
4. Test with example lexicon
5. Document in README.md

## Performance

Typical performance metrics:

- **Build time**: 30-60 seconds (first time), 2-5 seconds (incremental)
- **Generation time**: 2-4 seconds for ~240 lexicons
- **Memory usage**: < 100 MB

## Files Generated

### Main Files (per lexicon)
- `{LexiconID}.swift` - One file per lexicon

### Special Files
- `ATProtoClientGeneratedMain.swift` - Namespace hierarchy
- `ATProtocolValueContainer.swift` - Type registry

### Total
- ~241 Swift files
- ~50,000 lines of code
- ~2 MB total

## Next Steps

1. ✅ Build generator
2. ✅ Run generation
3. ✅ Verify output
4. ✅ Build Petrel
5. ✅ Run tests
6. 🎉 Ship it!

## Getting Help

- Check `README.md` for architecture details
- Check `TESTING.md` for comprehensive testing guide
- Check Python generator docs for behavior reference
- File issues on GitHub

## Migrating from Python

The Swift generator is a **drop-in replacement**:

1. Keep Python generator as backup
2. Build Swift generator
3. Generate with Swift
4. Compare outputs (should match)
5. Switch to Swift permanently
6. Remove Python dependency

No code changes needed in Petrel!
