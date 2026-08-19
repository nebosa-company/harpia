use rate_limit::{Clock, TokenBucket};
use std::cell::Cell;
use std::rc::Rc;

#[derive(Clone)]
struct FakeClock(Rc<Cell<u64>>);

impl FakeClock {
    fn at(millis: u64) -> Self {
        FakeClock(Rc::new(Cell::new(millis)))
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
fn fractional_millitokens_are_not_lost() {
    let clock = FakeClock::at(0);
    let mut bucket = TokenBucket::new(10, 3, clock.clone());
    assert!(bucket.try_acquire(10));
    clock.set(333); // 999 millitokens
    assert_eq!(bucket.available(), 0);
    assert!(!bucket.try_acquire(1));
    clock.set(334); // 1002 millitokens
    assert!(bucket.try_acquire(1));
    // 2 millitokens remain; 666 ms later: 2 + 1998 = 2000 exactly.
    clock.set(1000);
    assert!(bucket.try_acquire(2));
    assert_eq!(bucket.available(), 0);
}

#[test]
fn backwards_clock_does_not_refill_or_panic() {
    let clock = FakeClock::at(1000);
    let mut bucket = TokenBucket::new(5, 1, clock.clone());
    assert!(bucket.try_acquire(5));
    clock.set(500); // went backwards
    assert_eq!(bucket.available(), 0);
    assert!(!bucket.try_acquire(1));
    clock.set(1000); // back to where it was: still no elapsed time
    assert_eq!(bucket.available(), 0);
    clock.set(2000); // 1 s past the remembered timestamp
    assert_eq!(bucket.available(), 1);
    assert!(bucket.try_acquire(1));
}

#[test]
fn zero_rate_never_refills() {
    let clock = FakeClock::at(0);
    let mut bucket = TokenBucket::new(2, 0, clock.clone());
    assert!(bucket.try_acquire(2));
    clock.set(10_000_000);
    assert_eq!(bucket.available(), 0);
    assert!(!bucket.try_acquire(1));
}

#[test]
fn zero_token_acquire_always_succeeds() {
    let clock = FakeClock::at(0);
    let mut bucket = TokenBucket::new(1, 0, clock.clone());
    assert!(bucket.try_acquire(0));
    assert!(bucket.try_acquire(1));
    assert!(bucket.try_acquire(0));
    assert!(!bucket.try_acquire(1));
}

#[test]
fn nonzero_epoch_start() {
    let clock = FakeClock::at(1_000_000);
    let mut bucket = TokenBucket::new(3, 5, clock.clone());
    assert_eq!(bucket.available(), 3);
    assert!(bucket.try_acquire(3));
    clock.set(1_000_200); // 200 ms at 5/s -> exactly 1 token
    assert_eq!(bucket.available(), 1);
}
