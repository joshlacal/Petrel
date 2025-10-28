# Subscription/WebSocket Support Added to Generator

## Summary

The Petrel code generator has been updated to support subscription endpoints (WebSocket event streams) as defined in the ATProtocol Lexicon specification.

## Changes Made

### 1. Removed Subscription Filtering

**File**: `Generator/main.py`
- **Before**: `if 'subscribe' in lexicon_id or 'ozone' in lexicon_id:`
- **After**: `if 'ozone' in lexicon_id:`
- **Reason**: Removed the filter that was excluding all subscription lexicons from code generation (only keeping ozone filter)

### 2. Added New Templates

#### `Generator/templates/subscription.jinja`
- Generates Swift extension methods for subscription endpoints
- Supports optional parameters with proper default values
- Returns `AsyncThrowingStream<MessageType, Error>`
- Follows the same pattern as query/procedure templates with `ATProtoClient.` namespace prefix

#### `Generator/templates/messageUnion.jinja`
- Generates the `Message` enum for subscription message types
- Handles decoding of different message variants based on `$type` field
- Supports multiple message types in a single subscription stream

### 3. Updated `Generator/templates.py`

Added template loading for new templates:
```python
self.subscription_template = self.env.get_template('subscription.jinja')
self.message_union_template = self.env.get_template('messageUnion.jinja')
```

### 4. Updated `Generator/swift_code_generator.py`

#### Added Subscription Handling
- `handle_subscription_type()`: Handles subscription type main definitions
- `generate_message_union()`: Generates the Message enum from union refs
- `generate_subscription_function()`: Generates the Swift subscription method with:
  - Proper namespace resolution (e.g., `ATProtoClient.Com.Atproto.Sync`)
  - Optional parameter support with default values
  - Message type specification

#### Fixed Type Converter Issues
- Added explicit handling for `cid-link` → `CID`
- Added explicit handling for `bytes` → `Bytes`
- Added explicit handling for `blob` → `Blob`
- Fixed nullable array handling in `generate_lex_definitions()`

#### Updated Main Conversion Logic
- Added `subscription` and `message_union` to template rendering
- Handles subscription type in the main `convert()` method

### 5. Updated `Generator/templates/mainTemplate.jinja`

Added output for message union and subscription:
```jinja
{{- message_union }}
{{ subscription }}
```

### 6. Updated `Generator/type_converter.py`

Added support for ATProtocol-specific types that were falling through to the generic capitalize handler:
- `cid-link` → `CID`
- `bytes` → `Bytes`
- `blob` → `Blob`

## Generated Output

### Example: `ComAtprotoLabelSubscribeLabels.swift`

The generator now produces:

1. **Message Types**: Individual structs for each message variant (e.g., `Labels`, `Info`)
2. **Parameters Struct**: Optional query parameters (e.g., `cursor: Int? = nil`)
3. **Message Enum**: Union type with proper Codable implementation
4. **Errors Enum**: Subscription-specific errors
5. **Extension Method**: 
   ```swift
   extension ATProtoClient.Com.Atproto.Label {
       public func subscribeLabels(
           cursor: Int? = nil
       ) async throws -> AsyncThrowingStream<ComAtprotoLabelSubscribeLabels.Message, Error>
   ```

## What's Still Needed

The generator is complete and produces valid Swift code. However, the `NetworkService` protocol needs to be updated with WebSocket support:

```swift
protocol NetworkService {
    func subscribe<T: Codable, P: Parametrizable>(
        endpoint: String,
        parameters: P?
    ) async throws -> AsyncThrowingStream<T, Error>
}
```

This would include:
- WebSocket connection management
- DAG-CBOR decoding of binary frames
- Frame header parsing (op and t fields)
- Message deserialization with proper type discrimination
- Error handling and reconnection logic
- Sequence number tracking for backfill support

## Lexicons Now Supported

- `com.atproto.label.subscribeLabels`
- `com.atproto.sync.subscribeRepos`
- Any future subscription lexicons

## Testing

The generator has been run successfully and produces valid Swift code that compiles (except for the missing `NetworkService.subscribe` method which needs to be implemented separately).

```bash
cd /Users/joshlacalamito/Developer/Catbird+Petrel/Petrel
python run.py Generator/lexicons Sources/Petrel/Generated
swift build
```

Build errors are limited to the missing `subscribe` method on `NetworkService`, confirming that the generated code structure is correct.
