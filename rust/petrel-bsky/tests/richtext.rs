//! Ported RichText & RichTextDetection tests including the reference detection vectors.

use petrel_api::generated::app::bsky::feed::post::{Entity, TextSlice};
use petrel_api::generated::app::bsky::richtext::facet::{ByteSlice, Facet};
use petrel_bsky::{RichText, RichTextDetectionKind, all_tlds, is_valid_domain};
use petrel_core::{Did, Uri};
use serde::Deserialize;

#[derive(Deserialize)]
struct DetectionVectors {
    segments: Vec<SegmentCase>,
    tags: Vec<TagCase>,
    cashtags: Vec<TagCase>,
}

#[derive(Deserialize)]
struct SegmentCase {
    text: String,
    segments: Vec<Vec<String>>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TagCase {
    text: String,
    tags: Vec<String>,
    indices: Vec<TagIndex>,
}

#[derive(Debug, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "camelCase")]
struct TagIndex {
    byte_start: i64,
    byte_end: i64,
}

fn load_vectors() -> DetectionVectors {
    serde_json::from_str(include_str!(
        "../../../Tests/PetrelTests/Vectors/richtext/detection.json"
    ))
    .expect("valid detection vectors json")
}

fn facet_empty(start: i64, end: i64) -> Facet {
    Facet::new(ByteSlice::new(start, end), Vec::new())
}

const FAMILY: &str = "👨‍👩‍👧‍👧";

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn rich_text_lengths_limits_and_entities() {
    // Entities to facets
    let rt = RichText::new(
        "test",
        None,
        Some(&[
            Entity::new(
                TextSlice::new(0, 1),
                "link".to_owned(),
                "https://example.com".to_owned(),
            ),
            Entity::new(
                TextSlice::new(1, 2),
                "mention".to_owned(),
                "did:plc:1234".to_owned(),
            ),
            Entity::new(
                TextSlice::new(2, 3),
                "other".to_owned(),
                "willbedropped".to_owned(),
            ),
        ]),
        false,
    );
    assert_eq!(rt.facets.len(), 2);
    assert_eq!(
        (rt.facets[0].index.byte_start, rt.facets[0].index.byte_end),
        (0, 1)
    );
    assert_eq!(
        (rt.facets[1].index.byte_start, rt.facets[1].index.byte_end),
        (1, 2)
    );

    // UTF-16 entity offsets converted to UTF-8
    let fam3 = format!("{FAMILY}{FAMILY}{FAMILY}");
    let rt_utf16 = RichText::new(
        fam3,
        None,
        Some(&[
            Entity::new(
                TextSlice::new(0, 11),
                "link".to_owned(),
                "https://example.com".to_owned(),
            ),
            Entity::new(
                TextSlice::new(11, 22),
                "mention".to_owned(),
                "did:plc:1234".to_owned(),
            ),
            Entity::new(
                TextSlice::new(22, 33),
                "other".to_owned(),
                "willbedropped".to_owned(),
            ),
        ]),
        false,
    );
    let ranges: Vec<(i64, i64)> = rt_utf16
        .facets
        .iter()
        .map(|f| (f.index.byte_start, f.index.byte_end))
        .collect();
    assert_eq!(ranges, vec![(0, 25), (25, 50)]);

    // Facets win over entities
    let explicit = RichText::new(
        "test",
        Some(vec![facet_empty(0, 4)]),
        Some(&[Entity::new(
            TextSlice::new(0, 1),
            "link".to_owned(),
            "https://example.com".to_owned(),
        )]),
        false,
    );
    assert_eq!(explicit.facets.len(), 1);
    assert_eq!(explicit.facets[0].index.byte_end, 4);

    // Byte and grapheme lengths
    assert_eq!(RichText::from_text("Hello!").utf8_length(), 6);
    assert_eq!(RichText::from_text("Hello!").grapheme_length(), 6);
    assert_eq!(RichText::from_text(FAMILY).utf8_length(), 25);
    assert_eq!(RichText::from_text(FAMILY).grapheme_length(), 1);
    let mixed = format!("{FAMILY}🔥 good!✅");
    assert_eq!(RichText::from_text(&mixed).utf8_length(), 38);
    assert_eq!(RichText::from_text(&mixed).grapheme_length(), 9);

    // Limits
    assert!(!RichText::from_text("a".repeat(300)).exceeds_post_limits());
    assert!(RichText::from_text("a".repeat(301)).exceeds_post_limits());
    assert!(RichText::from_text(FAMILY.repeat(300)).exceeds_post_limits());
    assert!(!RichText::from_text(FAMILY.repeat(120)).exceeds_post_limits());

    // recordFacets
    assert!(RichText::from_text("plain").record_facets().is_none());
    assert!(
        RichText::new("plain", Some(vec![facet_empty(0, 5)]), None, false)
            .record_facets()
            .is_some()
    );
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn rich_text_insert_delete_sanitize_and_shorten() {
    let base = RichText::new("hello world", Some(vec![facet_empty(2, 7)]), None, false);

    let mut before = base.clone();
    before.insert("test", 0);
    assert_eq!(before.text, "testhello world");
    assert_eq!(
        (
            before.facets[0].index.byte_start,
            before.facets[0].index.byte_end
        ),
        (6, 11)
    );
    assert_eq!(before.slice(6, 11), "llo w");

    let mut inner = base.clone();
    inner.insert("test", 4);
    assert_eq!(inner.text, "helltesto world");
    assert_eq!(
        (
            inner.facets[0].index.byte_start,
            inner.facets[0].index.byte_end
        ),
        (2, 11)
    );
    assert_eq!(inner.slice(2, 11), "lltesto w");

    let mut after = base.clone();
    after.insert("test", 8);
    assert_eq!(after.text, "hello wotestrld");
    assert_eq!(
        (
            after.facets[0].index.byte_start,
            after.facets[0].index.byte_end
        ),
        (2, 7)
    );

    let mut fat = base.clone();
    fat.insert(FAMILY, 0);
    assert_eq!(
        (fat.facets[0].index.byte_start, fat.facets[0].index.byte_end),
        (27, 32)
    );
    assert_eq!(fat.slice(27, 32), "llo w");

    // Delete outer -> dropped
    let mut del = base;
    del.delete(0, 9);
    assert_eq!(del.text, "ld");
    assert_eq!(
        del.facets,
        [] as [petrel_api::generated::app::bsky::richtext::facet::Facet; 0]
    );

    // Sanitize newlines preserving facets
    let mut rt = RichText::from_text("");
    rt.append("hello\n\n\n\n");
    rt.append_link("example.com", "https://example.com".parse::<Uri>().unwrap());
    let cleaned = rt.sanitized(true);
    assert_eq!(cleaned.text, "hello\n\nexample.com");
    assert_eq!(
        cleaned.slice(
            cleaned.facets[0].index.byte_start,
            cleaned.facets[0].index.byte_end
        ),
        "example.com"
    );

    // Shortening URLs
    assert_eq!(
        RichText::shortened_url("https://example.com/a/very/long/path?query=1#frag"),
        "example.com/a/very/long/..."
    );
    assert_eq!(
        RichText::shortened_url("https://example.com/short"),
        "example.com/short"
    );

    let mut with_link = RichText::from_text("");
    with_link.append("See ");
    with_link.append_link(
        "https://example.com/a/very/long/path/here",
        "https://example.com/a/very/long/path/here"
            .parse::<Uri>()
            .unwrap(),
    );
    with_link.append("!");
    let shortened = with_link.shortening_links();
    assert_eq!(shortened.text, "See example.com/a/very/long/...!");
    assert_eq!(
        shortened.segments()[1].link().unwrap().uri.as_str(),
        "https://example.com/a/very/long/path/here"
    );
}

#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
async fn rich_text_detection_vectors_segments_tags_cashtags() {
    let vectors = load_vectors();
    assert_eq!(vectors.segments.len(), 40);
    assert_eq!(vectors.tags.len(), 39);
    assert_eq!(vectors.cashtags.len(), 18);

    let fake_resolver =
        |handle: String| async move { format!("did:fake:{handle}").parse::<Did>().ok() };

    for case in &vectors.segments {
        let mut rt = RichText::from_text(&case.text);
        rt.detect_facets(fake_resolver).await;
        let actual: Vec<Vec<String>> = rt
            .segments()
            .into_iter()
            .map(|seg| {
                if seg.facet.is_none() {
                    return vec![seg.text];
                }
                if let Some(m) = seg.mention() {
                    return vec![seg.text.clone(), m.did.as_str().to_owned()];
                }
                if let Some(l) = seg.link() {
                    return vec![seg.text.clone(), l.uri.as_str().to_owned()];
                }
                vec![seg.text, String::new()]
            })
            .collect();
        assert_eq!(actual, case.segments, "input: {:?}", case.text);
    }

    for case in &vectors.tags {
        let mut rt = RichText::from_text(&case.text);
        rt.detect_facets(fake_resolver).await;
        let mut tags = Vec::new();
        let mut indices = Vec::new();
        for seg in rt.segments() {
            if let Some(facet) = &seg.facet {
                if let Some(tag) = seg.tag() {
                    tags.push(tag.tag.clone());
                }
                indices.push(TagIndex {
                    byte_start: facet.index.byte_start,
                    byte_end: facet.index.byte_end,
                });
            }
        }
        assert_eq!(tags, case.tags, "input: {:?}", case.text);
        assert_eq!(indices, case.indices, "input: {:?}", case.text);
    }

    for case in &vectors.cashtags {
        let mut rt = RichText::from_text(&case.text);
        rt.detect_facets_without_resolution();
        let mut tags = Vec::new();
        let mut indices = Vec::new();
        for seg in rt.segments() {
            if let Some(facet) = &seg.facet
                && let Some(tag) = seg.tag()
                && tag.tag.starts_with('$')
            {
                tags.push(tag.tag.clone());
                indices.push(TagIndex {
                    byte_start: facet.index.byte_start,
                    byte_end: facet.index.byte_end,
                });
            }
        }
        assert_eq!(tags, case.tags, "input: {:?}", case.text);
        assert_eq!(indices, case.indices, "input: {:?}", case.text);
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn rich_text_domain_rules_and_tld_table() {
    let links = |text: &str| -> Vec<String> {
        RichText::detect(text)
            .into_iter()
            .filter_map(|d| match d.kind {
                RichTextDetectionKind::Link { uri } => Some(uri),
                _ => None,
            })
            .collect()
    };
    assert_eq!(
        links("see example.museum now"),
        vec!["https://example.museum"]
    );
    assert_eq!(links("see example.notatld now"), [] as [String; 0]);
    assert_eq!(links("photo.jpg and archive.tar.gz"), [] as [String; 0]);
    assert_eq!(
        links("try httpbin.org/get"),
        vec!["https://httpbin.org/get"]
    );
    assert_eq!(
        links("https.example.com"),
        vec!["https://https.example.com"]
    );
    assert_eq!(links("httpfoo.notatld"), [] as [String; 0]);
    assert_eq!(
        links("http://example.com and https://httpbin.org"),
        vec!["http://example.com", "https://httpbin.org"]
    );
    assert_eq!(links("HTTPS://EXAMPLE.COM"), [] as [String; 0]);
    assert_eq!(links("EXAMPLE.COM"), [] as [String; 0]);
    assert_eq!(
        RichText::detect("@name.xn--p1ai")
            .into_iter()
            .map(|d| d.kind)
            .collect::<Vec<_>>(),
        vec![RichTextDetectionKind::Mention {
            handle: "name.xn--p1ai".to_owned(),
        }]
    );

    let tlds = all_tlds();
    assert_eq!(tlds.len(), 1436);
    for expected in ["com", "org", "net", "social", "app", "blue", "xn--p1ai"] {
        assert!(tlds.contains(expected));
    }
    assert!(!tlds.contains("jpg"));
    assert!(!tlds.contains("test"));

    // Check UTF-8 slice boundaries on multi-byte text
    let rt =
        RichText::from_text("こんにちは @alice.test を見て https://例.example.com/パス #東京 $btc");
    let detections = RichText::detect(&rt.text);
    let slices: Vec<String> = detections
        .iter()
        .map(|d| {
            rt.slice(
                i64::try_from(d.byte_start).unwrap(),
                i64::try_from(d.byte_end).unwrap(),
            )
        })
        .collect();
    assert_eq!(
        slices,
        vec![
            "@alice.test",
            "https://例.example.com/パス",
            "#東京",
            "$btc"
        ]
    );
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn punycode_tlds_have_no_embedded_spaces_and_detect_in_rich_text() {
    let tlds = all_tlds();
    for expected in [
        "xn--3ds443g",
        "xn--4gbrim",
        "xn--80adxhks",
        "xn--9dbq2a",
        "xn--eckvdtc9d",
        "xn--flw351e",
        "xn--h2breg3eve",
        "xn--j6w193g",
        "xn--lgbbat1ad8j",
        "xn--mgbah1a3hjkrd",
        "xn--mgbcpq6gpa1a",
        "xn--mgbx4cd0ab",
        "xn--nqv7fs00ema",
        "xn--q7ce6a",
        "xn--ses554g",
        "xn--vhquv",
        "xn--xkc2dl3a5ee0h",
    ] {
        assert!(tlds.contains(expected), "missing expected TLD: {expected}");
        assert!(is_valid_domain(&format!("example.{expected}")));
    }
    assert!(!tlds.contains("xn"));
    assert!(!tlds.contains("xn--"));
    assert!(tlds.iter().all(|t| {
        t.len() >= 2
            && !t.starts_with('-')
            && !t.ends_with('-')
            && t.bytes()
                .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
            && (!t.starts_with("xn--") || t.len() > 4)
    }));
    assert_eq!(
        RichText::detect("@alice.xn--80adxhks @bob.xn--3ds443g https://example.xn--3ds443g")
            .into_iter()
            .map(|d| d.kind)
            .collect::<Vec<_>>(),
        vec![
            RichTextDetectionKind::Mention {
                handle: "alice.xn--80adxhks".to_owned(),
            },
            RichTextDetectionKind::Mention {
                handle: "bob.xn--3ds443g".to_owned(),
            },
            RichTextDetectionKind::Link {
                uri: "https://example.xn--3ds443g".to_owned(),
            },
        ]
    );
}
