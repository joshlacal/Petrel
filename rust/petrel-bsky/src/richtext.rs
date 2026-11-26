//! RichText parsing, editing, facet detection, sanitization, and link shortening.

use std::collections::BTreeSet;
use std::future::Future;

use petrel_api::generated::app::bsky::feed::post::{Entity, Post};
use petrel_api::generated::app::bsky::richtext::facet::{
    ByteSlice, Facet, FacetFeatures, Link, Mention, Tag,
};
use petrel_core::{Did, Uri};

use crate::tld::is_valid_domain;
use crate::unicode::{count_graphemes, is_ecmascript_whitespace, is_unicode_punctuation};

/// What rich text detection found in plain text.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum RichTextDetectionKind {
    /// An `@handle` mention. Value is the handle without `@`.
    Mention {
        /// Handle without the leading `@`.
        handle: String,
    },
    /// A link. Value is the full URI (with `https://` added for bare domains).
    Link {
        /// Destination URI string.
        uri: String,
    },
    /// A hashtag (without `#`) or uppercased cashtag (with `$`).
    Tag(String),
}

/// A detected rich-text annotation with UTF-8 byte offsets.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct RichTextDetection {
    /// Offset of the first UTF-8 byte.
    pub byte_start: usize,
    /// Offset one past the last UTF-8 byte.
    pub byte_end: usize,
    /// What was detected.
    pub kind: RichTextDetectionKind,
}

impl RichTextDetection {
    /// Creates a detection.
    #[must_use]
    pub const fn new(byte_start: usize, byte_end: usize, kind: RichTextDetectionKind) -> Self {
        Self {
            byte_start,
            byte_end,
            kind,
        }
    }
}

/// Converts UTF-16 code unit offsets into UTF-8 byte offsets.
#[derive(Debug, Clone)]
pub(crate) struct Utf16ToUtf8Offsets {
    table: Vec<usize>,
}

impl Utf16ToUtf8Offsets {
    pub(crate) fn new(text: &str) -> Self {
        let mut table = Vec::with_capacity(text.encode_utf16().count() + 1);
        let mut utf8 = 0;
        for ch in text.chars() {
            let units = ch.len_utf16();
            for _ in 0..units {
                table.push(utf8);
            }
            utf8 += ch.len_utf8();
        }
        table.push(utf8);
        Self { table }
    }

    pub(crate) fn utf8_offset(&self, at_utf16: usize) -> usize {
        let idx = at_utf16.min(self.table.len() - 1);
        self.table[idx]
    }
}

/// Post text paired with UTF-8 byte-indexed `app.bsky.richtext.facet` annotations.
#[derive(Debug, Clone, PartialEq)]
pub struct RichText {
    /// Plain text of the post.
    pub text: String,
    /// Facets sorted by start offset (`byte_start <= byte_end`).
    pub facets: Vec<Facet>,
}

impl RichText {
    /// Maximum post length in Unicode extended grapheme clusters (`app.bsky.feed.post`).
    pub const MAX_POST_GRAPHEMES: usize = 300;
    /// Maximum post length in UTF-8 bytes (`app.bsky.feed.post`).
    pub const MAX_POST_UTF8_BYTES: usize = 3000;

    /// Creates rich text from plain text, optional facets, optional legacy entities, and optional newline cleaning.
    #[must_use]
    pub fn new(
        text: impl Into<String>,
        facets: Option<Vec<Facet>>,
        entities: Option<&[Entity]>,
        clean_newlines: bool,
    ) -> Self {
        let text = text.into();
        let mut resolved = facets.unwrap_or_default();
        if resolved.is_empty()
            && let Some(entities) = entities
            && !entities.is_empty()
        {
            resolved = Self::facets_from_entities(entities, &text);
        }
        resolved.retain(|facet| facet.index.byte_start <= facet.index.byte_end);
        let facets = Self::sorted_facets(resolved);
        let value = Self { text, facets };
        if clean_newlines {
            value.sanitized(true)
        } else {
            value
        }
    }

    /// Creates rich text from plain text with no facets.
    #[must_use]
    pub fn from_text(text: impl Into<String>) -> Self {
        Self::new(text, None, None, false)
    }

