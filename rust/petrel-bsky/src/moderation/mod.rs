//! Bluesky moderation decision engine.

pub mod behavior;
pub mod decision;
pub mod labels;
pub mod mute_words;
pub mod types;

use std::collections::HashSet;

use petrel_api::generated::app::bsky::actor::defs::{ProfileViewBasic, ViewerState};
use petrel_api::generated::app::bsky::embed::gallery::{
    Gallery, GalleryItems, View as GalleryView, ViewItems as GalleryViewItems,
};
use petrel_api::generated::app::bsky::embed::record::{ViewBlocked, ViewRecord, ViewRecordUnion};
use petrel_api::generated::app::bsky::feed::defs::{GeneratorView, PostView, PostViewEmbed};
use petrel_api::generated::app::bsky::feed::post::{Post, PostEmbed};
use petrel_api::generated::app::bsky::notification::list_notifications::Notification;
use petrel_api::generated::com::atproto::label::defs::Label;
use petrel_core::{Datetime, Did, FromValue, Value};

use crate::label_set::current_datetime;

pub use behavior::{
    LabelTarget, LabelValueDefinitionFlag, ModerationAction, ModerationBehavior, ModerationContext,
};
pub use decision::ModerationDecision;
pub use labels::{
    InterpretedLabelValueDefinition, LabelTargetBehaviors, builtin_label_definitions,
    interpret_label_value_definition, interpret_label_value_definitions,
};
pub use mute_words::{has_muted_word, match_mute_words};
pub use types::{
    LabelCause, LabelPreference, ModerationCause, ModerationCauseKind, ModerationCauseSource,
    ModerationCauseType, ModerationOptions, ModerationPrefs, ModerationPrefsLabeler,
    ModerationSubjectProfile, ModerationSubjectUserList, ModerationUI, MuteWordMatch, known_labels,
};

/// Bluesky moderation engine entry points matching `@atproto/api`.
#[derive(Debug, Clone, Copy, Default)]
pub struct Moderation;

impl Moderation {
    /// Evaluates an account and its profile record against the system clock.
    #[must_use]
    pub fn moderate_profile<S: ModerationSubjectProfile + ?Sized>(
        subject: &S,
        options: &ModerationOptions,
    ) -> ModerationDecision {
        let now = current_datetime();
        Self::moderate_profile_with_time(subject, options, now.as_ref())
    }

    /// Evaluates an account and its profile record against explicit `now`.
    #[must_use]
    pub fn moderate_profile_at<S: ModerationSubjectProfile + ?Sized>(
        subject: &S,
        options: &ModerationOptions,
        now: &Datetime,
    ) -> ModerationDecision {
        Self::moderate_profile_with_time(subject, options, Some(now))
    }

    fn moderate_profile_with_time<S: ModerationSubjectProfile + ?Sized>(
        subject: &S,
        options: &ModerationOptions,
        now: Option<&Datetime>,
    ) -> ModerationDecision {
        ModerationDecision::merge([
            Some(decide_account(subject, options, now)),
            Some(decide_profile(subject, options, now)),
        ])
    }

    /// Evaluates a post, its quoted post (if any, downgraded), and its author.
    #[must_use]
    pub fn moderate_post(
        subject: &PostView,
        options: &ModerationOptions,
        now: &Datetime,
    ) -> ModerationDecision {
        ModerationDecision::merge([
            Some(decide_post_subject(subject, options, now)),
            decide_embed(subject.embed.as_ref(), options, Some(now)).map(|d| d.downgraded()),
            Some(decide_account(&subject.author, options, Some(now))),
            Some(decide_profile(&subject.author, options, Some(now))),
        ])
    }

    /// Evaluates a notification and its author against the system clock.
    #[must_use]
    pub fn moderate_notification(
        subject: &Notification,
        options: &ModerationOptions,
    ) -> ModerationDecision {
        let now = current_datetime();
        Self::moderate_notification_with_time(subject, options, now.as_ref())
    }

    /// Evaluates a notification and its author against explicit `now`.
    #[must_use]
    pub fn moderate_notification_at(
        subject: &Notification,
        options: &ModerationOptions,
        now: &Datetime,
    ) -> ModerationDecision {
        Self::moderate_notification_with_time(subject, options, Some(now))
    }

