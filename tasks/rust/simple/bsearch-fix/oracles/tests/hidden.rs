use bsearch::{contains, lower_bound, upper_bound};

#[test]
fn lower_bound_first_matching_position() {
    let s = [1, 2, 2, 2, 3];
    assert_eq!(lower_bound(&s, 2), 1);
    assert_eq!(lower_bound(&s, 1), 0);
    assert_eq!(lower_bound(&s, 3), 4);
}

#[test]
fn lower_bound_absent_values() {
    let s = [10, 20, 30];
    assert_eq!(lower_bound(&s, 5), 0);
    assert_eq!(lower_bound(&s, 15), 1);
    assert_eq!(lower_bound(&s, 35), 3);
}

#[test]
fn upper_bound_first_greater_position() {
    let s = [1, 2, 2, 2, 3];
    assert_eq!(upper_bound(&s, 2), 4);
    assert_eq!(upper_bound(&s, 0), 0);
    assert_eq!(upper_bound(&s, 3), 5);
}

#[test]
fn contains_finds_present_values() {
    let s = [2, 4, 6, 8];
    for v in s {
        assert!(contains(&s, v), "missing {v}");
    }
    assert!(!contains(&s, 5));
    assert!(!contains(&s, 1));
    assert!(!contains(&s, 9));
}

#[test]
fn empty_slice_is_safe() {
    assert_eq!(lower_bound(&[], 1), 0);
    assert_eq!(upper_bound(&[], 1), 0);
    assert!(!contains(&[], 1));
}
