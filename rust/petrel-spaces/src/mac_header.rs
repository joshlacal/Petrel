//! Space MAC HTTP response/header signing and verification (`Covered-Signature`, `Signature-Input`, `Signature`).

use base64::Engine as _;
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use petrel_core::{AtUri, Cid, Did, SpaceRef, Tid, syntax::Grammar};
use petrel_crypto::{P256DIDKey, SpaceMAC};

use crate::error::{Result, SpaceError, parse_space_ref};
use crate::sf::{
    DuplicatePolicy, SfBareItem, SfDictionary, SfItem, SfMember, escape_sf_string, parse_dictionary,
};

/// Space MAC profile name (`commit` or `record`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum MacProfile {
    /// `atproto-space-commit` covering `ver`, `repo`, `space`, `rev`, and `data`.
    Commit,
    /// `atproto-space-record` covering `uri` and `cid`.
    Record,
}

impl MacProfile {
    /// Wire profile & RFC 9421 header component / tag string.
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Commit => "atproto-space-commit",
            Self::Record => "atproto-space-record",
        }
    }

    /// HTTP header carrying the covered structured-field payload for this profile.
    pub fn response_header(self) -> &'static str {
        match self {
            Self::Commit => "atproto-space-commit",
            Self::Record => "atproto-space-record",
        }
    }

    /// Parse profile wire string.
    pub fn parse(raw: &str) -> Result<Self> {
        match raw {
            "atproto-space-commit" => Ok(Self::Commit),
            "atproto-space-record" => Ok(Self::Record),
            other => Err(SpaceError::InvalidAcceptSignature(format!(
                "unsupported MAC profile '{other}'"
            ))),
        }
    }
}

/// Parsed client `Accept-Signature` MAC request.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AcceptSignatureRequest {
    pub profile: MacProfile,
    pub keyid: String,
}

/// Generated MAC response headers (`Covered-Signature`, `Signature-Input`, `Signature`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SpaceMacHeaders {
    pub covered_signature: String,
    pub signature_input: String,
    pub signature: String,
    pub mac: [u8; 32],
}

/// Verified fields from a `atproto-space-commit` MAC response.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedCommitMac {
    pub ver: i64,
    pub repo: Did,
    pub space: SpaceRef,
    pub rev: Tid,
    pub data: [u8; 32],
    pub keyid: String,
}

/// Verified fields from a `atproto-space-record` MAC response.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedRecordMac {
    pub uri: AtUri,
    pub cid: Cid,
    pub keyid: String,
}

/// Format an outbound `Accept-Signature` header for HPKE MAC negotiation.
pub fn format_accept_signature(profile: MacProfile, recipient_did_key: &str) -> Result<String> {
    let _ = P256DIDKey::parse(recipient_did_key)
        .map_err(|e| SpaceError::InvalidKemKey(e.to_string()))?;
    let p = profile.as_str();
    Ok(format!(
        "mac=(\"{p}\";sf);keyid=\"{}\";tag=\"{p}\"",
        escape_sf_string(recipient_did_key)
    ))
}

/// Parse an inbound `Accept-Signature` header.
pub fn parse_accept_signature(header: &str) -> Result<AcceptSignatureRequest> {
    let dict = parse_dictionary(header, DuplicatePolicy::Reject)
        .map_err(|e| SpaceError::InvalidAcceptSignature(e.to_string()))?;
    let (_lbl, profile, keyid) = parse_mac_signature_input(&dict, None)?;
    Ok(AcceptSignatureRequest { profile, keyid })
}

/// Compute and format `Covered-Signature`, `Signature-Input`, and `Signature` for a commit MAC.
pub fn sign_commit_mac(
    shared_secret: &[u8; 32],
    space: &SpaceRef,
    repo: &Did,
    rev: &Tid,
    data: &[u8; 32],
    keyid_did_key: &str,
) -> Result<SpaceMacHeaders> {
    let _ =
        P256DIDKey::parse(keyid_did_key).map_err(|e| SpaceError::InvalidKemKey(e.to_string()))?;
    let covered_signature = format!(
        "ver=1, repo=\"{}\", space=\"{}\", rev=\"{}\", data=:{}:",
        escape_sf_string(repo.as_str()),
        escape_sf_string(space.as_str()),
        escape_sf_string(rev.as_str()),
        BASE64_STANDARD.encode(data)
    );
    sign_mac_common(
        shared_secret,
        MacProfile::Commit,
        covered_signature,
        keyid_did_key,
    )
}

