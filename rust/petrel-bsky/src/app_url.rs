//! Bidirectional mapping between `at://` URIs and `https://bsky.app/...` URLs.

use std::collections::BTreeSet;

use petrel_core::{AtUri, Did, Handle};
use url::Url;

/// Host of the official Bluesky web client.
pub const DEFAULT_HOST: &str = "bsky.app";

const RECORD_SEGMENTS: &[(&str, &str)] = &[
    ("app.bsky.feed.post", "post"),
    ("app.bsky.feed.generator", "feed"),
    ("app.bsky.graph.list", "lists"),
];

const STARTER_PACK_COLLECTION: &str = "app.bsky.graph.starterpack";

/// Helpers converting between `at://` URIs and Bluesky web URLs.
#[derive(Debug, Clone, Copy, Default)]
pub struct BskyAppURL;

impl BskyAppURL {
    /// Default official web app host (`"bsky.app"`).
    pub const HOST: &'static str = DEFAULT_HOST;

    /// Returns the web URL for an actor's profile (by handle or DID).
    #[must_use]
    pub fn profile_url(actor: &str) -> Option<Url> {
        Self::profile_url_with_host(actor, DEFAULT_HOST)
    }

    /// Returns the web URL for an actor's profile on a custom web host.
    #[must_use]
    pub fn profile_url_with_host(actor: &str, host: &str) -> Option<Url> {
        if actor.parse::<Did>().is_err() && actor.parse::<Handle>().is_err() {
            return None;
        }
        build_url(host, &["profile", actor])
    }

    /// Returns the web URL for an `at://` URI (account, profile, post, feed generator,
    /// list, or starter pack), optionally preferring `handle` over the DID authority.
    #[must_use]
    pub fn url_for(uri: &AtUri, handle: Option<&str>, host: Option<&str>) -> Option<Url> {
        let host = host.unwrap_or(DEFAULT_HOST);
        let actor = if let Some(handle) = handle {
            if handle.parse::<Handle>().is_err() {
                return None;
            }
            handle
        } else {
            uri.authority().as_str()
        };

        let Some(collection) = uri.collection() else {
            return build_url(host, &["profile", actor]);
        };
        let collection_str = collection.as_str();
        if collection_str == "app.bsky.actor.profile" {
            return build_url(host, &["profile", actor]);
        }
        let rkey = uri.rkey()?.as_str();
        if collection_str == STARTER_PACK_COLLECTION {
            return build_url(host, &["starter-pack", actor, rkey]);
        }
        let (_, segment) = RECORD_SEGMENTS
            .iter()
            .find(|&&(col, _)| col == collection_str)?;
        build_url(host, &["profile", actor, segment, rkey])
    }

    /// Parses a Bluesky web URL back into an `at://` URI if it identifies a profile,
    /// post, feed generator, list, or starter pack on one of `hosts` (defaults to `["bsky.app"]`).
    #[must_use]
    pub fn at_uri_from_url(url: &Url, hosts: Option<&BTreeSet<String>>) -> Option<AtUri> {
        if !matches!(url.scheme(), "https" | "http") {
            return None;
        }
        let url_host = url.host_str()?.to_ascii_lowercase();
        let allowed = match hosts {
            Some(set) => set.contains(&url_host),
            None => url_host == DEFAULT_HOST,
        };
        if !allowed {
            return None;
        }

        let segments: Vec<String> = url
            .path()
            .split('/')
            .filter(|part| !part.is_empty())
            .map(decode_path_segment)
            .collect::<Option<Vec<_>>>()?;
        if segments.len() < 2 {
            return None;
        }

        let (actor, collection, rkey): (&str, Option<&str>, Option<&str>) =
            match (segments[0].as_str(), segments.len()) {
                ("profile", 2) => (segments[1].as_str(), None, None),
                ("profile", 4) => {
                    let &(col, _) = RECORD_SEGMENTS
                        .iter()
                        .find(|&&(_, seg)| seg == segments[2].as_str())?;
                    (segments[1].as_str(), Some(col), Some(segments[3].as_str()))
                }
                ("starter-pack" | "start", 3) => (
                    segments[1].as_str(),
                    Some(STARTER_PACK_COLLECTION),
                    Some(segments[2].as_str()),
                ),
                _ => return None,
            };

        if actor.parse::<Did>().is_err() && actor.parse::<Handle>().is_err() {
            return None;
        }

        let uri_str = match (collection, rkey) {
            (Some(collection), Some(rkey)) => format!("at://{actor}/{collection}/{rkey}"),
            _ => format!("at://{actor}"),
        };
        uri_str.parse::<AtUri>().ok()
    }
}

fn build_url(host: &str, segments: &[&str]) -> Option<Url> {
    if host.is_empty() || host.contains(['/', '?', '#', '@']) {
        return None;
    }
    let mut url = Url::parse(&format!("https://{host}")).ok()?;
    if url.path() != "/"
        || url.query().is_some()
        || url.fragment().is_some()
        || !url.username().is_empty()
        || url.password().is_some()
    {
        return None;
    }
    {
        let mut path = url.path_segments_mut().ok()?;
        path.extend(segments);
    }
    Some(url)
}

fn decode_path_segment(raw: &str) -> Option<String> {
    let bytes = raw.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        let byte = bytes[i];
        if byte == b'%' {
            let hi = hex_nibble(*bytes.get(i + 1)?)?;
            let lo = hex_nibble(*bytes.get(i + 2)?)?;
            let decoded = (hi << 4) | lo;
            if decoded == b'/' {
                return None;
            }
            out.push(decoded);
            i += 3;
        } else {
            if byte == b'/' {
                return None;
            }
            out.push(byte);
            i += 1;
        }
    }
    String::from_utf8(out).ok()
}

const fn hex_nibble(byte: u8) -> Option<u8> {
    match byte {
        b'0'..=b'9' => Some(byte - b'0'),
        b'a'..=b'f' => Some(byte - b'a' + 10),
        b'A'..=b'F' => Some(byte - b'A' + 10),
        _ => None,
    }
}
