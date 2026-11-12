# Validating Data at Runtime

Check records, XRPC parameters, bodies and event-stream messages against
Lexicon schemas loaded at runtime.

## Overview

Validation has two layers, and it helps to keep them apart.

The **data model** layer needs no schema. It decides whether some JSON or
DAG-CBOR is a legal atproto value at all. ``LexValue`` is that layer.

The **Lexicon** layer needs a schema. It decides whether a legal value has the
right shape for a particular record type or endpoint. ``LexiconCatalog`` is
that layer, and it only accepts ``LexValue`` input, so anything that reaches
it has already passed the first.

## Load schemas, validate a record

Add Lexicon documents to a catalog, then validate. A document is checked
against the rules of the Lexicon language as it is added; an invalid one
throws ``LexiconSchemaError`` and is not added.

<!-- Mirrors DocumentationSnippetTests.documentationValidateRecord -->

<!-- compile-example: lexicon-validate-record -->
```swift
import Foundation
import PetrelLexicon

// `schemaJSON` is the Lexicon document for com.example.note.
func validateNote(schemaJSON: Data) throws {
    var catalog = LexiconCatalog()
    try catalog.add(json: schemaJSON)

    let record = try LexValue.record(json: Data(#"""
    { "$type": "com.example.note", "text": "hello", "createdAt": "2026-01-01T00:00:00.000Z" }
    """#.utf8))

    try catalog.validateRecord(record, collection: "com.example.note", recordKey: "3jzfcijpj2z2a")
}
```

`validateRecord` requires an object whose `$type` is exactly the collection,
then enforces the record schema: `required` and `nullable`; string length in
UTF-8 bytes and in grapheme clusters; every string `format`; `enum` and
`const`; integer ranges; bytes and array lengths; blob `accept` patterns and
`maxSize`; open and closed unions; and references into any document in the
catalog. Properties the schema does not define are ignored, as the
specification requires. Passing `recordKey` also checks the key against the
record's `key` type.

A catalog is a value type. Build it once, then share copies freely across
tasks.

A whole directory of Lexicon files loads in one call; subdirectories are
searched.

<!-- Mirrors DocumentationSnippetTests.documentationLoadDirectory -->

<!-- compile-example: lexicon-load-directory -->
```swift
import Foundation
import PetrelLexicon

func loadCatalog(lexiconsDirectory: URL) throws -> LexiconCatalog {
    var catalog = LexiconCatalog()
    try catalog.add(contentsOfDirectory: lexiconsDirectory)
    return catalog
}
```

## Read the issues

``LexiconValidationError`` carries every problem found, each with a JSON
pointer into the value and a stable reason code.

<!-- Mirrors DocumentationSnippetTests.documentationReadIssues -->

<!-- compile-example: lexicon-read-issues -->
```swift
import PetrelLexicon

// `catalog` holds the com.example.note schema.
func describeProblems(catalog: LexiconCatalog) throws -> [String] {
    let record: LexValue = [
        "$type": "com.example.note",
        "text": "hello",
        "createdAt": "yesterday",
        "langs": ["en", "not a language"],
    ]

    var report: [String] = []
    do {
        try catalog.validateRecord(record, collection: "com.example.note")
    } catch let error as LexiconValidationError {
        for issue in error.issues {
            report.append("\(issue.path): \(issue.code.rawValue)")
        }
    }
    // report == ["/createdAt: stringFormatMismatch", "/langs/1: stringFormatMismatch"]
    return report
}
```

## Unknown Lexicon versus invalid data

A PDS may validate "optimistically": check a record when it knows the Lexicon,
accept it when it does not. That needs "there is no such schema" to be a
different outcome from "the data is wrong", so the first is a
``LexiconCatalogError`` and the second a ``LexiconValidationError``.

<!-- Mirrors DocumentationSnippetTests.documentationOptimisticValidation -->

<!-- compile-example: lexicon-optimistic-validation -->
```swift
import PetrelLexicon

enum Outcome { case valid, unknownLexicon, invalid }

func check(_ record: LexValue, catalog: LexiconCatalog) -> Outcome {
    let outcome: Outcome
    do {
        try catalog.validateRecord(record, collection: "org.unknown.thing")
        outcome = .valid
    } catch LexiconCatalogError.definitionNotFound {
        // No schema for this collection: an "optimistic" writer accepts
        // the record, a "required" one refuses it.
        outcome = .unknownLexicon
    } catch {
        outcome = .invalid
    }
    return outcome
}
```

