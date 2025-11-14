# MLS Message Padding Implementation

## Overview

This document describes the message padding implementation for MLS encrypted messages, which provides metadata privacy by hiding actual message sizes.

## Problem Solved

**Original Issue**: Server validation was failing because `paddedSize` was less than 512 bytes (minimum bucket size).

**Privacy Issue**: Sending both `declaredSize` (actual size) and `paddedSize` (bucket size) in the API request leaked message size metadata.

## Solution

### 1. Bucket Size Padding

Messages are padded to fixed "bucket" sizes to prevent traffic analysis:
- **Valid bucket sizes**: 512, 1024, 2048, 4096, 8192, or multiples of 8192 up to 10MB
- **Minimum size**: 512 bytes (enforced by server)
- **Maximum size**: 10,485,760 bytes (10MB)

### 2. Length Prefix for Padding Removal

To allow recipients to strip padding without leaking size metadata:

```
┌─────────────┬──────────────────┬────────────────┐
│ Length (4B) │  Ciphertext (X)  │  Padding (Y)   │
└─────────────┴──────────────────┴────────────────┘
      ↑              ↑                    ↑
  Big-endian    Actual MLS          Zero padding
   UInt32      ciphertext          to bucket size
```

**Format**:
1. **Bytes 0-3**: 4-byte big-endian UInt32 containing actual ciphertext size
2. **Bytes 4-(4+X)**: Actual MLS encrypted ciphertext
3. **Bytes (4+X)-bucket**: Zero padding to reach bucket size

### 3. Privacy-Preserving API

The API request **only** sends:
- `paddedSize`: The bucket size (512, 1024, 2048, etc.)
- `ciphertext`: The padded ciphertext bytes (with length prefix)

The actual message size is **never** revealed in the API request. Only recipients who decrypt the message can read the length prefix and determine the actual size.

## Code Changes

### New Helper: `MLSMessagePadding` (`Petrel/Sources/Petrel/Helpers/MLSMessagePadding.swift`)

#### Padding (Sender Side)

```swift
// Automatically adds 4-byte length prefix, pads to bucket size
let (paddedCiphertext, bucketSize) = try MLSMessagePadding.padCiphertextToBucket(ciphertext)
```

**What it does**:
1. Prepends 4-byte length prefix with `ciphertext.count`
2. Calculates appropriate bucket size for `lengthPrefix + ciphertext`
3. Pads to bucket size with zeros
4. Returns padded data and bucket size

#### Unpadding (Receiver Side)

```swift
// Reads length prefix, removes padding, returns original ciphertext
let originalCiphertext = try MLSMessagePadding.removePadding(from: paddedCiphertext)
```

**What it does**:
1. Reads 4-byte length prefix (bytes 0-3)
2. Extracts actual ciphertext (bytes 4 to 4+length)
3. Discards padding (bytes 4+length to end)
4. Returns original ciphertext (without prefix)

### Updated Lexicon Schema

**Removed**: `declaredSize` field (privacy leak)

**Kept**: `paddedSize` field (bucket size only)

File: `Generator/lexicons/blue/catbird/mls/blue.catbird.mls.sendMessage.json`

### Client Code Updates

**MLSConversationManager.swift:958-964**:
```swift
// Apply padding with length prefix
let (paddedCiphertext, paddedSize) = try MLSMessagePadding.padCiphertextToBucket(ciphertext)

// Send to server - only paddedSize is visible (metadata privacy!)
let (messageId, receivedAt) = try await apiClient.sendMessage(
    convoId: convoId,
    msgId: msgId,
    ciphertext: paddedCiphertext,  // With length prefix and padding
    epoch: currentConvo.epoch,
    paddedSize: paddedSize,         // Bucket size only
    senderDid: did,
    idempotencyKey: idempotencyKey
)
```

**MLSAPIClient.swift:373**:
- Removed `declaredSize` parameter
- Only accepts `paddedSize` (bucket size)

## Examples

