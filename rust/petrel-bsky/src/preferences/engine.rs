//! Preferences engine: read-modify-write serializer, migration, and raw JSON preference writers.

use std::collections::{BTreeMap, HashSet};
use std::sync::Arc;

use async_lock::Mutex;
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use petrel::xrpc::XrpcLabeler;
use petrel_api::generated::app::bsky::actor::defs::{
    AdultContentPref, BskyAppStatePref, ContentLabelPref, DeclaredAgePref, FeedViewPref,
    HiddenPostsPref, InterestsPref, LabelersPref, LiveEventPreferences, MutedWord, MutedWordTarget,
    MutedWordsPref, PersonalDetailsPref, PostInteractionSettingsPref, SavedFeed, SavedFeedsPref,
    SavedFeedsPrefV2, ThreadViewPref, VerificationPrefs,
};
use petrel_core::{AtUri, Datetime, Did, TidGenerator, Value};
use serde::de::DeserializeOwned;
use serde_json::{Map, Value as JsonValue};

use crate::agent::BskyAgentError;
use crate::moderation::{LabelPreference, ModerationPrefs, ModerationPrefsLabeler, known_labels};

use super::types::{
    BskyAppProgressGuide, BskyFeedViewPreference, BskyFeedViewPreferenceUpdate, BskyLegacyFeeds,
    BskyLiveEventPreferences, BskyLiveEventPreferencesAction, BskyNewSavedFeed, BskyPreferences,
};
use super::utilities::{
    sanitize_muted_word_value, saved_feed_type, saved_feeds_to_uri_arrays, validate_saved_feed,
};

/// Storage backend for raw `preferences` JSON entries.
pub trait BskyPreferencesBackend: MaybeSend + MaybeSync {
    /// Returns the `preferences` array of `app.bsky.actor.getPreferences` untouched.
    fn load_preferences(&self) -> BoxFuture<'_, Result<Vec<JsonValue>, BskyAgentError>>;

    /// Replaces the stored array via `app.bsky.actor.putPreferences`.
    fn save_preferences(
        &self,
        preferences: Vec<JsonValue>,
    ) -> BoxFuture<'_, Result<(), BskyAgentError>>;

    /// Applies the user's labeler subscriptions to subsequent requests.
    fn configure_labelers(&self, labelers: Vec<XrpcLabeler>) -> BoxFuture<'_, ()>;
}

/// Read-modify-write preferences coordinator matching Swift `BskyPreferencesEngine`.
#[derive(Clone)]
pub struct BskyPreferencesEngine {
    backend: Arc<dyn BskyPreferencesBackend>,
    lock: Arc<Mutex<()>>,
    app_labelers: Vec<Did>,
    tid_gen: Arc<TidGenerator>,
}

impl std::fmt::Debug for BskyPreferencesEngine {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("BskyPreferencesEngine")
            .field("app_labelers", &self.app_labelers)
            .finish_non_exhaustive()
    }
}

impl BskyPreferencesEngine {
    /// Creates an engine over `backend` with shared lock and `app_labelers`.
    ///
    /// # Panics
    ///
    /// Panics only if initializing the default [`TidGenerator`] fails (unreachable).
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    #[must_use]
    pub fn new(
        backend: Arc<dyn BskyPreferencesBackend>,
        lock: Arc<Mutex<()>>,
        app_labelers: Vec<Did>,
    ) -> Self {
        Self {
            backend,
            lock,
            app_labelers,
            tid_gen: Arc::new(TidGenerator::new().expect("default TidGenerator")),
        }
    }

    fn next_tid(&self) -> Result<String, BskyAgentError> {
        self.tid_gen
            .next()
            .map(|tid| tid.as_str().to_owned())
            .map_err(|err| BskyAgentError::InvalidInput(format!("failed to generate TID: {err}")))
    }

    /// Reads, transforms, and saves preferences under the lock, returning `(written, result)`.
    pub async fn update_preferences_returning<R, F>(
        &self,
        transform: F,
    ) -> Result<(Vec<JsonValue>, R), BskyAgentError>
    where
        F: FnOnce(Vec<JsonValue>) -> Result<(Vec<JsonValue>, R), BskyAgentError>,
    {
        let _guard = self.lock.lock().await;
        let current = self.backend.load_preferences().await?;
        let (next, result) = transform(current)?;
        self.backend.save_preferences(next.clone()).await?;
        Ok((next, result))
    }

    /// Reads, transforms, and saves preferences under the lock.
    pub async fn update_preferences<F>(
        &self,
        transform: F,
    ) -> Result<Vec<JsonValue>, BskyAgentError>
    where
        F: FnOnce(Vec<JsonValue>) -> Result<Vec<JsonValue>, BskyAgentError>,
    {
        let (written, ()) = self
            .update_preferences_returning(|current| Ok((transform(current)?, ())))
            .await?;
        Ok(written)
    }

    /// Reads, transforms, saves, and applies updated `atproto-accept-labelers` atomically under lock.
    pub async fn update_preferences_applying_labelers<F>(
        &self,
        transform: F,
    ) -> Result<Vec<JsonValue>, BskyAgentError>
    where
        F: FnOnce(Vec<JsonValue>) -> Result<Vec<JsonValue>, BskyAgentError>,
    {
        let _guard = self.lock.lock().await;
        let current = self.backend.load_preferences().await?;
        let next = transform(current)?;
        self.backend.save_preferences(next.clone()).await?;
        self.apply_labelers(&next).await;
        Ok(next)
    }

    /// Extracts labeler DIDs from the last valid `labelersPref`, in stored order.
    #[must_use]
    pub fn labeler_dids(preferences: &[JsonValue]) -> Vec<Did> {
        let Some((_, pref)) =
            last_valid::<LabelersPref>(preferences, LabelersPref::TYPE_IDENTIFIER)
        else {
            return Vec::new();
        };
        pref.labelers.into_iter().map(|item| item.did).collect()
    }

    async fn apply_labelers(&self, preferences: &[JsonValue]) {
        let mut labelers: Vec<XrpcLabeler> = self
            .app_labelers
            .iter()
            .map(|did| XrpcLabeler {
                did: did.as_str().to_owned(),
                redact: true,
            })
            .collect();
        for did in Self::labeler_dids(preferences) {
            labelers.push(XrpcLabeler {
                did: did.as_str().to_owned(),
                redact: false,
            });
        }
        self.backend.configure_labelers(labelers).await;
    }

    /// Fetches, migrates `savedFeedsPrefV2` if absent, applies labelers, and parses preferences.
    pub async fn get_preferences(&self) -> Result<BskyPreferences, BskyAgentError> {
        let raw = {
            let _guard = self.lock.lock().await;
            let raw = self.backend.load_preferences().await?;
            self.apply_labelers(&raw).await;
            raw
        };

        let mut prefs = BskyPreferences {
            moderation_prefs: ModerationPrefs {
                adult_content_enabled: false,
                labels: known_labels::default_settings(),
                labelers: self
                    .app_labelers
                    .iter()
                    .cloned()
                    .map(ModerationPrefsLabeler::new)
                    .collect(),
                muted_words: Vec::new(),
                hidden_posts: Vec::new(),
            },
            ..BskyPreferences::default()
        };

        let mut saved_feeds: Option<Vec<SavedFeed>> = None;
        let mut label_prefs: Vec<ContentLabelPrefEntry> = Vec::new();
        for entry in &raw {
            self.apply_preference_entry(entry, &mut prefs, &mut saved_feeds, &mut label_prefs);
        }

        prefs.saved_feeds = if let Some(feeds) = saved_feeds {
            feeds
        } else {
            self.migrate_saved_feeds_if_needed().await?
        };

        for pref in label_prefs {
            let Some(visibility) = LabelPreference::parse(&pref.visibility) else {
                continue;
            };
            if let Some(labeler_did) = pref.labeler_did {
                if let Some(entry) = prefs
                    .moderation_prefs
                    .labelers
                    .iter_mut()
                    .find(|l| l.did == labeler_did)
                {
                    entry.labels.insert(pref.label, visibility);
                }
            } else {
                prefs.moderation_prefs.labels.insert(pref.label, visibility);
            }
        }
        Self::remap_legacy_labels(&mut prefs.moderation_prefs.labels);

        Ok(prefs)
    }

