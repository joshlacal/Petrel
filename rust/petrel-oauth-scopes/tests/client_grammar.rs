use petrel_oauth_scopes::{
    AccountPermission, AtProtoScope, BlobPermission, IdentityPermission, IncludeScope,
    RepoPermission, RpcPermission, ScopeParseError as E, ScopeSet,
};

type Parse = fn(&str) -> Result<AtProtoScope, E>;

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[allow(
    clippy::too_many_lines,
    reason = "The case table carries the suite vectors"
)]
fn swift_parser_diagnostics() {
    let suites: [(Parse, &[(&str, E)]); 7] = [
        (
            |input| RepoPermission::parse(input).map(AtProtoScope::Repo),
            &[
                ("repo:foo bar", E::NotAScopeToken),
                ("repo:foo%20bar", E::InvalidPositional { key: "collection" }),
                ("repo:.foo", E::InvalidPositional { key: "collection" }),
                ("repo:bar.", E::InvalidPositional { key: "collection" }),
                ("repo:invalid", E::InvalidPositional { key: "collection" }),
                (
                    "repo:not-a-valid-nsid",
                    E::InvalidPositional { key: "collection" },
                ),
                (
                    "repo:com.example",
                    E::InvalidPositional { key: "collection" },
                ),
                (
                    "repo:com..example",
                    E::InvalidPositional { key: "collection" },
                ),
                (
                    "repo:9com.example.foo",
                    E::InvalidPositional { key: "collection" },
                ),
                (
                    "repo:com.example.3foo",
                    E::InvalidPositional { key: "collection" },
                ),
                (
                    "repo:com.example.foo-bar",
                    E::InvalidPositional { key: "collection" },
                ),
                (
                    "repo:com.-example.foo",
                    E::InvalidPositional { key: "collection" },
                ),
                (
                    "repo:com.example-.foo",
                    E::InvalidPositional { key: "collection" },
                ),
                (
                    "repo:com.example.foo_bar",
                    E::InvalidPositional { key: "collection" },
                ),
                ("repo:", E::InvalidPositional { key: "collection" }),
                (
                    "repo:?action=create",
                    E::InvalidPositional { key: "collection" },
                ),
                (
                    "repo?collection=",
                    E::InvalidParameter { key: "collection" },
                ),
                (
                    "repo?collection=com.example.foo&collection=nope",
                    E::InvalidParameter { key: "collection" },
                ),
                (
                    "repo:com.example.*",
                    E::InvalidPositional { key: "collection" },
                ),
                ("repo:**", E::InvalidPositional { key: "collection" }),
                (
                    "repo:*.example.foo",
                    E::InvalidPositional { key: "collection" },
                ),
                (
                    "repo?collection=*&collection=com.*",
                    E::InvalidParameter { key: "collection" },
                ),
                (
                    "repo:com.example.foo?action=invalid",
                    E::InvalidParameter { key: "action" },
                ),
                ("repo:*?action=*", E::InvalidParameter { key: "action" }),
                (
                    "repo:com.example.foo?action=",
                    E::InvalidParameter { key: "action" },
                ),
                (
                    "repo:com.example.foo?action",
                    E::InvalidParameter { key: "action" },
                ),
                (
                    "repo:com.example.foo?action=Create",
                    E::InvalidParameter { key: "action" },
                ),
                (
                    "repo:com.example.foo?action=create&action=manage",
                    E::InvalidParameter { key: "action" },
                ),
                (
                    "repo?collection=invalid&action=invalid",
                    E::InvalidParameter { key: "collection" },
                ),
                ("invalid", E::PrefixMismatch { expected: "repo" }),
                ("scope", E::PrefixMismatch { expected: "repo" }),
                (
                    "repos:com.example.foo",
                    E::PrefixMismatch { expected: "repo" },
                ),
                (
                    "rep:com.example.foo",
                    E::PrefixMismatch { expected: "repo" },
                ),
                (
                    "Repo:com.example.foo",
                    E::PrefixMismatch { expected: "repo" },
                ),
                ("repo", E::MissingRequiredParameter { key: "collection" }),
                ("repo?", E::MissingRequiredParameter { key: "collection" }),
                (
                    "repo?action=create",
                    E::MissingRequiredParameter { key: "collection" },
                ),
                (
                    "repo:com.example.foo?collection=com.example.bar",
                    E::PositionalConflict { key: "collection" },
                ),
                (
                    "repo:com.example.foo?foo=bar",
                    E::UnknownParameter {
                        prefix: "repo",
                        key: "foo".into(),
                    },
                ),
                (
                    "repo:com.example.foo?Action=create",
                    E::UnknownParameter {
                        prefix: "repo",
                        key: "Action".into(),
                    },
                ),
                (
                    "repo:com.example.foo?aud=*",
                    E::UnknownParameter {
                        prefix: "repo",
                        key: "aud".into(),
                    },
                ),
                ("", E::PrefixMismatch { expected: "repo" }),
            ],
        ),
        (
            |input| RpcPermission::parse(input).map(AtProtoScope::Rpc),
            &[
                (
                    "rpc?aud=did:web:example.com%23service_id",
                    E::MissingRequiredParameter { key: "lxm" },
                ),
                (
                    "rpc:?aud=did:web:example.com%23service_id",
                    E::InvalidPositional { key: "lxm" },
                ),
                (
                    "rpc?aud=did:web:example.com",
                    E::MissingRequiredParameter { key: "lxm" },
                ),
                ("rpc", E::MissingRequiredParameter { key: "lxm" }),
                (
                    "rpc?lxm=com.example.method1",
                    E::MissingRequiredParameter { key: "aud" },
                ),
                (
                    "rpc:com.example.method1",
                    E::MissingRequiredParameter { key: "aud" },
                ),
                (
                    "rpc:com.example.service",
                    E::MissingRequiredParameter { key: "aud" },
                ),
                ("rpc:*", E::MissingRequiredParameter { key: "aud" }),
                ("rpc:foo.bar.baz?aud=", E::InvalidParameter { key: "aud" }),
                (
                    "rpc:com.example.method1?aud=did:web:example.com&lxm=com.example.method2",
                    E::PositionalConflict { key: "lxm" },
                ),
                (
                    "rpc:foo.bar.baz?aud=did:web:example.com%23service_id&lxm=foo.bar.baz",
                    E::PositionalConflict { key: "lxm" },
                ),
                ("rpc:*?lxm=*", E::PositionalConflict { key: "lxm" }),
                ("rpc?aud=*&lxm=*", E::ForbiddenCombination { prefix: "rpc" }),
                ("rpc:*?aud=*", E::ForbiddenCombination { prefix: "rpc" }),
                (
                    "rpc?lxm=com.example.foo&lxm=*&aud=*",
                    E::ForbiddenCombination { prefix: "rpc" },
                ),
                ("rpc:invalid", E::InvalidPositional { key: "lxm" }),
                ("rpc?lxm=invalid", E::InvalidParameter { key: "lxm" }),
                (
                    "rpc:invalid?aud=did:web:example.com",
                    E::InvalidPositional { key: "lxm" },
                ),
                (
                    "rpc:invalid?aud=did:web:example.com%23service_id",
                    E::InvalidPositional { key: "lxm" },
                ),
                ("rpc:foo.bar", E::InvalidPositional { key: "lxm" }),
                (
                    "rpc?lxm=invalid&aud=invalid",
                    E::InvalidParameter { key: "lxm" },
                ),
                (
                    "rpc:com.example.*?aud=did:web:example.com%23service_id",
                    E::InvalidPositional { key: "lxm" },
                ),
                (
                    "rpc:com.example.service?aud=invalid",
                    E::InvalidParameter { key: "aud" },
                ),
                (
                    "rpc:foo.bar.baz?aud=invalid",
                    E::InvalidParameter { key: "aud" },
                ),
                (
                    "rpc:foo.bar.baz?aud=did:web",
                    E::InvalidParameter { key: "aud" },
                ),
                (
                    "rpc:foo.bar.baz?aud=did:web%23service_id",
                    E::InvalidParameter { key: "aud" },
                ),
                (
                    "rpc:foo.bar.baz?aud=did:plc:111",
                    E::InvalidParameter { key: "aud" },
                ),
                (
                    "rpc:foo.bar.baz?aud=did:plc:111%23service_id",
                    E::InvalidParameter { key: "aud" },
                ),
                (
                    "rpc:foo.bar.baz?aud=did:foo:bar",
                    E::InvalidParameter { key: "aud" },
                ),
                (
                    "rpc:foo.bar.baz?aud=did:foo:bar%23service_id",
                    E::InvalidParameter { key: "aud" },
                ),
                (
                    "rpc:foo.bar.baz?aud=did:web:example.com",
                    E::InvalidParameter { key: "aud" },
                ),
                ("rpc:foo.bar.baz?aud=**", E::InvalidParameter { key: "aud" }),
                (
                    "rpc:foo.bar.baz?aud=*&aud=*",
                    E::RepeatedSingleValue { key: "aud" },
                ),
                (
                    "rpc:foo.bar.baz?aud=did:web:a.example%23x&aud=did:web:b.example%23x",
                    E::RepeatedSingleValue { key: "aud" },
                ),
                (
                    "rpc:com.example.service?aud=did:web:example.com%23service_id&invalid=param",
                    E::UnknownParameter {
                        prefix: "rpc",
                        key: "invalid".into(),
                    },
                ),
                (
                    "rpc:com.example.service?aud=*&action=create",
                    E::UnknownParameter {
                        prefix: "rpc",
                        key: "action".into(),
                    },
                ),
                ("invalid", E::PrefixMismatch { expected: "rpc" }),
                (
                    "notrpc:com.example.service?aud=did:web:example.com%23service_id",
                    E::PrefixMismatch { expected: "rpc" },
                ),
            ],
        ),
        (
            |input| BlobPermission::parse(input).map(AtProtoScope::Blob),
            &[
                ("blob", E::MissingRequiredParameter { key: "accept" }),
                ("blob?", E::MissingRequiredParameter { key: "accept" }),
                ("invalid", E::PrefixMismatch { expected: "blob" }),
                ("scope", E::PrefixMismatch { expected: "blob" }),
                ("blob:invalid", E::InvalidPositional { key: "accept" }),
                (
                    "blob?accept=invalid-mime",
                    E::InvalidParameter { key: "accept" },
                ),
                ("blob?accept=invalid", E::InvalidParameter { key: "accept" }),
                ("blob:*/**", E::InvalidPositional { key: "accept" }),
                ("blob:*/png", E::InvalidPositional { key: "accept" }),
                ("blob:*", E::InvalidPositional { key: "accept" }),
                ("blob:/image", E::InvalidPositional { key: "accept" }),
                ("blob:", E::InvalidPositional { key: "accept" }),
                ("blob:image/", E::InvalidPositional { key: "accept" }),
                ("blob:image//png", E::InvalidPositional { key: "accept" }),
                (
                    "blob:image/png/extra",
                    E::InvalidPositional { key: "accept" },
                ),
                ("blob:image/**", E::InvalidPositional { key: "accept" }),
                ("blob:image/p*", E::InvalidPositional { key: "accept" }),
                ("blob:image/%20png", E::InvalidPositional { key: "accept" }),
                (
                    "blob?accept=image/png&accept=nope",
                    E::InvalidParameter { key: "accept" },
                ),
                (
                    "blob:image/png?accept=image/jpeg",
                    E::PositionalConflict { key: "accept" },
                ),
                (
                    "blob:image/png?foo=bar",
                    E::UnknownParameter {
                        prefix: "blob",
                        key: "foo".into(),
                    },
                ),
                (
                    "blob:image/png?action=create",
                    E::UnknownParameter {
                        prefix: "blob",
                        key: "action".into(),
                    },
                ),
            ],
        ),
        (
            |input| AccountPermission::parse(input).map(AtProtoScope::Account),
            &[
                ("account:invalid", E::InvalidPositional { key: "attr" }),
                ("account:Email", E::InvalidPositional { key: "attr" }),
                ("account:*", E::InvalidPositional { key: "attr" }),
                ("account:", E::InvalidPositional { key: "attr" }),
                (
                    "account:email?action=invalid",
                    E::InvalidParameter { key: "action" },
                ),
                (
                    "account:email?action=",
                    E::InvalidParameter { key: "action" },
                ),
                (
                    "account:email?action=create",
                    E::InvalidParameter { key: "action" },
                ),
                (
                    "account:email?action=*",
                    E::InvalidParameter { key: "action" },
                ),
                (
                    "invalid:email",
                    E::PrefixMismatch {
                        expected: "account",
                    },
                ),
                ("account", E::MissingRequiredParameter { key: "attr" }),
                (
                    "account?action=manage",
                    E::MissingRequiredParameter { key: "attr" },
                ),
                (
                    "",
                    E::PrefixMismatch {
                        expected: "account",
                    },
                ),
                (
                    "account:email?attr=repo",
                    E::PositionalConflict { key: "attr" },
                ),
                (
                    "account?attr=email&attr=repo",
                    E::RepeatedSingleValue { key: "attr" },
                ),
                (
                    "account:email?foo=bar",
                    E::UnknownParameter {
                        prefix: "account",
                        key: "foo".into(),
                    },
                ),
                (
                    "account:email?attribute=repo",
                    E::UnknownParameter {
                        prefix: "account",
                        key: "attribute".into(),
                    },
                ),
            ],
        ),
        (
            |input| IdentityPermission::parse(input).map(AtProtoScope::Identity),
            &[
                (
                    "invalid",
                    E::PrefixMismatch {
                        expected: "identity",
                    },
                ),
                ("identity:invalid", E::InvalidPositional { key: "attr" }),
                ("identity:Handle", E::InvalidPositional { key: "attr" }),
                ("identity:", E::InvalidPositional { key: "attr" }),
                ("identity:**", E::InvalidPositional { key: "attr" }),
                ("identity:did", E::InvalidPositional { key: "attr" }),
                (
                    "identity:*?action=*",
                    E::UnknownParameter {
                        prefix: "identity",
                        key: "action".into(),
                    },
                ),
                (
                    "identity:*?action=manage",
                    E::UnknownParameter {
                        prefix: "identity",
                        key: "action".into(),
                    },
                ),
                (
                    "identity:*?action=submit",
                    E::UnknownParameter {
                        prefix: "identity",
                        key: "action".into(),
                    },
                ),
                (
                    "identity:handle?action=invalid",
                    E::UnknownParameter {
                        prefix: "identity",
                        key: "action".into(),
                    },
                ),
                (
                    "identity?attribute=invalid&action=invalid",
                    E::UnknownParameter {
                        prefix: "identity",
                        key: "attribute".into(),
                    },
                ),
                ("identity", E::MissingRequiredParameter { key: "attr" }),
                ("identity?", E::MissingRequiredParameter { key: "attr" }),
                (
                    "identity:handle?attr=*",
                    E::PositionalConflict { key: "attr" },
                ),
                (
                    "identity?attr=handle&attr=*",
                    E::RepeatedSingleValue { key: "attr" },
                ),
            ],
        ),
        (
            |input| IncludeScope::parse(input).map(AtProtoScope::Include),
            &[
                (
                    "",
                    E::PrefixMismatch {
                        expected: "include",
                    },
                ),
                (
                    "repo:com.example.baz",
                    E::PrefixMismatch {
                        expected: "include",
                    },
                ),
                ("include", E::MissingRequiredParameter { key: "nsid" }),
                (
                    "include#",
                    E::PrefixMismatch {
                        expected: "include",
                    },
                ),
                ("include:", E::InvalidPositional { key: "nsid" }),
                ("include:#", E::InvalidPositional { key: "nsid" }),
                ("include:&", E::InvalidPositional { key: "nsid" }),
                ("include:com..example", E::InvalidPositional { key: "nsid" }),
                ("include:com", E::InvalidPositional { key: "nsid" }),
                ("include:com.example", E::InvalidPositional { key: "nsid" }),
                (
                    "include:9com.example.foo",
                    E::InvalidPositional { key: "nsid" },
                ),
                (
                    "include:com.example.-bar",
                    E::InvalidPositional { key: "nsid" },
                ),
                ("include:invalid^nsid", E::InvalidPositional { key: "nsid" }),
                ("include:nsid", E::InvalidPositional { key: "nsid" }),
                ("include:*", E::InvalidPositional { key: "nsid" }),
                (
                    "include:com.example.*",
                    E::InvalidPositional { key: "nsid" },
                ),
                (
                    "include:com.example.baz?aud=",
                    E::InvalidParameter { key: "aud" },
                ),
                (
                    "include:com.example.baz?aud=did:web:example.com",
                    E::InvalidParameter { key: "aud" },
                ),
                (
                    "include:com.example.baz?aud=invalid^did",
                    E::InvalidParameter { key: "aud" },
                ),
                (
                    "include:com.example.baz?aud=*",
                    E::InvalidParameter { key: "aud" },
                ),
                (
                    "include:com.example.baz?nsid=com.example.qux",
                    E::PositionalConflict { key: "nsid" },
                ),
                (
                    "include?nsid=com.example.baz&nsid=com.example.qux",
                    E::RepeatedSingleValue { key: "nsid" },
                ),
                (
                    "include:com.example.baz?aud=did:web:a.example%23x&aud=did:web:b.example%23x",
                    E::RepeatedSingleValue { key: "aud" },
                ),
                (
                    "include:com.example.baz?lxm=com.example.foo",
                    E::UnknownParameter {
                        prefix: "include",
                        key: "lxm".into(),
                    },
                ),
            ],
        ),
        (
            AtProtoScope::parse,
            &[
                ("atproto:", E::UnknownPrefix),
                ("atproto:foo", E::UnknownPrefix),
                ("atproto?", E::UnknownPrefix),
                ("atproto?x=y", E::UnknownPrefix),
                ("transition", E::UnknownPrefix),
                ("transition:", E::UnknownPrefix),
                ("transition:foo", E::UnknownPrefix),
                ("transition:Generic", E::UnknownPrefix),
                ("transition:generic?", E::UnknownPrefix),
                ("transition:generic?x=1", E::UnknownPrefix),
                ("transition:chat.bsky.convo", E::UnknownPrefix),
                ("transition:chat", E::UnknownPrefix),
                ("transition?name=generic", E::UnknownPrefix),
                ("transition:%67eneric", E::UnknownPrefix),
                ("ATPROTO", E::UnknownPrefix),
                ("Atproto", E::UnknownPrefix),
                ("atproto2", E::UnknownPrefix),
                ("Transition:generic", E::UnknownPrefix),
                ("openid", E::UnknownPrefix),
                ("profile", E::UnknownPrefix),
                ("email", E::UnknownPrefix),
                ("offline_access", E::UnknownPrefix),
                ("https://example.com/scope", E::UnknownPrefix),
                (":foo", E::UnknownPrefix),
                ("?x=y", E::UnknownPrefix),
                (
                    "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a+b",
                    E::InvalidParameter { key: "aud" },
                ),
                (
                    "blob?accept=image/svg+xml",
                    E::InvalidParameter { key: "accept" },
                ),
                (
                    "repo:com.example.record?collection=com.example.other",
                    E::PositionalConflict { key: "collection" },
                ),
                (
                    "repo:com.example.*",
                    E::InvalidPositional { key: "collection" },
                ),
                (
                    "rpc:com.example.*?aud=*",
                    E::InvalidPositional { key: "lxm" },
                ),
                ("rpc:*?aud=*", E::ForbiddenCombination { prefix: "rpc" }),
                ("rpc?lxm=*&aud=*", E::ForbiddenCombination { prefix: "rpc" }),
                (
                    "rpc:app.example.moderation.createReport",
                    E::MissingRequiredParameter { key: "aud" },
                ),
                (
                    "rpc:app.example.moderation.createReport?aud=did:web:api.example.com",
                    E::InvalidParameter { key: "aud" },
                ),
                ("account:*", E::InvalidPositional { key: "attr" }),
                (
                    "account:email?action=delete",
                    E::InvalidParameter { key: "action" },
                ),
                (
                    "repo:app.example.profile?action=read",
                    E::InvalidParameter { key: "action" },
                ),
                ("repo", E::MissingRequiredParameter { key: "collection" }),
                ("rpc?aud=*", E::MissingRequiredParameter { key: "lxm" }),
                ("blob", E::MissingRequiredParameter { key: "accept" }),
                ("account", E::MissingRequiredParameter { key: "attr" }),
                ("identity", E::MissingRequiredParameter { key: "attr" }),
                ("include", E::MissingRequiredParameter { key: "nsid" }),
                ("resource", E::UnknownPrefix),
                ("resource:positional?key=val", E::UnknownPrefix),
                ("resource:positional&thing?key=val", E::UnknownPrefix),
                ("service:did:web:com.example#type?key=val", E::UnknownPrefix),
                ("resource:", E::UnknownPrefix),
                ("resource:?", E::UnknownPrefix),
                ("resource:&", E::UnknownPrefix),
                ("resource?", E::UnknownPrefix),
                ("resource:positional?key=qu\u{E9}bec", E::UnknownPrefix),
                ("emoji:\u{263A}\u{FE0F}", E::UnknownPrefix),
            ],
        ),
    ];
    for (parse, cases) in suites {
        for (input, expected) in cases {
            assert_eq!(parse(input), Err(expected.clone()), "{input:?}");
        }
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[allow(
    clippy::too_many_lines,
    reason = "The case table carries the suite vectors"
)]
fn canonical_spellings_outside_the_upstream_corpus() {
    let cases = [
        ("repo:com.example.foo", "repo:com.example.foo"),
        (
            "repo:com.example.foo?action=create",
            "repo:com.example.foo?action=create",
        ),
        (
            "repo:com.example.foo?action=create&action=update",
            "repo:com.example.foo?action=create&action=update",
        ),
        ("repo:*?action=create&action=update&action=delete", "repo:*"),
        (
            "repo:com.example.foo?action=create&action=update&action=delete",
            "repo:com.example.foo",
        ),
        ("repo:*?action=create", "repo:*?action=create"),
        ("repo:*?action=update", "repo:*?action=update"),
        ("repo?collection=*&action=update", "repo:*?action=update"),
        (
            "repo?collection=*&collection=com.example.foo&action=update",
            "repo:*?action=update",
        ),
        ("repo?collection=*", "repo:*"),
        (
            "repo?collection=*&action=create&action=update&action=delete",
            "repo:*",
        ),
        ("repo?collection=*&collection=com.example.foo", "repo:*"),
        (
            "repo?action=create&collection=com.example.foo",
            "repo:com.example.foo?action=create",
        ),
        (
            "repo?collection=com.example.foo&action=create&action=update&action=delete",
            "repo:com.example.foo",
        ),
        (
            "repo?action=create&collection=com.example.foo&collection=com.example.bar",
            "repo?collection=com.example.bar&collection=com.example.foo&action=create",
        ),
        (
            "repo:com.example.foo?action=delete&action=create",
            "repo:com.example.foo?action=create&action=delete",
        ),
        (
            "repo:com.example.foo?action=create&action=create",
            "repo:com.example.foo?action=create",
        ),
        (
            "repo?collection=com.example.foo&collection=com.example.foo",
            "repo:com.example.foo",
        ),
        ("repo:com.example.foo?", "repo:com.example.foo"),
        ("repo:%2A", "repo:*"),
        (
            "repo:com.example.foo?%61ction=%63reate",
            "repo:com.example.foo?action=create",
        ),
        (
            "rpc:com.example.service?aud=did:web:example.com%23service_id",
            "rpc:com.example.service?aud=did:web:example.com%23service_id",
        ),
        (
            "rpc:com.example.service?aud=did:web:example.com#service_id",
            "rpc:com.example.service?aud=did:web:example.com%23service_id",
        ),
        (
            "rpc?lxm=com.example.method1&lxm=com.example.method2&aud=*",
            "rpc?lxm=com.example.method1&lxm=com.example.method2&aud=*",
        ),
        (
            "rpc?lxm=com.example.method1&lxm=com.example.method2&lxm=*&aud=did:web:example.com%23service_id",
            "rpc:*?aud=did:web:example.com%23service_id",
        ),
        (
            "rpc?aud=did:web:example.com%23foo&lxm=com.example.service",
            "rpc:com.example.service?aud=did:web:example.com%23foo",
        ),
        (
            "rpc?lxm=com.example.method1&aud=did:web:example.com#foo",
            "rpc:com.example.method1?aud=did:web:example.com%23foo",
        ),
        (
            "rpc?lxm=com.example.method1&aud=did:web:example.com%23bar",
            "rpc:com.example.method1?aud=did:web:example.com%23bar",
        ),
        (
            "rpc?lxm=com.example.b&lxm=com.example.a&lxm=com.example.b&aud=*",
            "rpc?lxm=com.example.a&lxm=com.example.b&aud=*",
        ),
        (
            "rpc:com.example.method1?aud=did%3Aweb%3Aexample.com%23foo",
            "rpc:com.example.method1?aud=did:web:example.com%23foo",
        ),
        (
            "rpc:com.example.method1?aud=did:plc:ewvi7nxzyoun6zhxrhs64oiz%23atproto_labeler",
            "rpc:com.example.method1?aud=did:plc:ewvi7nxzyoun6zhxrhs64oiz%23atproto_labeler",
        ),
        (
            "rpc:com.example.method1?aud=%2A",
            "rpc:com.example.method1?aud=*",
        ),
        ("blob?accept=image/png", "blob:image/png"),
        ("blob?accept=image/png&accept=*/*", "blob:*/*"),
        ("blob?accept=image/png&accept=image/*", "blob:image/*"),
        (
            "blob?accept=video/*&accept=image/*",
            "blob?accept=image/*&accept=video/*",
        ),
        ("blob:%2A%2F%2A", "blob:*/*"),
        (
            "blob:application/vnd.api+json",
            "blob:application/vnd.api+json",
        ),
        ("blob:image/svg%2Bxml", "blob:image/svg+xml"),
        (
            "blob:text/plain;charset=utf-8",
            "blob:text/plain%3Bcharset%3Dutf-8",
        ),
        ("account?attr=status&action=read", "account:status"),
        ("account:email?", "account:email"),
        ("include:com.example.bar", "include:com.example.bar"),
        (
            "include:com.example.baz?aud=did:web:example.com%23my_service",
            "include:com.example.baz?aud=did:web:example.com%23my_service",
        ),
        (
            "include:com.example.baz?aud=did:web:example.com#my_service",
            "include:com.example.baz?aud=did:web:example.com%23my_service",
        ),
        ("include?nsid=com.example.baz", "include:com.example.baz"),
        (
            "include?aud=did:web:example.com%23my_service&nsid=com.example.baz",
            "include:com.example.baz?aud=did:web:example.com%23my_service",
        ),
        ("include:com.example.bar?", "include:com.example.bar"),
        (
            "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%2Bb",
            "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a+b",
        ),
        (
            "blob?accept=image/svg%2Bxml&accept=image/png",
            "blob?accept=image/png&accept=image/svg+xml",
        ),
        (
            "rpc:app.bsky.feed.getFeed?aud=did:web:localhost%253A8080%23svc",
            "rpc:app.bsky.feed.getFeed?aud=did:web:localhost%3A8080%23svc",
        ),
        (
            "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%2541",
            "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%41",
        ),
        (
            "blob?accept=image/png&accept=image/png",
            "blob?accept=image/png",
        ),
    ];
    for (input, expected) in cases {
        let parsed = AtProtoScope::parse(input).unwrap();
        assert_eq!(
            parsed.canonical_scope_string().unwrap(),
            expected,
            "{input:?}"
        );
        let loses_meaning_or_spelling = matches!(
            input,
            "blob?accept=image/svg%2Bxml&accept=image/png"
                | "rpc:app.bsky.feed.getFeed?aud=did:web:localhost%253A8080%23svc"
                | "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%2541"
                | "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%2Bb"
                | "blob?accept=image/png&accept=image/png"
        );
        let original = ScopeSet::from_scopes([parsed]).unwrap();
        let canonical_is_fixed_point = AtProtoScope::parse(expected).is_ok_and(|canonical| {
            let stable = canonical.canonical_scope_string().as_deref() == Ok(expected);
            let reparsed = ScopeSet::from_scopes([canonical]).unwrap();
            stable && original.covers(&reparsed) && reparsed.covers(&original)
        });
        assert_eq!(
            canonical_is_fixed_point, !loses_meaning_or_spelling,
            "{input:?}"
        );
        let wire = ScopeSet::parse_strict(&original.scope_string()).unwrap();
        assert!(
            original.covers(&wire) && wire.covers(&original),
            "{input:?}"
        );
    }
}
