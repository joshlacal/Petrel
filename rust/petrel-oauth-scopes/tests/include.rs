use petrel_oauth_scopes::{
    ExpansionRejectionReason as Reason, IncludeScope, LexiconPermissionSet, ScopeSet,
};

type ExpansionCase<'a> = (&'a str, &'a str, &'a str, &'a [&'a str], &'a [Reason]);

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[allow(
    clippy::too_many_lines,
    reason = "The case table carries the suite vectors"
)]
fn expansion_preserves_swift_grants_and_rejection_reasons() {
    let cases: &[ExpansionCase<'_>] = &[
        (
            "blob: rejects valid permissions",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"blob","accept":["image/*"]}]"#,
            &[],
            &[Reason::NotAllowedInPermissionSet],
        ),
        (
            "blob: rejects invalid permissions (accept is not an array)",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"blob","accept":"image/*"}]"#,
            &[],
            &[Reason::NotAllowedInPermissionSet],
        ),
        (
            "blob: rejects invalid permissions (extra property)",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"blob","accept":["image/*"],"extra":"property"}]"#,
            &[],
            &[Reason::NotAllowedInPermissionSet],
        ),
        (
            "rpc: allows * aud",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"*","lxm":["com.example.calendar.listEvents"]}]"#,
            &["rpc:com.example.calendar.listEvents?aud=*"],
            &[],
        ),
        (
            "rpc: inherits aud",
            "include:com.example.calendar.auth?aud=did:web:example.com#foo",
            r#"[{"type":"permission","resource":"rpc","inheritAud":true,"lxm":["com.example.calendar.listEvents"]},{"type":"permission","resource":"rpc","inheritAud":true,"lxm":["com.example.calendar.getEventDetails"]}]"#,
            &[
                "rpc:com.example.calendar.listEvents?aud=did:web:example.com%23foo",
                "rpc:com.example.calendar.getEventDetails?aud=did:web:example.com%23foo",
            ],
            &[],
        ),
        (
            "rpc: forbids use of a specific aud",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo","lxm":["com.example.calendar.listEvents"]}]"#,
            &[],
            &[Reason::NotAllowedInPermissionSet],
        ),
        (
            "rpc: invalid lxm syntax (not an array)",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo","lxm":"com.example.calendar.listEvents"}]"#,
            &[],
            &[Reason::NotAllowedInPermissionSet],
        ),
        (
            "rpc: invalid lxm syntax (not an array), wildcard aud",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"*","lxm":"com.example.calendar.listEvents"}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "rpc: extra properties",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo","lxm":["com.example.calendar.listEvents"],"extra":"property"}]"#,
            &[],
            &[Reason::NotAllowedInPermissionSet],
        ),
        (
            "rpc: extra properties, wildcard aud",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"*","lxm":["com.example.calendar.listEvents"],"extra":"property"}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "rpc: missing lxm",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo"}]"#,
            &[],
            &[Reason::NotAllowedInPermissionSet],
        ),
        (
            "rpc: missing lxm, wildcard aud",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"*"}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "rpc: missing aud",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","lxm":["com.example.calendar.listEvents"]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "rpc: missing aud and lxm",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc"}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "rpc: both inheritAud and aud specified",
            "include:com.example.calendar.auth?aud=did:web:example.com#bar",
            r#"[{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo","inheritAud":true,"lxm":["com.example.calendar.listEvents"]}]"#,
            &[],
            &[Reason::NotAllowedInPermissionSet],
        ),
        (
            "rpc: both inheritAud and wildcard aud specified",
            "include:com.example.calendar.auth?aud=did:web:example.com#bar",
            r#"[{"type":"permission","resource":"rpc","aud":"*","inheritAud":true,"lxm":["com.example.calendar.listEvents"]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "rpc: invalid authority, specific aud",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"did:web:example.com#foo","lxm":["com.atproto.moderation.createReport"]}]"#,
            &[],
            &[Reason::NotAllowedInPermissionSet],
        ),
        (
            "rpc: un-specified inherited aud",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","inheritAud":true,"lxm":["com.example.calendar.listEvents"]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "rpc: wildcard aud for an invalid authority",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"*","lxm":["com.atproto.moderation.createReport"]}]"#,
            &[],
            &[Reason::OutsideNamespaceAuthority],
        ),
        (
            "rpc: inherited aud for an invalid authority",
            "include:com.example.calendar.auth?aud=did:web:example.com#foo",
            r#"[{"type":"permission","resource":"rpc","inheritAud":true,"lxm":["com.example.calendar.listEvents","com.example.contacts.list"]}]"#,
            &[],
            &[Reason::OutsideNamespaceAuthority],
        ),
        (
            "rpc: wildcard lxm",
            "include:com.example.calendar.auth?aud=did:web:example.com#foo",
            r#"[{"type":"permission","resource":"rpc","inheritAud":true,"lxm":["*"]}]"#,
            &[],
            &[Reason::OutsideNamespaceAuthority],
        ),
        (
            "rpc: wildcard lxm next to a valid one, wildcard aud",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"*","lxm":["com.example.calendar.listEvents","*"]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "rpc: partial wildcard lxm",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"*","lxm":["com.example.calendar.*"]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "rpc: invalid lxm value",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"*","lxm":["listEvents"]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "rpc: empty lxm",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"*","lxm":[]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "rpc: lxm with a non-string element",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"*","lxm":["com.example.calendar.listEvents",1]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "rpc: aud is not a string",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":["*"],"lxm":["com.example.calendar.listEvents"]}]"#,
            &[],
            &[Reason::NotAllowedInPermissionSet],
        ),
        (
            "rpc: inheritAud is not a boolean",
            "include:com.example.calendar.auth?aud=did:web:example.com#foo",
            r#"[{"type":"permission","resource":"rpc","inheritAud":"true","lxm":["com.example.calendar.listEvents"]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "rpc: collection is not an rpc field",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"*","lxm":["com.example.calendar.listEvents"],"collection":["com.example.calendar.event"]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "rpc: inheritAud false with a wildcard aud",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"*","inheritAud":false,"lxm":["com.example.calendar.listEvents"]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "rpc: inheritAud false without aud does not inherit",
            "include:com.example.calendar.auth?aud=did:web:example.com#foo",
            r#"[{"type":"permission","resource":"rpc","inheritAud":false,"lxm":["com.example.calendar.listEvents"]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "rpc: several lxm are sorted",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"rpc","aud":"*","lxm":["com.example.calendar.listEvents","com.example.calendar.getEventDetails"]}]"#,
            &[
                "rpc?lxm=com.example.calendar.getEventDetails&lxm=com.example.calendar.listEvents&aud=*",
            ],
            &[],
        ),
        (
            "repo: valid permission",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"],"action":["create","update","delete"]}]"#,
            &["repo:com.example.calendar.event"],
            &[],
        ),
        (
            "repo: valid permission without action",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"]}]"#,
            &["repo:com.example.calendar.event"],
            &[],
        ),
        (
            "repo: valid permission with partial actions",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"],"action":["delete","update"]},{"type":"permission","resource":"repo","collection":["com.example.calendar.event","com.example.calendar.rsvp"],"action":["delete","create"]}]"#,
            &[
                "repo:com.example.calendar.event?action=update&action=delete",
                "repo?collection=com.example.calendar.event&collection=com.example.calendar.rsvp&action=create&action=delete",
            ],
            &[],
        ),
        (
            "repo: invalid collection syntax (not an array)",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","collection":"com.example.calendar.event","action":["create","update","delete"]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "repo: invalid action syntax (not an array)",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"],"action":"all"}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "repo: invalid action values",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"],"action":["create","update","manage"]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "repo: invalid authority",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","collection":["app.bsky.feed.post"],"action":["create","update","delete"]}]"#,
            &[],
            &[Reason::OutsideNamespaceAuthority],
        ),
        (
            "repo: one valid and one invalid authority",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event","app.bsky.feed.post"],"action":["create","update","delete"]}]"#,
            &[],
            &[Reason::OutsideNamespaceAuthority],
        ),
        (
            "repo: wildcard collection",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","collection":["*"]}]"#,
            &[],
            &[Reason::OutsideNamespaceAuthority],
        ),
        (
            "repo: wildcard collection next to a valid one",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event","*"],"action":["delete"]}]"#,
            &[],
            &[Reason::OutsideNamespaceAuthority],
        ),
        (
            "repo: partial wildcard collection",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","collection":["com.example.calendar.*"]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "repo: missing collection",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","action":["create"]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "repo: empty collection",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","collection":[]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "repo: empty action",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"],"action":[]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "repo: invalid collection value",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","collection":["event"]}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "repo: inheritAud is not a repo field",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"],"inheritAud":true}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "repo: extra properties",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"repo","collection":["com.example.calendar.event"],"extra":1.5}]"#,
            &[],
            &[Reason::InvalidPermission],
        ),
        (
            "account: rejects account permissions",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"account","attr":"email","action":["read"]}]"#,
            &[],
            &[Reason::NotAllowedInPermissionSet],
        ),
        (
            "identity: rejects identity permissions",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"identity","attr":"handle"}]"#,
            &[],
            &[Reason::NotAllowedInPermissionSet],
        ),
        (
            "include: rejects nested permission sets",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"include","nsid":"com.example.calendar.authOther"}]"#,
            &[],
            &[Reason::NotAllowedInPermissionSet],
        ),
        (
            "unknown resource",
            "include:com.example.calendar.auth",
            r#"[{"type":"permission","resource":"space","name":"com.example.calendar.shared"}]"#,
            &[],
            &[Reason::NotAllowedInPermissionSet],
        ),
        (
            "empty permission set",
            "include:com.example.calendar.auth",
            "[]",
            &[],
            &[],
        ),
    ];
    for &(name, scope, entries, expected, reasons) in cases {
        let include = IncludeScope::parse(scope).unwrap();
        let definition = format!(r#"{{"type":"permission-set", "permissions":{entries}}}"#);
        let set: LexiconPermissionSet = serde_json::from_str(&definition).unwrap();
        let expansion = include.expansion(&set);
        assert_eq!(
            include.expand_to_scope_strings(&set).unwrap(),
            expected,
            "{name}"
        );
        assert_eq!(include.expand(&set), expansion.permissions, "{name}");
        assert_eq!(
            expansion.permissions.len() + expansion.rejections.len(),
            set.permissions.len(),
            "{name}"
        );
        let observed: Vec<_> = expansion
            .rejections
            .iter()
            .map(|entry| entry.reason)
            .collect();
        assert_eq!(observed, reasons, "{name}");
        for rejection in expansion.rejections {
            assert_eq!(
                rejection.permission, &set.permissions[rejection.index],
                "{name}"
            );
        }
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn permission_set_ignores_only_invalid_entries_and_display_metadata() {
    let set: LexiconPermissionSet = serde_json::from_str(r#"{
        "type": "query",
        "title": "Calendar",
        "title:lang": {"ja": "カレンダー", "PT": "Calendário", "pt-PT": "Agenda"},
        "detail": "Events",
        "detail:lang": "malformed",
        "permissions": [
            {"type":"params", "resource":"repo", "collection":["com.example.calendar.event"]},
            {"type":"permission", "resource":"rpc", "aud":null, "lxm":["com.example.calendar.events"]},
            {"type":"permission", "resource":"repo", "action":null, "collection":["com.example.calendar.rsvp"]},
            {"type":"permission", "resource":"repo", "collection":[{"nsid":"com.example.calendar.rsvp"}]},
            {"type":"permission", "resource":"repo", "nested":{"a":1}, "collection":["com.example.calendar.rsvp"]},
            {"type":"permission", "resource":"repo", "collection":["app.bsky.feed.post"]}
        ]
    }"#).unwrap();
    assert_eq!(set.kind, "query");
    assert_eq!(set.permissions[0].kind, "params");
    assert_eq!(set.localized_title(&["ja-JP", "en"]), Some("カレンダー"));
    assert_eq!(set.localized_title(&["pt-BR"]), Some("Calendário"));
    assert_eq!(set.localized_title(&["PT-pt"]), Some("Agenda"));
    assert_eq!(set.localized_detail(&["fr"]), Some("Events"));
    assert_eq!(
        serde_json::from_value::<LexiconPermissionSet>(serde_json::to_value(&set).unwrap())
            .unwrap(),
        set
    );

    let include = IncludeScope::parse("include:com.example.calendar.auth").unwrap();
    let expansion = include.expansion(&set);
    assert_eq!(
        include.expand_to_scope_strings(&set).unwrap(),
        ["repo:com.example.calendar.event"]
    );
    assert_eq!(
        expansion
            .rejections
            .iter()
            .map(|entry| entry.index)
            .collect::<Vec<_>>(),
        [1, 2, 3, 4, 5]
    );
    assert_eq!(
        expansion.rejections[0].reason,
        Reason::NotAllowedInPermissionSet
    );
    assert_eq!(
        expansion.rejections[4].reason,
        Reason::OutsideNamespaceAuthority
    );
    assert!(
        ScopeSet::from_scope_string("repo:com.example.calendar.event")
            .allows_repo("com.example.calendar.event", "create")
    );
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn permission_definition_rejects_invalid_documents() {
    for raw in [
        r#"{"lexicon":1,"id":"com.example.foo","defs":{"main":{"type":"permission-set","permissions":[]}}}"#,
        r#"{"permissions":[]}"#,
        r#"{"type":"permission-set"}"#,
        r#"{"type":"permission-set","permissions":{}}"#,
        r#"{"type":"permission-set","permissions":["repo:*"]}"#,
        r#"{"type":"permission-set","permissions":[{"type":"permission"}]}"#,
        r#"{"type":"permission-set","permissions":[{"resource":"repo"}]}"#,
        r#"{"type":"permission-set","permissions":[{"type":"permission","resource":1}]}"#,
        r#"{"type":"permission-set","title":1,"permissions":[]}"#,
    ] {
        assert!(
            serde_json::from_str::<LexiconPermissionSet>(raw).is_err(),
            "{raw}"
        );
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn namespace_authority_additional_swift_cases() {
    for (set, resource, expected) in [
        ("com.example.foo.auth", "com.example.foo.bar.baz.quz", true),
        ("com.example.foo.auth", "com.example.bar.foo", false),
        ("com.example.foo.auth", "com.example.bar.qux", false),
        ("com.example.foo.auth", "com.atproto.foo", false),
        ("com.example.foo.auth", "com.atproto.foo.auth", false),
        ("com.example.foo.auth", "com.atproto.foo.bar", false),
        ("com.example.foo.auth", "com.example.fooBar.baz", false),
        ("com.example.foo.auth", "com.example.foobar", false),
        ("com.example.foo.auth", "com.example.auth", false),
        ("com.example.foo.auth", "com.example.foo.auth", true),
        ("com.example.foo.auth", "com.example.Foo.identifier", false),
        (
            "app.example.authFull",
            "app.example.feed.getPostThread",
            true,
        ),
        (
            "app.example.authFull",
            "app.example.feed.deeper.still.record",
            true,
        ),
        ("app.example.authFull", "app.other.feed.post", false),
        ("app.example.authFull", "com.example.feed.post", false),
    ] {
        let include = IncludeScope::new(set, None).unwrap();
        assert_eq!(
            include.is_parent_authority_of(resource),
            expected,
            "{set:?} / {resource:?}"
        );
    }
}
