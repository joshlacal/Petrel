//! Ported Bluesky moderation test suite against vendored vectors (`behaviors.json`,
//! `custom-labels.json`, `quoteposts.json`, `labels.json`) plus subjects & mute words.

use std::collections::{BTreeSet, HashMap};

use petrel_api::generated::app::bsky::actor::defs::{MutedWord, MutedWordTarget, ProfileViewBasic};
use petrel_api::generated::app::bsky::feed::defs::{GeneratorView, PostView};
use petrel_api::generated::app::bsky::graph::defs::{ListView, ListViewBasic};
use petrel_api::generated::app::bsky::notification::list_notifications::Notification;
use petrel_api::generated::app::bsky::richtext::facet::{ByteSlice, Facet, FacetFeatures, Tag};
use petrel_api::generated::com::atproto::label::defs::LabelValueDefinition;
use petrel_bsky::{
    LabelPreference, Moderation, ModerationBehavior, ModerationCauseType, ModerationContext,
    ModerationDecision, ModerationOptions, ModerationPrefs, ModerationPrefsLabeler, ModerationUI,
    builtin_label_definitions, interpret_label_value_definition, known_labels, match_mute_words,
};
use petrel_core::{AtUri, Datetime, Did};
use serde::Deserialize;
use serde_json::{Value as JsonValue, json};

const FAKE_CID: &str = "bafyreiclp443lavogvhj3d2ob2cxbfuscni2k5jk7bebjzg7khl3esabwq";
const TIMESTAMP: &str = "2024-01-01T00:00:00.000Z";
const FAKE_LABELER: &str = "did:plc:fake-labeler";

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ExpectedBehaviors {
    profile_list: Option<Vec<String>>,
    profile_view: Option<Vec<String>>,
    avatar: Option<Vec<String>>,
    banner: Option<Vec<String>>,
    display_name: Option<Vec<String>>,
    content_list: Option<Vec<String>>,
    content_view: Option<Vec<String>>,
    content_media: Option<Vec<String>>,
}

impl ExpectedBehaviors {
    fn for_context(&self, ctx: ModerationContext) -> Option<&[String]> {
        match ctx {
            ModerationContext::ProfileList => self.profile_list.as_deref(),
            ModerationContext::ProfileView => self.profile_view.as_deref(),
            ModerationContext::Avatar => self.avatar.as_deref(),
            ModerationContext::Banner => self.banner.as_deref(),
            ModerationContext::DisplayName => self.display_name.as_deref(),
            ModerationContext::ContentList => self.content_list.as_deref(),
            ModerationContext::ContentView => self.content_view.as_deref(),
            ModerationContext::ContentMedia => self.content_media.as_deref(),
        }
    }
}

fn expect_ui(ui: &ModerationUI, expected: Option<&[String]>, label: &str) {
    let flags: BTreeSet<&str> = expected.unwrap_or(&[]).iter().map(String::as_str).collect();
    for flag in &flags {
        assert!(
            matches!(*flag, "filter" | "blur" | "alert" | "inform" | "noOverride"),
            "{label}: unknown expected flag {flag}"
        );
    }
    assert_eq!(ui.inform(), flags.contains("inform"), "{label}: inform");
    assert_eq!(ui.alert(), flags.contains("alert"), "{label}: alert");
    assert_eq!(ui.blur(), flags.contains("blur"), "{label}: blur");
    assert_eq!(ui.filter(), flags.contains("filter"), "{label}: filter");
    assert_eq!(
        ui.no_override,
        flags.contains("noOverride"),
        "{label}: noOverride"
    );
}

fn expect_results(
    decision: &ModerationDecision,
    expected: &ExpectedBehaviors,
    name: &str,
    contexts: &[ModerationContext],
) {
    for &ctx in contexts {
        expect_ui(
            &decision.ui(ctx),
            expected.for_context(ctx),
            &format!("{name} [{ctx:?}]"),
        );
    }
}

fn mock_label(val: &str, uri: &str, src: &str) -> JsonValue {
    json!({
        "src": src,
        "uri": uri,
        "val": val,
        "cts": TIMESTAMP,
    })
}

