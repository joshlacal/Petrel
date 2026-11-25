use std::fmt::Debug;
use std::str::FromStr;

use petrel_core::syntax::{AtprotoMethod, Grammar};
use petrel_core::{
    AtIdentifier, AtUri, CidString, Did, Handle, Nsid, RecordKey, SpaceRef, Tid, Uri,
};
use serde::{Serialize, de::DeserializeOwned};

macro_rules! vectors {
    ($file:literal, $count:literal) => {{
        let text = include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../Tests/PetrelTests/Vectors/syntax/",
            $file,
            ".txt"
        ));
        let vectors: Vec<_> = text
            .split('\n')
            .filter(|line| !line.is_empty() && !line.starts_with('#'))
            .collect();
        assert_eq!(vectors.len(), $count, $file);
        vectors
    }};
}

fn valid<T: FromStr + Serialize + DeserializeOwned + Debug>(vectors: &[&str])
where
    T::Err: Debug,
{
    for &wire in vectors {
        let expected = serde_json::to_string(wire).unwrap();
        let parsed = wire
            .parse::<T>()
            .unwrap_or_else(|err| panic!("{wire:?}: {err:?}"));
        assert_eq!(
            serde_json::to_string(&parsed).unwrap(),
            expected,
            "{wire:?}"
        );
        let decoded: T = serde_json::from_str(&expected).unwrap();
        assert_eq!(
            serde_json::to_string(&decoded).unwrap(),
            expected,
            "{wire:?}"
        );
    }
}

