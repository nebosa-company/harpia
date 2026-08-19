//! Temperature-string parsing: normalize "<number><unit>" inputs to Celsius.

/// Why a temperature string failed to parse.
#[derive(Debug, PartialEq, Clone)]
pub enum TempError {
    /// Input was empty or whitespace-only.
    Empty,
    /// The number part did not parse as an f64 (payload: the trimmed number part).
    BadNumber(String),
    /// The final character was not a recognized unit (payload: that character).
    UnknownUnit(char),
    /// The converted value sits below absolute zero.
    BelowAbsoluteZero,
}

/// Parse a temperature such as "23.5C", "-40 F" or "300k" into Celsius.
pub fn parse_temp(input: &str) -> Result<f64, TempError> {
    let _ = input;
    todo!("parse the temperature string")
}

/// Format a Celsius value with one decimal place, e.g. "-40.0°C".
pub fn format_celsius(c: f64) -> String {
    let _ = c;
    todo!("format the temperature")
}
