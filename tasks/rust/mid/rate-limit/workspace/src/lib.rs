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
    // TODO: track capacity, rate, balance and the last-refill timestamp.
    _todo: std::marker::PhantomData<()>,
}

impl<C: Clock> TokenBucket<C> {
    /// A full bucket. Reads the clock once for the initial timestamp.
    pub fn new(capacity: u64, refill_per_sec: u64, clock: C) -> Self {
        let _ = (capacity, refill_per_sec, &clock);
        todo!("create the bucket")
    }

    /// Take `tokens` whole tokens if available: true on success, false (and
    /// no deduction) otherwise.
    pub fn try_acquire(&mut self, tokens: u64) -> bool {
        let _ = tokens;
        todo!("acquire tokens")
    }

    /// Whole tokens currently available (after lazy refill).
    pub fn available(&mut self) -> u64 {
        todo!("report availability")
    }
}
