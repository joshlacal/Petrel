#![cfg(feature = "app_bsky")]

use petrel_api::generated::app::bsky::feed::get_timeline;
use petrel_core::{FromQueryParams, ToQueryParams};

#[test]
fn generated_parameters_roundtrip_to_and_from_query_params() {
    let params = get_timeline::Parameters {
        algorithm: Some("reverse-chronological".to_owned()),
        cursor: Some("cursor-123".to_owned()),
        limit: 25,
        since: None,
    };
    let mut encoded = Vec::new();
    params.to_query_params(&mut encoded);
    let borrowed: Vec<(&str, &str)> = encoded.iter().map(|(k, v)| (*k, v.as_str())).collect();
    let decoded = get_timeline::Parameters::from_query_params(&borrowed)
        .expect("decode generated query params");
    assert_eq!(decoded.algorithm.as_deref(), Some("reverse-chronological"));
    assert_eq!(decoded.cursor.as_deref(), Some("cursor-123"));
    assert_eq!(decoded.limit, 25);
    assert_eq!(decoded.since, None);
}
