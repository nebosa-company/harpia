//! Statistics for benchmark reporting: bootstrap CIs and paired tests.
//! Deliberately dependency-free; a benchmark must not drift with a stats crate.

use crate::rng::Rng;

/// Percentile-bootstrap confidence interval of the mean.
/// Deterministic: seeded xorshift, so reports are reproducible.
pub fn bootstrap_ci_mean(xs: &[f64], iters: u32, alpha: f64, seed: u64) -> Option<(f64, f64)> {
    if xs.is_empty() {
        return None;
    }
    let mut rng = Rng::new(seed);
    let mut means: Vec<f64> = (0..iters)
        .map(|_| {
            let mut acc = 0.0;
            for _ in 0..xs.len() {
                acc += xs[rng.below(xs.len())];
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

// ---------------------------------------------------------------------------
// Meta-evaluation statistics: numbers that describe the benchmark itself
// rather than the harnesses it grades.
// ---------------------------------------------------------------------------

/// Population variance (denominator n). A round's task scores are the whole
/// corpus, not a sample drawn from a larger one.
pub fn var(xs: &[f64]) -> f64 {
    if xs.is_empty() {
        return 0.0;
    }
    let m = mean(xs);
    xs.iter().map(|x| (x - m).powi(2)).sum::<f64>() / xs.len() as f64
}

pub fn sd(xs: &[f64]) -> f64 {
    var(xs).sqrt()
}

/// Sample variance (denominator n-1), for inference about a larger
/// population — the paired-difference machinery below wants this one.
pub fn sample_var(xs: &[f64]) -> f64 {
    if xs.len() < 2 {
        return 0.0;
    }
    let m = mean(xs);
    xs.iter().map(|x| (x - m).powi(2)).sum::<f64>() / (xs.len() - 1) as f64
}

pub fn sample_sd(xs: &[f64]) -> f64 {
    sample_var(xs).sqrt()
}

pub fn median(xs: &[f64]) -> f64 {
    quantile(xs, 0.5)
}

/// Linear-interpolated quantile of an unsorted slice.
pub fn quantile(xs: &[f64], q: f64) -> f64 {
    if xs.is_empty() {
        return 0.0;
    }
    let mut s = xs.to_vec();
    s.sort_by(|a, b| a.total_cmp(b));
    let pos = q.clamp(0.0, 1.0) * (s.len() - 1) as f64;
    let lo = pos.floor() as usize;
    let hi = pos.ceil() as usize;
    if lo == hi {
        s[lo]
    } else {
        s[lo] + (pos - lo as f64) * (s[hi] - s[lo])
    }
}

/// Pearson correlation. `None` when either side is constant — an item every
/// harness scores identically has no correlation to report, and returning
/// 0.0 there would read as "measured, and it is uncorrelated".
pub fn pearson(xs: &[f64], ys: &[f64]) -> Option<f64> {
    if xs.len() != ys.len() || xs.len() < 2 {
        return None;
    }
    let (mx, my) = (mean(xs), mean(ys));
    let mut num = 0.0;
    let (mut dx, mut dy) = (0.0, 0.0);
    for (x, y) in xs.iter().zip(ys) {
        num += (x - mx) * (y - my);
        dx += (x - mx).powi(2);
        dy += (y - my).powi(2);
    }
    if dx <= 0.0 || dy <= 0.0 {
        return None;
    }
    Some(num / (dx * dy).sqrt())
}

/// Cronbach's alpha over a subjects-by-items score matrix (KR-20 when the
/// entries are 0/1): the share of score variance that is signal. Every
/// reported gap implicitly claims this number is high.
pub fn cronbach_alpha(matrix: &[Vec<f64>]) -> Option<f64> {
    let n_subj = matrix.len();
    if n_subj < 2 {
        return None;
    }
    let k = matrix[0].len();
    if k < 2 || matrix.iter().any(|r| r.len() != k) {
        return None;
    }
    let mut item_var_sum = 0.0;
    for j in 0..k {
        let col: Vec<f64> = matrix.iter().map(|r| r[j]).collect();
        item_var_sum += sample_var(&col);
    }
    let totals: Vec<f64> = matrix.iter().map(|r| r.iter().sum()).collect();
    let total_var = sample_var(&totals);
    if total_var <= 0.0 {
        return None;
    }
    let kf = k as f64;
    Some((kf / (kf - 1.0)) * (1.0 - item_var_sum / total_var))
}

/// Spearman-Brown prophecy: reliability of a test `factor` times longer.
/// With `factor = 2` it turns a split-half correlation into full-test
/// reliability.
pub fn spearman_brown(r: f64, factor: f64) -> f64 {
    if r <= -1.0 {
        return -1.0;
    }
    (factor * r) / (1.0 + (factor - 1.0) * r)
}

/// Odd/even split-half reliability, Spearman-Brown corrected.
pub fn split_half_reliability(matrix: &[Vec<f64>]) -> Option<f64> {
    if matrix.len() < 2 {
        return None;
    }
    let k = matrix[0].len();
    if k < 4 {
        return None;
    }
    let mut a = Vec::with_capacity(matrix.len());
    let mut b = Vec::with_capacity(matrix.len());
    for row in matrix {
        if row.len() != k {
            return None;
        }
        a.push(row.iter().step_by(2).sum::<f64>());
        b.push(row.iter().skip(1).step_by(2).sum::<f64>());
    }
    pearson(&a, &b).map(|r| spearman_brown(r, 2.0))
}

/// Standard error of measurement: the error bar a reliability of `alpha`
/// implies for one score with observed spread `sd_total`.
pub fn sem(sd_total: f64, reliability: f64) -> f64 {
    sd_total * (1.0 - reliability.clamp(0.0, 1.0)).sqrt()
}

/// Inverse standard normal CDF (Acklam's rational approximation plus one
/// Halley refinement against `normal_cdf`).
pub fn normal_quantile(p: f64) -> f64 {
    if p <= 0.0 {
        return f64::NEG_INFINITY;
    }
    if p >= 1.0 {
        return f64::INFINITY;
    }
    const A: [f64; 6] = [
        -3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
        1.38357751867269e+02, -3.066479806614716e+01, 2.506628277459239e+00,
    ];
    const B: [f64; 5] = [
        -5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
        6.680131188771972e+01, -1.328068155288572e+01,
    ];
    const C: [f64; 6] = [
        -7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
        -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00,
    ];
    const D: [f64; 4] = [
        7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
        3.754408661907416e+00,
    ];
    const P_LOW: f64 = 0.02425;
    let x = if p < P_LOW {
        let q = (-2.0 * p.ln()).sqrt();
        (((((C[0] * q + C[1]) * q + C[2]) * q + C[3]) * q + C[4]) * q + C[5])
            / ((((D[0] * q + D[1]) * q + D[2]) * q + D[3]) * q + 1.0)
    } else if p <= 1.0 - P_LOW {
        let q = p - 0.5;
        let r = q * q;
        (((((A[0] * r + A[1]) * r + A[2]) * r + A[3]) * r + A[4]) * r + A[5]) * q
            / (((((B[0] * r + B[1]) * r + B[2]) * r + B[3]) * r + B[4]) * r + 1.0)
    } else {
        let q = (-2.0 * (1.0 - p).ln()).sqrt();
        -(((((C[0] * q + C[1]) * q + C[2]) * q + C[3]) * q + C[4]) * q + C[5])
            / ((((D[0] * q + D[1]) * q + D[2]) * q + D[3]) * q + 1.0)
    };
    let e = normal_cdf(x) - p;
    let u = e * (2.0 * std::f64::consts::PI).sqrt() * (x * x / 2.0).exp();
    x - u / (1.0 + x * u / 2.0)
}

/// Smallest paired difference in mean capability this design could detect,
/// at significance `alpha` and the given `power`. Printed beside every
/// comparison: a gap below the MDE is a gap the corpus cannot resolve.
pub fn mde_paired(sd_diff: f64, n: usize, alpha: f64, power: f64) -> Option<f64> {
    if n == 0 || sd_diff <= 0.0 {
        return None;
    }
    let z_a = normal_quantile(1.0 - alpha / 2.0);
    let z_b = normal_quantile(power);
    Some((z_a + z_b) * sd_diff / (n as f64).sqrt())
}

/// Achieved power for an observed paired effect — the honest companion to a
/// non-significant result, which is otherwise indistinguishable from "we did
/// not look hard enough".
pub fn power_paired(effect: f64, sd_diff: f64, n: usize, alpha: f64) -> Option<f64> {
    if n == 0 || sd_diff <= 0.0 {
        return None;
    }
    let z_a = normal_quantile(1.0 - alpha / 2.0);
    let ncp = effect.abs() * (n as f64).sqrt() / sd_diff;
    Some(normal_cdf(ncp - z_a))
}

/// Kendall's tau-b between two orderings, tie-corrected. Harpia uses it to
/// ask how far a resampled leaderboard drifts from the full-corpus one.
pub fn kendall_tau_b(xs: &[f64], ys: &[f64]) -> Option<f64> {
    let n = xs.len();
    if n != ys.len() || n < 2 {
        return None;
    }
    let (mut conc, mut disc) = (0i64, 0i64);
    let (mut tie_x, mut tie_y) = (0i64, 0i64);
    for i in 0..n {
        for j in (i + 1)..n {
            let dx = xs[i] - xs[j];
            let dy = ys[i] - ys[j];
            if dx == 0.0 && dy == 0.0 {
                tie_x += 1;
                tie_y += 1;
            } else if dx == 0.0 {
                tie_x += 1;
            } else if dy == 0.0 {
                tie_y += 1;
            } else if dx.signum() * dy.signum() > 0.0 {
                conc += 1;
            } else {
                disc += 1;
            }
        }
    }
    let n0 = (n * (n - 1) / 2) as f64;
    let denom = ((n0 - tie_x as f64) * (n0 - tie_y as f64)).sqrt();
    (denom > 0.0).then(|| (conc - disc) as f64 / denom)
}

/// ICC(1,1): one-way random-effects intraclass correlation over repeated
/// measurements of the same subjects, with the standard k0 correction for
/// unbalanced groups. The test-retest number: the share of observed variance
/// that is between-subject rather than between-repeat.
pub fn icc_1_1(groups: &[Vec<f64>]) -> Option<f64> {
    let usable: Vec<&Vec<f64>> = groups.iter().filter(|g| g.len() >= 2).collect();
    let n = usable.len();
    if n < 2 {
        return None;
    }
    let total_obs: usize = usable.iter().map(|g| g.len()).sum();
    let all: Vec<f64> = usable.iter().flat_map(|g| g.iter().copied()).collect();
    let grand = mean(&all);
    let ss_between: f64 = usable
        .iter()
        .map(|g| g.len() as f64 * (mean(g) - grand).powi(2))
        .sum();
    let ss_within: f64 = usable
        .iter()
        .map(|g| {
            let m = mean(g);
            g.iter().map(|x| (x - m).powi(2)).sum::<f64>()
        })
        .sum();
    let df_between = (n - 1) as f64;
    let df_within = (total_obs - n) as f64;
    if df_within <= 0.0 {
        return None;
    }
    let ms_between = ss_between / df_between;
    let ms_within = ss_within / df_within;
    let sum_sq: f64 = usable.iter().map(|g| (g.len() as f64).powi(2)).sum();
    let k0 = (total_obs as f64 - sum_sq / total_obs as f64) / df_between;
    if k0 <= 0.0 {
        return None;
    }
    let denom = ms_between + (k0 - 1.0) * ms_within;
    if denom <= 0.0 {
        // No variance anywhere: every repeat identical, perfectly reliable.
        return Some(if ms_between == 0.0 && ms_within == 0.0 { 1.0 } else { 0.0 });
    }
    Some(((ms_between - ms_within) / denom).clamp(-1.0, 1.0))
}

/// Cohen's kappa on paired binary verdicts (agreement beyond chance).
pub fn cohens_kappa(n11: u32, n10: u32, n01: u32, n00: u32) -> Option<f64> {
    let n = (n11 + n10 + n01 + n00) as f64;
    if n == 0.0 {
        return None;
    }
    let po = (n11 + n00) as f64 / n;
    let p_yes = ((n11 + n10) as f64 / n) * ((n11 + n01) as f64 / n);
    let p_no = ((n01 + n00) as f64 / n) * ((n10 + n00) as f64 / n);
    let pe = p_yes + p_no;
    if (1.0 - pe).abs() < 1e-12 {
        return Some(if po >= 1.0 { 1.0 } else { 0.0 });
    }
    Some((po - pe) / (1.0 - pe))
}

/// Wilson score interval for a proportion — used wherever Harpia reports a
/// rate over a small denominator (mutation score, false-pass rate, infra
/// failure rate), which is exactly where the normal approximation lies.
pub fn wilson_ci(successes: u64, n: u64, alpha: f64) -> Option<(f64, f64)> {
    if n == 0 {
        return None;
    }
    let z = normal_quantile(1.0 - alpha / 2.0);
    let nf = n as f64;
    let p = successes as f64 / nf;
    let denom = 1.0 + z * z / nf;
    let centre = p + z * z / (2.0 * nf);
    let half = z * ((p * (1.0 - p) + z * z / (4.0 * nf)) / nf).sqrt();
    Some((
        ((centre - half) / denom).clamp(0.0, 1.0),
        ((centre + half) / denom).clamp(0.0, 1.0),
    ))
}

/// Variance decomposition of a rows-by-columns matrix with one observation
/// per cell (harnesses x tasks). Negative component estimates clamp to zero,
/// as is conventional.
#[derive(Debug, Clone, Copy, PartialEq, serde::Serialize)]
pub struct VarianceComponents {
    pub rows: f64,
    pub cols: f64,
    pub residual: f64,
    pub total: f64,
}

impl VarianceComponents {
    pub fn row_share(&self) -> f64 {
        if self.total > 0.0 { self.rows / self.total } else { 0.0 }
    }
    pub fn col_share(&self) -> f64 {
        if self.total > 0.0 { self.cols / self.total } else { 0.0 }
    }
    pub fn residual_share(&self) -> f64 {
        if self.total > 0.0 { self.residual / self.total } else { 0.0 }
    }
}

pub fn variance_components(matrix: &[Vec<f64>]) -> Option<VarianceComponents> {
    let a = matrix.len();
    if a < 2 {
        return None;
    }
    let b = matrix[0].len();
    if b < 2 || matrix.iter().any(|r| r.len() != b) {
        return None;
    }
    let (af, bf) = (a as f64, b as f64);
    let all: Vec<f64> = matrix.iter().flat_map(|r| r.iter().copied()).collect();
    let grand = mean(&all);
    let row_means: Vec<f64> = matrix.iter().map(|r| mean(r)).collect();
    let col_means: Vec<f64> = (0..b)
        .map(|j| mean(&matrix.iter().map(|r| r[j]).collect::<Vec<_>>()))
        .collect();
    let ss_rows: f64 = row_means.iter().map(|m| bf * (m - grand).powi(2)).sum();
    let ss_cols: f64 = col_means.iter().map(|m| af * (m - grand).powi(2)).sum();
    let mut ss_resid = 0.0;
    for (i, row) in matrix.iter().enumerate() {
        for (j, x) in row.iter().enumerate() {
            ss_resid += (x - row_means[i] - col_means[j] + grand).powi(2);
        }
    }
    let ms_rows = ss_rows / (af - 1.0);
    let ms_cols = ss_cols / (bf - 1.0);
    let ms_resid = ss_resid / ((af - 1.0) * (bf - 1.0));
    let rows = ((ms_rows - ms_resid) / bf).max(0.0);
    let cols = ((ms_cols - ms_resid) / af).max(0.0);
    let residual = ms_resid.max(0.0);
    Some(VarianceComponents { rows, cols, residual, total: rows + cols + residual })
}

#[cfg(test)]
mod meta_tests {
    use super::*;

    #[test]
    fn quantiles_and_spread() {
        let xs = [1.0, 2.0, 3.0, 4.0];
        assert_eq!(median(&xs), 2.5);
        assert_eq!(quantile(&xs, 0.0), 1.0);
        assert_eq!(quantile(&xs, 1.0), 4.0);
        assert!(sd(&[2.0, 2.0, 2.0]).abs() < 1e-12);
        assert!((sample_sd(&[1.0, 3.0]) - std::f64::consts::SQRT_2).abs() < 1e-6);
    }

    #[test]
    fn pearson_matches_hand_computation() {
        assert!((pearson(&[1.0, 2.0, 3.0], &[2.0, 4.0, 6.0]).unwrap() - 1.0).abs() < 1e-12);
        assert!((pearson(&[1.0, 2.0, 3.0], &[3.0, 2.0, 1.0]).unwrap() + 1.0).abs() < 1e-12);
        assert!(pearson(&[1.0, 1.0, 1.0], &[1.0, 2.0, 3.0]).is_none());
    }

    #[test]
    fn alpha_is_high_for_coherent_items_and_low_for_noise() {
        let coherent: Vec<Vec<f64>> = (0..4)
            .map(|s| (0..5).map(|j| s as f64 * 0.2 + j as f64 * 0.01).collect())
            .collect();
        let a = cronbach_alpha(&coherent).unwrap();
        assert!(a > 0.95, "coherent items scored alpha = {a}");

        // Items that disagree about who is good. Alpha goes negative, which
        // is the honest reading: the items are measuring different things.
        let noisy = vec![
            vec![1.0, 0.0, 1.0, 1.0],
            vec![0.0, 1.0, 0.0, 1.0],
            vec![1.0, 0.0, 0.0, 0.0],
            vec![0.0, 1.0, 1.0, 0.0],
        ];
        let a = cronbach_alpha(&noisy).unwrap();
        assert!(a < 0.0, "incoherent items scored alpha = {a}");

        // Every subject with the same total is undefined, not zero: there is
        // no between-subject variance to apportion.
        let flat = vec![vec![1.0, 0.0], vec![0.0, 1.0]];
        assert!(cronbach_alpha(&flat).is_none());
    }

    #[test]
    fn split_half_and_sem() {
        let m: Vec<Vec<f64>> = (0..6)
            .map(|s| (0..8).map(|j| (s as f64 * 0.15 + j as f64 * 0.02).min(1.0)).collect())
            .collect();
        let r = split_half_reliability(&m).unwrap();
        assert!(r > 0.9, "split-half = {r}");
        assert_eq!(sem(0.2, 1.0), 0.0);
        assert!((sem(0.2, 0.0) - 0.2).abs() < 1e-12);
    }

    #[test]
    fn normal_quantile_round_trips() {
        for p in [0.001, 0.01, 0.025, 0.1, 0.5, 0.8, 0.975, 0.999] {
            let z = normal_quantile(p);
            assert!((normal_cdf(z) - p).abs() < 1e-6, "p={p} z={z}");
        }
        assert!((normal_quantile(0.975) - 1.959964).abs() < 1e-4);
        assert!((normal_quantile(0.8) - 0.8416212).abs() < 1e-4);
    }

    #[test]
    fn mde_shrinks_with_n_and_matches_closed_form() {
        let a = mde_paired(0.3, 25, 0.05, 0.8).unwrap();
        let b = mde_paired(0.3, 100, 0.05, 0.8).unwrap();
        assert!(b < a);
        assert!((b - 0.0840475).abs() < 1e-4, "mde = {b}");
        assert!(mde_paired(0.0, 10, 0.05, 0.8).is_none());
    }

    #[test]
    fn power_rises_with_effect() {
        let small = power_paired(0.01, 0.3, 100, 0.05).unwrap();
        let large = power_paired(0.20, 0.3, 100, 0.05).unwrap();
        assert!(small < 0.1, "power for a tiny effect = {small}");
        assert!(large > 0.99, "power for a large effect = {large}");
    }

    #[test]
    fn kendall_tau_extremes() {
        let a = [1.0, 2.0, 3.0, 4.0];
        let same = [0.1, 0.2, 0.3, 0.4];
        let rev = [4.0, 3.0, 2.0, 1.0];
        assert!((kendall_tau_b(&a, &same).unwrap() - 1.0).abs() < 1e-12);
        assert!((kendall_tau_b(&a, &rev).unwrap() + 1.0).abs() < 1e-12);
        let swap = [2.0, 1.0, 3.0, 4.0];
        assert!((kendall_tau_b(&a, &swap).unwrap() - 4.0 / 6.0).abs() < 1e-12);
    }

    #[test]
    fn icc_separates_reliable_from_flaky_repeats() {
        let reliable = vec![vec![0.9, 0.9, 0.9], vec![0.1, 0.1, 0.1], vec![0.5, 0.5, 0.5]];
        assert!(icc_1_1(&reliable).unwrap() > 0.99);
        let flaky = vec![vec![1.0, 0.0, 1.0], vec![0.0, 1.0, 0.0], vec![1.0, 0.0, 1.0]];
        let icc = icc_1_1(&flaky).unwrap();
        assert!(icc < 0.2, "coin-flip repeats scored ICC = {icc}");
    }

    #[test]
    fn kappa_discounts_chance_agreement() {
        assert!((cohens_kappa(10, 0, 0, 10).unwrap() - 1.0).abs() < 1e-12);
        let k = cohens_kappa(5, 5, 5, 5).unwrap();
        assert!(k.abs() < 1e-12, "chance-level agreement gave kappa = {k}");
    }

    #[test]
    fn wilson_is_asymmetric_at_the_edges() {
        let (lo, hi) = wilson_ci(0, 20, 0.05).unwrap();
        assert_eq!(lo, 0.0);
        assert!(hi > 0.1 && hi < 0.2, "0/20 upper bound = {hi}");
        let (lo, hi) = wilson_ci(10, 20, 0.05).unwrap();
        assert!(lo < 0.5 && hi > 0.5);
    }

    #[test]
    fn variance_components_find_the_dominant_factor() {
        let harness_driven = vec![
            vec![0.9, 0.88, 0.92, 0.9],
            vec![0.3, 0.28, 0.32, 0.3],
            vec![0.6, 0.58, 0.62, 0.6],
        ];
        let v = variance_components(&harness_driven).unwrap();
        assert!(v.row_share() > 0.9, "row share = {}", v.row_share());

        let task_driven = vec![
            vec![0.95, 0.1, 0.5, 0.2],
            vec![0.93, 0.12, 0.52, 0.18],
            vec![0.97, 0.09, 0.48, 0.22],
        ];
        let v = variance_components(&task_driven).unwrap();
        assert!(v.col_share() > 0.9, "col share = {}", v.col_share());
    }
}
