# Firehose Monitor

A CLI tool for testing Petrel's WebSocket subscription support by connecting to the Bluesky firehose.

## Overview

The FirehoseMonitor demonstrates:
- Unauthenticated ATProtoClient connections (no OAuth required)
- WebSocket subscription to `com.atproto.sync.subscribeRepos`
- Full DAG-CBOR frame decoding
- Message type discrimination (commit, identity, account, sync, info)
- Record type classification (posts, likes, follows, reposts, profiles)
- Real-time statistics and event rate monitoring

## Building

```bash
swift build --product FirehoseMonitor
```

## Running

```bash
swift run FirehoseMonitor
```

Or run the built executable directly:

```bash
.build/debug/FirehoseMonitor
```

## What It Does

The monitor connects to `wss://bsky.network` (the public Bluesky firehose relay) and:

1. **Receives all message types**:
   - `#commit` - Repository commits with operations
   - `#identity` - DID/handle updates
   - `#account` - Account status changes
   - `#sync` - Sync events
   - `#info` - Info messages

2. **Parses commit operations** to identify:
   - Post creates/updates/deletes
   - Like creates/deletes
   - Follow creates/deletes
   - Repost creates/deletes
   - Profile updates

3. **Displays formatted output** including:
   - DID and handle information
   - Record paths and CIDs
   - Sequence numbers and revisions
   - Operation actions (create/update/delete)

4. **Tracks statistics**:
   - Event rate (events/sec)
   - Message type counts
   - Record type counts
   - Real-time throughput monitoring

## Features Tested

### Unauthenticated Client Support
The firehose endpoint is public and doesn't require authentication. The monitor uses:

```swift
let client = await ATProtoClient(
    baseURL: URL(string: "https://bsky.network")!,
    oauthConfig: nil,  // No OAuth needed
    namespace: "firehose-monitor"
)
```

### WebSocket Subscription
Uses Petrel's `subscribe()` method which handles:
- WebSocket connection upgrade
- Binary frame reception
- DAG-CBOR header/payload parsing
- Message type discrimination
- Automatic CID link conversion

### Message Processing
Fully typed message handling with Swift enums:

```swift
for try await message in stream {
    switch message {
    case .commit(let commit):
        // Process repo operations
    case .identity(let identity):
        // Handle DID/handle updates
    case .account(let account):
        // Handle account status
    // ...
    }
}
```

## Expected Output

```
🔥 Bluesky Firehose Monitor
================================================================================
Connecting to wss://bsky.network...
Press Ctrl+C to stop

✅ Connected to firehose!

📝 POST CREATE
   Repo: did:plc:abc123...
   Path: app.bsky.feed.post/3k7abc...
   CID: bafyreiabc123...
   Seq: 12345678 | Rev: 3k7abc...

❤️  LIKE CREATE
   Repo: did:plc:def456...
   Seq: 12345679

👥 FOLLOW CREATE
   Repo: did:plc:ghi789...
   Seq: 12345680

================================================================================
📊 Statistics after 100 messages
================================================================================
Rate: 45.2 events/sec | Elapsed: 2.2s

Message Types:
  • Commits: 98
  • Identity Updates: 1
  • Account Updates: 0
  • Sync Messages: 1

Record Types:
  • Posts: 23
  • Likes: 45
  • Follows: 12
  • Reposts: 8
  • Profiles: 2
  • Other: 8
================================================================================
```

## Implementation Details

### ATProtoClient Changes
Modified `ATProtoClientGeneratedMain.swift` to support optional OAuth:
- `oauthConfig` parameter is now optional
- When nil, skips authentication setup
- NetworkService doesn't add auth headers (firehose allows this)
- Logs "unauthenticated mode" for clarity

### Generated Types Used
- `ComAtprotoSyncSubscribeRepos.Message` - Union type for all message variants
- `ComAtprotoSyncSubscribeRepos.Commit` - Repo commit with operations
- `ComAtprotoSyncSubscribeRepos.Identity` - Identity update event
- `ComAtprotoSyncSubscribeRepos.Account` - Account status event
- `ComAtprotoSyncSubscribeRepos.Sync` - Sync event
- `ComAtprotoSyncSubscribeRepos.Info` - Info message
- `ComAtprotoSyncSubscribeRepos.RepoOp` - Individual operation in a commit

### WebSocket Frame Format
Each frame contains two DAG-CBOR objects:
1. **Header**: `{op: 1, t: "#commit"}` or `{op: -1}` for errors
2. **Payload**: The actual message data

NetworkService handles:
- Binary frame reception
- CBOR decoding
- Header extraction
- Type discrimination via `$type` field
- CID link conversion (`tag 42` → `{"$link": "..."}`)

## Troubleshooting

### Connection Issues
If you see connection errors, check:
- Network connectivity to `bsky.network`
- Firewall/proxy settings for WebSocket (wss://)
- DNS resolution

### Decoding Errors
If frames fail to decode:
- Check that SwiftCBOR dependency is installed
- Verify Petrel library is up to date
- Review NetworkService logs for details

### High CPU/Memory
The firehose can be very busy (50+ events/sec):
- Consider filtering messages you care about
- Reduce print frequency
- Add backpressure handling if needed

## Next Steps

This monitor demonstrates the core functionality. For production use, consider:

1. **Cursor persistence** - Save sequence numbers to resume after restart
2. **Reconnection logic** - Handle disconnections with exponential backoff
3. **Message filtering** - Process only specific record types
4. **Batch processing** - Queue messages for efficient processing
5. **Block decoding** - Parse the CAR blocks to extract record content
6. **Database storage** - Persist events for analysis

## References

- [AT Protocol Event Streams Spec](https://atproto.com/specs/event-stream)
- [WebSocket Subscription Implementation](Sources/Petrel/Managerial/NetworkService.swift#L1117-L1230)
- [DAG-CBOR Decoding](Sources/Petrel/Managerial/NetworkService.swift#L1232-L1372)
- [Firehose Lexicon](https://github.com/bluesky-social/atproto/blob/main/lexicons/com/atproto/sync/subscribeRepos.json)
