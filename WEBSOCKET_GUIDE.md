# WebSocket Implementation Guide for Petrel

## Summary

Foundation **DOES** support WebSockets natively via `URLSessionWebSocketTask` (available since macOS 12/iOS 15). Your project targets macOS 14+/iOS 17+, so you're good to go without any additional dependencies!

## What You Already Have

### 1. DAG-CBOR Support ✅
You already have complete DAG-CBOR encoding/decoding:

- **SwiftCBOR library** - In Package.swift
- **DAGCBOREncodable/DAGCBORDecodable protocols** - In CID.swift
- **Canonical ordering** - OrderedCBORMap.swift
- **CID link handling** - Tag 42 support in CID.swift
- **Type conversion** - CBOR ↔ JSON conversion helpers

### 2. WebSocket Support ✅
Foundation provides `URLSessionWebSocketTask`:

```swift
import Foundation

let url = URL(string: "wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos")!
let webSocketTask = URLSession.shared.webSocketTask(with: url)
webSocketTask.resume()

// Receive messages
let message = try await webSocketTask.receive()
```

## What You Need to Implement

### 1. Add subscribe() method to NetworkService protocol

```swift
protocol NetworkService {
    // ... existing methods ...
    
    func subscribe<Message: Codable>(
        endpoint: String,
        parameters: (any Parametrizable)?
    ) async throws -> AsyncThrowingStream<Message, Error>
}
```

### 2. Implement the subscription logic

The implementation needs to handle:

#### a. WebSocket Connection
```swift
// Build wss:// URL with query parameters
var urlComponents = URLComponents()
urlComponents.scheme = "wss"
urlComponents.host = pdsURL.host
urlComponents.path = "/xrpc/\(endpoint)"
urlComponents.queryItems = parameters?.asQueryItems()

let webSocketTask = URLSession.shared.webSocketTask(with: url)
webSocketTask.resume()
```

#### b. Binary Frame Decoding
Each WebSocket frame contains **two concatenated DAG-CBOR objects**:

1. **Header object** with fields:
   - `op` (integer): 1 = message, -1 = error
   - `t` (string): message type (e.g., "#commit")

2. **Payload object**: The actual message data

```swift
// Parse frame
let data = receivedData

// Decode header (first CBOR object)
let headerCBOR = try CBOR.decode([UInt8](data))
let headerData = try headerCBOR.encode()
let headerSize = headerData.count

// Decode payload (second CBOR object)
let payloadData = data[headerSize...]
let payloadCBOR = try CBOR.decode([UInt8](payloadData))
```

#### c. Type Discrimination
The `t` field in the header indicates which variant of the Message enum to decode:

```swift
// From header: t = "com.atproto.sync.subscribeRepos#commit"
// Maps to: ComAtprotoSyncSubscribeRepos.Message.commit(...)

// Add $type to payload for Codable decoding
var jsonObject = try cborToJSON(payloadCBOR)
jsonObject["$type"] = messageTypeName // e.g., "com.atproto.sync.subscribeRepos#commit"

// Decode as the Message enum
let message = try JSONDecoder().decode(Message.self, from: finalJSON)
```

#### d. AsyncThrowingStream
Return an async stream that yields decoded messages:

```swift
AsyncThrowingStream { continuation in
    Task {
        while !Task.isCancelled {
            let frame = try await webSocketTask.receive()
            if case .data(let data) = frame {
                let message = try decodeSubscriptionFrame(data, as: Message.self)
                continuation.yield(message)
            }
        }
    }
    
    continuation.onTermination = { _ in
        webSocketTask.cancel(with: .goingAway, reason: nil)
    }
}
```

### 3. Helper Methods Needed

#### CBOR to JSON Conversion
You'll need to convert CBOR to JSON for Codable compatibility:

```swift
private func cborToJSONValue(_ cbor: CBOR) throws -> Any {
    switch cbor {
    case .unsignedInt(let value):
        return Int(value)
    case .utf8String(let string):
        return string
    case .array(let items):
        return try items.map { try cborToJSONValue($0) }
    case .map(let map):
        var result: [String: Any] = [:]
        for (key, value) in map {
            guard case .utf8String(let keyString) = key else {
                throw error
            }
            result[keyString] = try cborToJSONValue(value)
        }
        return result
    case .tagged(let tag, let value):
        if tag.rawValue == 42 {
            // CID link - decode to {"$link": "cid_string"}
            let cid = try CID(bytes: ...)
            return ["$link": cid.toString()]
        }
        return try cborToJSONValue(value)
    // ... handle other cases
    }
}
```

#### Query Parameter Conversion
Convert Parametrizable structs to URLQueryItems:

```swift
extension Parametrizable {
    func asQueryItems() throws -> [URLQueryItem] {
        // Use Mirror to reflect on properties
        // Convert each property to URLQueryItem
        // Handle optionals appropriately
    }
}
```

## ATProtocol Subscription Specifics

### Frame Format
```
[Header CBOR][Payload CBOR]
```

### Header Schema
```typescript
{
  op: 1 | -1,    // 1 = message, -1 = error
  t?: string     // message type (required if op = 1)
}
```

### Error Frame
```typescript
{
  error: string,    // error type name
  message?: string  // error description
}
```

### Sequence Numbers
Messages may include a `seq` field for backfill support:

```swift
// Resume from sequence 12345
client.com.atproto.sync.subscribeRepos(cursor: 12345)
```

## Implementation Checklist

- [ ] Add `subscribe()` to NetworkService protocol
- [ ] Implement WebSocket connection with URLSessionWebSocketTask
- [ ] Implement binary frame parsing (2 CBOR objects)
- [ ] Implement header decoding (op and t fields)
- [ ] Implement payload decoding
- [ ] Implement CBOR to JSON conversion
- [ ] Handle CID links (Tag 42) in CBOR
- [ ] Handle error frames (op = -1)
- [ ] Implement AsyncThrowingStream wrapper
- [ ] Add query parameter conversion for Parametrizable
- [ ] Handle WebSocket reconnection logic
- [ ] Add proper error handling
- [ ] Add logging for debugging

## Testing

Once implemented, you can test with:

```swift
let client = ATProtoClient(...)

// Test label subscription
for try await message in try await client.com.atproto.label.subscribeLabels() {
    switch message {
    case .labels(let labels):
        print("Got \(labels.labels.count) labels")
    case .info(let info):
        print("Info: \(info.name)")
    }
}

// Test firehose
for try await message in try await client.com.atproto.sync.subscribeRepos() {
    switch message {
    case .commit(let commit):
        print("Commit from \(commit.repo)")
    case .identity(let identity):
        print("Identity update: \(identity.did)")
    case .account(let account):
        print("Account update: \(account.did)")
    case .sync(let sync):
        print("Sync: \(sync.did)")
    case .info(let info):
        print("Info: \(info.name)")
    }
}
```

## Resources

- **Foundation WebSocket docs**: https://developer.apple.com/documentation/foundation/urlsessionwebsockettask
- **ATProtocol Event Stream spec**: The specs you provided above
- **SwiftCBOR library**: https://github.com/valpackett/SwiftCBOR
- **Example implementation**: See WEBSOCKET_IMPLEMENTATION_EXAMPLE.swift

## No Additional Dependencies Needed! 🎉

You have everything you need:
- ✅ Swift 6.2
- ✅ Foundation WebSocket support (macOS 14+/iOS 17+)
- ✅ SwiftCBOR library
- ✅ DAG-CBOR encoding/decoding infrastructure
- ✅ Generated subscription code from the generator

Just implement the NetworkService extension and you're ready to go!
