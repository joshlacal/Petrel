//! Core moderation types, preferences, causes, UI outputs, and subject traits.

use std::collections::HashMap;

use petrel_api::generated::app::bsky::actor::defs::{
    MutedWord, ProfileView, ProfileViewBasic, ProfileViewDetailed, StatusView, ViewerState,
};
use petrel_api::generated::app::bsky::graph::defs::{ListView, ListViewBasic};
use petrel_api::generated::chat::bsky::actor::defs::ProfileViewBasic as ChatProfileViewBasic;
use petrel_api::generated::com::atproto::label::defs::Label;
use petrel_core::{AtUri, Did};
use serde::{Deserialize, Serialize};

use super::behavior::{LabelTarget, ModerationBehavior};
use super::labels::InterpretedLabelValueDefinition;

/// How the user wants content carrying a given label to be treated.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum LabelPreference {
    /// Show the content as if the label were not there.
    Ignore,
    /// Show the content behind a warning.
    Warn,
    /// Remove the content from listings.
    Hide,
}

impl LabelPreference {
    /// Parses a wire string (`"ignore"`, `"warn"`, `"hide"`).
    #[must_use]
    pub fn parse(raw: &str) -> Option<Self> {
        match raw {
            "ignore" => Some(Self::Ignore),
            "warn" => Some(Self::Warn),
            "hide" => Some(Self::Hide),
            _ => None,
        }
    }

    /// Returns the wire string representation.
    #[must_use]
    pub const fn as_str(&self) -> &'static str {
        match self {
            Self::Ignore => "ignore",
            Self::Warn => "warn",
            Self::Hide => "hide",
        }
    }
}

/// A labeler the user subscribes to, with per-label overrides.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModerationPrefsLabeler {
    /// Labeler service DID.
    pub did: Did,
    /// User's settings for this labeler's label values, keyed by label value.
    pub labels: HashMap<String, LabelPreference>,
}

impl ModerationPrefsLabeler {
    /// Creates a labeler preference entry.
    #[must_use]
    pub fn new(did: Did) -> Self {
        Self {
            did,
            labels: HashMap::new(),
        }
    }

    /// Creates a labeler preference entry with custom label overrides.
    #[must_use]
    pub const fn with_labels(did: Did, labels: HashMap<String, LabelPreference>) -> Self {
        Self { did, labels }
    }
}

/// The user's moderation settings, as consumed by the moderation decision engine.
#[derive(Debug, Clone, PartialEq)]
pub struct ModerationPrefs {
    /// Whether the user has opted in to adult content.
    pub adult_content_enabled: bool,
    /// Settings for built-in (global) label values, keyed by label value.
    pub labels: HashMap<String, LabelPreference>,
    /// Labelers whose labels apply. Labels from any other source are ignored.
    pub labelers: Vec<ModerationPrefsLabeler>,
    /// Words and tags the user has muted.
    pub muted_words: Vec<MutedWord>,
    /// Posts the user has hidden.
    pub hidden_posts: Vec<AtUri>,
}

impl Default for ModerationPrefs {
    fn default() -> Self {
        Self {
            adult_content_enabled: false,
            labels: known_labels::default_settings(),
            labelers: Vec::new(),
            muted_words: Vec::new(),
            hidden_posts: Vec::new(),
        }
    }
}

/// Built-in label values and defaults understood without consulting a labeler.
pub mod known_labels {
    use std::collections::HashMap;

    use super::LabelPreference;

    /// Returns the default setting of each user-configurable built-in label.
    #[must_use]
    pub fn default_settings() -> HashMap<String, LabelPreference> {
        HashMap::from([
            ("porn".to_owned(), LabelPreference::Hide),
            ("sexual".to_owned(), LabelPreference::Warn),
            ("nudity".to_owned(), LabelPreference::Ignore),
            ("graphic-media".to_owned(), LabelPreference::Warn),
        ])
    }
}

/// Everything the moderation engine needs to know about the viewer.
#[derive(Debug, Clone, Default)]
pub struct ModerationOptions {
    /// Signed-in viewer DID, or `None` when signed out.
    pub user_did: Option<Did>,
    /// Viewer's moderation settings.
    pub prefs: ModerationPrefs,
    /// Custom label definitions keyed by labeler DID.
    pub label_defs: HashMap<Did, Vec<InterpretedLabelValueDefinition>>,
}

impl ModerationOptions {
    /// Creates moderation options.
    #[must_use]
    pub fn new(user_did: Option<Did>, prefs: ModerationPrefs) -> Self {
        Self {
            user_did,
            prefs,
            label_defs: HashMap::new(),
        }
    }
}

