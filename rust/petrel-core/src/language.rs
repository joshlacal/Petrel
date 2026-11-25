//! Lexicon language tags and the distinction between grammar and validity.

use std::collections::BTreeSet;
use std::fmt;
use std::iter::Peekable;
use std::str::{FromStr, Split};

use crate::error::{SyntaxError, SyntaxKind};
use crate::syntax::string_newtype;

const GRANDFATHERED: &[&str] = &[
    "en-gb-oed",
    "i-ami",
    "i-bnn",
    "i-default",
    "i-enochian",
    "i-hak",
    "i-klingon",
    "i-lux",
    "i-mingo",
    "i-navajo",
    "i-pwn",
    "i-tao",
    "i-tay",
    "i-tsu",
    "sgn-be-fr",
    "sgn-be-nl",
    "sgn-ch-de",
    "art-lojban",
    "cel-gaulish",
    "no-bok",
    "no-nyn",
    "zh-guoyu",
    "zh-hakka",
    "zh-min",
    "zh-min-nan",
    "zh-xiang",
];

/// The parsed parts of a valid BCP 47 language tag.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct LanguageTag {
    /// The complete tag as written.
    pub raw_value: String,
    /// The primary language. Absent for whole grandfathered and private-use tags.
    pub language: Option<String>,
    /// Up to three extended language subtags.
    pub extended_languages: Vec<String>,
    /// The four-letter script, if present.
    pub script: Option<String>,
    /// The two-letter or three-digit region, if present.
    pub region: Option<String>,
    /// Variation subtags in their original order.
    pub variants: Vec<String>,
    /// Extension sequences, each including its singleton prefix.
    pub extensions: Vec<String>,
    /// The private-use sequence including its singleton prefix.
    pub private_use: Option<String>,
    /// Whether the complete tag names a grandfathered registration.
    pub is_grandfathered: bool,
}

impl LanguageTag {
    /// Parses a valid tag with a lowercase two- or three-letter primary subtag,
    /// or a whole grandfathered or private-use tag.
    pub fn parse(value: &str) -> Result<Self, SyntaxError> {
        let tag = parse_tag(value).map_err(failure)?;
        tag.check_validity().map_err(failure)?;
        Ok(tag)
    }

    /// Whether a tag matches the grammar, regardless of capitalization or duplicates.
    pub fn is_well_formed(value: &str) -> bool {
        parse_tag(value).is_ok()
    }

    /// Whether a tag also meets the primary-language and uniqueness requirements.
    pub fn is_valid(value: &str) -> bool {
        Self::parse(value).is_ok()
    }

    fn check_validity(&self) -> Result<(), &'static str> {
        if let Some(primary) = &self.language
            && (!(2..=3).contains(&primary.len())
                || !primary.bytes().all(|b| b.is_ascii_lowercase()))
        {
            return Err("primary language must be two or three lowercase ASCII letters");
        }

        if self
            .variants
            .iter()
            .map(|variant| variant.to_ascii_lowercase())
            .collect::<BTreeSet<_>>()
            .len()
            != self.variants.len()
        {
            return Err("a variant subtag is repeated");
        }

        let mut seen_singletons = 0_u64;
        for extension in &self.extensions {
            let singleton = extension.as_bytes()[0].to_ascii_lowercase();
            let index = if singleton.is_ascii_digit() {
                singleton - b'0'
            } else {
                singleton - b'a' + 10
            };
            let bit = 1_u64 << index;
            if seen_singletons & bit != 0 {
                return Err("an extension singleton is repeated");
            }
            seen_singletons |= bit;
        }
        Ok(())
    }
}

impl fmt::Display for LanguageTag {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.raw_value)
    }
}

impl FromStr for LanguageTag {
    type Err = SyntaxError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        Self::parse(value)
    }
}

string_newtype!(
    /// Lexicon `language`: a well-formed BCP 47 tag kept exactly as written.
    Language,
    SyntaxKind::Language,
    validate_language
);

impl Language {
    /// Parses a tag that meets both grammar and validity requirements.
    pub fn parse_validated(value: impl Into<String>) -> Result<Self, SyntaxError> {
        let value = value.into();
        LanguageTag::parse(&value)?;
        Ok(Self(value))
    }

