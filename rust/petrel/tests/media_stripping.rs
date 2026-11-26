use base64::{Engine, engine::general_purpose::STANDARD as BASE64};
use petrel::media::{ImageContainerSurgery, ImageMetadataStripper, ImageMetadataStrippingError};

const SECRET_CAMERA_MAKE: &str = "PetrelCam-9000";
const SECRET_XMP_AUTHOR: &str = "xmp-author-Jane-Doe";
const SECRET_XMP_GPS: &str = "40,26.767N";
const SECRET_IPTC_CITY: &str = "IPTC-City-Pittsburgh";
const SECRET_COMMENT: &str = "comment-shot-at-home";
const SECRET_TRAILER: &str = "TRAILER-AFTER-END";

const BASELINE_JPEG_B64: &str = "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAAQABADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/90ABAAB/9oADAMBAAIRAxEAPwDzfTtA6fJXXadoHT5P0rpNO0Dp8n6V12naB0+SilVDIc+21P/Z";
const PROGRESSIVE_JPEG_B64: &str = "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wgARCAAQABADASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAABQb/xAAUAQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAGbXSXP/8QAFRABAQAAAAAAAAAAAAAAAAAAAwD/2gAIAQEAAQUCMIwjCML/xAAVEQEBAAAAAAAAAAAAAAAAAAAEAP/aAAgBAwEBPwED7//EABURAQEAAAAAAAAAAAAAAAAAAAIA/9oACAECAQE/ASr/xAAUEAEAAAAAAAAAAAAAAAAAAAAg/9oACAEBAAY/Ah//xAAVEAEBAAAAAAAAAAAAAAAAAAAAYf/aAAgBAQABPyGKKKL/2gAMAwEAAgADAAAAEAP/xAAWEQADAAAAAAAAAAAAAAAAAAAAITH/2gAIAQMBAT8Qgz//xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/EH//xAAWEAEBAQAAAAAAAAAAAAAAAAAAMcH/2gAIAQEAAT8QmzynlN//2Q==";
const WEBP_LOSSY_B64: &str = "UklGRkwAAABXRUJQVlA4IEAAAADQAQCdASoIAAgAAUAmJagCdAEPDAbF4AD+/NL+knuy93LHeaDzZiaV80//9R/NBckl/v+ftEZD/4D/opcMAAAA";
const WEBP_LOSSLESS_B64: &str =
    "UklGRiwAAABXRUJQVlA4TCAAAAAvB8ABALmM6H/sClGIgvc/ICQgTPF/p+bAgERMANjeAA==";

fn contains_subslice(haystack: &[u8], needle: &[u8]) -> bool {
    !needle.is_empty() && haystack.windows(needle.len()).any(|w| w == needle)
}

fn expect_no_secrets(bytes: &[u8]) {
    for secret in [
        SECRET_CAMERA_MAKE,
        SECRET_XMP_AUTHOR,
        SECRET_XMP_GPS,
        SECRET_IPTC_CITY,
        SECRET_COMMENT,
        SECRET_TRAILER,
    ] {
        assert!(
            !contains_subslice(bytes, secret.as_bytes()),
            "secret `{secret}` survived stripping"
        );
    }
}

