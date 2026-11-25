//! Bluesky application helpers for Petrel: `BskyAgent`, `RichText`, `Moderation`,
//! `LabelSet`, `BskyAppURL`, and `BskyPreferences`.

pub mod agent;
pub mod app_url;
pub mod label_set;
pub mod moderation;
pub mod preferences;
pub mod richtext;
pub mod tld;
pub mod unicode;

pub use agent::{
    BSKY_LABELER_DID, BskyAgent, BskyAgentError, BskyCallOptions, PostEmbedBuilder, PostEmbedMedia,
    PostImage, ProfileUpdate, RecordSwap, ServiceProxy, VIDEO_SERVICE_URL,
};
pub use app_url::BskyAppURL;
pub use label_set::{LabelExt, LabelKey, LabelSet, LabelStreamEvent};
pub use moderation::{
    InterpretedLabelValueDefinition, LabelCause, LabelPreference, LabelTarget,
    LabelTargetBehaviors, LabelValueDefinitionFlag, Moderation, ModerationAction,
    ModerationBehavior, ModerationCause, ModerationCauseKind, ModerationCauseSource,
    ModerationCauseType, ModerationContext, ModerationDecision, ModerationOptions, ModerationPrefs,
    ModerationPrefsLabeler, ModerationSubjectProfile, ModerationSubjectUserList, ModerationUI,
    MuteWordMatch, builtin_label_definitions, has_muted_word, interpret_label_value_definition,
    interpret_label_value_definitions, known_labels, match_mute_words,
};
pub use preferences::{
    BskyAppProgressGuide, BskyAppState, BskyFeedViewPreference, BskyFeedViewPreferenceUpdate,
    BskyInterestsPreference, BskyLegacyFeeds, BskyLiveEventPreferences,
    BskyLiveEventPreferencesAction, BskyNewSavedFeed, BskyPreferences, BskyPreferencesBackend,
    BskyPreferencesEngine, BskyPreferencesSession, BskyThreadViewPreference,
    sanitize_muted_word_value, saved_feed_type, saved_feeds_to_uri_arrays, validate_saved_feed,
    validate_saved_feed_fields,
};
pub use richtext::{RichText, RichTextDetection, RichTextDetectionKind, RichTextSegment};
pub use tld::{all_tlds, is_valid_domain};