    fn moderate_notification_with_time(
        subject: &Notification,
        options: &ModerationOptions,
        now: Option<&Datetime>,
    ) -> ModerationDecision {
        let mut decision = ModerationDecision::new(
            Some(subject.author.did.clone()),
            is_viewer(&subject.author.did, options),
        );
        decision.add_labels_at(
            LabelTarget::Content,
            subject.labels.as_deref().unwrap_or(&[]),
            options,
            now,
        );
        ModerationDecision::merge([
            Some(decision),
            Some(decide_account(&subject.author, options, now)),
            Some(decide_profile(&subject.author, options, now)),
        ])
    }

    /// Evaluates a feed generator and its creator against the system clock.
    #[must_use]
    pub fn moderate_feed_generator(
        subject: &GeneratorView,
        options: &ModerationOptions,
    ) -> ModerationDecision {
        let now = current_datetime();
        Self::moderate_feed_generator_with_time(subject, options, now.as_ref())
    }

    /// Evaluates a feed generator and its creator against explicit `now`.
    #[must_use]
    pub fn moderate_feed_generator_at(
        subject: &GeneratorView,
        options: &ModerationOptions,
        now: &Datetime,
    ) -> ModerationDecision {
        Self::moderate_feed_generator_with_time(subject, options, Some(now))
    }

    fn moderate_feed_generator_with_time(
        subject: &GeneratorView,
        options: &ModerationOptions,
        now: Option<&Datetime>,
    ) -> ModerationDecision {
        let mut decision = ModerationDecision::new(
            Some(subject.creator.did.clone()),
            is_viewer(&subject.creator.did, options),
        );
        decision.add_labels_at(
            LabelTarget::Content,
            subject.labels.as_deref().unwrap_or(&[]),
            options,
            now,
        );
        ModerationDecision::merge([
            Some(decision),
            Some(decide_account(&subject.creator, options, now)),
            Some(decide_profile(&subject.creator, options, now)),
        ])
    }

    /// Evaluates a user list and its creator (or list AT URI authority for `ListViewBasic`).
    #[must_use]
    pub fn moderate_user_list<S: ModerationSubjectUserList + ?Sized>(
        subject: &S,
        options: &ModerationOptions,
    ) -> ModerationDecision {
        let now = current_datetime();
        Self::moderate_user_list_with_time(subject, options, now.as_ref())
    }

    /// Evaluates a user list against explicit `now`.
    #[must_use]
    pub fn moderate_user_list_at<S: ModerationSubjectUserList + ?Sized>(
        subject: &S,
        options: &ModerationOptions,
        now: &Datetime,
    ) -> ModerationDecision {
        Self::moderate_user_list_with_time(subject, options, Some(now))
    }

    fn moderate_user_list_with_time<S: ModerationSubjectUserList + ?Sized>(
        subject: &S,
        options: &ModerationOptions,
        now: Option<&Datetime>,
    ) -> ModerationDecision {
        if let Some(creator) = subject.moderation_creator() {
            let mut decision = ModerationDecision::new(
                Some(creator.did.clone()),
                is_viewer(&creator.did, options),
            );
            decision.add_labels_at(
                LabelTarget::Content,
                subject.labels().unwrap_or(&[]),
                options,
                now,
            );
            return ModerationDecision::merge([
                Some(decision),
                Some(decide_account(creator, options, now)),
                Some(decide_profile(creator, options, now)),
            ]);
        }

        let creator_did = subject.uri().authority().as_str().parse::<Did>().ok();
        let is_me = creator_did
            .as_ref()
            .is_some_and(|did| is_viewer(did, options));
        let mut decision = ModerationDecision::new(creator_did, is_me);
        decision.add_labels_at(
            LabelTarget::Content,
            subject.labels().unwrap_or(&[]),
            options,
            now,
        );
        decision
    }

    /// Evaluates an account's status record together with the account itself.
    #[must_use]
    pub fn moderate_status<S: ModerationSubjectProfile + ?Sized>(
        subject: &S,
        options: &ModerationOptions,
    ) -> ModerationDecision {
        let now = current_datetime();
        Self::moderate_status_with_time(subject, options, now.as_ref())
    }

    /// Evaluates an account's status record together with the account itself against explicit `now`.
    #[must_use]
    pub fn moderate_status_at<S: ModerationSubjectProfile + ?Sized>(
        subject: &S,
        options: &ModerationOptions,
        now: &Datetime,
    ) -> ModerationDecision {
        Self::moderate_status_with_time(subject, options, Some(now))
    }

