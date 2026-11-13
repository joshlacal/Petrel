# ``PetrelJetstream``

Consume Jetstream, the JSON view of the AT Protocol firehose.

## Overview

[Jetstream](https://github.com/bluesky-social/jetstream) re-publishes repository events as
JSON over WebSocket, with server-side filtering by collection and DID. It needs no CBOR, CAR
or MST handling, at the cost of the cryptographic material that makes the firehose
verifiable.

- ``JetstreamSubscription`` is the live stream. It reports frames it cannot use as
  ``JetstreamSubscriptionEvent/ignoredFrame(_:)`` rather than dropping them. Start with
  <doc:Jetstream>.
- ``JetstreamClient`` adds archive backfill on hosts that offer it, then cuts over to live.

## Topics

### Live stream

- <doc:Jetstream>
- ``JetstreamSubscription``
- ``JetstreamSubscriptionConfiguration``
- ``JetstreamSubscriptionEvent``
- ``JetstreamIgnoredFrame``
- ``JetstreamSubscriptionError``
- ``JetstreamAPIVersion``
- ``JetstreamOptionsUpdate``

### Events and filters

- ``JetstreamEvent``
- ``JetstreamCommitEvent``
- ``JetstreamFilter``
- ``JetstreamKind``

### Backfill

- ``JetstreamClient``
- ``JetstreamClientConfiguration``
- ``JetstreamMode``
- ``JetstreamBatch``
