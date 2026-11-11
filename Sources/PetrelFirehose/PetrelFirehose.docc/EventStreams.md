# Consuming event streams

Subscribe to a relay firehose, a labeler, or any Lexicon subscription, with cursors, reconnection and backpressure.

## Overview

AT Protocol services publish changes over WebSocket *event streams*
([specification](https://atproto.com/specs/event-stream)). The best known is the repository
firehose, `com.atproto.sync.subscribeRepos`, which a relay such as `bsky.network` or any PDS
serves ([sync specification](https://atproto.com/specs/sync)).

Petrel has four ways to read one. Pick by what you need:

| You want | Use | Module |
|---|---|---|
| The firehose, typed, with cursor and reconnect | ``FirehoseSubscription`` | `PetrelFirehose` |
| Labels from a labeler | ``LabelSubscription`` | `PetrelFirehose` |
| Any other subscription Lexicon, with cursor and reconnect | ``EventStreamSubscription`` | `PetrelFirehose` |
| Repository events as filtered JSON, without CBOR or CAR | `JetstreamSubscription` | `PetrelJetstream` |

The generated client also has a one-shot stream per subscription Lexicon
(`client.com.atproto.sync.subscribeRepos(…)`): a single connection, no cursor handling, no
reconnect. The types above are built for long-running consumers.

## Read the firehose

```swift
import PetrelFirehose

let subscription = FirehoseSubscription(
  service: URL(string: "https://bsky.network")!,
  cursorStorage: InMemoryFirehoseCursorStorage(),   // use your own durable storage
  autoAcknowledge: true
)

for try await element in subscription.events() {
  switch element {
  case let .event(.commit(commit)):
    for operation in try commit.records() {
      // operation.action, operation.collection, operation.recordKey, operation.record
    }
  case let .event(.identity(identity)):
    // identity.did may have a new handle or DID document: refresh your cache
    _ = identity
  case let .event(.account(account)):
    // account.active / account.status: stop serving content of inactive accounts
    _ = account
  case .event(.sync), .event(.info), .event(.error):
    break
  case let .sequenceGap(expected, received):
    // informational; the stream continues
    _ = (expected, received)
  case let .ignoredFrame(frame):
    // unknown message type or a payload that did not match its schema
    _ = frame
  }
}
```

`FirehoseSubscription(service:)` maps `https://host` to
`wss://host/xrpc/com.atproto.sync.subscribeRepos`. Pass a complete `wss://` URL with
`FirehoseSubscription(url:)` if you need other query parameters.

``RelayCommitEvent/records()`` pairs each create and update operation with its record,
decoded from the commit's `blocks` CAR after checking the block against the operation's CID.

## Read labels, or any other subscription

``EventStreamSubscription`` works for every subscription Lexicon. It decodes into the message
union the code generator emits for that Lexicon.

```swift
let labels = LabelSubscription.labels(
  service: URL(string: "https://mod.bsky.app")!,
  cursorStorage: InMemoryFirehoseCursorStorage(initialCursor: 0),   // 0: replay everything
  autoAcknowledge: true
)

for try await element in labels.events() {
  if case let .message(.labels(batch), _) = element {
    for label in batch.labels {
      // label.src, label.uri, label.val, label.neg
    }
  }
}
```

For another endpoint, name the NSID and the generated `Message` type:

```swift
let stream = EventStreamSubscription<ComAtprotoSyncSubscribeRepos.Message>(
  nsid: "com.atproto.sync.subscribeRepos",
  configuration: FirehoseSubscriptionConfiguration(
    url: URL(string: "wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos")!
  )
)
```

## Cursors

Sequenced messages carry a `seq`. The cursor is the `seq` of the last event your application
finished processing; Petrel sends it as the `cursor` query parameter on every (re)connection.

- **Storage.** Implement ``FirehoseCursorStorage`` over your database. The in-memory
  implementation forgets the cursor when the process exits.
- **Acknowledging.** With `autoAcknowledge: true` the cursor of an event is saved when your
  loop asks for the *next* element, which is the first moment the event is known to be
  handled. If the process dies while handling event N, the stored cursor is still N-1 and N
  is delivered again: at-least-once. With `autoAcknowledge: false` (the default) call
  ``FirehoseSubscription/acknowledge(sequence:)`` yourself, for example after a database
  commit.
- **Starting point.** No cursor starts at the live tip. `0` asks for the oldest event the
  server still has. A cursor inside the server's window resumes there.
- **Replay at the cursor.** The specification says the server sends events with `seq`
  greater than *or equal to* the cursor. The event at the cursor was already processed, so
  that one replayed copy is dropped. Servers that resume after the cursor work the same.
- **Outdated cursor.** The server sends `#info` with name `OutdatedCursor` and continues from
  its oldest event. You receive the info event, a ``FirehoseSubscriptionEvent/sequenceGap(expected:received:)``,
  and then the events.
- **Gaps.** Sequence numbers "may contain arbitrary gaps". A gap is reported as an element
  and the stream goes on. If you need every event, treat a gap as a reason to resynchronise
  the affected repositories.
- **Reconnect without an acknowledgement.** If nothing was acknowledged yet, a reconnect
  resumes from the last sequence delivered in this process, so events are not skipped.

## What is skipped and what ends the stream

| Situation | Behaviour | Specification |
|---|---|---|
| Unknown `op`, or unknown `t` (including deprecated `#handle`, `#migrate`, `#tombstone`) | skipped; reported as `.ignoredFrame`; cursor moves past it | "Clients should ignore frames with headers that have unknown `op` or `t` values" |
| Unknown fields in header or payload | ignored | "Unknown fields in both headers and payloads should be ignored" |
| `#account` with an unknown `status`, or `active: true` with a status | delivered | `status` has open `knownValues` |
| `#commit` with `tooBig` / `rebase` / `blobs`, in any state or absent | delivered; the fields are ignored | deprecated fields |
| Update or delete operation without `prev` | delivered | `prev` is optional in the Lexicon |
| A payload that does not match its schema | skipped; reported as `.ignoredFrame` with the reason | one bad event must not stall the stream |
| Invalid framing or CBOR, or a frame above 5 MB | stream ends with ``RelayVerifierError`` | "hard errors, and the client should drop the entire connection" |
| Error frame (`op: -1`) | socket closed; stream ends with `EventStreamError` | "Streams should be closed immediately following … an error frame" |
| Duplicate or decreasing `seq` within a connection | stream ends with ``FirehoseSubscriptionError`` | suggested client behaviour |
| Connection lost, close frame, `429`, `5xx` other than `501` | reconnect with backoff from the cursor | Connection section |
| Upgrade refused with `501` or another `4xx` | stream ends with ``FirehoseSubscriptionError/upgradeRejected(status:retryAfter:)`` | "`501` … should not be retried" |

Error frames are typed, so the common ones can be matched directly:

```swift
do {
  for try await _ in subscription.events() {}
} catch EventStreamError.futureCursor {
  // The stored cursor is ahead of the server (it may have reset its sequence).
  // Do not reset the cursor automatically; an operator should decide.
} catch EventStreamError.consumerTooSlow {
  // The server dropped this client for falling behind.
}
```

To reconnect after `ConsumerTooSlow` instead, set
``FirehoseSubscriptionConfiguration/reconnectsOnConsumerTooSlow``.

## Backpressure and cancellation

`events()` is pull-based. A frame is read from the socket only when your loop asks for the
next element; nothing is buffered ahead of you and nothing is dropped. A consumer that does
I/O per event simply slows the connection, and the server's own "too slow" policy applies.

Cancelling the task that iterates the stream closes the socket and ends the sequence without
an error. Leaving the loop with `break` and dropping the stream closes the socket too.

## Reconnection and keep-alive

Reconnection uses exponential backoff (``FirehoseBackoffConfiguration``: 0.5 s doubling to
30 s, with ±25% jitter) and resets once a frame arrives. `Retry-After` on a `429` or `503` is
honoured.

The `URLSession` transport sends a WebSocket ping every 30 seconds
(``FirehoseWebSocketOptions/pingInterval``). A quiet stream (a labeler, a small PDS) is
therefore not reaped by proxies or load balancers along the way, and a peer that disappeared
without closing is detected when a ping goes unanswered.

The transport accepts messages up to 5 MB (``FirehoseFrameLimits/maximumFrameBytes``), the hard
limit of the sync specification. A larger message ends the stream with
``FirehoseSubscriptionError/frameTooLarge`` instead of reconnecting to the same frame forever.

## Authentication headers

Endpoints that require authentication at connect time take extra headers through the
transport options:

```swift
let factory = URLSessionFirehoseWebSocketFactory(
  options: FirehoseWebSocketOptions(additionalHeaders: ["Authorization": "Bearer \(token)"])
)
let subscription = FirehoseSubscription(url: url, sessionFactory: factory)
```

## Decode frames without a connection

``RelayFrameDecoder`` decodes one frame, for example from a capture file.

```swift
switch try RelayFrameDecoder.decodeFrame(frameData) {
case let .event(event):
  // RelayEvent
  _ = event
case let .ignored(frame):
  // unknown op or t
  _ = frame
}
```

The default mode is ``RelayFrameDecodingMode/lenient``, the consumer rules above.
``RelayFrameDecodingMode/strict`` checks a *producer*: exact key sets, the closed account
status set, sync-1.1 operation shapes. Use it to test a relay or PDS implementation, not to
consume one.

## Linux

The consumers are transport-agnostic: they talk to ``FirehoseWebSocketSession`` and
``FirehoseWebSocketSessionFactory``. The default factory uses `URLSessionWebSocketTask`.

On Apple platforms that is all you need. On Linux, `URLSessionWebSocketTask` exists in
swift-corelibs-foundation but only functions when the system libcurl was built with WebSocket
support. The official Swift 6.1 image for Ubuntu 22.04 (libcurl 7.81) is not: there every
connection fails with "WebSockets not supported by libcurl". Petrel reports that as
``FirehoseSubscriptionError/webSocketTransportUnavailable(_:)`` and ends the stream instead of
retrying. Check your target system before relying on the default transport.

To consume streams on such a system, wrap a WebSocket client of your choice (for example one
built on SwiftNIO) in the two protocols. Petrel does not ship one, because that would add a
networking stack to every consumer of the package.

```swift
struct MySession: FirehoseWebSocketSession {
  func receiveMessage() async throws -> Data { /* next binary message */ fatalError() }
  func close() async { /* close the socket */ }
}

struct MyFactory: FirehoseWebSocketSessionFactory {
  func makeSession(url: URL) async throws -> any FirehoseWebSocketSession { MySession() }
}

let subscription = FirehoseSubscription(url: url, sessionFactory: MyFactory())
```

`receiveMessage()` is called once per element the consumer takes, so a transport that reads
from the socket on demand keeps the backpressure property.

## What this module does not do

The stream consumers deliver events; they do not authenticate them. Verifying a commit's
signature against the account's current signing key, and checking `blocks` against `prevData`
by MST inversion (sync 1.1), are repository-level operations and are not performed on the
stream. `PetrelRepo` has the CAR, MST and commit primitives.

## Live tests

The test suite has loopback tests against a real WebSocket server on a local socket, and
live smoke tests that are skipped unless an endpoint is named:

```bash
FIREHOSE_SMOKE_URL=wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos \
LABELS_SMOKE_URL=https://mod.bsky.app \
swift test --filter FirehoseLiveSmokeTests
```
