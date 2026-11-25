//! Ported BskyPreferences & BskyPreferencesEngine tests.
#![cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]

use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};

use async_lock::Mutex as AsyncMutex;
use petrel::rt::BoxFuture;
use petrel::xrpc::XrpcLabeler;
use petrel_api::generated::app::bsky::actor::defs::{
    MutedWord, MutedWordTarget, Nux, PostInteractionSettingsPref,
    PostInteractionSettingsPrefPostgateEmbeddingRules,
    PostInteractionSettingsPrefThreadgateAllowRules, SavedFeed,
};
use petrel_api::generated::app::bsky::feed::postgate::DisableRule;
use petrel_api::generated::app::bsky::feed::threadgate::MentionRule;
use petrel_bsky::{
    BSKY_LABELER_DID, BskyAgentError, BskyAppProgressGuide, BskyFeedViewPreferenceUpdate,
    BskyLiveEventPreferencesAction, BskyNewSavedFeed, BskyPreferencesBackend,
    BskyPreferencesEngine, LabelPreference, sanitize_muted_word_value, saved_feeds_to_uri_arrays,
    validate_saved_feed_fields,
};
use petrel_core::{AtUri, Datetime, Did, Value};
use serde_json::{Value as JsonValue, json};

struct FakePrefsBackend {
    stored: Mutex<Vec<JsonValue>>,
    loads: Mutex<usize>,
    saves: Mutex<usize>,
    labelers: Mutex<Vec<Vec<XrpcLabeler>>>,
}

impl FakePrefsBackend {
    fn new(seed: Vec<JsonValue>) -> Arc<Self> {
        Arc::new(Self {
            stored: Mutex::new(seed),
            loads: Mutex::new(0),
            saves: Mutex::new(0),
            labelers: Mutex::new(Vec::new()),
        })
    }

    fn entries(&self, ty: &str) -> Vec<JsonValue> {
        self.stored
            .lock()
            .unwrap()
            .iter()
            .filter(|v| v.get("$type").and_then(JsonValue::as_str) == Some(ty))
            .cloned()
            .collect()
    }

    fn save_count(&self) -> usize {
        *self.saves.lock().unwrap()
    }

    fn last_labelers(&self) -> Option<Vec<XrpcLabeler>> {
        self.labelers.lock().unwrap().last().cloned()
    }
}

impl BskyPreferencesBackend for FakePrefsBackend {
    fn load_preferences(&self) -> BoxFuture<'_, Result<Vec<JsonValue>, BskyAgentError>> {
        Box::pin(async move {
            *self.loads.lock().unwrap() += 1;
            Ok(self.stored.lock().unwrap().clone())
        })
    }

    fn save_preferences(
        &self,
        preferences: Vec<JsonValue>,
    ) -> BoxFuture<'_, Result<(), BskyAgentError>> {
        Box::pin(async move {
            *self.saves.lock().unwrap() += 1;
            *self.stored.lock().unwrap() = preferences;
            Ok(())
        })
    }

    fn configure_labelers(&self, labelers: Vec<XrpcLabeler>) -> BoxFuture<'_, ()> {
        Box::pin(async move {
            self.labelers.lock().unwrap().push(labelers);
        })
    }
}