/// Who is responsible for a moderation cause.
#[derive(Debug, Clone, PartialEq)]
pub enum ModerationCauseSource {
    /// Viewer's own action (block, mute, hidden post) or self-label.
    User,
    /// A moderation list the viewer subscribes to.
    List(Box<ListViewBasic>),
    /// A labeler the viewer subscribes to.
    Labeler(Did),
}

/// A muted word that matched some text.
#[derive(Debug, Clone, PartialEq)]
pub struct MuteWordMatch {
    /// The muted word preference that matched.
    pub word: MutedWord,
    /// The matched text predicate.
    pub predicate: String,
}

/// Details of a cause originating from a label.
#[derive(Debug, Clone, PartialEq)]
pub struct LabelCause {
    /// Applied label.
    pub label: Label,
    /// Resolved label value definition.
    pub label_def: InterpretedLabelValueDefinition,
    /// Target the label was attached to.
    pub target: LabelTarget,
    /// Effective setting after applying viewer settings.
    pub setting: LabelPreference,
    /// Behavior of the definition for this target.
    pub behavior: ModerationBehavior,
    /// Whether blurs caused by this label cannot be clicked through.
    pub no_override: bool,
}

/// Kind of moderation cause, with its payload.
#[derive(Debug, Clone, PartialEq)]
pub enum ModerationCauseKind {
    /// Viewer blocks the account.
    Blocking,
    /// Account blocks the viewer.
    BlockedBy,
    /// Subject involves a block between two other accounts.
    BlockOther,
    /// A label applies.
    Label(Box<LabelCause>),
    /// Viewer muted the account.
    Muted,
    /// Content matches one or more muted words.
    MuteWord(Vec<MuteWordMatch>),
    /// Viewer hid the post.
    Hidden,
}

/// Kind of cause without its details, named as in the reference implementation.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ModerationCauseType {
    /// `"blocking"`
    Blocking,
    /// `"blocked-by"`
    BlockedBy,
    /// `"block-other"`
    BlockOther,
    /// `"label"`
    Label,
    /// `"muted"`
    Muted,
    /// `"mute-word"`
    MuteWord,
    /// `"hidden"`
    Hidden,
}

impl ModerationCauseType {
    /// Returns the wire/reference string name.
    #[must_use]
    pub const fn as_str(&self) -> &'static str {
        match self {
            Self::Blocking => "blocking",
            Self::BlockedBy => "blocked-by",
            Self::BlockOther => "block-other",
            Self::Label => "label",
            Self::Muted => "muted",
            Self::MuteWord => "mute-word",
            Self::Hidden => "hidden",
        }
    }
}

/// One reason a subject is moderated.
#[derive(Debug, Clone, PartialEq)]
pub struct ModerationCause {
    /// Kind of cause with payload.
    pub kind: ModerationCauseKind,
    /// Source of the cause.
    pub source: ModerationCauseSource,
    /// Sort order among causes (lower is shown first).
    pub priority: i32,
    /// Whether this cause came from embedded content (a quoted post).
    pub downgraded: bool,
}

impl ModerationCause {
    /// Creates a non-downgraded cause.
    #[must_use]
    pub const fn new(
        kind: ModerationCauseKind,
        source: ModerationCauseSource,
        priority: i32,
    ) -> Self {
        Self {
            kind,
            source,
            priority,
            downgraded: false,
        }
    }

    /// Returns the cause type without its payload.
    #[must_use]
    pub const fn cause_type(&self) -> ModerationCauseType {
        match &self.kind {
            ModerationCauseKind::Blocking => ModerationCauseType::Blocking,
            ModerationCauseKind::BlockedBy => ModerationCauseType::BlockedBy,
            ModerationCauseKind::BlockOther => ModerationCauseType::BlockOther,
            ModerationCauseKind::Label(_) => ModerationCauseType::Label,
            ModerationCauseKind::Muted => ModerationCauseType::Muted,
            ModerationCauseKind::MuteWord(_) => ModerationCauseType::MuteWord,
            ModerationCauseKind::Hidden => ModerationCauseType::Hidden,
        }
    }

    /// Returns label details when this cause is a label.
    #[must_use]
    pub const fn label_cause(&self) -> Option<&LabelCause> {
        if let ModerationCauseKind::Label(cause) = &self.kind {
            Some(cause)
        } else {
            None
        }
    }

    /// Returns matched muted words when this cause is a muted word, otherwise empty slice.
    #[must_use]
    pub fn matches(&self) -> &[MuteWordMatch] {
        if let ModerationCauseKind::MuteWord(matches) = &self.kind {
            matches
        } else {
            &[]
        }
    }

