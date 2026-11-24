//! Monotonic AT Protocol timestamp identifier generation.

use std::fmt;
use std::sync::Mutex;
#[cfg(any(not(target_arch = "wasm32"), feature = "wasm"))]
use std::sync::OnceLock;

use crate::{SyntaxError, SyntaxKind, Tid};

/// A generator with a single 10-bit clock ID.
///
/// Each call to [`Self::next`] advances at least one microsecond, even when the
/// clock stops or moves backwards. A call to [`Self::next_after`] may return an
/// identifier from further in the future than the generator's own clock.
pub struct TidGenerator {
    last: Mutex<u64>,
    clock_id: u16,
    clock: Box<dyn Fn() -> u64 + Send + Sync>,
}

impl TidGenerator {
    /// Constructs a generator with a random clock ID and the system clock.
    #[cfg(any(not(target_arch = "wasm32"), feature = "wasm"))]
    pub fn new() -> Result<Self, SyntaxError> {
        let mut random = [0; 2];
        getrandom::getrandom(&mut random).map_err(|_| failure("cannot obtain random clock ID"))?;
        Self::with_clock(u16::from_ne_bytes(random) & 1023, system_microseconds)
    }

    /// Constructs a generator with the given clock ID and microsecond clock.
    pub fn with_clock(
        clock_id: u16,
        clock: impl Fn() -> u64 + Send + Sync + 'static,
    ) -> Result<Self, SyntaxError> {
        if clock_id >= 1024 {
            return Err(failure("clock ID exceeds 10 bits"));
        }
        Ok(Self {
            last: Mutex::new(0),
            clock_id,
            clock: Box::new(clock),
        })
    }

    /// A generator shared by callers in this process or WebAssembly instance.
    #[cfg(any(not(target_arch = "wasm32"), feature = "wasm"))]
    pub fn shared() -> Result<&'static Self, SyntaxError> {
        static SHARED: OnceLock<TidGenerator> = OnceLock::new();
        if let Some(generator) = SHARED.get() {
            return Ok(generator);
        }
        let generator = Self::new()?;
        Ok(SHARED.get_or_init(|| generator))
    }

    /// The clock ID included in every generated TID.
    pub fn clock_id(&self) -> u16 {
        self.clock_id
    }

    /// Produces the next identifier, strictly increasing for this generator.
    pub fn next(&self) -> Result<Tid, SyntaxError> {
        let now = (self.clock)();
        let mut last = self
            .last
            .lock()
            .map_err(|_| failure("generator lock poisoned"))?;
        let timestamp = now.max(*last + 1);
        let tid = Tid::from_parts(timestamp, self.clock_id)?;
        *last = timestamp;
        Ok(tid)
    }

    /// Produces an identifier that sorts after `previous`.
    ///
    /// When `previous` is ahead of the local sequence, the result uses its
    /// timestamp plus one. The local sequence stays anchored to the local clock.
    pub fn next_after(&self, previous: &Tid) -> Result<Tid, SyntaxError> {
        if previous.has_high_bit() {
            return Err(failure("cannot follow a TID with its high bit set"));
        }
        if previous.timestamp_micros() == Tid::MAX_TIMESTAMP_MICROS {
            return Err(failure("cannot follow a TID with the maximum timestamp"));
        }

        let candidate = self.next()?;
        if candidate > *previous {
            Ok(candidate)
        } else {
            Tid::from_parts(previous.timestamp_micros() + 1, self.clock_id)
        }
    }
}

impl fmt::Debug for TidGenerator {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("TidGenerator")
            .field("clock_id", &self.clock_id)
            .finish_non_exhaustive()
    }
}

fn failure(reason: &'static str) -> SyntaxError {
    SyntaxError::new(SyntaxKind::Tid, reason)
}

#[cfg(any(not(target_arch = "wasm32"), feature = "wasm"))]
fn system_microseconds() -> u64 {
    web_time::SystemTime::now()
        .duration_since(web_time::UNIX_EPOCH)
        .map_or(0, |duration| {
            u64::try_from(duration.as_micros()).unwrap_or(u64::MAX)
        })
}
