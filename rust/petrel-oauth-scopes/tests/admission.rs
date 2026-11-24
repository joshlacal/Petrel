use petrel_oauth_scopes::{
    AtProtoScope, OAuthScopeAdmissionError as Error, OAuthScopeAdmissionPolicy as Policy,
    OAuthScopeBudget, OAuthScopeTokenizer, OAuthUnknownScopePolicy, ScopeSet,
};

#[test]
fn canonical_collision_cannot_expand_a_declaration() {
    let declared = "rpc:com.example.method?aud=did:web:example.com%23svc%26admin";
    let requested = "rpc:com.example.method?aud=did:web:example.com%23svc%2526admin";
    let a = AtProtoScope::parse(declared).unwrap();
    let b = AtProtoScope::parse(requested).unwrap();
    assert_eq!(a.canonical_scope_string(), b.canonical_scope_string());
    assert_ne!(a.wire_scope_string(), b.wire_scope_string());
    assert_eq!(
        Policy::admit(
            &ScopeSet::from_scope_string(&format!("atproto {requested}")),
            &ScopeSet::from_scope_string(&format!("atproto {declared}")),
            OAuthUnknownScopePolicy::Reject,
        ),
        Err(Error::NotRegistered),
    );
}

#[test]
fn declaration_matches_meaning_within_one_family() {
    for (a, b) in [
        (
            "repo:app.bsky.feed.post?action=create",
            "repo?collection=app.bsky.feed.post&action=create",
        ),
        (
            "repo:app.bsky.feed.post",
            "repo:app.bsky.feed.post?action=create&action=update&action=delete",
        ),
        ("repo:*", "repo?collection=*&collection=app.bsky.feed.post"),
        ("blob:image/*", "blob?accept=image/png&accept=image/*"),
        ("blob:image/png", "blob?accept=image/png&accept=image/png"),
        ("blob:image/png", "blob:IMAGE/PNG"),
        (
            "account:email?action=manage",
            "account:email?action=read&action=manage",
        ),
        (
            "rpc:app.bsky.feed.getFeed?aud=*",
            "rpc?lxm=app.bsky.feed.getFeed&aud=*",
        ),
        (
            "include:app.example.authBasic",
            "include?nsid=app.example.authBasic",
        ),
    ] {
        let first = ScopeSet::from_scope_string(a);
        let second = ScopeSet::from_scope_string(b);
        assert!(Policy::is_declared(&first, &second), "{a:?}, {b:?}");
        assert!(Policy::is_declared(&second, &first), "{a:?}, {b:?}");
    }

    for (a, b) in [
        (
            "repo:app.bsky.feed.post",
            "repo:app.bsky.feed.post?action=create",
        ),
        ("blob:image/*", "blob:image/png"),
        ("account:email", "account:email?action=manage"),
        ("identity:*", "identity:handle"),
        (
            "rpc:app.bsky.feed.getFeed?aud=*",
            "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23svc",
        ),
        (
            "include:app.example.authBasic",
            "include:app.example.authBasic?aud=did:web:example.com%23svc",
        ),
        ("transition:generic", "repo:app.bsky.feed.post"),
        ("transition:generic", "transition:chat.bsky"),
    ] {
        let first = ScopeSet::from_scope_string(a);
        let second = ScopeSet::from_scope_string(b);
        assert!(!Policy::is_declared(&first, &second), "{a:?}, {b:?}");
        assert!(!Policy::is_declared(&second, &first), "{a:?}, {b:?}");
    }
}

#[test]
fn admission_requires_base_scope_and_has_explicit_unknown_scope_policy() {
    let opaque = ScopeSet::from_scope_string("atproto future:K");
    let opaque_different = ScopeSet::from_scope_string("atproto future:\u{212A}");
    let base = ScopeSet::parse("atproto").unwrap();
    assert!(Policy::is_declared(&opaque, &opaque));
    assert!(!Policy::is_declared(&opaque, &opaque_different));
    assert_eq!(
        Policy::admit(&opaque, &base, OAuthUnknownScopePolicy::Ignore),
        Ok(base.clone())
    );
    assert!(matches!(
        Policy::admit(&opaque, &opaque, OAuthUnknownScopePolicy::Reject),
        Err(Error::UnparseableScope(_))
    ));
    let no_base = ScopeSet::parse("repo:app.bsky.feed.post").unwrap();
    assert_eq!(
        Policy::admit(&no_base, &no_base, OAuthUnknownScopePolicy::Reject),
        Err(Error::MissingBaseScope)
    );
}

