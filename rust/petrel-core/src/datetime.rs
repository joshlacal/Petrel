//! Lexicon datetime parsing and proleptic Gregorian calendar conversion.

use std::fmt;
use std::hash::{Hash, Hasher};
use std::str::FromStr;

use crate::error::{DecodeError, EncodeError, SyntaxError, SyntaxKind};
use crate::serde_bridge::{FromValue, ToValue};
use crate::value::{Value, serde_via_value};
use crate::xrpc::QueryValue;

const MIN_SECONDS: i64 = -62_167_219_200; // 0000-01-01T00:00:00Z
const MAX_SECONDS: i64 = 253_402_300_799; // 9999-12-31T23:59:59Z
const NANOS_PER_SECOND: u32 = 1_000_000_000;
const SECONDS_PER_DAY: i64 = 86_400;
const EPOCH: &str = "1970-01-01T00:00:00.000Z";

/// A timestamp whose wire spelling is preserved and whose identity is its instant.
///
/// Fractional seconds are stored to nanosecond resolution. Any remaining digits
/// are retained in the original spelling.
#[derive(Debug, Clone)]
pub struct Datetime {
    wire: String,
    instant: Instant,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
struct Instant {
    secs: i64,
    nanos: u32,
}

impl Instant {
    fn new(secs: i64, nanos: u32) -> Result<Self, SyntaxError> {
        if !(MIN_SECONDS..=MAX_SECONDS).contains(&secs) {
            return Err(failure("UTC year must be 0000–9999"));
        }

        if nanos >= NANOS_PER_SECOND {
            return Err(failure("nanoseconds must be less than one second"));
        }

        Ok(Self { secs, nanos })
    }

    fn normalized_string(self) -> Result<String, SyntaxError> {
        // Round milliseconds to nearest, ties away from the Unix epoch.
        let bias = if self.secs < 0 { 499_999 } else { 500_000 };
        let millis = self.secs * 1000 + i64::from((self.nanos + bias) / 1_000_000);
        let secs = millis.div_euclid(1000);
        if secs > MAX_SECONDS {
            return Err(failure(
                "millisecond rounding is outside UTC years 0000–9999",
            ));
        }
        let ms = millis.rem_euclid(1000);
        let second_of_day = secs.rem_euclid(SECONDS_PER_DAY);
        let (year, month, day) = civil_from_days(secs.div_euclid(SECONDS_PER_DAY));
        let hour = second_of_day / 3600;
        let minute = second_of_day / 60 % 60;
        let second = second_of_day % 60;
        Ok(format!(
            "{year:04}-{month:02}-{day:02}T{hour:02}:{minute:02}:{second:02}.{ms:03}Z"
        ))
    }
}

impl Datetime {
    /// Parses the strict AT Protocol datetime grammar.
    pub fn parse(value: impl Into<String>) -> Result<Self, SyntaxError> {
        let wire = value.into();
        let instant = parse(&wire, false)?;
        Ok(Self { wire, instant })
    }

    /// Whether the string satisfies the strict AT Protocol datetime grammar.
    pub fn is_valid_datetime(value: &str) -> bool {
        parse(value, false).is_ok()
    }

    /// Builds an instant from Unix seconds and a nonnegative nanosecond offset.
    /// Its wire form uses UTC and millisecond precision.
    pub fn from_unix(secs: i64, nanos: u32) -> Result<Self, SyntaxError> {
        let instant = Instant::new(secs, nanos)?;
        let wire = instant.normalized_string()?;
        Ok(Self { wire, instant })
    }

    /// The current instant, with UTC milliseconds as its wire form.
    ///
    /// The clock is available on native targets and on wasm with the wasm feature.
    #[cfg(any(not(target_arch = "wasm32"), feature = "wasm"))]
    pub fn now() -> Result<Self, SyntaxError> {
        Self::from_system_time(web_time::SystemTime::now())
    }

