#![cfg(all(feature = "app_bsky", feature = "com_atproto"))]
//! Wire compatibility with already-deployed peers: records written by the
//! official TypeScript SDK, and deep AppView responses.

use petrel_api::generated::app::bsky::feed::get_post_thread::{Output, OutputThread};
use petrel_api::generated::app::bsky::feed::post::Post;
use petrel_api::generated::app::bsky::richtext::facet::Facet;
use petrel_core::serde_bridge::cid_of;
use petrel_core::{Value, XrpcOutput, from_dag_cbor, from_json, to_dag_cbor, to_json};

const CID: &str = "bafyreie5737gdxlw5i64vzichcalba3z2v5n6icifvx5xytvske7mr3hpm";

/// A post as the TypeScript SDK writes it: `$type` on facets, on their
/// features and indexes, on reply refs, and on embed members.
fn ts_sdk_post() -> String {
    format!(
        r#"{{"$type":"app.bsky.feed.post","createdAt":"2026-11-24T12:00:00.000Z","embed":{{"$type":"app.bsky.embed.external","external":{{"$type":"app.bsky.embed.external#external","description":"d","title":"t","uri":"https://example.com"}}}},"facets":[{{"$type":"app.bsky.richtext.facet","features":[{{"$type":"app.bsky.richtext.facet#link","uri":"https://example.com"}}],"index":{{"$type":"app.bsky.richtext.facet#byteSlice","byteEnd":5,"byteStart":0}}}},{{"features":[{{"$type":"app.bsky.richtext.facet#tag","tag":"x"}}],"index":{{"byteEnd":8,"byteStart":6}}}}],"langs":["en"],"reply":{{"parent":{{"$type":"com.atproto.repo.strongRef","cid":"{CID}","uri":"at://did:plc:abc/app.bsky.feed.post/3k"}},"root":{{"cid":"{CID}","uri":"at://did:plc:abc/app.bsky.feed.post/3j"}}}},"text":"hello #x"}}"#
    )
}

#[test]
fn a_ts_sdk_post_with_tagged_nested_objects_keeps_its_cid() {
    let json = ts_sdk_post();
    let raw: Value = from_json(json.as_bytes()).unwrap();
    let post: Post = from_json(json.as_bytes()).unwrap();
    assert!(post.facets.as_ref().is_some_and(|facets| facets.len() == 2));

    // Every `$type` present on decode is written back, none is added.
    assert_eq!(to_json(&post).unwrap(), json.as_bytes());
    assert_eq!(to_dag_cbor(&post).unwrap(), to_dag_cbor(&raw).unwrap());
    assert_eq!(cid_of(&post).unwrap(), raw.cid());

    // Same through DAG-CBOR, the form a repository stores and signs.
    let block = to_dag_cbor(&raw).unwrap();
    let from_block: Post = from_dag_cbor(&block).unwrap();
    assert_eq!(to_dag_cbor(&from_block).unwrap(), block);
}

#[test]
fn an_untagged_nested_object_stays_untagged() {
    let json = br#"{"features":[],"index":{"byteEnd":1,"byteStart":0}}"#;
    let facet: Facet = from_json(json).unwrap();
    assert_eq!(to_json(&facet).unwrap(), json.to_vec());
}

#[test]
fn a_union_member_built_in_code_equals_one_decoded_from_the_wire() {
    // The union writes the member's tag itself, so the decoded member does
    // not also carry it in `extra_data`.
    let post: Post = from_json(ts_sdk_post().as_bytes()).unwrap();
    let decoded_feature = &post.facets.as_ref().unwrap()[0].features[0];
    let re_decoded = from_json(&to_json(decoded_feature).unwrap()).unwrap();
    assert_eq!(decoded_feature, &re_decoded);
    let rendered = format!("{decoded_feature:?}");
    assert!(!rendered.contains("$type"), "{rendered}");
}

fn post_view(depth: usize) -> String {
    format!(
        r#"{{"uri":"at://did:plc:abc/app.bsky.feed.post/{depth}","cid":"{CID}","author":{{"did":"did:plc:abc","handle":"a.example.com"}},"record":{{"$type":"app.bsky.feed.post","text":"{depth}","createdAt":"2026-11-24T12:00:00Z"}},"indexedAt":"2026-11-24T12:00:00Z"}}"#
    )
}

#[test]
fn a_post_thread_nested_past_the_json_cap_is_refused_cleanly() {
    // `getPostThread` with parentHeight=80 nests one object per ancestor.
    // Typed decoding costs ~26 KB of stack per level, so that depth would
    // overflow a 2 MiB worker stack; the JSON depth cap turns it into an
    // error. Decoding such threads needs boxed generated fields first.
    let body = deep_thread_body(80);
    assert!(<Output as XrpcOutput>::from_body(body.as_bytes()).is_err());
}

#[test]
fn a_post_thread_within_the_json_cap_decodes() {
    let parents = 20;
    let body = deep_thread_body(parents);
    let output = <Output as XrpcOutput>::from_body(body.as_bytes()).expect("thread");
    let OutputThread::ThreadViewPost(mut node) = output.thread else {
        panic!("expected a thread view post");
    };
    let mut seen = 0;
    while let Some(parent) = node.parent.take() {
        seen += 1;
        match parent {
            petrel_api::generated::app::bsky::feed::defs::ThreadViewPostParent::ThreadViewPost(
                next,
            ) => node = next,
            other => panic!("unexpected parent {other:?}"),
        }
    }
    assert_eq!(seen, parents);
}

fn deep_thread_body(parents: usize) -> String {
    let mut thread = format!(
        r#"{{"$type":"app.bsky.feed.defs#threadViewPost","post":{}}}"#,
        post_view(0)
    );
    for depth in 1..=parents {
        thread = format!(
            r#"{{"$type":"app.bsky.feed.defs#threadViewPost","post":{},"parent":{thread}}}"#,
            post_view(depth)
        );
    }
    format!(r#"{{"thread":{thread}}}"#)
}
