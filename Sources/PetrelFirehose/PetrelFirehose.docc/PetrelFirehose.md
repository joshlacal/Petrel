# ``PetrelFirehose``

Consume AT Protocol event streams: the repository firehose of a relay or PDS, labeler streams, and any other Lexicon subscription.

## Overview

An event stream is a WebSocket on which a server sends binary frames, each holding two
DAG-CBOR objects (a header and a payload). `PetrelFirehose` connects, decodes, keeps a cursor,
and reconnects, and hands you an `AsyncSequence`.

- ``FirehoseSubscription`` consumes `com.atproto.sync.subscribeRepos` and yields typed
  ``RelayEvent`` values.
- ``EventStreamSubscription`` consumes any subscription endpoint and decodes into the
  generated message union for that Lexicon. ``LabelSubscription`` is its
  `com.atproto.label.subscribeLabels` form.
- ``RelayFrameDecoder`` decodes single frames without a connection.

Start with <doc:EventStreams>.

The module also contains the producer side used by a PDS (``FirehoseFrameEncoder``,
``PublicFirehoseDiffCAR``) and verifiers for relay captures (``RelaySequenceVerifier``,
``RelayCommitSemanticVerifier``). Those are independent of the consumers.

## Topics

### Consuming streams

- <doc:EventStreams>
- ``FirehoseSubscription``
- ``FirehoseSubscriptionConfiguration``
- ``FirehoseSubscriptionEvent``
- ``FirehoseSubscriptionError``
- ``EventStreamSubscription``
- ``EventStreamEvent``
- ``LabelSubscription``
- ``EventStreamIgnoredFrame``

### Cursors and reconnection

- ``FirehoseCursorStorage``
- ``InMemoryFirehoseCursorStorage``
- ``FirehoseBackoffConfiguration``

### Events and frames

- ``RelayEvent``
- ``RelayCommitEvent``
- ``RelayRecordOperation``
- ``RelayFrameDecoder``
- ``RelayFrame``
- ``RelayFrameDecodingMode``
- ``FirehoseFrameLimits``

### Transport

- ``FirehoseWebSocketSession``
- ``FirehoseWebSocketSessionFactory``
- ``URLSessionFirehoseWebSocketFactory``
- ``FirehoseWebSocketOptions``
