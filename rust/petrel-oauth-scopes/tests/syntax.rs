use petrel_oauth_scopes::{AtProtoScope, ScopeParseError, ScopeStringSyntax, SingleLookup};

#[test]
fn scope_parts_and_parameter_order() {
    type Case<'a> = (&'a str, &'a str, Option<&'a str>, &'a [(&'a str, &'a str)]);
    let cases: &[Case<'_>] = &[
        ("my-res", "my-res", None, &[]),
        ("my-res:my-pos", "my-res", Some("my-pos"), &[]),
        ("my-res:", "my-res", Some(""), &[]),
        (
            "my-res:foo?x=value&y=value-y",
            "my-res",
            Some("foo"),
            &[("x", "value"), ("y", "value-y")],
        ),
        (
            "my-res?x=value&y=value-y",
            "my-res",
            None,
            &[("x", "value"), ("y", "value-y")],
        ),
        (
            "my-res?x=foo&x=bar&x=baz",
            "my-res",
            None,
            &[("x", "foo"), ("x", "bar"), ("x", "baz")],
        ),
        (
            "rpc:foo.bar?aud=did:foo:bar?lxm=bar.baz",
            "rpc",
            Some("foo.bar"),
            &[("aud", "did:foo:bar?lxm=bar.baz")],
        ),
        ("my-res?x=a:b", "my-res", None, &[("x", "a:b")]),
        ("my-res?flag", "my-res", None, &[("flag", "")]),
        ("my-res?&x=1&&", "my-res", None, &[("x", "1")]),
        ("my-res?x=a=b", "my-res", None, &[("x", "a=b")]),
        ("my-res:my%20pos", "my-res", Some("my pos"), &[]),
        ("my-res:my:pos", "my-res", Some("my:pos"), &[]),
        (
            "my-res?x=my%20value&%79=%C3%A9",
            "my-res",
            None,
            &[("x", "my value"), ("y", "é")],
        ),
        (
            "resource:positional&thing?key=val",
            "resource",
            Some("positional&thing"),
            &[("key", "val")],
        ),
        (
            "service:did:web:com.example#type?key=val",
            "service",
            Some("did:web:com.example#type"),
            &[("key", "val")],
        ),
        ("resource:?", "resource", Some(""), &[]),
        ("resource:&", "resource", Some("&"), &[]),
        ("resource?", "resource", None, &[]),
    ];

    for &(raw, prefix, positional, parameters) in cases {
        let parsed = ScopeStringSyntax::parse(raw).unwrap();
        assert_eq!(parsed.prefix, prefix, "{raw}");
        assert_eq!(parsed.positional.as_deref(), positional, "{raw}");
        let entries: Vec<_> = parsed
            .parameters
            .entries()
            .iter()
            .map(|(key, value)| (key.as_str(), value.as_str()))
            .collect();
        assert_eq!(entries, parameters, "{raw}");
        assert_eq!(parsed.parameters.single("absent"), SingleLookup::Absent);
    }

    let syntax = ScopeStringSyntax::parse("repo:foo?name=x&other=1&name=y").unwrap();
    assert_eq!(syntax.parameters.ordered_keys(), ["name", "other"]);
    assert_eq!(
        syntax.parameters.single("name"),
        SingleLookup::Repeated(vec!["x", "y"])
    );
    assert_eq!(
        syntax.parameters.single("other"),
        SingleLookup::Present("1")
    );
}

#[test]
fn checks_resource_prefix_at_the_delimiter() {
    for (scope, prefix, result) in [
        ("prefix", "prefix", true),
        ("prefix", "differentResource", false),
        ("prefix:positional", "prefix", true),
        ("differentResource:positional", "prefix", false),
        ("prefix?param=value", "prefix", true),
        ("prefix", "prefi", false),
        ("prefix:pos", "prefi", false),
        ("prefix?param=value", "prefi", false),
        ("prefix", "fix", false),
        ("prefix:pos", "fix", false),
        ("prefix?param=value", "fix", false),
        ("differentResource?param=value", "prefix", false),
    ] {
        assert_eq!(
            ScopeStringSyntax::is_scope_string(scope, prefix),
            result,
            "{scope} / {prefix}"
        );
    }
}