    fn moderate_status_with_time<S: ModerationSubjectProfile + ?Sized>(
        subject: &S,
        options: &ModerationOptions,
        now: Option<&Datetime>,
    ) -> ModerationDecision {
        let mut decision = ModerationDecision::new(
            Some(subject.did().clone()),
            is_viewer(subject.did(), options),
        );
        if let Some(status) = subject.moderation_status() {
            decision.add_labels_at(
                LabelTarget::Content,
                status.labels.as_deref().unwrap_or(&[]),
                options,
                now,
            );
        }
        ModerationDecision::merge([
            Some(decision),
            Some(decide_account(subject, options, now)),
            Some(decide_profile(subject, options, now)),
        ])
    }
}

fn is_viewer(did: &Did, options: &ModerationOptions) -> bool {
    options.user_did.as_ref().is_some_and(|me| me == did)
}

fn is_profile_record_label(label: &Label) -> bool {
    label.uri.as_str().ends_with("/app.bsky.actor.profile/self")
}

fn decide_account<S: ModerationSubjectProfile + ?Sized>(
    subject: &S,
    options: &ModerationOptions,
    now: Option<&Datetime>,
) -> ModerationDecision {
    let mut decision = ModerationDecision::new(
        Some(subject.did().clone()),
        is_viewer(subject.did(), options),
    );
    add_viewer_state(subject.viewer(), &mut decision);

    let account_labels: Vec<Label> = subject
        .labels()
        .unwrap_or(&[])
        .iter()
        .filter(|label| !is_profile_record_label(label) || label.val == "!no-unauthenticated")
        .cloned()
        .collect();
    decision.add_labels_at(LabelTarget::Account, &account_labels, options, now);
    decision
}

fn decide_profile<S: ModerationSubjectProfile + ?Sized>(
    subject: &S,
    options: &ModerationOptions,
    now: Option<&Datetime>,
) -> ModerationDecision {
    let mut decision = ModerationDecision::new(
        Some(subject.did().clone()),
        is_viewer(subject.did(), options),
    );
    let profile_labels: Vec<Label> = subject
        .labels()
        .unwrap_or(&[])
        .iter()
        .filter(|label| is_profile_record_label(label))
        .cloned()
        .collect();
    decision.add_labels_at(LabelTarget::Profile, &profile_labels, options, now);
    decision
}

fn add_viewer_state(viewer: Option<&ViewerState>, decision: &mut ModerationDecision) {
    let Some(viewer) = viewer else { return };
    if viewer.muted == Some(true) {
        if let Some(list) = &viewer.muted_by_list {
            decision.add_muted_by_list(Some(list.clone()));
        } else {
            decision.add_muted(true);
        }
    }
    if viewer.blocking.is_some() {
        if let Some(list) = &viewer.blocking_by_list {
            decision.add_blocking_by_list(Some(list.clone()));
        } else {
            decision.add_blocking(true);
        }
    }
    decision.add_blocked_by(viewer.blocked_by == Some(true));
}

fn decide_post_subject(
    subject: &PostView,
    options: &ModerationOptions,
    now: &Datetime,
) -> ModerationDecision {
    let mut decision = ModerationDecision::new(
        Some(subject.author.did.clone()),
        is_viewer(&subject.author.did, options),
    );
    decision.add_labels_at(
        LabelTarget::Content,
        subject.labels.as_deref().unwrap_or(&[]),
        options,
        Some(now),
    );
    decision.add_hidden(is_hidden(subject, &options.prefs.hidden_posts));
    if !decision.is_me {
        decision.add_muted_word(match_all_mute_words(
            subject,
            &options.prefs.muted_words,
            now,
        ));
    }
    decision
}

fn quoted_record(embed: Option<&PostViewEmbed>) -> Option<&ViewRecordUnion> {
    match embed {
        Some(PostViewEmbed::RecordView(view)) => Some(&view.record),
        Some(PostViewEmbed::RecordWithMediaView(view)) => Some(&view.record.record),
        _ => None,
    }
}

fn decide_embed(
    embed: Option<&PostViewEmbed>,
    options: &ModerationOptions,
    now: Option<&Datetime>,
) -> Option<ModerationDecision> {
    match quoted_record(embed) {
        Some(ViewRecordUnion::ViewRecord(record)) => Some(decide_quoted_post(record, options, now)),
        Some(ViewRecordUnion::ViewBlocked(blocked)) => {
            Some(decide_blocked_quoted_post(blocked, options))
        }
        _ => None,
    }
}

