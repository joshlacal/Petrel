//! The serialization spike for the Petrel Rust program (Lane 0).
//!
//! Plan decision 4 says generated types get hand-written `Serialize` and
//! `Deserialize` impls through a petrel-core helper, never
//! `#[serde(flatten)]` and never a derive on objects. The whole generator
//! rests on that, so this file proves it before anyone builds on it.
//!
//! The three type groups below are written by hand **exactly as the generator
//! will emit them**, using only petrel-core's public API:
//!
//! - (a) a record with an open union, a blob, a cid-link, bytes and
//!   `extra_data` ([`spike::Post`]);
//! - (b) a query with parameters and a declared error enum
//!   ([`spike::GetPosts`]);
//! - (c) an object with required-nullable, optional-nullable and plain
//!   optional fields ([`spike::Tri`]).
//!
//! Run with `cargo test -p petrel-core spike`.

// The types are spelled the way generated code spells them, `pub` included.
#![allow(unreachable_pub)]

mod spike {
    use std::collections::BTreeMap;

    use petrel_core::unknown::{tagged, type_of};
    use petrel_core::xrpc::{XrpcErrorBody, push_array_param, push_optional_param, push_param};
    use petrel_core::{
        AtUri, Blob, Bytes, CidLink, Collection, DagCborError, Datetime, DeclaredXrpcError,
        DecodeError, EncodeError, FromValue, Language, Nullable, ObjectReader, ObjectWriter,
        RecordKeyType, ToQueryParams, ToValue, Value, XrpcMethod, XrpcOutput, XrpcRequest, dagcbor,
        from_dag_cbor, from_json, to_dag_cbor, to_json,
    };

    const DAG_CID: &str = "bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a";
    const RAW_CID: &str = "bafkreiccldh766hwcnuxnf2wh6jgzepf2nlu2lvcllt63eww5p6chi4ity";

