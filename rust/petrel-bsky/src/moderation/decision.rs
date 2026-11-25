//! Per-subject moderation decisions and UI context resolution.

use petrel_api::generated::app::bsky::graph::defs::ListViewBasic;
use petrel_api::generated::com::atproto::label::defs::Label;
use petrel_core::Did;

use super::behavior::{
    LabelTarget, LabelValueDefinitionFlag, ModerationAction, ModerationBehavior, ModerationContext,
};
use super::labels::builtin_label_definitions;
use super::types::{
    LabelCause, LabelPreference, ModerationCause, ModerationCauseKind, ModerationCauseSource,
    ModerationCauseType, ModerationOptions, ModerationUI, MuteWordMatch,
};

/// The outcome of evaluating a subject against the viewer's moderation settings.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct ModerationDecision {
    /// Account the subject belongs to, when known.
    pub did: Option<Did>,
    /// Whether the subject belongs to the viewer.
    pub is_me: bool,
    /// Causes in the order they were accumulated.
    pub causes: Vec<ModerationCause>,
}

impl ModerationDecision {
    /// Creates a decision.
    #[must_use]
    pub const fn new(did: Option<Did>, is_me: bool) -> Self {
        Self {
            did,
            is_me,
            causes: Vec::new(),
        }
    }

    /// Combines multiple decisions into one (`did` and `is_me` come from the first `Some`).
    #[must_use]
    pub fn merge<I>(decisions: I) -> Self
    where
        I: IntoIterator<Item = Option<Self>>,
    {
        let mut merged = Self::default();
        let mut has_identity = false;
        for decision in decisions.into_iter().flatten() {
            if !has_identity {
                merged.did = decision.did;
                merged.is_me = decision.is_me;
                has_identity = true;
            }
            merged.causes.extend(decision.causes);
        }
        merged
    }

    /// Marks every cause as coming from embedded content.
    pub fn downgrade(&mut self) {
        for cause in &mut self.causes {
            cause.downgraded = true;
        }
    }

    /// Returns a copy with every cause marked as downgraded.
    #[must_use]
    pub fn downgraded(&self) -> Self {
        let mut copy = self.clone();
        copy.downgrade();
        copy
    }

    /// Returns `true` when any block cause applies.
    #[must_use]
    pub fn blocked(&self) -> bool {
        self.block_cause().is_some()
    }

    /// Returns `true` when any mute cause applies.
    #[must_use]
    pub fn muted(&self) -> bool {
        self.mute_cause().is_some()
    }

    /// Returns the first block cause, if any.
    #[must_use]
    pub fn block_cause(&self) -> Option<&ModerationCause> {
        self.causes.iter().find(|c| c.is_block())
    }

    /// Returns the first mute cause, if any.
    #[must_use]
    pub fn mute_cause(&self) -> Option<&ModerationCause> {
        self.causes
            .iter()
            .find(|c| c.cause_type() == ModerationCauseType::Muted)
    }

    /// Returns every cause originating from a label.
    #[must_use]
    pub fn label_causes(&self) -> Vec<&ModerationCause> {
        self.causes
            .iter()
            .filter(|c| c.cause_type() == ModerationCauseType::Label)
            .collect()
    }

