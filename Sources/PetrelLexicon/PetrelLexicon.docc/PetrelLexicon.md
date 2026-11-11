# ``PetrelLexicon``

Read Lexicon schemas at runtime, validate data against them, and resolve
schemas from the network.

## Overview

Petrel's generated API covers the Lexicons it was built with. `PetrelLexicon`
is for everything else: schemas that arrive as JSON, records of types the
application has never seen, and servers that must check what clients send.

It has three parts.

- ``LexValue`` is a strict value of the AT Protocol data model. It parses JSON
  and DAG-CBOR, rejects what the data model forbids (floats, malformed `$link`
  / `$bytes` / blob objects, a `$type` that is not a non-empty string), and
  writes canonical DAG-CBOR and CIDs.
- ``LexiconDoc`` models a Lexicon document, covering every type of Lexicon
  version 1, and checks it against the rules of the language.
- ``LexiconCatalog`` holds documents and validates records, XRPC parameters,
  request and response bodies, and subscription messages against them.

<!-- Mirrors DocumentationSnippetTests.documentationValidateRecord -->

```swift
import PetrelLexicon

var catalog = LexiconCatalog()
try catalog.add(json: schemaJSON)

let record = try LexValue.record(json: Data(#"""
{ "$type": "com.example.note", "text": "hello", "createdAt": "2026-01-01T00:00:00.000Z" }
"""#.utf8))

try catalog.validateRecord(record, collection: "com.example.note", recordKey: "3jzfcijpj2z2a")
```

Every failure is a typed error that says where and why: ``LexValueError`` for
data that is not valid under the data model, ``LexiconSchemaError`` for a
document that is not a valid Lexicon, ``LexiconValidationError`` for data that
breaks its schema, and ``LexiconCatalogError`` when the schema asked for is
not in the catalog.

The behaviour is pinned to the official
[atproto-interop-tests](https://github.com/bluesky-social/atproto-interop-tests)
files, which the test suite runs in full: `data-model`, `lexicon` (including
its `catalog`), and `syntax`.

## Topics

### Guides

- <doc:RuntimeValidation>
- <doc:LexiconResolution>

### Data model values

- ``LexValue``
- ``LexBlobRef``
- ``LexValueError``

### Lexicon documents

- ``LexiconDoc``
- ``LexiconDef``
- ``LexiconReference``
- ``LexiconSchemaOptions``
- ``LexiconSchemaError``
- ``LexStringFormat``

### Definition types

- ``LexRecord``
- ``LexRecordKeyType``
- ``LexXRPCQuery``
- ``LexXRPCProcedure``
- ``LexXRPCSubscription``
- ``LexXRPCMessage``
- ``LexXRPCBody``
- ``LexXRPCError``
- ``LexParams``
- ``LexPermissionSet``
- ``LexPermission``
- ``LexObject``
- ``LexArray``
- ``LexToken``
- ``LexString``
- ``LexInteger``
- ``LexBoolean``
- ``LexBytes``
- ``LexCIDLink``
- ``LexBlob``
- ``LexUnknown``
- ``LexRef``
- ``LexUnion``
- ``LexUnsupportedDef``

### Validation

- ``LexiconCatalog``
- ``LexiconValidationOptions``
- ``LexiconValidationError``
- ``LexiconValidationIssue``
- ``LexiconCatalogError``

### Resolution

- ``LexiconResolver``
- ``DefaultLexiconResolver``
- ``ResolvedLexicon``
- ``LexiconAuthority``
- ``LexiconResolutionCache``
- ``LexiconResolutionError``
- ``LexiconDNSTXTResolving``
- ``LexiconDIDDocumentResolving``
- ``LexiconRecordFetching``
- ``LexiconFetchedRecord``
- ``LexiconHTTPRecordFetcher``
- ``LexiconHTTPTransport``
- ``LexiconHTTPError``
- ``lexiconSchemaCollection``
