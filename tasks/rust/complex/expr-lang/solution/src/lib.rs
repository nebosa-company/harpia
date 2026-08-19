//! A small, strictly typed expression language: assignments plus a final
//! expression, over i64 and bool values.

use std::collections::HashMap;

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

#[derive(Debug, PartialEq, Clone)]
enum Tok {
    Int(i64),
    Ident(String),
    True,
    False,
    Sym(&'static str),
}

fn lex(src: &str) -> Result<Vec<Tok>, EvalError> {
    let chars: Vec<char> = src.chars().collect();
    let mut toks = Vec::new();
    let mut i = 0usize;
    while i < chars.len() {
        let c = chars[i];
        if c.is_whitespace() {
            i += 1;
        } else if c.is_ascii_digit() {
            let start = i;
            while i < chars.len() && chars[i].is_ascii_digit() {
                i += 1;
            }
            let text: String = chars[start..i].iter().collect();
            let value: i64 = text
                .parse()
                .map_err(|_| EvalError::Parse(format!("integer literal `{text}` overflows i64")))?;
            toks.push(Tok::Int(value));
        } else if c.is_ascii_alphabetic() || c == '_' {
            let start = i;
            while i < chars.len() && (chars[i].is_ascii_alphanumeric() || chars[i] == '_') {
                i += 1;
            }
            let word: String = chars[start..i].iter().collect();
            toks.push(match word.as_str() {
                "true" => Tok::True,
                "false" => Tok::False,
                _ => Tok::Ident(word),
            });
        } else {
            let two: String = chars[i..chars.len().min(i + 2)].iter().collect();
            let sym = match two.as_str() {
                "||" | "&&" | "==" | "!=" | "<=" | ">=" => {
                    i += 2;
                    match two.as_str() {
                        "||" => "||",
                        "&&" => "&&",
                        "==" => "==",
                        "!=" => "!=",
                        "<=" => "<=",
                        _ => ">=",
                    }
                }
                _ => {
                    let one = match c {
                        '<' => "<",
                        '>' => ">",
                        '+' => "+",
                        '-' => "-",
                        '*' => "*",
                        '/' => "/",
                        '%' => "%",
                        '(' => "(",
                        ')' => ")",
                        ';' => ";",
                        '=' => "=",
                        '!' => "!",
                        other => {
                            return Err(EvalError::Parse(format!("unexpected character `{other}`")))
                        }
                    };
                    i += 1;
                    one
                }
            };
            toks.push(Tok::Sym(sym));
        }
    }
    Ok(toks)
}

#[derive(Debug, Clone)]
enum Expr {
    Int(i64),
    Bool(bool),
    Var(String),
    Neg(Box<Expr>),
    Not(Box<Expr>),
    Bin(&'static str, Box<Expr>, Box<Expr>),
}

struct Parser {
    toks: Vec<Tok>,
    pos: usize,
}

impl Parser {
    fn peek(&self) -> Option<&Tok> {
        self.toks.get(self.pos)
    }

    fn peek2(&self) -> Option<&Tok> {
        self.toks.get(self.pos + 1)
    }

    fn bump(&mut self) -> Option<Tok> {
        let t = self.toks.get(self.pos).cloned();
        if t.is_some() {
            self.pos += 1;
        }
        t
    }

    fn eat_sym(&mut self, sym: &str) -> bool {
        if matches!(self.peek(), Some(Tok::Sym(s)) if *s == sym) {
            self.pos += 1;
            true
        } else {
            false
        }
    }

    fn expect_sym(&mut self, sym: &str) -> Result<(), EvalError> {
        if self.eat_sym(sym) {
            Ok(())
        } else {
            Err(EvalError::Parse(format!("expected `{sym}` at token {}", self.pos)))
        }
    }

    fn expr(&mut self) -> Result<Expr, EvalError> {
        self.or_level()
    }

