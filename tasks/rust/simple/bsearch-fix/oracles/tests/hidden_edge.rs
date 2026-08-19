use bsearch::{contains, equal_range, lower_bound};

#[test]
fn equal_range_on_duplicates() {
    let s = [1, 2, 2, 2, 3];
    assert_eq!(equal_range(&s, 2), (1, 4));
    assert_eq!(equal_range(&s, 1), (0, 1));
    assert_eq!(equal_range(&s, 3), (4, 5));
}

#[test]
fn equal_range_absent_is_empty_insertion_point() {
    let s = [10, 20, 20, 30];
    assert_eq!(equal_range(&s, 15), (1, 1));
    assert_eq!(equal_range(&s, 0), (0, 0));
    assert_eq!(equal_range(&s, 99), (4, 4));
}

#[test]
fn singleton_slices() {
    assert_eq!(equal_range(&[7], 7), (0, 1));
    assert!(contains(&[7], 7));
    assert!(!contains(&[7], 8));
}

#[test]
fn extreme_values() {
    let s = [i64::MIN, 0, i64::MAX];
    assert!(contains(&s, i64::MIN));
    assert!(contains(&s, i64::MAX));
    assert_eq!(lower_bound(&s, i64::MIN), 0);
    assert_eq!(equal_range(&s, i64::MAX), (2, 3));
}

#[test]
fn every_element_of_a_long_run_is_found() {
    let s: Vec<i64> = (0..1000).map(|i| i * 2).collect();
    for (idx, v) in s.iter().enumerate() {
        assert!(contains(&s, *v), "missing {v}");
        assert_eq!(lower_bound(&s, *v), idx);
    }
    for v in (1..1999).step_by(2) {
        assert!(!contains(&s, v), "phantom {v}");
    }
}
