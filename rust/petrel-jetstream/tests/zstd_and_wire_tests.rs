use base64::Engine as _;
use petrel_firehose::RelayRepoAction;
use petrel_jetstream::{
    DEFAULT_MAX_DICT_FRAME_BYTES, DEFAULT_MAX_DICTIONARY_BYTES, DEFAULT_MAX_STANDALONE_BYTES,
    JetstreamEvent, JetstreamFilter, JetstreamKind, JetstreamWire, JetstreamWireError,
    JetstreamWireFrame, JetstreamZstd, JetstreamZstdDictionaryDecoder, JetstreamZstdError,
};
use serde_json::json;

const RAW_DICT_B64: &str = "YXBwLmJza3kuZmVlZC5wb3N0YXBwLmJza3kuZ3JhcGguZm9sbG93ZGlkOnBsYzp7IiR0eXBlIjoibWVzc2FnZSIsInBheWxvYWQiOnsiY29sbGVjdGlvbiI6ImFwcC5ic2t5LmZlZWQucG9zdCJ9fQ==";
const RAW_FRAME_B64: &str = "KLUv/ST8XQQAkggcHGCJdRCdDUmJwQpiEePiKNHoNlb8svc1gQIAOC7Pk9iFr/pttwwdb6G5niHHUvA55STLeruzfP2AIcdSyWgICRIqEiqYQurtK2NfD597uxKVa9Ju2Hl9RykbCJjNrBPYFxnOd5iGdMs9ewkLN4heJggAUcwFbYNbatxbFyNiRjbDjAVKBNEEILneKeg=";
const STRUCT_DICT_B64: &str = "N6Qw7IHCfhEWEBjdAQAAAAAAAPD8////qJJCSrgdCgMxGAwGg5ra06WZbRtEgAABggsJDlAMCAgICAgICDgoCAgICAgICAwICAgICAgIWgiEZ0IIIYQQIiIiDwQ4cxAEQRAEQRAEQRAEIYQQQgghhIiIyAMBAAAABAAAAAgAAABudHMjY29tbWl0Iiwic2VxIjo3LCJkaWQiOiJkaWQ6cGxjOnVzZXIwMDA3IiwidGltZWVudHMjY29tbWl0Iiwic2VxIjo3LCJkaWQiOiJkaWQ6cGxjOnVzZXIwMDAyIiwidGltZW50cyNjb21taXQiLCJzZXEiOjcsImRpZCI6ImRpZDpwbGM6dXNlcjAwMDYiLCJ0aW1lbnRzI2NvbW1pdCIsInNlcSI6NywiZGlkIjoiZGlkOnBsYzp1c2VyMDAxMSIsInRpbWVudHMjY29tbWl0Iiwic2VxIjo3LCJkaWQiOiJkaWQ6cGxjOnVzZXIwMDEzIiwidGltZW50cyNjb21taXQiLCJzZXEiOjcsImRpZCI6ImRpZDpwbGM6dXNlcjAwMDgiLCJ0aW1udHMjY29tbWl0Iiwic2VxIjo3LCJkaWQiOiJkaWQ6cGxjOnVzZXIwMDAzIiwidGltZW50cyNjb21taXQiLCJzZXEiOjcsImRpZCI6ImRpZDpwbGM6dXNlcjAwMDQiLCJ0aW1lbnRzI2NvbW1pdCIsInNlcSI6NywiZGlkIjoiZGlkOnBsYzp1c2VyMDAxNSIsInRpbWVudHMjY29tbWl0Iiwic2VxIjo3LCJkaWQiOiJkaWQ6cGxjOnVzZXIwMDEyIiwidGltZW50cyNjb21taXQiLCJzZXEiOjcsImRpZCI6ImRpZDpwbGM6dXNlcjAwMTYiLCJ0aW1lbnRzI2NvbW1pdCIsInNlcSI6NywiZGlkIjoiZGlkOnBsYzp1c2VyMDAwMCIsInRpbWVudHMjY29tbWl0Iiwic2VxIjo3LCJkaWQiOiJkaWQ6cGxjOnVzZXIwMDE4IiwidGltZWlvbiI6ImFwcC5ic2t5LmZlZWQucG9zdCIsInJrZXkiOiIzazd2MmFiYzIzNDU2In19Iiwic2VxIjo3LCJkaWQiOiJkaWQ6cGxjOnVzZXIwMDAxIiwidGltZSI6IjIwMjYtMDFjMjM0NTYiLCJvcGVyYXRpb24iOiJjcmVhdGUiLCJjb2xsZWN0aW9uIjoiYXBwLmJzay5ic2t5LmpldHN0cmVhbS5zdWJzY3JpYmVFdmVudHMjY29tbWl0Iiwic2VxIjo3LCJkdHlwZSI6Im1lc3NhZ2UiLCJwYXlsb2FkIjp7IiR0eXBlIjoibmV0d29yay5ic2t5LmoyMDI2LTAxLTAxVDAwOjAwOjAwLjEyMzQ1NloiLCJyZXYiOiIzazd2MmFiYzIzNDU2Ig==";
const STRUCT_FRAME_B64: &str = "KLUv/SeBwn4R/MUAABhhYmMI/PIFrvN6oGRa5APM0VFrswcyeLneKeg=";

