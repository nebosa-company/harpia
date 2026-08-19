//! Per-column totals over bare (unquoted) CSV text.

/// How CSV summarization can fail.
#[derive(Debug, PartialEq)]
pub enum CsvError {
    /// No header line present.
    Empty,
    /// A data row's field count differs from the header's (1-based line).
    Ragged { line: usize },
}

/// Sum every column of `csv`.
pub fn column_sums(csv: &str) -> Result<Vec<(String, Option<f64>)>, CsvError> {
    let mut rows = csv
        .split('\n')
        .map(|l| l.strip_suffix('\r').unwrap_or(l))
        .enumerate()
        .filter(|(_, l)| !l.trim().is_empty());

    let Some((_, header)) = rows.next() else {
        return Err(CsvError::Empty);
    };
    let names: Vec<String> = header.split(',').map(|f| f.trim().to_string()).collect();
    let mut sums: Vec<Option<f64>> = vec![Some(0.0); names.len()];

    for (idx, row) in rows {
        let cells: Vec<&str> = row.split(',').map(|f| f.trim()).collect();
        if cells.len() != names.len() {
            return Err(CsvError::Ragged { line: idx + 1 });
        }
        for (col, cell) in cells.iter().enumerate() {
            if let Some(total) = sums[col] {
                sums[col] = cell.parse::<f64>().ok().map(|v| total + v);
            }
        }
    }
    Ok(names.into_iter().zip(sums).collect())
}
