use csv_sums::{column_sums, CsvError};

fn close(a: f64, b: f64) -> bool {
    (a - b).abs() < 1e-9
}

#[test]
fn sums_numeric_columns() {
    let out = column_sums("a,b\n1,2\n3,4\n").unwrap();
    assert_eq!(out.len(), 2);
    assert_eq!(out[0].0, "a");
    assert!(close(out[0].1.unwrap(), 4.0));
    assert_eq!(out[1].0, "b");
    assert!(close(out[1].1.unwrap(), 6.0));
}

#[test]
fn non_numeric_column_is_none() {
    let out = column_sums("name,qty\nbolt,4\nnut,6\n").unwrap();
    assert_eq!(out[0], ("name".to_string(), None));
    assert!(close(out[1].1.unwrap(), 10.0));
}

#[test]
fn floats_negatives_and_exponents() {
    let out = column_sums("x\n1.5\n-0.5\n1e1\n").unwrap();
    assert!(close(out[0].1.unwrap(), 11.0));
}

#[test]
fn header_names_are_trimmed() {
    let out = column_sums(" a , b \n1,2\n").unwrap();
    assert_eq!(out[0].0, "a");
    assert_eq!(out[1].0, "b");
}

#[test]
fn empty_input_errors() {
    assert_eq!(column_sums(""), Err(CsvError::Empty));
    assert_eq!(column_sums("\n  \n\n"), Err(CsvError::Empty));
}

#[test]
fn ragged_row_errors_with_line_number() {
    assert_eq!(
        column_sums("a,b\n1,2\n1,2,3\n"),
        Err(CsvError::Ragged { line: 3 })
    );
    assert_eq!(column_sums("a,b\n1\n"), Err(CsvError::Ragged { line: 2 }));
}
