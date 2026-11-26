//! Built-in and custom label value definition expansion.

use std::collections::HashMap;

use petrel_api::generated::app::bsky::labeler::defs::LabelerViewDetailed;
use petrel_api::generated::com::atproto::label::defs::{
    LabelValueDefinition, LabelValueDefinitionStrings,
};
use petrel_core::Did;

use super::behavior::{
    LabelTarget, LabelValueDefinitionFlag, ModerationAction, ModerationBehavior,
};
use super::types::LabelPreference;

/// Behaviors of a label definition for each kind of label target.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct LabelTargetBehaviors {
    /// Applied when the label is on an account.
    pub account: ModerationBehavior,
    /// Applied when the label is on a profile record.
    pub profile: ModerationBehavior,
    /// Applied when the label is on a piece of content.
    pub content: ModerationBehavior,
}

impl LabelTargetBehaviors {
    /// Returns the behavior for `target`.
    #[must_use]
    pub const fn for_target(&self, target: LabelTarget) -> ModerationBehavior {
        match target {
            LabelTarget::Account => self.account,
            LabelTarget::Profile => self.profile,
            LabelTarget::Content => self.content,
        }
    }
}

/// A label value definition expanded into the concrete behaviors a client applies.
#[derive(Debug, Clone, PartialEq)]
pub struct InterpretedLabelValueDefinition {
    /// Label value this definition describes (`label.val`).
    pub identifier: String,
    /// Visual severity (`"alert"`, `"inform"`, or `"none"`).
    pub severity: String,
    /// Blur target (`"content"`, `"media"`, or `"none"`).
    pub blurs: String,
    /// Default setting when the user has not chosen one.
    pub default_setting: LabelPreference,
    /// Whether the label requires adult content enabled.
    pub adult_only: bool,
    /// Human-readable localized names and descriptions.
    pub locales: Vec<LabelValueDefinitionStrings>,
    /// Defining labeler DID, or `None` for built-in global definitions.
    pub defined_by: Option<Did>,
    /// Whether the user may change the setting.
    pub configurable: bool,
    /// Enforcement flags.
    pub flags: Vec<LabelValueDefinitionFlag>,
    /// Concrete behaviors per target.
    pub behaviors: LabelTargetBehaviors,
}

/// Returns the built-in label definitions keyed by label value (`!hide`, `!warn`,
/// `!no-unauthenticated`, `porn`, `sexual`, `nudity`, `graphic-media`, `gore`).
#[allow(clippy::too_many_lines)]
#[must_use]
pub fn builtin_label_definitions() -> HashMap<String, InterpretedLabelValueDefinition> {
    let blur_everything = ModerationBehavior {
        profile_list: Some(ModerationAction::Blur),
        profile_view: Some(ModerationAction::Blur),
        avatar: Some(ModerationAction::Blur),
        banner: Some(ModerationAction::Blur),
        display_name: Some(ModerationAction::Blur),
        content_list: Some(ModerationAction::Blur),
        content_view: Some(ModerationAction::Blur),
        content_media: None,
    };
    let blur_profile_identity = ModerationBehavior {
        avatar: Some(ModerationAction::Blur),
        banner: Some(ModerationAction::Blur),
        display_name: Some(ModerationAction::Blur),
        ..ModerationBehavior::NOOP
    };
    let blur_content = ModerationBehavior {
        content_list: Some(ModerationAction::Blur),
        content_view: Some(ModerationAction::Blur),
        ..ModerationBehavior::NOOP
    };
    let blur_profile_media = ModerationBehavior {
        avatar: Some(ModerationAction::Blur),
        banner: Some(ModerationAction::Blur),
        ..ModerationBehavior::NOOP
    };
    let media_behaviors = LabelTargetBehaviors {
        account: blur_profile_media,
        profile: blur_profile_media,
        content: ModerationBehavior {
            content_media: Some(ModerationAction::Blur),
            ..ModerationBehavior::NOOP
        },
    };

    let media = |identifier: &str,
                 default_setting: LabelPreference,
                 flags: Vec<LabelValueDefinitionFlag>|
     -> InterpretedLabelValueDefinition {
        InterpretedLabelValueDefinition {
            identifier: identifier.to_owned(),
            severity: "none".to_owned(),
            blurs: "media".to_owned(),
            default_setting,
            adult_only: false,
            locales: Vec::new(),
            defined_by: None,
            configurable: true,
            flags,
            behaviors: media_behaviors.clone(),
        }
    };

    let defs = [
        InterpretedLabelValueDefinition {
            identifier: "!hide".to_owned(),
            severity: "alert".to_owned(),
            blurs: "content".to_owned(),
            default_setting: LabelPreference::Hide,
            adult_only: false,
            locales: Vec::new(),
            defined_by: None,
            configurable: false,
            flags: vec![
                LabelValueDefinitionFlag::NoOverride,
                LabelValueDefinitionFlag::NoSelf,
            ],
            behaviors: LabelTargetBehaviors {
                account: blur_everything,
                profile: blur_profile_identity,
                content: blur_content,
            },
        },
        InterpretedLabelValueDefinition {
            identifier: "!warn".to_owned(),
            severity: "none".to_owned(),
            blurs: "content".to_owned(),
            default_setting: LabelPreference::Warn,
            adult_only: false,
            locales: Vec::new(),
            defined_by: None,
            configurable: false,
            flags: vec![LabelValueDefinitionFlag::NoSelf],
            behaviors: LabelTargetBehaviors {
                account: ModerationBehavior {
                    profile_list: Some(ModerationAction::Blur),
                    profile_view: Some(ModerationAction::Blur),
                    avatar: Some(ModerationAction::Blur),
                    banner: Some(ModerationAction::Blur),
                    display_name: None,
                    content_list: Some(ModerationAction::Blur),
                    content_view: Some(ModerationAction::Blur),
                    content_media: None,
                },
                profile: blur_profile_identity,
                content: blur_content,
            },
        },
        InterpretedLabelValueDefinition {
            identifier: "!no-unauthenticated".to_owned(),
            severity: "none".to_owned(),
            blurs: "content".to_owned(),
            default_setting: LabelPreference::Hide,
            adult_only: false,
            locales: Vec::new(),
            defined_by: None,
            configurable: false,
            flags: vec![
                LabelValueDefinitionFlag::NoOverride,
                LabelValueDefinitionFlag::Unauthed,
            ],
            behaviors: LabelTargetBehaviors {
                account: blur_everything,
                profile: blur_profile_identity,
                content: blur_content,
            },
        },
        media(
            "porn",
            LabelPreference::Hide,
            vec![LabelValueDefinitionFlag::Adult],
        ),
        media(
            "sexual",
            LabelPreference::Warn,
            vec![LabelValueDefinitionFlag::Adult],
        ),
        media("nudity", LabelPreference::Ignore, Vec::new()),
        media(
            "graphic-media",
            LabelPreference::Warn,
            vec![LabelValueDefinitionFlag::Adult],
        ),
        media(
            "gore",
            LabelPreference::Warn,
            vec![LabelValueDefinitionFlag::Adult],
        ),
    ];

    defs.into_iter()
        .map(|d| (d.identifier.clone(), d))
        .collect()
}

