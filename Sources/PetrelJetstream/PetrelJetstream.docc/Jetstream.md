# Subscribing to Jetstream

Stream filtered repository events as JSON from a Jetstream host, on either of its two APIs.

## Overview

<!-- compile-example: jetstream-quick-start -->
```swift
import Foundation
import PetrelJetstream

func readPosts() async throws {
  let subscription = JetstreamSubscription(configuration: .init(
    url: URL(string: "https://jetstream2.us-east.bsky.network")!,
    filter: JetstreamFilter(kinds: [.commit], collections: ["app.bsky.feed.post"])
  ))

  for try await element in subscription.events() {
    guard case let .event(.commit(commit)) = element else { continue }
    // commit.did, commit.collection, commit.rkey, commit.operation
    // commit.recordJSON is the record as JSON; commit.decodedRecord() parses it
    _ = commit
  }
}
```

The stream reconnects with backoff and resumes from the last delivered position. It is
pull-based: a frame is read from the socket when your loop asks for the next element.
Cancelling the iterating task closes the socket.

## What the stream yields

``JetstreamSubscriptionEvent`` has three cases. A loop that switches over it exhaustively
handles all three:

<!-- compile-example: jetstream-exhaustive-switch -->
```swift
import PetrelJetstream

func consume(_ subscription: JetstreamSubscription) async throws {
  for try await element in subscription.events() {
    switch element {
    case let .event(event):
      // .commit, .identity, .account, .sync or .info
      _ = event
    case let .streamError(name, message):
      // The stream ends with the matching error right after this.
      _ = (name, message)
    case let .ignoredFrame(frame):
      switch frame.reason {
      case let .malformedFrame(description):
        _ = description            // not a JSON object, or an incomplete envelope
      case let .undecompressable(description):
        _ = description            // a compressed frame that did not decompress
      case .unknownType:
        break                      // a message type this version of Petrel does not know
      case let .undecodablePayload(description):
        _ = description            // a known type with missing or invalid fields
      case let .duplicateSequence(sequence):
        _ = sequence               // a v2 `seq` already delivered on this connection
      }
      // frame.type: the message type, when the frame named one
      // frame.sequence: the frame's position, when it carried a valid one
    }
  }
}
```

``JetstreamSubscriptionEvent/ignoredFrame(_:)`` reports a frame the subscription could not
use; the stream carries on after it. ``JetstreamIgnoredFrame/Reason/unknownType`` is
expected from time to time, because Jetstream adds message types without notice. To keep
the behaviour of ignoring such frames, write `case .ignoredFrame: break`.

On the v2 API an ignored frame with a new sequence number moves the cursor past it, so a
reconnect does not fetch it again. Legacy `time_us` positions are not unique, so on the
legacy API the cursor only follows delivered events. A compressed frame that does not
decompress is reported as ``JetstreamIgnoredFrame/Reason/undecompressable(_:)`` and the
stream keeps reading on the same connection.

``JetstreamIgnoredFrame/Reason/duplicateSequence(_:)`` is a v2 `seq` at or below one already
delivered on the same connection. The single replayed event at the cursor right after a
reconnect is expected (resume is inclusive) and is dropped without being reported.

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

<!-- compile-example: jetstream-legacy-api -->
```swift
import Foundation
import PetrelJetstream

func useLegacyAPI() async throws {
  var configuration = JetstreamSubscriptionConfiguration(
    url: URL(string: "wss://jetstream2.us-east.bsky.network/subscribe")!,
    filter: JetstreamFilter(collections: ["app.bsky.feed.like"])
  )
  configuration.requireHello = true          // send the filters as the first message
  let legacy = JetstreamSubscription(configuration: configuration)

  // later, without reconnecting:
  try await legacy.updateOptions(JetstreamOptionsUpdate(wantedCollections: ["app.bsky.feed.post"]))
}
```

``JetstreamSubscription/updateOptions(_:)`` throws
``JetstreamSubscriptionError/optionsUpdateUnsupported`` on the v2 API.

## Frames and compression

Without compression Jetstream sends each event as a WebSocket **text** message. The default
transport of ``JetstreamSubscriptionConfiguration`` accepts text. If you supply your own
`FirehoseWebSocketSessionFactory`, it must deliver text messages as UTF-8 bytes
(`FirehoseWebSocketOptions.jetstream`).

With `compression: true` events arrive as **binary** zstd frames compressed with a shared
dictionary. On the v2 API the dictionary is fetched from the host
(`network.bsky.jetstream.getZstdDictionary`). The legacy API has no such endpoint: pass the
dictionary published in the Jetstream repository (`pkg/models/zstd_dictionary`) as
``JetstreamSubscriptionConfiguration/legacyZstdDictionary``. Requesting compression on the
legacy API without it ends the stream with
``JetstreamSubscriptionError/missingZstdDictionary``.

## Cursors

Set ``JetstreamSubscriptionConfiguration/cursor`` to resume from a position, or
``JetstreamSubscriptionConfiguration/cursorStorage`` to load and save it automatically. The
position of an event is saved when your loop asks for the next element, so an event that was
being handled when the process died is delivered again.

Resume is inclusive; the replayed event at the cursor is dropped.

A cursor storage that throws ends the stream with
``JetstreamSubscriptionError/cursorStorageFailure(operation:message:)``. The `operation` is
``JetstreamSubscriptionError/CursorStorageOperation/load`` or
``JetstreamSubscriptionError/CursorStorageOperation/save``, and `message` describes the
underlying error. A failed load ends the stream before it connects, instead of starting at
the live tip and skipping everything since the stored position. A failed save ends it
instead of losing the position.

## Errors

- A request the server refuses before upgrading (an unknown collection, a cursor that is too
  old) ends the stream with ``JetstreamSubscriptionError/connectionRejected(status:error:message:)``,
  carrying the server's explanation.
- An error frame is surfaced as ``JetstreamSubscriptionEvent/streamError(name:message:)`` and
  then ends the stream with the matching `EventStreamError`, for example
  `EventStreamError.consumerTooSlow`. Set
  ``JetstreamSubscriptionConfiguration/reconnectsOnConsumerTooSlow`` to reconnect instead.
- A cursor storage failure ends the stream with
  ``JetstreamSubscriptionError/cursorStorageFailure(operation:message:)`` (see Cursors).
- Network failures, `429` and `5xx` are retried with backoff.
- Frames the stream cannot use do not end it; they arrive as
  ``JetstreamSubscriptionEvent/ignoredFrame(_:)``.

## Backfill, then live

On hosts that publish an archive, ``JetstreamClient`` replays history and then switches to
the live stream without a gap:

<!-- compile-example: jetstream-backfill -->
```swift
import Foundation
import PetrelJetstream

func backfillThenLive() async throws {
  let client = JetstreamClient(configuration: .init(
    host: URL(string: "https://jetstream.example")!,
    mode: .snapshotThenLive(afterSeq: 0),
    filter: JetstreamFilter(collections: ["app.bsky.feed.post"])
  ))

  for try await batch in client.events() {
    // batch.events, batch.lastCursor
    _ = batch
  }
}
```

`.live()` skips the archive. Batches are handed over through a small bounded buffer, so
downloads and the socket pause while your loop is busy.

Batches carry events only. Ignored frames are not passed on; consume
``JetstreamSubscription`` directly to see them. ``JetstreamClient`` also ignores errors from
its own `cursorStorage` rather than ending the stream with
``JetstreamSubscriptionError/cursorStorageFailure(operation:message:)``.

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