#[cfg(target_arch = "wasm32")]
use wasm_bindgen_test::wasm_bindgen_test as wasm_compat_test;

#[cfg_attr(target_arch = "wasm32", wasm_compat_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn zstd_standalone_roundtrip_and_limits() {
    let payload: Vec<u8> = (0..10_000_u32)
        .map(|i| u8::try_from((i.wrapping_mul(31)) & 0xff).unwrap_or(0))
        .collect();
    let compressed = JetstreamZstd::compress(&payload).unwrap();
    assert!(compressed.len() < payload.len());
    let decompressed = JetstreamZstd::decompress(&compressed).unwrap();
    assert_eq!(decompressed, payload);

    assert_eq!(
        JetstreamZstd::decompress(&[]),
        Err(JetstreamZstdError::InvalidFrame)
    );
    assert!(JetstreamZstd::decompress(&[0xde, 0xad, 0xbe, 0xef, 0x00]).is_err());

    let repetitive = vec![0x41_u8; 4096];
    let comp_rep = JetstreamZstd::compress(&repetitive).unwrap();
    assert!(matches!(
        JetstreamZstd::decompress_with_limit(&comp_rep, 16),
        Err(JetstreamZstdError::FrameTooLarge { limit: 16, .. })
    ));
}

#[cfg_attr(target_arch = "wasm32", wasm_compat_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn zstd_dictionary_id_and_raw_and_structured_dictionaries() {
    let header_only = [0x37, 0xa4, 0x30, 0xec, 42, 0, 0, 0];
    assert_eq!(JetstreamZstd::dictionary_id(&header_only), Some(42));
    assert_eq!(JetstreamZstd::dictionary_id(b"rawdict"), None);

    let b64 = base64::engine::general_purpose::STANDARD;
    let raw_dict = b64.decode(RAW_DICT_B64).unwrap();
    let raw_frame = b64.decode(RAW_FRAME_B64).unwrap();
    let struct_dict = b64.decode(STRUCT_DICT_B64).unwrap();
    let struct_frame = b64.decode(STRUCT_FRAME_B64).unwrap();

    let expected = br#"{"$type":"message","payload":{"$type":"network.bsky.jetstream.subscribeEvents#commit","seq":7,"did":"did:plc:abc","time":"2026-01-01T00:00:00.123456Z","rev":"3k7v2abc23456","operation":"create","collection":"app.bsky.feed.post","rkey":"3k7v2abc23456"}}"#;

    let raw_dec = JetstreamZstdDictionaryDecoder::new(&raw_dict).unwrap();
    assert_eq!(raw_dec.decompress(&raw_frame).unwrap(), expected);

    let struct_dec = JetstreamZstdDictionaryDecoder::new(&struct_dict).unwrap();
    assert!(JetstreamZstd::dictionary_id(&struct_dict).is_some());
    assert_eq!(struct_dec.decompress(&struct_frame).unwrap(), expected);

    // Wrong dictionary must fail!
    let wrong_dec = JetstreamZstdDictionaryDecoder::new(b"unrelated").unwrap();
    assert!(wrong_dec.decompress(&raw_frame).is_err());
    assert!(wrong_dec.decompress(&struct_frame).is_err());
}