/// Compute and format `Covered-Signature`, `Signature-Input`, and `Signature` for a record MAC.
///
/// Enforces Nov 24 alpha `at:space/{space}/{type}/{skey}/{author}/{collection}/{rkey}` URIs.
pub fn sign_record_mac(
    shared_secret: &[u8; 32],
    record_uri: &AtUri,
    cid: &Cid,
    keyid_did_key: &str,
) -> Result<SpaceMacHeaders> {
    validate_space_record_uri(record_uri)?;
    let _ =
        P256DIDKey::parse(keyid_did_key).map_err(|e| SpaceError::InvalidKemKey(e.to_string()))?;
    let covered_signature = format!(
        "uri=\"{}\", cid=\"{}\"",
        escape_sf_string(record_uri.as_str()),
        escape_sf_string(&cid.to_string()),
    );
    sign_mac_common(
        shared_secret,
        MacProfile::Record,
        covered_signature,
        keyid_did_key,
    )
}

/// Verify `Atproto-Space-Commit` (or `Covered-Signature`), `Signature-Input`, and `Signature`
/// for an `atproto-space-commit` MAC.
pub fn verify_commit_mac(
    shared_secret: &[u8; 32],
    covered_signature: &str,
    signature_input: &str,
    signature: &str,
) -> Result<VerifiedCommitMac> {
    let (_profile, keyid, covered) = verify_mac_common(
        shared_secret,
        MacProfile::Commit,
        covered_signature,
        signature_input,
        signature,
    )?;

    let ver = covered
        .get("ver")
        .and_then(SfMember::as_item)
        .and_then(|i| i.bare.as_int())
        .ok_or_else(|| SpaceError::InvalidMacHeader("missing integer 'ver'".into()))?;
    if ver != 1 {
        return Err(SpaceError::InvalidMacHeader(format!(
            "unsupported commit MAC ver={ver}"
        )));
    }
    let repo_str = covered
        .get("repo")
        .and_then(SfMember::as_item)
        .and_then(|i| i.bare.as_string_strict())
        .ok_or_else(|| SpaceError::InvalidMacHeader("missing string 'repo'".into()))?;
    let repo = Did::parse(repo_str).map_err(|e| SpaceError::InvalidDid(e.to_string()))?;

    let space_str = covered
        .get("space")
        .and_then(SfMember::as_item)
        .and_then(|i| i.bare.as_string_strict())
        .ok_or_else(|| SpaceError::InvalidMacHeader("missing string 'space'".into()))?;
    let space = parse_space_ref(space_str)?;

    let rev_str = covered
        .get("rev")
        .and_then(SfMember::as_item)
        .and_then(|i| i.bare.as_string_strict())
        .ok_or_else(|| SpaceError::InvalidMacHeader("missing string 'rev'".into()))?;
    let rev = Tid::parse(rev_str).map_err(|e| SpaceError::InvalidTid(e.to_string()))?;

    let data_bytes = covered
        .get("data")
        .and_then(SfMember::as_item)
        .and_then(|i| i.bare.as_bytes())
        .ok_or_else(|| SpaceError::InvalidMacHeader("missing byte-seq 'data'".into()))?;
    let data: [u8; 32] = data_bytes
        .try_into()
        .map_err(|_| SpaceError::InvalidMacHeader("'data' must be 32 bytes".into()))?;

    Ok(VerifiedCommitMac {
        ver,
        repo,
        space,
        rev,
        data,
        keyid,
    })
}