    /// Builds an instant from a supplied clock time.
    #[cfg(any(not(target_arch = "wasm32"), feature = "wasm"))]
    pub fn from_system_time(time: web_time::SystemTime) -> Result<Self, SyntaxError> {
        match time.duration_since(web_time::UNIX_EPOCH) {
            Ok(duration) => {
                let secs = i64::try_from(duration.as_secs())
                    .map_err(|_| failure("clock time outside UTC years 0000–9999"))?;
                Self::from_unix(secs, duration.subsec_nanos())
            }
            Err(error) => {
                let duration = error.duration();
                let secs = i64::try_from(duration.as_secs())
                    .map_err(|_| failure("clock time outside UTC years 0000–9999"))?;
                let nanos = duration.subsec_nanos();
                if nanos == 0 {
                    Self::from_unix(-secs, 0)
                } else {
                    Self::from_unix(-secs - 1, NANOS_PER_SECOND - nanos)
                }
            }
        }
    }

    /// Whole Unix seconds, rounded down.
    pub fn unix_seconds(&self) -> i64 {
        self.instant.secs
    }

    /// Nanoseconds after the whole Unix second, always less than one billion.
    pub fn subsec_nanos(&self) -> u32 {
        self.instant.nanos
    }

    /// The original spelling or the generated UTC time.
    pub fn as_str(&self) -> &str {
        &self.wire
    }

    /// Unwraps the wire spelling.
    pub fn into_string(self) -> String {
        self.wire
    }

    /// Formats the instant in UTC with three fractional digits.
    pub fn to_normalized_string(&self) -> Result<String, SyntaxError> {
        self.instant.normalized_string()
    }
}

/// Accepts common datetime variations and writes strict UTC milliseconds.
pub fn normalize_datetime(value: &str) -> Result<String, SyntaxError> {
    parse(value.trim(), true)?.normalized_string()
}

/// Normalizes common datetime variations and uses the Unix epoch on failure.
pub fn normalize_datetime_always(value: &str) -> String {
    normalize_datetime(value).unwrap_or_else(|_| EPOCH.to_owned())
}

impl fmt::Display for Datetime {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

impl FromStr for Datetime {
    type Err = SyntaxError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        Self::parse(value)
    }
}

impl TryFrom<String> for Datetime {
    type Error = SyntaxError;

    fn try_from(value: String) -> Result<Self, Self::Error> {
        Self::parse(value)
    }
}

impl AsRef<str> for Datetime {
    fn as_ref(&self) -> &str {
        self.as_str()
    }
}

impl PartialEq for Datetime {
    fn eq(&self, other: &Self) -> bool {
        self.instant == other.instant
    }
}

impl Eq for Datetime {}

impl Hash for Datetime {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.instant.hash(state);
    }
}

impl PartialOrd for Datetime {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for Datetime {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.instant.cmp(&other.instant)
    }
}

impl ToValue for Datetime {
    fn to_value(&self) -> Result<Value, EncodeError> {
        Ok(Value::String(self.wire.clone()))
    }
}

impl FromValue for Datetime {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        Ok(Self::parse(String::from_value(value)?)?)
    }
}

impl QueryValue for Datetime {
    fn to_query_value(&self) -> String {
        self.wire.clone()
    }
}

serde_via_value!(Datetime);

fn failure(reason: &'static str) -> SyntaxError {
    SyntaxError::new(SyntaxKind::Datetime, reason)
}

fn parse(text: &str, lenient: bool) -> Result<Instant, SyntaxError> {
    if text.len() > 64 {
        return Err(failure("longer than 64 bytes"));
    }
    let mut cursor = Cursor(text.as_bytes());
    let (year, month, day) = cursor.date()?;
    if !(1..=12).contains(&month) || !(1..=days_in_month(year, month)).contains(&day) {
        return Err(failure("invalid Gregorian calendar date"));
    }
    let midnight = days_from_civil(year, month, day) * SECONDS_PER_DAY;
    if lenient && cursor.is_empty() {
        return Instant::new(midnight, 0);
    }

    if !cursor.eat(b'T') && !(lenient && (cursor.eat(b't') || cursor.eat(b' ') || cursor.eat(b'_')))
    {
        return Err(failure("date and time must be separated by uppercase T"));
    }

    let (elapsed, nanos) = cursor.time(lenient)?;
    let offset = cursor.offset(lenient)?;
    if !cursor.is_empty() {
        return Err(failure("unexpected characters after the timezone"));
    }

    Instant::new(midnight + elapsed - offset, nanos)
}

