//! Rate-limit header interpretation, `Retry-After` parsing, and retry backoff policies.

use std::time::Duration;

use petrel_core::xrpc::RateLimit;
use web_time::{SystemTime, UNIX_EPOCH};

/// Configurable exponential backoff policy with symmetric jitter.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BackoffPolicy {
    /// Initial delay before exponential scaling.
    pub base: Duration,
    /// Upper bound on computed backoff delays.
    pub max: Duration,
    /// Upper bound when honoring a server-supplied `Retry-After` header.
    pub max_retry_after: Duration,
    /// Fractional jitter spread in `[0.0, 1.0]`.
    pub spread: f64,
    /// Total attempts allowed before giving up.
    pub max_attempts: u32,
}

impl Default for BackoffPolicy {
    fn default() -> Self {
        Self {
            base: Duration::from_secs(1),
            max: Duration::from_secs(30),
            max_retry_after: Duration::from_secs(30),
            spread: 0.2,
            max_attempts: 3,
        }
    }
}

impl BackoffPolicy {
    /// Computes the next retry delay for a 1-based failed attempt number.
    ///
    /// When `retry_after` is provided, it is clamped by `max_retry_after`.
    #[must_use]
    pub fn next_delay(&self, attempt: u32, retry_after: Option<Duration>) -> Duration {
        if let Some(delay) = retry_after {
            return delay.min(self.max_retry_after);
        }
        let exp = attempt.saturating_sub(1).min(30);
        let factor = 1_u32.checked_shl(exp).unwrap_or(u32::MAX);
        let raw = self.base.saturating_mul(factor).min(self.max);
        let spread = self.spread.clamp(0.0, 1.0);
        let mut random_bytes = [0_u8; 2];
        let variation = getrandom::getrandom(&mut random_bytes).map_or(1.0, |()| {
            let fraction = f64::from(u16::from_ne_bytes(random_bytes)) / f64::from(u16::MAX);
            1.0 + spread * (2.0 * fraction - 1.0)
        });
        raw.mul_f64(variation.max(0.0))
    }
}

/// Convenience wrapper for interpreting an XRPC `RateLimit` snapshot against wall time.
#[derive(Debug, Clone, PartialEq)]
pub struct RateLimitStatus {
    /// Parsed header values.
    pub limit: RateLimit,
}

impl RateLimitStatus {
    /// Wraps a parsed [`RateLimit`].
    #[must_use]
    pub const fn new(limit: RateLimit) -> Self {
        Self { limit }
    }

    /// Returns `true` when zero requests remain in the current window.
    #[must_use]
    pub const fn is_exhausted(&self) -> bool {
        self.limit.remaining <= 0
    }

    /// Returns the remaining duration until the current rate-limit window resets.
    #[must_use]
    pub fn reset_delay(&self, now: SystemTime) -> Option<Duration> {
        let now_secs = now.duration_since(UNIX_EPOCH).ok()?.as_secs_f64();
        let remaining = self.limit.reset_unix_seconds - now_secs;
        if !remaining.is_finite() || remaining <= 0.0 {
            return Some(Duration::ZERO);
        }
        Duration::try_from_secs_f64(remaining).ok()
    }
}

/// Parses an HTTP `Retry-After` header value as either delay seconds or an HTTP-date.
#[must_use]
pub fn parse_retry_after(header: &str, now: SystemTime) -> Option<Duration> {
    let trimmed = header.trim();
    if trimmed.is_empty() {
        return None;
    }
    if let Ok(seconds) = trimmed.parse::<f64>() {
        if !seconds.is_finite() || seconds < 0.0 {
            return None;
        }
        return Duration::try_from_secs_f64(seconds).ok();
    }
    let target = parse_http_date(trimmed)?;
    Some(target.duration_since(now).unwrap_or(Duration::ZERO))
}