    /// Creates rich text from an `app.bsky.feed.post` record.
    #[must_use]
    pub fn from_post(post: &Post) -> Self {
        Self::new(
            post.text.as_str(),
            post.facets.clone(),
            post.entities.as_deref(),
            false,
        )
    }

    /// Returns the length of the text in UTF-8 bytes.
    #[must_use]
    pub fn utf8_length(&self) -> usize {
        self.text.len()
    }

    /// Returns the length of the text in Unicode extended grapheme clusters.
    #[must_use]
    pub fn grapheme_length(&self) -> usize {
        count_graphemes(&self.text)
    }

    /// Returns `true` when the text exceeds 300 graphemes or 3000 UTF-8 bytes.
    #[must_use]
    pub fn exceeds_post_limits(&self) -> bool {
        self.utf8_length() > Self::MAX_POST_UTF8_BYTES
            || self.grapheme_length() > Self::MAX_POST_GRAPHEMES
    }

    /// Returns facets formatted for a record (`None` when empty).
    #[must_use]
    pub fn record_facets(&self) -> Option<Vec<Facet>> {
        if self.facets.is_empty() {
            None
        } else {
            Some(self.facets.clone())
        }
    }

    /// Extracts the leniently UTF-8-decoded slice between two byte offsets (clamped).
    #[must_use]
    pub fn slice(&self, byte_start: i64, byte_end: i64) -> String {
        Self::slice_bytes(self.text.as_bytes(), byte_start, byte_end)
    }

    fn slice_bytes(bytes: &[u8], byte_start: i64, byte_end: i64) -> String {
        let len = i64::try_from(bytes.len()).unwrap_or(i64::MAX);
        let start = usize::try_from(byte_start.clamp(0, len)).unwrap_or(0);
        let end = usize::try_from(byte_end.clamp(byte_start.clamp(0, len), len)).unwrap_or(start);
        String::from_utf8_lossy(&bytes[start..end]).into_owned()
    }

    /// Splits the text into annotated and plain segments whose concatenated text equals `self.text`.
    #[must_use]
    pub fn segments(&self) -> Vec<RichTextSegment> {
        if self.facets.is_empty() {
            return vec![RichTextSegment::plain(self.text.clone())];
        }
        let bytes = self.text.as_bytes();
        let len_i64 = i64::try_from(bytes.len()).unwrap_or(i64::MAX);
        let mut segments = Vec::new();
        let mut text_cursor: i64 = 0;
        let mut facet_cursor: usize = 0;

        let push_plain = |out: &mut Vec<RichTextSegment>, start: i64, end: i64| {
            let piece = Self::slice_bytes(bytes, start, end);
            if !piece.is_empty() {
                out.push(RichTextSegment::plain(piece));
            }
        };

        while facet_cursor < self.facets.len() {
            let facet = &self.facets[facet_cursor];
            let start = facet.index.byte_start;
            let end = facet.index.byte_end;
            if text_cursor < start {
                push_plain(&mut segments, text_cursor, start);
            } else if text_cursor > start {
                facet_cursor += 1;
                continue;
            }
            if start < end {
                let piece = Self::slice_bytes(bytes, start, end);
                if crate::unicode::is_blank(&piece) {
                    if !piece.is_empty() {
                        segments.push(RichTextSegment::plain(piece));
                    }
                } else {
                    segments.push(RichTextSegment::with_facet(piece, facet.clone()));
                }
            }
            text_cursor = end;
            facet_cursor += 1;
        }

        if text_cursor < len_i64 {
            push_plain(&mut segments, text_cursor, len_i64);
        }
        segments
    }