#[allow(clippy::too_many_lines)]
#[cfg_attr(target_arch = "wasm32", wasm_compat_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn wire_decoder_decodes_v2_and_legacy_v1_and_handles_edge_cases() {
    let commit_json = serde_json::to_vec(&json!({
        "$type": "message",
        "payload": {
            "$type": "network.bsky.jetstream.subscribeEvents#commit",
            "seq": 42,
            "did": "did:plc:abc",
            "time": "2026-01-01T00:00:00.123456Z",
            "rev": "3k7v2abc23456",
            "operation": "create",
            "collection": "app.bsky.feed.post",
            "rkey": "3k7v2abc23456",
            "cid": "bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454",
            "record": { "$type": "app.bsky.feed.post", "text": "hello" }
        }
    }))
    .unwrap();

    let decoded = JetstreamWire::decode_frame(&commit_json).unwrap();
    let JetstreamWireFrame::Message(JetstreamEvent::Commit(c)) = decoded else {
        panic!("expected commit");
    };
    assert_eq!(c.seq, 42);
    assert_eq!(c.operation, RelayRepoAction::Create);
    assert_eq!(c.collection, "app.bsky.feed.post");
    assert!(c.decoded_record().is_some());
    assert_eq!(
        c.time_us,
        JetstreamWire::microseconds_from_rfc3339("2026-01-01T00:00:00.123456Z").unwrap()
    );

    let err_json = serde_json::to_vec(&json!({
        "$type": "error",
        "error": "CursorTooOld",
        "message": "behind"
    }))
    .unwrap();
    assert_eq!(
        JetstreamWire::decode_frame(&err_json).unwrap(),
        JetstreamWireFrame::Error {
            name: "CursorTooOld".to_owned(),
            message: Some("behind".to_owned())
        }
    );

    let unknown_type = serde_json::to_vec(&json!({
        "$type": "message",
        "payload": { "$type": "network.bsky.jetstream.subscribeEvents#future", "seq": 50 }
    }))
    .unwrap();
    assert_eq!(
        JetstreamWire::decode_frame(&unknown_type).unwrap(),
        JetstreamWireFrame::Skipped {
            r#type: Some("future".to_owned()),
            seq: Some(50)
        }
    );

    let bad_commit = serde_json::to_vec(&json!({
        "$type": "message",
        "payload": {
            "$type": "network.bsky.jetstream.subscribeEvents#commit",
            "seq": 51,
            "did": "did:plc:abc",
            "time": "2026-01-01T00:00:00Z"
        }
    }))
    .unwrap();
    assert!(matches!(
        JetstreamWire::decode_frame(&bad_commit).unwrap(),
        JetstreamWireFrame::Undecodable { seq: Some(51), .. }
    ));

    assert!(matches!(
        JetstreamWire::decode_frame(b"[]"),
        Err(JetstreamWireError::MalformedFrame(_))
    ));

    // Legacy v1 frame: time_us becomes seq
    let legacy = serde_json::to_vec(&json!({
        "did": "did:plc:legacy",
        "time_us": 1_700_000_000_123_456_i64,
        "kind": "commit",
        "commit": {
            "rev": "3k7v2abc23456",
            "operation": "delete",
            "collection": "app.bsky.feed.post",
            "rkey": "3k7v2abc23456"
        }
    }))
    .unwrap();
    let leg_dec = JetstreamWire::decode_legacy_frame(&legacy).unwrap();
    assert!(matches!(
        leg_dec,
        JetstreamWireFrame::Message(JetstreamEvent::Commit(ref ev))
            if ev.seq == 1_700_000_000_123_456 && ev.operation == RelayRepoAction::Delete
    ));

    // positive_integer rejects floats, bools, 0, and > 2^53 - 1
    assert_eq!(
        JetstreamWire::positive_integer(Some(&json!(1_000_000.5))),
        None
    );
    assert_eq!(JetstreamWire::positive_integer(Some(&json!(true))), None);
    assert_eq!(JetstreamWire::positive_integer(Some(&json!(0))), None);
    assert_eq!(
        JetstreamWire::positive_integer(Some(&json!(9_007_199_254_740_992_i64))),
        None
    );
    assert_eq!(
        JetstreamWire::positive_integer(Some(&json!(123))),
        Some(123)
    );

    // Filter wildcard + non-commit interaction
    let filter = JetstreamFilter {
        kinds: vec![JetstreamKind::Commit, JetstreamKind::Identity],
        dids: vec!["did:plc:abc".to_owned()],
        collections: vec!["app.bsky.feed.*".to_owned()],
    };
    assert!(filter.matches(&JetstreamEvent::Commit(c)));
    assert!(filter.matches(&JetstreamEvent::Info(
        petrel_jetstream::JetstreamInfoEvent {
            name: "notice".to_owned(),
            message: None,
        }
    )));
}