    /// Resolves what to do with the subject in `context`.
    #[must_use]
    pub fn ui(&self, context: ModerationContext) -> ModerationUI {
        let mut ui = ModerationUI::default();
        let is_listing = matches!(
            context,
            ModerationContext::ProfileList | ModerationContext::ContentList
        );

        let mut apply =
            |action: Option<ModerationAction>, cause: &ModerationCause, no_override: bool| {
                match action {
                    Some(ModerationAction::Blur) => {
                        ui.blurs.push(cause.clone());
                        if no_override {
                            ui.no_override = true;
                        }
                    }
                    Some(ModerationAction::Alert) => ui.alerts.push(cause.clone()),
                    Some(ModerationAction::Inform) => ui.informs.push(cause.clone()),
                    None => {}
                }
            };

        for cause in &self.causes {
            match &cause.kind {
                ModerationCauseKind::Blocking
                | ModerationCauseKind::BlockedBy
                | ModerationCauseKind::BlockOther => {
                    if self.is_me {
                        continue;
                    }
                    if is_listing {
                        ui.filters.push(cause.clone());
                    }
                    if !cause.downgraded {
                        apply(ModerationBehavior::BLOCK.action(context), cause, true);
                    }
                }
                ModerationCauseKind::Muted => {
                    if self.is_me {
                        continue;
                    }
                    if is_listing {
                        ui.filters.push(cause.clone());
                    }
                    if !cause.downgraded {
                        apply(ModerationBehavior::MUTE.action(context), cause, false);
                    }
                }
                ModerationCauseKind::MuteWord(_) => {
                    if self.is_me {
                        continue;
                    }
                    if context == ModerationContext::ContentList {
                        ui.filters.push(cause.clone());
                    }
                    if !cause.downgraded {
                        apply(ModerationBehavior::MUTE_WORD.action(context), cause, false);
                    }
                }
                ModerationCauseKind::Hidden => {
                    if is_listing {
                        ui.filters.push(cause.clone());
                    }
                    if !cause.downgraded {
                        apply(ModerationBehavior::HIDE.action(context), cause, false);
                    }
                }
                ModerationCauseKind::Label(label) => {
                    let filters_here = (context == ModerationContext::ProfileList
                        && label.target == LabelTarget::Account)
                        || (context == ModerationContext::ContentList
                            && matches!(label.target, LabelTarget::Account | LabelTarget::Content));
                    if filters_here && label.setting == LabelPreference::Hide && !self.is_me {
                        ui.filters.push(cause.clone());
                    }
                    if !cause.downgraded {
                        apply(
                            label.behavior.action(context),
                            cause,
                            label.no_override && !self.is_me,
                        );
                    }
                }
            }
        }

        sort_by_priority(&mut ui.filters);
        sort_by_priority(&mut ui.blurs);
        ui
    }

    /// Adds a hidden-by-viewer cause when `hidden` is `true`.
    pub fn add_hidden(&mut self, hidden: bool) {
        if hidden {
            self.causes.push(ModerationCause::new(
                ModerationCauseKind::Hidden,
                ModerationCauseSource::User,
                6,
            ));
        }
    }

    /// Adds a muted-word cause when `matches` is non-empty.
    pub fn add_muted_word(&mut self, matches: Vec<MuteWordMatch>) {
        if !matches.is_empty() {
            self.causes.push(ModerationCause::new(
                ModerationCauseKind::MuteWord(matches),
                ModerationCauseSource::User,
                6,
            ));
        }
    }

    /// Adds a viewer-blocks-account cause when `blocking` is `true`.
    pub fn add_blocking(&mut self, blocking: bool) {
        if blocking {
            self.causes.push(ModerationCause::new(
                ModerationCauseKind::Blocking,
                ModerationCauseSource::User,
                3,
            ));
        }
    }

    /// Adds a viewer-blocks-account-via-list cause.
    pub fn add_blocking_by_list(&mut self, list: Option<ListViewBasic>) {
        if let Some(list) = list {
            self.causes.push(ModerationCause::new(
                ModerationCauseKind::Blocking,
                ModerationCauseSource::List(Box::new(list)),
                3,
            ));
        }
    }

    /// Adds an account-blocks-viewer cause when `blocked_by` is `true`.
    pub fn add_blocked_by(&mut self, blocked_by: bool) {
        if blocked_by {
            self.causes.push(ModerationCause::new(
                ModerationCauseKind::BlockedBy,
                ModerationCauseSource::User,
                4,
            ));
        }
    }

    /// Adds a block-between-other-accounts cause when `block_other` is `true`.
    pub fn add_block_other(&mut self, block_other: bool) {
        if block_other {
            self.causes.push(ModerationCause::new(
                ModerationCauseKind::BlockOther,
                ModerationCauseSource::User,
                4,
            ));
        }
    }