#[test]
fn tokenizer_and_storage_apply_separate_byte_and_count_budgets() {
    let small = OAuthScopeBudget {
        bytes_per_scope: 7,
        scope_count: 2,
        bytes_per_set: 15,
    };
    for (wire, expected) in [
        ("  ", Error::EmptyScopeRequest),
        ("atproto atproto", Error::DuplicateScope),
        ("atproto\t", Error::NotAScopeToken),
        ("openid", Error::ForbiddenScope),
        (
            "atproto longword",
            Error::RawRequestTooLong {
                bytes: 16,
                limit: 15,
            },
        ),
        ("a bb c", Error::TooManyScopes { count: 3, limit: 2 }),
        ("longword", Error::RawScopeTooLong { bytes: 8, limit: 7 }),
    ] {
        assert_eq!(OAuthScopeTokenizer::tokenize(wire, small), Err(expected));
    }
    assert!(OAuthScopeTokenizer::tokenize("atproto x", small).is_ok());
    let expanded = ScopeSet::from_scope_string("a b c");
    assert_eq!(
        Policy::enforce_expanded_grant_budget(&expanded, small),
        Err(Error::ExpandedGrantTooManyScopes { count: 3, limit: 2 })
    );
    let expanded = ScopeSet::from_scope_string("a longword");
    assert_eq!(
        Policy::enforce_expanded_grant_budget(&expanded, small),
        Err(Error::ExpandedScopeTooLong { bytes: 8, limit: 7 })
    );
    let small_total = OAuthScopeBudget {
        bytes_per_set: 8,
        ..small
    };
    let expanded = ScopeSet::from_scope_string("aaa bbbbb");
    assert_eq!(
        Policy::enforce_expanded_grant_budget(&expanded, small_total),
        Err(Error::ExpandedGrantTooLong { bytes: 9, limit: 8 })
    );
}

#[test]
fn scope_set_keeps_opaque_bytes_and_checks_wildcards_as_requirements() {
    let generic = ScopeSet::from_scope_string("atproto transition:generic");
    let both = ScopeSet::from_scope_string("atproto transition:generic transition:chat.bsky");
    let wildcard = ScopeSet::from_scope_string("rpc:*?aud=did:web:example.com%23svc");
    assert!(generic.allows_rpc("*", "did:web:example.com#svc"));
    assert!(!generic.covers(&wildcard));
    assert!(both.covers(&wildcard));

    let opaque = ScopeSet::parse("space:com.example.group?aud=%3a+%FF").unwrap();
    assert!(opaque.covers(&opaque));
    assert_eq!(opaque.scopes(), []);
    assert_eq!(opaque.normalized_scope_string(), opaque.scope_string());
    assert!(!generic.covers(&opaque));
    assert!(AtProtoScope::parse("rpc:*?aud=*").is_err());
    assert!(
        !ScopeSet::from_scope_string("atproto rpc:*?aud=*")
            .allows_rpc("com.example.method", "did:web:example.com#svc")
    );
}

#[test]
fn wire_normalization_preserves_literal_percent_and_plus() {
    let wire = "blob?accept=image/svg%2Bxml&accept=image/png rpc:com.example.method?aud=did:web:example.com%23svc%2541";
    let grant = ScopeSet::parse(wire).unwrap();
    let normalized = ScopeSet::parse(&grant.normalized_scope_string()).unwrap();
    assert!(normalized.covers(&grant));
    assert!(grant.covers(&normalized));
    assert!(normalized.allows_blob("IMAGE/SVG+XML"));
    assert!(normalized.allows_rpc("com.example.method", "did:web:example.com#svc%41"));
    assert!(!normalized.allows_rpc("com.example.method", "did:web:example.com#svcA"));
}