/// Expands a labeler's label value definition into client behaviors.
#[must_use]
pub fn interpret_label_value_definition(
    definition: &LabelValueDefinition,
    defined_by: Option<Did>,
) -> InterpretedLabelValueDefinition {
    let mut behaviors = LabelTargetBehaviors::default();
    let adult_only = definition.adult_only.unwrap_or(false);
    let alert_or_inform = match definition.severity.as_str() {
        "alert" => Some(ModerationAction::Alert),
        "inform" => Some(ModerationAction::Inform),
        _ => None,
    };

    match definition.blurs.as_str() {
        "content" => {
            behaviors.account.profile_list = alert_or_inform;
            behaviors.account.profile_view = alert_or_inform;
            behaviors.account.content_list = Some(ModerationAction::Blur);
            behaviors.account.content_view = if adult_only {
                Some(ModerationAction::Blur)
            } else {
                alert_or_inform
            };
            behaviors.profile.profile_list = alert_or_inform;
            behaviors.profile.profile_view = alert_or_inform;
            behaviors.content.content_list = Some(ModerationAction::Blur);
            behaviors.content.content_view = if adult_only {
                Some(ModerationAction::Blur)
            } else {
                alert_or_inform
            };
        }
        "media" => {
            behaviors.account.profile_list = alert_or_inform;
            behaviors.account.profile_view = alert_or_inform;
            behaviors.account.avatar = Some(ModerationAction::Blur);
            behaviors.account.banner = Some(ModerationAction::Blur);
            behaviors.profile.profile_list = alert_or_inform;
            behaviors.profile.profile_view = alert_or_inform;
            behaviors.profile.avatar = Some(ModerationAction::Blur);
            behaviors.profile.banner = Some(ModerationAction::Blur);
            behaviors.content.content_media = Some(ModerationAction::Blur);
        }
        "none" => {
            behaviors.account.profile_list = alert_or_inform;
            behaviors.account.profile_view = alert_or_inform;
            behaviors.account.content_list = alert_or_inform;
            behaviors.account.content_view = alert_or_inform;
            behaviors.profile.profile_list = alert_or_inform;
            behaviors.profile.profile_view = alert_or_inform;
            behaviors.content.content_list = alert_or_inform;
            behaviors.content.content_view = alert_or_inform;
        }
        _ => {}
    }

    let default_setting = match definition.default_setting.as_deref() {
        Some("hide") => LabelPreference::Hide,
        Some("ignore") => LabelPreference::Ignore,
        _ => LabelPreference::Warn,
    };

    let mut flags = vec![LabelValueDefinitionFlag::NoSelf];
    if adult_only {
        flags.push(LabelValueDefinitionFlag::Adult);
    }

    InterpretedLabelValueDefinition {
        identifier: definition.identifier.clone(),
        severity: definition.severity.clone(),
        blurs: definition.blurs.clone(),
        default_setting,
        adult_only,
        locales: definition.locales.clone(),
        defined_by,
        configurable: true,
        flags,
        behaviors,
    }
}

/// Expands every label value definition a labeler publishes.
#[must_use]
pub fn interpret_label_value_definitions(
    labeler_view: &LabelerViewDetailed,
) -> Vec<InterpretedLabelValueDefinition> {
    labeler_view
        .policies
        .label_value_definitions
        .as_deref()
        .unwrap_or(&[])
        .iter()
        .map(|def| interpret_label_value_definition(def, Some(labeler_view.creator.did.clone())))
        .collect()
}
