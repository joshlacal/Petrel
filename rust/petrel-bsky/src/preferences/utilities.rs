//! Pure validation, normalization, and migration helpers for Bluesky preferences.

use petrel_api::generated::app::bsky::actor::defs::SavedFeed;
use petrel_core::AtUri;

use crate::agent::BskyAgentError;
use crate::unicode::is_ecmascript_whitespace;

fn is_disallowed_in_muted_word(ch: char) -> bool {
    matches!(
        ch as u32,
        0x0D | 0x0A | 0xAD | 0x2060 | 0x200D | 0x200C | 0x200B
    )
}

/// Normalizes a muted word before storage: trims ECMAScript whitespace, drops one leading
/// `#` (unless `#\u{FE0F}`), and removes the first run of line breaks / zero-width chars.
#[must_use]
pub fn sanitize_muted_word_value(value: &str) -> String {
    let mut chars: Vec<char> = value.chars().collect();
    while chars.first().is_some_and(|&c| is_ecmascript_whitespace(c)) {
        chars.remove(0);
    }
    while chars.last().is_some_and(|&c| is_ecmascript_whitespace(c)) {
        chars.pop();
    }

    if chars.first() == Some(&'#') && chars.get(1) != Some(&'\u{FE0F}') {
        chars.remove(0);
    }

    if let Some(start) = chars.iter().position(|&c| is_disallowed_in_muted_word(c)) {
        let mut end = start;
        while end < chars.len() && is_disallowed_in_muted_word(chars[end]) {
            end += 1;
        }
        chars.drain(start..end);
    }

    chars.into_iter().collect()
}

/// Splits v2 `(value, pinned)` pairs into `(pinned, saved)` v1 URI arrays.
#[must_use]
pub fn saved_feeds_to_uri_arrays(saved_feeds: &[(&str, bool)]) -> (Vec<String>, Vec<String>) {
    let mut pinned = Vec::new();
    let mut saved = Vec::new();
    for &(value, is_pinned) in saved_feeds {
        if is_pinned {
            pinned.push(value.to_owned());
        }
        saved.push(value.to_owned());
    }
    (pinned, saved)
}

/// Classifies an AT URI as `"feed"`, `"list"`, or `"unknown"`.
pub fn saved_feed_type(uri: &str) -> Result<&'static str, BskyAgentError> {
    let parsed = uri.parse::<AtUri>().map_err(|_| {
        BskyAgentError::InvalidInput(format!("Saved feed value is not an AT URI: {uri}"))
    })?;
    Ok(match parsed.collection().map(petrel_core::Nsid::as_str) {
        Some("app.bsky.feed.generator") => "feed",
        Some("app.bsky.graph.list") => "list",
        _ => "unknown",
    })
}

/// Validates a saved feed's ID and type/value correspondence before storing.
pub fn validate_saved_feed_fields(
    id: &str,
    r#type: &str,
    value: &str,
) -> Result<(), BskyAgentError> {
    if id.is_empty() {
        return Err(BskyAgentError::InvalidInput(
            "Saved feed must have an `id` - use a TID".to_owned(),
        ));
    }
    if r#type != "feed" && r#type != "list" {
        return Ok(());
    }
    let actual = saved_feed_type(value)?;
    if r#type == "feed" && actual != "feed" {
        return Err(BskyAgentError::InvalidInput(format!(
            "Saved feed of type 'feed' must be a feed, got {value}"
        )));
    }
    if r#type == "list" && actual != "list" {
        return Err(BskyAgentError::InvalidInput(format!(
            "Saved feed of type 'list' must be a list, got {value}"
        )));
    }
    Ok(())
}

/// Validates a `SavedFeed` entry.
pub fn validate_saved_feed(saved_feed: &SavedFeed) -> Result<(), BskyAgentError> {
    validate_saved_feed_fields(&saved_feed.id, &saved_feed.r#type, &saved_feed.value)
}
