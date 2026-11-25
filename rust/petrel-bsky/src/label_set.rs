//! Label expiration/negation semantics and stateful [`LabelSet`] accumulation.

use std::collections::HashMap;

use petrel_api::generated::com::atproto::label::defs::Label;
use petrel_core::{Datetime, Did};

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

/// Accumulated state of a label stream with negation tombstones and expiration filtering.
#[derive(Debug, Clone, Default)]
pub struct LabelSet {
    latest: HashMap<LabelKey, Label>,
    cursor: Option<i64>,
}

impl LabelSet {
    /// Creates an empty label set.
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Returns the sequence cursor of the last applied `#labels` stream event.
    #[must_use]
    pub const fn cursor(&self) -> Option<i64> {
        self.cursor
    }

    /// Applies one label, returning `true` if accepted (newer or equal timestamp, or unseen key).
    pub fn apply(&mut self, label: Label) -> bool {
        let key = LabelKey::from_label(&label);
        if let Some(stored) = self.latest.get(&key)
            && cmp_datetime(&stored.cts, &label.cts).is_gt()
        {
            return false;
        }
        self.latest.insert(key, label);
        true
    }

    /// Applies a stream event (`Labels` applies each label in order and updates `cursor`).
    pub fn apply_event(&mut self, event: LabelStreamEvent) {
        if let LabelStreamEvent::Labels { seq, labels } = event {
            for label in labels {
                self.apply(label);
            }
            self.cursor = Some(seq);
        }
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
