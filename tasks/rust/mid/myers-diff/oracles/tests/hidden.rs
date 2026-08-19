use myers_diff::{diff_lines, edit_distance, Edit};

/// Independent LCS length for computing the expected minimal edit count.
fn lcs_len(a: &[&str], b: &[&str]) -> usize {
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
    dp[0][0]
}

/// Assert the script is valid for (a, b) and minimal; return its D+I count.
fn check_script(a: &str, b: &str) -> usize {
    let script = diff_lines(a, b);
    let mut left = Vec::new();
    let mut right = Vec::new();
    let mut ops = 0usize;
    for edit in &script {
        match edit {
            Edit::Equal(l) => {
                left.push(l.as_str());
                right.push(l.as_str());
            }
            Edit::Delete(l) => {
                left.push(l.as_str());
                ops += 1;
            }
            Edit::Insert(l) => {
                right.push(l.as_str());
                ops += 1;
            }
        }
    }
    let al: Vec<&str> = a.lines().collect();
    let bl: Vec<&str> = b.lines().collect();
    assert_eq!(left, al, "left projection mismatch for {a:?} -> {b:?}");
    assert_eq!(right, bl, "right projection mismatch for {a:?} -> {b:?}");
    let minimal = al.len() + bl.len() - 2 * lcs_len(&al, &bl);
    assert_eq!(ops, minimal, "script not minimal for {a:?} -> {b:?}");
    assert_eq!(edit_distance(a, b), minimal, "edit_distance disagrees");
    ops
}

#[test]
fn identical_inputs_are_all_equal() {
    let src = "alpha\nbeta\ngamma\n";
    let script = diff_lines(src, src);
    assert!(script.iter().all(|e| matches!(e, Edit::Equal(_))));
    assert_eq!(script.len(), 3);
    assert_eq!(edit_distance(src, src), 0);
}

#[test]
fn empty_to_empty_is_empty_script() {
    assert!(diff_lines("", "").is_empty());
    assert_eq!(edit_distance("", ""), 0);
}

#[test]
fn pure_insertions_and_deletions() {
    assert_eq!(check_script("", "a\nb\nc\n"), 3);
    assert_eq!(check_script("a\nb\nc\n", ""), 3);
    let script = diff_lines("", "x\ny\n");
    assert_eq!(
        script,
        vec![Edit::Insert("x".to_string()), Edit::Insert("y".to_string())]
    );
}

#[test]
fn single_line_change() {
    assert_eq!(check_script("a\nb\nc\n", "a\nX\nc\n"), 2);
}

#[test]
fn myers_paper_example() {
    let a = "a\nb\nc\na\nb\nb\na\n";
    let b = "c\nb\na\nb\na\nc\n";
    assert_eq!(check_script(a, b), 5);
}

#[test]
fn disjoint_inputs() {
    let a = "one\ntwo\n";
    let b = "three\nfour\nfive\n";
    assert_eq!(check_script(a, b), 5);
}

#[test]
fn interleaved_common_lines() {
    check_script(
        "keep1\nold1\nkeep2\nold2\nkeep3\n",
        "new1\nkeep1\nkeep2\nnew2\nkeep3\nnew3\n",
    );
}