fn make_engine(seed: Vec<JsonValue>) -> (BskyPreferencesEngine, Arc<FakePrefsBackend>) {
    let backend = FakePrefsBackend::new(seed);
    let b_trait: Arc<dyn BskyPreferencesBackend> = backend.clone();
    let app_labeler: Did = BSKY_LABELER_DID.parse().unwrap();
    let engine =
        BskyPreferencesEngine::new(b_trait, Arc::new(AsyncMutex::new(())), vec![app_labeler]);
    (engine, backend)
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn preferences_utilities_sanitization_and_validation() {
    let cases = [
        ("#", ""),
        ("##", "#"),
        ("##hashtag", "#hashtag"),
        ("#\u{FE0F}\u{20E3}", "#\u{FE0F}\u{20E3}"),
        ("##\u{FE0F}\u{20E3}", "#\u{FE0F}\u{20E3}"),
        ("###\u{FE0F}\u{20E3}", "##\u{FE0F}\u{20E3}"),
        ("Bluesky's", "Bluesky's"),
        ("#\u{200B}", ""),
        ("#\u{200B}ab", "ab"),
        ("test value\n with newline", "test value with newline"),
        ("test value\n\r with newline", "test value with newline"),
        (" ", ""),
        (" trim ", "trim"),
    ];
    for (input, expected) in cases {
        assert_eq!(
            sanitize_muted_word_value(input),
            expected,
            "input: {input:?}"
        );
    }

    assert!(
        validate_saved_feed_fields("3kabc", "feed", "at://bob.com/app.bsky.feed.generator/1")
            .is_ok()
    );
    assert!(
        validate_saved_feed_fields("3kabc", "feed", "at://bob.com/app.bsky.graph.list/1").is_err()
    );
    assert!(
        validate_saved_feed_fields("3kabc", "list", "at://bob.com/app.bsky.feed.generator/1")
            .is_err()
    );
    assert!(validate_saved_feed_fields("", "timeline", "following").is_err());

    let (pinned, saved) = saved_feeds_to_uri_arrays(&[
        ("at://bob.com/app.bsky.feed.generator/1", true),
        ("at://bob.com/app.bsky.graph.list/2", false),
    ]);
    assert_eq!(pinned, vec!["at://bob.com/app.bsky.feed.generator/1"]);
    assert_eq!(
        saved,
        vec![
            "at://bob.com/app.bsky.feed.generator/1",
            "at://bob.com/app.bsky.graph.list/2"
        ]
    );
}

#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[allow(clippy::too_many_lines)]
async fn preferences_engine_saved_feeds_moderation_and_app_state() {
    // 1. Auto-migration from empty -> default Following timeline + labelers configured
    let (engine, backend) = make_engine(vec![]);
    let prefs = engine.get_preferences().await.unwrap();
    assert_eq!(prefs.saved_feeds.len(), 1);
    assert_eq!(prefs.saved_feeds[0].r#type, "timeline");
    assert_eq!(prefs.saved_feeds[0].value, "following");
    assert!(prefs.saved_feeds[0].pinned);
    assert_eq!(
        backend.last_labelers().unwrap(),
        vec![XrpcLabeler {
            did: BSKY_LABELER_DID.to_owned(),
            redact: true
        }]
    );

    // 2. Add/update/overwrite/remove saved feeds + v1 mirror
    let feed_uri: AtUri = "at://bob.com/app.bsky.feed.generator/0".parse().unwrap();
    let list_uri: AtUri = "at://bob.com/app.bsky.graph.list/1".parse().unwrap();
    let added = engine
        .add_saved_feeds(&[
            BskyNewSavedFeed::list(&list_uri, false),
            BskyNewSavedFeed::feed(&feed_uri, true),
        ])
        .await
        .unwrap();
    // Pinned comes first!
    assert_eq!(added[0].value, "following");
    assert_eq!(added[1].value, feed_uri.as_str());
    assert!(added[1].pinned);
    assert_eq!(added[2].value, list_uri.as_str());
    assert!(!added[2].pinned);

    // Toggle pin
    let mut to_update = added[2].clone();
    to_update.pinned = true;
    let updated = engine
        .update_saved_feeds(&[to_update.clone()])
        .await
        .unwrap();
    assert_eq!(updated.iter().filter(|f| f.pinned).count(), 3);

    // Overwrite collapsing duplicates to last occurrence
    let custom = vec![
        SavedFeed::new(
            "id1".to_owned(),
            "feed".to_owned(),
            feed_uri.as_str().to_owned(),
            false,
        ),
        SavedFeed::new(
            "id2".to_owned(),
            "list".to_owned(),
            list_uri.as_str().to_owned(),
            true,
        ),
        SavedFeed::new(
            "id1".to_owned(),
            "feed".to_owned(),
            feed_uri.as_str().to_owned(),
            true,
        ),
    ];
    let overwritten = engine.overwrite_saved_feeds(&custom).await.unwrap();
    assert_eq!(
        overwritten
            .iter()
            .map(|f| f.id.as_str())
            .collect::<Vec<_>>(),
        vec!["id2", "id1"]
    );
    assert!(overwritten[1].pinned);

    // 3. Migration from legacy v1 savedFeedsPref
    let (legacy_engine, _) = make_engine(vec![json!({
        "$type": "app.bsky.actor.defs#savedFeedsPref",
        "saved": ["at://bob.com/app.bsky.feed.generator/a", "at://bob.com/app.bsky.graph.list/b"],
        "pinned": ["at://bob.com/app.bsky.graph.list/b"]
    })]);
    let migrated_prefs = legacy_engine.get_preferences().await.unwrap();
    assert_eq!(
        migrated_prefs
            .saved_feeds
            .iter()
            .map(|f| (f.r#type.as_str(), f.value.as_str(), f.pinned))
            .collect::<Vec<_>>(),
        vec![
            ("timeline", "following", true),
            ("list", "at://bob.com/app.bsky.graph.list/b", true),
            ("feed", "at://bob.com/app.bsky.feed.generator/a", false),
        ]
    );

    // 4. Content labels double-write + legacy `show`/`gore`/`nsfw`/`suggestive` remapping
    engine.set_adult_content_enabled(true).await.unwrap();
    engine
        .set_content_label_pref("porn", LabelPreference::Warn, None)
        .await
        .unwrap();
    engine
        .set_content_label_pref("graphic-media", LabelPreference::Hide, None)
        .await
        .unwrap();
    let label_entries = backend.entries("app.bsky.actor.defs#contentLabelPref");
    assert!(
        label_entries
            .iter()
            .any(|e| e["label"] == "nsfw" && e["visibility"] == "warn")
    );
    assert!(
        label_entries
            .iter()
            .any(|e| e["label"] == "gore" && e["visibility"] == "hide")
    );

    // Labeler subscription updates `configure_labelers`
    let extra_labeler: Did = "did:plc:labeler1".parse().unwrap();
    engine.add_labeler(&extra_labeler).await.unwrap();
    assert_eq!(
        backend.last_labelers().unwrap(),
        vec![
            XrpcLabeler {
                did: BSKY_LABELER_DID.to_owned(),
                redact: true
            },
            XrpcLabeler {
                did: "did:plc:labeler1".to_owned(),
                redact: false
            }
        ]
    );
    engine.remove_labeler(&extra_labeler).await.unwrap();

    // Legacy "show" maps to "ignore" on read
    let (legacy_vis_engine, _) = make_engine(vec![
        json!({
            "$type": "app.bsky.actor.defs#contentLabelPref",
            "label": "suggestive",
            "visibility": "show"
        }),
        json!({
            "$type": "app.bsky.actor.defs#savedFeedsPrefV2",
            "items": []
        }),
    ]);
    let legacy_vis = legacy_vis_engine.get_preferences().await.unwrap();
    assert_eq!(
        legacy_vis.moderation_prefs.labels.get("sexual").copied(),
        Some(LabelPreference::Ignore)
    );

    // 5. Muted words (sanitize, legacy migration, update/remove) & hidden posts
    let before_saves = backend.save_count();
    engine
        .add_muted_word("   ", &[MutedWordTarget::Content], None, None)
        .await
        .unwrap();
    assert_eq!(
        backend.save_count(),
        before_saves,
        "empty after sanitize skips write"
    );

    let exp: Datetime = "2030-01-01T00:00:00Z".parse().unwrap();
    engine
        .add_muted_word(
            "#spoilers",
            &[MutedWordTarget::Content, MutedWordTarget::Tag],
            None,
            Some(&exp),
        )
        .await
        .unwrap();
    let mut loaded = engine.get_preferences().await.unwrap();
    assert_eq!(loaded.moderation_prefs.muted_words.len(), 1);
    let mut mw: MutedWord = loaded.moderation_prefs.muted_words[0].clone();
    assert_eq!(mw.value, "spoilers");
    assert_eq!(mw.actor_target.as_deref(), Some("all"));
    "updated".clone_into(&mut mw.value);
    engine.update_muted_word(&mw).await.unwrap();
    loaded = engine.get_preferences().await.unwrap();
    assert_eq!(loaded.moderation_prefs.muted_words[0].value, "updated");
    engine.remove_muted_word(&mw).await.unwrap();
    assert_eq!(
        engine
            .get_preferences()
            .await
            .unwrap()
            .moderation_prefs
            .muted_words,
        [] as [petrel_api::generated::app::bsky::actor::defs::MutedWord; 0]
    );

    let post_uri: AtUri = "at://did:plc:bob/app.bsky.feed.post/1".parse().unwrap();
    engine.hide_post(&post_uri).await.unwrap();
    engine.hide_post(&post_uri).await.unwrap();
    assert_eq!(
        engine
            .get_preferences()
            .await
            .unwrap()
            .moderation_prefs
            .hidden_posts
            .len(),
        1
    );
    engine.unhide_post(&post_uri).await.unwrap();
    assert_eq!(
        engine
            .get_preferences()
            .await
            .unwrap()
            .moderation_prefs
            .hidden_posts,
        [] as [AtUri; 0]
    );

    // 6. Display, AppState, PostInteractionSettings, Verification, LiveEvent + unknown field preservation
    engine
        .set_feed_view_prefs(
            "home",
            &BskyFeedViewPreferenceUpdate {
                hide_reposts: Some(true),
                ..Default::default()
            },
        )
        .await
        .unwrap();
    engine.set_thread_view_prefs("newest").await.unwrap();
    engine
        .set_interests_pref(&["birds".to_owned(), "rust".to_owned()])
        .await
        .unwrap();
    engine
        .bsky_app_queue_nudges(&["nudge-1".to_owned(), "nudge-2".to_owned()])
        .await
        .unwrap();
    engine
        .bsky_app_dismiss_nudges(&["nudge-1".to_owned()])
        .await
        .unwrap();

    let mut extra = BTreeMap::new();
    extra.insert("step".to_owned(), Value::Integer(2));
    engine
        .bsky_app_set_active_progress_guide(Some(&BskyAppProgressGuide {
            guide: "onboarding".to_owned(),
            additional_fields: extra,
        }))
        .await
        .unwrap();
    engine.set_is_beta_user(true).await.unwrap();
    engine
        .bsky_app_upsert_nux(&Nux::new("welcome".to_owned(), true))
        .await
        .unwrap();
    engine.set_verification_prefs(true).await.unwrap();
    let live = engine
        .update_live_event_preferences(&BskyLiveEventPreferencesAction::HideFeed(
            "live-1".to_owned(),
        ))
        .await
        .unwrap();
    assert_eq!(live.hidden_feed_ids, vec!["live-1"]);

    let interaction = PostInteractionSettingsPref {
        threadgate_allow_rules: Some(vec![
            PostInteractionSettingsPrefThreadgateAllowRules::MentionRule(Box::new(
                MentionRule::new(),
            )),
        ]),
        postgate_embedding_rules: Some(vec![
            PostInteractionSettingsPrefPostgateEmbeddingRules::DisableRule(Box::new(
                DisableRule::new(),
            )),
        ]),
        extra_data: None,
    };
    engine
        .set_post_interaction_settings(&interaction)
        .await
        .unwrap();

    let final_prefs = engine.get_preferences().await.unwrap();
    assert!(final_prefs.feed_view_prefs["home"].hide_reposts);
    assert_eq!(final_prefs.thread_view_prefs.sort, "newest");
    assert_eq!(final_prefs.interests.tags, vec!["birds", "rust"]);
    assert_eq!(final_prefs.bsky_app_state.queued_nudges, vec!["nudge-2"]);
    assert_eq!(
        final_prefs
            .bsky_app_state
            .active_progress_guide
            .as_ref()
            .unwrap()
            .guide,
        "onboarding"
    );
    assert_eq!(final_prefs.bsky_app_state.is_beta_user, Some(true));
    assert_eq!(final_prefs.bsky_app_state.nuxs.len(), 1);
    assert_eq!(final_prefs.verification_prefs.hide_badges, Some(true));
    assert_eq!(
        final_prefs
            .post_interaction_settings
            .threadgate_allow_rules
            .as_ref()
            .unwrap()
            .len(),
        1
    );
}
