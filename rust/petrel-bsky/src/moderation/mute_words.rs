//! Scalar-level muted-word matching matching the official Bluesky rules.

use petrel_api::generated::app::bsky::actor::defs::MutedWord;
use petrel_api::generated::app::bsky::richtext::facet::{Facet, FacetFeatures};
use petrel_core::Datetime;

use super::types::{ModerationSubjectProfile, MuteWordMatch};
use crate::unicode::{is_ecmascript_whitespace, is_unicode_punctuation};

const LANGUAGE_EXCEPTIONS: &[&str] = &["ja", "zh", "ko", "th", "vi"];

/// Finds the muted words that match `text` (and optional facets/outline tags).
#[must_use]
pub fn match_mute_words(
    muted_words: &[MutedWord],
    text: &str,
    facets: Option<&[Facet]>,
    outline_tags: Option<&[String]>,
    languages: Option<&[String]>,
    actor: Option<&dyn ModerationSubjectProfile>,
    now: &Datetime,
) -> Vec<MuteWordMatch> {
    if muted_words.is_empty() {
        return Vec::new();
    }

    let first_lang = languages
        .and_then(|langs| langs.first())
        .map_or("", String::as_str);
    let exception = LANGUAGE_EXCEPTIONS.contains(&first_lang);

    let mut tags: Vec<Vec<char>> = Vec::new();
    for tag in outline_tags.unwrap_or(&[]) {
        tags.push(tag.to_lowercase().chars().collect());
    }
    for facet in facets.unwrap_or(&[]) {
        for feature in &facet.features {
            if let FacetFeatures::Tag(tag) = feature {
                tags.push(tag.tag.to_lowercase().chars().collect());
            }
        }
    }

    let post_text: Vec<char> = text.to_lowercase().chars().collect();
    let post_length = utf16_length(&post_text);
    let mut post_words: Option<Vec<Vec<char>>> = None;
    let mut matches = Vec::new();

    for mute_word in muted_words {
        let muted_word_chars: Vec<char> = mute_word.value.to_lowercase().chars().collect();
        let muted_length = utf16_length(&muted_word_chars);

        if let Some(expires_at) = &mute_word.expires_at
            && (expires_at.unix_seconds(), expires_at.subsec_nanos())
                < (now.unix_seconds(), now.subsec_nanos())
        {
            continue;
        }
        if mute_word.actor_target.as_deref() == Some("exclude-following")
            && actor
                .and_then(|a| a.viewer())
                .and_then(|v| v.following.as_ref())
                .is_some()
        {
            continue;
        }

        if tags.iter().any(|tag| tag == &muted_word_chars) {
            matches.push(MuteWordMatch {
                word: mute_word.clone(),
                predicate: mute_word.value.clone(),
            });
            continue;
        }

        if !mute_word.targets.iter().any(|t| t.as_str() == "content") {
            continue;
        }

        if (muted_length == 1 || exception) && contains_slice(&post_text, &muted_word_chars) {
            matches.push(MuteWordMatch {
                word: mute_word.clone(),
                predicate: mute_word.value.clone(),
            });
            continue;
        }

        if muted_length > post_length {
            continue;
        }

        if muted_word_chars == post_text {
            matches.push(MuteWordMatch {
                word: mute_word.clone(),
                predicate: mute_word.value.clone(),
            });
            continue;
        }

        if muted_word_chars
            .iter()
            .any(|&ch| is_ecmascript_whitespace(ch) || is_unicode_punctuation(ch))
            && contains_slice(&post_text, &muted_word_chars)
        {
            matches.push(MuteWordMatch {
                word: mute_word.clone(),
                predicate: mute_word.value.clone(),
            });
            continue;
        }

        let words = post_words.get_or_insert_with(|| split_on_whitespace(&post_text));
        if let Some(predicate) = matching_word(words, &muted_word_chars, muted_length) {
            matches.push(MuteWordMatch {
                word: mute_word.clone(),
                predicate,
            });
        }
    }

    matches
}

/// Returns `true` when any muted word matches `text`.
#[must_use]
pub fn has_muted_word(
    muted_words: &[MutedWord],
    text: &str,
    facets: Option<&[Facet]>,
    outline_tags: Option<&[String]>,
    languages: Option<&[String]>,
    actor: Option<&dyn ModerationSubjectProfile>,
    now: &Datetime,
) -> bool {
    !match_mute_words(
        muted_words,
        text,
        facets,
        outline_tags,
        languages,
        actor,
        now,
    )
    .is_empty()
}

fn utf16_length(chars: &[char]) -> usize {
    chars.iter().map(|ch| ch.len_utf16()).sum()
}

fn contains_slice(haystack: &[char], needle: &[char]) -> bool {
    if needle.is_empty() {
        return true;
    }
    if haystack.len() < needle.len() {
        return false;
    }
    haystack
        .windows(needle.len())
        .any(|window| window == needle)
}

fn split_on_whitespace(chars: &[char]) -> Vec<Vec<char>> {
    let mut words = Vec::new();
    let mut current = Vec::new();
    for &ch in chars {
        if is_ecmascript_whitespace(ch) {
            words.push(std::mem::take(&mut current));
        } else {
            current.push(ch);
        }
    }
    words.push(current);
    words
}

fn split_on_punctuation(chars: &[char]) -> Vec<Vec<char>> {
    let mut parts = Vec::new();
    let mut current = Vec::new();
    let mut in_punct = false;
    for &ch in chars {
        if is_unicode_punctuation(ch) {
            if !in_punct {
                parts.push(std::mem::take(&mut current));
                in_punct = true;
            }
        } else {
            in_punct = false;
            current.push(ch);
        }
    }
    parts.push(current);
    parts
}

fn trimming_punctuation(chars: &[char]) -> &[char] {
    let mut start = 0;
    let mut end = chars.len();
    while start < end && is_unicode_punctuation(chars[start]) {
        start += 1;
    }
    while end > start && is_unicode_punctuation(chars[end - 1]) {
        end -= 1;
    }
    &chars[start..end]
}

fn replacing_punctuation_with_space(chars: &[char]) -> Vec<char> {
    let mut result = Vec::with_capacity(chars.len());
    let mut in_punct = false;
    for &ch in chars {
        if is_unicode_punctuation(ch) {
            if !in_punct {
                result.push(' ');
                in_punct = true;
            }
        } else {
            in_punct = false;
            result.push(ch);
        }
    }
    result
}

fn chars_to_string(chars: &[char]) -> String {
    chars.iter().collect()
}

fn matching_word(words: &[Vec<char>], muted_word: &[char], muted_length: usize) -> Option<String> {
    for word in words {
        if word.as_slice() == muted_word {
            return Some(chars_to_string(word));
        }

        let trimmed = trimming_punctuation(word);
        if trimmed == muted_word {
            return Some(chars_to_string(word));
        }
        if muted_length > utf16_length(trimmed) {
            continue;
        }

        if trimmed.iter().copied().any(is_unicode_punctuation) {
            if trimmed.contains(&'/') {
                continue;
            }
            let spaced = replacing_punctuation_with_space(trimmed);
            if spaced.as_slice() == muted_word {
                return Some(chars_to_string(word));
            }
            let contiguous: Vec<char> = spaced
                .iter()
                .copied()
                .filter(|&ch| !is_ecmascript_whitespace(ch))
                .collect();
            if contiguous.as_slice() == muted_word {
                return Some(chars_to_string(word));
            }
            for part in split_on_punctuation(trimmed) {
                if part.as_slice() == muted_word {
                    return Some(chars_to_string(word));
                }
            }
        }
    }
    None
}
