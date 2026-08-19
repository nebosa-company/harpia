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

/// Exact two-sided McNemar test on paired pass/fail outcomes.
/// `b` = tasks harness A solved and B did not; `c` = the reverse.
/// Small discordant counts are the norm at n=100 tasks, so the exact
/// binomial form is used rather than the chi-square approximation.
pub fn mcnemar_p(b: u32, c: u32) -> f64 {
    let n = b + c;
    if n == 0 {
        return 1.0;
    }
    let k_max = b.min(c);
    // 2 * P[Binomial(n, 1/2) <= min(b, c)], clamped.
    let mut coef: f64 = 1.0; // C(n, 0)
    let mut tail = coef;
    for k in 1..=k_max {
        coef *= (n - k + 1) as f64 / k as f64;
        tail += coef;
    }
    (2.0 * tail * 0.5f64.powi(n as i32)).min(1.0)
}

/// Two-sided Wilcoxon signed-rank test on paired score differences,
/// normal approximation with tie correction and continuity correction.
/// Zeros are dropped (Wilcooxon's original treatment). Returns None when
/// fewer than 6 non-zero pairs remain — too few for the approximation.
pub fn wilcoxon_p(diffs: &[f64]) -> Option<f64> {
    let mut nz: Vec<f64> = diffs.iter().copied().filter(|d| *d != 0.0).collect();
    let n = nz.len();
    if n < 6 {
        return None;
    }
    nz.sort_by(|a, b| a.abs().total_cmp(&b.abs()));
    // Average ranks over ties on |d|.
    let mut ranks = vec![0.0; n];
    let mut i = 0;
    let mut tie_correction = 0.0;
    while i < n {
        let mut j = i;
        while j + 1 < n && nz[j + 1].abs() == nz[i].abs() {
            j += 1;
        }
        let avg = (i + 1 + j + 1) as f64 / 2.0;
        for r in ranks.iter_mut().take(j + 1).skip(i) {
            *r = avg;
        }
        let t = (j - i + 1) as f64;
        tie_correction += t * t * t - t;
        i = j + 1;
    }
    let w_plus: f64 = nz
        .iter()
        .zip(&ranks)
        .filter(|(d, _)| **d > 0.0)
        .map(|(_, r)| *r)
        .sum();
    let nf = n as f64;
    let mean_w = nf * (nf + 1.0) / 4.0;
    let var_w = nf * (nf + 1.0) * (2.0 * nf + 1.0) / 24.0 - tie_correction / 48.0;
    if var_w <= 0.0 {
        return Some(1.0);
    }
    let z = (w_plus - mean_w).abs().max(0.5) - 0.5; // continuity correction
    let z = z / var_w.sqrt();
    Some((2.0 * (1.0 - normal_cdf(z))).min(1.0))
}

/// Unbiased pass@k estimator (Chen et al.): n attempts, c passes.
pub fn pass_at_k(n: u32, c: u32, k: u32) -> f64 {
    if n == 0 || k == 0 {
        return 0.0;
    }
    if c == 0 {
        return 0.0;
    }
    if n.saturating_sub(c) < k {
        return 1.0;
    }
    // 1 - C(n-c, k) / C(n, k) = 1 - prod_{i=n-c+1..n} (i - k) / i
    let mut prod = 1.0;
    for i in (n - c + 1)..=n {
        prod *= (i - k) as f64 / i as f64;
    }
    1.0 - prod
}

/// Standard normal CDF via Abramowitz–Stegun 7.1.26 erf approximation
/// (max abs error 1.5e-7 — far below reporting precision).
pub fn normal_cdf(z: f64) -> f64 {
    let x = z / std::f64::consts::SQRT_2;
    let (sign, x) = if x < 0.0 { (-1.0, -x) } else { (1.0, x) };
    let t = 1.0 / (1.0 + 0.3275911 * x);
    let poly = t
        * (0.254829592 + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))));
    let erf = sign * (1.0 - poly * (-x * x).exp());
    0.5 * (1.0 + erf)
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

    #[test]
    fn mcnemar_known_value() {
        // b=5, c=1: p = 2 * (C(6,0)+C(6,1)) / 2^6 = 14/64
        assert!((mcnemar_p(5, 1) - 0.21875).abs() < 1e-12);
        assert_eq!(mcnemar_p(0, 0), 1.0);
        assert!(mcnemar_p(20, 0) < 0.001);
    }

    #[test]
    fn mcnemar_is_symmetric() {
        assert_eq!(mcnemar_p(7, 2), mcnemar_p(2, 7));
    }

    #[test]
    fn wilcoxon_detects_a_shift() {
        let shifted: Vec<f64> = (1..=20).map(|i| 0.1 + (i % 3) as f64 * 0.01).collect();
        let p = wilcoxon_p(&shifted).unwrap();
        assert!(p < 0.01, "one-sided shift got p={p}");
    }

    #[test]
    fn wilcoxon_near_one_on_symmetric_diffs() {
        let sym = [0.1, -0.1, 0.2, -0.2, 0.3, -0.3, 0.15, -0.15];
        let p = wilcoxon_p(&sym).unwrap();
        assert!(p > 0.8, "symmetric diffs got p={p}");
    }

    #[test]
    fn wilcoxon_refuses_tiny_samples() {
        assert!(wilcoxon_p(&[0.1, 0.2, 0.0, 0.0, 0.3]).is_none());
    }

    #[test]
    fn pass_at_k_edges() {
        assert!((pass_at_k(3, 1, 1) - 1.0 / 3.0).abs() < 1e-12);
        assert_eq!(pass_at_k(3, 1, 3), 1.0);
        assert_eq!(pass_at_k(3, 0, 1), 0.0);
        assert_eq!(pass_at_k(1, 1, 1), 1.0);
    }
}