fn mock_profile(
    handle: &str,
    display_name: Option<&str>,
    viewer: Option<JsonValue>,
    labels: Option<Vec<JsonValue>>,
) -> JsonValue {
    let mut obj = serde_json::Map::new();
    obj.insert(
        "did".to_owned(),
        JsonValue::String(format!("did:web:{handle}")),
    );
    obj.insert("handle".to_owned(), JsonValue::String(handle.to_owned()));
    if let Some(dn) = display_name {
        obj.insert("displayName".to_owned(), JsonValue::String(dn.to_owned()));
    }
    if let Some(v) = viewer {
        obj.insert("viewer".to_owned(), v);
    }
    if let Some(l) = labels {
        obj.insert("labels".to_owned(), JsonValue::Array(l));
    }
    JsonValue::Object(obj)
}

fn mock_post(text: &str, langs: Option<Vec<&str>>) -> JsonValue {
    let mut obj = serde_json::Map::new();
    obj.insert(
        "$type".to_owned(),
        JsonValue::String("app.bsky.feed.post".to_owned()),
    );
    obj.insert("text".to_owned(), JsonValue::String(text.to_owned()));
    obj.insert(
        "createdAt".to_owned(),
        JsonValue::String(TIMESTAMP.to_owned()),
    );
    if let Some(langs) = langs {
        obj.insert(
            "langs".to_owned(),
            JsonValue::Array(
                langs
                    .into_iter()
                    .map(|s| JsonValue::String(s.to_owned()))
                    .collect(),
            ),
        );
    }
    JsonValue::Object(obj)
}

fn mock_post_view(
    record: JsonValue,
    author: JsonValue,
    embed: Option<JsonValue>,
    labels: Option<Vec<JsonValue>>,
) -> PostView {
    let did = author.get("did").and_then(JsonValue::as_str).unwrap_or("");
    let mut obj = serde_json::Map::new();
    obj.insert(
        "$type".to_owned(),
        JsonValue::String("app.bsky.feed.defs#postView".to_owned()),
    );
    obj.insert(
        "uri".to_owned(),
        JsonValue::String(format!("at://{did}/app.bsky.feed.post/fake")),
    );
    obj.insert("cid".to_owned(), JsonValue::String(FAKE_CID.to_owned()));
    obj.insert("author".to_owned(), author);
    obj.insert("record".to_owned(), record);
    obj.insert(
        "indexedAt".to_owned(),
        JsonValue::String(TIMESTAMP.to_owned()),
    );
    if let Some(e) = embed {
        obj.insert("embed".to_owned(), e);
    }
    if let Some(l) = labels {
        obj.insert("labels".to_owned(), JsonValue::Array(l));
    }
    serde_json::from_value(JsonValue::Object(obj)).expect("valid mock PostView")
}

fn mock_embed_record_view(
    record: JsonValue,
    author: JsonValue,
    labels: Option<Vec<JsonValue>>,
) -> JsonValue {
    let did = author.get("did").and_then(JsonValue::as_str).unwrap_or("");
    let mut view_record = serde_json::Map::new();
    view_record.insert(
        "$type".to_owned(),
        JsonValue::String("app.bsky.embed.record#viewRecord".to_owned()),
    );
    view_record.insert(
        "uri".to_owned(),
        JsonValue::String(format!("at://{did}/app.bsky.feed.post/fake")),
    );
    view_record.insert("cid".to_owned(), JsonValue::String(FAKE_CID.to_owned()));
    view_record.insert("author".to_owned(), author);
    view_record.insert("value".to_owned(), record);
    view_record.insert(
        "indexedAt".to_owned(),
        JsonValue::String(TIMESTAMP.to_owned()),
    );
    if let Some(l) = labels {
        view_record.insert("labels".to_owned(), JsonValue::Array(l));
    }
    json!({
        "$type": "app.bsky.embed.record#view",
        "record": JsonValue::Object(view_record),
    })
}

fn mock_list_view_basic(name: &str) -> JsonValue {
    json!({
        "uri": "at://did:plc:fake/app.bsky.graph.list/fake",
        "cid": FAKE_CID,
        "name": name,
        "purpose": "app.bsky.graph.defs#modlist",
        "indexedAt": TIMESTAMP,
    })
}

fn dt_now() -> Datetime {
    TIMESTAMP.parse::<Datetime>().expect("valid timestamp")
}

