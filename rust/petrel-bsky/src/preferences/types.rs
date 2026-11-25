//! Parsed Bluesky preference types and update payloads.

use std::collections::BTreeMap;

use petrel_api::generated::app::bsky::actor::defs::{
    DeclaredAgePref, Nux, PostInteractionSettingsPref, SavedFeed, VerificationPrefs,
};
use petrel_core::{AtUri, Datetime, Value};

use crate::moderation::ModerationPrefs;

/// How a feed filters what it shows (`app.bsky.actor.defs#feedViewPref`).
#[allow(clippy::struct_excessive_bools)]
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BskyFeedViewPreference {
    /// Hide all replies.
    pub hide_replies: bool,
    /// Hide replies whose author the user does not follow.
    pub hide_replies_by_unfollowed: bool,
    /// Hide replies with fewer likes than this.
    pub hide_replies_by_like_count: i64,
    /// Hide reposts.
    pub hide_reposts: bool,
    /// Hide quote posts.
    pub hide_quote_posts: bool,
}

impl Default for BskyFeedViewPreference {
    fn default() -> Self {
        Self {
            hide_replies: false,
            hide_replies_by_unfollowed: true,
            hide_replies_by_like_count: 0,
            hide_reposts: false,
            hide_quote_posts: false,
        }
    }
}

/// Partial update to a feed's view preference. Fields left `None` keep their stored values.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct BskyFeedViewPreferenceUpdate {
    /// Hide all replies.
    pub hide_replies: Option<bool>,
    /// Hide replies whose author the user does not follow.
    pub hide_replies_by_unfollowed: Option<bool>,
    /// Hide replies with fewer likes than this.
    pub hide_replies_by_like_count: Option<i64>,
    /// Hide reposts.
    pub hide_reposts: Option<bool>,
    /// Hide quote posts.
    pub hide_quote_posts: Option<bool>,
}

/// Thread display preferences (`app.bsky.actor.defs#threadViewPref`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BskyThreadViewPreference {
    /// Reply sort order (`oldest`, `newest`, `most-likes`, `random`, `hotness`).
    pub sort: String,
}

impl Default for BskyThreadViewPreference {
    fn default() -> Self {
        Self {
            sort: "hotness".to_owned(),
        }
    }
}

/// Onboarding interests (`app.bsky.actor.defs#interestsPref`).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct BskyInterestsPreference {
    /// Interest tags.
    pub tags: Vec<String>,
}

/// Onboarding progress guide (`app.bsky.actor.defs#bskyAppProgressGuide`).
#[derive(Debug, Clone, Default, PartialEq)]
pub struct BskyAppProgressGuide {
    /// Guide identifier.
    pub guide: String,
    /// Arbitrary fields stored alongside `guide`.
    pub additional_fields: BTreeMap<String, Value>,
}

/// State kept by the official app (`app.bsky.actor.defs#bskyAppStatePref`).
#[derive(Debug, Clone, Default, PartialEq)]
pub struct BskyAppState {
    /// Nudges waiting to be shown.
    pub queued_nudges: Vec<String>,
    /// Onboarding guide currently in progress.
    pub active_progress_guide: Option<BskyAppProgressGuide>,
    /// New-user-experience items.
    pub nuxs: Vec<Nux>,
    /// Whether the user joined the beta program.
    pub is_beta_user: Option<bool>,
}

/// Live-event feed hiding preferences (`app.bsky.actor.defs#liveEventPreferences`).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct BskyLiveEventPreferences {
    /// Identifiers of hidden live-event feeds.
    pub hidden_feed_ids: Vec<String>,
    /// Whether every live-event feed is hidden.
    pub hide_all_feeds: bool,
}

/// Mutation to apply to live-event preferences.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BskyLiveEventPreferencesAction {
    /// Hide one live-event feed.
    HideFeed(String),
    /// Unhide one live-event feed.
    UnhideFeed(String),
    /// Flip `hideAllFeeds`.
    ToggleHideAllFeeds,
}

