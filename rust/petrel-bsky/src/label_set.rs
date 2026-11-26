//! Label expiration/negation semantics and stateful [`LabelSet`] accumulation.

use std::{collections::HashMap, fmt, sync::Arc, time::Duration};

use petrel::rt::{MaybeSend, MaybeSync};
use petrel_api::generated::com::atproto::label::defs::Label;
use petrel_core::{Datetime, Did};

/// Default clock skew tolerance (5 minutes) for incoming label `cts` timestamps.
pub const DEFAULT_MAX_FUTURE_CTS_SKEW: Duration = Duration::from_secs(300);

/// Optional cryptographic signature verification hook for incoming labels.
///
/// Embedders can attach a DID-document key verifier so unsigned or improperly signed
/// labels are rejected before entering [`LabelSet`].
pub trait LabelSignatureVerifier: MaybeSend + MaybeSync {
    /// Verifies `label.sig` for `label` issued by `label.src`.
    fn verify_label(&self, label: &Label) -> Result<(), String>;
}

/// Reason a label was rejected by [`LabelSet`] ingestion policy.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LabelRejectionReason {
    /// Label `src` did not match the stream's expected labeler DID.
    UnexpectedSource {
        /// Expected labeler DID bound to the stream/set.
        expected: Did,
        /// Actual `src` DID carried by the label.
        actual: Did,
    },
    /// Signature verification was required, but `label.sig` was absent.
    MissingSignature,
    /// Signature verification failed.
    InvalidSignature(String),
    /// Label `cts` exceeded `now + max_future_skew` and could poison replacement ordering.
    FutureTimestamp {
        /// Claimed creation timestamp on the label.
        cts: Datetime,
        /// Maximum allowed timestamp at evaluation time.
        max_allowed: Datetime,
    },
    /// No wall-clock source is available to evaluate `max_future_skew`.
    ClockUnavailable,
}

/// One label rejected while processing a [`LabelStreamEvent::Labels`] batch.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LabelRejection {
    /// Zero-based index of the rejected label within the frame's `labels` vector.
    pub index: usize,
    /// Policy failure reason.
    pub reason: LabelRejectionReason,
}

/// Summary of applying a [`LabelStreamEvent`] to [`LabelSet`].
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct LabelEventOutcome {
    /// Number of labels newly stored or replacing an older entry.
    pub accepted: usize,
    /// Number of stale replay labels ignored because a newer `cts` was already stored.
    pub stale: usize,
    /// Labels rejected by source, signature, or timestamp policy.
    pub rejected: Vec<LabelRejection>,
}

/// Helper trait adding lifecycle queries (`is_negation`, `is_expired`, `is_active`) to [`Label`].
pub trait LabelExt {
    /// Returns `true` when this label retracts an earlier label (`neg == Some(true)`).
    fn is_negation(&self) -> bool;
    /// Returns `true` when this label has an `exp` timestamp at or before `now`.
    fn is_expired(&self, now: &Datetime) -> bool;
    /// Returns `true` when this label is neither a negation nor expired at `now`.
    fn is_active(&self, now: &Datetime) -> bool;
}

impl LabelExt for Label {
    fn is_negation(&self) -> bool {
        self.neg == Some(true)
    }

    fn is_expired(&self, now: &Datetime) -> bool {
        self.exp.as_ref().is_some_and(|exp| {
            (exp.unix_seconds(), exp.subsec_nanos()) <= (now.unix_seconds(), now.subsec_nanos())
        })
    }

    fn is_active(&self, now: &Datetime) -> bool {
        !self.is_negation() && !self.is_expired(now)
    }
}

/// Decoded frame from `com.atproto.label.subscribeLabels`.
#[derive(Debug, Clone, PartialEq)]
pub enum LabelStreamEvent {
    /// Batch of labels with its stream sequence cursor.
    Labels {
        /// Monotonic stream sequence number.
        seq: i64,
        /// Labels in arrival order.
        labels: Vec<Label>,
    },
    /// Informational frame carrying no labels.
    Info {
        /// Frame name.
        name: String,
        /// Optional details.
        message: Option<String>,
    },
}

/// Identifying `(src, uri, val)` key for label replacement and negation tombstones.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct LabelKey {
    /// Labeler DID.
    pub src: Did,
    /// Subject URI or DID.
    pub uri: String,
    /// Label value.
    pub val: String,
}

impl LabelKey {
    /// Derives a key from a [`Label`].
    #[must_use]
    pub fn from_label(label: &Label) -> Self {
        Self {
            src: label.src.clone(),
            uri: label.uri.as_str().to_owned(),
            val: label.val.clone(),
        }
    }
}

/// Accumulated state of a label stream with negation tombstones, expiration filtering,
/// optional stream-`src` binding, signature verification hook, and future-`cts` bounding.
#[derive(Clone)]
pub struct LabelSet {
    latest: HashMap<LabelKey, Label>,
    cursor: Option<i64>,
    expected_src: Option<Did>,
    signature_verifier: Option<Arc<dyn LabelSignatureVerifier>>,
    require_signature: bool,
    max_future_skew: Option<Duration>,
}

