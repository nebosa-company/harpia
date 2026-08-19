//! Per-column totals over bare (unquoted) CSV text.

/// How CSV summarization can fail.
#[derive(Debug, PartialEq)]
pub enum CsvError {
    /// No header line present.
    Empty,
    /// A data row's field count differs from the header's (1-based line).
    Ragged { line: usize },
}

/// Sum every column of `csv`. Returns one `(column name, sum)` pair per
/// header column; a column whose every data cell parses as f64 gets
/// `Some(total)`, any other column gets `None`.
pub fn column_sums(csv: &str) -> Result<Vec<(String, Option<f64>)>, CsvError> {
    let _ = csv;
    todo!("sum the numeric columns")
}