/// Verify `Atproto-Space-Record` (or `Covered-Signature`), `Signature-Input`, and `Signature`
/// for an `atproto-space-record` MAC.
pub fn verify_record_mac(
    shared_secret: &[u8; 32],
    covered_signature: &str,
    signature_input: &str,
    signature: &str,
) -> Result<VerifiedRecordMac> {
    let (_profile, keyid, covered) = verify_mac_common(
        shared_secret,
        MacProfile::Record,
        covered_signature,
        signature_input,
        signature,
    )?;

    let uri_str = covered
        .get("uri")
        .and_then(SfMember::as_item)
        .and_then(|i| i.bare.as_string_strict())
        .ok_or_else(|| SpaceError::InvalidMacHeader("missing string 'uri'".into()))?;
    if AtUri::from_legacy_space_uri(uri_str).is_some() {
        return Err(SpaceError::LegacySpaceUriRejected(uri_str.to_owned()));
    }
    let uri = AtUri::parse_with_grammar(uri_str, Grammar::RestrictedOrSpace)
        .map_err(|e| SpaceError::InvalidUri(e.to_string()))?;
    validate_space_record_uri(&uri)?;

    let cid_str = covered
        .get("cid")
        .and_then(SfMember::as_item)
        .and_then(|i| i.bare.as_string_strict())
        .ok_or_else(|| SpaceError::InvalidMacHeader("missing string 'cid'".into()))?;
    let cid = Cid::parse(cid_str).map_err(|e| SpaceError::InvalidCid(e.to_string()))?;

    Ok(VerifiedRecordMac { uri, cid, keyid })
}

fn validate_space_record_uri(uri: &AtUri) -> Result<()> {
    if AtUri::from_legacy_space_uri(uri.as_str()).is_some() {
        return Err(SpaceError::LegacySpaceUriRejected(uri.as_str().to_owned()));
    }
    if uri.space_ref().is_none()
        || uri.author_did().is_none()
        || uri.collection().is_none()
        || uri.rkey().is_none()
    {
        return Err(SpaceError::InvalidUri(format!(
            "expected Nov 24 6-part at:space/ record URI: {uri}"
        )));
    }
    Ok(())
}

fn sign_mac_common(
    shared_secret: &[u8; 32],
    profile: MacProfile,
    covered_signature: String,
    keyid_did_key: &str,
) -> Result<SpaceMacHeaders> {
    let p = profile.as_str();
    let sig_params = format!(
        "(\"{p}\";sf);keyid=\"{}\";tag=\"{p}\"",
        escape_sf_string(keyid_did_key)
    );
    let signature_input = format!("mac={sig_params}");
    let base = build_mac_signature_base(profile, &covered_signature, &sig_params);
    let mac = SpaceMAC::authentication_code(base.as_bytes(), shared_secret)
        .map_err(|e| SpaceError::KemError(e.to_string()))?;
    let signature = format!("mac=:{}:", BASE64_STANDARD.encode(mac));
    Ok(SpaceMacHeaders {
        covered_signature,
        signature_input,
        signature,
        mac,
    })
}

fn verify_mac_common(
    shared_secret: &[u8; 32],
    expected_profile: MacProfile,
    covered_signature: &str,
    signature_input: &str,
    signature: &str,
) -> Result<(MacProfile, String, SfDictionary)> {
    let input_dict = parse_dictionary(signature_input, DuplicatePolicy::Reject)
        .map_err(|e| SpaceError::InvalidMacHeader(e.to_string()))?;
    let (label, profile, keyid) = parse_mac_signature_input(&input_dict, Some(expected_profile))?;

    let sig_dict = parse_dictionary(signature, DuplicatePolicy::Reject)
        .map_err(|e| SpaceError::InvalidMacHeader(e.to_string()))?;
    let sig_item = sig_dict
        .get(&label)
        .and_then(SfMember::as_item)
        .ok_or_else(|| SpaceError::InvalidMacHeader(format!("missing '{label}' in Signature")))?;
    if !sig_item.params.is_empty() {
        return Err(SpaceError::InvalidMacHeader(
            "MAC Signature member must not carry parameters".into(),
        ));
    }
    let tag = sig_item.bare.as_bytes().ok_or_else(|| {
        SpaceError::InvalidMacHeader("MAC Signature must be a byte sequence".into())
    })?;

    let covered = parse_dictionary(covered_signature, DuplicatePolicy::Reject)
        .map_err(|e| SpaceError::InvalidMacHeader(e.to_string()))?;
    let canonical_covered = covered.format();

    let sig_params = input_dict
        .get(&label)
        .ok_or_else(|| SpaceError::InvalidMacHeader(format!("missing '{label}'")))?
        .format();
    let base = build_mac_signature_base(profile, &canonical_covered, &sig_params);

    SpaceMAC::verify(tag, base.as_bytes(), shared_secret).map_err(|_| SpaceError::MacMismatch)?;
    Ok((profile, keyid, covered))
}