    fn binary_level(
        &mut self,
        ops: &[&'static str],
        next: fn(&mut Parser) -> Result<Expr, EvalError>,
    ) -> Result<Expr, EvalError> {
        let mut lhs = next(self)?;
        loop {
            let op = match self.peek() {
                Some(Tok::Sym(s)) if ops.contains(s) => *s,
                _ => break,
            };
            self.pos += 1;
            let rhs = next(self)?;
            lhs = Expr::Bin(op, Box::new(lhs), Box::new(rhs));
        }
        Ok(lhs)
    }

    fn or_level(&mut self) -> Result<Expr, EvalError> {
        self.binary_level(&["||"], |p| p.and_level())
    }

    fn and_level(&mut self) -> Result<Expr, EvalError> {
        self.binary_level(&["&&"], |p| p.eq_level())
    }

    fn eq_level(&mut self) -> Result<Expr, EvalError> {
        self.binary_level(&["==", "!="], |p| p.cmp_level())
    }

    fn cmp_level(&mut self) -> Result<Expr, EvalError> {
        self.binary_level(&["<", "<=", ">", ">="], |p| p.add_level())
    }

    fn add_level(&mut self) -> Result<Expr, EvalError> {
        self.binary_level(&["+", "-"], |p| p.mul_level())
    }

    fn mul_level(&mut self) -> Result<Expr, EvalError> {
        self.binary_level(&["*", "/", "%"], |p| p.unary())
    }

    fn unary(&mut self) -> Result<Expr, EvalError> {
        if self.eat_sym("-") {
            Ok(Expr::Neg(Box::new(self.unary()?)))
        } else if self.eat_sym("!") {
            Ok(Expr::Not(Box::new(self.unary()?)))
        } else {
            self.atom()
        }
    }

    fn atom(&mut self) -> Result<Expr, EvalError> {
        match self.bump() {
            Some(Tok::Int(v)) => Ok(Expr::Int(v)),
            Some(Tok::True) => Ok(Expr::Bool(true)),
            Some(Tok::False) => Ok(Expr::Bool(false)),
            Some(Tok::Ident(name)) => Ok(Expr::Var(name)),
            Some(Tok::Sym("(")) => {
                let inner = self.expr()?;
                self.expect_sym(")")?;
                Ok(inner)
            }
            Some(other) => Err(EvalError::Parse(format!("unexpected token {other:?}"))),
            None => Err(EvalError::Parse("unexpected end of input".into())),
        }
    }
}

fn eval(expr: &Expr, env: &HashMap<String, Value>) -> Result<Value, EvalError> {
    match expr {
        Expr::Int(v) => Ok(Value::Int(*v)),
        Expr::Bool(b) => Ok(Value::Bool(*b)),
        Expr::Var(name) => env
            .get(name)
            .cloned()
            .ok_or_else(|| EvalError::UndefinedVar(name.clone())),
        Expr::Neg(inner) => match eval(inner, env)? {
            Value::Int(v) => Ok(Value::Int(v.wrapping_neg())),
            Value::Bool(_) => Err(EvalError::TypeMismatch("unary `-` needs an int".into())),
        },
        Expr::Not(inner) => match eval(inner, env)? {
            Value::Bool(b) => Ok(Value::Bool(!b)),
            Value::Int(_) => Err(EvalError::TypeMismatch("`!` needs a bool".into())),
        },
        Expr::Bin(op, lhs, rhs) => {
            // Short-circuit forms first.
            if *op == "&&" || *op == "||" {
                let l = match eval(lhs, env)? {
                    Value::Bool(b) => b,
                    Value::Int(_) => {
                        return Err(EvalError::TypeMismatch(format!("`{op}` needs bools")))
                    }
                };
                if *op == "&&" && !l {
                    return Ok(Value::Bool(false));
                }
                if *op == "||" && l {
                    return Ok(Value::Bool(true));
                }
                return match eval(rhs, env)? {
                    Value::Bool(b) => Ok(Value::Bool(b)),
                    Value::Int(_) => Err(EvalError::TypeMismatch(format!("`{op}` needs bools"))),
                };
            }
            let l = eval(lhs, env)?;
            let r = eval(rhs, env)?;
            match *op {
                "==" | "!=" => {
                    let equal = match (&l, &r) {
                        (Value::Int(a), Value::Int(b)) => a == b,
                        (Value::Bool(a), Value::Bool(b)) => a == b,
                        _ => {
                            return Err(EvalError::TypeMismatch(
                                "`==`/`!=` need matching types".into(),
                            ))
                        }
                    };
                    Ok(Value::Bool(if *op == "==" { equal } else { !equal }))
                }
                "<" | "<=" | ">" | ">=" => match (&l, &r) {
                    (Value::Int(a), Value::Int(b)) => Ok(Value::Bool(match *op {
                        "<" => a < b,
                        "<=" => a <= b,
                        ">" => a > b,
                        _ => a >= b,
                    })),
                    _ => Err(EvalError::TypeMismatch("comparisons need ints".into())),
                },
                "+" | "-" | "*" | "/" | "%" => match (&l, &r) {
                    (Value::Int(a), Value::Int(b)) => {
                        let v = match *op {
                            "+" => a.wrapping_add(*b),
                            "-" => a.wrapping_sub(*b),
                            "*" => a.wrapping_mul(*b),
                            "/" => {
                                if *b == 0 {
                                    return Err(EvalError::DivisionByZero);
                                }
                                a.wrapping_div(*b)
                            }
                            _ => {
                                if *b == 0 {
                                    return Err(EvalError::DivisionByZero);
                                }
                                a.wrapping_rem(*b)
                            }
                        };
                        Ok(Value::Int(v))
                    }
                    _ => Err(EvalError::TypeMismatch("arithmetic needs ints".into())),
                },
                other => Err(EvalError::Parse(format!("unknown operator `{other}`"))),
            }
        }
    }
}

/// Evaluate a program: `{ ident "=" expr ";" } expr [";"]`.
pub fn eval_program(src: &str) -> Result<Value, EvalError> {
    let toks = lex(src)?;
    let mut parser = Parser { toks, pos: 0 };
    let mut statements: Vec<(String, Expr)> = Vec::new();
    loop {
        let is_assign = matches!(parser.peek(), Some(Tok::Ident(_)))
            && matches!(parser.peek2(), Some(Tok::Sym("=")));
        if !is_assign {
            break;
        }
        let Some(Tok::Ident(name)) = parser.bump() else { unreachable!() };
        parser.expect_sym("=")?;
        let rhs = parser.expr()?;
        parser.expect_sym(";")?;
        statements.push((name, rhs));
    }
    if parser.peek().is_none() {
        return Err(EvalError::Parse("expected a final expression".into()));
    }
    let final_expr = parser.expr()?;
    let _ = parser.eat_sym(";");
    if parser.peek().is_some() {
        return Err(EvalError::Parse(format!("trailing tokens at {}", parser.pos)));
    }

    let mut env: HashMap<String, Value> = HashMap::new();
    for (name, rhs) in &statements {
        let value = eval(rhs, &env)?;
        env.insert(name.clone(), value);
    }
    eval(&final_expr, &env)
}
