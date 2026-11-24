use petrel_oauth_scopes::{
    AtProtoScope, IncludeScope, LexiconPermissionSet, ScopeDenied, ScopeParseError, ScopeSet,
    encode_form_component, encode_uri_component, is_accept, is_atproto_did_ref_absolute, is_mime,
    is_nsid, is_parent_authority_of,
};
use serde_json::Value;

const CORPUS: &str =
    include_str!("../../../Tests/PetrelOAuthScopesTests/Fixtures/upstream-oauth-scopes.json");

fn corpus() -> Value {
    let fixture: Value = serde_json::from_str(CORPUS).unwrap();
    assert_eq!(
        fixture["referenceCommit"],
        "0e1042e65d5df27030849167773728b84d469182"
    );
    assert_eq!(
        fixture["referenceRepository"],
        "https://github.com/bluesky-social/atproto"
    );
    assert_eq!(fixture["source"], "packages/oauth/oauth-scopes");
    assert!(
        fixture["$comment"]
            .as_str()
            .unwrap()
            .contains("regenerate.sh")
    );
    assert_eq!(fixture.as_object().unwrap().len(), 14);
    fixture
}

fn rows<'a>(fixture: &'a Value, key: &str, expected: usize) -> &'a [Value] {
    let entries = fixture[key].as_array().unwrap();
    assert_eq!(entries.len(), expected, "{key}");
    entries
}

fn string<'a>(value: &'a Value, key: &str) -> &'a str {
    value[key].as_str().unwrap()
}

fn canonical(input: &str) -> Option<String> {
    AtProtoScope::parse(input)
        .ok()?
        .canonical_scope_string()
        .ok()
}

#[test]
fn scope_values() {
    let fixture = corpus();
    for row in rows(&fixture, "values", 184) {
        let input = string(row, "input");
        let expected = row["canonical"].as_str();
        if matches!(input, "blob:im*ge/*" | "blob:*a/*") {
            assert!(expected.is_some());
            assert_eq!(canonical(input), None);
            continue;
        }
        if row["threw"].is_string() {
            assert!(
                matches!(
                    AtProtoScope::parse(input),
                    Err(ScopeParseError::MalformedPercentEncoding)
                ),
                "{input:?}"
            );
            assert!(row["isAtprotoOauthScope"].is_null(), "{input:?}");
        } else {
            assert_eq!(
                AtProtoScope::parse(input).is_ok(),
                row["isAtprotoOauthScope"].as_bool().unwrap(),
                "{input:?}"
            );
        }
        assert_eq!(canonical(input).as_deref(), expected, "{input:?}");
        if let Some(canonical_form) = expected {
            assert_eq!(
                canonical(canonical_form).as_deref() == Some(canonical_form),
                row["roundTripStable"].as_bool().unwrap(),
                "{input:?}"
            );
        } else {
            assert!(row["roundTripStable"].is_null(), "{input:?}");
        }
    }
}

#[test]
fn whole_scope_strings() {
    let fixture = corpus();
    for row in rows(&fixture, "strings", 8) {
        let input = string(row, "input");
        let mut scopes: Vec<_> = input.split(' ').filter_map(canonical).collect();
        scopes.sort();
        assert_eq!(scopes.join(" "), string(row, "normalized"), "{input:?}");
    }
}

#[test]
fn granular_and_transition_permissions() {
    let fixture = corpus();
    let grants = fixture["matches"].as_object().unwrap();
    assert_eq!(grants.len(), 22);
    for (name, grant) in grants {
        let wire = string(grant, "scope");
        let granular = wire
            .split(' ')
            .filter(|scope| !scope.starts_with("transition:"))
            .collect::<Vec<_>>()
            .join(" ");
        for (kind, scope) in [("granular", granular.as_str()), ("transition", wire)] {
            let set = ScopeSet::from_scope_string(scope);
            let mut count = 0;
            for (resource, results) in grant[kind].as_object().unwrap() {
                for row in results.as_array().unwrap() {
                    count += 1;
                    let arg = &row["arg"];
                    let allowed = match resource.as_str() {
                        "repo" => set.allows_repo(string(arg, "collection"), string(arg, "action")),
                        "rpc" => set.allows_rpc(string(arg, "lxm"), string(arg, "aud")),
                        "blob" => set.allows_blob(string(arg, "mime")),
                        "account" => set.allows_account(string(arg, "attr"), string(arg, "action")),
                        "identity" => set.allows_identity(string(arg, "attr")),
                        _ => panic!("unexpected resource {resource:?}"),
                    };
                    assert!(row["threw"].is_null(), "{name}/{kind}/{resource}");
                    assert_eq!(
                        Some(allowed),
                        row["allowed"].as_bool(),
                        "{name}/{kind}/{resource} {arg}"
                    );
                }
            }
            assert_eq!(count, 27, "{name}/{kind}");
        }
    }
}

