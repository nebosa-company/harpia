//! Token-bucket rate limiting over an injectable clock.

/// Time source. Production uses a monotonic clock; tests drive time by hand.
pub trait Clock {
    /// Milliseconds since an arbitrary epoch. Expected to be monotonic, but
    /// the bucket must tolerate a stalled or backwards clock by simply not
    /// refilling.
    fn now_millis(&self) -> u64;
}

/// A token bucket: capacity tokens, refilled continuously at
/// `refill_per_sec` tokens per second, tracked in integer millitokens.
pub struct TokenBucket<C: Clock> {
    clock: C,
    cap_milli: u64,
    rate_per_sec: u64,
    balance_milli: u64,
    last_millis: u64,
}

impl<C: Clock> TokenBucket<C> {
    /// A full bucket. Reads the clock once for the initial timestamp.
    pub fn new(capacity: u64, refill_per_sec: u64, clock: C) -> Self {
        let last_millis = clock.now_millis();
        let cap_milli = capacity.saturating_mul(1000);
        TokenBucket {
            clock,
            cap_milli,
            rate_per_sec: refill_per_sec,
            balance_milli: cap_milli,
            last_millis,
        }
    }

    fn refill(&mut self) {
        let now = self.clock.now_millis();
        if now > self.last_millis {
            let gained = (now - self.last_millis).saturating_mul(self.rate_per_sec);
            self.balance_milli = self.balance_milli.saturating_add(gained).min(self.cap_milli);
            self.last_millis = now;
        }
    }

    /// Take `tokens` whole tokens if available: true on success, false (and
    /// no deduction) otherwise.
    pub fn try_acquire(&mut self, tokens: u64) -> bool {
        self.refill();
        let need = tokens.saturating_mul(1000);
        if self.balance_milli >= need {
            self.balance_milli -= need;
            true
        } else {
            false
        }
    }

    /// Whole tokens currently available (after lazy refill).
    pub fn available(&mut self) -> u64 {
        self.refill();
        self.balance_milli / 1000
    }
}
