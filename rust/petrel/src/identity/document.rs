use petrel_core::{Did, Handle};
use petrel_crypto::{ATProtoKeyCurve, PLCDIDKeyCodec, PLCDIDVerificationKey, PublicKey};
use serde::{Deserialize, Deserializer, Serialize};
use serde_json::Value as Json;
use url::Url;

use super::IdentityError;
use crate::net::policy::validate_url_with_development;

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct UnreadableService {
    position: usize,
    id: String,
    kind: Option<String>,
}

/// The AT Protocol fields of a DID document. Unrelated or malformed optional
/// entries are tolerated, while the document ID must be a valid DID.
#[derive(Debug, Clone, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DidDocument {
    pub id: Did,
    #[serde(rename = "@context")]
    pub context: Vec<String>,
    pub also_known_as: Vec<String>,
    #[serde(rename = "service")]
    pub services: Vec<Service>,
    #[serde(rename = "verificationMethod")]
    pub verification_methods: Vec<VerificationMethod>,
    #[serde(skip)]
    unreadable_services: Vec<UnreadableService>,
}

impl PartialEq for DidDocument {
    fn eq(&self, other: &Self) -> bool {
        self.id == other.id
            && self.context == other.context
            && self.also_known_as == other.also_known_as
            && self.services == other.services
            && self.verification_methods == other.verification_methods
    }
}

