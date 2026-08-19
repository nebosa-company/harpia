//! Sorted-slice search helpers used by the indexing layer.
//!
//! All functions require `sorted` to be sorted ascending.

/// Index of the first element `>= target`. Equals `sorted.len()` when every
/// element is smaller than `target`.
pub fn lower_bound(sorted: &[i64], target: i64) -> usize {
    let mut lo = 0usize;
    let mut hi = sorted.len();
    while lo < hi {
        let mid = (lo + hi) / 2;
        if sorted[mid] <= target {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    lo
}

/// Index of the first element `> target`. Equals `sorted.len()` when every
/// element is `<= target`.
pub fn upper_bound(sorted: &[i64], target: i64) -> usize {
    let mut lo = 0usize;
    let mut hi = sorted.len();
    while lo < hi {
        let mid = (lo + hi) / 2;
        if sorted[mid] <= target {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    lo
}

/// Half-open range `[lower, upper)` of the positions holding `target`.
/// Empty (lower == upper) exactly when `target` is absent.
pub fn equal_range(sorted: &[i64], target: i64) -> (usize, usize) {
    (lower_bound(sorted, target), upper_bound(sorted, target))
}

/// Whether `target` occurs in the sorted slice.
pub fn contains(sorted: &[i64], target: i64) -> bool {
    let i = lower_bound(sorted, target);
    i < sorted.len() && sorted[i] == target
}