struct Cursor<'a>(&'a [u8]);

impl Cursor<'_> {
    fn is_empty(&self) -> bool {
        self.0.is_empty()
    }

    fn eat(&mut self, byte: u8) -> bool {
        if let Some(rest) = self.0.strip_prefix(&[byte]) {
            self.0 = rest;
            true
        } else {
            false
        }
    }

    fn digits(&mut self, count: usize) -> Option<i64> {
        let (digits, rest) = self.0.split_at_checked(count)?;
        if !digits.iter().all(u8::is_ascii_digit) {
            return None;
        }
        self.0 = rest;
        Some(
            digits
                .iter()
                .fold(0, |result, byte| result * 10 + i64::from(byte - b'0')),
        )
    }

    fn date(&mut self) -> Result<(i64, i64, i64), SyntaxError> {
        let invalid = || failure("date must be YYYY-MM-DD");
        let year = self.digits(4).ok_or_else(invalid)?;
        if !self.eat(b'-') {
            return Err(invalid());
        }
        let month = self.digits(2).ok_or_else(invalid)?;
        if !self.eat(b'-') {
            return Err(invalid());
        }
        let day = self.digits(2).ok_or_else(invalid)?;
        Ok((year, month, day))
    }

    fn time(&mut self, lenient: bool) -> Result<(i64, u32), SyntaxError> {
        let invalid = || failure("time must be HH:MM:SS");
        let hour = self.digits(2).ok_or_else(invalid)?;
        if !self.eat(b':') {
            return Err(invalid());
        }
        let minute = self.digits(2).ok_or_else(invalid)?;
        let (seconds, nanos) = if self.eat(b':') {
            let seconds = self.digits(2).ok_or_else(invalid)?;
            let nanos = if self.eat(b'.') {
                self.fraction(lenient)?
            } else {
                0
            };
            (seconds, nanos)
        } else if lenient {
            (0, 0)
        } else {
            return Err(invalid());
        };
        if hour > 23 || minute > 59 || seconds > 59 {
            return Err(failure("time components are out of range"));
        }
        Ok((hour * 3600 + minute * 60 + seconds, nanos))
    }

    fn fraction(&mut self, lenient: bool) -> Result<u32, SyntaxError> {
        let count = self
            .0
            .iter()
            .take_while(|byte| byte.is_ascii_digit())
            .count();
        if count == 0 && !lenient {
            return Err(failure("fractional seconds need at least one digit"));
        }
        let (digits, rest) = self.0.split_at(count);
        self.0 = rest;
        let mut nanos = 0;
        let mut scale = 100_000_000;
        for &byte in digits.iter().take(9) {
            nanos += u32::from(byte - b'0') * scale;
            scale /= 10;
        }
        Ok(nanos)
    }

    fn offset(&mut self, lenient: bool) -> Result<i64, SyntaxError> {
        if self.eat(b'Z') || (lenient && (self.eat(b'z') || self.is_empty())) {
            return Ok(0);
        }
        let negative = self.eat(b'-');
        if !negative && !self.eat(b'+') {
            return Err(failure("timezone must be Z or ±HH:MM"));
        }
        let invalid = || failure("timezone offset must contain two-digit hours and minutes");
        let hours = self.digits(2).ok_or_else(invalid)?;
        let minutes = if self.eat(b':') || (lenient && !self.is_empty()) {
            self.digits(2).ok_or_else(invalid)?
        } else if lenient {
            0
        } else {
            return Err(invalid());
        };
        if hours > 23 || minutes > 59 {
            return Err(failure("timezone offset is out of range"));
        }
        if !lenient && negative && hours == 0 && minutes == 0 {
            return Err(failure("-00:00 is not allowed"));
        }
        let magnitude = hours * 3600 + minutes * 60;
        Ok(if negative { -magnitude } else { magnitude })
    }
}

