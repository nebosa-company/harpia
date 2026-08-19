use temp_parse::{parse_temp, TempError};

fn close(a: f64, b: f64) -> bool {
    (a - b).abs() < 1e-9
}

#[test]
fn celsius_passes_through() {
    assert!(close(parse_temp("0C").unwrap(), 0.0));
    assert!(close(parse_temp("23.5C").unwrap(), 23.5));
    assert!(close(parse_temp("-40C").unwrap(), -40.0));
}

#[test]
fn fahrenheit_converts() {
    assert!(close(parse_temp("32F").unwrap(), 0.0));
    assert!(close(parse_temp("212F").unwrap(), 100.0));
    assert!(close(parse_temp("-40F").unwrap(), -40.0));
}

#[test]
fn kelvin_converts() {
    assert!(close(parse_temp("273.15K").unwrap(), 0.0));
    assert!(close(parse_temp("300K").unwrap(), 26.85));
}

#[test]
fn empty_inputs() {
    assert_eq!(parse_temp(""), Err(TempError::Empty));
    assert_eq!(parse_temp("   "), Err(TempError::Empty));
}

#[test]
fn unknown_units() {
    assert_eq!(parse_temp("12X"), Err(TempError::UnknownUnit('X')));
    assert_eq!(parse_temp("42"), Err(TempError::UnknownUnit('2')));
}

#[test]
fn bad_numbers() {
    assert_eq!(parse_temp("abcC"), Err(TempError::BadNumber("abc".to_string())));
    assert_eq!(parse_temp("C"), Err(TempError::BadNumber(String::new())));
    assert_eq!(parse_temp("1.2.3K"), Err(TempError::BadNumber("1.2.3".to_string())));
}

#[test]
fn below_absolute_zero() {
    assert_eq!(parse_temp("-300C"), Err(TempError::BelowAbsoluteZero));
    assert_eq!(parse_temp("-1K"), Err(TempError::BelowAbsoluteZero));
    assert_eq!(parse_temp("-500F"), Err(TempError::BelowAbsoluteZero));
}