#[cfg_attr(target_arch = "wasm32", wasm_compat_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn zstd_rejects_oversized_dictionary_and_default_bomb_caps() {
    // Oversized dictionary (> DEFAULT_MAX_DICTIONARY_BYTES) must fail before decoding.
    let huge_dict = vec![0x61_u8; DEFAULT_MAX_DICTIONARY_BYTES + 1];
    assert_eq!(
        JetstreamZstdDictionaryDecoder::new(&huge_dict).unwrap_err(),
        JetstreamZstdError::DictionaryLoadFailed
    );

    // Crafted zstd header declaring > DEFAULT_MAX_STANDALONE_BYTES must reject immediately.
    // Descriptor byte 0xE0: FCS_Field_Size = 8 bytes (bits 6..7 == 3), Single_Segment = 1 (bit 5 == 1).
    let mut standalone_bomb = vec![0x28, 0xB5, 0x2F, 0xFD, 0xE0];
    standalone_bomb.extend_from_slice(&((DEFAULT_MAX_STANDALONE_BYTES as u64) + 1).to_le_bytes());
    assert_eq!(
        JetstreamZstd::decompress(&standalone_bomb).unwrap_err(),
        JetstreamZstdError::FrameTooLarge {
            declared: (DEFAULT_MAX_STANDALONE_BYTES as u64) + 1,
            limit: DEFAULT_MAX_STANDALONE_BYTES,
        }
    );

    // Dictionary decoder default cap is DEFAULT_MAX_DICT_FRAME_BYTES (8 MiB), not 128 MiB.
    let b64 = base64::engine::general_purpose::STANDARD;
    let raw_dict = b64.decode(RAW_DICT_B64).unwrap();
    let dec = JetstreamZstdDictionaryDecoder::new(&raw_dict).unwrap();
    let mut dict_bomb = vec![0x28, 0xB5, 0x2F, 0xFD, 0xE0];
    dict_bomb.extend_from_slice(&((DEFAULT_MAX_DICT_FRAME_BYTES as u64) + 1).to_le_bytes());
    assert_eq!(
        dec.decompress(&dict_bomb).unwrap_err(),
        JetstreamZstdError::FrameTooLarge {
            declared: (DEFAULT_MAX_DICT_FRAME_BYTES as u64) + 1,
            limit: DEFAULT_MAX_DICT_FRAME_BYTES,
        }
    );
}

/// zstd frame (no checksum, not single-segment) declaring a 64 MiB window, followed by one raw
/// last block of `content`.
fn frame_with_huge_window(fhd: u8, fcs: &[u8], content: &[u8]) -> Vec<u8> {
    let mut frame = vec![0x28, 0xB5, 0x2F, 0xFD, fhd];
    // Window_Descriptor: exponent 16, mantissa 0 -> 1 << (10 + 16) = 64 MiB.
    frame.push(16 << 3);
    frame.extend_from_slice(fcs);
    let header = (u32::try_from(content.len()).unwrap() << 3) | 1;
    frame.extend_from_slice(&header.to_le_bytes()[..3]);
    frame.extend_from_slice(content);
    frame
}

#[cfg_attr(target_arch = "wasm32", wasm_compat_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn zstd_rejects_declared_window_larger_than_output_limit() {
    const WINDOW: u64 = 64 * 1024 * 1024;

    // Standalone path: no Frame_Content_Size, so only the window bounds buffering.
    let standalone = frame_with_huge_window(0x00, &[], b"0123456789abcdef");
    assert_eq!(
        JetstreamZstd::decompress_with_limit(&standalone, 1024 * 1024),
        Err(JetstreamZstdError::FrameTooLarge {
            declared: WINDOW,
            limit: 1024 * 1024
        })
    );
    // The same frame decodes when the limit admits its window.
    assert_eq!(
        JetstreamZstd::decompress_with_limit(&standalone, 64 * 1024 * 1024).unwrap(),
        b"0123456789abcdef"
    );

    // Dictionary path: a small declared content size does not excuse a huge window.
    let dict = base64::engine::general_purpose::STANDARD
        .decode(RAW_DICT_B64)
        .unwrap();
    let decoder = JetstreamZstdDictionaryDecoder::with_max_size(&dict, 1024 * 1024).unwrap();
    // FHD 0x40: 2-byte Frame_Content_Size (value + 256), no dictionary ID; FCS 0 -> 256 bytes.
    let dict_frame = frame_with_huge_window(0x40, &[0, 0], &[b'a'; 256]);
    assert_eq!(
        decoder.decompress(&dict_frame),
        Err(JetstreamZstdError::FrameTooLarge {
            declared: WINDOW,
            limit: 1024 * 1024
        })
    );
}
