# Circular Reference Fix

## Problem

The generated Swift types had a circular reference that caused stack overflow during JSON decoding:

```
ProfileViewBasic → ViewerState → KnownFollowers → [ProfileViewBasic] → (cycle repeats)
```

This caused Swift's generic metadata system to infinitely recurse during type instantiation, resulting in `SIGSEGV: Signal 11, Code 2 - Stack overflow`.

## Solution

Implemented automatic circular reference detection and breaking using `IndirectBox<T>`.

### Key Components

1. **IndirectBox Helper** (`Sources/Petrel/Helpers/IndirectBox.swift`)
   - Indirect enum that stores values on the heap
   - Breaks circular type dependencies without changing public API
   - Supports Codable, Hashable, Equatable, and Sendable
   - Transparent to API consumers

2. **Cycle Detector** (`Generator/cycle_detector.py`)
   - Analyzes type dependency graph across all lexicons
   - Detects circular references using DFS algorithm
   - Selects optimal properties to box (prefers arrays)
   - Tracks which properties need boxing

3. **Template Updates** (`Generator/templates/lexiconDefinitions.jinja`)
   - Generates private boxed storage: `private let _followers: IndirectBox<[ProfileViewBasic]>`
   - Provides public computed property: `public var followers: [ProfileViewBasic] { _followers.value }`
   - Handles boxing/unboxing in init, decode, encode, hash, and equality

4. **Generator Integration** (`Generator/main.py`, `Generator/swift_code_generator.py`)
   - Two-pass processing: first builds dependency graph, then generates code
   - Passes cycle information to code generator
   - Properties marked as `boxed: true` in template context

## How It Works

### Detection

1. Load all lexicons and extract type dependencies
2. Build graph: `AppBskyActorDefs.ViewerState` → `AppBskyActorDefs.KnownFollowers`
3. Run DFS to find cycles
4. For each cycle, select best property to box (prefers arrays, later in cycle)

### Code Generation

For `AppBskyActorDefs.KnownFollowers.followers`:

```swift
// Before (causes stack overflow)
public let followers: [ProfileViewBasic]

// After (breaks cycle)
private let _followers: IndirectBox<[ProfileViewBasic]>
public var followers: [ProfileViewBasic] {
    _followers.value
}

// Init wraps value
self._followers = IndirectBox(followers)

// Decode wraps value
let decoded = try container.decode([ProfileViewBasic].self, forKey: .followers)
self._followers = IndirectBox(decoded)

// Encode unwraps value
try container.encode(_followers.value, forKey: .followers)
```

## Benefits

✅ **No API Changes** - Public interface remains identical
✅ **Automatic** - Detects and fixes all circular references
✅ **Value Semantics** - Maintains struct semantics (no classes)
✅ **Type Safe** - Compile-time checked
✅ **Minimal Overhead** - Only affected properties use indirection

## Testing

Run generator:
```bash
python run.py Generator/lexicons Sources/Petrel/Generated
```

Expected output shows detected cycles:
```
Loaded 202 types
Detected 1 circular properties
  - AppBskyActorDefs.KnownFollowers.followers
```

## Files Modified

- `Sources/Petrel/Helpers/IndirectBox.swift` (new)
- `Generator/cycle_detector.py` (new)
- `Generator/main.py`
- `Generator/swift_code_generator.py`
- `Generator/templates/lexiconDefinitions.jinja`
- `Tests/PetrelTests/CircularReferenceTests.swift` (new)
