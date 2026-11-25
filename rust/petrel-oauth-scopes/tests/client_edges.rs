use petrel_oauth_scopes::{
    AccountPermission, AtProtoScope, BlobPermission, RepoPermission, RpcPermission,
    ScopeParseError, ScopeSet, is_atproto_did_ref_absolute, is_nsid,
};

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn rpc_audience_validation_and_wire_encoding() {
    for (audience, canonical_preserves_audience) in [
        ("did:web:example.com#service_id", true),
        ("did:web:api.bsky.app#bsky_appview", true),
        ("did:web:sub.domain.example.co.uk#svc", true),
        ("did:web:localhost#svc", true),
        ("did:web:localhost%3A3000#svc", false),
        ("did:web:localhost%3A65535#svc", false),
        ("did:plc:ewvi7nxzyoun6zhxrhs64oiz#atproto_labeler", true),
        ("did:plc:z72i7hdynmk6r22z27h6tvur#bsky_fg", true),
        ("did:web:example.com#a-b.c_d~e", true),
        ("did:web:example.com#a!$&'()*,;=b", true),
        ("did:web:example.com#a!$&'()*+,;=b", false),
        ("did:web:example.com#a:b@c/d?e", true),
        ("did:web:example.com#a%20b%2fc", false),
    ] {
        let method = "com.example.method";
        let permission = RpcPermission::new(&[method], audience).unwrap();
        assert!(is_atproto_did_ref_absolute(audience), "{audience:?}");
        assert!(permission.matches(method, audience), "{audience:?}");
        let canonical = permission.canonical_scope_string().unwrap();
        let canonical_match =
            RpcPermission::parse(&canonical).is_ok_and(|value| value.matches(method, audience));
        assert_eq!(
            canonical_match, canonical_preserves_audience,
            "{audience:?}"
        );
        let wire = permission.wire_scope_string().unwrap();
        assert!(
            RpcPermission::parse(&wire)
                .unwrap()
                .matches(method, audience),
            "{audience:?}"
        );
    }
    for audience in [
        "",
        "did:web:example.com",
        "did:web:example.com#",
        "did:web:example.com#a#b",
        "#service_id",
        "example.com#service_id",
        "https://example.com#service_id",
        "DID:web:example.com#svc",
        "did:WEB:example.com#svc",
        "did:web:#svc",
        "did:web:example.com:path#svc",
        "did:web::example.com#svc",
        "did:web:example.com%3A443#svc",
        "did:web:example.com%3a443#svc",
        "did:web:localhost%3Aabc#svc",
        "did:web:localhost%3A65536#svc",
        "did:web:localhost%3A3000%3A1#svc",
        "did:web:localhost:3000#svc",
        "did:web:exa mple.com#svc",
        "did:web:example.com/path#svc",
        "did:plc:ewvi7nxzyoun6zhxrhs64oi#svc",
        "did:plc:ewvi7nxzyoun6zhxrhs64oizz#svc",
        "did:plc:EWVI7NXZYOUN6ZHXRHS64OIZ#svc",
        "did:plc:ewvi7nxzyoun6zhxrhs64oi1#svc",
        "did:plc:ewvi7nxzyoun6zhxrhs64oi8#svc",
        "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK#svc",
        "did:example:123#svc",
        "did:web:example.com#sp ace",
        "did:web:example.com#%zz",
        "did:web:example.com#abc%2",
        "did:web:example.com#a\"b",
        "did:web:example.com#a[b]",
        "did:web:example.com#caf\u{E9}",
    ] {
        assert_eq!(
            RpcPermission::new(&["com.example.method"], audience),
            Err(ScopeParseError::InvalidParameter { key: "aud" }),
            "{audience:?}"
        );
        assert!(!is_atproto_did_ref_absolute(audience), "{audience:?}");
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn nsid_limits_and_matching_use_the_original_bytes() {
    let label63 = "a".repeat(63);
    let label64 = "a".repeat(64);
    let longest = format!("{label63}.{label63}.{label63}.{label63}.{}", "a".repeat(61));
    let too_long = format!("{label63}.{label63}.{label63}.{label63}.{label63}");
    assert_eq!(longest.len(), 317);
    assert_eq!(too_long.len(), 319);
    for valid in [
        "com.example.foo",
        "COM.Example.fooBar",
        "com.3example.foo",
        "com.ex-ample.foo",
        "a.b.c",
        "com.example.sub.domain.deep.recordName",
        "com.example.foo2",
        &format!("com.{label63}.foo"),
        &longest,
    ] {
        assert!(is_nsid(valid), "{valid:?}");
        let permission = RepoPermission::new(&[valid], &[]).unwrap();
        assert!(permission.matches(valid, "create"));
        assert_eq!(
            permission.canonical_scope_string().unwrap(),
            format!("repo:{valid}")
        );
    }
    for invalid in [
        format!("com.{label64}.foo"),
        format!("com.example.{label64}"),
        too_long,
    ] {
        assert!(!is_nsid(&invalid), "{invalid:?}");
        assert_eq!(
            RepoPermission::new(&[&invalid], &[]),
            Err(ScopeParseError::InvalidParameter { key: "collection" })
        );
    }

    let repo = RepoPermission::new(&["com.example.Key"], &["create"]).unwrap();
    assert!(repo.matches("com.example.Key", "create"));
    assert!(!repo.matches("com.example.\u{212A}ey", "create"));
    assert!(!repo.matches("com.example.Key", "update"));
    assert!(!repo.matches("com.example.key", "create"));

    let rpc = RpcPermission::new(&["com.example.Key"], "did:web:example.com#Key").unwrap();
    assert!(!rpc.matches("com.example.\u{212A}ey", "did:web:example.com#Key"));
    assert!(!rpc.matches("com.example.Key", "did:web:example.com#\u{212A}ey"));
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn media_type_patterns_match_only_concrete_mime_types() {
    let any_type = BlobPermission::parse("blob:*/*").unwrap();
    let images = BlobPermission::parse("blob:image/*").unwrap();
    for mime in [
        "image/*",
        "*/*",
        "image/png/extra",
        "*/mime",
        "/png",
        "image/",
        "image",
        "image/ png",
        "image//png",
        "/mime",
        "",
    ] {
        assert!(!any_type.matches(mime), "{mime:?}");
        assert!(!images.matches(mime), "{mime:?}");
    }
    for (pattern, mime, expected) in [
        ("image/png", "image/png", true),
        ("image/*", "image/jpeg", true),
        ("image/*", "image/gif", true),
        ("image/png", "image/jpeg", false),
        ("image/*", "text/html", false),
        ("*/*", "application/json", true),
        ("image/png", "*/mime", false),
        ("image/png", "image", false),
        ("image/*", "image//png", false),
        ("image/*", "image/ png", false),
        ("*/*", "image/", false),
        ("*/*", "/mime", false),
        ("image/*", "imagex/png", false),
        ("image/*", "image", false),
        ("image/png", "image/pngx", false),
        ("image/png", "image/pn", false),
    ] {
        let scope = format!("blob:{pattern}");
        assert_eq!(
            BlobPermission::new(&[pattern]).unwrap().matches(mime),
            expected,
            "{scope} / {mime:?}"
        );
        assert_eq!(
            ScopeSet::from_scope_string(&scope).allows_blob(mime),
            expected,
            "{scope} / {mime:?}"
        );
    }
    let mime = "image/\u{212A}tx";
    let permission = BlobPermission::new(&[mime]).unwrap();
    let wire = permission.wire_scope_string().unwrap();
    assert_eq!(wire, "blob:image/%E2%84%AAtx");
    let reparsed = BlobPermission::parse(&wire).unwrap();
    assert!(reparsed.matches(mime));
    assert!(!reparsed.matches("image/ktx"));
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn account_default_and_manage_cover_each_attribute() {
    for attribute in ["email", "repo", "status"] {
        let read = AccountPermission::new(attribute, "read").unwrap();
        let manage = AccountPermission::new(attribute, "manage").unwrap();
        assert!(read.matches(attribute, "read"));
        assert!(!read.matches(attribute, "manage"));
        assert!(manage.matches(attribute, "read"));
        assert!(manage.matches(attribute, "manage"));
        let expected_read = format!("account:{attribute}");
        let expected_manage = format!("account:{attribute}?action=manage");
        assert_eq!(
            AccountPermission::scope_needed(attribute, "read").unwrap(),
            expected_read
        );
        assert_eq!(
            AccountPermission::scope_needed(attribute, "manage").unwrap(),
            expected_manage
        );
        assert_eq!(read.canonical_scope_string().unwrap(), expected_read);
        assert_eq!(manage.canonical_scope_string().unwrap(), expected_manage);
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn requested_scope_subset_and_raw_set_membership_remain_distinct() {
    let requested = ScopeSet::parse_strict(
        "account:email atproto blob:image/* repo?collection=app.bsky.feed.like&collection=app.bsky.feed.post rpc:app.bsky.feed.getTimeline?aud=did:web:api.bsky.app%23bsky_appview",
    ).unwrap();
    let partial = ScopeSet::parse_strict(
        "atproto repo:app.bsky.feed.post rpc:app.bsky.feed.getTimeline?aud=did:web:api.bsky.app%23bsky_appview blob:image/*",
    ).unwrap();
    assert!(requested.covers(&partial));
    assert!(!partial.covers(&requested));

    let raw = ScopeSet::from_scope_string(" atproto  repo:* future:thing atproto ");
    let permuted = ScopeSet::from_scope_string("future:thing repo:* atproto");
    assert_eq!(raw, permuted);
    assert_eq!(raw.scope_string(), "atproto future:thing repo:*");
    let other_spelling = ScopeSet::from_scope_string("atproto repo?collection=* future:thing");
    assert_ne!(raw, other_spelling);
    assert_eq!(
        raw.normalized_scope_string(),
        other_spelling.normalized_scope_string()
    );
    assert!(raw.covers(&other_spelling) && other_spelling.covers(&raw));
    assert!(!raw.raw_scopes().contains("repo:com.example.foo"));
    assert!(raw.covers(&ScopeSet::from_scope_string("repo:com.example.foo")));
    assert!(!raw.covers(&ScopeSet::from_scope_string("future:other")));
    assert!(!raw.covers(&ScopeSet::from_scope_string("future:thing?x=y")));
    assert!(
        ScopeSet::from_scope_string("repo:read")
            .rejected()
            .contains_key("repo:read")
    );
    let removed = ScopeSet::from_raw_scopes(
        raw.raw_scopes()
            .iter()
            .filter(|scope| scope.as_str() != "future:thing")
            .cloned()
            .collect(),
    );
    assert!(!removed.raw_scopes().contains("future:thing"));
    assert!(!removed.covers(&raw));

    let opaque = AtProtoScope::parse_or_unrecognized("future:%41").unwrap();
    let from_typed = ScopeSet::from_scopes([opaque]).unwrap();
    assert_eq!(from_typed.scope_string(), "future:%41");
    assert_eq!(
        from_typed.rejected().get("future:%41"),
        Some(&ScopeParseError::UnknownPrefix)
    );
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn granting_scope_and_multi_action_account_match_swift_parity() {
    use petrel_oauth_scopes::IdentityPermission;

    assert_eq!(
        RepoPermission::granting_scope("app.bsky.feed.post", "create").unwrap(),
        "repo:app.bsky.feed.post?action=create"
    );
    assert!(RepoPermission::granting_scope("bad", "create").is_err());

    assert_eq!(
        RpcPermission::granting_scope("com.example.method", "did:web:example.com#svc").unwrap(),
        "rpc:com.example.method?aud=did:web:example.com%23svc"
    );
    assert!(RpcPermission::granting_scope("*", "*").is_err());

    assert_eq!(
        BlobPermission::granting_scope("image/svg+xml").unwrap(),
        "blob:image/svg+xml"
    );
    assert_eq!(
        BlobPermission::granting_scope("image/*"),
        Err(ScopeParseError::ForbiddenCombination { prefix: "blob" })
    );

    assert_eq!(
        AccountPermission::granting_scope("email", "manage").unwrap(),
        "account:email?action=manage"
    );
    assert_eq!(
        IdentityPermission::granting_scope("handle").unwrap(),
        "identity:handle"
    );

    let multi = AccountPermission::with_actions("email", &["manage", "read"]).unwrap();
    assert_eq!(
        multi.canonical_scope_string().unwrap(),
        "account:email?action=manage&action=read"
    );
    assert!(multi.matches("email", "read"));
    assert!(multi.matches("email", "manage"));
}