fn exif_tiff_be(orientation: u16) -> Vec<u8> {
    let mut make = SECRET_CAMERA_MAKE.as_bytes().to_vec();
    make.push(0);
    let make_padding = make.len() % 2;
    let make_offset = 50_u32;
    let gps_offset = make_offset + u32::try_from(make.len() + make_padding).unwrap();
    let lat_offset = gps_offset + 30;

    let mut tiff = Vec::new();
    tiff.extend_from_slice(b"MM");
    tiff.extend_from_slice(&42_u16.to_be_bytes());
    tiff.extend_from_slice(&8_u32.to_be_bytes());
    tiff.extend_from_slice(&3_u16.to_be_bytes());
    // Make
    tiff.extend_from_slice(&0x010F_u16.to_be_bytes());
    tiff.extend_from_slice(&2_u16.to_be_bytes());
    tiff.extend_from_slice(&u32::try_from(make.len()).unwrap().to_be_bytes());
    tiff.extend_from_slice(&make_offset.to_be_bytes());
    // Orientation
    tiff.extend_from_slice(&0x0112_u16.to_be_bytes());
    tiff.extend_from_slice(&3_u16.to_be_bytes());
    tiff.extend_from_slice(&1_u32.to_be_bytes());
    tiff.extend_from_slice(&orientation.to_be_bytes());
    tiff.extend_from_slice(&0_u16.to_be_bytes());
    // GPS IFD pointer
    tiff.extend_from_slice(&0x8825_u16.to_be_bytes());
    tiff.extend_from_slice(&4_u16.to_be_bytes());
    tiff.extend_from_slice(&1_u32.to_be_bytes());
    tiff.extend_from_slice(&gps_offset.to_be_bytes());
    tiff.extend_from_slice(&0_u32.to_be_bytes());

    tiff.extend_from_slice(&make);
    if make_padding == 1 {
        tiff.push(0);
    }
    // GPS IFD (2 entries)
    tiff.extend_from_slice(&2_u16.to_be_bytes());
    tiff.extend_from_slice(&0x0001_u16.to_be_bytes());
    tiff.extend_from_slice(&2_u16.to_be_bytes());
    tiff.extend_from_slice(&2_u32.to_be_bytes());
    tiff.extend_from_slice(&[b'N', 0, 0, 0]);
    tiff.extend_from_slice(&0x0002_u16.to_be_bytes());
    tiff.extend_from_slice(&5_u16.to_be_bytes());
    tiff.extend_from_slice(&3_u32.to_be_bytes());
    tiff.extend_from_slice(&lat_offset.to_be_bytes());
    tiff.extend_from_slice(&0_u32.to_be_bytes());
    for num in [40_u32, 1, 26, 1, 46, 1] {
        tiff.extend_from_slice(&num.to_be_bytes());
    }
    tiff
}

fn xmp_packet() -> Vec<u8> {
    format!(
        "<x:xmpmeta xmlns:x=\"adobe:ns:meta/\"><rdf:Description dc:creator=\"{SECRET_XMP_AUTHOR}\" exif:GPSLatitude=\"{SECRET_XMP_GPS}\"/></x:xmpmeta>"
    )
    .into_bytes()
}

fn jpeg_segment(marker: u8, payload: &[u8]) -> Vec<u8> {
    let mut out = vec![0xFF, marker];
    out.extend_from_slice(&u16::try_from(payload.len() + 2).unwrap().to_be_bytes());
    out.extend_from_slice(payload);
    out
}

fn jpeg_loaded(base: &[u8], orientation: u16) -> Vec<u8> {
    let jfif_end = 20;
    let mut metadata = Vec::new();
    let mut jfxx = b"JFXX\0\x13".to_vec();
    jfxx.extend_from_slice(b"thumbnail-bytes");
    metadata.extend_from_slice(&jpeg_segment(0xE0, &jfxx));

    let mut exif = b"Exif\0\0".to_vec();
    exif.extend_from_slice(&exif_tiff_be(orientation));
    metadata.extend_from_slice(&jpeg_segment(0xE1, &exif));

    let mut xmp = b"http://ns.adobe.com/xap/1.0/\0".to_vec();
    xmp.extend_from_slice(&xmp_packet());
    metadata.extend_from_slice(&jpeg_segment(0xE1, &xmp));

    let mut icc = b"ICC_PROFILE\0\x01\x01not-a-real-icc".to_vec();
    metadata.extend_from_slice(&jpeg_segment(0xE2, &icc));
    icc.clear();

    metadata.extend_from_slice(&jpeg_segment(0xED, SECRET_IPTC_CITY.as_bytes()));
    metadata.extend_from_slice(&jpeg_segment(0xFE, SECRET_COMMENT.as_bytes()));

    let mut out = Vec::new();
    out.extend_from_slice(&base[..jfif_end]);
    out.extend_from_slice(&metadata);
    out.extend_from_slice(&base[jfif_end..]);
    out.extend_from_slice(SECRET_TRAILER.as_bytes());
    out
}

