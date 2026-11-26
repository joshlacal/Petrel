use petrel_core::{
    Datetime, Did, Nsid, ToValue, Value, XrpcMethod, XrpcRequest, from_dag_cbor, from_json,
    to_dag_cbor, to_json,
};
use petrel_ozone::generated::tools::ozone::communication::defs::TemplateView;
use petrel_ozone::generated::tools::ozone::moderation::defs::{
    ModEventComment, ModEventView, ModEventViewEvent, ModEventViewSubject,
};
use petrel_ozone::generated::tools::ozone::moderation::emit_event::{
    EmitEvent, Input as EmitEventInput, InputEvent, InputSubject,
};
use petrel_ozone::generated::tools::ozone::setting::defs::OptionDef;
use petrel_ozone::generated::tools::ozone::signature::defs::SigDetail;

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn emit_event_metadata_and_cross_crate_refs() {
    assert_eq!(EmitEvent::NSID, "tools.ozone.moderation.emitEvent");
    assert_eq!(EmitEvent::METHOD, XrpcMethod::Procedure);
    assert_eq!(EmitEvent::INPUT_ENCODING, Some("application/json"));
    assert_eq!(EmitEvent::OUTPUT_ENCODING, Some("application/json"));

    let mut comment = ModEventComment::new();
    comment.comment = Some("Escalated for review".to_owned());
    comment.sticky = Some(true);

    let repo_ref = petrel_api::generated::com::atproto::admin::defs::RepoRef::new(
        Did::parse("did:plc:alice").unwrap(),
    );

    let input = EmitEventInput::new(
        InputEvent::ModEventComment(Box::new(comment)),
        InputSubject::RepoRef(Box::new(repo_ref)),
        Did::parse("did:plc:moderator").unwrap(),
    );

    let json_bytes = to_json(&input).expect("serialize emitEvent input");
    let decoded: EmitEventInput = from_json(&json_bytes).expect("deserialize emitEvent input");
    assert_eq!(decoded, input);

    let cbor_bytes = to_dag_cbor(&input).expect("encode DAG-CBOR emitEvent input");
    let cbor_decoded: EmitEventInput =
        from_dag_cbor(&cbor_bytes).expect("decode DAG-CBOR emitEvent input");
    assert_eq!(cbor_decoded, input);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn mod_event_view_roundtrip() {
    let mut comment = ModEventComment::new();
    comment.comment = Some("Clean".to_owned());

    let repo_ref = petrel_api::generated::com::atproto::admin::defs::RepoRef::new(
        Did::parse("did:plc:bob").unwrap(),
    );

    let view = ModEventView::new(
        42,
        ModEventViewEvent::ModEventComment(Box::new(comment)),
        ModEventViewSubject::RepoRef(Box::new(repo_ref)),
        vec![],
        Did::parse("did:plc:mod1").unwrap(),
        Datetime::parse("2025-05-01T12:00:00Z").unwrap(),
    );

    let json = to_json(&view).expect("serialize ModEventView");
    let round_tripped: ModEventView = from_json(&json).expect("deserialize ModEventView");
    assert_eq!(round_tripped, view);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn setting_option_def_avoids_prelude_shadowing_and_roundtrips() {
    let option = OptionDef::new(
        Nsid::parse("tools.ozone.setting.example").unwrap(),
        Did::parse("did:plc:service").unwrap(),
        Value::String("enabled".to_owned()),
        "instance".to_owned(),
        Did::parse("did:plc:admin1").unwrap(),
        Did::parse("did:plc:admin2").unwrap(),
    );

    let value = option.to_value().expect("to_value OptionDef");
    let json = to_json(&value).expect("to_json OptionDef");
    let decoded: OptionDef = from_json(&json).expect("from_json OptionDef");
    assert_eq!(decoded, option);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn communication_and_signature_defs_roundtrip() {
    let tmpl = TemplateView::new(
        "tpl-1".to_owned(),
        "Warning".to_owned(),
        "Please review guidelines.".to_owned(),
        false,
        Did::parse("did:plc:mod").unwrap(),
        Datetime::parse("2025-01-01T00:00:00Z").unwrap(),
        Datetime::parse("2025-01-02T00:00:00Z").unwrap(),
    );
    let json = to_json(&tmpl).expect("serialize TemplateView");
    let decoded_tmpl: TemplateView = from_json(&json).expect("deserialize TemplateView");
    assert_eq!(decoded_tmpl, tmpl);

    let sig = SigDetail::new("emailDomain".to_owned(), "example.com".to_owned());
    let sig_json = to_json(&sig).expect("serialize SigDetail");
    let decoded_sig: SigDetail = from_json(&sig_json).expect("deserialize SigDetail");
    assert_eq!(decoded_sig, sig);
}