/// A new saved feed prior to ID assignment.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BskyNewSavedFeed {
    /// `"feed"`, `"list"`, or `"timeline"`.
    pub r#type: String,
    /// AT URI for `feed`/`list`, or `"following"` for `timeline`.
    pub value: String,
    /// Whether the feed is pinned.
    pub pinned: bool,
}

impl BskyNewSavedFeed {
    /// Creates a new saved feed entry.
    #[must_use]
    pub fn new(r#type: impl Into<String>, value: impl Into<String>, pinned: bool) -> Self {
        Self {
            r#type: r#type.into(),
            value: value.into(),
            pinned,
        }
    }

    /// Creates a feed-generator saved feed entry.
    #[must_use]
    pub fn feed(uri: &AtUri, pinned: bool) -> Self {
        Self::new("feed", uri.as_str(), pinned)
    }

    /// Creates a list saved feed entry.
    #[must_use]
    pub fn list(uri: &AtUri, pinned: bool) -> Self {
        Self::new("list", uri.as_str(), pinned)
    }

    /// Creates a built-in timeline saved feed entry (`"following"`).
    #[must_use]
    pub fn timeline(name: &str, pinned: bool) -> Self {
        Self::new("timeline", name, pinned)
    }
}

/// First-generation saved feeds entry (`savedFeedsPref`).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct BskyLegacyFeeds {
    /// Saved feeds, or `None` when absent.
    pub saved: Option<Vec<AtUri>>,
    /// Pinned feeds, or `None` when absent.
    pub pinned: Option<Vec<AtUri>>,
}

/// Parsed Bluesky account preferences.
#[derive(Debug, Clone, PartialEq)]
pub struct BskyPreferences {
    /// Legacy first-generation saved feeds.
    pub feeds: BskyLegacyFeeds,
    /// Saved and pinned feeds (pinned first).
    pub saved_feeds: Vec<SavedFeed>,
    /// Per-feed view preferences (`"home"` is always present).
    pub feed_view_prefs: BTreeMap<String, BskyFeedViewPreference>,
    /// Thread display preferences.
    pub thread_view_prefs: BskyThreadViewPreference,
    /// Moderation settings ready for [`crate::moderation::Moderation`].
    pub moderation_prefs: ModerationPrefs,
    /// Declared birth date, if any.
    pub birth_date: Option<Datetime>,
    /// Server-derived age flags, if any.
    pub declared_age: Option<DeclaredAgePref>,
    /// Onboarding interests.
    pub interests: BskyInterestsPreference,
    /// Official app UI state.
    pub bsky_app_state: BskyAppState,
    /// Default post interaction restrictions.
    pub post_interaction_settings: PostInteractionSettingsPref,
    /// Verification display preferences.
    pub verification_prefs: VerificationPrefs,
    /// Live-event feed preferences.
    pub live_event_preferences: BskyLiveEventPreferences,
}

impl Default for BskyPreferences {
    fn default() -> Self {
        let mut feed_view_prefs = BTreeMap::new();
        feed_view_prefs.insert("home".to_owned(), BskyFeedViewPreference::default());
        Self {
            feeds: BskyLegacyFeeds::default(),
            saved_feeds: Vec::new(),
            feed_view_prefs,
            thread_view_prefs: BskyThreadViewPreference::default(),
            moderation_prefs: ModerationPrefs::default(),
            birth_date: None,
            declared_age: None,
            interests: BskyInterestsPreference::default(),
            bsky_app_state: BskyAppState::default(),
            post_interaction_settings: PostInteractionSettingsPref {
                threadgate_allow_rules: None,
                postgate_embedding_rules: None,
                extra_data: None,
            },
            verification_prefs: VerificationPrefs {
                hide_badges: Some(false),
                extra_data: None,
            },
            live_event_preferences: BskyLiveEventPreferences::default(),
        }
    }
}
