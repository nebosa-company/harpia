use rate_limit::{Clock, TokenBucket};
use std::cell::Cell;
use std::rc::Rc;

#[derive(Clone)]
struct FakeClock(Rc<Cell<u64>>);

impl FakeClock {
    fn new() -> Self {
        FakeClock(Rc::new(Cell::new(0)))
    }
    fn set(&self, millis: u64) {
        self.0.set(millis);
    }
}

impl Clock for FakeClock {
    fn now_millis(&self) -> u64 {
        self.0.get()
    }
}

#[test]
fn bucket_starts_full() {
    let clock = FakeClock::new();
    let mut bucket = TokenBucket::new(5, 1, clock.clone());
    assert_eq!(bucket.available(), 5);
    assert!(bucket.try_acquire(5));
    assert_eq!(bucket.available(), 0);
}

#[test]
fn acquire_beyond_balance_fails_without_deduction() {
    let clock = FakeClock::new();
    let mut bucket = TokenBucket::new(3, 1, clock.clone());
    assert!(bucket.try_acquire(2));
    assert!(!bucket.try_acquire(2));
    assert_eq!(bucket.available(), 1);
    assert!(bucket.try_acquire(1));
    assert!(!bucket.try_acquire(1));
}

#[test]
fn refill_is_proportional_to_elapsed_time() {
    let clock = FakeClock::new();
    let mut bucket = TokenBucket::new(10, 2, clock.clone());
    assert!(bucket.try_acquire(10));
    clock.set(500); // 0.5 s at 2 tokens/s -> 1 token
    assert_eq!(bucket.available(), 1);
    assert!(!bucket.try_acquire(2));
    clock.set(1000); // another 0.5 s -> 2 tokens total
    assert!(bucket.try_acquire(2));
    assert_eq!(bucket.available(), 0);
}

#[test]
fn refill_clamps_at_capacity() {
    let clock = FakeClock::new();
    let mut bucket = TokenBucket::new(4, 100, clock.clone());
    assert!(bucket.try_acquire(4));
    clock.set(3_600_000); // an hour later
    assert_eq!(bucket.available(), 4);
    assert!(bucket.try_acquire(4));
    assert!(!bucket.try_acquire(1));
}

#[test]
fn tokens_accumulate_across_acquires() {
    let clock = FakeClock::new();
    let mut bucket = TokenBucket::new(100, 10, clock.clone());
    assert!(bucket.try_acquire(100));
    clock.set(100); // 1 token
    assert!(bucket.try_acquire(1));
    clock.set(200); // 1 more
    assert!(bucket.try_acquire(1));
    clock.set(300);
    assert!(!bucket.try_acquire(2));
    assert!(bucket.try_acquire(1));
}