    fn apply_preference_entry(
        &self,
        entry: &JsonValue,
        prefs: &mut BskyPreferences,
        saved_feeds: &mut Option<Vec<SavedFeed>>,
        label_prefs: &mut Vec<ContentLabelPrefEntry>,
    ) {
        let Some(ty) = json_type(entry) else {
            return;
        };
        match ty {
            AdultContentPref::TYPE_IDENTIFIER => {
                if let Some(value) = decode_valid::<AdultContentPref>(entry, ty) {
                    prefs.moderation_prefs.adult_content_enabled = value.enabled;
                }
            }
            ContentLabelPref::TYPE_IDENTIFIER => {
                if let Some(value) = ContentLabelPrefEntry::parse(entry) {
                    label_prefs.push(value.adjusting_legacy_visibility());
                }
            }
            LabelersPref::TYPE_IDENTIFIER => {
                if let Some(value) = decode_valid::<LabelersPref>(entry, ty) {
                    let mut list: Vec<ModerationPrefsLabeler> = self
                        .app_labelers
                        .iter()
                        .cloned()
                        .map(ModerationPrefsLabeler::new)
                        .collect();
                    list.extend(
                        value
                            .labelers
                            .into_iter()
                            .map(|item| ModerationPrefsLabeler::new(item.did)),
                    );
                    prefs.moderation_prefs.labelers = list;
                }
            }
            SavedFeedsPrefV2::TYPE_IDENTIFIER => {
                if let Some(value) = decode_valid::<SavedFeedsPrefV2>(entry, ty) {
                    *saved_feeds = Some(value.items);
                }
            }
            SavedFeedsPref::TYPE_IDENTIFIER => {
                if let Some(value) = decode_valid::<SavedFeedsPref>(entry, ty) {
                    prefs.feeds.saved = Some(value.saved);
                    prefs.feeds.pinned = Some(value.pinned);
                }
            }
            PersonalDetailsPref::TYPE_IDENTIFIER => {
                if let Some(value) = decode_valid::<PersonalDetailsPref>(entry, ty)
                    && let Some(birth_date) = value.birth_date
                {
                    prefs.birth_date = Some(birth_date);
                }
            }
            DeclaredAgePref::TYPE_IDENTIFIER => {
                if let Some(value) = decode_valid::<DeclaredAgePref>(entry, ty) {
                    prefs.declared_age = Some(value);
                }
            }
            FeedViewPref::TYPE_IDENTIFIER
            | ThreadViewPref::TYPE_IDENTIFIER
            | InterestsPref::TYPE_IDENTIFIER
            | MutedWordsPref::TYPE_IDENTIFIER
            | HiddenPostsPref::TYPE_IDENTIFIER
            | BskyAppStatePref::TYPE_IDENTIFIER
            | PostInteractionSettingsPref::TYPE_IDENTIFIER
            | VerificationPrefs::TYPE_IDENTIFIER
            | LiveEventPreferences::TYPE_IDENTIFIER => {
                Self::apply_app_preference_entry(ty, entry, prefs);
            }
            _ => {}
        }
    }

    fn apply_app_preference_entry(ty: &str, entry: &JsonValue, prefs: &mut BskyPreferences) {
        match ty {
            FeedViewPref::TYPE_IDENTIFIER => {
                if let Some(value) = decode_valid::<FeedViewPref>(entry, ty) {
                    let defaults = BskyFeedViewPreference::default();
                    prefs.feed_view_prefs.insert(
                        value.feed,
                        BskyFeedViewPreference {
                            hide_replies: value.hide_replies.unwrap_or(defaults.hide_replies),
                            hide_replies_by_unfollowed: value
                                .hide_replies_by_unfollowed
                                .unwrap_or(defaults.hide_replies_by_unfollowed),
                            hide_replies_by_like_count: value
                                .hide_replies_by_like_count
                                .unwrap_or(defaults.hide_replies_by_like_count),
                            hide_reposts: value.hide_reposts.unwrap_or(defaults.hide_reposts),
                            hide_quote_posts: value
                                .hide_quote_posts
                                .unwrap_or(defaults.hide_quote_posts),
                        },
                    );
                }
            }
            ThreadViewPref::TYPE_IDENTIFIER => {
                if let Some(value) = decode_valid::<ThreadViewPref>(entry, ty)
                    && let Some(sort) = value.sort
                {
                    prefs.thread_view_prefs.sort = sort;
                }
            }
            InterestsPref::TYPE_IDENTIFIER => {
                if let Some(value) = decode_valid::<InterestsPref>(entry, ty) {
                    prefs.interests.tags = value.tags;
                }
            }
            MutedWordsPref::TYPE_IDENTIFIER => {
                if let Some(value) = decode_valid::<MutedWordsPref>(entry, ty) {
                    prefs.moderation_prefs.muted_words = value
                        .items
                        .into_iter()
                        .map(|word| MutedWord {
                            actor_target: match word.actor_target.as_deref() {
                                None | Some("") => Some("all".to_owned()),
                                Some(_) => word.actor_target,
                            },
                            ..word
                        })
                        .collect();
                }
            }
            HiddenPostsPref::TYPE_IDENTIFIER => {
                if let Some(value) = decode_valid::<HiddenPostsPref>(entry, ty) {
                    prefs.moderation_prefs.hidden_posts = value.items;
                }
            }
            BskyAppStatePref::TYPE_IDENTIFIER => {
                if let Some(value) = decode_valid::<BskyAppStatePref>(entry, ty) {
                    prefs.bsky_app_state.queued_nudges = value.queued_nudges.unwrap_or_default();
                    prefs.bsky_app_state.active_progress_guide =
                        progress_guide_from_json(entry.get("activeProgressGuide"));
                    prefs.bsky_app_state.nuxs = value.nuxs.unwrap_or_default();
                    if let Some(is_beta) = value.is_beta_user {
                        prefs.bsky_app_state.is_beta_user = Some(is_beta);
                    }
                }
            }
            PostInteractionSettingsPref::TYPE_IDENTIFIER => {
                if let Some(value) = decode_valid::<PostInteractionSettingsPref>(entry, ty) {
                    prefs.post_interaction_settings = value;
                }
            }
            VerificationPrefs::TYPE_IDENTIFIER => {
                if let Some(value) = decode_valid::<VerificationPrefs>(entry, ty) {
                    prefs.verification_prefs = VerificationPrefs {
                        hide_badges: value.hide_badges,
                        extra_data: None,
                    };
                }
            }
            LiveEventPreferences::TYPE_IDENTIFIER => {
                if let Some(value) = decode_valid::<LiveEventPreferences>(entry, ty) {
                    prefs.live_event_preferences = BskyLiveEventPreferences {
                        hidden_feed_ids: value.hidden_feed_ids.unwrap_or_default(),
                        hide_all_feeds: value.hide_all_feeds.unwrap_or(false),
                    };
                }
            }
            _ => {}
        }
    }

    fn remap_legacy_labels(labels: &mut std::collections::HashMap<String, LabelPreference>) {
        for (legacy, current) in [
            ("gore", "graphic-media"),
            ("nsfw", "porn"),
            ("suggestive", "sexual"),
        ] {
            if let Some(&val) = labels.get(legacy) {
                labels.insert(current.to_owned(), val);
            }
        }
    }

