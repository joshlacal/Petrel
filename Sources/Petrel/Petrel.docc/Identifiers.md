# Identifiers and String Formats

Parse, validate and normalize DIDs, handles, NSIDs, record keys, TIDs, AT-URIs,
datetimes, language tags, URIs and CID strings.

## Overview

Every Lexicon string format has a Swift type in Petrel. Generated models use
these types for their fields, so a response or record that carries a malformed
identifier fails to decode instead of handing your code an unchecked string.

| Lexicon format | Type | Specification |
|---|---|---|
| `did` | ``DID`` | [DID](https://atproto.com/specs/did) |
| `handle` | ``Handle`` | [Handle](https://atproto.com/specs/handle) |
| `at-identifier` | ``ATIdentifier`` | [Lexicon](https://atproto.com/specs/lexicon#at-identifier) |
| `nsid` | ``NSID`` | [NSID](https://atproto.com/specs/nsid) |
| `record-key` | ``RecordKey`` | [Record Key](https://atproto.com/specs/record-key) |
| `tid` | ``TID``, ``TIDGenerator`` | [TID](https://atproto.com/specs/tid) |
| `at-uri` | ``ATProtocolURI`` | [AT URI Scheme](https://atproto.com/specs/at-uri-scheme) |
| `datetime` | ``ATProtocolDate`` | [Lexicon](https://atproto.com/specs/lexicon#datetime) |
| `language` | ``LanguageTag``, ``LanguageCodeContainer`` | [Lexicon](https://atproto.com/specs/lexicon#language) |
| `uri` | ``URI`` | [Lexicon](https://atproto.com/specs/lexicon#uri) |
| `cid` | ``CIDSyntax`` | [Data Model](https://atproto.com/specs/data-model) |

The validators are checked against every file in the `syntax` directory of
[atproto-interop-tests](https://github.com/bluesky-social/atproto-interop-tests),
which is vendored under `Tests/PetrelTests/Vectors/syntax` and run in full by
`SyntaxVectorTests`.

### Three ways to check a string

Each type offers the same three entry points:

- a static validator that returns `Bool` (``DID/isValidDID(_:)``,
  ``Handle/isValidHandle(_:)``, ``NSID/isValidNSID(_:)``,
  ``RecordKey/isValidRecordKey(_:)``, ``TID/isValidTID(_:)``,
  ``ATProtocolURI/isValidATURI(_:grammar:)``,
  ``ATProtocolDate/isValidDatetime(_:)``, ``LanguageTag/isValid(_:)``,
  ``URI/isValidURI(_:)``, ``CIDSyntax/isValid(_:)``);
- a throwing initializer that reports why the string was rejected;
- `Decodable`, which applies the same rules when a model is decoded.

```swift
DID.isValidDID("did:plc:ewvi7nxzyoun6zhxrhs64oiz")   // true
DID.isValidDID("did:plc:ewvi7nxzyoun6zhxrhs64oiz\n") // false

do {
    _ = try Handle(handleString: "not a handle")
} catch let error as ATProtocolError {
    // .invalidHandle("Invalid handle \"not a handle\": contains a character outside A-Z a-z 0-9 . -")
    print(error.message)
}
```

Failures are reported as ``ATProtocolError``, with one case per format, so a
caller can tell a bad DID from a bad record key without reading the message.

Validation is byte-exact. Leading or trailing whitespace, a trailing newline,
control characters and Unicode look-alikes of ASCII letters are all rejected, and
nothing is trimmed or repaired on your behalf.

### Values are kept as written

A parsed value re-encodes to exactly the string it was created from. This
matters because records are content-addressed: re-encoding a record must not
change its bytes. Where the specification defines a normalized form, it is
available separately:

```swift
let handle = try Handle(handleString: "Alice.Example.COM")
handle.value      // "alice.example.com"  — normalized; used for equality and hashing
handle.wireValue  // "Alice.Example.COM"  — as written; used when encoding

let uri = try ATProtocolURI(uriString: "at://Alice.Example.COM/COM.Example.fooBar/Self")
uri.normalized().uriString()  // "at://alice.example.com/com.example.fooBar/Self"

let nsid = try NSID(nsidString: "COM.Example.fooBar")
nsid.normalized.nsidString()  // "com.example.fooBar" — authority lower-cased, name untouched
```

DIDs, NSID names and record keys are case-sensitive and are never changed.

## DIDs and handles

``DID`` accepts any DID method, as the Lexicon `did` format requires. To ask
whether a DID can identify an atproto account — `did:plc`, or a `did:web` that
is a bare hostname — use ``DID/atprotoMethod``:

```swift
let did = try DID(didString: "did:plc:ewvi7nxzyoun6zhxrhs64oiz")
did.method         // "plc"
did.atprotoMethod  // .plc

try DID(didString: "did:key:zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn6N").atprotoMethod  // nil
try DID(didString: "did:web:example.com:user:alice").isAtprotoDID  // false: path-based did:web
```

``Handle`` checks syntax only. The reserved top-level domains (`.local`,
`.onion`, `.arpa`, `.invalid` and the others in ``Handle/disallowedTLDs``) are
valid syntax but must not be registered or resolved; check
``Handle/hasDisallowedTLD`` before doing either. ``Handle/invalidSentinel`` is
the `handle.invalid` placeholder used when a handle does not resolve back to its
DID.

``ATIdentifier`` holds either one, decided by the `did:` prefix:

```swift
switch try ATIdentifier(string: "atproto.com") {
case let .did(did): print("DID", did)
case let .handle(handle): print("handle", handle)
}
```

## NSIDs and record keys

```swift
let collection = try NSID(nsidString: "app.bsky.feed.post")
collection.authority  // "app.bsky.feed"
collection.name       // "post"

let key = try RecordKey(keyString: "3jzfcijpj2z2a")
RecordKey.isValidRecordKey("..")  // false
```

## TIDs

A ``TID`` is a 64-bit timestamp identifier written as 13 base32-sortable
characters. ``TIDGenerator`` produces them: every identifier from a generator is
strictly greater than the one before it, however fast it is called and even if
the system clock stalls or steps backwards.

```swift
let rkey = await TIDGenerator.next()              // a new record key
let tid = await TIDGenerator.shared.nextTID()
tid.timestampMicros   // microseconds since the UNIX epoch
tid.clockID           // 0...1023, fixed for the generator

// A repository revision must be greater than the previous one, even if that
// one came from a machine whose clock was ahead:
let revision = try await TIDGenerator.shared.next(after: previousRevision)
```

## AT-URIs

``ATProtocolURI`` implements the restricted AT-URI syntax used in Lexicons:
`at://AUTHORITY[/COLLECTION[/RKEY]]`. Trailing slashes, empty path segments,
query strings and fragments are rejected.

```swift
let uri = try ATProtocolURI(uriString: "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3jzfcijpj2z2a")
uri.authority       // "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
uri.collectionNSID  // NSID("app.bsky.feed.post")
uri.rkey            // RecordKey("3jzfcijpj2z2a")

ATProtocolURI.isValidATURI("at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/")  // false: trailing slash

let built = try ATProtocolURI(
    authority: .did(did),
    collection: collection,
    recordKey: key
)
```

By default the type also accepts the permissioned-data space form,
`at://SPACE-DID/space/SPACE-TYPE/SKEY[/AUTHOR-DID/COLLECTION/RKEY]`, which is
validated just as strictly but is not part of the published AT-URI
specification (see ``SpaceRef``). To accept the specification grammar only:

```swift
let strict = try ATProtocolURI(uriString: string, grammar: .restricted)
ATProtocolURI.isValidATURI(string, grammar: .restricted)
```

## Datetimes

``ATProtocolDate`` validates the intersection of RFC 3339, ISO 8601 and WHATWG
datetimes that the Lexicon specification defines: upper-case `T`, a mandatory
timezone (`Z` or `±HH:MM`, but not `-00:00`), whole seconds, real calendar
values, and a UTC year between 0000 and 9999.

```swift
let created = try ATProtocolDate(datetimeString: "1985-04-12T23:20:50.123Z")
created.date           // Foundation Date
created.iso8601String  // "1985-04-12T23:20:50.123Z" — the string as written

ATProtocolDate.isValidDatetime("1985-04-12T23:20:50.123")   // false: no timezone
ATProtocolDate.isValidDatetime("1985-02-30T00:00:00Z")      // false: no such day

ATProtocolDate(date: Date()).iso8601String  // now, as "YYYY-MM-DDTHH:MM:SS.sssZ"
```

Older records sometimes carry timestamps that are close to valid but not quite.
``ATProtocolDate/normalizeDatetime(_:)`` converts those to the canonical form:

```swift
try ATProtocolDate.normalizeDatetime("1985-04-12 23:20:50")           // "1985-04-12T23:20:50.000Z"
try ATProtocolDate.normalizeDatetime("1985-04-12T23:20:50.123+0700")  // "1985-04-12T16:20:50.123Z"
```

## Language tags

``LanguageTag`` parses BCP 47 tags (RFC 5646). ``LanguageCodeContainer`` is the
value generated models use for `language` fields; it keeps the tag as written.

```swift
let tag = try LanguageTag("hy-Latn-IT-arevela")
tag.language  // "hy"
tag.script    // "Latn"
tag.region    // "IT"
tag.variants  // ["arevela"]

let language = try LanguageCodeContainer(validating: "pt-BR")
language.languageTag  // "pt-BR"

LanguageTag.isValid("ja-")        // false
LanguageTag.isWellFormed("JA")    // true: matches the RFC grammar
LanguageTag.isValid("JA")         // false: the primary subtag must be lower case
```

Record decoding requires a well-formed tag, as the Lexicon specification does.
``LanguageTag/isValid(_:)`` is stricter and is the level the official vectors
test.

## URIs

``URI`` is the generic Lexicon `uri` format: any RFC 3986 scheme, no whitespace,
at most 8 KB. The string is stored and re-encoded exactly as written.

```swift
let link = try URI(validating: "https://example.com/path?q=1#top")
link.scheme     // "https"
link.authority  // "example.com"
link.url        // Foundation URL

URI.isValidURI("dns:example.com")  // true
URI.isValidURI("example.com")      // false: no scheme
```

``URI/init(uriString:)`` and string literals do not validate, so that existing
call sites keep compiling. A value built that way from a string that is not a
URI reports `isValid() == false` and throws when it is encoded; it is never
replaced by a placeholder.

## CID strings

``CIDSyntax`` checks that a string is shaped like a CID, in any multibase
encoding, as the Lexicon `cid` format requires. Decoding a CID into its codec
and hash is a separate, stricter step.

```swift
CIDSyntax.isValid("bafyreidfayvfuwqa7qgahxgn2xrq2xrq2xrq2xrq2xrq2xrq2xrq2xrq2y")  // true
CIDSyntax.isValid("QmbWqxBEKC3P8tqsKc98xmWNzrzDtRLMiMPL8wBuTGsMnR")              // false: CIDv0
```

## Topics

### Account identifiers

- ``DID``
- ``Handle``
- ``ATIdentifier``

### Schema and record identifiers

- ``NSID``
- ``RecordKey``
- ``TID``
- ``TIDGenerator``
- ``ATProtocolURI``
- ``SpaceRef``

### String formats

- ``ATProtocolDate``
- ``LanguageTag``
- ``LanguageCodeContainer``
- ``URI``
- ``CIDSyntax``

### Errors

- ``ATProtocolError``