    /// The serde impls the generator writes for every type: two delegations.
    macro_rules! generated_serde_impls {
        ($($ty:ty),+ $(,)?) => {$(
            impl serde::Serialize for $ty {
                fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
                    petrel_core::serde_bridge::serialize(self, serializer)
                }
            }

            impl<'de> serde::Deserialize<'de> for $ty {
                fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
                    petrel_core::serde_bridge::deserialize(deserializer)
                }
            }
        )+};
    }

    // ---------------------------------------------------------------------
    // (a) app.example.embed.images: a named object def with a blob.
    // ---------------------------------------------------------------------

    #[derive(Debug, Clone, PartialEq)]
    pub struct Images {
        pub alt: String,
        pub image: Blob,
        pub extra_data: Option<BTreeMap<String, Value>>,
    }

    impl ToValue for Images {
        fn to_value(&self) -> Result<Value, EncodeError> {
            let mut writer = ObjectWriter::new();
            writer.field("alt", &self.alt)?;
            writer.field("image", &self.image)?;
            writer.extra(self.extra_data.as_ref());
            Ok(writer.finish())
        }
    }

    impl FromValue for Images {
        fn from_value(value: Value) -> Result<Self, DecodeError> {
            let mut reader = ObjectReader::new(value)?;
            Ok(Self {
                alt: reader.required("alt")?,
                image: reader.required("image")?,
                extra_data: reader.finish(),
            })
        }
    }

    // ---------------------------------------------------------------------
    // (a) app.example.like: a record, also used as a union member.
    // ---------------------------------------------------------------------

    #[derive(Debug, Clone, PartialEq)]
    pub struct Like {
        pub subject: AtUri,
        pub created_at: Datetime,
        pub extra_data: Option<BTreeMap<String, Value>>,
    }

    impl Collection for Like {
        const NSID: &'static str = "app.example.like";
        const KEY: RecordKeyType = RecordKeyType::Tid;
    }

    impl ToValue for Like {
        fn to_value(&self) -> Result<Value, EncodeError> {
            let mut writer = ObjectWriter::with_type("app.example.like");
            writer.field("subject", &self.subject)?;
            writer.field("createdAt", &self.created_at)?;
            writer.extra(self.extra_data.as_ref());
            Ok(writer.finish())
        }
    }

    impl FromValue for Like {
        fn from_value(value: Value) -> Result<Self, DecodeError> {
            let mut reader = ObjectReader::new(value)?;
            Ok(Self {
                subject: reader.required("subject")?,
                created_at: reader.required("createdAt")?,
                extra_data: reader.finish(),
            })
        }
    }

    // ---------------------------------------------------------------------
    // (a) app.example.post#embed: an open union.
    // ---------------------------------------------------------------------

    #[derive(Debug, Clone, PartialEq)]
    pub enum PostEmbed {
        Images(Box<Images>),
        Like(Box<Like>),
        /// A member this build does not know: the whole raw object.
        Unknown(Value),
    }

    impl ToValue for PostEmbed {
        fn to_value(&self) -> Result<Value, EncodeError> {
            match self {
                Self::Images(member) => tagged(member.to_value()?, "app.example.embed.images"),
                Self::Like(member) => tagged(member.to_value()?, "app.example.like"),
                Self::Unknown(raw) => Ok(raw.clone()),
            }
        }
    }

    impl FromValue for PostEmbed {
        fn from_value(value: Value) -> Result<Self, DecodeError> {
            match type_of(&value)? {
                "app.example.embed.images" => FromValue::from_value(value).map(Self::Images),
                "app.example.like" => FromValue::from_value(value).map(Self::Like),
                _ => Ok(Self::Unknown(value)),
            }
        }
    }

    // ---------------------------------------------------------------------
    // (a) app.example.post: the record.
    // ---------------------------------------------------------------------

    #[derive(Debug, Clone, PartialEq)]
    pub struct Post {
        pub text: String,
        pub created_at: Datetime,
        pub edited_at: Option<Datetime>,
        pub embed: Option<PostEmbed>,
        pub thumb: Option<Blob>,
        pub root: Option<CidLink>,
        pub sig: Option<Bytes>,
        pub langs: Option<Vec<Language>>,
        pub like_count: Option<i64>,
        pub extra_data: Option<BTreeMap<String, Value>>,
    }

    impl Post {
        pub fn new(text: String, created_at: Datetime) -> Self {
            Self {
                text,
                created_at,
                edited_at: None,
                embed: None,
                thumb: None,
                root: None,
                sig: None,
                langs: None,
                like_count: None,
                extra_data: None,
            }
        }
    }

    impl Collection for Post {
        const NSID: &'static str = "app.example.post";
        const KEY: RecordKeyType = RecordKeyType::Tid;
    }

    impl ToValue for Post {
        fn to_value(&self) -> Result<Value, EncodeError> {
            let mut writer = ObjectWriter::with_type("app.example.post");
            writer.field("text", &self.text)?;
            writer.field("createdAt", &self.created_at)?;
            writer.optional("editedAt", &self.edited_at)?;
            writer.optional("embed", &self.embed)?;
            writer.optional("thumb", &self.thumb)?;
            writer.optional("root", &self.root)?;
            writer.optional("sig", &self.sig)?;
            writer.optional("langs", &self.langs)?;
            writer.optional("likeCount", &self.like_count)?;
            writer.extra(self.extra_data.as_ref());
            Ok(writer.finish())
        }
    }

    impl FromValue for Post {
        fn from_value(value: Value) -> Result<Self, DecodeError> {
            let mut reader = ObjectReader::new(value)?;
            Ok(Self {
                text: reader.required("text")?,
                created_at: reader.required("createdAt")?,
                edited_at: reader.optional("editedAt"),
                embed: reader.optional("embed"),
                thumb: reader.optional("thumb"),
                root: reader.optional("root"),
                sig: reader.optional("sig"),
                langs: reader.optional("langs"),
                like_count: reader.optional("likeCount"),
                extra_data: reader.finish(),
            })
        }
    }

    // ---------------------------------------------------------------------
    // (b) app.example.getPosts: a query.
    // ---------------------------------------------------------------------

    #[derive(Debug, Clone, PartialEq)]
    pub struct GetPostsParams {
        pub uris: Vec<AtUri>,
        pub include_replies: Option<bool>,
        /// Lexicon default 50. A default is part of the value and is sent.
        pub limit: i64,
    }

    impl GetPostsParams {
        pub fn new(uris: Vec<AtUri>) -> Self {
            Self {
                uris,
                include_replies: None,
                limit: 50,
            }
        }
    }

    impl ToQueryParams for GetPostsParams {
        fn to_query_params(&self, out: &mut Vec<(&'static str, String)>) {
            push_array_param(out, "uris", &self.uris);
            push_optional_param(out, "includeReplies", self.include_replies.as_ref());
            push_param(out, "limit", &self.limit);
        }
    }

    /// XRPC outputs decode leniently but keep no `extra_data`.
    #[derive(Debug, Clone, PartialEq)]
    pub struct GetPostsOutput {
        pub posts: Vec<Post>,
        pub cursor: Option<String>,
    }

    impl ToValue for GetPostsOutput {
        fn to_value(&self) -> Result<Value, EncodeError> {
            let mut writer = ObjectWriter::new();
            writer.field("posts", &self.posts)?;
            writer.optional("cursor", &self.cursor)?;
            Ok(writer.finish())
        }
    }

    impl FromValue for GetPostsOutput {
        fn from_value(value: Value) -> Result<Self, DecodeError> {
            let mut reader = ObjectReader::new(value)?;
            Ok(Self {
                posts: reader.required("posts")?,
                cursor: reader.optional("cursor"),
            })
        }
    }

    impl XrpcOutput for GetPostsOutput {
        fn from_body(body: &[u8]) -> Result<Self, DecodeError> {
            from_json(body)
        }
    }

    #[derive(Debug, Clone, PartialEq, Eq)]
    pub enum GetPostsError {
        NotFound,
        BlockedActor,
        /// A name the lexicon does not declare, as the server sent it.
        Unknown(String),
    }

    impl DeclaredXrpcError for GetPostsError {
        fn from_wire_name(name: &str) -> Self {
            match name {
                "NotFound" => Self::NotFound,
                "BlockedActor" => Self::BlockedActor,
                other => Self::Unknown(other.to_owned()),
            }
        }

        fn wire_name(&self) -> &str {
            match self {
                Self::NotFound => "NotFound",
                Self::BlockedActor => "BlockedActor",
                Self::Unknown(name) => name,
            }
        }

        fn is_declared(&self) -> bool {
            !matches!(self, Self::Unknown(_))
        }
    }

    #[derive(Debug)]
    pub struct GetPosts;

    impl XrpcRequest for GetPosts {
        const NSID: &'static str = "app.example.getPosts";
        const METHOD: XrpcMethod = XrpcMethod::Query;
        const INPUT_ENCODING: Option<&'static str> = None;
        const OUTPUT_ENCODING: Option<&'static str> = Some("application/json");
        type Params = GetPostsParams;
        type Input = ();
        type Output = GetPostsOutput;
        type Error = GetPostsError;
    }

    // ---------------------------------------------------------------------
    // (c) app.example.defs#tri: the three kinds of "may be missing".
    // ---------------------------------------------------------------------

    #[derive(Debug, Clone, PartialEq)]
    pub struct Tri {
        /// Required and nullable: the key is always present, maybe `null`.
        pub pinned: Option<AtUri>,
        /// Optional and nullable: absent, `null`, or a value.
        pub swap_record: Option<Nullable<CidLink>>,
        /// Optional: absent or a value.
        pub note: Option<String>,
        pub extra_data: Option<BTreeMap<String, Value>>,
    }

    impl ToValue for Tri {
        fn to_value(&self) -> Result<Value, EncodeError> {
            let mut writer = ObjectWriter::new();
            writer.required_nullable("pinned", &self.pinned)?;
            writer.optional_nullable("swapRecord", &self.swap_record)?;
            writer.optional("note", &self.note)?;
            writer.extra(self.extra_data.as_ref());
            Ok(writer.finish())
        }
    }

    impl FromValue for Tri {
        fn from_value(value: Value) -> Result<Self, DecodeError> {
            let mut reader = ObjectReader::new(value)?;
            Ok(Self {
                pinned: reader.required_nullable("pinned")?,
                swap_record: reader.optional_nullable("swapRecord"),
                note: reader.optional("note"),
                extra_data: reader.finish(),
            })
        }
    }

    generated_serde_impls!(Images, Like, PostEmbed, Post, GetPostsOutput, Tri);

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    fn link(cid: &str) -> CidLink {
        CidLink(cid.parse().unwrap())
    }

    /// Decodes `json` as `T` and checks every route back to bytes:
    /// JSON → T → JSON, T → CBOR → T → CBOR, CBOR → T → JSON, and the serde
    /// impls. The CBOR must also equal the encoding of the untyped value, so
    /// the typed hop provably lost and reordered nothing.
    fn assert_round_trips<T>(json: &str) -> T
    where
        T: ToValue + FromValue + serde::Serialize + serde::de::DeserializeOwned,
    {
        let typed: T = from_json(json.as_bytes()).unwrap();
        assert_eq!(String::from_utf8(to_json(&typed).unwrap()).unwrap(), json);

        let cbor = to_dag_cbor(&typed).unwrap();
        let untyped: Value = from_json(json.as_bytes()).unwrap();
        assert_eq!(cbor, dagcbor::encode(&untyped));

        let from_cbor: T = from_dag_cbor(&cbor).unwrap();
        assert_eq!(to_dag_cbor(&from_cbor).unwrap(), cbor);
        assert_eq!(
            String::from_utf8(to_json(&from_cbor).unwrap()).unwrap(),
            json
        );

        let via_serde: T = serde_json::from_str(json).unwrap();
        assert_eq!(serde_json::to_string(&via_serde).unwrap(), json);
        typed
    }

    fn full_post_json() -> String {
        format!(
            "{{\"$type\":\"app.example.post\",\
             \"createdAt\":\"2026-11-24T12:00:00.000Z\",\
             \"editedAt\":\"2026-11-24T12:30:00+01:00\",\
             \"embed\":{{\"$type\":\"app.example.embed.images\",\"alt\":\"a petrel\",\
             \"image\":{{\"$type\":\"blob\",\"mimeType\":\"image/jpeg\",\
             \"ref\":{{\"$link\":\"{RAW_CID}\"}},\"size\":10000}}}},\
             \"futureField\":{{\"n\":[1,-2,null,true],\"when\":{{\"$link\":\"{DAG_CID}\"}}}},\
             \"langs\":[\"en\",\"pt-BR\"],\
             \"likeCount\":9007199254740993,\
             \"root\":{{\"$link\":\"{DAG_CID}\"}},\
             \"sig\":{{\"$bytes\":\"nFERjvLLiw9qm45JrqH9QTzyC2Lu1Xb4ne6+sBrCzI0\"}},\
             \"text\":\"hello\",\
             \"thumb\":{{\"cid\":\"{RAW_CID}\",\"mimeType\":\"image/png\"}}}}"
        )
    }

    fn minimal_post_json(extra: &str) -> String {
        format!(
            "{{\"$type\":\"app.example.post\",\"createdAt\":\"2026-11-24T12:00:00Z\"{extra},\"text\":\"hi\"}}"
        )
    }

    // ---------------------------------------------------------------------
    // (a) the record
    // ---------------------------------------------------------------------

    #[test]
    fn record_round_trips_byte_identical_in_json_and_dag_cbor() {
        let post: Post = assert_round_trips(&full_post_json());

        assert_eq!(post.text, "hello");
        assert_eq!(post.created_at.as_str(), "2026-11-24T12:00:00.000Z");
        // The raw datetime string is kept, offset and all.
        assert_eq!(
            post.edited_at.unwrap().as_str(),
            "2026-11-24T12:30:00+01:00"
        );
        assert_eq!(post.root, Some(link(DAG_CID)));
        assert_eq!(post.sig.unwrap().0.len(), 32);
        // Integers are i64: this one is not representable as a double.
        assert_eq!(post.like_count, Some(9_007_199_254_740_993));
        assert_eq!(post.langs.unwrap()[1].as_str(), "pt-BR");
        // A legacy blob stays a legacy blob.
        assert!(matches!(post.thumb, Some(Blob::Legacy { .. })));
        let Some(PostEmbed::Images(images)) = post.embed else {
            panic!("embed should be the images member");
        };
        assert_eq!(
            images.image,
            Blob::Typed {
                r#ref: link(RAW_CID),
                mime_type: "image/jpeg".into(),
                size: 10_000,
            }
        );
        // `$type` is never left behind in extra_data.
        assert_eq!(images.extra_data, None);
    }

    #[test]
    fn record_built_in_code_encodes_type_and_omits_absent_optionals() {
        let post = Post::new("hi".into(), "2026-11-24T12:00:00Z".parse().unwrap());
        assert_eq!(
            String::from_utf8(to_json(&post).unwrap()).unwrap(),
            minimal_post_json("")
        );
        assert_eq!(<Post as Collection>::NSID, "app.example.post");
    }

    #[test]
    fn unknown_field_survives_in_extra_data() {
        let post: Post = assert_round_trips(&full_post_json());
        let extra = post.extra_data.unwrap();
        assert_eq!(extra.keys().collect::<Vec<_>>(), ["futureField"]);
        // The link inside the unknown field is still a link, not a string.
        let when = &extra["futureField"].as_object().unwrap()["when"];
        assert_eq!(when, &Value::Link(DAG_CID.parse().unwrap()));
    }

    #[test]
    fn unknown_union_type_survives_verbatim() {
        let embed = format!(
            ",\"embed\":{{\"$type\":\"app.example.embed.future\",\
             \"blob\":{{\"$link\":\"{RAW_CID}\"}},\"raw\":{{\"$bytes\":\"AQID\"}},\"x\":1}}"
        );
        let post: Post = assert_round_trips(&minimal_post_json(&embed));
        let Some(PostEmbed::Unknown(raw)) = post.embed else {
            panic!("an unknown `$type` should land in the Unknown arm");
        };
        assert_eq!(type_of(&raw).unwrap(), "app.example.embed.future");
        assert_eq!(raw.as_object().unwrap()["raw"], Value::Bytes(vec![1, 2, 3]));
        // Nothing leaked into the record's extra_data.
        assert_eq!(post.extra_data, None);
    }

    #[test]
    fn union_member_without_type_is_an_error() {
        assert_eq!(
            PostEmbed::from_value(from_json(b"{\"alt\":\"x\"}").unwrap()),
            Err(DecodeError::MissingType)
        );
    }

    #[test]
    fn malformed_optional_datetime_degrades_to_none_and_is_re_emitted() {
        let json = minimal_post_json(",\"editedAt\":\"yesterday at noon\"");
        let mut post: Post = assert_round_trips(&json);

        // The typed field is gone, the record is not.
        assert_eq!(post.edited_at, None);
        assert_eq!(post.text, "hi");
        // The raw value is kept under its own key.
        assert_eq!(
            post.extra_data.as_ref().unwrap()["editedAt"],
            Value::String("yesterday at noon".into())
        );

        // Once the typed field has a value, the stale raw form is not written.
        post.edited_at = Some("2026-11-24T13:00:00Z".parse().unwrap());
        assert_eq!(
            String::from_utf8(to_json(&post).unwrap()).unwrap(),
            minimal_post_json(",\"editedAt\":\"2026-11-24T13:00:00Z\"")
        );
    }

    #[test]
    fn malformed_union_member_in_an_optional_field_degrades_too() {
        // An images embed with no `image`: the member fails, the post survives.
        let json =
            minimal_post_json(",\"embed\":{\"$type\":\"app.example.embed.images\",\"alt\":\"x\"}");
        let post: Post = assert_round_trips(&json);
        assert_eq!(post.embed, None);
        assert!(post.extra_data.unwrap().contains_key("embed"));
    }

    #[test]
    fn malformed_required_field_fails_the_record() {
        let json = "{\"$type\":\"app.example.post\",\"createdAt\":\"noon\",\"text\":\"hi\"}";
        let error = from_json::<Post>(json.as_bytes()).unwrap_err();
        assert!(matches!(error, DecodeError::Field { ref field, .. } if field == "createdAt"));
        assert_eq!(
            from_json::<Post>(b"{\"createdAt\":\"2026-11-24T12:00:00Z\"}"),
            Err(DecodeError::MissingField("text".into()))
        );
    }

    #[test]
    fn record_used_as_union_member_emits_type_exactly_once() {
        let embed = ",\"embed\":{\"$type\":\"app.example.like\",\
                     \"createdAt\":\"2026-11-24T12:00:00Z\",\"subject\":\"at://did:plc:abc/app.example.post/1\"}";
        let post: Post = assert_round_trips(&minimal_post_json(embed));
        let Some(PostEmbed::Like(like)) = &post.embed else {
            panic!("embed should be the like record");
        };

        // The record writes its own `$type`, and the union tags it again.
        let own = String::from_utf8(to_json(&**like).unwrap()).unwrap();
        assert_eq!(own.matches("\"$type\"").count(), 1);
        let member = String::from_utf8(to_json(post.embed.as_ref().unwrap()).unwrap()).unwrap();
        assert_eq!(member.matches("\"$type\"").count(), 1);
        assert_eq!(member, own);

        // And in CBOR: the 5-byte text head+key `$type` appears once per object.
        let cbor = to_dag_cbor(post.embed.as_ref().unwrap()).unwrap();
        let needle = b"\x65$type";
        assert_eq!(
            cbor.windows(needle.len()).filter(|w| w == needle).count(),
            1
        );
        // The strict decoder would refuse a duplicate key in any case.
        assert_eq!(
            dagcbor::decode(&[0xa2, 0x61, b'a', 0x01, 0x61, b'a', 0x02]),
            Err(DagCborError::KeyOrder)
        );
    }

    // ---------------------------------------------------------------------
    // (b) the query
    // ---------------------------------------------------------------------

    #[test]
    fn query_params_follow_the_swift_rules() {
        let uri = |rkey: &str| AtUri::parse(format!("at://did:plc:abc/app.example.post/{rkey}"));
        let mut params = GetPostsParams::new(vec![uri("1").unwrap(), uri("2").unwrap()]);

        let mut pairs = Vec::new();
        params.to_query_params(&mut pairs);
        assert_eq!(
            pairs,
            [
                // An array is one pair per element.
                ("uris", "at://did:plc:abc/app.example.post/1".to_owned()),
                ("uris", "at://did:plc:abc/app.example.post/2".to_owned()),
                // An absent optional emits nothing; the defaulted int is sent.
                ("limit", "50".to_owned()),
            ]
        );

        params.include_replies = Some(false);
        params.limit = 10;
        pairs.clear();
        params.to_query_params(&mut pairs);
        assert_eq!(pairs[2], ("includeReplies", "false".to_owned()));
        assert_eq!(pairs[3], ("limit", "10".to_owned()));
    }

    #[test]
    fn query_endpoint_metadata_and_output_decoding() {
        assert_eq!(GetPosts::NSID, "app.example.getPosts");
        assert_eq!(GetPosts::METHOD, XrpcMethod::Query);
        assert_eq!(GetPosts::INPUT_ENCODING, None);
        assert_eq!(GetPosts::OUTPUT_ENCODING, Some("application/json"));

        let body = format!(
            "{{\"cursor\":\"abc\",\"posts\":[{},{}]}}",
            full_post_json(),
            // One bad optional field must not drop the page.
            minimal_post_json(",\"editedAt\":\"garbage\"")
        );
        let output: GetPostsOutput = assert_round_trips(&body);
        assert_eq!(output.posts.len(), 2);
        assert_eq!(output.posts[1].edited_at, None);
        let via_trait = <GetPosts as XrpcRequest>::Output::from_body(body.as_bytes()).unwrap();
        assert_eq!(via_trait, output);
    }

    #[test]
    fn declared_errors_map_with_an_unknown_arm() {
        let body =
            XrpcErrorBody::parse(b"{\"error\":\"BlockedActor\",\"message\":\"no\"}").unwrap();
        let error = <GetPosts as XrpcRequest>::Error::from_wire_name(&body.error);
        assert_eq!(error, GetPostsError::BlockedActor);
        assert!(error.is_declared());
        assert_eq!(body.message.as_deref(), Some("no"));

        let unknown = GetPostsError::from_wire_name("RateLimitExceeded");
        assert_eq!(unknown, GetPostsError::Unknown("RateLimitExceeded".into()));
        assert!(!unknown.is_declared());
        assert_eq!(unknown.wire_name(), "RateLimitExceeded");
        assert_eq!(XrpcErrorBody::parse(b"<html>502</html>"), None);
    }

    // ---------------------------------------------------------------------
    // (c) required-nullable, optional-nullable, optional
    // ---------------------------------------------------------------------

    #[test]
    fn missing_required_nullable_key_is_an_error() {
        assert_eq!(
            from_json::<Tri>(b"{\"note\":\"x\"}"),
            Err(DecodeError::MissingField("pinned".into()))
        );
        assert_eq!(
            from_dag_cbor::<Tri>(&[0xa0]),
            Err(DecodeError::MissingField("pinned".into()))
        );
    }

    #[test]
    fn required_nullable_null_is_none_and_is_always_written() {
        let tri: Tri = assert_round_trips("{\"pinned\":null}");
        assert_eq!(tri.pinned, None);
        // CBOR: a one-entry map, key "pinned", value null (0xf6).
        assert_eq!(
            to_dag_cbor(&tri).unwrap(),
            [&[0xa1, 0x66][..], b"pinned", &[0xf6]].concat()
        );

        let tri: Tri = assert_round_trips("{\"pinned\":\"at://did:plc:abc\"}");
        assert_eq!(tri.pinned.unwrap().as_str(), "at://did:plc:abc");
    }

    #[test]
    fn optional_nullable_is_tri_state() {
        let absent: Tri = assert_round_trips("{\"pinned\":null}");
        assert_eq!(absent.swap_record, None);

        let null: Tri = assert_round_trips("{\"pinned\":null,\"swapRecord\":null}");
        assert_eq!(null.swap_record, Some(Nullable::Null));

        let json = format!("{{\"pinned\":null,\"swapRecord\":{{\"$link\":\"{DAG_CID}\"}}}}");
        let value: Tri = assert_round_trips(&json);
        assert_eq!(value.swap_record, Some(Nullable::Value(link(DAG_CID))));

        // Three different states, three different encodings.
        let encodings: Vec<_> = [&absent, &null, &value]
            .map(|tri| to_dag_cbor(tri).unwrap())
            .into();
        assert_ne!(encodings[0], encodings[1]);
        assert_ne!(encodings[1], encodings[2]);
    }

    #[test]
    fn plain_optional_treats_null_as_absent() {
        let tri: Tri = from_json(b"{\"note\":null,\"pinned\":null}").unwrap();
        assert_eq!(tri.note, None);
        assert_eq!(to_json(&tri).unwrap(), b"{\"pinned\":null}");
    }

    // ---------------------------------------------------------------------
    // The codecs themselves
    // ---------------------------------------------------------------------

    #[test]
    fn link_is_cbor_tag_42_and_bytes_is_a_cbor_byte_string() {
        let cid: petrel_core::Cid = DAG_CID.parse().unwrap();
        assert_eq!(cid.as_bytes().len(), 36);

        let link_cbor = to_dag_cbor(&CidLink(cid.clone())).unwrap();
        // d8 2a = tag 42; 58 25 = byte string of 37; 00 = multibase identity.
        assert_eq!(link_cbor[..5], [0xd8, 0x2a, 0x58, 0x25, 0x00]);
        assert_eq!(&link_cbor[5..], cid.as_bytes());
        assert_eq!(from_dag_cbor::<CidLink>(&link_cbor).unwrap().0, cid);

        // 43 = byte string of 3. Not text, not an array, not a `$bytes` map.
        assert_eq!(to_dag_cbor(&Bytes(vec![1, 2, 3])).unwrap(), [0x43, 1, 2, 3]);

        // JSON: unpadded on encode, padded or unpadded on decode.
        assert_eq!(to_json(&Bytes(vec![1])).unwrap(), b"{\"$bytes\":\"AQ\"}");
        assert_eq!(from_json::<Bytes>(b"{\"$bytes\":\"AQ==\"}").unwrap().0, [1]);
        assert_eq!(from_json::<Bytes>(b"{\"$bytes\":\"AQ\"}").unwrap().0, [1]);

        // A `$link` with a sibling key is an ordinary object, not a link.
        let lookalike = format!("{{\"$link\":\"{DAG_CID}\",\"x\":1}}");
        assert!(matches!(
            from_json::<Value>(lookalike.as_bytes()),
            Ok(Value::Object(_))
        ));
        // A tag other than 42 is refused.
        assert_eq!(
            dagcbor::decode(&[0xc1, 0x00]),
            Err(DagCborError::UnsupportedTag(1))
        );
    }

    #[test]
    fn map_keys_encode_in_canonical_length_then_bytewise_order() {
        // Sorted as strings this is a, aa, b. Canonically it is a, b, aa.
        let value: Value = from_json(b"{\"a\":3,\"aa\":2,\"b\":1}").unwrap();
        let canonical = [0xa3, 0x61, b'a', 3, 0x61, b'b', 1, 0x62, b'a', b'a', 2];
        assert_eq!(dagcbor::encode(&value), canonical);
        assert_eq!(dagcbor::decode(&canonical).unwrap(), value);

        // The same map in plain string order is not canonical and is refused.
        let string_order = [0xa3, 0x61, b'a', 3, 0x62, b'a', b'a', 2, 0x61, b'b', 1];
        assert_eq!(dagcbor::decode(&string_order), Err(DagCborError::KeyOrder));
    }

    #[test]
    fn floats_are_rejected_everywhere() {
        for json in ["1.5", "1.0", "1e2", "{\"x\":[0.1]}"] {
            let error = from_json::<Value>(json.as_bytes()).unwrap_err();
            assert!(
                matches!(error, DecodeError::Json(ref text) if text.contains("float")),
                "{json}"
            );
        }
        assert!(from_json::<Post>(minimal_post_json(",\"likeCount\":1.5").as_bytes()).is_err());

        let half = [0xf9, 0x3c, 0x00];
        let single = [0xfa, 0x3f, 0x80, 0x00, 0x00];
        let double = [0xfb, 0x3f, 0xf0, 0, 0, 0, 0, 0, 0];
        for cbor in [&half[..], &single[..], &double[..]] {
            assert_eq!(dagcbor::decode(cbor), Err(DagCborError::FloatNotAllowed));
        }
    }

    #[test]
    fn strict_cbor_refuses_non_canonical_input() {
        let cases: [(&[u8], DagCborError); 7] = [
            (&[0x18, 0x01], DagCborError::NonMinimalEncoding),
            (&[0x9f, 0x01, 0xff], DagCborError::IndefiniteLength),
            (&[0xa1, 0x01, 0x02], DagCborError::NonStringKey),
            (&[0x01, 0x02], DagCborError::TrailingBytes),
            (
                &[0x1b, 0x80, 0, 0, 0, 0, 0, 0, 0],
                DagCborError::IntegerOutOfRange,
            ),
            (&[0xf7], DagCborError::Unsupported(0xf7)),
            (&[0x62, b'a'], DagCborError::LengthExceedsInput),
        ];
        for (bytes, expected) in cases {
            assert_eq!(dagcbor::decode(bytes), Err(expected), "{bytes:02x?}");
        }
        // i64::MIN and i64::MAX both survive.
        for number in [i64::MIN, -1, 0, 23, 24, i64::MAX] {
            let bytes = dagcbor::encode(&Value::Integer(number));
            assert_eq!(dagcbor::decode(&bytes), Ok(Value::Integer(number)));
        }
    }

    /// The official AT Protocol data-model fixtures, read in place from the
    /// Swift test vectors: JSON must encode to exactly the fixture's CBOR
    /// bytes and hash to exactly its CID.
    #[test]
    fn official_data_model_fixtures_reproduce_cbor_bytes_and_cids() {
        let path = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../Tests/PetrelRepoTests/Vectors/data-model/data-model-fixtures.json"
        );
        // Read the file as plain JSON so the fixtures' own `$link` and
        // `$bytes` objects are still text when we take them apart.
        let fixtures: serde_json::Value =
            serde_json::from_slice(&std::fs::read(path).unwrap()).unwrap();
        let fixtures = fixtures.as_array().unwrap();
        assert_eq!(fixtures.len(), 3);

        for fixture in fixtures {
            let json = serde_json::to_vec(&fixture["json"]).unwrap();
            let expected_cid = fixture["cid"].as_str().unwrap();
            // Borrow the `$bytes` reader to decode the fixture's base64.
            let wrapped = format!("{{\"$bytes\":{}}}", fixture["cbor_base64"]);
            let expected_cbor = from_json::<Bytes>(wrapped.as_bytes()).unwrap().0;

            let value: Value = from_json(&json).unwrap();
            let cbor = dagcbor::encode(&value);
            assert_eq!(cbor, expected_cbor, "CBOR bytes for {expected_cid}");
            assert_eq!(
                petrel_core::Cid::for_dag_cbor(&cbor).to_string(),
                expected_cid
            );
            assert_eq!(dagcbor::decode(&expected_cbor).unwrap(), value);
        }
    }
}