fn decide_quoted_post(
    subject: &ViewRecord,
    options: &ModerationOptions,
    now: Option<&Datetime>,
) -> ModerationDecision {
    let mut decision = ModerationDecision::new(
        Some(subject.author.did.clone()),
        is_viewer(&subject.author.did, options),
    );
    decision.add_labels_at(
        LabelTarget::Content,
        subject.labels.as_deref().unwrap_or(&[]),
        options,
        now,
    );
    ModerationDecision::merge([
        Some(decision),
        Some(decide_account(&subject.author, options, now)),
        Some(decide_profile(&subject.author, options, now)),
    ])
}

fn decide_blocked_quoted_post(
    subject: &ViewBlocked,
    options: &ModerationOptions,
) -> ModerationDecision {
    let mut decision = ModerationDecision::new(
        Some(subject.author.did.clone()),
        is_viewer(&subject.author.did, options),
    );
    add_viewer_state(subject.author.viewer.as_ref(), &mut decision);
    decision
}

fn is_hidden(subject: &PostView, hidden_posts: &[petrel_core::AtUri]) -> bool {
    if hidden_posts.is_empty() {
        return false;
    }
    let hidden: HashSet<&str> = hidden_posts
        .iter()
        .map(petrel_core::AtUri::as_str)
        .collect();
    if hidden.contains(subject.uri.as_str()) {
        return true;
    }
    if let Some(ViewRecordUnion::ViewRecord(record)) = quoted_record(subject.embed.as_ref()) {
        return hidden.contains(record.uri.as_str());
    }
    false
}

fn decode_post_record(container: &Value) -> Option<Post> {
    Post::from_value(container.clone()).ok()
}

fn language_tags(post: Option<&Post>) -> Vec<String> {
    post.and_then(|p| p.langs.as_ref())
        .map(|langs| langs.iter().map(|l| l.as_str().to_owned()).collect())
        .unwrap_or_default()
}

fn link_card_text(title: &str, description: &str) -> String {
    format!("{title} {description}")
}

fn match_all_mute_words(
    subject: &PostView,
    muted_words: &[petrel_api::generated::app::bsky::actor::defs::MutedWord],
    now: &Datetime,
) -> Vec<MuteWordMatch> {
    if muted_words.is_empty() {
        return Vec::new();
    }

    let post_author = &subject.author;
    let post = decode_post_record(&subject.record);

    if let Some(post) = &post {
        let languages = language_tags(Some(post));
        let matches = match_mute_words(
            muted_words,
            &post.text,
            post.facets.as_deref(),
            post.tags.as_deref(),
            Some(&languages),
            Some(post_author),
            now,
        );
        if !matches.is_empty() {
            return matches;
        }

        let alts: Vec<String> = match post.embed.as_ref() {
            Some(PostEmbed::Images(images)) => {
                images.images.iter().map(|img| img.alt.clone()).collect()
            }
            Some(PostEmbed::Gallery(gallery)) => gallery_alts(gallery),
            _ => Vec::new(),
        };
        let alt_matches = first_alt_mute_match(muted_words, &alts, &languages, post_author, now);
        if !alt_matches.is_empty() {
            return alt_matches;
        }
    }

    match_embed_mute_words(subject, post.as_ref(), muted_words, now)
}

fn first_alt_mute_match(
    muted_words: &[petrel_api::generated::app::bsky::actor::defs::MutedWord],
    alts: &[String],
    languages: &[String],
    actor: &ProfileViewBasic,
    now: &Datetime,
) -> Vec<MuteWordMatch> {
    for alt in alts {
        let matches = match_mute_words(
            muted_words,
            alt,
            None,
            None,
            Some(languages),
            Some(actor),
            now,
        );
        if !matches.is_empty() {
            return matches;
        }
    }
    Vec::new()
}

