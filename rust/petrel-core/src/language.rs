//! Lexicon `language`: a BCP 47 language tag.
//!
//! A [`Language`] keeps the tag verbatim. Decoding requires only that the tag
//! is well-formed.
//!
//! **Placeholder validator.** Lane 0 checks only that the tag is made of
//! hyphen-separated alphanumeric subtags. Lane A (work package C3) replaces
//! it with the hand-written RFC 5646 parser ported from
//! `Sources/Petrel/Core/Utils/Languages.swift` (plan decision 7), including
//! the well-formed versus valid distinction and the grandfathered tags.

use crate::error::SyntaxKind;
use crate::syntax::string_newtype;

fn validate_language(value: &str) -> Result<(), &'static str> {
    let well_formed = !value.is_empty()
        && value.split('-').all(|subtag| {
            (1..=8).contains(&subtag.len()) && subtag.bytes().all(|b| b.is_ascii_alphanumeric())
        });
    if well_formed {
        Ok(())
    } else {
        Err("expected hyphen-separated alphanumeric subtags")
    }
}

string_newtype!(
    /// Lexicon `language`: a BCP 47 tag, kept exactly as written.
    Language,
    SyntaxKind::Language,
    validate_language
);
