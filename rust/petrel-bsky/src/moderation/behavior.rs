//! UI moderation behaviors, targets, and label enforcement flags.

use serde::{Deserialize, Serialize};

/// What to do to a piece of UI.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ModerationAction {
    /// Cover the content; the user may be able to reveal it.
    Blur,
    /// Show a prominent warning next to the content.
    Alert,
    /// Show a low-key notice next to the content.
    Inform,
}

/// A place in the interface where moderation can apply.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ModerationContext {
    /// A profile shown in a list of profiles (search results, followers).
    ProfileList,
    /// A profile shown on its own screen.
    ProfileView,
    /// An account's avatar, wherever it appears.
    Avatar,
    /// An account's banner image.
    Banner,
    /// An account's display name.
    DisplayName,
    /// A piece of content (post, feed, list) shown in a feed or listing.
    ContentList,
    /// A piece of content opened on its own screen.
    ContentView,
    /// The media (images, video, link card) attached to content.
    ContentMedia,
}

impl ModerationContext {
    /// All contexts in declaration order.
    pub const ALL: [Self; 8] = [
        Self::ProfileList,
        Self::ProfileView,
        Self::Avatar,
        Self::Banner,
        Self::DisplayName,
        Self::ContentList,
        Self::ContentView,
        Self::ContentMedia,
    ];
}

/// Maps UI contexts to moderation actions. Contexts left `None` are untouched.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash)]
pub struct ModerationBehavior {
    /// Action for a profile shown in a list.
    pub profile_list: Option<ModerationAction>,
    /// Action for a profile shown on its own screen.
    pub profile_view: Option<ModerationAction>,
    /// Action for an avatar.
    pub avatar: Option<ModerationAction>,
    /// Action for a banner.
    pub banner: Option<ModerationAction>,
    /// Action for a display name.
    pub display_name: Option<ModerationAction>,
    /// Action for content shown in a listing.
    pub content_list: Option<ModerationAction>,
    /// Action for content opened on its own screen.
    pub content_view: Option<ModerationAction>,
    /// Action for media attached to content.
    pub content_media: Option<ModerationAction>,
}

impl ModerationBehavior {
    /// How a block (in either direction) is presented.
    pub const BLOCK: Self = Self {
        profile_list: Some(ModerationAction::Blur),
        profile_view: Some(ModerationAction::Alert),
        avatar: Some(ModerationAction::Blur),
        banner: Some(ModerationAction::Blur),
        display_name: None,
        content_list: Some(ModerationAction::Blur),
        content_view: Some(ModerationAction::Blur),
        content_media: None,
    };

    /// How a muted account is presented.
    pub const MUTE: Self = Self {
        profile_list: Some(ModerationAction::Inform),
        profile_view: Some(ModerationAction::Alert),
        avatar: None,
        banner: None,
        display_name: None,
        content_list: Some(ModerationAction::Blur),
        content_view: Some(ModerationAction::Inform),
        content_media: None,
    };

    /// How content matching a muted word is presented.
    pub const MUTE_WORD: Self = Self {
        profile_list: None,
        profile_view: None,
        avatar: None,
        banner: None,
        display_name: None,
        content_list: Some(ModerationAction::Blur),
        content_view: Some(ModerationAction::Blur),
        content_media: None,
    };

    /// How a post the user hid is presented.
    pub const HIDE: Self = Self {
        profile_list: None,
        profile_view: None,
        avatar: None,
        banner: None,
        display_name: None,
        content_list: Some(ModerationAction::Blur),
        content_view: Some(ModerationAction::Blur),
        content_media: None,
    };

    /// A behavior that does nothing.
    pub const NOOP: Self = Self {
        profile_list: None,
        profile_view: None,
        avatar: None,
        banner: None,
        display_name: None,
        content_list: None,
        content_view: None,
        content_media: None,
    };

    /// Returns the action for `context`, or `None` when unaffected.
    #[must_use]
    pub const fn action(&self, context: ModerationContext) -> Option<ModerationAction> {
        match context {
            ModerationContext::ProfileList => self.profile_list,
            ModerationContext::ProfileView => self.profile_view,
            ModerationContext::Avatar => self.avatar,
            ModerationContext::Banner => self.banner,
            ModerationContext::DisplayName => self.display_name,
            ModerationContext::ContentList => self.content_list,
            ModerationContext::ContentView => self.content_view,
            ModerationContext::ContentMedia => self.content_media,
        }
    }
}

/// What a label is attached to, which selects which behavior of its definition applies.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum LabelTarget {
    /// Label on the account as a whole (URI is account DID).
    Account,
    /// Label on the account's profile record.
    Profile,
    /// Label on a piece of content: post, feed generator, list, or status.
    Content,
}

/// A property of a label definition that changes how it is enforced.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum LabelValueDefinitionFlag {
    /// The user cannot click through a blur caused by this label.
    #[serde(rename = "no-override")]
    NoOverride,
    /// The label marks adult content; forced to `"hide"` unless adult content is enabled.
    #[serde(rename = "adult")]
    Adult,
    /// The label only applies to signed-out viewers.
    #[serde(rename = "unauthed")]
    Unauthed,
    /// The label is ignored when an account applies it to itself.
    #[serde(rename = "no-self")]
    NoSelf,
}