    fn legacy_for_current(key: &str) -> Option<&'static str> {
        match key {
            "graphic-media" => Some("gore"),
            "porn" => Some("nsfw"),
            "sexual" => Some("suggestive"),
            _ => None,
        }
    }

    // MARK: Saved feeds

    /// Replaces the entire saved feeds list (collapsing duplicate IDs to the last occurrence).
    pub async fn overwrite_saved_feeds(
        &self,
        saved_feeds: &[SavedFeed],
    ) -> Result<Vec<SavedFeed>, BskyAgentError> {
        for feed in saved_feeds {
            validate_saved_feed(feed)?;
        }
        let mut order: Vec<String> = Vec::new();
        let mut by_id: std::collections::HashMap<String, JsonValue> =
            std::collections::HashMap::new();
        for feed in saved_feeds {
            if by_id.contains_key(&feed.id) {
                order.retain(|id| id != &feed.id);
            }
            order.push(feed.id.clone());
            by_id.insert(feed.id.clone(), saved_feed_json(feed));
        }
        let unique: Vec<JsonValue> = order
            .into_iter()
            .filter_map(|id| by_id.remove(&id))
            .collect();
        self.update_saved_feeds_v2(|_| Ok(unique)).await
    }

    /// Updates the `pinned` flag on stored feeds matched by ID.
    pub async fn update_saved_feeds(
        &self,
        saved_feeds_to_update: &[SavedFeed],
    ) -> Result<Vec<SavedFeed>, BskyAgentError> {
        for feed in saved_feeds_to_update {
            validate_saved_feed(feed)?;
        }
        self.update_saved_feeds_v2(|saved_feeds| {
            Ok(saved_feeds
                .into_iter()
                .map(|feed| {
                    let Some(id) = feed.get("id").and_then(JsonValue::as_str) else {
                        return feed;
                    };
                    let Some(updated) = saved_feeds_to_update.iter().find(|f| f.id == id) else {
                        return feed;
                    };
                    setting_field(feed, "pinned", Some(JsonValue::Bool(updated.pinned)))
                })
                .collect())
        })
        .await
    }

    /// Appends newly created saved feeds, assigning each a fresh TID.
    pub async fn add_saved_feeds(
        &self,
        saved_feeds: &[BskyNewSavedFeed],
    ) -> Result<Vec<SavedFeed>, BskyAgentError> {
        let mut to_save = Vec::with_capacity(saved_feeds.len());
        for feed in saved_feeds {
            let id = self.next_tid()?;
            let sf = SavedFeed {
                id,
                r#type: feed.r#type.clone(),
                value: feed.value.clone(),
                pinned: feed.pinned,
                extra_data: None,
            };
            validate_saved_feed(&sf)?;
            to_save.push(sf);
        }
        let added: Vec<JsonValue> = to_save.iter().map(saved_feed_json).collect();
        self.update_saved_feeds_v2(|mut current| {
            current.extend(added);
            Ok(current)
        })
        .await
    }

    /// Removes saved feeds by ID.
    pub async fn remove_saved_feeds(
        &self,
        ids: &[String],
    ) -> Result<Vec<SavedFeed>, BskyAgentError> {
        self.update_saved_feeds_v2(|saved_feeds| {
            Ok(saved_feeds
                .into_iter()
                .filter(|feed| {
                    feed.get("id")
                        .and_then(JsonValue::as_str)
                        .is_none_or(|id| !ids.iter().any(|target| target == id))
                })
                .collect())
        })
        .await
    }

    async fn update_saved_feeds_v2<F>(&self, transform: F) -> Result<Vec<SavedFeed>, BskyAgentError>
    where
        F: FnOnce(Vec<JsonValue>) -> Result<Vec<JsonValue>, BskyAgentError>,
    {
        let (_, items) = self
            .update_preferences_returning(|prefs| Self::rewriting_saved_feeds_v2(prefs, transform))
            .await?;
        decode_saved_feeds(&items)
    }

    fn rewriting_saved_feeds_v2<F>(
        prefs: Vec<JsonValue>,
        transform: F,
    ) -> Result<(Vec<JsonValue>, Vec<JsonValue>), BskyAgentError>
    where
        F: FnOnce(Vec<JsonValue>) -> Result<Vec<JsonValue>, BskyAgentError>,
    {
        let existing_v2 = last_valid::<SavedFeedsPrefV2>(&prefs, SavedFeedsPrefV2::TYPE_IDENTIFIER)
            .map_or_else(
                || {
                    make_preference(
                        SavedFeedsPrefV2::TYPE_IDENTIFIER,
                        [("items", JsonValue::Array(Vec::new()))],
                    )
                },
                |(json, _)| json,
            );

        let current_items = existing_v2
            .get("items")
            .and_then(JsonValue::as_array)
            .cloned()
            .unwrap_or_default();
        let new_saved = transform(current_items)?;

        let mut ordered = Vec::with_capacity(new_saved.len());
        ordered.extend(
            new_saved
                .iter()
                .filter(|item| item.get("pinned").and_then(JsonValue::as_bool) == Some(true))
                .cloned(),
        );
        ordered.extend(
            new_saved
                .iter()
                .filter(|item| item.get("pinned").and_then(JsonValue::as_bool) != Some(true))
                .cloned(),
        );

        let updated_v2 = setting_field(
            existing_v2,
            "items",
            Some(JsonValue::Array(ordered.clone())),
        );
        let mut updated = replacing(prefs, SavedFeedsPrefV2::TYPE_IDENTIFIER, updated_v2);

        if let Some((existing_v1, _)) =
            last_valid::<SavedFeedsPref>(&updated, SavedFeedsPref::TYPE_IDENTIFIER)
        {
            let compatible: Vec<(&str, bool)> = ordered
                .iter()
                .filter_map(|item| {
                    let ty = item.get("type").and_then(JsonValue::as_str)?;
                    if ty != "feed" && ty != "list" {
                        return None;
                    }
                    let val = item.get("value").and_then(JsonValue::as_str)?;
                    let pinned = item.get("pinned").and_then(JsonValue::as_bool) == Some(true);
                    Some((val, pinned))
                })
                .collect();
            let (mirrored_pinned, mirrored_saved) = saved_feeds_to_uri_arrays(&compatible);
            let mut saved_strs = json_strings(existing_v1.get("saved"));
            saved_strs.extend(mirrored_saved);
            let mut pinned_strs = json_strings(existing_v1.get("pinned"));
            pinned_strs.extend(mirrored_pinned);

            let updated_v1 = setting_field(
                setting_field(
                    existing_v1,
                    "saved",
                    Some(JsonValue::Array(
                        unique_strings(saved_strs)
                            .into_iter()
                            .map(JsonValue::String)
                            .collect(),
                    )),
                ),
                "pinned",
                Some(JsonValue::Array(
                    unique_strings(pinned_strs)
                        .into_iter()
                        .map(JsonValue::String)
                        .collect(),
                )),
            );
            updated = replacing(updated, SavedFeedsPref::TYPE_IDENTIFIER, updated_v1);
        }

        Ok((updated, ordered))
    }

    /// Migrates v1 `savedFeedsPref` (or creates a default Following feed) when `savedFeedsPrefV2` is absent.
    pub async fn migrate_saved_feeds_if_needed(&self) -> Result<Vec<SavedFeed>, BskyAgentError> {
        let items = {
            let _guard = self.lock.lock().await;
            let current = self.backend.load_preferences().await?;
            if let Some((existing, _)) =
                last_valid::<SavedFeedsPrefV2>(&current, SavedFeedsPrefV2::TYPE_IDENTIFIER)
            {
                existing
                    .get("items")
                    .and_then(JsonValue::as_array)
                    .cloned()
                    .unwrap_or_default()
            } else {
                let legacy =
                    last_valid::<SavedFeedsPref>(&current, SavedFeedsPref::TYPE_IDENTIFIER)
                        .map(|(_, val)| val);
                let migrated: Vec<JsonValue> = self
                    .migrated_saved_feeds(
                        legacy.as_ref().map(|v| v.saved.as_slice()),
                        legacy.as_ref().map(|v| v.pinned.as_slice()),
                    )?
                    .iter()
                    .map(saved_feed_json)
                    .collect();
                let (next_prefs, result) =
                    Self::rewriting_saved_feeds_v2(current, |_| Ok(migrated))?;
                self.backend.save_preferences(next_prefs).await?;
                result
            }
        };
        decode_saved_feeds(&items)
    }

    fn migrated_saved_feeds(
        &self,
        saved: Option<&[AtUri]>,
        pinned: Option<&[AtUri]>,
    ) -> Result<Vec<SavedFeed>, BskyAgentError> {
        let mut order = vec!["timeline".to_owned()];
        let mut feeds: std::collections::HashMap<String, SavedFeed> =
            std::collections::HashMap::new();
        feeds.insert(
            "timeline".to_owned(),
            SavedFeed {
                id: self.next_tid()?,
                r#type: "timeline".to_owned(),
                value: "following".to_owned(),
                pinned: true,
                extra_data: None,
            },
        );

        if let (Some(saved), Some(pinned)) = (saved, pinned) {
            for uri in pinned.iter().map(AtUri::as_str) {
                let ty = saved_feed_type(uri)?;
                if ty == "unknown" {
                    continue;
                }
                if !feeds.contains_key(uri) {
                    order.push(uri.to_owned());
                }
                feeds.insert(
                    uri.to_owned(),
                    SavedFeed {
                        id: self.next_tid()?,
                        r#type: ty.to_owned(),
                        value: uri.to_owned(),
                        pinned: true,
                        extra_data: None,
                    },
                );
            }
            for uri in saved.iter().map(AtUri::as_str) {
                if feeds.contains_key(uri) {
                    continue;
                }
                let ty = saved_feed_type(uri)?;
                if ty == "unknown" {
                    continue;
                }
                order.push(uri.to_owned());
                feeds.insert(
                    uri.to_owned(),
                    SavedFeed {
                        id: self.next_tid()?,
                        r#type: ty.to_owned(),
                        value: uri.to_owned(),
                        pinned: false,
                        extra_data: None,
                    },
                );
            }
        }

        Ok(order.into_iter().filter_map(|k| feeds.remove(&k)).collect())
    }

    // Legacy v1 feeds

    /// Replaces first-generation saved and pinned feed arrays.
    pub async fn set_saved_feeds(
        &self,
        saved: &[AtUri],
        pinned: &[AtUri],
    ) -> Result<BskyLegacyFeeds, BskyAgentError> {
        let saved_strs: Vec<String> = saved.iter().map(|u| u.as_str().to_owned()).collect();
        let pinned_strs: Vec<String> = pinned.iter().map(|u| u.as_str().to_owned()).collect();
        self.update_legacy_feeds(|_, _| (saved_strs, pinned_strs))
            .await
    }

    /// Saves a feed in the legacy v1 preference.
    pub async fn add_saved_feed(&self, uri: &AtUri) -> Result<BskyLegacyFeeds, BskyAgentError> {
        let value = uri.as_str().to_owned();
        self.update_legacy_feeds(|saved, pinned| {
            let mut next: Vec<String> = saved.into_iter().filter(|u| u != &value).collect();
            next.push(value);
            (next, pinned)
        })
        .await
    }

    /// Removes a feed from both legacy v1 arrays.
    pub async fn remove_saved_feed(&self, uri: &AtUri) -> Result<BskyLegacyFeeds, BskyAgentError> {
        let value = uri.as_str();
        self.update_legacy_feeds(|saved, pinned| {
            (
                saved.into_iter().filter(|u| u != value).collect(),
                pinned.into_iter().filter(|u| u != value).collect(),
            )
        })
        .await
    }

    /// Saves and pins a feed in the legacy v1 entry.
    pub async fn add_pinned_feed(&self, uri: &AtUri) -> Result<BskyLegacyFeeds, BskyAgentError> {
        let value = uri.as_str().to_owned();
        self.update_legacy_feeds(|saved, pinned| {
            let mut next_saved: Vec<String> = saved.into_iter().filter(|u| u != &value).collect();
            next_saved.push(value.clone());
            let mut next_pinned: Vec<String> = pinned.into_iter().filter(|u| u != &value).collect();
            next_pinned.push(value);
            (next_saved, next_pinned)
        })
        .await
    }

    /// Unpins a feed in the legacy v1 entry while keeping it saved.
    pub async fn remove_pinned_feed(&self, uri: &AtUri) -> Result<BskyLegacyFeeds, BskyAgentError> {
        let value = uri.as_str();
        self.update_legacy_feeds(|saved, pinned| {
            (saved, pinned.into_iter().filter(|u| u != value).collect())
        })
        .await
    }

    async fn update_legacy_feeds<F>(&self, transform: F) -> Result<BskyLegacyFeeds, BskyAgentError>
    where
        F: FnOnce(Vec<String>, Vec<String>) -> (Vec<String>, Vec<String>),
    {
        let (_, [saved_strs, pinned_strs]) = self
            .update_preferences_returning(|prefs| {
                let feeds_pref =
                    last_valid::<SavedFeedsPref>(&prefs, SavedFeedsPref::TYPE_IDENTIFIER)
                        .map_or_else(
                            || {
                                make_preference(
                                    SavedFeedsPref::TYPE_IDENTIFIER,
                                    [
                                        ("saved", JsonValue::Array(Vec::new())),
                                        ("pinned", JsonValue::Array(Vec::new())),
                                    ],
                                )
                            },
                            |(j, _)| j,
                        );
                let (next_saved, next_pinned) = transform(
                    json_strings(feeds_pref.get("saved")),
                    json_strings(feeds_pref.get("pinned")),
                );
                let updated = setting_field(
                    setting_field(
                        feeds_pref,
                        "saved",
                        Some(JsonValue::Array(
                            next_saved.iter().cloned().map(JsonValue::String).collect(),
                        )),
                    ),
                    "pinned",
                    Some(JsonValue::Array(
                        next_pinned.iter().cloned().map(JsonValue::String).collect(),
                    )),
                );
                Ok((
                    replacing(prefs, SavedFeedsPref::TYPE_IDENTIFIER, updated),
                    [next_saved, next_pinned],
                ))
            })
            .await?;

        Ok(BskyLegacyFeeds {
            saved: Some(parse_at_uris(&saved_strs)?),
            pinned: Some(parse_at_uris(&pinned_strs)?),
        })
    }

    // MARK: Moderation preferences

    /// Enables or disables adult content.
    pub async fn set_adult_content_enabled(&self, enabled: bool) -> Result<(), BskyAgentError> {
        self.update_preferences(|prefs| {
            let pref = last_valid::<AdultContentPref>(&prefs, AdultContentPref::TYPE_IDENTIFIER)
                .map_or_else(
                    || make_preference(AdultContentPref::TYPE_IDENTIFIER, []),
                    |(j, _)| j,
                );
            Ok(replacing(
                prefs,
                AdultContentPref::TYPE_IDENTIFIER,
                setting_field(pref, "enabled", Some(JsonValue::Bool(enabled))),
            ))
        })
        .await?;
        Ok(())
    }

    /// Sets how content carrying `key` is treated (globally or per labeler).
    pub async fn set_content_label_pref(
        &self,
        key: &str,
        value: LabelPreference,
        labeler_did: Option<&Did>,
    ) -> Result<(), BskyAgentError> {
        let labeler = labeler_did.map(Did::as_str);
        self.update_preferences(|prefs| {
            let concerns = |pref: &JsonValue, label: &str, labeler: Option<&str>| -> bool {
                json_type(pref) == Some(ContentLabelPref::TYPE_IDENTIFIER)
                    && pref.get("label").and_then(JsonValue::as_str) == Some(label)
                    && pref.get("labelerDid").and_then(JsonValue::as_str) == labeler
            };
            let last_valid_for = |list: &[JsonValue], label: &str, labeler: Option<&str>| {
                list.iter()
                    .rev()
                    .find(|p| {
                        ContentLabelPrefEntry::parse(p).is_some() && concerns(p, label, labeler)
                    })
                    .cloned()
            };
            let fresh = |label: &str, labeler: Option<&str>| {
                let mut fields = vec![("label", JsonValue::String(label.to_owned()))];
                if let Some(l) = labeler {
                    fields.push(("labelerDid", JsonValue::String(l.to_owned())));
                }
                make_preference(ContentLabelPref::TYPE_IDENTIFIER, fields)
            };

            let visibility = JsonValue::String(value.as_str().to_owned());
            let label_pref = setting_field(
                last_valid_for(&prefs, key, labeler).unwrap_or_else(|| fresh(key, labeler)),
                "visibility",
                Some(visibility.clone()),
            );

            let mut updated: Vec<JsonValue> = prefs
                .into_iter()
                .filter(|p| !concerns(p, key, labeler))
                .collect();
            updated.push(label_pref);

            if labeler.is_none()
                && let Some(legacy_label) = Self::legacy_for_current(key)
            {
                let legacy_pref = setting_field(
                    last_valid_for(&updated, legacy_label, None)
                        .unwrap_or_else(|| fresh(legacy_label, None)),
                    "visibility",
                    Some(visibility),
                );
                updated.retain(|p| !concerns(p, legacy_label, None));
                updated.push(legacy_pref);
            }

            Ok(updated)
        })
        .await?;
        Ok(())
    }

    /// Subscribes to a labeler and updates `atproto-accept-labelers`.
    pub async fn add_labeler(&self, did: &Did) -> Result<(), BskyAgentError> {
        let did_str = did.as_str().to_owned();
        self.update_preferences_applying_labelers(|prefs| {
            let pref = last_valid::<LabelersPref>(&prefs, LabelersPref::TYPE_IDENTIFIER)
                .map_or_else(
                    || {
                        make_preference(
                            LabelersPref::TYPE_IDENTIFIER,
                            [("labelers", JsonValue::Array(Vec::new()))],
                        )
                    },
                    |(j, _)| j,
                );
            let mut labelers = pref
                .get("labelers")
                .and_then(JsonValue::as_array)
                .cloned()
                .unwrap_or_default();
            if !labelers
                .iter()
                .any(|item| item.get("did").and_then(JsonValue::as_str) == Some(did_str.as_str()))
            {
                let mut map = Map::new();
                map.insert("did".to_owned(), JsonValue::String(did_str));
                labelers.push(JsonValue::Object(map));
            }
            Ok(replacing(
                prefs,
                LabelersPref::TYPE_IDENTIFIER,
                setting_field(pref, "labelers", Some(JsonValue::Array(labelers))),
            ))
        })
        .await?;
        Ok(())
    }

    /// Unsubscribes from a labeler and updates `atproto-accept-labelers`.
    pub async fn remove_labeler(&self, did: &Did) -> Result<(), BskyAgentError> {
        let did_str = did.as_str();
        self.update_preferences_applying_labelers(|prefs| {
            let pref = last_valid::<LabelersPref>(&prefs, LabelersPref::TYPE_IDENTIFIER)
                .map_or_else(
                    || {
                        make_preference(
                            LabelersPref::TYPE_IDENTIFIER,
                            [("labelers", JsonValue::Array(Vec::new()))],
                        )
                    },
                    |(j, _)| j,
                );
            let labelers: Vec<JsonValue> = pref
                .get("labelers")
                .and_then(JsonValue::as_array)
                .cloned()
                .unwrap_or_default()
                .into_iter()
                .filter(|item| item.get("did").and_then(JsonValue::as_str) != Some(did_str))
                .collect();
            Ok(replacing(
                prefs,
                LabelersPref::TYPE_IDENTIFIER,
                setting_field(pref, "labelers", Some(JsonValue::Array(labelers))),
            ))
        })
        .await?;
        Ok(())
    }

    /// Mutes a word or tag. No-op when `value` sanitizes to empty.
    pub async fn add_muted_word(
        &self,
        value: &str,
        targets: &[MutedWordTarget],
        actor_target: Option<&str>,
        expires_at: Option<&Datetime>,
    ) -> Result<(), BskyAgentError> {
        let sanitized = sanitize_muted_word_value(value);
        if sanitized.is_empty() {
            return Ok(());
        }
        let id = self.next_tid()?;
        let new_word = muted_word_json(&id, &sanitized, targets, actor_target, expires_at);
        self.update_preferences(|prefs| {
            let pref = if let Some((existing, _)) =
                last_valid::<MutedWordsPref>(&prefs, MutedWordsPref::TYPE_IDENTIFIER)
            {
                let mut items = existing
                    .get("items")
                    .and_then(JsonValue::as_array)
                    .cloned()
                    .unwrap_or_default();
                items.push(new_word);
                let migrated = self.migrating_legacy_muted_words(items)?;
                setting_field(existing, "items", Some(JsonValue::Array(migrated)))
            } else {
                make_preference(
                    MutedWordsPref::TYPE_IDENTIFIER,
                    [("items", JsonValue::Array(vec![new_word]))],
                )
            };
            Ok(replacing(prefs, MutedWordsPref::TYPE_IDENTIFIER, pref))
        })
        .await?;
        Ok(())
    }

    /// Mutes several words sequentially in order.
    pub async fn add_muted_words(&self, words: &[MutedWord]) -> Result<(), BskyAgentError> {
        for word in words {
            self.add_muted_word(
                &word.value,
                &word.targets,
                word.actor_target.as_deref(),
                word.expires_at.as_ref(),
            )
            .await?;
        }
        Ok(())
    }

    /// Updates a stored muted word matched by `id` (or `value` for legacy words).
    pub async fn update_muted_word(&self, muted_word: &MutedWord) -> Result<(), BskyAgentError> {
        self.update_preferences(|prefs| {
            let Some((existing, _)) =
                last_valid::<MutedWordsPref>(&prefs, MutedWordsPref::TYPE_IDENTIFIER)
            else {
                return Ok(prefs);
            };
            let mut items = Vec::new();
            for item in existing
                .get("items")
                .and_then(JsonValue::as_array)
                .cloned()
                .unwrap_or_default()
            {
                if !muted_word_matches_json(&item, muted_word) {
                    items.push(item);
                    continue;
                }
                let sanitized = sanitize_muted_word_value(&muted_word.value);
                let existing_id = item.get("id").and_then(JsonValue::as_str).unwrap_or("");
                let id = if existing_id.is_empty() {
                    self.next_tid()?
                } else {
                    existing_id.to_owned()
                };
                let effective_value = if sanitized.is_empty() {
                    item.get("value")
                        .and_then(JsonValue::as_str)
                        .unwrap_or("")
                        .to_owned()
                } else {
                    sanitized
                };
                let effective_actor_target = muted_word
                    .actor_target
                    .as_deref()
                    .or_else(|| item.get("actorTarget").and_then(JsonValue::as_str));
                items.push(muted_word_json(
                    &id,
                    &effective_value,
                    &muted_word.targets,
                    effective_actor_target,
                    muted_word.expires_at.as_ref(),
                ));
            }
            let migrated = self.migrating_legacy_muted_words(items)?;
            let pref = setting_field(existing, "items", Some(JsonValue::Array(migrated)));
            Ok(replacing(prefs, MutedWordsPref::TYPE_IDENTIFIER, pref))
        })
        .await?;
        Ok(())
    }

    /// Removes a stored muted word matched by `id` (or `value` for legacy words).
    pub async fn remove_muted_word(&self, muted_word: &MutedWord) -> Result<(), BskyAgentError> {
        self.update_preferences(|prefs| {
            let Some((existing, _)) =
                last_valid::<MutedWordsPref>(&prefs, MutedWordsPref::TYPE_IDENTIFIER)
            else {
                return Ok(prefs);
            };
            let mut items = existing
                .get("items")
                .and_then(JsonValue::as_array)
                .cloned()
                .unwrap_or_default();
            if let Some(pos) = items
                .iter()
                .position(|item| muted_word_matches_json(item, muted_word))
            {
                items.remove(pos);
            }
            let migrated = self.migrating_legacy_muted_words(items)?;
            let pref = setting_field(existing, "items", Some(JsonValue::Array(migrated)));
            Ok(replacing(prefs, MutedWordsPref::TYPE_IDENTIFIER, pref))
        })
        .await?;
        Ok(())
    }

    /// Removes several muted words sequentially in order.
    pub async fn remove_muted_words(&self, words: &[MutedWord]) -> Result<(), BskyAgentError> {
        for word in words {
            self.remove_muted_word(word).await?;
        }
        Ok(())
    }

    fn migrating_legacy_muted_words(
        &self,
        items: Vec<JsonValue>,
    ) -> Result<Vec<JsonValue>, BskyAgentError> {
        let mut migrated = Vec::with_capacity(items.len());
        for item in items {
            let has_id = item
                .get("id")
                .and_then(JsonValue::as_str)
                .is_some_and(|s| !s.is_empty());
            if !has_id && item.is_object() {
                let id = self.next_tid()?;
                migrated.push(setting_field(item, "id", Some(JsonValue::String(id))));
            } else {
                migrated.push(item);
            }
        }
        Ok(migrated)
    }

    /// Hides a post (idempotent).
    pub async fn hide_post(&self, uri: &AtUri) -> Result<(), BskyAgentError> {
        self.update_hidden_post(uri.as_str(), true).await
    }

    /// Unhides a post (no-op if not hidden).
    pub async fn unhide_post(&self, uri: &AtUri) -> Result<(), BskyAgentError> {
        self.update_hidden_post(uri.as_str(), false).await
    }

    async fn update_hidden_post(&self, uri: &str, hide: bool) -> Result<(), BskyAgentError> {
        self.update_preferences(|prefs| {
            let pref = last_valid::<HiddenPostsPref>(&prefs, HiddenPostsPref::TYPE_IDENTIFIER)
                .map_or_else(
                    || {
                        make_preference(
                            HiddenPostsPref::TYPE_IDENTIFIER,
                            [("items", JsonValue::Array(Vec::new()))],
                        )
                    },
                    |(j, _)| j,
                );
            let mut items = unique_strings(json_strings(pref.get("items")));
            if hide {
                if !items.iter().any(|item| item == uri) {
                    items.push(uri.to_owned());
                }
            } else {
                items.retain(|item| item != uri);
            }
            let updated = setting_field(
                pref,
                "items",
                Some(JsonValue::Array(
                    items.into_iter().map(JsonValue::String).collect(),
                )),
            );
            Ok(replacing(prefs, HiddenPostsPref::TYPE_IDENTIFIER, updated))
        })
        .await?;
        Ok(())
    }

    // MARK: Display & App State

    /// Declares or clears (`None`) the user's birth date.
    pub async fn set_personal_details(
        &self,
        birth_date: Option<&Datetime>,
    ) -> Result<(), BskyAgentError> {
        self.update_preferences(|prefs| {
            let pref =
                last_valid::<PersonalDetailsPref>(&prefs, PersonalDetailsPref::TYPE_IDENTIFIER)
                    .map_or_else(
                        || make_preference(PersonalDetailsPref::TYPE_IDENTIFIER, []),
                        |(j, _)| j,
                    );
            let val = birth_date.map(|d| JsonValue::String(d.as_str().to_owned()));
            Ok(replacing(
                prefs,
                PersonalDetailsPref::TYPE_IDENTIFIER,
                setting_field(pref, "birthDate", val),
            ))
        })
        .await?;
        Ok(())
    }

    /// Partially updates view preferences for one feed.
    pub async fn set_feed_view_prefs(
        &self,
        feed: &str,
        update: &BskyFeedViewPreferenceUpdate,
    ) -> Result<(), BskyAgentError> {
        self.update_preferences(|prefs| {
            let existing =
                last_valid_where::<FeedViewPref, _>(&prefs, FeedViewPref::TYPE_IDENTIFIER, |p| {
                    p.feed == feed
                })
                .map(|(j, _)| j);

            let mut fields = vec![("feed", JsonValue::String(feed.to_owned()))];
            if let Some(v) = update.hide_replies {
                fields.push(("hideReplies", JsonValue::Bool(v)));
            }
            if let Some(v) = update.hide_replies_by_unfollowed {
                fields.push(("hideRepliesByUnfollowed", JsonValue::Bool(v)));
            }
            if let Some(v) = update.hide_replies_by_like_count {
                fields.push(("hideRepliesByLikeCount", JsonValue::Number(v.into())));
            }
            if let Some(v) = update.hide_reposts {
                fields.push(("hideReposts", JsonValue::Bool(v)));
            }
            if let Some(v) = update.hide_quote_posts {
                fields.push(("hideQuotePosts", JsonValue::Bool(v)));
            }

            let pref = merge_objects(
                existing.unwrap_or_else(|| JsonValue::Object(Map::new())),
                &make_preference(FeedViewPref::TYPE_IDENTIFIER, fields),
            );
            let mut updated: Vec<JsonValue> = prefs
                .into_iter()
                .filter(|p| {
                    !(json_type(p) == Some(FeedViewPref::TYPE_IDENTIFIER)
                        && p.get("feed").and_then(JsonValue::as_str) == Some(feed))
                })
                .collect();
            updated.push(pref);
            Ok(updated)
        })
        .await?;
        Ok(())
    }

    /// Sets the thread reply sort order.
    pub async fn set_thread_view_prefs(&self, sort: &str) -> Result<(), BskyAgentError> {
        self.update_preferences(|prefs| {
            let existing = last_valid::<ThreadViewPref>(&prefs, ThreadViewPref::TYPE_IDENTIFIER)
                .map_or_else(|| JsonValue::Object(Map::new()), |(j, _)| j);
            let pref = merge_objects(
                existing,
                &make_preference(
                    ThreadViewPref::TYPE_IDENTIFIER,
                    [("sort", JsonValue::String(sort.to_owned()))],
                ),
            );
            Ok(replacing(prefs, ThreadViewPref::TYPE_IDENTIFIER, pref))
        })
        .await?;
        Ok(())
    }

    /// Replaces the user's interest tags.
    pub async fn set_interests_pref(&self, tags: &[String]) -> Result<(), BskyAgentError> {
        self.update_preferences(|prefs| {
            let existing = last_valid::<InterestsPref>(&prefs, InterestsPref::TYPE_IDENTIFIER)
                .map_or_else(|| JsonValue::Object(Map::new()), |(j, _)| j);
            let pref = merge_objects(
                existing,
                &make_preference(
                    InterestsPref::TYPE_IDENTIFIER,
                    [(
                        "tags",
                        JsonValue::Array(tags.iter().cloned().map(JsonValue::String).collect()),
                    )],
                ),
            );
            Ok(replacing(prefs, InterestsPref::TYPE_IDENTIFIER, pref))
        })
        .await?;
        Ok(())
    }

    async fn update_app_state<F>(&self, transform: F) -> Result<(), BskyAgentError>
    where
        F: FnOnce(JsonValue) -> Result<JsonValue, BskyAgentError>,
    {
        self.update_preferences(|prefs| {
            let pref = last_valid::<BskyAppStatePref>(&prefs, BskyAppStatePref::TYPE_IDENTIFIER)
                .map_or_else(
                    || make_preference(BskyAppStatePref::TYPE_IDENTIFIER, []),
                    |(j, _)| j,
                );
            let next = transform(pref)?;
            Ok(replacing(prefs, BskyAppStatePref::TYPE_IDENTIFIER, next))
        })
        .await?;
        Ok(())
    }

    /// Appends nudges to the queued nudges list.
    pub async fn bsky_app_queue_nudges(&self, nudges: &[String]) -> Result<(), BskyAgentError> {
        self.update_app_state(|pref| {
            let mut queued = json_strings(pref.get("queuedNudges"));
            queued.extend(nudges.iter().cloned());
            Ok(setting_field(
                pref,
                "queuedNudges",
                Some(JsonValue::Array(
                    queued.into_iter().map(JsonValue::String).collect(),
                )),
            ))
        })
        .await
    }

    /// Removes nudges from the queued nudges list.
    pub async fn bsky_app_dismiss_nudges(&self, nudges: &[String]) -> Result<(), BskyAgentError> {
        self.update_app_state(|pref| {
            let queued: Vec<JsonValue> = json_strings(pref.get("queuedNudges"))
                .into_iter()
                .filter(|item| !nudges.iter().any(|target| target == item))
                .map(JsonValue::String)
                .collect();
            Ok(setting_field(
                pref,
                "queuedNudges",
                Some(JsonValue::Array(queued)),
            ))
        })
        .await
    }

    /// Sets or clears (`None`) the onboarding progress guide.
    pub async fn bsky_app_set_active_progress_guide(
        &self,
        guide: Option<&BskyAppProgressGuide>,
    ) -> Result<(), BskyAgentError> {
        let stored = if let Some(guide) = guide {
            if guide.guide.len() > 100 {
                return Err(BskyAgentError::InvalidInput(
                    "Progress guide name must be at most 100 bytes".to_owned(),
                ));
            }
            let Ok(JsonValue::Object(mut map)) = serde_json::to_value(&guide.additional_fields)
            else {
                return Err(BskyAgentError::InvalidInput(
                    "Progress guide fields are not representable as JSON".to_owned(),
                ));
            };
            map.insert("guide".to_owned(), JsonValue::String(guide.guide.clone()));
            Some(JsonValue::Object(map))
        } else {
            None
        };
        self.update_app_state(|pref| Ok(setting_field(pref, "activeProgressGuide", stored)))
            .await
    }

    /// Records whether the user is a beta user.
    pub async fn set_is_beta_user(&self, is_beta_user: bool) -> Result<(), BskyAgentError> {
        self.update_app_state(|pref| {
            Ok(setting_field(
                pref,
                "isBetaUser",
                Some(JsonValue::Bool(is_beta_user)),
            ))
        })
        .await
    }

    /// Inserts or replaces a NUX item by ID.
    pub async fn bsky_app_upsert_nux(
        &self,
        nux: &petrel_api::generated::app::bsky::actor::defs::Nux,
    ) -> Result<(), BskyAgentError> {
        if nux.id.encode_utf16().count() > 64 {
            return Err(BskyAgentError::InvalidInput(
                "NUX id must be at most 64 characters".to_owned(),
            ));
        }
        if let Some(data) = &nux.data
            && data.encode_utf16().count() > 300
        {
            return Err(BskyAgentError::InvalidInput(
                "NUX data must be at most 300 characters".to_owned(),
            ));
        }
        let mut next = Map::new();
        next.insert("id".to_owned(), JsonValue::String(nux.id.clone()));
        next.insert("completed".to_owned(), JsonValue::Bool(nux.completed));
        if let Some(data) = &nux.data {
            next.insert("data".to_owned(), JsonValue::String(data.clone()));
        }
        if let Some(expires_at) = &nux.expires_at {
            next.insert(
                "expiresAt".to_owned(),
                JsonValue::String(expires_at.as_str().to_owned()),
            );
        }
        let stored = JsonValue::Object(next);

        self.update_app_state(|pref| {
            let mut nuxs: Vec<JsonValue> = pref
                .get("nuxs")
                .and_then(JsonValue::as_array)
                .cloned()
                .unwrap_or_default()
                .into_iter()
                .filter(|item| item.get("id").and_then(JsonValue::as_str) != Some(nux.id.as_str()))
                .collect();
            nuxs.push(stored);
            Ok(setting_field(pref, "nuxs", Some(JsonValue::Array(nuxs))))
        })
        .await
    }

    /// Removes NUX items by ID.
    pub async fn bsky_app_remove_nuxs(&self, ids: &[String]) -> Result<(), BskyAgentError> {
        self.update_app_state(|pref| {
            let nuxs: Vec<JsonValue> = pref
                .get("nuxs")
                .and_then(JsonValue::as_array)
                .cloned()
                .unwrap_or_default()
                .into_iter()
                .filter(|item| {
                    item.get("id")
                        .and_then(JsonValue::as_str)
                        .is_none_or(|id| !ids.iter().any(|target| target == id))
                })
                .collect();
            Ok(setting_field(pref, "nuxs", Some(JsonValue::Array(nuxs))))
        })
        .await
    }

    /// Sets default reply and quote restrictions for new posts.
    pub async fn set_post_interaction_settings(
        &self,
        settings: &PostInteractionSettingsPref,
    ) -> Result<(), BskyAgentError> {
        let threadgate = encode_rule_list(
            settings.threadgate_allow_rules.as_deref(),
            "threadgateAllowRules",
        )?;
        let postgate = encode_rule_list(
            settings.postgate_embedding_rules.as_deref(),
            "postgateEmbeddingRules",
        )?;

        self.update_preferences(|prefs| {
            let pref = last_valid::<PostInteractionSettingsPref>(
                &prefs,
                PostInteractionSettingsPref::TYPE_IDENTIFIER,
            )
            .map_or_else(
                || make_preference(PostInteractionSettingsPref::TYPE_IDENTIFIER, []),
                |(j, _)| j,
            );
            let updated = setting_field(
                setting_field(pref, "threadgateAllowRules", threadgate),
                "postgateEmbeddingRules",
                postgate,
            );
            Ok(replacing(
                prefs,
                PostInteractionSettingsPref::TYPE_IDENTIFIER,
                updated,
            ))
        })
        .await?;
        Ok(())
    }

    /// Sets whether verification badges are hidden.
    pub async fn set_verification_prefs(&self, hide_badges: bool) -> Result<(), BskyAgentError> {
        self.update_preferences(|prefs| {
            let pref = last_valid::<VerificationPrefs>(&prefs, VerificationPrefs::TYPE_IDENTIFIER)
                .map_or_else(
                    || make_preference(VerificationPrefs::TYPE_IDENTIFIER, []),
                    |(j, _)| j,
                );
            Ok(replacing(
                prefs,
                VerificationPrefs::TYPE_IDENTIFIER,
                setting_field(pref, "hideBadges", Some(JsonValue::Bool(hide_badges))),
            ))
        })
        .await?;
        Ok(())
    }

    /// Applies one mutation to live-event feed preferences and returns the updated state.
    pub async fn update_live_event_preferences(
        &self,
        action: &BskyLiveEventPreferencesAction,
    ) -> Result<BskyLiveEventPreferences, BskyAgentError> {
        let (_, result) = self
            .update_preferences_returning(|prefs| {
                let pref = last_valid::<LiveEventPreferences>(
                    &prefs,
                    LiveEventPreferences::TYPE_IDENTIFIER,
                )
                .map_or_else(
                    || make_preference(LiveEventPreferences::TYPE_IDENTIFIER, []),
                    |(j, _)| j,
                );

                let mut hidden_feed_ids = unique_strings(json_strings(pref.get("hiddenFeedIds")));
                let mut hide_all_feeds = pref
                    .get("hideAllFeeds")
                    .and_then(JsonValue::as_bool)
                    .unwrap_or(false);
                let mut updated = pref;

                match action {
                    BskyLiveEventPreferencesAction::HideFeed(id) => {
                        if !hidden_feed_ids.iter().any(|existing| existing == id) {
                            hidden_feed_ids.push(id.clone());
                        }
                    }
                    BskyLiveEventPreferencesAction::UnhideFeed(id) => {
                        hidden_feed_ids.retain(|existing| existing != id);
                    }
                    BskyLiveEventPreferencesAction::ToggleHideAllFeeds => {
                        hide_all_feeds = !hide_all_feeds;
                        updated = setting_field(
                            updated,
                            "hideAllFeeds",
                            Some(JsonValue::Bool(hide_all_feeds)),
                        );
                    }
                }
                updated = setting_field(
                    updated,
                    "hiddenFeedIds",
                    Some(JsonValue::Array(
                        hidden_feed_ids
                            .iter()
                            .cloned()
                            .map(JsonValue::String)
                            .collect(),
                    )),
                );

                Ok((
                    replacing(prefs, LiveEventPreferences::TYPE_IDENTIFIER, updated),
                    BskyLiveEventPreferences {
                        hidden_feed_ids,
                        hide_all_feeds,
                    },
                ))
            })
            .await?;
        Ok(result)
    }
}

