//! Space URIs in the `at:space/` form of the November 24 spaces alpha
//! (bluesky-social/atproto `permissioned-data-alpha` at 1f510f8e), matching
//! Petrel's Swift `ATProtocolURI` and `SpaceRef`.

use petrel_core::syntax::Grammar;
use petrel_core::xrpc::QueryValue;
use petrel_core::{AtIdentifier, AtUri, Did, Nsid, RecordKey, SPACE_URI_PREFIX, SpaceRef};

const SPACE: &str = "at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa";
const RECORD: &str = "at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa/did:plc:ewvi7nxzyoun6zhxrhs64oiz/blue.catbird.mlsChat.message/3l2aaaaaaaaac";
/// `RECORD` normalized: an NSID's domain authority is lowercased.
const NORMALIZED_RECORD: &str = "at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa/did:plc:ewvi7nxzyoun6zhxrhs64oiz/blue.catbird.mlschat.message/3l2aaaaaaaaac";
const LEGACY_RECORD: &str = "at://did:web:ds.catbird.blue/space/blue.catbird.mlsChat/3l2aaaaaaaaaa/did:plc:ewvi7nxzyoun6zhxrhs64oiz/blue.catbird.mlsChat.message/3l2aaaaaaaaac";

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn parses_space_and_record_uris_in_the_at_space_form() {
    assert_eq!(SPACE_URI_PREFIX, "at:space/");

    let space: AtUri = SPACE.parse().unwrap();
    assert!(space.is_space());
    assert_eq!(space.as_str(), SPACE);
    assert_eq!(
        space.space_did().map(Did::as_str),
        Some("did:web:ds.catbird.blue")
    );
    assert_eq!(
        space.space_type().map(Nsid::as_str),
        Some("blue.catbird.mlsChat")
    );
    assert_eq!(space.skey().map(RecordKey::as_str), Some("3l2aaaaaaaaaa"));
    assert_eq!(space.collection(), None);
    assert_eq!(space.rkey(), None);
    assert_eq!(space.author_did(), None);
    assert!(matches!(space.authority(), AtIdentifier::Did(_)));

    let record: AtUri = RECORD.parse().unwrap();
    assert!(record.is_space());
    assert_eq!(
        record.author_did().map(Did::as_str),
        Some("did:plc:ewvi7nxzyoun6zhxrhs64oiz")
    );
    assert_eq!(
        record.collection().map(Nsid::as_str),
        Some("blue.catbird.mlsChat.message")
    );
    assert_eq!(record.rkey().map(RecordKey::as_str), Some("3l2aaaaaaaaac"));
    assert_eq!(record.space_ref().unwrap().as_str(), SPACE);
    assert_eq!(record.normalized().as_str(), NORMALIZED_RECORD);
    assert_eq!(record.to_query_value(), RECORD);
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn rejects_malformed_space_uris() {
    for wire in [
        // The spaces alpha form is no longer accepted by parsing.
        "at://did:web:ds.catbird.blue/space/blue.catbird.mlsChat/3l2aaaaaaaaaa",
        LEGACY_RECORD,
        // Handles are not space or author identifiers.
        "at:space/ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa",
        "at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa/alice.test/blue.catbird.mlsChat.message/3l2aaaaaaaaac",
        // Wrong segment counts and empty segments.
        "at:space/did:web:ds.catbird.blue",
        "at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat",
        "at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa/",
        "at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa/did:plc:ewvi7nxzyoun6zhxrhs64oiz",
        "at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa/did:plc:ewvi7nxzyoun6zhxrhs64oiz/blue.catbird.mlsChat.message",
        "at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa/did:plc:ewvi7nxzyoun6zhxrhs64oiz/blue.catbird.mlsChat.message/3l2aaaaaaaaac/extra",
        "at:space//blue.catbird.mlsChat/3l2aaaaaaaaaa",
        // Bad type and keys.
        "at:space/did:web:ds.catbird.blue/notannsid/3l2aaaaaaaaaa",
        "at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/..",
        "at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa/did:plc:ewvi7nxzyoun6zhxrhs64oiz/notannsid/3l2aaaaaaaaac",
        // Other near misses.
        "at:/space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa",
        "at:space:did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa",
        "at://space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa",
    ] {
        assert!(wire.parse::<AtUri>().is_err(), "{wire}");
    }
    let too_long = format!("{SPACE}/{}", "a".repeat(8192));
    assert!(too_long.parse::<AtUri>().is_err());
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn the_restricted_grammar_rejects_space_uris() {
    assert!(AtUri::parse_with_grammar(SPACE, Grammar::Restricted).is_err());
    assert!(AtUri::parse_with_grammar(RECORD, Grammar::Restricted).is_err());
    assert!(AtUri::parse_with_grammar(SPACE, Grammar::RestrictedOrSpace).is_ok());
    // Standard URIs are unaffected.
    for wire in [
        "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz",
        "at://alice.test/app.bsky.feed.post/3l2aaaaaaaaac",
    ] {
        let uri = AtUri::parse_with_grammar(wire, Grammar::Restricted).unwrap();
        assert!(!uri.is_space());
        assert_eq!(uri.to_query_value(), wire);
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn decoding_keeps_the_spaces_alpha_form_as_written() {
    let json = serde_json::to_string(LEGACY_RECORD).unwrap();
    let decoded: AtUri = serde_json::from_str(&json).unwrap();
    assert!(decoded.is_legacy_space_form());
    assert!(decoded.is_space());
    // The bytes a CID covers stay as written.
    assert_eq!(decoded.as_str(), LEGACY_RECORD);
    assert_eq!(serde_json::to_string(&decoded).unwrap(), json);
    // Requests and normalization use the current form.
    assert_eq!(decoded.to_query_value(), RECORD);
    assert_eq!(decoded.normalized().as_str(), NORMALIZED_RECORD);
    assert_eq!(decoded.space_ref().unwrap().as_str(), SPACE);
    assert_eq!(
        decoded.author_did().map(Did::as_str),
        Some("did:plc:ewvi7nxzyoun6zhxrhs64oiz")
    );

    let current: AtUri = serde_json::from_str(&serde_json::to_string(RECORD).unwrap()).unwrap();
    assert!(!current.is_legacy_space_form());
    // A legacy-form string that is otherwise malformed still fails.
    let bad =
        serde_json::to_string("at://alice.test/space/blue.catbird.mlsChat/3l2aaaaaaaaaa").unwrap();
    assert!(serde_json::from_str::<AtUri>(&bad).is_err());
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn rewrites_the_spaces_alpha_form() {
    assert_eq!(
        AtUri::from_legacy_space_uri(LEGACY_RECORD).as_deref(),
        Some(RECORD)
    );
    for wire in [
        SPACE,
        "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3l2aaaaaaaaac",
        "at:///space/blue.catbird.mlsChat/3l2aaaaaaaaaa",
        "at://did:plc:x?y/space/blue.catbird.mlsChat/3l2aaaaaaaaaa",
        "at://did:plc:x y/space/blue.catbird.mlsChat/3l2aaaaaaaaaa",
        "at://did:plc:x/spaces/blue.catbird.mlsChat/3l2aaaaaaaaaa",
        "at://did:plc:x/space",
    ] {
        assert_eq!(AtUri::from_legacy_space_uri(wire), None, "{wire}");
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn space_refs_take_the_at_space_form_only() {
    let space: SpaceRef = SPACE.parse().unwrap();
    assert_eq!(space.space_did().as_str(), "did:web:ds.catbird.blue");
    assert_eq!(space.space_type().as_str(), "blue.catbird.mlsChat");
    assert_eq!(space.skey().as_str(), "3l2aaaaaaaaaa");
    assert_eq!(
        SpaceRef::from_parts(space.space_did(), space.space_type(), space.skey())
            .unwrap()
            .as_str(),
        SPACE
    );
    let record = space
        .record_uri(
            &"did:plc:ewvi7nxzyoun6zhxrhs64oiz".parse().unwrap(),
            &"blue.catbird.mlsChat.message".parse().unwrap(),
            &"3l2aaaaaaaaac".parse().unwrap(),
        )
        .unwrap();
    assert_eq!(record.as_str(), RECORD);

    for wire in [
        "at://did:web:ds.catbird.blue/space/blue.catbird.mlsChat/3l2aaaaaaaaaa",
        RECORD,
        "at:space/ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa",
        "at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat",
        "at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa/",
    ] {
        assert!(wire.parse::<SpaceRef>().is_err(), "{wire}");
        let json = serde_json::to_string(wire).unwrap();
        assert!(serde_json::from_str::<SpaceRef>(&json).is_err(), "{wire}");
    }
}
