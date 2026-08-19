use csv_sums::{column_sums, CsvError};

fn close(a: f64, b: f64) -> bool {
    (a - b).abs() < 1e-9
}

#[test]
fn crlf_input_works() {
    let out = column_sums("a,b\r\n1,2\r\n3,4\r\n").unwrap();
    assert!(close(out[0].1.unwrap(), 4.0));
    assert!(close(out[1].1.unwrap(), 6.0));
}

#[test]
fn blank_lines_are_skipped_but_counted() {
    let out = column_sums("\na,b\n\n1,2\n   \n3,4\n").unwrap();
    assert!(close(out[0].1.unwrap(), 4.0));
    // The ragged row is physical line 6.
    assert_eq!(
        column_sums("\na,b\n\n1,2\n   \n3,4,5\n"),
        Err(CsvError::Ragged { line: 6 })
    );
}

#[test]
fn header_only_sums_to_zero() {
    let out = column_sums("alpha,beta\n").unwrap();
    assert_eq!(out[0].0, "alpha");
    assert!(close(out[0].1.unwrap(), 0.0));
    assert!(close(out[1].1.unwrap(), 0.0));
}

#[test]
fn cells_are_trimmed_before_parsing() {
    let out = column_sums("n\n 3 \n\t4\n").unwrap();
    assert!(close(out[0].1.unwrap(), 7.0));
}

#[test]
fn empty_cell_poisons_its_column() {
    let out = column_sums("a,b\n1,\n2,3\n").unwrap();
    assert!(close(out[0].1.unwrap(), 3.0));
    assert_eq!(out[1].1, None);
}

#[test]
fn single_column_input() {
    let out = column_sums("only\n5\n7\n").unwrap();
    assert_eq!(out.len(), 1);
    assert!(close(out[0].1.unwrap(), 12.0));
}