A schema can also refer to a definition in a Lexicon the catalog does not
hold. Data that reaches such a reference fails with the issue code
`unresolvedReference`, because it can not be checked. To find those gaps ahead
of time, ask the catalog for its `referenceProblems()`.

## Strict data-model parsing

``LexValue`` parses JSON with its own parser rather than `JSONSerialization`,
because the data model depends on distinctions Foundation does not keep: an
integer is not a float, a repeated key is an error, and `{"$link": …}` with a
second key is neither a link nor an ordinary object.

<!-- Mirrors DocumentationSnippetTests.documentationStrictParsing -->

<!-- compile-example: lexicon-strict-parsing -->
```swift
import Foundation
import PetrelLexicon

func strictParsing() throws {
    // A float is not part of the data model.
    do {
        _ = try LexValue(json: Data(#"{"ratio": 0.5}"#.utf8))
    } catch let error as LexValueError {
        assert(error.code == .floatNotAllowed && error.path == "/ratio")
    }

    // Links and bytes come out typed.
    let value = try LexValue(json: Data(#"""
    {"ref": {"$link": "bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a"}, "sig": {"$bytes": "aGVsbG8"}}
    """#.utf8))
    let link = value["ref"]?.cidValue       // a CID with codec .dagCBOR
    let bytes = value["sig"]?.bytesValue    // 5 bytes: "hello"
    _ = (link, bytes)
}
```

Two rules are deliberately opt-in, through `LexValue.ParseOptions`, because
deployed data and the official interop vectors do not meet them:

- `requireRawBlobCIDs`: the blob specification says a blob reference uses the
  `raw` codec, but the official `record-data-valid.json` vector carries a
  `dag-cbor` reference, so the default accepts both.
- Legacy `{cid, mimeType}` blobs have no `$type` and can not be recognised
  without a schema. They are read where a schema expects a blob (controlled by
  `LexiconValidationOptions.allowLegacyBlobs`) and are never written.

## Canonical bytes and CIDs

A ``LexValue`` encodes to canonical DAG-CBOR (DRISL) and hashes to the CID a
PDS would compute for the same record.

<!-- Mirrors DocumentationSnippetTests.documentationCanonicalBytes -->

<!-- compile-example: lexicon-canonical-bytes -->
```swift
import PetrelLexicon

func canonicalForm() throws {
    let record: LexValue = ["$type": "com.example.note", "text": "hello", "createdAt": "2026-01-01T00:00:00.000Z"]

    let bytes = try record.dagCBOR()
    let cid = try record.cid()
    _ = (bytes, cid)
}
```

## Validate what Petrel's typed API produces

Any `Encodable` value converts to a ``LexValue``, including Petrel's generated
record types and `ATProtocolValueContainer`. The conversion goes through the
strict parser, so a typed value is held to the same rules as wire data.

<!-- Mirrors DocumentationSnippetTests.documentationTypedRecord -->

<!-- compile-example: lexicon-typed-record -->
```swift
import Foundation
import Petrel
import PetrelLexicon

func postAsLexValue() throws -> LexValue {
    let post = AppBskyFeedPost(
        text: "hello",
        createdAt: ATProtocolDate(date: Date(timeIntervalSince1970: 1_767_225_600))
    )

    let record = try LexValue(encoding: post)
    // record.type == "app.bsky.feed.post"
    return record
}
```

### The Lexicons Petrel is built from

The schemas behind Petrel's generated types are compiled into this module.
``LexiconCatalog/bundled()`` returns them as a catalog, and
``LexiconCatalog/validateRecord(_:recordKey:options:)`` takes a
generated value directly: the type's `typeIdentifier` names the schema. This is
how to enforce what the Swift types do not carry — a post's `text` is a
`String`, and only its Lexicon says it may hold at most 300 graphemes.

<!-- Mirrors BundledCatalogTests.validGeneratedRecordPasses and constraintViolationsAreReported -->