    /// Inserts `insert_text` at `byte_index` (clamped), shifting and expanding facets.
    pub fn insert(&mut self, insert_text: &str, byte_index: i64) {
        let bytes = self.text.as_bytes();
        let len_i64 = i64::try_from(bytes.len()).unwrap_or(i64::MAX);
        let index_i64 = byte_index.clamp(0, len_i64);
        let index = usize::try_from(index_i64).unwrap_or(bytes.len());
        let inserted = insert_text.as_bytes();

        let mut combined = Vec::with_capacity(bytes.len() + inserted.len());
        combined.extend_from_slice(&bytes[..index]);
        combined.extend_from_slice(inserted);
        combined.extend_from_slice(&bytes[index..]);
        self.text = String::from_utf8_lossy(&combined).into_owned();

        let added = i64::try_from(inserted.len()).unwrap_or(i64::MAX);
        if added == 0 || self.facets.is_empty() {
            return;
        }
        for facet in &mut self.facets {
            let start = facet.index.byte_start;
            let end = facet.index.byte_end;
            if index_i64 <= start {
                facet.index.byte_start = start.saturating_add(added);
                facet.index.byte_end = end.saturating_add(added);
            } else if index_i64 < end {
                facet.index.byte_end = end.saturating_add(added);
            }
        }
    }

    /// Deletes bytes in `[byte_start, byte_end)` (clamped), adjusting or dropping affected facets.
    pub fn delete(&mut self, byte_start: i64, byte_end: i64) {
        let bytes = self.text.as_bytes();
        let len_i64 = i64::try_from(bytes.len()).unwrap_or(i64::MAX);
        let remove_start = byte_start.clamp(0, len_i64);
        let remove_end = byte_end.clamp(0, len_i64);
        if remove_start >= remove_end {
            return;
        }
        let rs = usize::try_from(remove_start).unwrap_or(0);
        let re = usize::try_from(remove_end).unwrap_or(rs);
        let mut combined = Vec::with_capacity(bytes.len() - (re - rs));
        combined.extend_from_slice(&bytes[..rs]);
        combined.extend_from_slice(&bytes[re..]);
        self.text = String::from_utf8_lossy(&combined).into_owned();

        if self.facets.is_empty() {
            return;
        }
        let removed = remove_end - remove_start;
        self.facets.retain_mut(|facet| {
            let mut start = facet.index.byte_start;
            let mut end = facet.index.byte_end;
            if remove_start <= start && remove_end >= end {
                return false;
            } else if remove_start > end {
                // Entirely after facet: unchanged.
            } else if remove_start > start && remove_start <= end && remove_end > end {
                end = remove_start;
            } else if remove_start >= start && remove_end <= end {
                end = end.saturating_sub(removed);
            } else if remove_start < start && remove_end >= start && remove_end <= end {
                start = remove_start;
                end = end.saturating_sub(removed);
            } else if remove_end < start {
                start = start.saturating_sub(removed);
                end = end.saturating_sub(removed);
            }
            if start >= end {
                return false;
            }
            facet.index.byte_start = start;
            facet.index.byte_end = end;
            true
        });
    }

    /// Appends plain text.
    pub fn append(&mut self, text: &str) {
        let len = i64::try_from(self.utf8_length()).unwrap_or(i64::MAX);
        self.insert(text, len);
    }

    /// Appends text annotated with a link facet.
    pub fn append_link(&mut self, text: &str, uri: Uri) {
        self.append_faceted(text, FacetFeatures::Link(Box::new(Link::new(uri))));
    }

    /// Appends text annotated with a mention facet.
    pub fn append_mention(&mut self, text: &str, did: Did) {
        self.append_faceted(text, FacetFeatures::Mention(Box::new(Mention::new(did))));
    }

    /// Appends text annotated with a hashtag facet (without leading `#`).
    pub fn append_tag(&mut self, text: &str, tag: impl Into<String>) {
        self.append_faceted(text, FacetFeatures::Tag(Box::new(Tag::new(tag.into()))));
    }

    fn append_faceted(&mut self, text: &str, feature: FacetFeatures) {
        let start = i64::try_from(self.utf8_length()).unwrap_or(i64::MAX);
        self.text.push_str(text);
        if text.is_empty() {
            return;
        }
        let end = i64::try_from(self.utf8_length()).unwrap_or(i64::MAX);
        self.facets
            .push(Facet::new(ByteSlice::new(start, end), vec![feature]));
    }

