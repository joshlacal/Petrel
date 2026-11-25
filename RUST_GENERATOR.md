# Rust code generator

The Petrel generator includes a Rust code generation backend that emits owned, deterministic Rust models, open/closed unions, string enums, XRPC endpoint descriptors (`petrel_core::XrpcRequest` / `Collection`), and module trees from AT Protocol Lexicon definitions.

## Generator architecture

```
generator/
├── main.py                         # CLI entrypoint, manifest runner, Rust module tree + feature graph
├── base_code_generator.py          # Abstract base generator class & Lexicon schema validation
├── rust_code_generator.py          # Rust code generator
├── rust_type_converter.py          # Lexicon to Rust type mapping, naming, and SCC cycle boxing
├── rust_enum_generator.py          # Unions, named knownValues enums, and closed string enums
├── rust_templates.py               # Jinja2 template manager for Rust
├── manifests/
│   └── petrel-core.json            # Manifest configuring `rust` output and feature gating
└── templates/rust/                 # Jinja2 templates
    ├── module.rs.jinja
    ├── struct.rs.jinja
    ├── parameters.rs.jinja
    ├── errors.rs.jinja
    ├── endpoint.rs.jinja
    ├── subscription.rs.jinja
    ├── space.rs.jinja
    ├── type_alias.rs.jinja
    └── strict_ref_helper.rs.jinja
```

## Type mappings

| Lexicon type | Rust type | Notes |
|---|---|---|
| `string` | `String` | Plain string or inline `knownValues` |
| `string` (`did`, `handle`, `at-identifier`, `nsid`, `at-uri`, `space-ref`, `uri`, `tid`, `record-key`, `datetime`, `language`, `cid`) | `petrel_core::{Did, Handle, AtIdentifier, Nsid, AtUri, SpaceRef, Uri, Tid, RecordKey, Datetime, Language, CidString}` | Owned validated newtypes preserving original wire string |
| `string` (`enum`) | `enum` | Closed enum with hand-written serde; unknown values fail |
| `string` (`knownValues`, named def) | `enum` with `Other(String)` | Open enum implementing `Display`, `FromStr`, `ToValue`, `FromValue`, `QueryValue`, `Serialize`, `Deserialize` |
| `integer` | `i64` | Always 64-bit signed integer |
| `boolean` | `bool` | Primitive boolean |
| `bytes` | `petrel_core::Bytes` | JSON `{"$bytes": ...}` / CBOR byte string |
| `cid-link` | `petrel_core::CidLink` | JSON `{"$link": ...}` / CBOR tag 42 |
| `blob` | `petrel_core::Blob` | Modern typed blob and legacy `{cid, mimeType}` |
| `unknown` | `petrel_core::Value` | Data-model value (floats rejected) |
| `array` | `Vec<T>` | Heap-allocated sequence |
| `union` | `enum` with `Box<T>` arms | Open unions include `Unknown(petrel_core::Value)`; closed unions reject unknown `$type` |
| `object` (no `properties`) | `std::collections::BTreeMap<String, petrel_core::Value>` | Untyped map |
| `number` / unknown type | Generator `ValueError` | Rejected at generation time |

### Nullability and optionality

- Required, non-nullable: `T` (`ObjectReader::required`, `ObjectWriter::field`)
- Optional, non-nullable: `Option<T>` (`ObjectReader::optional` on objects/records/outputs, `ObjectReader::optional_strict` on XRPC inputs)
- Required, nullable: `Option<T>` (`ObjectReader::required_nullable`, `ObjectWriter::required_nullable`; key must be present on wire)
- Optional, nullable (tri-state): `Option<petrel_core::Nullable<T>>` (`ObjectReader::optional_nullable`, `ObjectWriter::optional_nullable`)

## Run the generator

To generate Rust files for `petrel-api`:

```bash
python3 run.py --manifest generator/manifests/petrel-core.json --language rust
```

To verify zero drift without writing:

```bash
petrel-gen generate --manifest generator/manifests/petrel-core.json --language rust --check
```

### Formatting behavior

Like Kotlin, generated Rust output has **no post-format step** (`#[rustfmt::skip] pub mod generated;` in `rust/petrel-api/src/lib.rs`). Templates emit final deterministic bytes, verified by CI drift checks (`git diff --exit-code -- rust/petrel-api/src/generated`) and SHA-256 stability tests.

## Crate structure and features

Generated code for `petrel-api` is written under `rust/petrel-api/src/generated/`, mirroring each Lexicon NSID as a snake_case module path (for example `app::bsky::feed::post::Post`). Cross-namespace references in `rust/petrel-api/Cargo.toml` are gated by top-level 2-segment features (`app_bsky`, `chat_bsky`, `com_atproto`, `com_germnetwork`, `network_bsky`, `site_standard`) with computed implication edges.