fn png_chunk(chunk_type: &str, data: &[u8]) -> Vec<u8> {
    let mut type_and_data = chunk_type.as_bytes().to_vec();
    type_and_data.extend_from_slice(data);
    let mut out = u32::try_from(data.len()).unwrap().to_be_bytes().to_vec();
    out.extend_from_slice(&type_and_data);
    out.extend_from_slice(&ImageContainerSurgery::crc32(&type_and_data).to_be_bytes());
    out
}

fn png_base() -> Vec<u8> {
    let mut out = vec![0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    let mut ihdr = 4_u32.to_be_bytes().to_vec();
    ihdr.extend_from_slice(&4_u32.to_be_bytes());
    ihdr.extend_from_slice(&[8, 2, 0, 0, 0]);
    out.extend_from_slice(&png_chunk("IHDR", &ihdr));
    out.extend_from_slice(&png_chunk(
        "IDAT",
        &[
            0x78, 0x01, 0x01, 0x01, 0x00, 0xFE, 0xFF, 0x00, 0x00, 0x01, 0x00, 0x01,
        ],
    ));
    out.extend_from_slice(&png_chunk("IEND", &[]));
    out
}

fn png_loaded(orientation: u16) -> Vec<u8> {
    let base = png_base();
    let header_end = 8 + 12 + 13;
    let iend_start = base.len() - 12;
    let mut out = base[..header_end].to_vec();
    out.extend_from_slice(&png_chunk("sRGB", &[0]));
    out.extend_from_slice(&png_chunk("pHYs", &[0, 0, 11, 19, 0, 0, 11, 19, 1]));
    let mut text = b"Comment\0".to_vec();
    text.extend_from_slice(SECRET_COMMENT.as_bytes());
    out.extend_from_slice(&png_chunk("tEXt", &text));
    out.extend_from_slice(&png_chunk("iTXt", &xmp_packet()));
    out.extend_from_slice(&png_chunk("tIME", &[7, 234, 11, 11, 9, 30, 0]));
    out.extend_from_slice(&png_chunk("eXIf", &exif_tiff_be(orientation)));
    out.extend_from_slice(&png_chunk("prVt", SECRET_IPTC_CITY.as_bytes()));
    out.extend_from_slice(&base[header_end..iend_start]);
    out.extend_from_slice(&base[iend_start..]);
    out.extend_from_slice(SECRET_TRAILER.as_bytes());
    out
}

fn webp_chunk(four_cc: &str, payload: &[u8]) -> Vec<u8> {
    let mut out = four_cc.as_bytes().to_vec();
    out.extend_from_slice(&u32::try_from(payload.len()).unwrap().to_le_bytes());
    out.extend_from_slice(payload);
    if payload.len() % 2 == 1 {
        out.push(0);
    }
    out
}

fn webp_loaded(simple: &[u8], orientation: u16) -> Vec<u8> {
    let mut xmp = xmp_packet();
    if xmp.len().is_multiple_of(2) {
        xmp.push(b'!');
    }
    let mut body = Vec::new();
    body.extend_from_slice(&webp_chunk("VP8X", &[0x2C, 0, 0, 0, 7, 0, 0, 7, 0, 0]));
    body.extend_from_slice(&webp_chunk("ICCP", b"srgb-icc"));
    body.extend_from_slice(&simple[12..]);
    body.extend_from_slice(&webp_chunk("EXIF", &exif_tiff_be(orientation)));
    body.extend_from_slice(&webp_chunk("XMP ", &xmp));
    body.extend_from_slice(&webp_chunk("JUNK", SECRET_IPTC_CITY.as_bytes()));

    let mut out = b"RIFF".to_vec();
    out.extend_from_slice(&u32::try_from(body.len() + 4).unwrap().to_le_bytes());
    out.extend_from_slice(b"WEBP");
    out.extend_from_slice(&body);
    out.extend_from_slice(SECRET_TRAILER.as_bytes());
    out
}

fn gif_loaded() -> Vec<u8> {
    let mut out = b"GIF89a".to_vec();
    out.extend_from_slice(&[1, 0, 1, 0, 0x80, 0, 0]);
    out.extend_from_slice(&[0, 0, 0, 255, 255, 255]);
    // NETSCAPE2.0 loop block
    out.extend_from_slice(&[0x21, 0xFF, 11]);
    out.extend_from_slice(b"NETSCAPE2.0");
    out.extend_from_slice(&[3, 1, 0, 0, 0]);
    // Comment block
    out.extend_from_slice(&[0x21, 0xFE]);
    out.push(u8::try_from(SECRET_COMMENT.len()).unwrap());
    out.extend_from_slice(SECRET_COMMENT.as_bytes());
    out.push(0);
    // Frame
    out.extend_from_slice(&[0x21, 0xF9, 4, 0, 10, 0, 0, 0]);
    out.extend_from_slice(&[0x2C, 0, 0, 0, 0, 1, 0, 1, 0, 0, 2, 2, 0x4C, 0x01, 0]);
    out.push(0x3B);
    out.extend_from_slice(SECRET_TRAILER.as_bytes());
    out
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn strips_jpeg_png_webp_and_gif_losslessly_with_orientation() {
    let baseline = BASE64.decode(BASELINE_JPEG_B64).unwrap();
    let progressive = BASE64.decode(PROGRESSIVE_JPEG_B64).unwrap();

    for base in [&baseline, &progressive] {
        let stripped_1 =
            ImageMetadataStripper::strip_metadata(&jpeg_loaded(base, 1), "image/jpeg").unwrap();
        expect_no_secrets(&stripped_1);
        assert!(!contains_subslice(&stripped_1, b"Exif\0\0"));
        assert!(contains_subslice(&stripped_1, b"ICC_PROFILE\0"));

        for orientation in [2_u16, 3, 6, 8] {
            let stripped = ImageMetadataStripper::strip_metadata(
                &jpeg_loaded(base, orientation),
                "image/jpeg",
            )
            .unwrap();
            expect_no_secrets(&stripped);
            assert!(contains_subslice(&stripped, b"Exif\0\0"));
            assert!(contains_subslice(
                &stripped,
                &ImageContainerSurgery::orientation_only_tiff(orientation)
            ));
        }
    }

    // Little-endian EXIF orientation is preserved as canonical orientation-only TIFF.
    let mut le_tiff = vec![
        b'I', b'I', 42, 0, 8, 0, 0, 0, 1, 0, 0x12, 0x01, 3, 0, 1, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0,
    ];
    let mut png_le = png_base();
    let end = png_le.len() - 12;
    let tail = png_le.split_off(end);
    png_le.extend_from_slice(&png_chunk("eXIf", &le_tiff));
    png_le.extend_from_slice(&tail);
    le_tiff.clear();
    let stripped_le_png = ImageMetadataStripper::strip_metadata(&png_le, "image/png").unwrap();
    assert!(contains_subslice(
        &stripped_le_png,
        &ImageContainerSurgery::orientation_only_tiff(6)
    ));

    let stripped_png = ImageMetadataStripper::strip_metadata(&png_loaded(6), "image/png").unwrap();
    expect_no_secrets(&stripped_png);
    assert!(contains_subslice(&stripped_png, b"sRGB"));
    assert!(contains_subslice(&stripped_png, b"pHYs"));
    assert!(contains_subslice(&stripped_png, b"eXIf"));

    let lossy = BASE64.decode(WEBP_LOSSY_B64).unwrap();
    let lossless = BASE64.decode(WEBP_LOSSLESS_B64).unwrap();
    for simple in [&lossy, &lossless] {
        let stripped_1 =
            ImageMetadataStripper::strip_metadata(&webp_loaded(simple, 1), "image/webp").unwrap();
        expect_no_secrets(&stripped_1);
        assert!(!contains_subslice(&stripped_1, b"EXIF"));
        assert!(contains_subslice(&stripped_1, b"ICCP"));

        let stripped_6 =
            ImageMetadataStripper::strip_metadata(&webp_loaded(simple, 6), "image/webp").unwrap();
        expect_no_secrets(&stripped_6);
        assert!(contains_subslice(&stripped_6, b"EXIF"));
    }

    let stripped_gif = ImageMetadataStripper::strip_metadata(&gif_loaded(), "image/gif").unwrap();
    expect_no_secrets(&stripped_gif);
    assert!(contains_subslice(&stripped_gif, b"NETSCAPE2.0"));
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn rejects_malformed_and_unsupported_image_formats_and_passes_non_images() {
    assert_eq!(
        ImageMetadataStripper::strip_metadata(b"{\"hello\":true}", "application/json").unwrap(),
        bytes::Bytes::from_static(b"{\"hello\":true}")
    );

    assert_eq!(
        ImageMetadataStripper::strip_metadata(b"\x00\x00\x00\x18ftypheic", "IMAGE/HEIC"),
        Err(ImageMetadataStrippingError::UnsupportedImageFormat(
            "image/heic".to_owned()
        ))
    );
    assert_eq!(
        ImageMetadataStripper::strip_metadata(b"<svg/>", "image/svg+xml"),
        Err(ImageMetadataStrippingError::UnsupportedImageFormat(
            "image/svg+xml".to_owned()
        ))
    );

    // Sniffs container even if declared wrong.
    let png = ImageMetadataStripper::strip_metadata(&png_loaded(1), "image/jpeg").unwrap();
    expect_no_secrets(&png);
    assert_eq!(&png[..8], &[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

    // Malformed containers fail closed.
    let baseline = BASE64.decode(BASELINE_JPEG_B64).unwrap();
    let cases: &[(&[u8], &str)] = &[
        (b"", "image/jpeg"),
        (b"", "image/png"),
        (b"", "image/webp"),
        (b"not-a-png", "image/png"),
        (b"RIFFxxxxWAVEfmt ", "image/webp"),
        (&baseline[..baseline.len() - 2], "image/jpeg"),
        (&[0xFF, 0xD8, 0xFF], "image/jpeg"),
        (
            &[0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x00, 0xFF, 0xD9],
            "image/jpeg",
        ),
        (&png_base()[..png_base().len() - 12], "image/png"),
        (&gif_loaded()[..20], "image/gif"),
    ];
    for &(bytes, mime) in cases {
        assert_eq!(
            ImageMetadataStripper::strip_metadata(bytes, mime),
            Err(ImageMetadataStrippingError::MalformedImage),
            "mime={mime}"
        );
    }

    // Truncation and bit-flip fuzz never panic.
    let lossy = BASE64.decode(WEBP_LOSSY_B64).unwrap();
    let fixtures = [
        (jpeg_loaded(&baseline, 6), "image/jpeg"),
        (png_loaded(6), "image/png"),
        (webp_loaded(&lossy, 6), "image/webp"),
        (gif_loaded(), "image/gif"),
    ];
    let mut state = 0x1234_5678_9ABC_DEF0_u64;
    let mut next = || -> usize {
        state = state
            .wrapping_mul(6_364_136_223_846_793_005)
            .wrapping_add(1_442_695_040_888_963_407);
        usize::try_from(state >> 33).unwrap_or(0)
    };
    for (fixture, mime) in fixtures {
        for len in (0..fixture.len()).step_by(7) {
            let _ = ImageMetadataStripper::strip_metadata(&fixture[..len], mime);
        }
        for _ in 0..250 {
            let mut mutated = fixture.clone();
            let flips = 1 + next() % 3;
            for _ in 0..flips {
                let idx = next() % mutated.len();
                let bit = u8::try_from(next() % 8).unwrap_or(0);
                mutated[idx] ^= 1_u8 << bit;
            }
            let _ = ImageMetadataStripper::strip_metadata(&mutated, mime);
        }
    }
}
