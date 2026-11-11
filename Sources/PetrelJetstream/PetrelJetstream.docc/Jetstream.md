# Subscribing to Jetstream

Stream filtered repository events as JSON from a Jetstream host, on either of its two APIs.

## Overview

```swift
import PetrelJetstream

let subscription = JetstreamSubscription(configuration: .init(
  url: URL(string: "https://jetstream2.us-east.bsky.network")!,
  filter: JetstreamFilter(kinds: [.commit], collections: ["app.bsky.feed.post"])
))

for try await element in subscription.events() {
  guard case let .event(.commit(commit)) = element else { continue }
  // commit.did, commit.collection, commit.rkey, commit.operation
  // commit.recordJSON is the record as JSON; commit.decodedRecord() parses it
}
```

The stream reconnects with backoff and resumes from the last delivered position. It is
pull-based: a frame is read from the socket when your loop asks for the next element.
Cancelling the iterating task closes the socket.

## Two APIs

Jetstream hosts speak one or both of these. ``JetstreamSubscription`` picks by URL; set
``JetstreamSubscriptionConfiguration/apiVersion`` to force one.

| | v2 (``JetstreamAPIVersion/v2``) | legacy (``JetstreamAPIVersion/v1``) |
|---|---|---|
| URL you pass | base host, `https://host` | full endpoint, `wss://host/subscribe` |
| Endpoint | `/xrpc/network.bsky.jetstream.subscribeEvents` | `/subscribe` |
| Filters | `kinds`, `collections`, `dids` | `wantedCollections`, `wantedDids`; `kinds` is applied locally |
| Cursor | sequence number | unix microseconds (`time_us`) |
| Compression | `zstdDictionary`, dictionary fetched from the host | `compress=true`, dictionary supplied by you |
| Change filters while connected | reconnect | ``JetstreamSubscription/updateOptions(_:)`` |

On the legacy API events have no sequence number, so ``JetstreamEvent/seq`` is the event's
`time_us` there. Cursor handling is otherwise identical.

```swift
var configuration = JetstreamSubscriptionConfiguration(
  url: URL(string: "wss://jetstream2.us-east.bsky.network/subscribe")!,
  filter: JetstreamFilter(collections: ["app.bsky.feed.like"])
)
configuration.requireHello = true          // send the filters as the first message
let legacy = JetstreamSubscription(configuration: configuration)

// later, without reconnecting:
try await legacy.updateOptions(JetstreamOptionsUpdate(wantedCollections: ["app.bsky.feed.post"]))
```

## Frames and compression

Without compression Jetstream sends each event as a WebSocket **text** message. The default
transport of ``JetstreamSubscriptionConfiguration`` accepts text. If you supply your own
`FirehoseWebSocketSessionFactory`, it must deliver text messages as UTF-8 bytes
(`FirehoseWebSocketOptions.jetstream`).

With `compression: true` events arrive as **binary** zstd frames compressed with a shared
dictionary. On the v2 API the dictionary is fetched from the host
(`network.bsky.jetstream.getZstdDictionary`). The legacy API has no such endpoint: pass the
dictionary published in the Jetstream repository (`pkg/models/zstd_dictionary`) as
``JetstreamSubscriptionConfiguration/legacyZstdDictionary``.

## Cursors

Set ``JetstreamSubscriptionConfiguration/cursor`` to resume from a position, or
``JetstreamSubscriptionConfiguration/cursorStorage`` to load and save it automatically. The
position of an event is saved when your loop asks for the next element, so an event that was
being handled when the process died is delivered again.

Resume is inclusive; the replayed event at the cursor is dropped.

## Errors

- A request the server refuses before upgrading (an unknown collection, a cursor that is too
  old) ends the stream with ``JetstreamSubscriptionError/connectionRejected(status:error:message:)``,
  carrying the server's explanation.
- An error frame is surfaced as ``JetstreamSubscriptionEvent/streamError(name:message:)`` and
  then ends the stream with the matching `EventStreamError`, for example
  `EventStreamError.consumerTooSlow`. Set
  ``JetstreamSubscriptionConfiguration/reconnectsOnConsumerTooSlow`` to reconnect instead.
- Network failures, `429` and `5xx` are retried with backoff.

## Backfill, then live

On hosts that publish an archive, ``JetstreamClient`` replays history and then switches to
the live stream without a gap:

```swift
let client = JetstreamClient(configuration: .init(
  host: URL(string: "https://jetstream.example")!,
  mode: .snapshotThenLive(afterSeq: 0),
  filter: JetstreamFilter(collections: ["app.bsky.feed.post"])
))

for try await batch in client.events() {
  // batch.events, batch.lastCursor
}
```

`.live()` skips the archive. Batches are handed over through a small bounded buffer, so
downloads and the socket pause while your loop is busy.

## Linux

Jetstream uses the same WebSocket transport as `PetrelFirehose`, with the same limitation on
Linux systems whose libcurl lacks WebSocket support. See the *Linux* section of the
`PetrelFirehose` article "Consuming event streams" for how to plug in another transport.

## Live test

```bash
JETSTREAM_SMOKE_URL=wss://jetstream2.us-east.bsky.network/subscribe \
JETSTREAM_SMOKE_V2_URL=https://jetstream2.us-east.bsky.network \
swift test --filter JetstreamLiveSmokeTests
```