impl fmt::Debug for LabelSet {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("LabelSet")
            .field("entry_count", &self.latest.len())
            .field("cursor", &self.cursor)
            .field("expected_src", &self.expected_src)
            .field("has_signature_verifier", &self.signature_verifier.is_some())
            .field("require_signature", &self.require_signature)
            .field("max_future_skew", &self.max_future_skew)
            .finish()
    }
}

impl Default for LabelSet {
    fn default() -> Self {
        Self::new()
    }
}

impl LabelSet {
    /// Creates an unbound label set with the default 5-minute future-`cts` skew guard.
    #[must_use]
    pub fn new() -> Self {
        Self {
            latest: HashMap::new(),
            cursor: None,
            expected_src: None,
            signature_verifier: None,
            require_signature: false,
            max_future_skew: Some(DEFAULT_MAX_FUTURE_CTS_SKEW),
        }
    }

    /// Creates a label set bound to a single labeler stream `src` DID.
    #[must_use]
    pub fn for_labeler(expected_src: Did) -> Self {
        Self::new().with_expected_src(expected_src)
    }

    /// Binds this set to reject any label whose `src` differs from `expected_src`.
    #[must_use]
    pub fn with_expected_src(mut self, expected_src: Did) -> Self {
        self.expected_src = Some(expected_src);
        self
    }

    /// Attaches an optional signature verifier and requires labels to carry a valid `sig`.
    #[must_use]
    pub fn with_signature_verifier(mut self, verifier: Arc<dyn LabelSignatureVerifier>) -> Self {
        self.signature_verifier = Some(verifier);
        self.require_signature = true;
        self
    }

    /// Configures whether labels without `sig` are rejected when no verifier is attached.
    #[must_use]
    pub const fn with_require_signature(mut self, required: bool) -> Self {
        self.require_signature = required;
        self
    }

    /// Configures the maximum allowed clock skew ahead of `now` for incoming `cts` timestamps.
    #[must_use]
    pub const fn with_max_future_skew(mut self, skew: Option<Duration>) -> Self {
        self.max_future_skew = skew;
        self
    }

    /// Returns the expected labeler DID when bound to a single stream.
    #[must_use]
    pub const fn expected_src(&self) -> Option<&Did> {
        self.expected_src.as_ref()
    }

    /// Returns the sequence cursor of the last applied `#labels` stream event.
    #[must_use]
    pub const fn cursor(&self) -> Option<i64> {
        self.cursor
    }

    /// Validates and applies one label against explicit `now`.
    ///
    /// Returns `Ok(true)` if applied, `Ok(false)` if a newer `cts` for the same key is already
    /// stored, or `Err(reason)` if rejected by source binding, future-`cts`, or signature checks.
    pub fn try_apply_at(
        &mut self,
        label: Label,
        now: &Datetime,
    ) -> Result<bool, LabelRejectionReason> {
        self.try_apply_internal(None, label, Some(now))
    }

    /// Validates and applies one label against explicit `now`, returning `true` only if stored.
    pub fn apply_at(&mut self, label: Label, now: &Datetime) -> bool {
        self.try_apply_at(label, now).unwrap_or(false)
    }

    /// Applies one label against the system clock, returning `true` if accepted.
    pub fn apply(&mut self, label: Label) -> bool {
        let now = current_datetime();
        self.try_apply_internal(None, label, now.as_ref())
            .unwrap_or(false)
    }

    /// Applies a stream event against explicit `expected_src` (when supplied) and `now`.
    pub fn try_apply_event_at(
        &mut self,
        expected_src: Option<&Did>,
        event: LabelStreamEvent,
        now: &Datetime,
    ) -> LabelEventOutcome {
        self.apply_event_internal(expected_src, event, Some(now))
    }

    /// Applies a stream event bound to `expected_src` using the system clock.
    pub fn apply_event_for(
        &mut self,
        expected_src: &Did,
        event: LabelStreamEvent,
    ) -> LabelEventOutcome {
        let now = current_datetime();
        self.apply_event_internal(Some(expected_src), event, now.as_ref())
    }

    /// Applies a stream event (`Labels` applies each label in order and updates `cursor`).
    pub fn apply_event(&mut self, event: LabelStreamEvent) {
        let now = current_datetime();
        let _ = self.apply_event_internal(None, event, now.as_ref());
    }

    fn apply_event_internal(
        &mut self,
        expected_src: Option<&Did>,
        event: LabelStreamEvent,
        now: Option<&Datetime>,
    ) -> LabelEventOutcome {
        let mut outcome = LabelEventOutcome::default();
        if let LabelStreamEvent::Labels { seq, labels } = event {
            let effective_src = match (self.expected_src.as_ref(), expected_src) {
                (Some(bound), Some(passed)) if bound != passed => {
                    for (index, label) in labels.into_iter().enumerate() {
                        outcome.rejected.push(LabelRejection {
                            index,
                            reason: LabelRejectionReason::UnexpectedSource {
                                expected: bound.clone(),
                                actual: label.src,
                            },
                        });
                    }
                    self.cursor = Some(seq);
                    return outcome;
                }
                (Some(bound), _) => Some(bound),
                (None, Some(passed)) => Some(passed),
                (None, None) => None,
            };

            let effective_src = effective_src.cloned();
            for (index, label) in labels.into_iter().enumerate() {
                match self.try_apply_internal(effective_src.as_ref(), label, now) {
                    Ok(true) => outcome.accepted += 1,
                    Ok(false) => outcome.stale += 1,
                    Err(reason) => outcome.rejected.push(LabelRejection { index, reason }),
                }
            }
            self.cursor = Some(seq);
        }
        outcome
    }

