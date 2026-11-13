# JetstreamLiveCLI — Filtered ATmosphere Event Streaming

`JetstreamLiveCLI` is a standalone Swift 6 command-line package demonstrating `PetrelJetstream` and `PetrelFirehose` with server-side collection/DID filters, optional `zstd` WebSocket compression, typed `AppBskyFeedPost` decoding, arbitrary custom-collection inspection, and atomic file-backed cursor persistence (`FirehoseCursorStorage`).

No account, API key, or authentication is required.

## Quick Start

```bash
cd Examples/JetstreamLiveCLI

# Stream 15 live Bluesky posts (default)
swift run JetstreamLiveCLI

# Filter live posts mentioning "swift" with zstd compression enabled
swift run JetstreamLiveCLI --keyword swift --compress --limit 10

# Watch a custom ATmosphere Lexicon namespace and persist the cursor to disk
swift run JetstreamLiveCLI \
  --collection "xyz.statusphere.*" \
  --cursor-file /tmp/statusphere-jetstream.cursor \
  --limit 0
```

## CLI Reference

```text
--host <url>            Jetstream host (default: https://jetstream2.us-east.bsky.network)
-c, --collection <nsid> Collection NSID or prefix.* filter (repeatable; default: app.bsky.feed.post)
--all-collections       Stream every collection across the network
--did <did>             Restrict events to specific repository DID(s) (repeatable)
-k, --keyword <text>    Case-insensitive text filter on decoded records
--compress              Enable dictionary-based zstd WebSocket compression
--include-identity      Also print #identity and #account lifecycle events
--cursor-file <path>    Persist and resume sequence cursor atomically on disk
-n, --limit <N>         Stop after N matching events (default: 15, 0 = run forever)
```