fn match_embed_mute_words(
    subject: &PostView,
    post: Option<&petrel_api::generated::app::bsky::feed::post::Post>,
    muted_words: &[petrel_api::generated::app::bsky::actor::defs::MutedWord],
    now: &Datetime,
) -> Vec<MuteWordMatch> {
    let post_author = &subject.author;
    match subject.embed.as_ref() {
        Some(PostViewEmbed::RecordView(view)) => {
            if let ViewRecordUnion::ViewRecord(record) = &view.record
                && let Some(embedded_post) = decode_post_record(&record.value)
            {
                return match_quoted_post(&embedded_post, &record.author, muted_words, now);
            }
            Vec::new()
        }
        Some(PostViewEmbed::ExternalView(view)) => match_mute_words(
            muted_words,
            &link_card_text(&view.external.title, &view.external.description),
            None,
            None,
            Some(&[]),
            Some(post_author),
            now,
        ),
        Some(PostViewEmbed::RecordWithMediaView(view)) => {
            if let ViewRecordUnion::ViewRecord(record) = &view.record.record
                && let Some(quoted) = decode_post_record(&record.value)
            {
                let matches = match_quoted_post(&quoted, &record.author, muted_words, now);
                if !matches.is_empty() {
                    return matches;
                }
            }

            let languages = language_tags(post);
            match &view.media {
                petrel_api::generated::app::bsky::embed::record_with_media::ViewMedia::ImagesView(images) => {
                    let alts: Vec<String> = images.images.iter().map(|img| img.alt.clone()).collect();
                    first_alt_mute_match(muted_words, &alts, &languages, post_author, now)
                }
                petrel_api::generated::app::bsky::embed::record_with_media::ViewMedia::GalleryView(gallery) => {
                    let alts = gallery_view_alts(gallery);
                    first_alt_mute_match(muted_words, &alts, &languages, post_author, now)
                }
                petrel_api::generated::app::bsky::embed::record_with_media::ViewMedia::ExternalView(external) => {
                    match_mute_words(
                        muted_words,
                        &link_card_text(&external.external.title, &external.external.description),
                        None,
                        None,
                        Some(&[]),
                        Some(post_author),
                        now,
                    )
                }
                _ => Vec::new(),
            }
        }
        _ => Vec::new(),
    }
}

fn match_quoted_post(
    embedded_post: &Post,
    embed_author: &ProfileViewBasic,
    muted_words: &[petrel_api::generated::app::bsky::actor::defs::MutedWord],
    now: &Datetime,
) -> Vec<MuteWordMatch> {
    let languages = language_tags(Some(embedded_post));
    let matches = match_mute_words(
        muted_words,
        &embedded_post.text,
        embedded_post.facets.as_deref(),
        embedded_post.tags.as_deref(),
        Some(&languages),
        Some(embed_author),
        now,
    );
    if !matches.is_empty() {
        return matches;
    }

    let first_match = |alts: &[String], langs: &[String]| {
        for alt in alts {
            let m = match_mute_words(
                muted_words,
                alt,
                None,
                None,
                Some(langs),
                Some(embed_author),
                now,
            );
            if !m.is_empty() {
                return m;
            }
        }
        Vec::new()
    };

    match embedded_post.embed.as_ref() {
        Some(PostEmbed::Images(images)) => {
            let alts: Vec<String> = images.images.iter().map(|img| img.alt.clone()).collect();
            first_match(&alts, &languages)
        }
        Some(PostEmbed::Gallery(gallery)) => first_match(&gallery_alts(gallery), &languages),
        Some(PostEmbed::External(external)) => match_mute_words(
            muted_words,
            &link_card_text(&external.external.title, &external.external.description),
            None,
            None,
            Some(&[]),
            Some(embed_author),
            now,
        ),
        Some(PostEmbed::RecordWithMedia(record_with_media)) => {
            match &record_with_media.media {
                petrel_api::generated::app::bsky::embed::record_with_media::RecordWithMediaMedia::External(external) => {
                    match_mute_words(
                        muted_words,
                        &link_card_text(&external.external.title, &external.external.description),
                        None,
                        None,
                        Some(&[]),
                        Some(embed_author),
                        now,
                    )
                }
                petrel_api::generated::app::bsky::embed::record_with_media::RecordWithMediaMedia::Images(images) => {
                    let alts: Vec<String> = images.images.iter().map(|img| img.alt.clone()).collect();
                    first_match(&alts, &[])
                }
                petrel_api::generated::app::bsky::embed::record_with_media::RecordWithMediaMedia::Gallery(gallery) => {
                    first_match(&gallery_alts(gallery), &[])
                }
                _ => Vec::new(),
            }
        }
        _ => Vec::new(),
    }
}

fn gallery_alts(gallery: &Gallery) -> Vec<String> {
    gallery
        .items
        .iter()
        .filter_map(|item| match item {
            GalleryItems::Image(image) => Some(image.alt.clone()),
            GalleryItems::Unknown(_) => None,
        })
        .collect()
}

fn gallery_view_alts(gallery: &GalleryView) -> Vec<String> {
    gallery
        .items
        .iter()
        .filter_map(|item| match item {
            GalleryViewItems::ViewImage(image) => Some(image.alt.clone()),
            GalleryViewItems::Unknown(_) => None,
        })
        .collect()
}
