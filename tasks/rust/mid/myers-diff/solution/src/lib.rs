//! Minimal line-based diff scripts (LCS dynamic program; O(nm) suffices for
//! the few-hundred-line inputs this crate serves).

/// One entry of an edit script over lines.
#[derive(Debug, PartialEq, Eq, Clone)]
pub enum Edit {
    /// Line present in both inputs.
    Equal(String),
    /// Line only in the left input.
    Delete(String),
    /// Line only in the right input.
    Insert(String),
}

fn lcs_table(a: &[&str], b: &[&str]) -> Vec<Vec<usize>> {
    let mut dp = vec![vec![0usize; b.len() + 1]; a.len() + 1];
    for i in (0..a.len()).rev() {
        for j in (0..b.len()).rev() {
            dp[i][j] = if a[i] == b[j] {
                dp[i + 1][j + 1] + 1
            } else {
                dp[i + 1][j].max(dp[i][j + 1])
            };
        }
    }
    dp
}

/// A minimal edit script turning the lines of `a` into the lines of `b`.
pub fn diff_lines(a: &str, b: &str) -> Vec<Edit> {
    let al: Vec<&str> = a.lines().collect();
    let bl: Vec<&str> = b.lines().collect();
    let dp = lcs_table(&al, &bl);
    let mut out = Vec::new();
    let (mut i, mut j) = (0usize, 0usize);
    while i < al.len() && j < bl.len() {
        if al[i] == bl[j] {
            out.push(Edit::Equal(al[i].to_string()));
            i += 1;
            j += 1;
        } else if dp[i + 1][j] >= dp[i][j + 1] {
            out.push(Edit::Delete(al[i].to_string()));
            i += 1;
        } else {
            out.push(Edit::Insert(bl[j].to_string()));
            j += 1;
        }
    }
    while i < al.len() {
        out.push(Edit::Delete(al[i].to_string()));
        i += 1;
    }
    while j < bl.len() {
        out.push(Edit::Insert(bl[j].to_string()));
        j += 1;
    }
    out
}

/// Number of Delete + Insert entries in a minimal script for (a, b).
pub fn edit_distance(a: &str, b: &str) -> usize {
    let al: Vec<&str> = a.lines().collect();
    let bl: Vec<&str> = b.lines().collect();
    let lcs = lcs_table(&al, &bl)[0][0];
    al.len() + bl.len() - 2 * lcs
}
