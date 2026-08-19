use myers_diff::{diff_lines, edit_distance, Edit};

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
    assert_eq!(left, al, "left projection mismatch");
    assert_eq!(right, bl, "right projection mismatch");
    let minimal = al.len() + bl.len() - 2 * lcs_len(&al, &bl);
    assert_eq!(ops, minimal, "script not minimal for {a:?} -> {b:?}");
    assert_eq!(edit_distance(a, b), minimal);
    ops
}

#[test]
fn repeated_lines_stay_minimal() {
    assert_eq!(check_script("x\nx\nx\nx\n", "x\nx\n"), 2);
    check_script("a\nb\na\nb\na\n", "b\na\nb\na\nb\n");
}

#[test]
fn crlf_lines_equal_lf_lines() {
    // str::lines() strips '\r', so these are identical line-wise.
    let script = diff_lines("x\r\ny\r\n", "x\ny\n");
    assert!(script.iter().all(|e| matches!(e, Edit::Equal(_))), "{script:?}");
    assert_eq!(edit_distance("x\r\ny", "x\ny"), 0);
}

#[test]
fn trailing_newline_is_immaterial() {
    assert_eq!(edit_distance("a\nb\n", "a\nb"), 0);
}

#[test]
fn large_input_with_small_change_is_fast_and_minimal() {
    let a: String = (0..300).map(|i| format!("line-{i}\n")).collect();
    let mut lines: Vec<String> = (0..300).map(|i| format!("line-{i}")).collect();
    lines[40] = "edited-40".to_string();
    lines.remove(200);
    lines.insert(250, "brand-new".to_string());
    let b = lines.join("\n") + "\n";
    // one replace (2 ops) + one delete + one insert = 4
    assert_eq!(check_script(&a, &b), 4);
}

#[test]
fn completely_alternating_case() {
    let a = "a1\nc\na2\nc\na3\n";
    let b = "b1\nc\nb2\nc\nb3\n";
    assert_eq!(check_script(a, b), 6);
}

#[test]
fn one_sided_empty_lines() {
    check_script("\n\n\n", "\n");
    assert_eq!(edit_distance("\n\n\n", "\n"), 2);
}