// MARK: 1. Behavior Matrix (`behaviors.json`)

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
#[allow(clippy::struct_excessive_bools)]
struct BehaviorUser {
    blocking: bool,
    blocking_by_list: bool,
    blocked_by: bool,
    muted: bool,
    muted_by_list: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct BehaviorConfig {
    authed: Option<bool>,
    adult_content_enabled: Option<bool>,
    settings: Option<HashMap<String, String>>,
}

#[derive(Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BehaviorLabels {
    post: Option<Vec<String>>,
    profile: Option<Vec<String>>,
    account: Option<Vec<String>>,
    quoted_post: Option<Vec<String>>,
    quoted_account: Option<Vec<String>>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct BehaviorScenario {
    name: String,
    cfg: String,
    subject: String,
    author: String,
    quote_author: Option<String>,
    labels: BehaviorLabels,
    behaviors: ExpectedBehaviors,
}

#[derive(Deserialize)]
struct BehaviorSuite {
    users: HashMap<String, BehaviorUser>,
    configurations: HashMap<String, BehaviorConfig>,
    scenarios: Vec<BehaviorScenario>,
}

impl BehaviorSuite {
    fn build_profile(
        &self,
        name: &str,
        account: Option<&[String]>,
        profile: Option<&[String]>,
    ) -> JsonValue {
        let user = self.users.get(name).expect("known user");
        let mut labels = Vec::new();
        for val in account.unwrap_or(&[]) {
            labels.push(mock_label(val, &format!("did:web:{name}"), FAKE_LABELER));
        }
        for val in profile.unwrap_or(&[]) {
            labels.push(mock_label(
                val,
                &format!("at://did:web:{name}/app.bsky.actor.profile/self"),
                FAKE_LABELER,
            ));
        }
        let mut viewer = serde_json::Map::new();
        viewer.insert(
            "muted".to_owned(),
            JsonValue::Bool(user.muted || user.muted_by_list),
        );
        viewer.insert("blockedBy".to_owned(), JsonValue::Bool(user.blocked_by));
        if user.muted_by_list {
            viewer.insert("mutedByList".to_owned(), mock_list_view_basic("Fake List"));
        }
        if user.blocking || user.blocking_by_list {
            viewer.insert(
                "blocking".to_owned(),
                JsonValue::String("at://did:web:self.test/app.bsky.graph.block/fake".to_owned()),
            );
        }
        if user.blocking_by_list {
            viewer.insert(
                "blockingByList".to_owned(),
                mock_list_view_basic("Fake List"),
            );
        }
        mock_profile(
            &format!("{name}.test"),
            None,
            Some(JsonValue::Object(viewer)),
            Some(labels),
        )
    }