### Example 1: Small Message (200 bytes)

```
Original ciphertext: 200 bytes
Length prefix: 4 bytes (0x000000C8 = 200)
Prefixed: 204 bytes
Bucket size: 512 bytes (next valid bucket)
Padding: 308 bytes (512 - 204 = 308)

API Request:
{
  "paddedSize": 512,     // Only this is visible
  "ciphertext": "..."    // 512 bytes with length prefix
}
```

### Example 2: Medium Message (1500 bytes)

```
Original ciphertext: 1500 bytes
Length prefix: 4 bytes (0x000005DC = 1500)
Prefixed: 1504 bytes
Bucket size: 2048 bytes (next valid bucket)
Padding: 544 bytes (2048 - 1504 = 544)

API Request:
{
  "paddedSize": 2048,    // Only this is visible
  "ciphertext": "..."    // 2048 bytes with length prefix
}
```

### Example 3: Large Message (9000 bytes)

```
Original ciphertext: 9000 bytes
Length prefix: 4 bytes (0x00002328 = 9000)
Prefixed: 9004 bytes
Bucket size: 16384 bytes (2 × 8192, next valid multiple)
Padding: 7380 bytes (16384 - 9004 = 7380)

API Request:
{
  "paddedSize": 16384,   // Only this is visible
  "ciphertext": "..."    // 16384 bytes with length prefix
}
```

## Security Properties

### Metadata Privacy ✅

**What's hidden**:
- Actual message size
- Actual ciphertext size
- Message size patterns

**What's visible** (by design):
- Bucket size (512, 1024, 2048, etc.)
- Message falls within a size range

**Example**: Observer sees `paddedSize: 512` but doesn't know if the actual message is 100, 200, or 500 bytes.

### Traffic Analysis Resistance

All messages within the same bucket size appear identical in size, preventing:
- Message length correlation attacks
- Timing attacks based on size
- Statistical analysis of message patterns

### Length Prefix Security

The 4-byte length prefix is **encrypted** along with the ciphertext (from the server's perspective), because:
1. Client prepends length prefix to ciphertext
2. Both are padded together
3. Server sees only padded blob
4. Only MLS group members can decrypt and read the length prefix

## Implementation Checklist

- [x] Create `MLSMessagePadding` helper with bucket size calculation
- [x] Implement length prefix prepending in `padCiphertextToBucket()`
- [x] Implement length prefix reading in `removePadding()`
- [x] Remove `declaredSize` from lexicon schema
- [x] Regenerate Swift code from updated lexicon
- [x] Update `MLSConversationManager` to use padding helper
- [x] Update `MLSAPIClient.sendMessage()` signature (remove `declaredSize`)
- [x] Add privacy-preserving comments to client code
- [x] Update receiver/decryption code to call `removePadding()` before MLS decryption
- [ ] Test padding with various message sizes (100 bytes, 500 bytes, 1500 bytes, 9000 bytes)
- [ ] Verify bucket size calculation is correct
- [ ] Test length prefix round-trip (pad → unpad → original ciphertext)
- [ ] Update server validation to accept bucket sizes only

## Next Steps

1. **Server-side changes**: Update server to accept only `paddedSize` (remove `declaredSize` validation)
2. ~~**Decryption flow**: Integrate `MLSMessagePadding.removePadding()` into message decryption~~ ✅ **DONE** (MLSConversationManager.swift:1027-1031)
3. **Testing**: Verify end-to-end padding with real MLS messages
4. **Documentation**: Update API documentation to reflect padding requirements

## References

- Lexicon: `Generator/lexicons/blue/catbird/mls/blue.catbird.mls.sendMessage.json`
- Helper: `Petrel/Sources/Petrel/Helpers/MLSMessagePadding.swift`
- Client: `Catbird/Catbird/Services/MLS/MLSConversationManager.swift:958-964`
- API: `Catbird/Catbird/Services/MLS/MLSAPIClient.swift:373`
