use expr_lang::{eval_program, EvalError, Value};

#[test]
fn division_and_remainder_by_zero() {
    assert_eq!(eval_program("1 / 0"), Err(EvalError::DivisionByZero));
    assert_eq!(eval_program("5 % 0"), Err(EvalError::DivisionByZero));
    assert_eq!(eval_program("x = 0; 10 / x"), Err(EvalError::DivisionByZero));
    assert_eq!(eval_program("y = 1 / 0; 1"), Err(EvalError::DivisionByZero));
}

#[test]
fn undefined_variables_carry_the_name() {
    assert_eq!(eval_program("nope"), Err(EvalError::UndefinedVar("nope".to_string())));
    assert_eq!(
        eval_program("x = 1; x + ghost_2"),
        Err(EvalError::UndefinedVar("ghost_2".to_string()))
    );
    assert_eq!(
        eval_program("x = y; 1"),
        Err(EvalError::UndefinedVar("y".to_string()))
    );
}

#[test]
fn type_mismatches() {
    for src in [
        "1 + true",
        "true - false",
        "true < false",
        "1 == true",
        "false != 3",
        "1 && true",
        "false || 0",
        "true && 3",
        "!3",
        "-true",
        "x = true; x * 2",
    ] {
        match eval_program(src) {
            Err(EvalError::TypeMismatch(_)) => {}
            other => panic!("{src:?} -> {other:?}, expected TypeMismatch"),
        }
    }
}

#[test]
fn parse_errors() {
    for src in [
        "",
        "   ",
        "1 +",
        "* 3",
        "(1",
        "1)",
        "1 2",
        "x = ;",
        "x = 1 y = 2; x",
        "x = 1; ",
        ";",
        "1 @ 2",
        "9223372036854775808",
        "x == 1; x",
        "true = 1; 2",
    ] {
        match eval_program(src) {
            Err(EvalError::Parse(_)) => {}
            other => panic!("{src:?} -> {other:?}, expected Parse"),
        }
    }
}

#[test]
fn wrapping_arithmetic() {
    assert_eq!(
        eval_program("9223372036854775807 + 1"),
        Ok(Value::Int(i64::MIN))
    );
    assert_eq!(
        eval_program("0 - 9223372036854775807 - 1"),
        Ok(Value::Int(i64::MIN))
    );
    assert_eq!(
        eval_program("x = 9223372036854775807; x * 2"),
        Ok(Value::Int(-2))
    );
}

#[test]
fn identifier_shapes() {
    assert_eq!(eval_program("_x = 1; _x"), Ok(Value::Int(1)));
    assert_eq!(eval_program("snake_case_9 = 4; snake_case_9 * 2"), Ok(Value::Int(8)));
    assert_eq!(eval_program("truely = 1; truely"), Ok(Value::Int(1)),
        "identifiers may merely start with a keyword");
}

#[test]
fn min_int_edge() {
    // 9223372036854775808 alone overflows, but the negation path works via wrapping.
    assert_eq!(eval_program("-9223372036854775807 - 1"), Ok(Value::Int(i64::MIN)));
    assert_eq!(eval_program("x = -9223372036854775807 - 1; -x"), Ok(Value::Int(i64::MIN)));
}

#[test]
fn complex_program() {
    let src = "
        base = 100;
        rate = 15;
        total = base + base * rate / 100;
        high = total > 110;
        cap = 120;
        high && total <= cap
    ";
    assert_eq!(eval_program(src), Ok(Value::Bool(true)));
}