    /// Adds a viewer-muted-account cause when `muted` is `true`.
    pub fn add_muted(&mut self, muted: bool) {
        if muted {
            self.causes.push(ModerationCause::new(
                ModerationCauseKind::Muted,
                ModerationCauseSource::User,
                6,
            ));
        }
    }

    /// Adds a viewer-muted-account-via-list cause.
    pub fn add_muted_by_list(&mut self, list: Option<ListViewBasic>) {
        if let Some(list) = list {
            self.causes.push(ModerationCause::new(
                ModerationCauseKind::Muted,
                ModerationCauseSource::List(Box::new(list)),
                6,
            ));
        }
    }

    /// Evaluates one label and appends a cause if it applies to the viewer.
    pub fn add_label(&mut self, target: LabelTarget, label: &Label, options: &ModerationOptions) {
        let builtins = builtin_label_definitions();
        let built_in = builtins.get(&label.val).cloned();
        let definition = if is_custom_label_value(&label.val) {
            options
                .label_defs
                .get(&label.src)
                .and_then(|defs| defs.iter().find(|d| d.identifier == label.val).cloned())
                .or(built_in)
        } else {
            built_in
        };
        let Some(label_def) = definition else {
            return;
        };

        let is_self = self.did.as_ref().is_some_and(|did| *did == label.src);
        let labeler = if is_self {
            None
        } else {
            options.prefs.labelers.iter().find(|l| l.did == label.src)
        };
        if !is_self && labeler.is_none() {
            return;
        }
        if is_self && label_def.flags.contains(&LabelValueDefinitionFlag::NoSelf) {
            return;
        }

        let is_adult_gated = label_def.flags.contains(&LabelValueDefinitionFlag::Adult)
            && !options.prefs.adult_content_enabled;

        let mut setting = label_def.default_setting;
        if label_def.configurable {
            if is_adult_gated {
                setting = LabelPreference::Hide;
            } else if let Some(labeler_setting) =
                labeler.and_then(|l| l.labels.get(&label_def.identifier).copied())
            {
                setting = labeler_setting;
            } else if let Some(global_setting) =
                options.prefs.labels.get(&label_def.identifier).copied()
            {
                setting = global_setting;
            }
        }

        if setting == LabelPreference::Ignore {
            return;
        }
        if label_def
            .flags
            .contains(&LabelValueDefinitionFlag::Unauthed)
            && options.user_did.is_some()
        {
            return;
        }

        let behavior = label_def.behaviors.for_target(target);
        let no_override = label_def
            .flags
            .contains(&LabelValueDefinitionFlag::NoOverride)
            || is_adult_gated;

        let priority = if no_override {
            1
        } else if setting == LabelPreference::Hide {
            2
        } else if behavior.profile_view == Some(ModerationAction::Blur)
            || behavior.content_view == Some(ModerationAction::Blur)
        {
            5
        } else if behavior.content_list == Some(ModerationAction::Blur)
            || behavior.content_media == Some(ModerationAction::Blur)
        {
            7
        } else {
            8
        };

        let source = match labeler {
            Some(l) if !is_self => ModerationCauseSource::Labeler(l.did.clone()),
            _ => ModerationCauseSource::User,
        };

        self.causes.push(ModerationCause::new(
            ModerationCauseKind::Label(Box::new(LabelCause {
                label: label.clone(),
                label_def,
                target,
                setting,
                behavior,
                no_override,
            })),
            source,
            priority,
        ));
    }
}

fn sort_by_priority(causes: &mut Vec<ModerationCause>) {
    let mut indexed: Vec<(usize, ModerationCause)> = causes.drain(..).enumerate().collect();
    indexed.sort_by(|(idx_a, a), (idx_b, b)| {
        a.priority.cmp(&b.priority).then_with(|| idx_a.cmp(idx_b))
    });
    *causes = indexed.into_iter().map(|(_, cause)| cause).collect();
}

pub(crate) fn is_custom_label_value(value: &str) -> bool {
    !value.is_empty() && value.bytes().all(|b| b.is_ascii_lowercase() || b == b'-')
}