#[test]
fn percent_decoding_is_strict_only_in_the_positional_part() {
    for input in [
        "repo:%",
        "repo:%A",
        "repo:%G0",
        "repo:%C3%28",
        "repo:%FF",
        "repo:%C3",
    ] {
        assert_eq!(
            ScopeStringSyntax::parse(input),
            Err(ScopeParseError::MalformedPercentEncoding)
        );
        assert_eq!(
            AtProtoScope::parse(input),
            Err(ScopeParseError::MalformedPercentEncoding)
        );
    }
    for (raw, key, value) in [
        ("repo:com.example.foo?action=%", "action", "%"),
        ("repo:com.example.foo?action=%G0", "action", "%G0"),
        ("repo:com.example.foo?%=create", "%", "create"),
        ("repo:com.example.foo?action=%C3%28", "action", "\u{FFFD}("),
    ] {
        let syntax = ScopeStringSyntax::parse(raw).unwrap();
        assert_eq!(
            syntax.parameters.single(key),
            SingleLookup::Present(value),
            "{raw}"
        );
        assert!(AtProtoScope::parse(raw).is_err(), "{raw}");
    }
    assert_eq!(
        ScopeStringSyntax::parse("x:%2f%2F")
            .unwrap()
            .positional
            .as_deref(),
        Some("//")
    );
}

#[test]
fn scope_syntax_matches_reference_escaping() {
    for (raw, canonical, stable) in [
        ("my-res", "my-res", true),
        ("my-res:", "my-res:", true),
        ("my-res:my-pos", "my-res:my-pos", true),
        (
            "my-res:foo?x=value&y=value-y",
            "my-res:foo?x=value&y=value-y",
            true,
        ),
        ("my-res?x=foo&x=bar&x=baz", "my-res?x=foo&x=bar&x=baz", true),
        ("my-res?", "my-res", true),
        ("my-res:pos?", "my-res:pos", true),
        ("my-res:pos?&", "my-res:pos", true),
        (
            "my-res:a%23b%3Fc%26d%3De%20f",
            "my-res:a%23b%3Fc%26d%3De%20f",
            true,
        ),
        ("my-res:a#b&c=d", "my-res:a%23b%26c%3Dd", true),
        ("my-res?x=a#b", "my-res?x=a%23b", true),
        ("my-res?x=a%26b%3Dc", "my-res?x=a%26b%3Dc", true),
        ("my-res:a%3Ab%2Fc%2Cd%40e", "my-res:a:b/c,d@e", true),
        ("my-res?x=a%3Ab%2Fc%2Cd%40e", "my-res?x=a:b/c,d@e", true),
        ("my-res:!~*'()", "my-res:!~*'()", true),
        ("my-res?x=!~*'()", "my-res?x=%21%7E*%27%28%29", true),
        ("my-res:a%20b", "my-res:a%20b", true),
        ("my-res?x=a%20b", "my-res?x=a+b", true),
        ("my-res:a+b", "my-res:a+b", true),
        ("my-res:a%2Bb", "my-res:a+b", true),
        ("my-res?x=a+b", "my-res?x=a+b", true),
        ("my-res?x=a%2Bb", "my-res?x=a+b", false),
        ("my-res:100%25", "my-res:100%", false),
        ("my-res?x=%253A", "my-res?x=%3A", false),
        (
            "my-res:%C3%A9?x=%E2%98%BA",
            "my-res:%C3%A9?x=%E2%98%BA",
            true,
        ),
    ] {
        let syntax = ScopeStringSyntax::parse(raw).unwrap();
        assert_eq!(syntax.canonical_string().unwrap(), canonical, "{raw}");
        assert_eq!(
            ScopeStringSyntax::parse(canonical).as_ref() == Ok(&syntax),
            stable,
            "{raw}"
        );
        assert_eq!(
            ScopeStringSyntax::parse(&syntax.wire_string().unwrap()),
            Ok(syntax),
            "{raw}"
        );
    }
}

#[test]
fn accepts_only_the_rfc6749_token_alphabet() {
    for byte in 0..=u8::MAX {
        let one = char::from(byte).to_string();
        let valid = matches!(byte, 0x21 | 0x23..=0x5b | 0x5d..=0x7e);
        assert_eq!(ScopeStringSyntax::parse(&one).is_ok(), valid, "{byte:02x}");
    }
}