    fn options(&self, scenario: &BehaviorScenario) -> ModerationOptions {
        let cfg = self.configurations.get(&scenario.cfg).expect("known cfg");
        let mut labels = HashMap::new();
        if let Some(settings) = &cfg.settings {
            for (k, v) in settings {
                labels.insert(k.clone(), LabelPreference::parse(v).expect("valid pref"));
            }
        }
        let user_did = if cfg.authed == Some(false) {
            None
        } else {
            Some("did:web:self.test".parse::<Did>().unwrap())
        };
        ModerationOptions::new(
            user_did,
            ModerationPrefs {
                adult_content_enabled: cfg.adult_content_enabled.unwrap_or(false),
                labels,
                labelers: vec![ModerationPrefsLabeler::new(
                    FAKE_LABELER.parse::<Did>().unwrap(),
                )],
                muted_words: Vec::new(),
                hidden_posts: Vec::new(),
            },
        )
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn moderation_behaviors_matrix_matches_vectors() {
    let suite: BehaviorSuite = serde_json::from_str(include_str!(
        "../../../Tests/PetrelTests/Vectors/moderation/behaviors.json"
    ))
    .expect("valid behaviors json");
    assert_eq!(suite.users.len(), 8);
    assert_eq!(suite.configurations.len(), 13);
    assert_eq!(suite.scenarios.len(), 67);

    let now = dt_now();
    for scenario in suite.scenarios.iter().filter(|s| !s.name.starts_with("//")) {
        let opts = suite.options(scenario);
        if scenario.subject == "profile" {
            let prof_json = suite.build_profile(
                &scenario.author,
                scenario.labels.account.as_deref(),
                scenario.labels.profile.as_deref(),
            );
            let prof: ProfileViewBasic =
                serde_json::from_value(prof_json).expect("valid ProfileViewBasic");
            let decision = Moderation::moderate_profile(&prof, &opts);
            expect_results(
                &decision,
                &scenario.behaviors,
                &scenario.name,
                &ModerationContext::ALL,
            );
        } else {
            let author = suite.build_profile(
                &scenario.author,
                scenario.labels.account.as_deref(),
                scenario.labels.profile.as_deref(),
            );
            let author_did = author
                .get("did")
                .and_then(JsonValue::as_str)
                .unwrap_or("")
                .to_owned();
            let post_uri = format!("at://{author_did}/app.bsky.feed.post/fake");
            let embed = scenario.quote_author.as_ref().map(|qa| {
                let q_labels: Vec<JsonValue> = scenario
                    .labels
                    .quoted_post
                    .as_deref()
                    .unwrap_or(&[])
                    .iter()
                    .map(|val| mock_label(val, &post_uri, FAKE_LABELER))
                    .collect();
                mock_embed_record_view(
                    mock_post("Quoted post text", Some(vec!["en"])),
                    suite.build_profile(qa, scenario.labels.quoted_account.as_deref(), None),
                    Some(q_labels),
                )
            });
            let post_labels: Vec<JsonValue> = scenario
                .labels
                .post
                .as_deref()
                .unwrap_or(&[])
                .iter()
                .map(|val| mock_label(val, &post_uri, FAKE_LABELER))
                .collect();
            let post = mock_post_view(
                mock_post("Post text", Some(vec!["en"])),
                author,
                embed,
                Some(post_labels),
            );
            let decision = Moderation::moderate_post(&post, &opts, &now);
            let post_contexts = [
                ModerationContext::Avatar,
                ModerationContext::Banner,
                ModerationContext::DisplayName,
                ModerationContext::ContentList,
                ModerationContext::ContentView,
                ModerationContext::ContentMedia,
            ];
            expect_results(
                &decision,
                &scenario.behaviors,
                &scenario.name,
                &post_contexts,
            );
        }
    }
}

// MARK: 2. Custom Labels & Quote Posts (`custom-labels.json`, `quoteposts.json`)

#[derive(Deserialize)]
struct CustomLabelScenario {
    blurs: String,
    severity: String,
    account: ExpectedBehaviors,
    profile: ExpectedBehaviors,
    post: ExpectedBehaviors,
}

fn custom_label_options(blurs: &str, severity: &str) -> ModerationOptions {
    let labeler: Did = "did:web:labeler.test".parse().unwrap();
    let def_raw = json!({
        "identifier": "custom",
        "blurs": blurs,
        "severity": severity,
        "defaultSetting": "warn",
        "locales": [],
    });
    let def: LabelValueDefinition = serde_json::from_value(def_raw).unwrap();
    let interpreted = interpret_label_value_definition(&def, Some(labeler.clone()));
    let mut opts = ModerationOptions::new(
        Some("did:web:alice.test".parse().unwrap()),
        ModerationPrefs {
            adult_content_enabled: true,
            labels: HashMap::new(),
            labelers: vec![ModerationPrefsLabeler::with_labels(
                labeler.clone(),
                HashMap::from([("custom".to_owned(), LabelPreference::Hide)]),
            )],
            muted_words: Vec::new(),
            hidden_posts: Vec::new(),
        },
    );
    opts.label_defs.insert(labeler, vec![interpreted]);
    opts
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[allow(clippy::too_many_lines)]
fn moderation_custom_labels_and_quoteposts_match_vectors() {
    let custom: Vec<CustomLabelScenario> = serde_json::from_str(include_str!(
        "../../../Tests/PetrelTests/Vectors/moderation/custom-labels.json"
    ))
    .unwrap();
    let quotes: Vec<CustomLabelScenario> = serde_json::from_str(include_str!(
        "../../../Tests/PetrelTests/Vectors/moderation/quoteposts.json"
    ))
    .unwrap();
    assert_eq!(custom.len(), 9);
    assert_eq!(quotes.len(), 9);

    let now = dt_now();
    let labeler = "did:web:labeler.test";

    for row in &custom {
        let opts = custom_label_options(&row.blurs, &row.severity);
        for (target, expected) in [
            ("post", &row.post),
            ("profile", &row.profile),
            ("account", &row.account),
        ] {
            let decision = match target {
                "post" => {
                    let pv = mock_post_view(
                        mock_post("Hello", None),
                        mock_profile("bob.test", Some("Bob"), None, None),
                        None,
                        Some(vec![mock_label(
                            "custom",
                            "at://did:web:bob.test/app.bsky.feed.post/fake",
                            labeler,
                        )]),
                    );
                    Moderation::moderate_post(&pv, &opts, &now)
                }
                "profile" => {
                    let p: ProfileViewBasic = serde_json::from_value(mock_profile(
                        "bob.test",
                        Some("Bob"),
                        None,
                        Some(vec![mock_label(
                            "custom",
                            "at://did:web:bob.test/app.bsky.actor.profile/self",
                            labeler,
                        )]),
                    ))
                    .unwrap();
                    Moderation::moderate_profile(&p, &opts)
                }
                _ => {
                    let p: ProfileViewBasic = serde_json::from_value(mock_profile(
                        "bob.test",
                        Some("Bob"),
                        None,
                        Some(vec![mock_label("custom", "did:web:bob.test", labeler)]),
                    ))
                    .unwrap();
                    Moderation::moderate_profile(&p, &opts)
                }
            };
            expect_results(
                &decision,
                expected,
                &format!("custom({}, {}, {})", row.blurs, row.severity, target),
                &ModerationContext::ALL,
            );
        }
    }

    for row in &quotes {
        let opts = custom_label_options(&row.blurs, &row.severity);
        for (target, expected) in [
            ("post", &row.post),
            ("profile", &row.profile),
            ("account", &row.account),
        ] {
            let (post_labels, profile_labels) = match target {
                "post" => (
                    Some(vec![mock_label(
                        "custom",
                        "at://did:web:carla.test/app.bsky.feed.post/fake",
                        labeler,
                    )]),
                    None,
                ),
                "profile" => (
                    None,
                    Some(vec![mock_label(
                        "custom",
                        "at://did:web:carla.test/app.bsky.actor.profile/self",
                        labeler,
                    )]),
                ),
                _ => (
                    None,
                    Some(vec![mock_label("custom", "did:web:carla.test", labeler)]),
                ),
            };
            let pv = mock_post_view(
                mock_post("Hello", None),
                mock_profile("bob.test", Some("Bob"), None, None),
                Some(mock_embed_record_view(
                    mock_post("Quoted post text", Some(vec!["en"])),
                    mock_profile("carla.test", Some("Carla"), None, profile_labels),
                    post_labels,
                )),
                None,
            );
            let decision = Moderation::moderate_post(&pv, &opts, &now);
            expect_results(
                &decision,
                expected,
                &format!("quote({}, {}, {})", row.blurs, row.severity, target),
                &ModerationContext::ALL,
            );
        }
    }
}

// MARK: 3. Built-in Label Definitions (`labels.json`)

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct VectorLabelDef {
    identifier: String,
    alias: Option<Vec<String>>,
    configurable: bool,
    default_setting: String,
    flags: Vec<String>,
    severity: String,
    blurs: String,
    behaviors: VectorLabelBehaviors,
}

#[derive(Deserialize)]
struct VectorLabelBehaviors {
    account: Option<HashMap<String, String>>,
    profile: Option<HashMap<String, String>>,
    content: Option<HashMap<String, String>>,
}

fn ctx_key(ctx: ModerationContext) -> &'static str {
    match ctx {
        ModerationContext::ProfileList => "profileList",
        ModerationContext::ProfileView => "profileView",
        ModerationContext::Avatar => "avatar",
        ModerationContext::Banner => "banner",
        ModerationContext::DisplayName => "displayName",
        ModerationContext::ContentList => "contentList",
        ModerationContext::ContentView => "contentView",
        ModerationContext::ContentMedia => "contentMedia",
    }
}

fn expect_behavior_map(actual: ModerationBehavior, expected: Option<&HashMap<String, String>>) {
    for ctx in ModerationContext::ALL {
        let actual_str = actual.action(ctx).map(|a| match a {
            petrel_bsky::ModerationAction::Blur => "blur",
            petrel_bsky::ModerationAction::Alert => "alert",
            petrel_bsky::ModerationAction::Inform => "inform",
        });
        let expected_str = expected.and_then(|m| m.get(ctx_key(ctx)).map(String::as_str));
        assert_eq!(actual_str, expected_str, "context {}", ctx_key(ctx));
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn moderation_builtin_label_definitions_match_labels_json() {
    let defs: Vec<VectorLabelDef> = serde_json::from_str(include_str!(
        "../../../Tests/PetrelTests/Vectors/moderation/labels.json"
    ))
    .unwrap();
    assert_eq!(defs.len(), 7);
    let builtins = builtin_label_definitions();
    let mut expected_ids = BTreeSet::new();

    for def in &defs {
        expected_ids.insert(def.identifier.clone());
        let mut all_ids = vec![def.identifier.clone()];
        if let Some(aliases) = &def.alias {
            for a in aliases {
                expected_ids.insert(a.clone());
                all_ids.push(a.clone());
            }
        }
        for id in all_ids {
            let actual = builtins.get(&id).expect("missing built-in definition");
            assert_eq!(actual.identifier, id);
            assert_eq!(actual.configurable, def.configurable);
            assert_eq!(actual.default_setting.as_str(), def.default_setting);
            assert_eq!(actual.severity, def.severity);
            assert_eq!(actual.blurs, def.blurs);
            assert_eq!(
                actual.locales,
                [] as [petrel_api::generated::com::atproto::label::defs::LabelValueDefinitionStrings; 0]
            );
            assert!(actual.defined_by.is_none());
            let flag_strs: Vec<&str> = actual
                .flags
                .iter()
                .map(|f| match f {
                    petrel_bsky::LabelValueDefinitionFlag::NoOverride => "no-override",
                    petrel_bsky::LabelValueDefinitionFlag::Adult => "adult",
                    petrel_bsky::LabelValueDefinitionFlag::Unauthed => "unauthed",
                    petrel_bsky::LabelValueDefinitionFlag::NoSelf => "no-self",
                })
                .collect();
            assert_eq!(flag_strs, def.flags);
            expect_behavior_map(actual.behaviors.account, def.behaviors.account.as_ref());
            expect_behavior_map(actual.behaviors.profile, def.behaviors.profile.as_ref());
            expect_behavior_map(actual.behaviors.content, def.behaviors.content.as_ref());
        }
    }

    let actual_ids: BTreeSet<String> = builtins.keys().cloned().collect();
    assert_eq!(actual_ids, expected_ids);

    let defaults = known_labels::default_settings();
    for def in &defs {
        if def.configurable {
            assert_eq!(
                defaults
                    .get(&def.identifier)
                    .map(petrel_bsky::LabelPreference::as_str),
                Some(def.default_setting.as_str())
            );
        }
    }
}

// MARK: 4. Subjects (Notification, FeedGenerator, UserList, Hidden) & Mute Words

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[allow(clippy::too_many_lines)]
fn moderation_subjects_and_mute_words() {
    let labeler: Did = "did:web:labeler.test".parse().unwrap();
    let opts = ModerationOptions::new(
        Some("did:web:alice.test".parse().unwrap()),
        ModerationPrefs {
            adult_content_enabled: false,
            labels: HashMap::new(),
            labelers: vec![ModerationPrefsLabeler::new(labeler)],
            muted_words: Vec::new(),
            hidden_posts: vec![
                "at://did:web:bob.test/app.bsky.feed.post/fake"
                    .parse::<AtUri>()
                    .unwrap(),
            ],
        },
    );

    // Notification
    let notif: Notification = serde_json::from_value(json!({
        "uri": "at://did:web:bob.test/app.bsky.feed.post/fake",
        "cid": FAKE_CID,
        "author": mock_profile("bob.test", None, Some(json!({"muted": true})), None),
        "reason": "reply",
        "reasonSubject": "at://did:web:bob.test/app.bsky.feed.post/fake-parent",
        "record": mock_post("Reply", Some(vec!["en"])),
        "isRead": false,
        "indexedAt": TIMESTAMP,
        "labels": [mock_label("!hide", "at://did:web:bob.test/app.bsky.feed.post/fake", "did:web:labeler.test")],
    }))
    .unwrap();
    let d_notif = Moderation::moderate_notification(&notif, &opts);
    assert_eq!(
        d_notif
            .causes
            .iter()
            .map(petrel_bsky::ModerationCause::cause_type)
            .collect::<Vec<_>>(),
        vec![ModerationCauseType::Label, ModerationCauseType::Muted]
    );
    expect_ui(
        &d_notif.ui(ModerationContext::ContentList),
        Some(&[
            "filter".to_owned(),
            "blur".to_owned(),
            "noOverride".to_owned(),
        ]),
        "notif contentList",
    );

    // Feed generator
    let feed_gen: GeneratorView = serde_json::from_value(json!({
        "uri": "at://did:web:bob.test/app.bsky.feed.generator/fake",
        "cid": FAKE_CID,
        "did": "did:web:feed.test",
        "creator": mock_profile("bob.test", None, Some(json!({"blocking": "at://did:web:alice.test/app.bsky.graph.block/1"})), None),
        "displayName": "Fake feed",
        "indexedAt": TIMESTAMP,
        "labels": [],
    }))
    .unwrap();
    let d_gen = Moderation::moderate_feed_generator(&feed_gen, &opts);
    assert!(d_gen.blocked());
    assert!(d_gen.ui(ModerationContext::ContentList).filter());

    // User lists (`ListViewBasic` vs `ListView`)
    let list_basic: ListViewBasic = serde_json::from_value(json!({
        "uri": "at://did:web:bob.test/app.bsky.graph.list/fake",
        "cid": FAKE_CID,
        "name": "List",
        "purpose": "app.bsky.graph.defs#curatelist",
        "indexedAt": TIMESTAMP,
        "labels": [mock_label("!warn", "at://did:web:bob.test/app.bsky.graph.list/fake", "did:web:labeler.test")],
    }))
    .unwrap();
    let d_list_basic = Moderation::moderate_user_list(&list_basic, &opts);
    assert!(d_list_basic.ui(ModerationContext::ContentList).blur());

    let list_full: ListView = serde_json::from_value(json!({
        "uri": "at://did:web:bob.test/app.bsky.graph.list/fake",
        "cid": FAKE_CID,
        "creator": mock_profile("bob.test", None, Some(json!({"muted": true})), None),
        "name": "List",
        "purpose": "app.bsky.graph.defs#curatelist",
        "indexedAt": TIMESTAMP,
    }))
    .unwrap();
    let d_list_full = Moderation::moderate_user_list(&list_full, &opts);
    assert!(d_list_full.muted());

    // Hidden post
    let hidden_post = mock_post_view(
        mock_post("Post", Some(vec!["en"])),
        mock_profile("bob.test", None, None, None),
        None,
        None,
    );
    let d_hidden = Moderation::moderate_post(&hidden_post, &opts, &dt_now());
    assert!(d_hidden.ui(ModerationContext::ContentList).filter());
    assert!(d_hidden.ui(ModerationContext::ContentView).blur());

    // Muted words: punctuation splitting, slash protection (`and/or` != `andor`), language exception (`ja`), tag match
    let mut mute_super = MutedWord::new("super".to_owned(), vec![MutedWordTarget::Content]);
    mute_super.actor_target = Some("all".to_owned());
    assert_eq!(
        match_mute_words(
            &[mute_super.clone()],
            "This is super-bad!",
            None,
            None,
            None,
            None,
            &dt_now(),
        )
        .len(),
        1
    );

    let mute_andor = MutedWord::new("andor".to_owned(), vec![MutedWordTarget::Content]);
    assert_eq!(
        match_mute_words(
            &[mute_andor],
            "This and/or that",
            None,
            None,
            None,
            None,
            &dt_now(),
        ),
        [] as [petrel_bsky::MuteWordMatch; 0]
    );

    let mute_single = MutedWord::new("希".to_owned(), vec![MutedWordTarget::Content]);
    assert_eq!(
        match_mute_words(
            &[mute_single],
            "希望",
            None,
            None,
            Some(&["ja".to_owned()]),
            None,
            &dt_now(),
        )
        .len(),
        1
    );

    let mute_tag = MutedWord::new("secret".to_owned(), vec![MutedWordTarget::Tag]);
    let tag_facets = vec![Facet::new(
        ByteSlice::new(0, 7),
        vec![FacetFeatures::Tag(Box::new(Tag::new("secret".to_owned())))],
    )];
    assert_eq!(
        match_mute_words(
            &[mute_tag],
            "#secret post",
            Some(&tag_facets),
            None,
            None,
            None,
            &dt_now(),
        )
        .len(),
        1
    );
}