fn days_in_month(year: i64, month: i64) -> i64 {
    match month {
        2 if year % 400 == 0 || (year % 4 == 0 && year % 100 != 0) => 29,
        2 => 28,
        4 | 6 | 9 | 11 => 30,
        _ => 31,
    }
}

fn days_from_civil(year: i64, month: i64, day: i64) -> i64 {
    let adjusted_year = year - i64::from(month <= 2);
    let era = adjusted_year.div_euclid(400);
    let year_of_era = adjusted_year - era * 400;
    let month_index = if month > 2 { month - 3 } else { month + 9 };
    let day_of_year = (153 * month_index + 2) / 5 + day - 1;
    let day_of_era = year_of_era * 365 + year_of_era / 4 - year_of_era / 100 + day_of_year;
    era * 146_097 + day_of_era - 719_468
}

fn civil_from_days(days: i64) -> (i64, i64, i64) {
    let shifted = days + 719_468;
    let era = shifted.div_euclid(146_097);
    let day_of_era = shifted - era * 146_097;
    let year_of_era =
        (day_of_era - day_of_era / 1460 + day_of_era / 36524 - day_of_era / 146_096) / 365;
    let day_of_year = day_of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100);
    let month_index = (5 * day_of_year + 2) / 153;
    let day = day_of_year - (153 * month_index + 2) / 5 + 1;
    let month = if month_index < 10 {
        month_index + 3
    } else {
        month_index - 9
    };
    let year = year_of_era + era * 400 + i64::from(month <= 2);
    (year, month, day)
}

#[cfg(feature = "chrono")]
impl TryFrom<chrono::DateTime<chrono::Utc>> for Datetime {
    type Error = SyntaxError;

    fn try_from(value: chrono::DateTime<chrono::Utc>) -> Result<Self, Self::Error> {
        Self::from_unix(value.timestamp(), value.timestamp_subsec_nanos())
    }
}

#[cfg(feature = "chrono")]
impl TryFrom<Datetime> for chrono::DateTime<chrono::Utc> {
    type Error = SyntaxError;

    fn try_from(value: Datetime) -> Result<Self, Self::Error> {
        Self::from_timestamp(value.unix_seconds(), value.subsec_nanos())
            .ok_or_else(|| failure("instant is outside chrono's range"))
    }
}

#[cfg(any(feature = "time", feature = "jiff"))]
fn unix_nanos(value: &Datetime) -> i128 {
    i128::from(value.unix_seconds()) * i128::from(NANOS_PER_SECOND)
        + i128::from(value.subsec_nanos())
}

#[cfg(feature = "time")]
impl TryFrom<time::OffsetDateTime> for Datetime {
    type Error = SyntaxError;

    fn try_from(value: time::OffsetDateTime) -> Result<Self, Self::Error> {
        Self::from_unix(value.unix_timestamp(), value.nanosecond())
    }
}

#[cfg(feature = "time")]
impl TryFrom<Datetime> for time::OffsetDateTime {
    type Error = SyntaxError;

    fn try_from(value: Datetime) -> Result<Self, Self::Error> {
        Self::from_unix_timestamp_nanos(unix_nanos(&value))
            .map_err(|_| failure("instant is outside time's range"))
    }
}

#[cfg(feature = "jiff")]
impl TryFrom<jiff::Timestamp> for Datetime {
    type Error = SyntaxError;

    fn try_from(value: jiff::Timestamp) -> Result<Self, Self::Error> {
        let nanos = value.as_nanosecond();
        let unit = i128::from(NANOS_PER_SECOND);
        let secs = i64::try_from(nanos.div_euclid(unit))
            .map_err(|_| failure("instant is outside UTC years 0000–9999"))?;
        let nanos = u32::try_from(nanos.rem_euclid(unit))
            .map_err(|_| failure("invalid subsecond nanoseconds"))?;
        Self::from_unix(secs, nanos)
    }
}

#[cfg(feature = "jiff")]
impl TryFrom<Datetime> for jiff::Timestamp {
    type Error = SyntaxError;

    fn try_from(value: Datetime) -> Result<Self, Self::Error> {
        Self::from_nanosecond(unix_nanos(&value))
            .map_err(|_| failure("instant is outside jiff's range"))
    }
}
