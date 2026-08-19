//! Flatten a JSON object into dotted-path keys, std-only (no serde).

use std::collections::BTreeMap;

enum Value {
    Object(Vec<(String, Value)>),
    Array(Vec<Value>),
    Str(String),
    NumberToken(String),
    Bool(bool),
    Null,
}

struct Parser<'a> {
    bytes: &'a [u8],
    pos: usize,
}

impl<'a> Parser<'a> {
    fn new(src: &'a str) -> Self {
        Parser { bytes: src.as_bytes(), pos: 0 }
    }

    fn skip_ws(&mut self) {
        while let Some(&b) = self.bytes.get(self.pos) {
            if b == b' ' || b == b'\t' || b == b'\r' || b == b'\n' {
                self.pos += 1;
            } else {
                break;
            }
        }
    }

    fn peek(&self) -> Option<u8> {
        self.bytes.get(self.pos).copied()
    }

    fn expect(&mut self, b: u8) -> Result<(), String> {
        if self.peek() == Some(b) {
            self.pos += 1;
            Ok(())
        } else {
            Err(format!("expected `{}` at byte {}", b as char, self.pos))
        }
    }

    fn value(&mut self) -> Result<Value, String> {
        self.skip_ws();
        match self.peek() {
            Some(b'{') => self.object(),
            Some(b'[') => self.array(),
            Some(b'"') => Ok(Value::Str(self.string()?)),
            Some(b'-') | Some(b'0'..=b'9') => self.number(),
            Some(b't') => self.literal("true", Value::Bool(true)),
            Some(b'f') => self.literal("false", Value::Bool(false)),
            Some(b'n') => self.literal("null", Value::Null),
            _ => Err(format!("unexpected input at byte {}", self.pos)),
        }
    }

    fn literal(&mut self, word: &str, value: Value) -> Result<Value, String> {
        if self.bytes[self.pos..].starts_with(word.as_bytes()) {
            self.pos += word.len();
            Ok(value)
        } else {
            Err(format!("bad literal at byte {}", self.pos))
        }
    }

    fn object(&mut self) -> Result<Value, String> {
        self.expect(b'{')?;
        let mut members = Vec::new();
        self.skip_ws();
        if self.peek() == Some(b'}') {
            self.pos += 1;
            return Ok(Value::Object(members));
        }
        loop {
            self.skip_ws();
            let key = self.string()?;
            self.skip_ws();
            self.expect(b':')?;
            let value = self.value()?;
            members.push((key, value));
            self.skip_ws();
            match self.peek() {
                Some(b',') => self.pos += 1,
                Some(b'}') => {
                    self.pos += 1;
                    return Ok(Value::Object(members));
                }
                _ => return Err(format!("expected `,` or `}}` at byte {}", self.pos)),
            }
        }
    }

    fn array(&mut self) -> Result<Value, String> {
        self.expect(b'[')?;
        let mut items = Vec::new();
        self.skip_ws();
        if self.peek() == Some(b']') {
            self.pos += 1;
            return Ok(Value::Array(items));
        }
        loop {
            items.push(self.value()?);
            self.skip_ws();
            match self.peek() {
                Some(b',') => self.pos += 1,
                Some(b']') => {
                    self.pos += 1;
                    return Ok(Value::Array(items));
                }
                _ => return Err(format!("expected `,` or `]` at byte {}", self.pos)),
            }
        }
    }

    fn string(&mut self) -> Result<String, String> {
        self.expect(b'"')?;
        let mut out = String::new();
        loop {
            match self.peek() {
                None => return Err("unterminated string".into()),
                Some(b'"') => {
                    self.pos += 1;
                    return Ok(out);
                }
                Some(b'\\') => {
                    self.pos += 1;
                    let esc = self.peek().ok_or("dangling escape")?;
                    self.pos += 1;
                    out.push(match esc {
                        b'"' => '"',
                        b'\\' => '\\',
                        b'/' => '/',
                        b'n' => '\n',
                        b't' => '\t',
                        other => return Err(format!("bad escape `\\{}`", other as char)),
                    });
                }
                Some(_) => {
                    // Consume one full UTF-8 character.
                    let rest = std::str::from_utf8(&self.bytes[self.pos..])
                        .map_err(|_| "invalid utf-8".to_string())?;
                    let ch = rest.chars().next().unwrap();
                    out.push(ch);
                    self.pos += ch.len_utf8();
                }
            }
        }
    }

    fn number(&mut self) -> Result<Value, String> {
        let start = self.pos;
        if self.peek() == Some(b'-') {
            self.pos += 1;
        }
        let digits_start = self.pos;
        while matches!(self.peek(), Some(b'0'..=b'9')) {
            self.pos += 1;
        }
        if self.pos == digits_start {
            return Err(format!("bad number at byte {start}"));
        }
        if self.peek() == Some(b'.') {
            self.pos += 1;
            let frac_start = self.pos;
            while matches!(self.peek(), Some(b'0'..=b'9')) {
                self.pos += 1;
            }
            if self.pos == frac_start {
                return Err(format!("bad number at byte {start}"));
            }
        }
        if matches!(self.peek(), Some(b'e') | Some(b'E')) {
            self.pos += 1;
            if matches!(self.peek(), Some(b'+') | Some(b'-')) {
                self.pos += 1;
            }
            let exp_start = self.pos;
            while matches!(self.peek(), Some(b'0'..=b'9')) {
                self.pos += 1;
            }
            if self.pos == exp_start {
                return Err(format!("bad number at byte {start}"));
            }
        }
        let token = std::str::from_utf8(&self.bytes[start..self.pos]).unwrap();
        Ok(Value::NumberToken(token.to_string()))
    }
}

fn walk(value: &Value, path: &str, out: &mut BTreeMap<String, String>) {
    match value {
        Value::Object(members) => {
            for (key, child) in members {
                let sub = if path.is_empty() { key.clone() } else { format!("{path}.{key}") };
                walk(child, &sub, out);
            }
        }
        Value::Array(items) => {
            for (idx, child) in items.iter().enumerate() {
                let sub = if path.is_empty() { idx.to_string() } else { format!("{path}.{idx}") };
                walk(child, &sub, out);
            }
        }
        Value::Str(s) => {
            out.insert(path.to_string(), s.clone());
        }
        Value::NumberToken(t) => {
            out.insert(path.to_string(), t.clone());
        }
        Value::Bool(b) => {
            out.insert(path.to_string(), b.to_string());
        }
        Value::Null => {
            out.insert(path.to_string(), "null".to_string());
        }
    }
}

/// Flatten the JSON object in `input`.
pub fn flatten(input: &str) -> Result<BTreeMap<String, String>, String> {
    let mut parser = Parser::new(input);
    parser.skip_ws();
    if parser.peek() != Some(b'{') {
        return Err("top-level value must be an object".into());
    }
    let root = parser.value()?;
    parser.skip_ws();
    if parser.pos != parser.bytes.len() {
        return Err(format!("trailing content at byte {}", parser.pos));
    }
    let mut out = BTreeMap::new();
    walk(&root, "", &mut out);
    Ok(out)
}