    fn try_apply_internal(
        &mut self,
        expected_src: Option<&Did>,
        label: Label,
        now: Option<&Datetime>,
    ) -> Result<bool, LabelRejectionReason> {
        let expected_src = expected_src.or(self.expected_src.as_ref());
        if let Some(expected) = expected_src
            && &label.src != expected
        {
            return Err(LabelRejectionReason::UnexpectedSource {
                expected: expected.clone(),
                actual: label.src,
            });
        }

        if let Some(skew) = self.max_future_skew {
            let Some(now) = now else {
                return Err(LabelRejectionReason::ClockUnavailable);
            };
            let max_allowed = add_duration_clamped(now, skew);
            if cmp_datetime(&label.cts, &max_allowed).is_gt() {
                return Err(LabelRejectionReason::FutureTimestamp {
                    cts: label.cts,
                    max_allowed,
                });
            }
        }

        if let Some(verifier) = &self.signature_verifier {
            if label.sig.is_none() {
                return Err(LabelRejectionReason::MissingSignature);
            }
            verifier
                .verify_label(&label)
                .map_err(LabelRejectionReason::InvalidSignature)?;
        } else if self.require_signature && label.sig.is_none() {
            return Err(LabelRejectionReason::MissingSignature);
        }

        let key = LabelKey::from_label(&label);
        if let Some(stored) = self.latest.get(&key)
            && cmp_datetime(&stored.cts, &label.cts).is_gt()
        {
            return Ok(false);
        }
        self.latest.insert(key, label);
        Ok(true)
    }

    /// Removes stored labels (including negation tombstones) whose `exp` is at or before `now`.
    pub fn purge_expired(&mut self, now: &Datetime) {
        self.latest.retain(|_, label| !label.is_expired(now));
    }

    /// Drops inactive labels and tombstones whose `cts` is strictly before `older_than`.
    pub fn prune(&mut self, now: &Datetime, older_than: &Datetime) {
        self.latest.retain(|_, label| {
            label.is_active(now) || !cmp_datetime(&label.cts, older_than).is_lt()
        });
    }

    /// Returns all currently active (non-negated, unexpired) labels matching `uri` (or all if `None`),
    /// sorted deterministically by `(val, src)`.
    #[must_use]
    pub fn active_labels(&self, uri: Option<&str>, now: &Datetime) -> Vec<&Label> {
        let mut out: Vec<&Label> = self
            .latest
            .values()
            .filter(|label| {
                label.is_active(now) && uri.is_none_or(|target| label.uri.as_str() == target)
            })
            .collect();
        out.sort_by(|a, b| {
            a.val
                .cmp(&b.val)
                .then_with(|| a.src.as_str().cmp(b.src.as_str()))
        });
        out
    }

    /// Returns the total number of stored entries (including negation tombstones).
    #[must_use]
    pub fn len(&self) -> usize {
        self.latest.len()
    }

    /// Returns `true` when no labels (or tombstones) are stored.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.latest.is_empty()
    }
}

fn cmp_datetime(a: &Datetime, b: &Datetime) -> std::cmp::Ordering {
    (a.unix_seconds(), a.subsec_nanos()).cmp(&(b.unix_seconds(), b.subsec_nanos()))
}

pub(crate) fn current_datetime() -> Option<Datetime> {
    #[cfg(any(not(target_arch = "wasm32"), feature = "wasm"))]
    {
        Datetime::now().ok()
    }
    #[cfg(not(any(not(target_arch = "wasm32"), feature = "wasm")))]
    {
        None
    }
}

fn add_duration_clamped(now: &Datetime, delta: Duration) -> Datetime {
    const MAX_UNIX_SECS: i64 = 253_402_300_799; // 9999-12-31T23:59:59Z
    const NANOS_PER_SEC: u64 = 1_000_000_000;

    let delta_secs = i64::try_from(delta.as_secs()).unwrap_or(i64::MAX);
    let nano_sum = u64::from(now.subsec_nanos()) + u64::from(delta.subsec_nanos());
    let carry = i64::try_from(nano_sum / NANOS_PER_SEC).unwrap_or(0);
    let nanos = u32::try_from(nano_sum % NANOS_PER_SEC).unwrap_or(0);
    let secs = now
        .unix_seconds()
        .saturating_add(delta_secs)
        .saturating_add(carry);
    if secs > MAX_UNIX_SECS {
        return Datetime::from_unix(MAX_UNIX_SECS, 999_999_999).unwrap_or_else(|_| now.clone());
    }
    Datetime::from_unix(secs, nanos).unwrap_or_else(|_| now.clone())
}