    /// Detects mentions, links, hashtags, and cashtags in plain text, sorted by byte offset.
    #[must_use]
    pub fn detect(text: &str) -> Vec<RichTextDetection> {
        let mut detections = detect_all(text);
        detections.sort_by_key(|d| d.byte_start);
        detections
    }

    /// Replaces `self.facets` with detected facets, resolving mentioned handles via `resolve_mention`.
    pub async fn detect_facets<F, Fut>(&mut self, resolve_mention: F)
    where
        F: Fn(String) -> Fut,
        Fut: Future<Output = Option<Did>>,
    {
        let detections = Self::detect(&self.text);
        let mut handles = BTreeSet::new();
        for detection in &detections {
            if let RichTextDetectionKind::Mention { handle } = &detection.kind {
                handles.insert(handle.clone());
            }
        }
        let mut resolved = std::collections::HashMap::new();
        for handle in handles {
            if let Some(did) = resolve_mention(handle.clone()).await {
                resolved.insert(handle, did);
            }
        }
        self.facets = Self::facets_from_detections(&detections, &resolved);
    }

    /// Replaces `self.facets` with detected links and tags only (leaving mentions as plain text).
    pub fn detect_facets_without_resolution(&mut self) {
        let detections = Self::detect(&self.text);
        let empty = std::collections::HashMap::new();
        self.facets = Self::facets_from_detections(&detections, &empty);
    }

    fn facets_from_detections(
        detections: &[RichTextDetection],
        mentions: &std::collections::HashMap<String, Did>,
    ) -> Vec<Facet> {
        detections
            .iter()
            .filter_map(|detection| {
                let feature = match &detection.kind {
                    RichTextDetectionKind::Mention { handle } => {
                        let did = mentions.get(handle)?.clone();
                        FacetFeatures::Mention(Box::new(Mention::new(did)))
                    }
                    RichTextDetectionKind::Link { uri } => {
                        let uri = uri.parse::<Uri>().ok()?;
                        FacetFeatures::Link(Box::new(Link::new(uri)))
                    }
                    RichTextDetectionKind::Tag(tag) => {
                        FacetFeatures::Tag(Box::new(Tag::new(tag.clone())))
                    }
                };
                Some(Facet::new(
                    ByteSlice::new(
                        i64::try_from(detection.byte_start).unwrap_or(i64::MAX),
                        i64::try_from(detection.byte_end).unwrap_or(i64::MAX),
                    ),
                    vec![feature],
                ))
            })
            .collect()
    }

    /// Returns a cleaned copy of the rich text with runs of 3+ line breaks collapsed to `\n\n`.
    #[must_use]
    pub fn sanitized(&self, clean_newlines: bool) -> Self {
        if !clean_newlines {
            return self.clone();
        }
        let mut result = self.clone();
        while let Some((remove_start, remove_end)) = find_excess_newlines(&result.text) {
            let before = result.text.clone();
            let rs = i64::try_from(remove_start).unwrap_or(i64::MAX);
            let re = i64::try_from(remove_end).unwrap_or(i64::MAX);
            result.delete(rs, re);
            if result.text == before {
                break;
            }
            result.insert("\n\n", rs);
        }
        result
    }

    /// Shortens an HTTP/HTTPS URL for display (dropping scheme and truncating paths > 15 chars to 13 + `...`).
    #[must_use]
    pub fn shortened_url(raw_url: &str) -> String {
        let Ok(parsed) = url::Url::parse(raw_url) else {
            return raw_url.to_owned();
        };
        let scheme = parsed.scheme();
        if scheme != "http" && scheme != "https" {
            return raw_url.to_owned();
        }
        let Some(raw_host) = parsed.host_str() else {
            return raw_url.to_owned();
        };
        if raw_host.is_empty() {
            return raw_url.to_owned();
        }
        let mut host = raw_host.to_ascii_lowercase();
        if let Some(port) = parsed.port() {
            host.push(':');
            host.push_str(&port.to_string());
        }
        let mut path = if parsed.path() == "/" {
            String::new()
        } else {
            parsed.path().to_owned()
        };
        if let Some(query) = parsed.query() {
            path.push('?');
            path.push_str(query);
        }
        if let Some(fragment) = parsed.fragment() {
            path.push('#');
            path.push_str(fragment);
        }
        if path.chars().count() > 15 {
            let prefix: String = path.chars().take(13).collect();
            format!("{host}{prefix}...")
        } else {
            format!("{host}{path}")
        }
    }