fn invalid<T: FromStr + DeserializeOwned>(vectors: &[&str]) {
    for &wire in vectors {
        assert!(wire.parse::<T>().is_err(), "{wire:?}");
        assert!(
            serde_json::from_str::<T>(&serde_json::to_string(wire).unwrap()).is_err(),
            "{wire:?}"
        );
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn official_identifier_vectors() {
    valid::<Did>(&vectors!("did_syntax_valid", 24));
    invalid::<Did>(&vectors!("did_syntax_invalid", 18));
    valid::<Handle>(&vectors!("handle_syntax_valid", 71));
    invalid::<Handle>(&vectors!("handle_syntax_invalid", 48));
    valid::<AtIdentifier>(&vectors!("atidentifier_syntax_valid", 11));
    invalid::<AtIdentifier>(&vectors!("atidentifier_syntax_invalid", 22));
    valid::<Nsid>(&vectors!("nsid_syntax_valid", 25));
    invalid::<Nsid>(&vectors!("nsid_syntax_invalid", 27));
    valid::<RecordKey>(&vectors!("recordkey_syntax_valid", 16));
    invalid::<RecordKey>(&vectors!("recordkey_syntax_invalid", 11));
    valid::<Tid>(&vectors!("tid_syntax_valid", 4));
    invalid::<Tid>(&vectors!("tid_syntax_invalid", 9));
    valid::<CidString>(&vectors!("cid_syntax_valid", 8));
    invalid::<CidString>(&vectors!("cid_syntax_invalid", 10));

    let valid_uris = vectors!("aturi_syntax_valid", 23);
    valid::<AtUri>(&valid_uris);
    for wire in valid_uris {
        let uri = AtUri::parse_with_grammar(wire, Grammar::Restricted).unwrap();
        assert_eq!(uri.as_str(), wire);
        assert!(!uri.is_space());
    }

    let invalid_uris = vectors!("aturi_syntax_invalid", 72);
    invalid::<AtUri>(&invalid_uris);
    for wire in invalid_uris {
        assert!(
            AtUri::parse_with_grammar(wire, Grammar::Restricted).is_err(),
            "{wire:?}"
        );
    }

    valid::<Uri>(&vectors!("uri_syntax_valid", 9));
    let invalid_generic_uris = vectors!("uri_syntax_invalid", 12);
    invalid::<Uri>(&invalid_generic_uris);
    for wire in invalid_generic_uris {
        let uri = Uri::new_unchecked(wire);
        assert_eq!(uri.as_str(), wire);
        assert!(!uri.has_valid_syntax());
        assert!(serde_json::to_string(&uri).is_err());
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn identifier_semantics() {
    let handle: Handle = "Alice.BSKY.Social".parse().unwrap();
    assert_eq!(handle.normalized(), "alice.bsky.social");
    assert_eq!(handle.wire_value(), "Alice.BSKY.Social");
    assert_eq!(handle, "alice.bsky.social".parse().unwrap());
    assert!(!"name.ONION".parse::<Handle>().unwrap().is_valid_tld());
    let nsid: Nsid = "Com.ATProto.PublishPost".parse().unwrap();
    assert_eq!(nsid, "com.atproto.PublishPost".parse().unwrap());
    assert_ne!(nsid, "com.atproto.publishPost".parse().unwrap());

    let plc: Did = "did:plc:abcdefghijklmnopqrstuvwx".parse().unwrap();
    assert_eq!(plc.method(), "plc");
    assert_eq!(plc.atproto_method(), Some(AtprotoMethod::Plc));
    let dev_web: Did = "did:web:localhost%3a65535".parse().unwrap();
    assert_eq!(dev_web.atproto_method(), Some(AtprotoMethod::Web));
    assert_eq!(dev_web.atproto_method_with_localhost(false), None);
    for wire in [
        "did:web:x.onion",
        "did:web:x.example.org%3A8888",
        "did:web:x.example.org:path",
    ] {
        assert_eq!(
            wire.parse::<Did>().unwrap().atproto_method(),
            None,
            "{wire}"
        );
    }

    let public: AtUri = "at://Alice.Bsky.Social/App.Bsky.FeedPost/Case"
        .parse()
        .unwrap();
    assert_eq!(
        public.normalized().as_str(),
        "at://alice.bsky.social/app.bsky.FeedPost/Case"
    );
    let space: SpaceRef = "at:space/did:plc:space/Com.Catbird.Type/One"
        .parse()
        .unwrap();
    let record = space
        .record_uri(&plc, &nsid, &"Key".parse().unwrap())
        .unwrap();
    assert_eq!(record.space_ref().as_ref(), Some(&space));
    assert_eq!(record.author_did(), Some(&plc));
    assert!(record.as_str().parse::<SpaceRef>().is_err());
    assert!(AtUri::parse_with_grammar(record.as_str(), Grammar::Restricted).is_err());
    assert_eq!(
        record.normalized().as_str(),
        "at:space/did:plc:space/com.catbird.Type/One/did:plc:abcdefghijklmnopqrstuvwx/com.atproto.PublishPost/Key"
    );

    let high: Tid = "c222222222222".parse().unwrap();
    assert!(high.has_high_bit());
    assert!(high > Tid::from_parts(Tid::MAX_TIMESTAMP_MICROS, 1023).unwrap());
    assert_eq!(high.timestamp_micros(), 0);
    assert_eq!(high.clock_id(), 0);
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn official_datetime_vectors() {
    use petrel_core::{Datetime, datetime::normalize_datetime};

    let vectors = vectors!("datetime_syntax_valid", 35);
    valid::<Datetime>(&vectors);
    invalid::<Datetime>(&vectors!("datetime_syntax_invalid", 45));
    invalid::<Datetime>(&vectors!("datetime_parse_invalid", 7));
    for wire in vectors {
        let parsed = Datetime::parse(wire).unwrap();
        let normalized = parsed.to_normalized_string().unwrap();
        assert_eq!(normalize_datetime(wire).unwrap(), normalized, "{wire}");
        let reparsed = Datetime::parse(normalized).unwrap();
        let secs = reparsed.unix_seconds() - parsed.unix_seconds();
        let nanos = i64::from(reparsed.subsec_nanos()) - i64::from(parsed.subsec_nanos());
        assert!((secs * 1_000_000_000 + nanos).abs() <= 500_000, "{wire}");
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn datetime_calendar_and_range() {
    use petrel_core::{
        Datetime,
        datetime::{normalize_datetime, normalize_datetime_always},
    };

    for (wire, valid) in [
        ("2024-02-29T00:00:00Z", true),
        ("2023-02-29T00:00:00Z", false),
        ("2024-04-31T00:00:00Z", false),
        ("9999-12-31T23:59:59Z", true),
        ("9999-12-31T23:59:59-00:01", false),
        ("0000-01-01T01:00:00+01:00", true),
        ("0000-01-01T00:59:59+01:00", false),
    ] {
        assert_eq!(Datetime::is_valid_datetime(wire), valid, "{wire}");
    }

    let epoch = Datetime::from_unix(0, 0).unwrap();
    assert_eq!(epoch, Datetime::parse("1969-12-31T19:00:00-05:00").unwrap());
    assert_eq!(epoch.as_str(), "1970-01-01T00:00:00.000Z");
    for wire in [
        "1969-12-31 19:00-0500 ",
        "1970-01-01t00:00:00z",
        "1970-01-01_00:00-00:00",
        "1970-01-01",
    ] {
        assert_eq!(normalize_datetime(wire).unwrap(), epoch.as_str(), "{wire}");
    }
    assert_eq!(normalize_datetime_always("invalid"), epoch.as_str());
    assert_eq!(
        Datetime::from_unix(-1, 999_500_000).unwrap().as_str(),
        "1969-12-31T23:59:59.999Z"
    );
    assert_eq!(
        Datetime::from_unix(0, 999_500_000).unwrap().as_str(),
        "1970-01-01T00:00:01.000Z"
    );
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn official_language_vectors() {
    use petrel_core::{Language, language::LanguageTag};

    let valid_vectors = vectors!("language_syntax_valid", 18);
    valid::<Language>(&valid_vectors);
    for wire in valid_vectors {
        let tag = LanguageTag::parse(wire).unwrap();
        assert_eq!(tag.raw_value, wire);
        assert_eq!(Language::parse_validated(wire).unwrap().tag(), Some(tag));
    }
    for wire in vectors!("language_syntax_invalid", 7) {
        assert!(!LanguageTag::is_valid(wire), "{wire}");
        assert!(Language::parse_validated(wire).is_err(), "{wire}");
        if matches!(wire, "JA" | "jaja") {
            assert!(LanguageTag::is_well_formed(wire), "{wire}");
            valid::<Language>(&[wire]);
        } else {
            assert!(!LanguageTag::is_well_formed(wire), "{wire}");
            invalid::<Language>(&[wire]);
        }
    }
    for wire in vectors!("language_parse_invalid", 4) {
        assert!(LanguageTag::is_well_formed(wire), "{wire}");
        assert!(!LanguageTag::is_valid(wire), "{wire}");
        assert!(Language::parse_validated(wire).is_err(), "{wire}");
        valid::<Language>(&[wire]);
        assert_eq!(Language::parse(wire).unwrap().tag(), None);
    }
}

#[test]
#[cfg(all(
    not(target_arch = "wasm32"),
    feature = "chrono",
    feature = "time",
    feature = "jiff"
))]
fn datetime_interop_preserves_subseconds() {
    use petrel_core::Datetime;

    let value = Datetime::parse("1969-12-31T23:59:59.123456789Z").unwrap();
    let chrono = chrono::DateTime::<chrono::Utc>::try_from(value.clone()).unwrap();
    assert_eq!(Datetime::try_from(chrono).unwrap(), value);
    let time = time::OffsetDateTime::try_from(value.clone()).unwrap();
    assert_eq!(Datetime::try_from(time).unwrap(), value);
    let jiff = jiff::Timestamp::try_from(value.clone()).unwrap();
    assert_eq!(Datetime::try_from(jiff).unwrap(), value);
}
