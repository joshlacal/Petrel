//! Bluesky preferences parsing, validation, migration, and read-modify-write coordination.

pub mod engine;
pub mod types;
pub mod utilities;

pub use engine::{BskyPreferencesBackend, BskyPreferencesEngine, BskyPreferencesSession};
pub use types::{
    BskyAppProgressGuide, BskyAppState, BskyFeedViewPreference, BskyFeedViewPreferenceUpdate,
    BskyInterestsPreference, BskyLegacyFeeds, BskyLiveEventPreferences,
    BskyLiveEventPreferencesAction, BskyNewSavedFeed, BskyPreferences, BskyThreadViewPreference,
};
pub use utilities::{
    sanitize_muted_word_value, saved_feed_type, saved_feeds_to_uri_arrays, validate_saved_feed,
    validate_saved_feed_fields,
};
