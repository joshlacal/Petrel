use petrel_core::{Did, ServiceRef, ServiceRefError};

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn parses_and_formats_service_references() {
    let wire = "did:web:api.bsky.app#bsky_appview";
    let appview: ServiceRef = wire.parse().unwrap();
    assert_eq!(appview.did().as_str(), "did:web:api.bsky.app");
    assert_eq!(appview.service_id(), Some(ServiceRef::BSKY_APPVIEW));
    assert_eq!(appview.to_string(), wire);
    assert_eq!(appview.proxy_header_value().as_deref(), Ok(wire));
    assert_eq!(ServiceRef::PROXY_HEADER, "atproto-proxy");

    let did = Did::parse("did:plc:abcdefghijklmnopqrstuvwx").unwrap();
    let labeler = ServiceRef::new(did.clone(), Some("#atproto_labeler")).unwrap();
    assert_eq!(
        labeler,
        "did:plc:abcdefghijklmnopqrstuvwx#atproto_labeler"
            .parse()
            .unwrap()
    );
    assert_eq!(labeler.service_id(), Some(ServiceRef::ATPROTO_LABELER));

    let bare = ServiceRef::new(did, None).unwrap();
    assert_eq!(bare.service_id(), None);
    assert_eq!(bare.to_string(), "did:plc:abcdefghijklmnopqrstuvwx");
    assert_eq!(
        bare.proxy_header_value(),
        Err(ServiceRefError::MissingServiceId)
    );
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn rejects_invalid_references_and_bounds_fragments() {
    for invalid in [
        "",
        "api.bsky.app",
        "https://api.bsky.app",
        "did:web:api.bsky.app#",
        "did:web:api.bsky.app#a#b",
        "did:web:api.bsky.app##a",
        "did:web:api.bsky.app#has space",
        "did:web:api.bsky.app#日本語",
        "did:web:api.bsky.app:path#bsky_appview",
        "#bsky_appview",
    ] {
        assert!(ServiceRef::parse(invalid).is_err(), "{invalid:?}");
    }

    let did = Did::parse("did:web:api.bsky.app").unwrap();
    for invalid in ["", "#", "##extra", "with/slash", "new\nline"] {
        assert_eq!(
            ServiceRef::new(did.clone(), Some(invalid)),
            Err(ServiceRefError::InvalidServiceId)
        );
    }

    let suffix = "Aa09._~:%-";
    let limit = format!("{}{suffix}", "a".repeat(512 - suffix.len()));
    assert_eq!(limit.len(), 512);
    let at_limit = ServiceRef::new(did.clone(), Some(&limit)).unwrap();
    assert_eq!(at_limit.service_id(), Some(limit.as_str()));
    assert_eq!(
        ServiceRef::new(did, Some(&format!("{limit}a"))),
        Err(ServiceRefError::InvalidServiceId)
    );
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn applies_service_auth_method_grammar() {
    for valid in [
        "did:plc:abcdefghijklmnopqrstuvwx",
        "did:web:localhost",
        "did:web:localhost%3A2583",
        "did:web:localhost%3A65535",
        "did:web:pds.example.com",
        "did:example:iss",
        // Public multikey fixtures from PetrelCryptoTests.swift.
        "did:key:zDnaejgmAHMLkBPMBWnkBxyGxpXx8LgE4WJAYDhwZzyoRAddF",
        "did:key:zQ3shqwJEJyMBsBXCWyCBpUBMqxcon9oHB7mCvx4sSpMdLJwc",
    ] {
        assert_eq!(ServiceRef::parse(valid).unwrap().to_string(), valid);
    }

    for invalid in [
        "did:plc:short",
        "did:plc:abcdefghijklmnopqrstuvwx0",
        "did:web:Example.com",
        "did:web:LOCALHOST",
        "did:web:localhost%3a2583",
        "did:web:localhost%3A02583",
        "did:web:localhost%3A0",
        "did:web:localhost%3A65536",
        "did:web:pds.example.com%3A443",
        "did:web:pds.example.com:path",
        "did:key:zInvalid",
    ] {
        assert_eq!(
            ServiceRef::parse(invalid),
            Err(ServiceRefError::InvalidDid),
            "{invalid:?}"
        );
    }
}
