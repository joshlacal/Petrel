# Calling XRPC Endpoints

Make typed and untyped XRPC calls, handle errors, and control one call at a time.

## Overview

Every query and procedure in the Lexicons Petrel is built from is a method on
``ATProtoClient``, grouped by NSID: `app.bsky.feed.getTimeline` is
`client.app.bsky.feed.getTimeline`. The same transport also calls endpoints
Petrel has no generated method for, by NSID.

Authentication, DPoP, token refresh, service routing (`atproto-proxy`) and
retries apply to every call described here.

## Typed calls

A generated call takes the Lexicon's parameters (`input:` for a query's
parameters or a procedure's body, `params:` for a procedure's query parameters)
and returns the HTTP status with the decoded body.

<!-- Mirrors GeneratedXRPCCallTests.testSuccessReturnsTheStatusAndDecodedBody -->

```swift
let (status, timeline) = try await client.app.bsky.feed.getTimeline(
    input: .init(limit: 30)
)
// status is always 2xx here; timeline is the decoded AppBskyFeedGetTimeline.Output
```

A call returns only for a 2xx response whose body matches the output schema.
Everything else is thrown.

## Errors

A non-2xx response carries `{"error": "...", "message": "..."}`. Petrel throws
it, never drops it:

- `ATProtoError<Endpoint.Error>` when the Lexicon of the endpoint declares the
  error name. `error` is a case of the generated enum.
- ``ATProtoXRPCError`` for any other error. `error` and `message` are the
  server's strings. A body that is not an envelope (a gateway's HTML page, an
  empty body) gives `error == "HTTP <status>"`.
- ``XRPCResponseDecodingError`` when a 2xx body does not match the output schema.
- `NetworkError` for transport failures.

Both error types carry `statusCode` and the response `headers`.

<!-- Mirrors GeneratedXRPCCallTests.testDeclaredErrorIsThrownTyped and
     testRateLimitResponseCarriesTheEnvelopeAndRateLimitHeaders -->

```swift
do {
    let (_, record) = try await client.com.atproto.repo.getRecord(input: parameters)
    // use record
} catch let error as ATProtoError<ComAtprotoRepoGetRecord.Error> {
    switch error.error {
    case .recordNotFound: break   // declared in the Lexicon
    }
} catch let error as ATProtoXRPCError where error.statusCode == 429 {
    let waitSeconds = error.retryAfter           // Retry-After, in seconds
    let resetsAt = error.rateLimit?.reset        // ratelimit-reset
    _ = (waitSeconds, resetsAt)
} catch let error as ATProtoXRPCError {
    print(error.error, error.message ?? "")       // "InvalidRequest", "ExpiredToken", …
}
```

## Calling an endpoint without a generated method

``NetworkService/xrpcQuery(_:parameters:options:)`` and
``NetworkService/xrpcProcedure(_:parameters:body:options:)`` take an NSID. They
are also available as `client.query` and `client.procedure`.

<!-- Mirrors GeneratedXRPCCallTests.testUntypedQuerySendsParametersAndReturnsBodyAndHeaders
     and testUntypedProcedureSendsJSONAndBinaryBodies -->

```swift
let response = try await client.query(
    "com.example.widget.getThing",
    parameters: [
        URLQueryItem(name: "id", value: "3jwdwj2ctlk26"),
        URLQueryItem(name: "tag", value: "a"),     // repeat a name for an array
        URLQueryItem(name: "tag", value: "b"),
    ]
)
let untyped = try response.json()                  // ATProtocolValueContainer
let typed = try response.decode(Thing.self)        // or any Decodable

_ = try await client.procedure(
    "com.example.widget.createThing",
    body: .json(encoding: ["name": "left"])
)
_ = try await client.procedure(
    "com.example.widget.uploadThing",
    parameters: [URLQueryItem(name: "name", value: "left.bin")],
    body: .bytes(data, contentType: "application/x-widget")
)
```

``XRPCResponse`` holds the status, the headers and the body exactly as received.
Non-2xx responses throw ``ATProtoXRPCError``; a string that is not an NSID is
rejected before any request is made.

To get the typed API for your own Lexicons instead, see <doc:CustomLexicons>.

## Options for one call

``XRPCCallOptions`` sets headers, the `atproto-proxy` target, the
`atproto-accept-labelers` list, or a different service for a single call.
Pass it to the untyped calls, or wrap a generated call:

<!-- Mirrors GeneratedXRPCCallTests.testCallOptionsScopeAppliesToGeneratedCalls and
     testCallOptionsSetHeadersProxyAndLabelersForOneUntypedCall -->

```swift
let options = XRPCCallOptions(
    headers: ["X-Widget-Trace": "abc"],
    proxy: "did:web:api.example.com#my_appview",
    acceptLabelers: [XRPCLabeler(did: "did:plc:ar7c4by46qjdydhdevvrndac", redact: true)]
)

let (_, timeline) = try await NetworkService.withCallOptions(options) {
    try await client.app.bsky.feed.getTimeline(input: .init())
}
```

Client-wide defaults are set with `client.setAcceptLabelers(_:)`,
``NetworkService/setServiceDID(_:for:)`` and ``NetworkService/setHeader(name:value:)``.

## Response headers

Generated calls return the decoded body. To read what else the service sent —
rate-limit state, `atproto-content-labelers`, `atproto-repo-rev` — run the call
inside ``NetworkService/withResponseMetadata(_:)``:

<!-- Mirrors GeneratedXRPCCallTests.testResponseMetadataOfAGeneratedCallIsReadable -->

```swift
let (result, metadata) = try await NetworkService.withResponseMetadata {
    try await client.app.bsky.feed.getTimeline(input: .init())
}
let remaining = metadata?.rateLimit?.remaining
let labelers = metadata?.contentLabelers ?? []
let repoRev = metadata?.repoRev
```

## Uploading blobs

A procedure whose input encoding is `*/*`, such as `com.atproto.repo.uploadBlob`,
takes the bytes and their MIME type, which is sent as `Content-Type`.

<!-- Mirrors GeneratedXRPCCallTests.testUploadBlobStripsImageMetadataByDefault,
     testUploadBlobSendsNonImageBodiesUntouched and
     testUploadBlobSendsTheBodyUntouchedWhenNotStripping -->

```swift
let (_, uploaded) = try await client.com.atproto.repo.uploadBlob(
    data: photoData,
    mimeType: "image/jpeg"
)
let blob = uploaded?.blob     // reference it from a record

// Send a file byte for byte, metadata included:
_ = try await client.com.atproto.repo.uploadBlob(
    data: photoData,
    mimeType: "image/jpeg",
    stripMetadata: false
)
```

By default image metadata (EXIF, GPS position, XMP, comments) is removed before
the upload, because a photo's metadata can reveal where it was taken. Stripping
keeps the image format and does not re-encode pixels; `Content-Type` stays what
you passed. A body whose MIME type is not `image/*` is sent exactly as given.
An image that cannot be stripped is not uploaded:
`NetworkError.metadataStrippingFailed` is thrown instead.

## Retries

Queries (GET) are retried up to three times on 5xx responses and transport
errors, with randomized exponential backoff, or after the delay a `Retry-After`
header asks for. `501 Not Implemented` is never retried. Procedures (POST) are
retried only when the request provably never reached the server, because a
procedure that was applied before a gateway failed would otherwise be applied
twice.

## Event streams

Subscriptions are generated too. The stream skips frames whose message type or
operation it does not know, as the event-stream specification asks, and throws
with ``EventStreamError`` on an error frame.

```swift
for try await message in try await client.com.atproto.sync.subscribeRepos(cursor: nil) {
    switch message {
    case let .commit(commit): _ = commit.ops
    default: break
    }
}
```

## Reading and writing data faithfully

Generated types are a view of wire data, and writing a value back reproduces it:

- Fields a Lexicon does not declare are kept in `extraFields` and re-encoded, in
  JSON and DAG-CBOR, so a record keeps its CID through a round trip.
- An open union keeps a variant it does not know as `.unexpected`; a closed
  union rejects it.
- `cid-link` fields are ``ATProtoLink`` (`{"$link": …}`, CBOR tag 42). Strings of
  format `cid` are ``CIDString``: the text exactly as written, valid for any
  well-formed CID, with `.cid` giving the parsed ``CID`` when it is one atproto
  blesses for links.
- A property that is optional and nullable is `ATProtoNullable<T>?`, so
  absent, `null` and a value stay distinct.

By default an optional field that does not match its schema is dropped and
logged, so one malformed field in a feed does not fail the whole response.
`ATProtoDecoding.strictJSONDecoder()` rejects such data, as the Lexicon
specification prescribes for validation. To check constraints the Swift types do
not carry (lengths, ranges, enums), validate with the `PetrelLexicon` product.