    /// Returns a copy whose link facet display text is shortened while preserving full facet URIs.
    #[must_use]
    pub fn shortening_links(&self) -> Self {
        let mut result = self.clone();
        for pos in 0..result.facets.len() {
            let is_link = result.facets[pos]
                .features
                .iter()
                .any(|f| matches!(f, FacetFeatures::Link(_)));
            if !is_link {
                continue;
            }
            let bytes = result.text.as_bytes().to_vec();
            let start_i64 = result.facets[pos].index.byte_start;
            let end_i64 = result.facets[pos].index.byte_end;
            let len_i64 = i64::try_from(bytes.len()).unwrap_or(i64::MAX);
            if start_i64 < 0 || start_i64 >= end_i64 || end_i64 > len_i64 {
                continue;
            }
            let start = usize::try_from(start_i64).unwrap_or(0);
            let end = usize::try_from(end_i64).unwrap_or(start);
            let shown = Self::slice_bytes(&bytes, start_i64, end_i64);
            let shortened = Self::shortened_url(&shown);
            if shortened == shown {
                continue;
            }
            let replacement = shortened.as_bytes();
            let mut combined = Vec::with_capacity(bytes.len() - (end - start) + replacement.len());
            combined.extend_from_slice(&bytes[..start]);
            combined.extend_from_slice(replacement);
            combined.extend_from_slice(&bytes[end..]);
            result.text = String::from_utf8_lossy(&combined).into_owned();

            let rep_len = i64::try_from(replacement.len()).unwrap_or(i64::MAX);
            let delta = rep_len - (end_i64 - start_i64);
            for (other, candidate) in result.facets.iter_mut().enumerate() {
                let other_start = candidate.index.byte_start;
                let other_end = candidate.index.byte_end;
                if other == pos {
                    candidate.index.byte_start = start_i64;
                    candidate.index.byte_end = start_i64.saturating_add(rep_len);
                } else if other_start >= end_i64 {
                    candidate.index.byte_start = other_start.saturating_add(delta);
                    candidate.index.byte_end = other_end.saturating_add(delta);
                } else if other_start <= start_i64 && other_end >= end_i64 {
                    candidate.index.byte_end = other_end.saturating_add(delta);
                }
            }
        }
        result
    }

    fn sorted_facets(mut facets: Vec<Facet>) -> Vec<Facet> {
        facets.sort_by_key(|f| f.index.byte_start);
        facets
    }

    fn facets_from_entities(entities: &[Entity], text: &str) -> Vec<Facet> {
        let offsets = Utf16ToUtf8Offsets::new(text);
        entities
            .iter()
            .filter_map(|entity| {
                let feature = match entity.r#type.as_str() {
                    "link" => {
                        let uri = entity.value.parse::<Uri>().ok()?;
                        FacetFeatures::Link(Box::new(Link::new(uri)))
                    }
                    "mention" => {
                        let did = entity.value.parse::<Did>().ok()?;
                        FacetFeatures::Mention(Box::new(Mention::new(did)))
                    }
                    _ => return None,
                };
                let start_u16 = usize::try_from(entity.index.start).ok()?;
                let end_u16 = usize::try_from(entity.index.end).ok()?;
                let byte_start = i64::try_from(offsets.utf8_offset(start_u16)).unwrap_or(i64::MAX);
                let byte_end = i64::try_from(offsets.utf8_offset(end_u16)).unwrap_or(i64::MAX);
                Some(Facet::new(
                    ByteSlice::new(byte_start, byte_end),
                    vec![feature],
                ))
            })
            .collect()
    }
}

/// One segment produced by [`RichText::segments`].
#[derive(Debug, Clone, PartialEq)]
pub struct RichTextSegment {
    /// Text of this run.
    pub text: String,
    /// Optional facet annotating this run.
    pub facet: Option<Facet>,
}