struct ContentLabelPrefEntry {
    label: String,
    visibility: String,
    labeler_did: Option<Did>,
}

impl ContentLabelPrefEntry {
    fn parse(json: &JsonValue) -> Option<Self> {
        if json_type(json) != Some(ContentLabelPref::TYPE_IDENTIFIER) {
            return None;
        }
        let label = json.get("label")?.as_str()?.to_owned();
        let visibility = json.get("visibility")?.as_str()?.to_owned();
        let labeler_did = if let Some(raw) = json.get("labelerDid") {
            let s = raw.as_str()?;
            Some(s.parse::<Did>().ok()?)
        } else {
            None
        };
        Some(Self {
            label,
            visibility,
            labeler_did,
        })
    }

    fn adjusting_legacy_visibility(mut self) -> Self {
        if self.visibility == "show" {
            "ignore".clone_into(&mut self.visibility);
        }
        self
    }
}

fn json_type(value: &JsonValue) -> Option<&str> {
    value.get("$type").and_then(JsonValue::as_str)
}

fn decode_valid<T: DeserializeOwned>(value: &JsonValue, expected_type: &str) -> Option<T> {
    if json_type(value) != Some(expected_type) {
        return None;
    }
    serde_json::from_value(value.clone()).ok()
}

fn last_valid<T: DeserializeOwned>(
    prefs: &[JsonValue],
    expected_type: &str,
) -> Option<(JsonValue, T)> {
    last_valid_where(prefs, expected_type, |_| true)
}

