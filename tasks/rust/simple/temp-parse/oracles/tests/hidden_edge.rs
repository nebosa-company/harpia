use temp_parse::{format_celsius, parse_temp, TempError};

fn close(a: f64, b: f64) -> bool {
    (a - b).abs() < 1e-9
}

#[test]
fn units_are_case_insensitive() {
    assert!(close(parse_temp("100c").unwrap(), 100.0));
    assert!(close(parse_temp("212f").unwrap(), 100.0));
    assert!(close(parse_temp("273.15k").unwrap(), 0.0));
}

#[test]
fn whitespace_tolerance() {
    assert!(close(parse_temp("  -40F  ").unwrap(), -40.0));
    assert!(close(parse_temp("23.5 C").unwrap(), 23.5));
    assert!(close(parse_temp("300 \t K").unwrap(), 26.85));
}

#[test]
fn scientific_notation_numbers() {
    assert!(close(parse_temp("1e2C").unwrap(), 100.0));
    assert!(close(parse_temp("2.5e1C").unwrap(), 25.0));
}

#[test]
fn absolute_zero_boundary_is_inclusive() {
    assert!(close(parse_temp("0K").unwrap(), -273.15));
    assert!(close(parse_temp("-273.15C").unwrap(), -273.15));
    assert!(close(parse_temp("-459.67F").unwrap(), -273.15));
    assert_eq!(parse_temp("-0.5K"), Err(TempError::BelowAbsoluteZero));
}

#[test]
fn formatting() {
    assert_eq!(format_celsius(0.0), "0.0°C");
    assert_eq!(format_celsius(-40.0), "-40.0°C");
    assert_eq!(format_celsius(100.0), "100.0°C");
    assert_eq!(format_celsius(36.6), "36.6°C");
}