impl RichTextSegment {
    /// Creates a plain segment.
    #[must_use]
    pub const fn plain(text: String) -> Self {
        Self { text, facet: None }
    }

    /// Creates a faceted segment.
    #[must_use]
    pub const fn with_facet(text: String, facet: Facet) -> Self {
        Self {
            text,
            facet: Some(facet),
        }
    }

    /// Returns the link feature of this segment, if present.
    #[must_use]
    pub fn link(&self) -> Option<&Link> {
        self.facet.as_ref()?.features.iter().find_map(|f| match f {
            FacetFeatures::Link(link) => Some(link.as_ref()),
            _ => None,
        })
    }

    /// Returns the mention feature of this segment, if present.
    #[must_use]
    pub fn mention(&self) -> Option<&Mention> {
        self.facet.as_ref()?.features.iter().find_map(|f| match f {
            FacetFeatures::Mention(mention) => Some(mention.as_ref()),
            _ => None,
        })
    }

    /// Returns the tag feature of this segment, if present.
    #[must_use]
    pub fn tag(&self) -> Option<&Tag> {
        self.facet.as_ref()?.features.iter().find_map(|f| match f {
            FacetFeatures::Tag(tag) => Some(tag.as_ref()),
            _ => None,
        })
    }

    /// Returns `true` when this segment is a link.
    #[must_use]
    pub fn is_link(&self) -> bool {
        self.link().is_some()
    }

    /// Returns `true` when this segment is a mention.
    #[must_use]
    pub fn is_mention(&self) -> bool {
        self.mention().is_some()
    }

    /// Returns `true` when this segment is a tag.
    #[must_use]
    pub fn is_tag(&self) -> bool {
        self.tag().is_some()
    }
}

// MARK: Pure-Rust scanners matching RichTextDetection.swift regexes

fn is_ascii_word(ch: char) -> bool {
    ch.is_ascii_alphanumeric() || ch == '_'
}

fn is_handle_char(ch: char) -> bool {
    ch.is_ascii_alphanumeric() || ch == '.' || ch == '-'
}

fn is_tag_excluded(ch: char) -> bool {
    matches!(
        ch,
        '\u{00AD}' | '\u{2060}' | '\u{200A}' | '\u{200B}' | '\u{200C}' | '\u{200D}' | '\u{20E2}'
    )
}

fn is_newline_gap_char(ch: char) -> bool {
    matches!(
        ch,
        '\u{00AD}' | '\u{2060}' | '\u{200D}' | '\u{200C}' | '\u{200B}'
    ) || is_ecmascript_whitespace(ch)
}

fn find_excess_newlines(text: &str) -> Option<(usize, usize)> {
    let chars: Vec<(usize, char)> = text.char_indices().collect();
    let mut i = 0;
    while i < chars.len() {
        let (start_byte, ch) = chars[i];
        if ch != '\r' && ch != '\n' {
            i += 1;
            continue;
        }
        let mut pos = i + 1;
        let mut breaks = 0usize;
        while pos < chars.len() {
            let mut scan = pos;
            while scan < chars.len()
                && chars[scan].1 != '\r'
                && chars[scan].1 != '\n'
                && is_newline_gap_char(chars[scan].1)
            {
                scan += 1;
            }
            if scan < chars.len() && (chars[scan].1 == '\r' || chars[scan].1 == '\n') {
                breaks += 1;
                pos = scan + 1;
            } else {
                break;
            }
        }
        if breaks >= 2 {
            let end_byte = if pos < chars.len() {
                chars[pos].0
            } else {
                text.len()
            };
            return Some((start_byte, end_byte));
        }
        i += 1;
    }
    None
}

fn detect_all(text: &str) -> Vec<RichTextDetection> {
    if text.is_empty() {
        return Vec::new();
    }
    let chars: Vec<(usize, char)> = text.char_indices().collect();
    let mut out = Vec::new();
    detect_mentions(text, &chars, &mut out);
    detect_urls(text, &chars, &mut out);
    detect_tags(text, &chars, &mut out);
    detect_cashtags(text, &chars, &mut out);
    out
}