<!-- compile-example: lexicon-bundled-catalog -->
```swift
import Petrel
import PetrelLexicon

func checkPosts(post: AppBskyFeedPost, tooLongPost: AppBskyFeedPost) throws {
    let catalog = try LexiconCatalog.bundled()

    try catalog.validateRecord(post)
    try catalog.validateRecord(post, recordKey: "3jwdwj2ctlk26")

    do {
        try catalog.validateRecord(tooLongPost)
    } catch let error as LexiconValidationError {
        assert(error.contains(.stringTooManyGraphemes, at: "/text"))
    }
}
```

For Lexicons of your own, generate the same kind of bundle with the
`lexicon_documents` manifest option of Petrel's code generator and add the
documents to a catalog with ``LexiconCatalog/add(json:options:replaceExisting:)``.

## XRPC parameters and bodies

Query strings are untyped, so parameters are coerced by their declared type
before they are checked: `boolean` accepts exactly `true` or `false`,
`integer` a decimal that fits 64 bits, and an `array` parameter collects every
occurrence of its name. Declared defaults are filled in, and the typed result
is returned.

<!-- Mirrors DocumentationSnippetTests.documentationXRPCParameters -->

<!-- compile-example: lexicon-xrpc-parameters -->
```swift
import Foundation
import PetrelLexicon

// `catalog` holds the com.example.search query schema.
func checkSearch(catalog: LexiconCatalog) throws {
    let url = "https://example.com/xrpc/com.example.search?q=cats&tag=a&tag=b"
    let queryItems = URLComponents(string: url)?.queryItems ?? []
    let parameters = try catalog.validateXRPCParameters(queryItems, nsid: "com.example.search")
    // parameters["q"] == "cats", parameters["limit"] == 25 (the default), parameters["tag"] == ["a", "b"]
    _ = parameters

    try catalog.validateXRPCOutput(
        ["hits": ["at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/com.example.note/3jzfcijpj2z2a"]],
        nsid: "com.example.search"
    )
}
```

`validateXRPCInput` does the same for a procedure's request body. An endpoint
that declares no schema for a body accepts any body.

## Subscription messages

Union members normally carry a `$type`. Event-stream messages are the one
exception: the variant is named by the frame header, so pass the header's `t`
alongside the body.

<!-- Mirrors DocumentationSnippetTests.documentationSubscriptionMessage -->

<!-- compile-example: lexicon-subscription-message -->
```swift
import PetrelLexicon

// `catalog` holds the com.example.stream subscription schema.
func checkTick(catalog: LexiconCatalog) throws {
    // An event-stream frame is a header ({"op": 1, "t": "#tick"}) followed
    // by a body that has no `$type` of its own.
    let body: LexValue = ["seq": 42]
    try catalog.validateSubscriptionMessage(body, nsid: "com.example.stream", type: "#tick")
}
```

## Permission sets

A `permission-set` definition is kept as written, because the set of
resources and parameters is expected to grow. Interpreting it is a separate,
deliberately conservative step: `grants(publishedAs:)` returns only the
declarations a service may act on. A declaration is dropped when its resource
is not `repo` or `rpc`, when it carries a parameter this version does not
know, when a parameter is malformed or uses a wildcard, and when it names a
collection or endpoint outside the namespace of the set's own NSID.

<!-- Mirrors DocumentationSnippetTests.documentationPermissionSet -->

<!-- compile-example: lexicon-permission-set -->
```swift
import PetrelLexicon

func describeGrants(catalog: LexiconCatalog) -> [String] {
    var granted: [String] = []

    guard case let .permissionSet(set)? = catalog.definition("com.example.calendar.authBasic") else { return [] }

    for grant in set.grants(publishedAs: "com.example.calendar.authBasic") {
        switch grant {
        case let .repo(collections, actions):
            // Write access to `collections`, limited to `actions` when not nil.
            granted.append("repo \(collections) \(actions ?? ["create", "update", "delete"])")
        case let .rpc(methods, inheritAudience):
            // Calls to `methods`, against any audience or the inherited one.
            granted.append("rpc \(methods) \(inheritAudience ? "inherited audience" : "any audience")")
        }
    }
    return granted
}
```

## Schemas beyond Lexicon version 1

By default a document must be exactly Lexicon version 1. A schema that tracks
a draft of the language can be loaded with ``LexiconSchemaOptions``:
`allowUnknownStringFormats` treats an unrecognised `format` as an
unconstrained string, and `allowUnknownDefinitionTypes` keeps a definition of
an unrecognised `type` verbatim. Data never validates against such a
definition; it fails with the issue code `unsupportedSchemaType`.
