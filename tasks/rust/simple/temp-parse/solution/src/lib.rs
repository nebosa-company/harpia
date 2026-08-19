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
    let trimmed = input.trim();
    let Some(unit) = trimmed.chars().last() else {
        return Err(TempError::Empty);
    };
    let number_part = trimmed[..trimmed.len() - unit.len_utf8()].trim();
    let convert: fn(f64) -> f64 = match unit {
        'C' | 'c' => |v| v,
        'F' | 'f' => |v| (v - 32.0) * 5.0 / 9.0,
        'K' | 'k' => |v| v - 273.15,
        other => return Err(TempError::UnknownUnit(other)),
    };
    let value: f64 = number_part
        .parse()
        .map_err(|_| TempError::BadNumber(number_part.to_string()))?;
    let celsius = convert(value);
    if celsius < -273.15 - 1e-9 {
        return Err(TempError::BelowAbsoluteZero);
    }
    Ok(celsius)
}

/// Format a Celsius value with one decimal place, e.g. "-40.0°C".
pub fn format_celsius(c: f64) -> String {
    format!("{c:.1}°C")
}