fn has_valid_prefix(chars: &[(usize, char)], idx: usize, allow_open_paren: bool) -> bool {
    if idx == 0 {
        return true;
    }
    let prev = chars[idx - 1].1;
    is_ecmascript_whitespace(prev) || (allow_open_paren && prev == '(')
}

fn byte_end_of(text: &str, chars: &[(usize, char)], char_idx: usize) -> usize {
    if char_idx < chars.len() {
        chars[char_idx].0
    } else {
        text.len()
    }
}

fn detect_mentions(text: &str, chars: &[(usize, char)], out: &mut Vec<RichTextDetection>) {
    let mut i = 0;
    while i < chars.len() {
        if chars[i].1 != '@' || !has_valid_prefix(chars, i, true) {
            i += 1;
            continue;
        }
        let handle_start = i + 1;
        let mut max_end = handle_start;
        while max_end < chars.len() && is_handle_char(chars[max_end].1) {
            max_end += 1;
        }
        if max_end == handle_start {
            i += 1;
            continue;
        }
        let mut matched_end = None;
        for end in (handle_start + 1..=max_end).rev() {
            let prev_word = is_ascii_word(chars[end - 1].1);
            let next_word = end < chars.len() && is_ascii_word(chars[end].1);
            if prev_word != next_word {
                matched_end = Some(end);
                break;
            }
        }
        if let Some(end) = matched_end {
            let start_byte = chars[handle_start].0;
            let end_byte = byte_end_of(text, chars, end);
            let handle = &text[start_byte..end_byte];
            if is_valid_domain(handle)
                || std::path::Path::new(handle)
                    .extension()
                    .is_some_and(|ext| ext.eq_ignore_ascii_case("test"))
            {
                out.push(RichTextDetection::new(
                    chars[i].0,
                    end_byte,
                    RichTextDetectionKind::Mention {
                        handle: handle.to_owned(),
                    },
                ));
            }
            i = end;
        } else {
            i += 1;
        }
    }
}

fn detect_urls(text: &str, chars: &[(usize, char)], out: &mut Vec<RichTextDetection>) {
    let mut i = 0;
    while i < chars.len() {
        if !has_valid_prefix(chars, i, true) {
            i += 1;
            continue;
        }
        let start_byte = chars[i].0;
        let rest = &text[start_byte..];
        // Branch 1: case-insensitive `http://` or `https://` followed by 1+ non-ws chars.
        let mut matched_scheme_len = None;
        if rest.is_char_boundary(7) && rest[..7].eq_ignore_ascii_case("http://") {
            matched_scheme_len = Some(7);
        } else if rest.is_char_boundary(8) && rest[..8].eq_ignore_ascii_case("https://") {
            matched_scheme_len = Some(8);
        }

        let (link_end_char, domain_opt): (usize, Option<String>) =
            if let Some(scheme_bytes) = matched_scheme_len {
                let mut end = i;
                while end < chars.len() && !is_ecmascript_whitespace(chars[end].1) {
                    end += 1;
                }
                let end_byte = byte_end_of(text, chars, end);
                if end_byte > start_byte + scheme_bytes {
                    (end, None)
                } else {
                    i += 1;
                    continue;
                }
            } else {
                // Branch 2: `[A-Za-z][A-Za-z0-9]*(\.[A-Za-z0-9]+)+` followed by non-ws*.
                if !chars[i].1.is_ascii_alphabetic() {
                    i += 1;
                    continue;
                }
                let mut pos = i + 1;
                while pos < chars.len() && chars[pos].1.is_ascii_alphanumeric() {
                    pos += 1;
                }
                let mut labels = 0usize;
                loop {
                    if pos < chars.len()
                        && chars[pos].1 == '.'
                        && pos + 1 < chars.len()
                        && chars[pos + 1].1.is_ascii_alphanumeric()
                    {
                        pos += 1;
                        while pos < chars.len() && chars[pos].1.is_ascii_alphanumeric() {
                            pos += 1;
                        }
                        labels += 1;
                    } else {
                        break;
                    }
                }
                if labels == 0 {
                    i += 1;
                    continue;
                }
                let domain_end_byte = byte_end_of(text, chars, pos);
                let domain = text[start_byte..domain_end_byte].to_owned();
                let mut end = pos;
                while end < chars.len() && !is_ecmascript_whitespace(chars[end].1) {
                    end += 1;
                }
                (end, Some(domain))
            };

        let end_byte = byte_end_of(text, chars, link_end_char);
        let mut uri = text[start_byte..end_byte].to_owned();
        if !uri.starts_with("http://") && !uri.starts_with("https://") {
            let Some(domain) = domain_opt else {
                i = link_end_char;
                continue;
            };
            if !is_valid_domain(&domain) {
                i += 1;
                continue;
            }
            uri = format!("https://{uri}");
        }

        let mut trimmed_end_byte = end_byte;
        if let Some(last) = uri.chars().last()
            && matches!(last, '.' | ',' | ';' | ':' | '!' | '?')
        {
            uri.pop();
            trimmed_end_byte -= 1;
        }
        if uri.ends_with(')') && !uri.contains('(') {
            uri.pop();
            trimmed_end_byte -= 1;
        }
        out.push(RichTextDetection::new(
            start_byte,
            trimmed_end_byte,
            RichTextDetectionKind::Link { uri },
        ));
        i = link_end_char;
    }
}

