//! Statistics for benchmark reporting: bootstrap CIs and paired tests.
//! Deliberately dependency-free; a benchmark must not drift with a stats crate.

/// Percentile-bootstrap confidence interval of the mean.
/// Deterministic: seeded xorshift, so reports are reproducible.
pub fn bootstrap_ci_mean(xs: &[f64], iters: u32, alpha: f64, seed: u64) -> Option<(f64, f64)> {
    if xs.is_empty() {
        return None;
    }
    let mut rng = seed | 1;
    let mut means: Vec<f64> = (0..iters)
        .map(|_| {
            let mut acc = 0.0;
            for _ in 0..xs.len() {
                rng ^= rng << 13;
                rng ^= rng >> 7;
                rng ^= rng << 17;
                acc += xs[(rng as usize) % xs.len()];
            }
            acc / xs.len() as f64
        })
        .collect();
    means.sort_by(|a, b| a.total_cmp(b));
    let lo = ((alpha / 2.0) * iters as f64) as usize;
    let hi = ((1.0 - alpha / 2.0) * iters as f64) as usize;
    Some((means[lo.min(means.len() - 1)], means[hi.min(means.len() - 1)]))
}

pub fn mean(xs: &[f64]) -> f64 {
    if xs.is_empty() { 0.0 } else { xs.iter().sum::<f64>() / xs.len() as f64 }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ci_brackets_mean() {
        let xs = [0.2, 0.4, 0.6, 0.8, 1.0, 0.5, 0.3, 0.7];
        let (lo, hi) = bootstrap_ci_mean(&xs, 2000, 0.05, 42).unwrap();
        let m = mean(&xs);
        assert!(lo <= m && m <= hi, "{lo} <= {m} <= {hi}");
    }

    #[test]
    fn ci_is_deterministic() {
        let xs = [0.1, 0.9, 0.5];
        assert_eq!(
            bootstrap_ci_mean(&xs, 500, 0.05, 7),
            bootstrap_ci_mean(&xs, 500, 0.05, 7)
        );
    }
}
