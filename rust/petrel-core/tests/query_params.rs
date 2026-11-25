use petrel_core::xrpc::{
    pull_array_param, pull_default_param, pull_optional_array_param, pull_optional_param,
    pull_param,
};
use petrel_core::{DecodeError, FromQueryParams, ToQueryParams};

#[derive(Debug, PartialEq, Eq)]
struct SampleParams {
    req: String,
    opt: Option<i64>,
    flag: bool,
    tags: Vec<String>,
    opt_tags: Option<Vec<i64>>,
}

impl FromQueryParams for SampleParams {
    fn from_query_params(params: &[(&str, &str)]) -> Result<Self, DecodeError> {
        Ok(Self {
            req: pull_param(params, "req")?,
            opt: pull_optional_param(params, "opt")?,
            flag: pull_default_param(params, "flag", || false)?,
            tags: pull_array_param(params, "tags")?,
            opt_tags: pull_optional_array_param(params, "opt_tags")?,
        })
    }
}

#[test]
fn unit_params_roundtrip() {
    let parsed: Result<(), DecodeError> = <() as FromQueryParams>::from_query_params(&[]);
    assert!(parsed.is_ok());
    let mut roundtrip = Vec::new();
    <() as ToQueryParams>::to_query_params(&(), &mut roundtrip);
    assert_eq!(roundtrip, [] as [(&str, String); 0]);
}

#[test]
fn query_params_scalars_defaults_and_arrays() {
    let params = [
        ("req", "hello"),
        ("opt", "42"),
        ("tags", "a"),
        ("tags", "b"),
        ("opt_tags", "1"),
        ("opt_tags", "-2"),
    ];
    let decoded = SampleParams::from_query_params(&params).expect("valid query params");
    assert_eq!(
        decoded,
        SampleParams {
            req: "hello".to_owned(),
            opt: Some(42),
            flag: false,
            tags: vec!["a".to_owned(), "b".to_owned()],
            opt_tags: Some(vec![1, -2]),
        }
    );
}

#[test]
fn query_params_rejects_missing_required_duplicate_scalar_and_bad_int() {
    let missing = SampleParams::from_query_params(&[("opt", "1")]);
    assert!(missing.is_err());

    let dup_scalar = SampleParams::from_query_params(&[("req", "a"), ("req", "b")]);
    assert!(dup_scalar.is_err());

    let bad_bool = SampleParams::from_query_params(&[("req", "a"), ("flag", "maybe")]);
    assert!(bad_bool.is_err());

    let bad_int = SampleParams::from_query_params(&[("req", "a"), ("opt", "xyz")]);
    assert!(bad_int.is_err());
}