/// Parses RFC 7231 HTTP-dates (`IMF-fixdate`, obsolete `RFC 850`, and `asctime`).
#[must_use]
pub fn parse_http_date(value: &str) -> Option<SystemTime> {
    let trimmed = value.trim();
    let (day, month, year, hour, minute, second) = if let Some((_, rest)) = trimmed.split_once(", ")
    {
        let parts: Vec<&str> = rest.split_ascii_whitespace().collect();
        if parts.len() == 5 {
            // IMF-fixdate: "21 Oct 2015 07:28:00 GMT"
            if parts[4] != "GMT" {
                return None;
            }
            let day: u32 = parts[0].parse().ok()?;
            let month = parse_month(parts[1])?;
            let year: i64 = parts[2].parse().ok()?;
            let (hour, minute, second) = parse_hms(parts[3])?;
            (day, month, year, hour, minute, second)
        } else if parts.len() == 3 {
            // RFC 850: "06-Nov-94 08:49:37 GMT"
            if parts[2] != "GMT" {
                return None;
            }
            let mut date_parts = parts[0].split('-');
            let day: u32 = date_parts.next()?.parse().ok()?;
            let month = parse_month(date_parts.next()?)?;
            let short_year: i64 = date_parts.next()?.parse().ok()?;
            if date_parts.next().is_some() || !(0..=99).contains(&short_year) {
                return None;
            }
            let year = if short_year >= 70 {
                1900 + short_year
            } else {
                2000 + short_year
            };
            let (hour, minute, second) = parse_hms(parts[1])?;
            (day, month, year, hour, minute, second)
        } else {
            return None;
        }
    } else {
        // asctime: "Sun Nov  6 08:49:37 1994"
        let parts: Vec<&str> = trimmed.split_ascii_whitespace().collect();
        if parts.len() != 5 {
            return None;
        }
        let month = parse_month(parts[1])?;
        let day: u32 = parts[2].parse().ok()?;
        let (hour, minute, second) = parse_hms(parts[3])?;
        let year: i64 = parts[4].parse().ok()?;
        (day, month, year, hour, minute, second)
    };

    if year < 1970 || !(1..=31).contains(&day) || hour > 23 || minute > 59 || second > 59 {
        return None;
    }
    let max_day = days_in_month(year, month);
    if day > max_day {
        return None;
    }
    let days = days_since_epoch(year, month, day)?;
    let secs = days
        .checked_mul(86_400)?
        .checked_add(u64::from(hour) * 3_600 + u64::from(minute) * 60 + u64::from(second))?;
    UNIX_EPOCH.checked_add(Duration::from_secs(secs))
}

fn parse_hms(value: &str) -> Option<(u32, u32, u32)> {
    let mut parts = value.split(':');
    let hour = parts.next()?.parse().ok()?;
    let minute = parts.next()?.parse().ok()?;
    let second = parts.next()?.parse().ok()?;
    if parts.next().is_some() {
        return None;
    }
    Some((hour, minute, second))
}

fn parse_month(name: &str) -> Option<u32> {
    match name {
        "Jan" => Some(1),
        "Feb" => Some(2),
        "Mar" => Some(3),
        "Apr" => Some(4),
        "May" => Some(5),
        "Jun" => Some(6),
        "Jul" => Some(7),
        "Aug" => Some(8),
        "Sep" => Some(9),
        "Oct" => Some(10),
        "Nov" => Some(11),
        "Dec" => Some(12),
        _ => None,
    }
}

fn is_leap_year(year: i64) -> bool {
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

fn days_in_month(year: i64, month: u32) -> u32 {
    match month {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        2 => {
            if is_leap_year(year) {
                29
            } else {
                28
            }
        }
        _ => 0,
    }
}

fn days_since_epoch(year: i64, month: u32, day: u32) -> Option<u64> {
    // Howard Hinnant's civil-from-days inverse for UTC calendar dates.
    let adj_year = if month <= 2 { year - 1 } else { year };
    let era = adj_year.div_euclid(400);
    let yoe = u64::try_from(adj_year - era * 400).ok()?;
    let m = u64::from(month);
    let d = u64::from(day);
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    let total = era * 146_097 + i64::try_from(doe).ok()? - 719_468;
    u64::try_from(total).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_seconds_and_http_dates() {
        let now = UNIX_EPOCH + Duration::from_secs(1_700_000_000);
        assert_eq!(parse_retry_after("5", now), Some(Duration::from_secs(5)));
        assert_eq!(
            parse_retry_after(" 1.5 ", now),
            Some(Duration::from_millis(1_500))
        );
        assert_eq!(parse_retry_after("-1", now), None);

        let target_str = "Wed, 15 Nov 2023 22:13:30 GMT"; // 1700086410
        let parsed = parse_retry_after(target_str, now).unwrap();
        assert_eq!(parsed, Duration::from_secs(86_410));

        // Past HTTP-date clamps to zero.
        let past = parse_retry_after("Wed, 21 Oct 2015 07:28:00 GMT", now).unwrap();
        assert_eq!(past, Duration::ZERO);
    }

    #[test]
    fn status_reports_exhaustion_and_reset_delay() {
        let now = UNIX_EPOCH + Duration::from_secs(1_000);
        let status = RateLimitStatus::new(RateLimit {
            limit: 100,
            remaining: 0,
            reset_unix_seconds: 1_012.5,
            policy: None,
        });
        assert!(status.is_exhausted());
        assert_eq!(status.reset_delay(now), Some(Duration::from_millis(12_500)));
    }
}