fn last_valid_where<T: DeserializeOwned, F>(
    prefs: &[JsonValue],
    expected_type: &str,
    pred: F,
) -> Option<(JsonValue, T)>
where
    F: Fn(&T) -> bool,
{
    for entry in prefs.iter().rev() {
        if let Some(decoded) = decode_valid::<T>(entry, expected_type)
            && pred(&decoded)
        {
            return Some((entry.clone(), decoded));
        }
    }
    None
}

fn make_preference<'a, I>(ty: &str, fields: I) -> JsonValue
where
    I: IntoIterator<Item = (&'a str, JsonValue)>,
{
    let mut map = Map::new();
    map.insert("$type".to_owned(), JsonValue::String(ty.to_owned()));
    for (k, v) in fields {
        map.insert(k.to_owned(), v);
    }
    JsonValue::Object(map)
}

fn setting_field(mut value: JsonValue, key: &str, field_value: Option<JsonValue>) -> JsonValue {
    if let Some(obj) = value.as_object_mut() {
        if let Some(v) = field_value {
            obj.insert(key.to_owned(), v);
        } else {
            obj.remove(key);
        }
    }
    value
}

fn merge_objects(mut base: JsonValue, overlay: &JsonValue) -> JsonValue {
    if let (Some(base_obj), Some(overlay_obj)) = (base.as_object_mut(), overlay.as_object()) {
        for (k, v) in overlay_obj {
            base_obj.insert(k.clone(), v.clone());
        }
    }
    base
}

fn replacing(prefs: Vec<JsonValue>, ty: &str, entry: JsonValue) -> Vec<JsonValue> {
    let mut out: Vec<JsonValue> = prefs
        .into_iter()
        .filter(|p| json_type(p) != Some(ty))
        .collect();
    out.push(entry);
    out
}

fn saved_feed_json(feed: &SavedFeed) -> JsonValue {
    let mut map = Map::new();
    map.insert("id".to_owned(), JsonValue::String(feed.id.clone()));
    map.insert("type".to_owned(), JsonValue::String(feed.r#type.clone()));
    map.insert("value".to_owned(), JsonValue::String(feed.value.clone()));
    map.insert("pinned".to_owned(), JsonValue::Bool(feed.pinned));
    JsonValue::Object(map)
}

fn decode_saved_feeds(items: &[JsonValue]) -> Result<Vec<SavedFeed>, BskyAgentError> {
    items
        .iter()
        .map(|item| {
            serde_json::from_value::<SavedFeed>(item.clone()).map_err(|_| {
                BskyAgentError::InvalidResponse {
                    nsid: "app.bsky.actor.getPreferences".to_owned(),
                    reason: "A stored saved feed does not match the lexicon".to_owned(),
                }
            })
        })
        .collect()
}

fn json_strings(value: Option<&JsonValue>) -> Vec<String> {
    value
        .and_then(JsonValue::as_array)
        .map(|arr| {
            arr.iter()
                .filter_map(JsonValue::as_str)
                .map(ToOwned::to_owned)
                .collect()
        })
        .unwrap_or_default()
}

fn unique_strings(values: Vec<String>) -> Vec<String> {
    let mut seen = HashSet::new();
    values
        .into_iter()
        .filter(|val| seen.insert(val.clone()))
        .collect()
}

fn parse_at_uris(values: &[String]) -> Result<Vec<AtUri>, BskyAgentError> {
    values
        .iter()
        .map(|raw| {
            raw.parse::<AtUri>()
                .map_err(|_| BskyAgentError::InvalidInput(format!("Not an AT URI: {raw}")))
        })
        .collect()
}

fn muted_word_json(
    id: &str,
    value: &str,
    targets: &[MutedWordTarget],
    actor_target: Option<&str>,
    expires_at: Option<&Datetime>,
) -> JsonValue {
    let effective_actor = match actor_target {
        None | Some("") => "all",
        Some(other) => other,
    };
    let mut map = Map::new();
    map.insert("id".to_owned(), JsonValue::String(id.to_owned()));
    map.insert("value".to_owned(), JsonValue::String(value.to_owned()));
    map.insert(
        "targets".to_owned(),
        JsonValue::Array(
            targets
                .iter()
                .map(|t| JsonValue::String(t.as_str().to_owned()))
                .collect(),
        ),
    );
    map.insert(
        "actorTarget".to_owned(),
        JsonValue::String(effective_actor.to_owned()),
    );
    if let Some(exp) = expires_at {
        map.insert(
            "expiresAt".to_owned(),
            JsonValue::String(exp.as_str().to_owned()),
        );
    }
    JsonValue::Object(map)
}

fn muted_word_matches_json(stored: &JsonValue, candidate: &MutedWord) -> bool {
    let stored_id = stored.get("id").and_then(JsonValue::as_str).unwrap_or("");
    if !stored_id.is_empty() {
        return candidate.id.as_deref() == Some(stored_id);
    }
    stored.get("value").and_then(JsonValue::as_str) == Some(candidate.value.as_str())
}

fn progress_guide_from_json(json: Option<&JsonValue>) -> Option<BskyAppProgressGuide> {
    let obj = json?.as_object()?;
    let guide = obj.get("guide")?.as_str()?.to_owned();
    let mut additional_fields = BTreeMap::new();
    for (k, v) in obj {
        if k == "guide" || k == "$type" {
            continue;
        }
        if let Ok(val) = serde_json::from_value::<Value>(v.clone()) {
            additional_fields.insert(k.clone(), val);
        }
    }
    Some(BskyAppProgressGuide {
        guide,
        additional_fields,
    })
}

fn encode_rule_list<Rule: serde::Serialize>(
    rules: Option<&[Rule]>,
    name: &str,
) -> Result<Option<JsonValue>, BskyAgentError> {
    let Some(rules) = rules else {
        return Ok(None);
    };
    if rules.len() > 5 {
        return Err(BskyAgentError::InvalidInput(format!(
            "{name} accepts at most 5 rules"
        )));
    }
    let mut encoded = Vec::with_capacity(rules.len());
    for rule in rules {
        let json = serde_json::to_value(rule).map_err(|_| {
            BskyAgentError::InvalidInput(format!(
                "Every entry of {name} must be an object with a $type"
            ))
        })?;
        if !json.is_object() || json_type(&json).is_none() {
            return Err(BskyAgentError::InvalidInput(format!(
                "Every entry of {name} must be an object with a $type"
            )));
        }
        encoded.push(json);
    }
    Ok(Some(JsonValue::Array(encoded)))
}
