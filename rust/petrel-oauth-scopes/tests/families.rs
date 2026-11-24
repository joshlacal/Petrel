use petrel_oauth_scopes::{
    AccountPermission, AtProtoScope, BlobPermission, IdentityPermission, IncludeScope,
    RepoPermission, RpcPermission, ScopeSet,
};

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn builders_validate_the_same_values_as_parsers() {
    let repo = RepoPermission::new(&["com.example.foo", "com.example.foo"], &[]).unwrap();
    assert_eq!(
        repo.canonical_scope_string().unwrap(),
        "repo:com.example.foo"
    );
    assert!(!repo.parameters().was_stated("action"));
    assert!(repo.parameters().was_stated("collection"));
    assert_eq!(
        repo.parameters().multiple("collection"),
        ["com.example.foo", "com.example.foo"]
    );
    assert!(RepoPermission::new(&[], &["delete"]).is_err());
    assert!(RepoPermission::new(&["com.example.*"], &["create"]).is_err());
    assert!(RepoPermission::new(&["com.example.foo"], &["read"]).is_err());

    let account = AccountPermission::new("email", "manage").unwrap();
    assert!(account.matches("email", "read"));
    assert!(account.matches("email", "manage"));
    assert!(!account.matches("status", "manage"));
    assert!(AccountPermission::new("*", "read").is_err());

    let identity = IdentityPermission::new("*").unwrap();
    assert!(identity.matches("handle"));
    assert!(!identity.matches("profile"));
    assert!(IdentityPermission::new("email").is_err());

    let blob = BlobPermission::new(&["image/png", "image/svg+xml"]).unwrap();
    assert!(blob.matches("IMAGE/SVG+XML"));
    assert_eq!(
        blob.wire_scope_string().unwrap(),
        "blob?accept=image/png&accept=image/svg%2Bxml"
    );
    assert!(BlobPermission::new(&["*/png"]).is_err());
    assert!(BlobPermission::new(&[]).is_err());

    let rpc = RpcPermission::new(&["com.example.foo"], "did:web:example.com#special%41").unwrap();
    assert_eq!(
        rpc.wire_scope_string().unwrap(),
        "rpc:com.example.foo?aud=did:web:example.com%23special%2541"
    );
    assert!(RpcPermission::new(&["*"], "*").is_err());
    assert!(RpcPermission::new(&["com.example.foo"], "did:web:example.com").is_err());

    let include =
        IncludeScope::new("com.example.permissions", Some("did:web:example.com#svc")).unwrap();
    assert!(include.is_parent_authority_of("com.example.foo"));
    assert!(IncludeScope::new("com.example.permissions", Some("*")).is_err());
    assert!(IncludeScope::new("com.example.*", None).is_err());

    let set = ScopeSet::from_scopes([
        AtProtoScope::Atproto,
        AtProtoScope::Blob(blob),
        AtProtoScope::Repo(repo),
        AtProtoScope::Rpc(rpc),
        AtProtoScope::Include(include),
    ])
    .unwrap();
    assert_eq!(set, ScopeSet::parse_strict(&set.scope_string()).unwrap());
    assert!(set.allows_blob("image/svg+xml"));
    assert!(set.allows_rpc("com.example.foo", "did:web:example.com#special%41"));
    assert!(ScopeSet::parse_strict("atproto space:example").is_err());
    assert!(ScopeSet::parse_strict("atproto rpc:*?aud=*").is_err());
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn explicit_defaults_preserve_structural_provenance() {
    let basic = RepoPermission::parse("repo:com.example.foo").unwrap();
    let explicit =
        RepoPermission::parse("repo:com.example.foo?action=create&action=update&action=delete")
            .unwrap();
    assert_ne!(basic, explicit);
    assert_eq!(
        basic.canonical_scope_string(),
        explicit.canonical_scope_string()
    );
    assert_eq!(
        basic.parameters().multiple("action"),
        explicit.parameters().multiple("action")
    );
    assert!(!basic.parameters().was_stated("action"));
    assert!(explicit.parameters().was_stated("action"));
}
