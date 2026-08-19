//! One deterministic PRNG, shared by every resampling routine in Harpia.
//!
//! Robustness numbers that move between two runs of the same report are not
//! robustness numbers. Every bootstrap, permutation and shuffle in the
//! codebase draws from this generator with an explicit seed, so a report is
//! reproducible from the database alone.

/// xorshift64. Not cryptographic — it resamples finite arrays, and its whole
/// job is to do that identically every time.
#[derive(Debug, Clone)]
pub struct Rng(u64);

impl Rng {
    /// `seed | 1`: xorshift has a fixed point at zero, and a report seeded 0
    /// would silently resample the same index forever.
    pub fn new(seed: u64) -> Self {
        Self(seed | 1)
    }

    #[inline]
    pub fn next_u64(&mut self) -> u64 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        self.0
    }

    /// Uniform-ish index below `n`. The modulo bias is ~2^-64 relative and
    /// irrelevant at the array sizes a benchmark resamples.
    #[inline]
    pub fn below(&mut self, n: usize) -> usize {
        if n == 0 {
            return 0;
        }
        (self.next_u64() as usize) % n
    }

    /// Fisher–Yates, in place.
    pub fn shuffle<T>(&mut self, xs: &mut [T]) {
        for i in (1..xs.len()).rev() {
            let j = self.below(i + 1);
            xs.swap(i, j);
        }
    }

    /// One bootstrap resample of `0..n` (with replacement).
    pub fn resample_indices(&mut self, n: usize) -> Vec<usize> {
        (0..n).map(|_| self.below(n)).collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn same_seed_same_stream() {
        let mut a = Rng::new(7);
        let mut b = Rng::new(7);
        for _ in 0..100 {
            assert_eq!(a.next_u64(), b.next_u64());
        }
    }

    #[test]
    fn zero_seed_is_not_a_fixed_point() {
        let mut r = Rng::new(0);
        assert_ne!(r.next_u64(), 0);
    }

    #[test]
    fn shuffle_is_a_permutation() {
        let mut xs: Vec<u32> = (0..50).collect();
        Rng::new(3).shuffle(&mut xs);
        xs.sort();
        assert_eq!(xs, (0..50).collect::<Vec<_>>());
    }

    #[test]
    fn resample_stays_in_range() {
        let idx = Rng::new(11).resample_indices(8);
        assert_eq!(idx.len(), 8);
        assert!(idx.iter().all(|&i| i < 8));
    }
}
