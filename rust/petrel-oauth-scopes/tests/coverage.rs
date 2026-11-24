use petrel_oauth_scopes::{ScopeParseError, ScopeSet};

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[allow(
    clippy::too_many_lines,
    reason = "The case table carries the suite vectors"
)]
fn scope_set_coverage_matches_the_swift_client_suite() {
    let cases = [
        ("atproto", "atproto", true),
        ("transition:generic", "atproto", false),
        (
            "atproto repo:* blob:*/* rpc:*?aud=did:web:example.com%23foo",
            "transition:generic",
            false,
        ),
        ("atproto transition:generic", "transition:chat.bsky", false),
        ("transition:email", "transition:email", true),
        ("repo:*", "repo:com.example.foo", true),
        ("repo:*", "repo:com.example.foo?action=create", true),
        ("repo:*", "repo:*", true),
        (
            "repo:*",
            "repo?collection=com.example.foo&collection=com.example.bar",
            true,
        ),
        (
            "repo:*?action=create",
            "repo:com.example.foo?action=create",
            true,
        ),
        ("repo:*?action=create", "repo:com.example.foo", false),
        ("repo:*?action=create", "repo:*", false),
        ("repo:com.example.foo", "repo:com.example.foo", true),
        (
            "repo:com.example.foo",
            "repo:com.example.foo?action=delete",
            true,
        ),
        ("repo:com.example.foo", "repo:com.example.bar", false),
        ("repo:com.example.foo", "repo:*", false),
        ("repo:com.example.foo", "repo:*?action=create", false),
        (
            "repo:com.example.foo",
            "repo?collection=com.example.foo&collection=com.example.bar",
            false,
        ),
        (
            "repo:com.example.foo repo:com.example.bar",
            "repo?collection=com.example.foo&collection=com.example.bar",
            true,
        ),
        (
            "repo:com.example.foo?action=create repo:com.example.foo?action=update&action=delete",
            "repo:com.example.foo",
            true,
        ),
        (
            "repo:com.example.foo?action=create repo:com.example.foo?action=update",
            "repo:com.example.foo",
            false,
        ),
        (
            "repo:com.example.foo?action=create repo:com.example.bar?action=delete",
            "repo?collection=com.example.foo&collection=com.example.bar&action=create",
            false,
        ),
        (
            "rpc:*?aud=did:web:example.com%23foo",
            "rpc:com.example.a?aud=did:web:example.com%23foo",
            true,
        ),
        (
            "rpc:*?aud=did:web:example.com%23foo",
            "rpc:*?aud=did:web:example.com%23foo",
            true,
        ),
        (
            "rpc:*?aud=did:web:example.com%23foo",
            "rpc:com.example.a?aud=did:web:example.com%23bar",
            false,
        ),
        (
            "rpc:*?aud=did:web:example.com%23foo",
            "rpc:com.example.a?aud=*",
            false,
        ),
        (
            "rpc:com.example.a?aud=*",
            "rpc:com.example.a?aud=did:web:example.com%23foo",
            true,
        ),
        ("rpc:com.example.a?aud=*", "rpc:com.example.a?aud=*", true),
        (
            "rpc:com.example.a?aud=*",
            "rpc:com.example.b?aud=did:web:example.com%23foo",
            false,
        ),
        (
            "rpc:com.example.a?aud=*",
            "rpc:*?aud=did:web:example.com%23foo",
            false,
        ),
        (
            "rpc:com.example.a?aud=did:web:example.com%23foo",
            "rpc:com.example.a?aud=did:web:example.com%23foo",
            true,
        ),
        (
            "rpc:com.example.a?aud=did:web:example.com%23foo",
            "rpc?lxm=com.example.a&lxm=com.example.b&aud=did:web:example.com%23foo",
            false,
        ),
        (
            "rpc:com.example.a?aud=* rpc:com.example.b?aud=did:web:example.com%23foo",
            "rpc?lxm=com.example.a&lxm=com.example.b&aud=did:web:example.com%23foo",
            true,
        ),
        (
            "rpc:com.example.a?aud=* rpc:com.example.b?aud=did:web:example.com%23foo",
            "rpc?lxm=com.example.a&lxm=com.example.b&aud=*",
            false,
        ),
        ("blob:*/*", "blob:image/png", true),
        ("blob:*/*", "blob:image/*", true),
        ("blob:*/*", "blob:*/*", true),
        ("blob:*/*", "blob?accept=image/*&accept=video/mp4", true),
        ("blob:image/*", "blob:image/png", true),
        ("blob:image/*", "blob:image/*", true),
        ("blob:image/*", "blob:*/*", false),
        ("blob:image/*", "blob:video/*", false),
        (
            "blob:image/*",
            "blob?accept=image/png&accept=video/mp4",
            false,
        ),
        ("blob:image/png", "blob:image/png", true),
        ("blob:image/png", "blob:image/*", false),
        ("blob:image/png", "blob:image/jpeg", false),
        (
            "blob:image/* blob:video/mp4",
            "blob?accept=image/png&accept=video/mp4",
            true,
        ),
        ("blob:image/png blob:image/jpeg", "blob:image/*", false),
        ("account:email", "account:email", true),
        ("account:email", "account:email?action=manage", false),
        ("account:email?action=manage", "account:email", true),
        (
            "account:email?action=manage",
            "account:email?action=manage",
            true,
        ),
        ("account:email?action=manage", "account:repo", false),
        ("account:status", "account:email", false),
        ("identity:*", "identity:handle", true),
        ("identity:*", "identity:*", true),
        ("identity:handle", "identity:handle", true),
        ("identity:handle", "identity:*", false),
        ("include:com.example.auth", "include:com.example.auth", true),
        (
            "include:com.example.auth",
            "include:com.example.auth?aud=did:web:example.com%23foo",
            false,
        ),
        (
            "include:com.example.auth?aud=did:web:example.com%23foo",
            "include:com.example.auth",
            false,
        ),
        (
            "repo:* rpc:*?aud=did:web:example.com%23foo",
            "include:com.example.auth",
            false,
        ),
        ("include:com.example.auth", "repo:com.example.post", false),
        ("transition:generic", "repo:*", true),
        (
            "transition:generic",
            "repo:com.example.foo?action=delete",
            true,
        ),
        ("transition:generic", "blob:*/*", true),
        ("transition:generic", "blob:image/png", true),
        (
            "transition:generic",
            "rpc:chat.bsky.convo.getConvo?aud=did:web:example.com%23foo",
            false,
        ),
        (
            "transition:generic",
            "rpc?lxm=app.bsky.feed.getFeed&lxm=chat.bsky.convo.getConvo&aud=*",
            false,
        ),
        (
            "transition:generic transition:chat.bsky",
            "rpc:chat.bsky.convo.getConvo?aud=did:web:example.com%23foo",
            true,
        ),
        ("transition:generic", "account:email", false),
        ("transition:generic", "identity:handle", false),
        ("transition:email", "account:email", true),
        ("transition:email", "account:email?action=manage", false),
        ("transition:email", "account:repo", false),
        ("transition:email", "repo:com.example.foo", false),
        (
            "atproto repo:* blob:image/*",
            "atproto repo:com.example.foo blob:image/png",
            true,
        ),
        ("atproto repo:* blob:image/*", "", true),
        ("", "", true),
        ("", "atproto", false),
        (
            "repo:* blob:image/*",
            "atproto repo:com.example.foo blob:image/png",
            false,
        ),
        (
            "atproto repo:* blob:image/*",
            "atproto repo:com.example.foo blob:video/mp4",
            false,
        ),
        (
            "transition:chat.bsky",
            "rpc:chat.bsky.convo.getConvo?aud=did:web:example.com%23foo",
            true,
        ),
        (
            "transition:chat.bsky",
            "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23foo",
            false,
        ),
        (
            "transition:generic",
            "rpc:*?aud=did:web:example.com%23foo",
            false,
        ),
        (
            "transition:generic",
            "rpc:app.bsky.feed.getFeed?aud=*",
            true,
        ),
        (
            "transition:generic transition:chat.bsky",
            "rpc:chat.bsky.convo.getConvo?aud=*",
            true,
        ),
        (
            "transition:generic transition:chat.bsky",
            "rpc:*?aud=did:web:example.com%23foo",
            true,
        ),
    ];
    for (have, need, expected) in cases {
        let granted = ScopeSet::parse_strict(have).unwrap();
        let needed = ScopeSet::parse_strict(need).unwrap();
        assert_eq!(granted.covers(&needed), expected, "{have:?} vs {need:?}");
        if let [scope] = needed.scopes() {
            assert_eq!(
                granted.covers_scope(scope),
                expected,
                "{have:?} vs {need:?}"
            );
        }
        assert!(granted.covers(&granted), "{have:?}");
        assert!(needed.covers(&needed), "{need:?}");
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn strict_parsing_reports_the_first_error_in_wire_order() {
    assert_eq!(
        ScopeSet::parse_strict("atproto rpc:*?aud=* future:extra"),
        Err(ScopeParseError::ForbiddenCombination { prefix: "rpc" }),
    );
    assert_eq!(
        ScopeSet::parse_strict("atproto future:extra rpc:*?aud=*"),
        Err(ScopeParseError::UnknownPrefix),
    );
}
