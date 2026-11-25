use petrel_core::{Did, Handle};
use serde::{Deserialize, Deserializer};
use serde_json::Value as Json;
use url::Url;

use super::IdentityError;
use crate::net::policy::validate_url_with_development;

/// The AT Protocol fields of a DID document. Unrelated or malformed optional
/// entries are tolerated, while the document ID must be a valid DID.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DidDocument {
    pub id: Did,
    #[serde(rename = "@context", default, deserialize_with = "string_list")]
    pub context: Vec<String>,
    #[serde(default, deserialize_with = "string_list")]
    pub also_known_as: Vec<String>,
    #[serde(rename = "service", default, deserialize_with = "parse_services")]
    pub services: Vec<Service>,
    #[serde(
        rename = "verificationMethod",
        default,
        deserialize_with = "parse_keys"
    )]
    pub verification_methods: Vec<VerificationMethod>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Service {
    pub id: String,
    pub kind: String,
    /// May be absent if the document contained a non-string endpoint.
    pub endpoint: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VerificationMethod {
    pub id: String,
    #[serde(rename = "type")]
    pub kind: String,
    pub controller: Did,
    #[serde(default)]
    pub public_key_multibase: String,
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

impl DidDocument {
    /// The first claimed handle, which requires a DNS or HTTPS lookup to verify.
    pub fn claimed_handle(&self) -> Option<Handle> {
        self.also_known_as
            .iter()
            .filter_map(|alias| alias.strip_prefix("at://"))
            .find_map(|handle| handle.parse().ok())
    }

    pub fn service(&self, kind: ServiceKind) -> Option<&Service> {
        let (fragment, ty) = kind.parts();
        self.services
            .iter()
            .find(|service| self.matches_fragment(&service.id, fragment) && service.kind == ty)
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
        let Some(service) = self.service(kind) else {
            return Ok(None);
        };
        service
            .endpoint
            .as_deref()
            .and_then(|endpoint| parse_service_origin(endpoint, allow_development_hosts))
            .map(Some)
            .ok_or_else(|| IdentityError::InvalidServiceEndpoint {
                did: self.id.clone(),
                fragment: kind.fragment().to_owned(),
            })
    }

    /// The first valid key at `#atproto` that is controlled by this DID.
    pub fn signing_key(&self) -> Result<SigningKey, IdentityError> {
        self.valid_verification_keys("#atproto")
            .next()
            .ok_or_else(|| IdentityError::MissingSigningKey(self.id.clone()))
    }

    pub fn verification_key(&self, fragment: &str) -> Result<SigningKey, IdentityError> {
        let fragment = format!("#{}", fragment.strip_prefix('#').unwrap_or(fragment));
        let key = self.valid_verification_keys(&fragment).next();
        key.ok_or_else(|| IdentityError::MissingVerificationMethod {
            did: self.id.clone(),
            fragment,
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

    fn matches_fragment(&self, id: &str, fragment: &str) -> bool {
        id == fragment || id.strip_prefix(self.id.as_str()) == Some(fragment)
    }
}

fn parse_service_origin(endpoint: &str, allow_development_hosts: bool) -> Option<Url> {
    // URL parsers normalize dot segments, userinfo and surrounding whitespace.
    // Inspect the original spelling before the canonical representation loses them.
    let (scheme, authority) = endpoint.split_once("://")?;
    let authority = authority.strip_suffix('/').unwrap_or(authority);
    if !matches!(scheme, "https" | "http")
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

fn parse_services<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Vec<Service>, D::Error> {
    let value = Json::deserialize(deserializer)?;
    Ok(array_items(value)
        .filter_map(|item| {
            Some(Service {
                id: item.get("id")?.as_str()?.to_owned(),
                kind: item.get("type")?.as_str()?.to_owned(),
                endpoint: item
                    .get("serviceEndpoint")
                    .and_then(Json::as_str)
                    .map(str::to_owned),
            })
        })
        .collect())
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