    /// Returns the tag's parts if it also meets strict language-tag validation.
    pub fn tag(&self) -> Option<LanguageTag> {
        LanguageTag::parse(self.as_str()).ok()
    }
}

fn failure(reason: &'static str) -> SyntaxError {
    SyntaxError::new(SyntaxKind::Language, reason)
}

fn validate_language(value: &str) -> Result<(), &'static str> {
    parse_tag(value).map(|_| ())
}

fn alpha_at_len(value: &str, len: usize) -> bool {
    value.len() == len && value.bytes().all(|b| b.is_ascii_alphabetic())
}

fn private_use(value: &str) -> bool {
    value.eq_ignore_ascii_case("x")
}

fn variant(value: &str) -> bool {
    value.len() >= 5 || (value.len() == 4 && value.as_bytes()[0].is_ascii_digit())
}

type Subtags<'a> = Peekable<Split<'a, char>>;

fn extensions(subtags: &mut Subtags<'_>) -> Result<Vec<String>, &'static str> {
    let mut result = Vec::new();
    while let Some(singleton) = subtags.next_if(|part| part.len() == 1 && !private_use(part)) {
        let first = subtags
            .next_if(|part| part.len() >= 2)
            .ok_or("extension singleton must have a subtag of at least two characters")?;
        let mut extension = format!("{singleton}-{first}");
        while let Some(part) = subtags.next_if(|part| part.len() >= 2) {
            extension.push('-');
            extension.push_str(part);
        }
        result.push(extension);
    }
    Ok(result)
}

fn parse_tag(raw: &str) -> Result<LanguageTag, &'static str> {
    if !raw.split('-').all(|subtag| {
        (1..=8).contains(&subtag.len()) && subtag.bytes().all(|b| b.is_ascii_alphanumeric())
    }) {
        return Err("each subtag must be 1–8 ASCII letters or digits");
    }

    let mut result = LanguageTag {
        raw_value: raw.to_owned(),
        language: None,
        extended_languages: Vec::new(),
        script: None,
        region: None,
        variants: Vec::new(),
        extensions: Vec::new(),
        private_use: None,
        is_grandfathered: false,
    };
    if GRANDFATHERED
        .iter()
        .any(|tag| raw.eq_ignore_ascii_case(tag))
    {
        result.is_grandfathered = true;
        return Ok(result);
    }

    let mut parts = raw.split('-').peekable();
    let primary = parts.next().ok_or("primary language subtag is missing")?;
    if private_use(primary) {
        if parts.peek().is_none() {
            return Err("private-use singleton must have a subtag");
        }
        result.private_use = Some(raw.to_owned());
        return Ok(result);
    }

    if primary.len() < 2 || !primary.bytes().all(|b| b.is_ascii_alphabetic()) {
        return Err("primary language subtag must be 2–8 ASCII letters");
    }
    result.language = Some(primary.to_owned());

    if primary.len() <= 3 {
        for _ in 0..3 {
            let Some(part) = parts.next_if(|part| alpha_at_len(part, 3)) else {
                break;
            };
            result.extended_languages.push(part.to_owned());
        }
    }

    result.script = parts
        .next_if(|part| alpha_at_len(part, 4))
        .map(str::to_owned);
    result.region = parts
        .next_if(|part| {
            alpha_at_len(part, 2) || (part.len() == 3 && part.bytes().all(|b| b.is_ascii_digit()))
        })
        .map(str::to_owned);

    while let Some(part) = parts.next_if(|part| variant(part)) {
        result.variants.push(part.to_owned());
    }

    result.extensions = extensions(&mut parts)?;

    if let Some(singleton) = parts.next_if(|part| private_use(part)) {
        let rest: Vec<_> = parts.by_ref().collect();
        if rest.is_empty() {
            return Err("private-use singleton must have a subtag");
        }
        result.private_use = Some(format!("{singleton}-{}", rest.join("-")));
    }

    if parts.peek().is_some() {
        return Err("subtag is invalid at this position");
    }

    Ok(result)
}
