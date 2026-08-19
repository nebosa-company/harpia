//! A small, strictly typed expression language: assignments plus a final
//! expression, over i64 and bool values.

/// A runtime value.
#[derive(Debug, PartialEq, Clone)]
pub enum Value {
    Int(i64),
    Bool(bool),
}

/// Everything evaluation can report.
#[derive(Debug, PartialEq)]
pub enum EvalError {
    /// Syntax problem (message is informational only).
    Parse(String),
    /// Use of a variable that was never assigned.
    UndefinedVar(String),
    /// Operator applied to operands of the wrong type (message informational).
    TypeMismatch(String),
    /// Integer division or remainder by zero.
    DivisionByZero,
}

/// Evaluate a program: `{ ident "=" expr ";" } expr [";"]`.
pub fn eval_program(src: &str) -> Result<Value, EvalError> {
    let _ = src;
    todo!("tokenize, parse, and evaluate the program")
}