impl<'de> Deserialize<'de> for DidDocument {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase")]
        struct RawDidDocument {
            id: Did,
            #[serde(rename = "@context", default, deserialize_with = "string_list")]
            context: Vec<String>,
            #[serde(default, deserialize_with = "string_list")]
            also_known_as: Vec<String>,
            #[serde(rename = "service", default)]
            service: Json,
            #[serde(
                rename = "verificationMethod",
                default,
                deserialize_with = "parse_keys"
            )]
            verification_methods: Vec<VerificationMethod>,
        }

        let raw = RawDidDocument::deserialize(deserializer)?;
        let (services, unreadable_services) = parse_services_value(raw.service);
        Ok(Self {
            id: raw.id,
            context: raw.context,
            also_known_as: raw.also_known_as,
            services,
            verification_methods: raw.verification_methods,
            unreadable_services,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Service {
    pub id: String,
    #[serde(rename = "type")]
    pub kind: String,
    /// May be absent if constructed manually without a string endpoint.
    #[serde(rename = "serviceEndpoint", skip_serializing_if = "Option::is_none")]
    pub endpoint: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VerificationMethod {
    pub id: String,
    #[serde(rename = "type")]
    pub kind: String,
    pub controller: Did,
    #[serde(default, deserialize_with = "null_as_empty_string")]
    pub public_key_multibase: String,
}

/// The id fragment and optional type naming a service in a DID document.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct DidServiceIdentifier {
    pub id: String,
    pub kind: Option<String>,
}

impl DidServiceIdentifier {
    /// Creates a service identifier, normalizing a missing leading `#`.
    pub fn new(id: impl AsRef<str>, kind: Option<&str>) -> Self {
        let id = id.as_ref();
        let id = if id.starts_with('#') {
            id.to_owned()
        } else {
            format!("#{id}")
        };
        Self {
            id,
            kind: kind.map(str::to_owned),
        }
    }

    pub fn pds() -> Self {
        Self::from(ServiceKind::Pds)
    }

    pub fn labeler() -> Self {
        Self::from(ServiceKind::Labeler)
    }

    pub fn feed_generator() -> Self {
        Self::from(ServiceKind::FeedGenerator)
    }

    pub fn notification_service() -> Self {
        Self::from(ServiceKind::Notifications)
    }

    pub fn chat() -> Self {
        Self::from(ServiceKind::Chat)
    }

    pub fn app_view() -> Self {
        Self::from(ServiceKind::AppView)
    }
}

impl From<ServiceKind> for DidServiceIdentifier {
    fn from(kind: ServiceKind) -> Self {
        let (fragment, ty) = kind.parts();
        Self {
            id: fragment.to_owned(),
            kind: Some(ty.to_owned()),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ServiceKind {
    Pds,
    Labeler,
    FeedGenerator,
    Notifications,
    Chat,
    AppView,
}

impl ServiceKind {
    pub fn fragment(self) -> &'static str {
        self.parts().0
    }

    fn parts(self) -> (&'static str, &'static str) {
        match self {
            Self::Pds => ("#atproto_pds", "AtprotoPersonalDataServer"),
            Self::Labeler => ("#atproto_labeler", "AtprotoLabeler"),
            Self::FeedGenerator => ("#bsky_fg", "BskyFeedGenerator"),
            Self::Notifications => ("#bsky_notif", "BskyNotificationService"),
            Self::Chat => ("#bsky_chat", "BskyChatService"),
            Self::AppView => ("#bsky_appview", "BskyAppView"),
        }
    }
}

enum ServiceEntry<'a> {
    Readable(&'a Service),
    Unreadable,
}

impl DidDocument {
    /// The first claimed handle, which requires a DNS or HTTPS lookup to verify.
    pub fn claimed_handle(&self) -> Option<Handle> {
        self.also_known_as
            .iter()
            .filter_map(|alias| alias.strip_prefix("at://"))
            .find_map(|handle| handle.parse().ok())
    }

    pub fn service(&self, kind: ServiceKind) -> Option<&Service> {
        self.service_for(&DidServiceIdentifier::from(kind))
    }

    /// The first readable service matching `identifier`, respecting unreadable entries
    /// that precede it in document order.
    pub fn service_for(&self, identifier: &DidServiceIdentifier) -> Option<&Service> {
        match self.first_service_entry(identifier) {
            Some(ServiceEntry::Readable(service)) => Some(service),
            _ => None,
        }
    }

    pub fn validated_service_endpoint(
        &self,
        kind: ServiceKind,
    ) -> Result<Option<Url>, IdentityError> {
        self.validated_service_endpoint_with_development(kind, false)
    }

    pub fn validated_service_endpoint_with_development(
        &self,
        kind: ServiceKind,
        allow_development_hosts: bool,
    ) -> Result<Option<Url>, IdentityError> {
        self.validated_service_endpoint_for(
            &DidServiceIdentifier::from(kind),
            allow_development_hosts,
        )
    }

    /// Resolves and validates a service endpoint, returning `Ok(None)` when absent.
    pub fn validated_service_endpoint_for(
        &self,
        identifier: &DidServiceIdentifier,
        allow_development_hosts: bool,
    ) -> Result<Option<Url>, IdentityError> {
        let entry = match self.first_service_entry(identifier) {
            None => return Ok(None),
            Some(ServiceEntry::Unreadable) => {
                return Err(IdentityError::InvalidServiceEndpoint {
                    did: self.id.clone(),
                    fragment: identifier.id.clone(),
                });
            }
            Some(ServiceEntry::Readable(service)) => service,
        };
        entry
            .endpoint
            .as_deref()
            .and_then(|endpoint| parse_service_origin(endpoint, allow_development_hosts))
            .map(Some)
            .ok_or_else(|| IdentityError::InvalidServiceEndpoint {
                did: self.id.clone(),
                fragment: identifier.id.clone(),
            })
    }

    /// Resolves and validates a required service endpoint, returning `MissingService` when absent.
    pub fn service_endpoint(
        &self,
        identifier: &DidServiceIdentifier,
    ) -> Result<Url, IdentityError> {
        self.service_endpoint_with_development(identifier, false)
    }

    /// Resolves and validates a required service endpoint with optional development host support.
    pub fn service_endpoint_with_development(
        &self,
        identifier: &DidServiceIdentifier,
        allow_development_hosts: bool,
    ) -> Result<Url, IdentityError> {
        self.validated_service_endpoint_for(identifier, allow_development_hosts)?
            .ok_or_else(|| IdentityError::MissingService {
                did: self.id.clone(),
                fragment: identifier.id.clone(),
            })
    }

    pub fn pds_endpoint(&self) -> Option<Url> {
        self.validated_service_endpoint(ServiceKind::Pds)
            .ok()
            .flatten()
    }

    pub fn labeler_endpoint(&self) -> Option<Url> {
        self.validated_service_endpoint(ServiceKind::Labeler)
            .ok()
            .flatten()
    }

    pub fn feed_generator_endpoint(&self) -> Option<Url> {
        self.validated_service_endpoint(ServiceKind::FeedGenerator)
            .ok()
            .flatten()
    }

    pub fn notification_service_endpoint(&self) -> Option<Url> {
        self.validated_service_endpoint(ServiceKind::Notifications)
            .ok()
            .flatten()
    }

    pub fn chat_endpoint(&self) -> Option<Url> {
        self.validated_service_endpoint(ServiceKind::Chat)
            .ok()
            .flatten()
    }

    pub fn app_view_endpoint(&self) -> Option<Url> {
        self.validated_service_endpoint(ServiceKind::AppView)
            .ok()
            .flatten()
    }

    /// The first verification method matching `fragment`, written as `#id` or `<did>#id`.
    pub fn verification_method(&self, fragment: &str) -> Option<&VerificationMethod> {
        let normalized = normalize_fragment(fragment);
        self.verification_methods
            .iter()
            .find(|method| self.matches_fragment(&method.id, &normalized))
    }

    /// The first valid key at `#atproto` that is controlled by this DID.
    pub fn signing_key(&self) -> Result<SigningKey, IdentityError> {
        self.valid_verification_keys("#atproto")
            .next()
            .ok_or_else(|| IdentityError::MissingSigningKey(self.id.clone()))
    }

    /// The `#atproto` verification key as a `petrel_crypto::PublicKey`.
    pub fn atproto_signing_key(&self) -> Result<PublicKey, IdentityError> {
        self.signing_key()?.to_public_key()
    }

    /// The `#atproto` verification key encoded as `did:key:...`.
    pub fn atproto_signing_did_key(&self) -> Result<String, IdentityError> {
        Ok(self.signing_key()?.did_key())
    }

    pub fn verification_key(&self, fragment: &str) -> Result<SigningKey, IdentityError> {
        let fragment = normalize_fragment(fragment);
        let key = self.valid_verification_keys(&fragment).next();
        key.ok_or_else(|| IdentityError::MissingVerificationMethod {
            did: self.id.clone(),
            fragment,
        })
    }

    /// The first valid PLC-format verification key at `fragment` controlled by this DID.
    pub fn plc_verification_key(
        &self,
        fragment: &str,
    ) -> Result<PLCDIDVerificationKey, IdentityError> {
        let key = self.verification_key(fragment)?;
        PLCDIDKeyCodec::decode(&key.did_key()).map_err(|_| {
            IdentityError::MissingVerificationMethod {
                did: self.id.clone(),
                fragment: normalize_fragment(fragment),
            }
        })
    }

    fn valid_verification_keys<'a>(
        &'a self,
        fragment: &'a str,
    ) -> impl Iterator<Item = SigningKey> + 'a {
        self.verification_methods
            .iter()
            .filter(move |key| {
                key.controller == self.id && self.matches_fragment(&key.id, fragment)
            })
            .filter_map(SigningKey::decode)
    }

    fn first_service_entry(&self, identifier: &DidServiceIdentifier) -> Option<ServiceEntry<'_>> {
        let is_match = |id: &str, kind: Option<&str>| -> bool {
            self.matches_fragment(id, &identifier.id)
                && match identifier.kind.as_deref() {
                    None => true,
                    Some(required) => kind == Some(required),
                }
        };

        let mut readable = self.services.iter();
        let total = self.services.len() + self.unreadable_services.len();
        for position in 0..total {
            if let Some(unreadable) = self
                .unreadable_services
                .iter()
                .find(|entry| entry.position == position)
            {
                if is_match(&unreadable.id, unreadable.kind.as_deref()) {
                    return Some(ServiceEntry::Unreadable);
                }
            } else if let Some(service) = readable.next()
                && is_match(&service.id, Some(service.kind.as_str()))
            {
                return Some(ServiceEntry::Readable(service));
            }
        }
        None
    }

    fn matches_fragment(&self, id: &str, fragment: &str) -> bool {
        id == fragment || id.strip_prefix(self.id.as_str()) == Some(fragment)
    }
}

fn normalize_fragment(fragment: &str) -> String {
    if fragment.starts_with('#') {
        fragment.to_owned()
    } else {
        format!("#{fragment}")
    }
}

fn parse_service_origin(endpoint: &str, allow_development_hosts: bool) -> Option<Url> {
    // URL parsers normalize dot segments, userinfo and surrounding whitespace.
    // Inspect the original spelling before the canonical representation loses them.
    let (scheme, authority) = endpoint.split_once("://")?;
    let authority = authority.strip_suffix('/').unwrap_or(authority);
    if !(scheme.eq_ignore_ascii_case("https") || scheme.eq_ignore_ascii_case("http"))
        || authority.is_empty()
        || authority.contains(['/', '\\', '@', '?', '#'])
        || authority
            .bytes()
            .any(|byte| byte.is_ascii_whitespace() || byte.is_ascii_control())
    {
        return None;
    }
    let url = Url::parse(endpoint).ok()?;
    validate_url_with_development(&url, allow_development_hosts).ok()?;
    Some(url)
}

fn string_list<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Vec<String>, D::Error> {
    let value = Json::deserialize(deserializer)?;
    Ok(match value {
        Json::Array(items) => items
            .into_iter()
            .filter_map(|value| match value {
                Json::String(text) => Some(text),
                _ => None,
            })
            .collect(),
        Json::String(text) => vec![text],
        _ => Vec::new(),
    })
}

fn null_as_empty_string<'de, D: Deserializer<'de>>(deserializer: D) -> Result<String, D::Error> {
    Ok(Option::<String>::deserialize(deserializer)?.unwrap_or_default())
}

fn parse_services_value(value: Json) -> (Vec<Service>, Vec<UnreadableService>) {
    let mut services = Vec::new();
    let mut unreadable = Vec::new();
    for item in array_items(value) {
        let Some(id) = item.get("id").and_then(Json::as_str) else {
            continue;
        };
        let kind = item.get("type").and_then(Json::as_str).map(str::to_owned);
        let endpoint = item
            .get("serviceEndpoint")
            .and_then(Json::as_str)
            .map(str::to_owned);
        match (kind, endpoint) {
            (Some(kind), Some(endpoint)) => services.push(Service {
                id: id.to_owned(),
                kind,
                endpoint: Some(endpoint),
            }),
            (kind, _) => {
                let position = services.len() + unreadable.len();
                unreadable.push(UnreadableService {
                    position,
                    id: id.to_owned(),
                    kind,
                });
            }
        }
    }
    (services, unreadable)
}

fn parse_keys<'de, D: Deserializer<'de>>(
    deserializer: D,
) -> Result<Vec<VerificationMethod>, D::Error> {
    let value = Json::deserialize(deserializer)?;
    Ok(array_items(value)
        .filter_map(|item| serde_json::from_value(item).ok())
        .collect())
}

fn array_items(value: Json) -> std::vec::IntoIter<Json> {
    match value {
        Json::Array(array) => array.into_iter(),
        _ => Vec::new().into_iter(),
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SigningCurve {
    P256,
    Secp256k1,
}

impl From<SigningCurve> for ATProtoKeyCurve {
    fn from(curve: SigningCurve) -> Self {
        match curve {
            SigningCurve::P256 => Self::P256,
            SigningCurve::Secp256k1 => Self::Secp256k1,
        }
    }
}

/// A validated P-256 or secp256k1 signing key in compressed SEC1 form.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SigningKey {
    curve: SigningCurve,
    compressed_sec1: [u8; 33],
}

impl SigningKey {
    pub fn curve(&self) -> SigningCurve {
        self.curve
    }

    pub fn as_sec1(&self) -> &[u8; 33] {
        &self.compressed_sec1
    }

    pub fn did_key(&self) -> String {
        let mut encoded = [0; 35];
        encoded[..2].copy_from_slice(&self.codec());
        encoded[2..].copy_from_slice(&self.compressed_sec1);
        format!("did:key:z{}", bs58::encode(encoded).into_string())
    }

    /// Converts this signing key into a `petrel_crypto::PublicKey`.
    pub fn to_public_key(&self) -> Result<PublicKey, IdentityError> {
        PublicKey::from_sec1(self.curve.into(), &self.compressed_sec1)
            .map_err(|_| IdentityError::InvalidDidSyntax("invalid signing key point".to_owned()))
    }

    fn codec(&self) -> [u8; 2] {
        match self.curve {
            SigningCurve::P256 => [0x80, 0x24],
            SigningCurve::Secp256k1 => [0xe7, 0x01],
        }
    }

    fn decode(method: &VerificationMethod) -> Option<Self> {
        use p256::elliptic_curve::sec1::ToEncodedPoint as _;

        let encoded = method.public_key_multibase.strip_prefix('z')?;
        if encoded.is_empty() || encoded.len() > 255 {
            return None;
        }
        let bytes = bs58::decode(encoded).into_vec().ok()?;
        if bs58::encode(&bytes).into_string() != encoded {
            return None;
        }
        let (curve, sec1) = match (method.kind.as_str(), bytes.as_slice()) {
            ("Multikey", [0x80, 0x24, sec1 @ ..]) if sec1.len() == 33 => (SigningCurve::P256, sec1),
            ("Multikey", [0xe7, 0x01, sec1 @ ..]) if sec1.len() == 33 => {
                (SigningCurve::Secp256k1, sec1)
            }
            ("EcdsaSecp256r1VerificationKey2019", sec1) if matches!(sec1.len(), 33 | 65) => {
                (SigningCurve::P256, sec1)
            }
            ("EcdsaSecp256k1VerificationKey2019", sec1) if matches!(sec1.len(), 33 | 65) => {
                (SigningCurve::Secp256k1, sec1)
            }
            _ => return None,
        };

        let compressed_sec1 = match curve {
            SigningCurve::P256 => p256::PublicKey::from_sec1_bytes(sec1)
                .ok()?
                .to_encoded_point(true)
                .as_bytes()
                .try_into()
                .ok()?,
            SigningCurve::Secp256k1 => k256::PublicKey::from_sec1_bytes(sec1)
                .ok()?
                .to_encoded_point(true)
                .as_bytes()
                .try_into()
                .ok()?,
        };

        Some(Self {
            curve,
            compressed_sec1,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_malformed_first_matching_service_is_not_bypassed() {
        let document: DidDocument = serde_json::from_str(r##"{
            "id":"did:plc:abc",
            "alsoKnownAs": [null, "at://did:plc:other", "at://example.com"],
            "service":[
                {"id":"#atproto_pds","type":"AtprotoPersonalDataServer","serviceEndpoint":{}},
                {"id":"did:plc:abc#atproto_pds","type":"AtprotoPersonalDataServer","serviceEndpoint":"https://pds.example.com"}
            ]
        }"##).unwrap();

        assert_eq!(document.claimed_handle().unwrap().as_str(), "example.com");
        assert!(matches!(
            document.validated_service_endpoint(ServiceKind::Pds),
            Err(IdentityError::InvalidServiceEndpoint { .. })
        ));
    }

    #[test]
    fn endpoint_must_be_an_allowed_origin() {
        for url in [
            "https://pds.example.com/xrpc",
            "https://pds.example.com/.",
            "https://pds.example.com/?",
            "https://@pds.example.com",
            "https://pds.example.com#",
            "http://pds.example.com",
            "https://127.0.0.1",
        ] {
            assert!(parse_service_origin(url, false).is_none(), "{url}");
        }
        assert!(parse_service_origin("https://pds.example.com:4242/", false).is_some());
        assert!(parse_service_origin("http://localhost:3000", false).is_none());
        assert!(parse_service_origin("http://localhost:3000", true).is_some());
    }

    #[test]
    fn signing_key_skips_other_controllers_and_invalid_points() {
        use p256::elliptic_curve::sec1::ToEncodedPoint as _;

        let mut encoded = vec![0x80, 0x24];
        let key = p256::SecretKey::from_slice(&[1; 32]).unwrap();
        let point = key.public_key().to_encoded_point(true);
        encoded.extend(point.as_bytes());
        let multibase = format!("z{}", bs58::encode(encoded).into_string());
        let document: DidDocument = serde_json::from_value(serde_json::json!({
            "id": "did:plc:abc",
            "verificationMethod": [
                {"id":"#atproto","type":"Multikey","controller":"did:plc:someone","publicKeyMultibase":multibase},
                {"id":"#atproto","type":"Multikey","controller":"did:plc:abc","publicKeyMultibase":"z1111"},
                {"id":"did:plc:abc#atproto","type":"Multikey","controller":"did:plc:abc","publicKeyMultibase":multibase}
            ]
        })).unwrap();
        let key = document.signing_key().unwrap();
        assert_eq!(key.curve(), SigningCurve::P256);
        assert_eq!(key.did_key(), format!("did:key:{multibase}"));
    }
}