fn detect_tags(text: &str, chars: &[(usize, char)], out: &mut Vec<RichTextDetection>) {
    let mut i = 0;
    while i < chars.len() {
        let ch = chars[i].1;
        if (ch != '#' && ch != '＃') || !has_valid_prefix(chars, i, false) {
            i += 1;
            continue;
        }
        let body_start = i + 1;
        if body_start >= chars.len() || chars[body_start].1 == '\u{FE0F}' {
            i += 1;
            continue;
        }
        let mut end = body_start;
        let mut has_non_digit_non_punct = false;
        while end < chars.len() {
            let c = chars[end].1;
            if is_ecmascript_whitespace(c) || is_tag_excluded(c) {
                break;
            }
            if !c.is_ascii_digit() && !is_unicode_punctuation(c) {
                has_non_digit_non_punct = true;
            }
            end += 1;
        }
        if end == body_start || !has_non_digit_non_punct {
            i += 1;
            continue;
        }
        let raw_start_byte = chars[body_start].0;
        let raw_end_byte = byte_end_of(text, chars, end);
        let raw = &text[raw_start_byte..raw_end_byte];
        let trimmed = raw.trim_end_matches(is_unicode_punctuation);
        if !trimmed.is_empty() && count_graphemes(trimmed) <= 64 && trimmed.len() <= 640 {
            let tag_end_byte = raw_start_byte + trimmed.len();
            out.push(RichTextDetection::new(
                chars[i].0,
                tag_end_byte,
                RichTextDetectionKind::Tag(trimmed.to_owned()),
            ));
        }
        i = end;
    }
}

fn detect_cashtags(text: &str, chars: &[(usize, char)], out: &mut Vec<RichTextDetection>) {
    let mut i = 0;
    while i < chars.len() {
        if chars[i].1 != '$' || !has_valid_prefix(chars, i, true) {
            i += 1;
            continue;
        }
        let ticker_start = i + 1;
        if ticker_start >= chars.len() || !chars[ticker_start].1.is_ascii_alphabetic() {
            i += 1;
            continue;
        }
        let mut end = ticker_start + 1;
        while end < chars.len() && end - ticker_start < 5 && chars[end].1.is_ascii_alphanumeric() {
            end += 1;
        }
        let boundary_ok = end == chars.len()
            || is_ecmascript_whitespace(chars[end].1)
            || matches!(
                chars[end].1,
                '.' | ',' | ';' | ':' | '!' | '?' | ')' | '"' | '\'' | '’'
            );
        if boundary_ok {
            let start_byte = chars[ticker_start].0;
            let end_byte = byte_end_of(text, chars, end);
            let ticker = text[start_byte..end_byte].to_ascii_uppercase();
            out.push(RichTextDetection::new(
                chars[i].0,
                end_byte,
                RichTextDetectionKind::Tag(format!("${ticker}")),
            ));
            i = end;
        } else {
            i += 1;
        }
    }
}
