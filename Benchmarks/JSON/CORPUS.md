# Petrel JSON benchmark corpus

The seven fixtures are deterministic synthetic ATProto responses generated from this checkout's Lexicon schemas and generated Swift model shapes. They contain no captured network responses, real people, account credentials, or private data. All handles and HTTP URLs use reserved `example.test` domains. DIDs and valid CIDv1 multihashes are generated from SHA-256 of fixed synthetic labels. AT URIs use valid synthetic record keys.

The generator has no third-party Python dependencies or network access:

```sh
python3 Benchmarks/JSON/generate_fixtures.py
```

`Fixtures/manifest.json` records category, Swift decode type, byte count, SHA-256, JSON value-node count, and expected top-level counts. Hashes cover the exact UTF-8 bytes, including a final LF. JSON uses compact separators, unescaped Unicode and no BOM. Use identical committed files on every machine. Fixture I/O and JSON verification must be outside timed decoding regions.

| Category | File | Bytes | Petrel output type | Workload |
|---|---|---:|---|---|
| A: Small | `small-profile.json` | 1,017 | `AppBskyActorGetProfile.Output` | Detailed profile, URLs, dates, associated chat, viewer state and pinned post |
| B: Medium | `medium-search.json` | 33,567 | `AppBskyActorSearchActors.Output` | 50 actor-search results; Unicode in one third of names |
| C: Large | `large-feed.json` | 467,235 | `AppBskyFeedGetTimeline.Output` | 100 varied feed entries |
| D: Very large | `very-large-feed.json` | 3,738,557 | `AppBskyFeedGetTimeline.Output` | 800 varied feed entries; explicitly expanded stress workload |
| E: String heavy | `unicode-feed.json` | 546,809 | `AppBskyFeedGetTimeline.Output` | 100 entries with Unicode names, post text, alt text and link cards |
| F: Base64 heavy | `base64-records.json` | 1,410,148 | `ComAtprotoRepoListRecords.Output` | 32 synthetic extension records carrying 32 KiB of binary data each |
| G: Difficult Codable | `difficult-feed.json` | 537,455 | `AppBskyFeedGetTimeline.Output` | 100 entries with nested dynamic values and unknown union/record cases |

`AppBskyActorGetProfile.Output` is the generated alias for `AppBskyActorDefs.ProfileViewDetailed`. The harness dispatch keys in the manifest are `profile`, `search`, `timeline`, and `records`.

## Feed composition

The ordinary 100-entry feed has 20 image posts, 20 external-link posts, 20 quotes, 20 quotes with images, and 20 text posts. Images vary from one to four and include blob references, alt text and aspect ratios in the record as well as thumbnail/full-size image URLs in the view. Quoted records include their own authors, typed post values and external-card views. There are 25 reply entries with typed root/parent post views and 17 repost reasons. Each known post has three facets (mention, link, tag) and a language/tag array. Viewer state, counts, labels and associated profile fields are included. The 800-entry expansion generates distinct identities/record identifiers and repeats these proportions.

The Unicode corpus includes CJK, Hangul, Arabic, Hebrew, emoji, skin-tone modifiers, family/person ZWJ sequences, precomposed/decomposed accented letters and escaped newlines/quotes. Facet byte offsets are computed from UTF-8 bytes, not character counts. Dates vary across millisecond, microsecond and nanosecond precision. This tests the actual semantic date/identifier fields rather than substituting strings in an approximate benchmark model.

The difficult corpus retains 80 known typed post records and introduces 20 unknown records. It adds open-union unknown embeds/reasons, dictionaries, nested arrays, booleans, nulls, `$link`, explicit null optionals, absent optionals, and tolerated unknown fields on known post records. These exercise Petrel's forward-compatibility behavior rather than malformed JSON. Separate malformed-input tests belong to the differential harness.

## Base64 interpretation

Petrel's exact IPLD `{ "$bytes": "…" }` object decodes through `ATProtocolValueContainer` into `Bytes`. The generated `com.atproto.repo.listRecords` envelope can carry unknown custom records with this representation. The fixture uses a synthetic `test.example.binary` record with one 32 KiB payload and small metadata, repeated 32 times with distinct record identifiers. Decoded payloads total 1,048,576 bytes.

This is a valid dynamic-data workload, **not evidence that normal timeline images are Base64**. Feed blobs are links plus metadata and the actual image bytes travel separately. No existing large captured Base64 JSON workload was found among the inspected Petrel fixtures. The representative binary content is deterministic SHA-256 output, with no meaningful compressibility assumed. `base64-payload.bin` and `base64-payload.txt` contain the corresponding 32 KiB raw payload and standard padded RFC 4648 Base64 for component-only measurements.

## Validation and provenance

The generator checks:

- JSON encoding/decoding round trips and all known post facet boundaries.
- Required properties, scalar/array/object shapes, size bounds, known Lexicon references and known union alternatives against vendored schemas.
- The expanded response is between 1 and 10 decimal MB.

This Python check deliberately permits unknown union members and extra fields; it is not a full implementation of Lexicon format/grapheme validation. The Swift `validateCorpus(_:)` function performs the decisive Foundation-to-actual-Petrel-model check outside measurements. It verifies known records remain `AppBskyFeedPost`, expected optional fields and nested quote/reply/embed types survive, facets retain valid ranges, unknown data remains unknown rather than disappearing, and binary payload lengths are correct. The main differential harness then compares candidates with those Foundation-decoded models.

Run corpus validation in a separate process before **cold** measurements: decoding the corpus initializes static type-dispatch/date machinery and would contaminate a subsequent first-decode measurement in that process.

Relevant checked-in shape references are `generator/lexicons/app/bsky/{actor,feed,embed,richtext}`, generated `AppBskyActorGetProfile`, `AppBskyActorSearchActors`, `AppBskyFeedGetTimeline`, `ComAtprotoRepoListRecords`, and `ATProtocolValueContainer`. `Tests/PetrelTests/ATProtocolValueContainerDecodingTests.swift` informed the inclusion of nanosecond dates, explicit nulls and unknown extra fields; no private text or identities were copied from those tests.

## Limits on conclusions

This corpus preserves realistic nested model structures, but it is synthetic and intentionally exercises complex records. It cannot establish the distribution of payload size or feature frequencies in a particular user's feed. The 3.7 MB expansion is larger than an ordinary single timeline page and must be labeled as a stress workload. Repeated structural patterns may benefit warm caches; all implementations receive identical bytes. Decisions about production thresholds should also use sanitized application captures or production signpost distributions when available.
