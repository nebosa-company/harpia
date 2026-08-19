use expr_lang::{eval_program, EvalError, Value};

fn int(src: &str) -> i64 {
    match eval_program(src) {
        Ok(Value::Int(v)) => v,
        other => panic!("{src:?} -> {other:?}, expected Int"),
    }
}

fn boolean(src: &str) -> bool {
    match eval_program(src) {
        Ok(Value::Bool(b)) => b,
        other => panic!("{src:?} -> {other:?}, expected Bool"),
    }
}

#[test]
fn arithmetic_precedence() {
    assert_eq!(int("2 + 3 * 4"), 14);
    assert_eq!(int("(2 + 3) * 4"), 20);
    assert_eq!(int("2 * 3 + 4 * 5"), 26);
    assert_eq!(int("100 / 10 / 5"), 2, "division is left-associative");
    assert_eq!(int("10 - 3 - 2"), 5, "subtraction is left-associative");
    assert_eq!(int("7 % 3"), 1);
    assert_eq!(int("2 + 3 % 3"), 2);
}

#[test]
fn division_truncates_toward_zero() {
    assert_eq!(int("7 / 2"), 3);
    assert_eq!(int("-7 / 2"), -3);
    assert_eq!(int("7 / -2"), -3);
    assert_eq!(int("-7 % 3"), -1);
}

#[test]
fn unary_operators_nest() {
    assert_eq!(int("-5"), -5);
    assert_eq!(int("- -5"), 5);
    assert_eq!(int("--5"), 5);
    assert_eq!(int("-2 * 3"), -6);
    assert_eq!(int("2 - -3"), 5);
    assert!(boolean("!false"));
    assert!(boolean("!!true"));
    assert!(!boolean("!(1 < 2)"));
}

#[test]
fn comparisons_and_equality() {
    assert!(boolean("1 < 2"));
    assert!(boolean("2 <= 2"));
    assert!(!boolean("3 > 4"));
    assert!(boolean("4 >= 4"));
    assert!(boolean("1 == 1"));
    assert!(boolean("1 != 2"));
    assert!(boolean("true == true"));
    assert!(boolean("true != false"));
    assert!(boolean("1 + 2 == 3"), "additive binds tighter than equality");
    assert!(boolean("1 < 2 == 2 < 3"), "comparison binds tighter than equality");
}

#[test]
fn boolean_operators_and_precedence() {
    assert!(!boolean("true && false"));
    assert!(boolean("true || false"));
    assert!(boolean("true || false && false"), "&& binds tighter than ||");
    assert!(!boolean("(true || false) && false"));
}

#[test]
fn short_circuit_suppresses_runtime_errors() {
    assert!(!boolean("false && 1 / 0 == 0"));
    assert!(boolean("true || 1 / 0 == 0"));
    assert!(!boolean("x = 0; false && 10 / x > 1"));
    // ... but a taken branch still errors
    assert_eq!(eval_program("true && 1 / 0 == 0"), Err(EvalError::DivisionByZero));
}

#[test]
fn variables_and_sequencing() {
    assert_eq!(int("x = 2; y = x * 3; x + y"), 8);
    assert_eq!(int("x = 1; x = x + 1; x = x * 10; x"), 20);
    assert_eq!(int("a = 5; b = a; a = 1; b"), 5, "assignment copies the value");
    assert!(boolean("flag = 1 < 2; flag && true"));
}

#[test]
fn final_expression_forms() {
    assert_eq!(int("42"), 42);
    assert_eq!(int("42;"), 42, "optional trailing semicolon");
    assert_eq!(int("x = 7; x;"), 7);
    assert_eq!(eval_program("true"), Ok(Value::Bool(true)));
}

#[test]
fn whitespace_and_newlines() {
    assert_eq!(int("x = 1;\n\ny = 2;\r\n\tx + y"), 3);
    assert_eq!(int("  1+2*3  "), 7);
}
