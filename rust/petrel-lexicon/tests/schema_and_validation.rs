use std::collections::BTreeMap;

use petrel_core::{Cid, Datetime, Did, ToValue, Value};
use petrel_lexicon::{
    LexValue, LexiconCatalog, LexiconCatalogError, LexiconDoc, LexiconSchemaError,
    LexiconSchemaOptions, LexiconValidationError, LexiconValidationOptions, ParseOptions,
};
use serde::Deserialize;

#[derive(Deserialize)]
struct ValidLexiconCase {
    name: String,
    lexicon: serde_json::Value,
}

#[derive(Deserialize)]
struct InvalidLexiconCase {
    name: String,
    lexicon: serde_json::Value,
}

#[derive(Deserialize)]
struct RecordDataCase {
    name: String,
    rkey: Option<String>,
    data: serde_json::Value,
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn official_lexicon_valid_and_invalid_vectors() {
    let valid_raw =
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/lexicon/lexicon-valid.json");
    let valid_cases: Vec<ValidLexiconCase> =
        serde_json::from_str(valid_raw).expect("parse lexicon-valid.json");
    assert!(!valid_cases.is_empty());
    for case in valid_cases {
        let bytes = serde_json::to_vec(&case.lexicon).unwrap();
        let doc = LexiconDoc::from_json_bytes(&bytes)
            .unwrap_or_else(|e| panic!("lexicon-valid {:?} decode failed: {e}", case.name));
        doc.validate(LexiconSchemaOptions::strict())
            .unwrap_or_else(|e| panic!("lexicon-valid {:?} validate failed: {e}", case.name));
    }

    let invalid_raw =
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/lexicon/lexicon-invalid.json");
    let invalid_cases: Vec<InvalidLexiconCase> =
        serde_json::from_str(invalid_raw).expect("parse lexicon-invalid.json");
    assert_eq!(invalid_cases.len(), 7);
    for case in invalid_cases {
        let bytes = serde_json::to_vec(&case.lexicon).unwrap();
        let ok = LexiconDoc::from_json_bytes(&bytes)
            .ok()
            .and_then(|doc| doc.validate(LexiconSchemaOptions::strict()).ok())
            .is_some();
        assert!(
            !ok,
            "expected lexicon-invalid {:?} to fail decode or strict validation",
            case.name
        );
    }
}

fn vector_catalog() -> LexiconCatalog {
    let mut catalog = LexiconCatalog::new();
    for raw in [
        include_bytes!(
            "../../../Tests/PetrelLexiconTests/Vectors/lexicon/catalog/permission-set.json"
        )
        .as_slice(),
        include_bytes!("../../../Tests/PetrelLexiconTests/Vectors/lexicon/catalog/procedure.json")
            .as_slice(),
        include_bytes!("../../../Tests/PetrelLexiconTests/Vectors/lexicon/catalog/query.json")
            .as_slice(),
        include_bytes!("../../../Tests/PetrelLexiconTests/Vectors/lexicon/catalog/record.json")
            .as_slice(),
        include_bytes!(
            "../../../Tests/PetrelLexiconTests/Vectors/lexicon/catalog/subscription.json"
        )
        .as_slice(),
    ] {
        catalog
            .add_json(raw, LexiconSchemaOptions::strict())
            .unwrap();
    }
    catalog
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn official_record_data_valid_vectors() {
    let catalog = vector_catalog();

    let raw =
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/lexicon/record-data-valid.json");
    let cases: Vec<RecordDataCase> =
        serde_json::from_str(raw).expect("parse record-data-valid.json");
    assert!(!cases.is_empty());

    for case in cases {
        let record_bytes = serde_json::to_vec(&case.data).unwrap();
        let val = LexValue::from_record_json_bytes(&record_bytes, ParseOptions::standard())
            .unwrap_or_else(|e| panic!("case {:?} parse record failed: {e}", case.name));
        let collection = val
            .as_object()
            .and_then(|m| m.get("$type"))
            .and_then(Value::as_str)
            .unwrap_or_else(|| panic!("case {:?} missing $type", case.name));
        catalog
            .validate_record_value(
                collection,
                val.inner(),
                case.rkey.as_deref(),
                LexiconValidationOptions::standard(),
            )
            .unwrap_or_else(|e| panic!("case {:?} validation failed: {e}", case.name));
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn bundled_catalog_loads_all_core_schemas_and_strict_rejects_spaces() {
    let catalog = LexiconCatalog::bundled().expect("bundled catalog should load cleanly");
    assert_eq!(catalog.len(), LexiconCatalog::bundled_count());
    assert!(catalog.len() >= 370);
    assert!(catalog.document("app.bsky.feed.post").is_some());
    assert!(catalog.document("com.atproto.space.applyWrites").is_some());

    // Strict schema check must reject the permissioned-spaces draft lexicon (`space-ref`)
    let space_doc = catalog.document("com.atproto.space.applyWrites").unwrap();
    assert!(matches!(
        space_doc.validate(LexiconSchemaOptions::strict()),
        Err(LexiconSchemaError::UnknownStringFormat { .. })
    ));

    // Validate a real generated post record against the bundled catalog
    let mut post = petrel_api::generated::app::bsky::feed::post::Post::new(
        "Hello from Rust Petrel!".to_owned(),
        Datetime::parse("2026-01-01T00:00:00Z").unwrap(),
    );
    catalog
        .validate_record(
            &post,
            Some("3jui7kd54zh2y"),
            LexiconValidationOptions::standard(),
        )
        .expect("valid post must pass");

    // Exceed maxGraphemes (300) using emoji ZWJ sequences
    post.text = "👨‍👩‍👧‍👧".repeat(301);
    let err = catalog
        .validate_record(&post, None, LexiconValidationOptions::standard())
        .unwrap_err();
    assert!(matches!(
        err,
        LexiconValidationError::ConstraintViolation { .. }
    ));

    // Invalid TID key for app.bsky.feed.post (key: "tid")
    "ok".clone_into(&mut post.text);
    let bad_key = catalog
        .validate_record(
            &post,
            Some("not-a-tid!"),
            LexiconValidationOptions::standard(),
        )
        .unwrap_err();
    assert!(matches!(
        bad_key,
        LexiconValidationError::RecordKeyInvalid { .. }
    ));
}

#[cfg(not(target_arch = "wasm32"))]
#[test]
fn bundled_catalog_matches_on_disk_lexicon_corpus() {
    let corpus_dir =
        std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../generator/lexicons");
    if !corpus_dir.is_dir() {
        return;
    }
    let bundled = LexiconCatalog::bundled().unwrap();
    let mut from_disk = LexiconCatalog::new();
    from_disk
        .add_directory(&corpus_dir, LexiconSchemaOptions::lenient())
        .expect("load generator/lexicons from disk");
    for (nsid, doc) in bundled.iter() {
        let disk_doc = from_disk
            .document(nsid)
            .unwrap_or_else(|| panic!("bundled document {nsid} missing from generator/lexicons"));
        assert_eq!(doc, disk_doc, "corpus drift on {nsid}");
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn constraints_nullable_unions_tokens_and_blobs() {
    let schema_json = br##"{
      "lexicon": 1,
      "id": "com.example.testRecord",
      "defs": {
        "main": {
          "type": "record",
          "key": "literal:self",
          "record": {
            "type": "object",
            "required": ["label", "note", "kind", "attachment", "item"],
            "nullable": ["note"],
            "properties": {
              "label": {"type": "string", "minLength": 2, "maxLength": 10, "enum": ["alpha", "beta"]},
              "note": {"type": "string"},
              "kind": {"type": "ref", "ref": "#marker"},
              "attachment": {"type": "blob", "accept": ["image/*"], "maxSize": 1024},
              "item": {"type": "union", "closed": true, "refs": ["#branchA"]},
              "openItem": {"type": "union", "closed": false, "refs": ["#branchA"]}
            }
          }
        },
        "marker": {"type": "token"},
        "branchA": {
          "type": "object",
          "required": ["count"],
          "properties": {"count": {"type": "integer", "minimum": 1, "maximum": 5}}
        }
      }
    }"##;

    let mut catalog = LexiconCatalog::new();
    catalog
        .add_json(schema_json, LexiconSchemaOptions::strict())
        .unwrap();

    // Duplicate ID rejected
    assert!(matches!(
        catalog.add_json(schema_json, LexiconSchemaOptions::strict()),
        Err(LexiconCatalogError::DuplicateId { .. })
    ));

    let blob_cid = Cid::for_raw(b"img-bytes");
    let mut blob_map = BTreeMap::new();
    blob_map.insert("$type".to_owned(), Value::String("blob".to_owned()));
    blob_map.insert("ref".to_owned(), Value::Link(blob_cid));
    blob_map.insert("mimeType".to_owned(), Value::String("image/png".to_owned()));
    blob_map.insert("size".to_owned(), Value::Integer(512));

    let mut branch = BTreeMap::new();
    branch.insert(
        "$type".to_owned(),
        Value::String("com.example.testRecord#branchA".to_owned()),
    );
    branch.insert("count".to_owned(), Value::Integer(3));

    let mut open_branch = BTreeMap::new();
    open_branch.insert(
        "$type".to_owned(),
        Value::String("com.example.other#future".to_owned()),
    );

    let mut record = BTreeMap::new();
    record.insert(
        "$type".to_owned(),
        Value::String("com.example.testRecord".to_owned()),
    );
    record.insert("label".to_owned(), Value::String("alpha".to_owned()));
    record.insert("note".to_owned(), Value::Null);
    record.insert(
        "kind".to_owned(),
        Value::String("com.example.testRecord#marker".to_owned()),
    );
    record.insert("attachment".to_owned(), Value::Object(blob_map));
    record.insert("item".to_owned(), Value::Object(branch));
    record.insert("openItem".to_owned(), Value::Object(open_branch));

    let rec_val = Value::Object(record.clone());
    catalog
        .validate_record_value(
            "com.example.testRecord",
            &rec_val,
            Some("self"),
            LexiconValidationOptions::strict(),
        )
        .expect("valid testRecord");

    // Raw record missing `$type` is rejected
    let mut missing_type = record.clone();
    missing_type.remove("$type");
    assert!(matches!(
        catalog.validate_record_value(
            "com.example.testRecord",
            &Value::Object(missing_type),
            Some("self"),
            LexiconValidationOptions::strict()
        ),
        Err(LexiconValidationError::MissingRequiredField { ref field, .. }) if field == "$type"
    ));

    // Raw record mismatched `$type` is rejected
    let mut wrong_type = record.clone();
    wrong_type.insert(
        "$type".to_owned(),
        Value::String("com.example.other".to_owned()),
    );
    assert!(matches!(
        catalog.validate_record_value(
            "com.example.testRecord",
            &Value::Object(wrong_type),
            Some("self"),
            LexiconValidationOptions::strict()
        ),
        Err(LexiconValidationError::RecordTypeMismatch { .. })
    ));

    // Typed `Collection + ToValue` omitting `$type` still validates cleanly
    {
        struct TypelessPost(String);
        impl petrel_core::Collection for TypelessPost {
            const NSID: &'static str = "app.bsky.feed.post";
            const KEY: petrel_core::RecordKeyType = petrel_core::RecordKeyType::Tid;
        }
        impl petrel_core::ToValue for TypelessPost {
            fn to_value(&self) -> Result<Value, petrel_core::EncodeError> {
                let mut m = BTreeMap::new();
                m.insert("text".to_owned(), Value::String(self.0.clone()));
                m.insert(
                    "createdAt".to_owned(),
                    Value::String("2026-01-01T00:00:00Z".to_owned()),
                );
                Ok(Value::Object(m))
            }
        }
        LexiconCatalog::bundled()
            .unwrap()
            .validate_record(
                &TypelessPost("hello".to_owned()),
                Some("3jui7kd54zh2y"),
                LexiconValidationOptions::standard(),
            )
            .expect("typed record without explicit $type should inject T::NSID");
    }

    // Non-self key fails
    assert!(matches!(
        catalog.validate_record_value(
            "com.example.testRecord",
            &rec_val,
            Some("other"),
            LexiconValidationOptions::strict()
        ),
        Err(LexiconValidationError::RecordKeyInvalid { .. })
    ));

    // Closed union rejects unknown member
    let mut bad_union = record.clone();
    let mut unknown = BTreeMap::new();
    unknown.insert(
        "$type".to_owned(),
        Value::String("com.example.other".to_owned()),
    );
    bad_union.insert("item".to_owned(), Value::Object(unknown));
    assert!(matches!(
        catalog.validate_record_value(
            "com.example.testRecord",
            &Value::Object(bad_union),
            None,
            LexiconValidationOptions::strict()
        ),
        Err(LexiconValidationError::UnionMismatch { .. })
    ));

    // Blob wrong MIME rejected
    let mut bad_mime = record.clone();
    if let Some(Value::Object(b)) = bad_mime.get_mut("attachment") {
        b.insert("mimeType".to_owned(), Value::String("video/mp4".to_owned()));
    }
    assert!(matches!(
        catalog.validate_record_value(
            "com.example.testRecord",
            &Value::Object(bad_mime),
            None,
            LexiconValidationOptions::strict()
        ),
        Err(LexiconValidationError::BlobValidation { .. })
    ));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn xrpc_query_params_input_output_and_subscription_validation() {
    let catalog = LexiconCatalog::bundled().unwrap();

    // app.bsky.feed.getAuthorFeed query params
    let actor = Did::parse("did:plc:ewvi7nxzyoun6zhxrhs64oiz").unwrap();
    catalog
        .validate_xrpc_query_params(
            "app.bsky.feed.getAuthorFeed",
            &[("actor", actor.as_str()), ("limit", "50")],
            LexiconValidationOptions::standard(),
        )
        .expect("valid query params");

    // Out-of-range limit (max 100) rejected
    assert!(matches!(
        catalog.validate_xrpc_query_params(
            "app.bsky.feed.getAuthorFeed",
            &[("actor", actor.as_str()), ("limit", "101")],
            LexiconValidationOptions::standard(),
        ),
        Err(LexiconValidationError::ConstraintViolation { .. })
    ));

    // Missing required param rejected
    assert!(matches!(
        catalog.validate_xrpc_query_params(
            "app.bsky.feed.getAuthorFeed",
            &[("limit", "10")],
            LexiconValidationOptions::standard(),
        ),
        Err(LexiconValidationError::MissingRequiredField { .. })
    ));

    // Procedure input validation: com.atproto.repo.deleteRecord
    let mut delete_input = BTreeMap::new();
    delete_input.insert("repo".to_owned(), Value::String(actor.to_string()));
    delete_input.insert(
        "collection".to_owned(),
        Value::String("app.bsky.feed.post".to_owned()),
    );
    delete_input.insert("rkey".to_owned(), Value::String("3jui7kd54zh2y".to_owned()));
    catalog
        .validate_xrpc_input(
            "com.atproto.repo.deleteRecord",
            &Value::Object(delete_input),
            LexiconValidationOptions::standard(),
        )
        .expect("valid deleteRecord input");

    // Output validation: com.atproto.server.describeServer
    let mut output = BTreeMap::new();
    output.insert("did".to_owned(), Value::String(actor.to_string()));
    output.insert(
        "availableUserDomains".to_owned(),
        Value::Array(vec![Value::String(".bsky.social".to_owned())]),
    );
    catalog
        .validate_xrpc_output(
            "com.atproto.server.describeServer",
            &Value::Object(output),
            LexiconValidationOptions::standard(),
        )
        .expect("valid describeServer output");

    // Subscription message validation: com.atproto.sync.subscribeRepos (#info)
    let mut info_msg = BTreeMap::new();
    info_msg.insert(
        "$type".to_owned(),
        Value::String("com.atproto.sync.subscribeRepos#info".to_owned()),
    );
    info_msg.insert(
        "name".to_owned(),
        Value::String("OutdatedCursor".to_owned()),
    );
    catalog
        .validate_xrpc_message(
            "com.atproto.sync.subscribeRepos",
            &Value::Object(info_msg),
            LexiconValidationOptions::standard(),
        )
        .expect("valid subscribeRepos #info message");

    // Generated subscription body (no `$type`) validated with frame header selector `t`
    let generated_info = petrel_api::generated::com::atproto::sync::subscribe_repos::Info::new(
        "OutdatedCursor".to_owned(),
    )
    .to_value()
    .unwrap();
    assert!(!generated_info.as_object().unwrap().contains_key("$type"));
    catalog
        .validate_xrpc_message_with_type(
            "com.atproto.sync.subscribeRepos",
            Some("#info"),
            &generated_info,
            LexiconValidationOptions::standard(),
        )
        .expect("frame header t='#info' selects union member without mutating payload");

    // Invalid frame header selector rejected on closed subscription union? (subscribeRepos union is open,
    // so also test a closed subscription union + a payload carrying `t` directly)
    let mut info_with_t = generated_info.as_object().unwrap().clone();
    info_with_t.insert("t".to_owned(), Value::String("#info".to_owned()));
    catalog
        .validate_xrpc_message(
            "com.atproto.sync.subscribeRepos",
            &Value::Object(info_with_t),
            LexiconValidationOptions::standard(),
        )
        .expect("payload carrying frame field 't' validates without '$type'");
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn official_record_data_invalid_vectors() {
    let catalog = vector_catalog();

    let raw =
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/lexicon/record-data-invalid.json");
    let cases: Vec<RecordDataCase> =
        serde_json::from_str(raw).expect("parse record-data-invalid.json");
    assert_eq!(cases.len(), 50);

    for case in cases {
        let record_bytes = serde_json::to_vec(&case.data).unwrap();
        let ok = match LexValue::from_record_json_bytes(&record_bytes, ParseOptions::standard()) {
            Ok(val) => {
                let collection = val
                    .as_object()
                    .and_then(|m| m.get("$type"))
                    .and_then(Value::as_str)
                    .unwrap_or_else(|| panic!("case {:?} missing $type", case.name));
                catalog
                    .validate_record_value(
                        collection,
                        val.inner(),
                        case.rkey.as_deref(),
                        LexiconValidationOptions::standard(),
                    )
                    .is_ok()
            }
            Err(_) => false,
        };
        assert!(
            !ok,
            "expected record-data-invalid {:?} to be rejected",
            case.name
        );
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn ref_to_record_enforces_type_and_unknown_rejects_blobs() {
    let catalog = LexiconCatalog::bundled().unwrap();
    let actor = Did::parse("did:plc:ewvi7nxzyoun6zhxrhs64oiz").unwrap();
    let schema_cid = Cid::for_raw(b"lexicon-schema-bytes");

    let mut schema_record = BTreeMap::new();
    schema_record.insert(
        "$type".to_owned(),
        Value::String("com.atproto.lexicon.schema".to_owned()),
    );
    schema_record.insert("lexicon".to_owned(), Value::Integer(1));

    let mut resolve_out = BTreeMap::new();
    resolve_out.insert("cid".to_owned(), Value::String(schema_cid.to_string()));
    resolve_out.insert(
        "uri".to_owned(),
        Value::String(format!(
            "at://{actor}/com.atproto.lexicon.schema/app.bsky.feed.post"
        )),
    );
    resolve_out.insert("schema".to_owned(), Value::Object(schema_record.clone()));

    catalog
        .validate_xrpc_output(
            "com.atproto.lexicon.resolveLexicon",
            &Value::Object(resolve_out.clone()),
            LexiconValidationOptions::strict(),
        )
        .expect("resolveLexicon output with matching referenced record $type validates");

    // Missing `$type` on referenced record fails at `/schema`
    let mut missing_schema_type = schema_record.clone();
    missing_schema_type.remove("$type");
    let mut out_missing = resolve_out.clone();
    out_missing.insert("schema".to_owned(), Value::Object(missing_schema_type));
    assert!(matches!(
        catalog.validate_xrpc_output(
            "com.atproto.lexicon.resolveLexicon",
            &Value::Object(out_missing),
            LexiconValidationOptions::strict(),
        ),
        Err(LexiconValidationError::MissingRequiredField { ref path, ref field })
            if path == "/schema" && field == "$type"
    ));

    // Mismatched `$type` on referenced record fails at `/schema/$type`
    let mut wrong_schema_type = schema_record.clone();
    wrong_schema_type.insert(
        "$type".to_owned(),
        Value::String("app.bsky.feed.post".to_owned()),
    );
    let mut out_wrong = resolve_out.clone();
    out_wrong.insert("schema".to_owned(), Value::Object(wrong_schema_type));
    assert!(matches!(
        catalog.validate_xrpc_output(
            "com.atproto.lexicon.resolveLexicon",
            &Value::Object(out_wrong),
            LexiconValidationOptions::strict(),
        ),
        Err(LexiconValidationError::RecordTypeMismatch { ref path, ref expected, ref actual })
            if path == "/schema/$type"
                && expected == "com.atproto.lexicon.schema"
                && actual == "app.bsky.feed.post"
    ));

    // Nested property error inside referenced record preserves `/schema/...` path
    let mut bad_nested = schema_record;
    bad_nested.insert("lexicon".to_owned(), Value::String("one".to_owned()));
    let mut out_nested = resolve_out;
    out_nested.insert("schema".to_owned(), Value::Object(bad_nested));
    assert!(matches!(
        catalog.validate_xrpc_output(
            "com.atproto.lexicon.resolveLexicon",
            &Value::Object(out_nested),
            LexiconValidationOptions::strict(),
        ),
        Err(LexiconValidationError::TypeMismatch { ref path, .. }) if path == "/schema/lexicon"
    ));

    // `unknown` field rejects decoded blob references (even under strict options)
    let mut blob_map = BTreeMap::new();
    blob_map.insert("$type".to_owned(), Value::String("blob".to_owned()));
    blob_map.insert("ref".to_owned(), Value::Link(schema_cid));
    blob_map.insert("mimeType".to_owned(), Value::String("image/png".to_owned()));
    blob_map.insert("size".to_owned(), Value::Integer(42));

    let mut put_record_input = BTreeMap::new();
    put_record_input.insert("repo".to_owned(), Value::String(actor.to_string()));
    put_record_input.insert(
        "collection".to_owned(),
        Value::String("app.bsky.feed.post".to_owned()),
    );
    put_record_input.insert("rkey".to_owned(), Value::String("3jui7kd54zh2y".to_owned()));
    put_record_input.insert("record".to_owned(), Value::Object(blob_map));

    assert!(matches!(
        catalog.validate_xrpc_input(
            "com.atproto.repo.putRecord",
            &Value::Object(put_record_input),
            LexiconValidationOptions::strict(),
        ),
        Err(LexiconValidationError::TypeMismatch { ref path, ref expected, ref actual })
            if path == "/record" && expected == "object" && actual == "blob"
    ));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn query_unknown_params_and_array_bounds() {
    let mut catalog = LexiconCatalog::bundled().unwrap().clone();
    let search_schema = br#"{
      "lexicon": 1,
      "id": "com.example.search",
      "defs": {
        "main": {
          "type": "query",
          "parameters": {
            "type": "params",
            "required": ["q"],
            "properties": {
              "q": {"type": "string"},
              "opaque": {"type": "unknown"},
              "opaqueList": {"type": "array", "minLength": 2, "maxLength": 3, "items": {"type": "unknown"}}
            }
          }
        }
      }
    }"#;
    catalog
        .add_json(search_schema, LexiconSchemaOptions::strict())
        .unwrap();

    // Query string `unknown` and array-of-`unknown` validate without requiring JSON objects
    catalog
        .validate_xrpc_query_params(
            "com.example.search",
            &[
                ("q", "cats"),
                ("opaque", "plain-text"),
                ("opaqueList", "first"),
                ("opaqueList", "second"),
            ],
            LexiconValidationOptions::strict(),
        )
        .expect("scalar and array unknown query params pass");

    // Repeated scalar unknown query param still rejected
    assert!(matches!(
        catalog.validate_xrpc_query_params(
            "com.example.search",
            &[("q", "cats"), ("opaque", "a"), ("opaque", "b")],
            LexiconValidationOptions::strict(),
        ),
        Err(LexiconValidationError::TypeMismatch { ref path, .. }) if path == "/opaque"
    ));

    // Array length bounds still enforced on array-of-unknown query params
    assert!(matches!(
        catalog.validate_xrpc_query_params(
            "com.example.search",
            &[("q", "cats"), ("opaqueList", "only-one")],
            LexiconValidationOptions::strict(),
        ),
        Err(LexiconValidationError::ConstraintViolation { ref path, .. }) if path == "/opaqueList"
    ));
    assert!(matches!(
        catalog.validate_xrpc_query_params(
            "com.example.search",
            &[
                ("q", "cats"),
                ("opaqueList", "1"),
                ("opaqueList", "2"),
                ("opaqueList", "3"),
                ("opaqueList", "4"),
            ],
            LexiconValidationOptions::strict(),
        ),
        Err(LexiconValidationError::ConstraintViolation { ref path, .. }) if path == "/opaqueList"
    ));

    // Pre-typed params value also accepts scalar string `unknown` and validates array bounds
    let mut params_obj = BTreeMap::new();
    params_obj.insert("q".to_owned(), Value::String("cats".to_owned()));
    params_obj.insert("opaque".to_owned(), Value::String("{}".to_owned()));
    params_obj.insert(
        "opaqueList".to_owned(),
        Value::Array(vec![
            Value::String("a".to_owned()),
            Value::String("b".to_owned()),
        ]),
    );
    catalog
        .validate_xrpc_params_value(
            "com.example.search",
            &Value::Object(params_obj),
            LexiconValidationOptions::strict(),
        )
        .expect("typed params value accepts unknown query params");
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn embedded_union_requires_absolute_type_while_frame_t_allows_relative() {
    let catalog = LexiconCatalog::bundled().unwrap();

    // Embedded data union (`com.atproto.repo.applyWrites` `writes` items) rejects relative `#delete`
    let actor = Did::parse("did:plc:ewvi7nxzyoun6zhxrhs64oiz").unwrap();
    let mut rel_write = BTreeMap::new();
    rel_write.insert("$type".to_owned(), Value::String("#delete".to_owned()));
    rel_write.insert(
        "collection".to_owned(),
        Value::String("app.bsky.feed.post".to_owned()),
    );
    rel_write.insert("rkey".to_owned(), Value::String("3jui7kd54zh2y".to_owned()));

    let mut apply_input = BTreeMap::new();
    apply_input.insert("repo".to_owned(), Value::String(actor.to_string()));
    apply_input.insert(
        "writes".to_owned(),
        Value::Array(vec![Value::Object(rel_write.clone())]),
    );

    assert!(matches!(
        catalog.validate_xrpc_input(
            "com.atproto.repo.applyWrites",
            &Value::Object(apply_input.clone()),
            LexiconValidationOptions::strict(),
        ),
        Err(LexiconValidationError::UnionMismatch { ref path, .. }) if path == "/writes/0/$type"
    ));

    // Absolute `com.atproto.repo.applyWrites#delete` passes
    let mut abs_write = rel_write;
    abs_write.insert(
        "$type".to_owned(),
        Value::String("com.atproto.repo.applyWrites#delete".to_owned()),
    );
    apply_input.insert(
        "writes".to_owned(),
        Value::Array(vec![Value::Object(abs_write)]),
    );
    catalog
        .validate_xrpc_input(
            "com.atproto.repo.applyWrites",
            &Value::Object(apply_input),
            LexiconValidationOptions::strict(),
        )
        .expect("absolute union member $type passes applyWrites");

    // `#main` suffix rejected in embedded data union `$type`, while frame selector `t="#info"` stays allowed
    let mut main_suffix_info = BTreeMap::new();
    main_suffix_info.insert(
        "$type".to_owned(),
        Value::String("com.atproto.sync.subscribeRepos#main".to_owned()),
    );
    assert!(matches!(
        catalog.validate_xrpc_message(
            "com.atproto.sync.subscribeRepos",
            &Value::Object(main_suffix_info),
            LexiconValidationOptions::strict(),
        ),
        Err(LexiconValidationError::UnionMismatch { ref path, .. }) if path == "/$type"
    ));

    // Payload carrying `$type: "#info"` (not `t: "#info"`) is rejected as non-absolute `$type`
    let mut rel_dollar_type = BTreeMap::new();
    rel_dollar_type.insert("$type".to_owned(), Value::String("#info".to_owned()));
    rel_dollar_type.insert(
        "name".to_owned(),
        Value::String("OutdatedCursor".to_owned()),
    );
    assert!(matches!(
        catalog.validate_xrpc_message(
            "com.atproto.sync.subscribeRepos",
            &Value::Object(rel_dollar_type),
            LexiconValidationOptions::strict(),
        ),
        Err(LexiconValidationError::UnionMismatch { ref path, .. }) if path == "/$type"
    ));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn record_key_literal_preserves_inner_literal_prefix() {
    let parsed = petrel_lexicon::LexRecordKeyType::parse("literal:literal:foo");
    assert_eq!(
        parsed,
        petrel_lexicon::LexRecordKeyType::Literal("literal:foo".to_owned())
    );
    assert_eq!(parsed.as_str(), "literal:literal:foo");
    assert!(parsed.is_valid_key("literal:foo"));
    assert!(!parsed.is_valid_key("foo"));

    let schema_json = br#"{
        "lexicon": 1,
        "id": "com.example.literalPrefix",
        "defs": {
            "main": {
                "type": "record",
                "key": "literal:literal:foo",
                "record": {
                    "type": "object",
                    "required": ["ok"],
                    "properties": {
                        "ok": { "type": "boolean" }
                    }
                }
            }
        }
    }"#;
    let doc = petrel_lexicon::LexiconDoc::from_json_bytes(schema_json).expect("parse doc");
    let roundtrip = petrel_lexicon::LexiconDoc::from_json_bytes(&doc.to_json_bytes().unwrap())
        .expect("roundtrip doc");
    assert_eq!(roundtrip, doc);

    let mut catalog = LexiconCatalog::new();
    catalog.add(doc, LexiconSchemaOptions::strict()).unwrap();
    let mut record = BTreeMap::new();
    record.insert(
        "$type".to_owned(),
        Value::String("com.example.literalPrefix".to_owned()),
    );
    record.insert("ok".to_owned(), Value::Bool(true));
    assert!(
        catalog
            .validate_record_value(
                "com.example.literalPrefix",
                &Value::Object(record.clone()),
                Some("literal:foo"),
                LexiconValidationOptions::standard(),
            )
            .is_ok()
    );
    assert!(
        catalog
            .validate_record_value(
                "com.example.literalPrefix",
                &Value::Object(record),
                Some("foo"),
                LexiconValidationOptions::standard(),
            )
            .is_err()
    );
}
