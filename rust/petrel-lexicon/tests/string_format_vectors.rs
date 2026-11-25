use petrel_lexicon::LexStringFormat;

fn load_lines(raw: &str) -> Vec<&str> {
    raw.lines()
        .filter(|line| {
            let trimmed = line.trim();
            !trimmed.is_empty() && !trimmed.starts_with('#')
        })
        .collect()
}

fn check_format_vectors(format: &LexStringFormat, valid_raw: &str, invalid_raw: &str) {
    let valid = load_lines(valid_raw);
    assert!(!valid.is_empty(), "missing valid vectors for {format}");
    for sample in valid {
        assert!(
            format.is_valid(sample),
            "expected valid {format} sample {sample:?} to pass"
        );
    }

    let invalid = load_lines(invalid_raw);
    assert!(!invalid.is_empty(), "missing invalid vectors for {format}");
    for sample in invalid {
        assert!(
            !format.is_valid(sample),
            "expected invalid {format} sample {sample:?} to fail"
        );
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn official_string_format_vectors_all_eleven() {
    check_format_vectors(
        &LexStringFormat::Did,
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/did_syntax_valid.txt"),
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/did_syntax_invalid.txt"),
    );
    check_format_vectors(
        &LexStringFormat::Handle,
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/handle_syntax_valid.txt"),
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/handle_syntax_invalid.txt"),
    );
    check_format_vectors(
        &LexStringFormat::AtIdentifier,
        include_str!(
            "../../../Tests/PetrelLexiconTests/Vectors/syntax/atidentifier_syntax_valid.txt"
        ),
        include_str!(
            "../../../Tests/PetrelLexiconTests/Vectors/syntax/atidentifier_syntax_invalid.txt"
        ),
    );
    check_format_vectors(
        &LexStringFormat::Nsid,
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/nsid_syntax_valid.txt"),
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/nsid_syntax_invalid.txt"),
    );
    check_format_vectors(
        &LexStringFormat::AtUri,
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/aturi_syntax_valid.txt"),
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/aturi_syntax_invalid.txt"),
    );
    check_format_vectors(
        &LexStringFormat::Uri,
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/uri_syntax_valid.txt"),
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/uri_syntax_invalid.txt"),
    );
    check_format_vectors(
        &LexStringFormat::Cid,
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/cid_syntax_valid.txt"),
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/cid_syntax_invalid.txt"),
    );
    check_format_vectors(
        &LexStringFormat::Datetime,
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/datetime_syntax_valid.txt"),
        include_str!(
            "../../../Tests/PetrelLexiconTests/Vectors/syntax/datetime_syntax_invalid.txt"
        ),
    );
    for bad in load_lines(include_str!(
        "../../../Tests/PetrelLexiconTests/Vectors/syntax/datetime_parse_invalid.txt"
    )) {
        assert!(
            !LexStringFormat::Datetime.is_valid(bad),
            "expected datetime_parse_invalid {bad:?} to fail"
        );
    }
    check_format_vectors(
        &LexStringFormat::Language,
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/language_syntax_valid.txt"),
        include_str!(
            "../../../Tests/PetrelLexiconTests/Vectors/syntax/language_syntax_invalid.txt"
        ),
    );
    for bad in load_lines(include_str!(
        "../../../Tests/PetrelLexiconTests/Vectors/syntax/language_parse_invalid.txt"
    )) {
        assert!(
            !LexStringFormat::Language.is_valid(bad),
            "expected language_parse_invalid {bad:?} to fail"
        );
    }
    check_format_vectors(
        &LexStringFormat::Tid,
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/tid_syntax_valid.txt"),
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/tid_syntax_invalid.txt"),
    );
    check_format_vectors(
        &LexStringFormat::RecordKey,
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/syntax/recordkey_syntax_valid.txt"),
        include_str!(
            "../../../Tests/PetrelLexiconTests/Vectors/syntax/recordkey_syntax_invalid.txt"
        ),
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn space_uris_and_standard_vs_custom_formats() {
    assert_eq!(LexStringFormat::STANDARD.len(), 11);
    for fmt in LexStringFormat::STANDARD {
        assert!(fmt.is_standard());
    }

    let space_ref = LexStringFormat::parse("space-ref");
    assert!(!space_ref.is_standard());
    assert!(
        space_ref.is_valid("at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa")
    );
    assert!(
        !space_ref
            .is_valid("at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3jui7kd54zh2y")
    );

    // PR #90: AtUri accepts at:space/ forms too
    assert!(LexStringFormat::AtUri.is_valid(
        "at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa/did:plc:ewvi7nxzyoun6zhxrhs64oiz/blue.catbird.mlsChat.message/3l2aaaaaaaaac"
    ));
    assert!(!LexStringFormat::AtUri.is_valid("at:space/"));
}