#[test]
fn missing_scope_diagnostics() {
    let fixture = corpus();
    let none = ScopeSet::parse("atproto").unwrap();
    for row in rows(&fixture, "missing", 9) {
        let arg = &row["arg"];
        let resource = string(row, "resource");
        let denial = match resource {
            "repo" => none.require_repo(string(arg, "collection"), string(arg, "action")),
            "rpc" => none.require_rpc(string(arg, "lxm"), string(arg, "aud")),
            "blob" => none.require_blob(string(arg, "mime")),
            "account" => none.require_account(string(arg, "attr"), string(arg, "action")),
            "identity" => none.require_identity(string(arg, "attr")),
            _ => panic!("unexpected resource {resource:?}"),
        };
        assert_eq!(
            denial,
            Err(ScopeDenied {
                needed: string(row, "scope").to_owned()
            })
        );
    }
}

#[test]
fn permission_set_expansion_and_authority() {
    let fixture = corpus();
    for row in rows(&fixture, "includes", 9) {
        let include = IncludeScope::parse(string(row, "scope")).unwrap();
        let set: LexiconPermissionSet =
            serde_json::from_value(row["permissionSet"].clone()).unwrap();
        let expected: Vec<String> = serde_json::from_value(row["scopes"].clone()).unwrap();
        assert!(row["threw"].is_null());
        assert_eq!(
            include.expand_to_scope_strings(&set).unwrap(),
            expected,
            "{}",
            row["name"]
        );
    }
    for row in rows(&fixture, "authority", 21) {
        assert_eq!(
            is_parent_authority_of(string(row, "nsid"), string(row, "other")),
            row["isParentAuthority"].as_bool().unwrap(),
            "{row}"
        );
    }
}

#[test]
fn atom_syntax() {
    let fixture = corpus();
    for row in rows(&fixture, "didRefs", 66) {
        let input = string(row, "input");
        let swift_rejects = input == "did:web:%C3%A9xample.com#svc";
        let upstream = row["isAtprotoDidRefAbsolute"].as_bool().unwrap();
        assert!(!swift_rejects || upstream);
        assert_eq!(
            is_atproto_did_ref_absolute(input),
            upstream && !swift_rejects,
            "{input:?}"
        );
    }
    for row in rows(&fixture, "nsids", 35) {
        let input = string(row, "input");
        assert_eq!(
            is_nsid(input),
            row["isNsid"].as_bool().unwrap(),
            "{input:?}"
        );
    }
    for row in rows(&fixture, "accepts", 20) {
        let input = string(row, "input");
        let swift_rejects = matches!(input, "im*ge/*" | "*a/*");
        let upstream = row["isAccept"].as_bool().unwrap();
        assert!(!swift_rejects || upstream);
        assert_eq!(is_accept(input), upstream && !swift_rejects, "{input:?}");
        assert_eq!(
            is_mime(input),
            row["isMime"].as_bool().unwrap(),
            "{input:?}"
        );
    }
}

#[test]
fn percent_encoders() {
    let fixture = corpus();
    for row in rows(&fixture, "encoders", 19) {
        let input = string(row, "raw");
        assert_eq!(
            encode_uri_component(input),
            string(row, "encodeURIComponent"),
            "{input:?}"
        );
        assert_eq!(
            encode_form_component(input),
            string(row, "urlSearchParams"),
            "{input:?}"
        );
    }
}