    /// Returns `true` when this cause is any form of block.
    #[must_use]
    pub const fn is_block(&self) -> bool {
        matches!(
            self.kind,
            ModerationCauseKind::Blocking
                | ModerationCauseKind::BlockedBy
                | ModerationCauseKind::BlockOther
        )
    }
}

/// What to do with a subject in one UI context.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct ModerationUI {
    /// Whether the user must not be offered a reveal override on blurred content.
    pub no_override: bool,
    /// Causes for filtering the subject out of a listing.
    pub filters: Vec<ModerationCause>,
    /// Causes for blurring/covering the subject.
    pub blurs: Vec<ModerationCause>,
    /// Causes for displaying a prominent warning.
    pub alerts: Vec<ModerationCause>,
    /// Causes for displaying an informational notice.
    pub informs: Vec<ModerationCause>,
}

impl ModerationUI {
    /// Returns `true` when the subject should be filtered out of the listing.
    #[must_use]
    pub const fn filter(&self) -> bool {
        !self.filters.is_empty()
    }

    /// Returns `true` when the subject should be blurred.
    #[must_use]
    pub const fn blur(&self) -> bool {
        !self.blurs.is_empty()
    }

    /// Returns `true` when a prominent warning should be displayed.
    #[must_use]
    pub const fn alert(&self) -> bool {
        !self.alerts.is_empty()
    }

    /// Returns `true` when an informational notice should be displayed.
    #[must_use]
    pub const fn inform(&self) -> bool {
        !self.informs.is_empty()
    }
}

/// A profile view the moderation engine can evaluate.
pub trait ModerationSubjectProfile {
    /// Account DID.
    fn did(&self) -> &Did;
    /// Viewer relationship state (blocks, mutes).
    fn viewer(&self) -> Option<&ViewerState>;
    /// Labels on the account and its profile record.
    fn labels(&self) -> Option<&[Label]>;
    /// Account status record view, if carried.
    fn moderation_status(&self) -> Option<&StatusView>;
}

impl ModerationSubjectProfile for ProfileViewBasic {
    fn did(&self) -> &Did {
        &self.did
    }
    fn viewer(&self) -> Option<&ViewerState> {
        self.viewer.as_ref()
    }
    fn labels(&self) -> Option<&[Label]> {
        self.labels.as_deref()
    }
    fn moderation_status(&self) -> Option<&StatusView> {
        self.status.as_ref()
    }
}

impl ModerationSubjectProfile for ProfileView {
    fn did(&self) -> &Did {
        &self.did
    }
    fn viewer(&self) -> Option<&ViewerState> {
        self.viewer.as_ref()
    }
    fn labels(&self) -> Option<&[Label]> {
        self.labels.as_deref()
    }
    fn moderation_status(&self) -> Option<&StatusView> {
        self.status.as_ref()
    }
}

impl ModerationSubjectProfile for ProfileViewDetailed {
    fn did(&self) -> &Did {
        &self.did
    }
    fn viewer(&self) -> Option<&ViewerState> {
        self.viewer.as_ref()
    }
    fn labels(&self) -> Option<&[Label]> {
        self.labels.as_deref()
    }
    fn moderation_status(&self) -> Option<&StatusView> {
        self.status.as_ref()
    }
}

impl ModerationSubjectProfile for ChatProfileViewBasic {
    fn did(&self) -> &Did {
        &self.did
    }
    fn viewer(&self) -> Option<&ViewerState> {
        self.viewer.as_ref()
    }
    fn labels(&self) -> Option<&[Label]> {
        self.labels.as_deref()
    }
    fn moderation_status(&self) -> Option<&StatusView> {
        None
    }
}

/// A user list view the moderation engine can evaluate.
pub trait ModerationSubjectUserList {
    /// List AT URI.
    fn uri(&self) -> &AtUri;
    /// Labels on the list.
    fn labels(&self) -> Option<&[Label]>;
    /// List creator profile, when included in the view.
    fn moderation_creator(&self) -> Option<&ProfileView>;
}

impl ModerationSubjectUserList for ListViewBasic {
    fn uri(&self) -> &AtUri {
        &self.uri
    }
    fn labels(&self) -> Option<&[Label]> {
        self.labels.as_deref()
    }
    fn moderation_creator(&self) -> Option<&ProfileView> {
        None
    }
}

impl ModerationSubjectUserList for ListView {
    fn uri(&self) -> &AtUri {
        &self.uri
    }
    fn labels(&self) -> Option<&[Label]> {
        self.labels.as_deref()
    }
    fn moderation_creator(&self) -> Option<&ProfileView> {
        Some(&self.creator)
    }
}
