//! Lexicon `datetime`.
//!
//! A [`Datetime`] keeps the exact string it was parsed from and re-emits it
//! verbatim: normalizing would change a record's CID.
//!
//! **Placeholder validator.** Lane 0 checks only the outline
//! `YYYY-MM-DDTHH:MM:SS[.fraction](Z|±HH:MM)`, which is enough for the
//! serialization spike to tell a datetime from garbage. Lane A (work package
//! C2) replaces it with the hand-written strict scanner ported from
//! `Sources/Petrel/Core/Utils/DateValidation.swift` (plan decision 7), stores
//! the instant next to the raw string, and switches equality, ordering and
//! hashing to the instant, as in Swift. No chrono, time or jiff in the
//! storage type; conversions sit behind features.

use crate::error::SyntaxKind;
use crate::syntax::string_newtype;

const OUTLINE: &str = "expected YYYY-MM-DDTHH:MM:SS[.fraction](Z|±HH:MM)";

fn validate_datetime(value: &str) -> Result<(), &'static str> {
    let bytes = value.as_bytes();
    if bytes.len() < 20 || bytes.len() > 64 {
        return Err(OUTLINE);
    }
    let (head, tail) = bytes.split_at(19);
    let shape_ok = head
        .iter()
        .zip(b"dddd-dd-ddTdd:dd:dd")
        .all(|(byte, pattern)| match pattern {
            b'd' => byte.is_ascii_digit(),
            literal => byte == literal,
        });
    if !shape_ok {
        return Err(OUTLINE);
    }
    let zone = match tail {
        [b'.', rest @ ..] => {
            let fraction = rest.iter().take_while(|b| b.is_ascii_digit()).count();
            if fraction == 0 {
                return Err(OUTLINE);
            }
            &rest[fraction..]
        }
        other => other,
    };
    match zone {
        b"Z" => Ok(()),
        [b'+' | b'-', h1, h2, b':', m1, m2]
            if [h1, h2, m1, m2].iter().all(|b| b.is_ascii_digit()) =>
        {
            Ok(())
        }
        _ => Err(OUTLINE),
    }
}

string_newtype!(
    /// Lexicon `datetime`: an RFC 3339 timestamp in the AT Protocol's strict
    /// intersection grammar. Serializes the raw string it was parsed from.
    Datetime,
    SyntaxKind::Datetime,
    validate_datetime
);