fn find_mac_member(
    dict: &SfDictionary,
    expected_profile: Option<MacProfile>,
) -> Result<(String, &SfMember)> {
    let Some(exp) = expected_profile else {
        let mem = dict
            .get("mac")
            .ok_or_else(|| SpaceError::InvalidMacHeader("missing 'mac' member".into()))?;
        return Ok(("mac".to_owned(), mem));
    };

    let mut matched = None;
    for (lbl, mem) in &dict.entries {
        if let SfMember::InnerList(_, params) = mem
            && params
                .iter()
                .rev()
                .find(|(k, _)| k == "tag")
                .and_then(|(_, v)| v.as_string_strict())
                == Some(exp.as_str())
        {
            if matched.is_some() {
                return Err(SpaceError::InvalidMacHeader(
                    "multiple Signature-Input members match MAC tag".into(),
                ));
            }
            matched = Some((lbl.clone(), mem));
        }
    }
    matched.ok_or_else(|| {
        SpaceError::InvalidMacHeader(format!(
            "missing Signature-Input member tagged '{}'",
            exp.as_str()
        ))
    })
}

fn parse_mac_signature_input(
    dict: &SfDictionary,
    expected_profile: Option<MacProfile>,
) -> Result<(String, MacProfile, String)> {
    let (label, member) = find_mac_member(dict, expected_profile)?;
    let (items, params) = match member {
        SfMember::InnerList(items, params) => (items, params),
        SfMember::Item(_) => {
            return Err(SpaceError::InvalidMacHeader(
                "'mac' member must be an inner list".into(),
            ));
        }
    };
    if items.len() != 1 {
        return Err(SpaceError::InvalidMacHeader(
            "'mac' inner list must have exactly 1 component".into(),
        ));
    }
    let comp: &SfItem = &items[0];
    let comp_name = comp
        .bare
        .as_string_strict()
        .ok_or_else(|| SpaceError::InvalidMacHeader("component name must be a string".into()))?;
    let profile = MacProfile::parse(comp_name)?;
    if let Some(exp) = expected_profile
        && profile != exp
    {
        return Err(SpaceError::InvalidMacHeader(format!(
            "expected MAC profile {}, got {}",
            exp.as_str(),
            profile.as_str()
        )));
    }
    let has_sf = comp
        .params
        .iter()
        .any(|(k, v)| k == "sf" && matches!(v, SfBareItem::Boolean(true)));
    if !has_sf || comp.params.len() != 1 {
        return Err(SpaceError::InvalidMacHeader(
            "MAC component must carry strictly the ;sf parameter".into(),
        ));
    }

    let mut keyid: Option<String> = None;
    let mut tag_ok = false;
    for (k, v) in params {
        match k.as_str() {
            "keyid" => {
                let s = v
                    .as_string_strict()
                    .ok_or_else(|| SpaceError::InvalidMacHeader("keyid must be a string".into()))?;
                let _ =
                    P256DIDKey::parse(s).map_err(|e| SpaceError::InvalidKemKey(e.to_string()))?;
                keyid = Some(s.to_owned());
            }
            "alg" => {
                let s = v
                    .as_string_strict()
                    .ok_or_else(|| SpaceError::InvalidMacHeader("alg must be a string".into()))?;
                if s != "hmac-sha256" {
                    return Err(SpaceError::InvalidMacHeader(format!(
                        "unsupported MAC alg '{s}'"
                    )));
                }
            }
            "tag" => {
                let s = v
                    .as_string_strict()
                    .ok_or_else(|| SpaceError::InvalidMacHeader("tag must be a string".into()))?;
                if s != profile.as_str() {
                    return Err(SpaceError::InvalidMacHeader(format!(
                        "MAC tag '{s}' does not match profile '{}'",
                        profile.as_str()
                    )));
                }
                tag_ok = true;
            }
            other => {
                return Err(SpaceError::InvalidMacHeader(format!(
                    "unexpected MAC parameter '{other}'"
                )));
            }
        }
    }
    if !tag_ok {
        return Err(SpaceError::InvalidMacHeader(
            "missing 'tag' parameter".into(),
        ));
    }
    let keyid =
        keyid.ok_or_else(|| SpaceError::InvalidMacHeader("missing 'keyid' parameter".into()))?;
    Ok((label, profile, keyid))
}

fn build_mac_signature_base(
    profile: MacProfile,
    covered_signature: &str,
    sig_params: &str,
) -> String {
    let p = profile.as_str();
    format!("\"{p}\";sf: {covered_signature}\n\"@signature-params\": {sig_params}")
}
