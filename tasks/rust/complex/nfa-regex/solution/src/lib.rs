//! An anchored regex subset compiled to a Thompson NFA and simulated with
//! state sets (linear time, no backtracking).

/// Compile-time pattern errors.
#[derive(Debug, PartialEq)]
pub enum RegexError {
    /// Unclosed '(' or stray ')'.
    UnbalancedParen,
    /// Quantifier with no atom before it.
    DanglingQuantifier,
    /// Unterminated class or reversed range.
    BadClass,
    /// Backslash before an unsupported character, or trailing backslash.
    BadEscape,
}

// ---------------------------------------------------------------- AST ----

#[derive(Debug, Clone)]
enum Ast {
    Empty,
    Char(char),
    Any,
    Class { negated: bool, chars: Vec<char>, ranges: Vec<(char, char)> },
    Concat(Vec<Ast>),
    Alt(Vec<Ast>),
    Star(Box<Ast>),
    Plus(Box<Ast>),
    Opt(Box<Ast>),
}

struct Parser {
    chars: Vec<char>,
    pos: usize,
}

const ESCAPABLE: &[char] = &['.', '*', '+', '?', '|', '(', ')', '[', ']', '\\'];

impl Parser {
    fn peek(&self) -> Option<char> {
        self.chars.get(self.pos).copied()
    }

    fn bump(&mut self) -> Option<char> {
        let c = self.peek();
        if c.is_some() {
            self.pos += 1;
        }
        c
    }

    fn alt(&mut self) -> Result<Ast, RegexError> {
        let mut branches = vec![self.concat()?];
        while self.peek() == Some('|') {
            self.pos += 1;
            branches.push(self.concat()?);
        }
        Ok(if branches.len() == 1 { branches.pop().unwrap() } else { Ast::Alt(branches) })
    }

    fn concat(&mut self) -> Result<Ast, RegexError> {
        let mut items: Vec<Ast> = Vec::new();
        loop {
            match self.peek() {
                None | Some('|') | Some(')') => break,
                Some('*') | Some('+') | Some('?') => return Err(RegexError::DanglingQuantifier),
                Some(_) => {
                    let atom = self.atom()?;
                    let wrapped = match self.peek() {
                        Some('*') => {
                            self.pos += 1;
                            Ast::Star(Box::new(atom))
                        }
                        Some('+') => {
                            self.pos += 1;
                            Ast::Plus(Box::new(atom))
                        }
                        Some('?') => {
                            self.pos += 1;
                            Ast::Opt(Box::new(atom))
                        }
                        _ => atom,
                    };
                    if matches!(self.peek(), Some('*') | Some('+') | Some('?'))
                        && !matches!(wrapped, Ast::Char(_) | Ast::Any | Ast::Class { .. })
                    {
                        // a quantifier directly following a quantified atom
                        return Err(RegexError::DanglingQuantifier);
                    }
                    if matches!(self.peek(), Some('*') | Some('+') | Some('?'))
                        && matches!(
                            wrapped,
                            Ast::Star(_) | Ast::Plus(_) | Ast::Opt(_)
                        )
                    {
                        return Err(RegexError::DanglingQuantifier);
                    }
                    items.push(wrapped);
                }
            }
        }
        Ok(match items.len() {
            0 => Ast::Empty,
            1 => items.pop().unwrap(),
            _ => Ast::Concat(items),
        })
    }

    fn atom(&mut self) -> Result<Ast, RegexError> {
        match self.bump() {
            Some('(') => {
                let inner = self.alt()?;
                if self.bump() != Some(')') {
                    return Err(RegexError::UnbalancedParen);
                }
                Ok(inner)
            }
            Some('.') => Ok(Ast::Any),
            Some('[') => self.class(),
            Some('\\') => match self.bump() {
                Some(c) if ESCAPABLE.contains(&c) => Ok(Ast::Char(c)),
                _ => Err(RegexError::BadEscape),
            },
            Some(c) => Ok(Ast::Char(c)),
            None => Err(RegexError::UnbalancedParen), // unreachable via concat
        }
    }

    fn class(&mut self) -> Result<Ast, RegexError> {
        let negated = self.peek() == Some('^');
        if negated {
            self.pos += 1;
        }
        let mut chars = Vec::new();
        let mut ranges = Vec::new();
        let mut first = true;
        loop {
            let Some(c) = self.peek() else {
                return Err(RegexError::BadClass);
            };
            if c == ']' && !first {
                self.pos += 1;
                break;
            }
            first = false;
            // Range c-x, where '-' is not the last class char.
            if self.chars.get(self.pos + 1) == Some(&'-')
                && self
                    .chars
                    .get(self.pos + 2)
                    .is_some_and(|&x| x != ']')
            {
                let lo = c;
                let hi = self.chars[self.pos + 2];
                if hi < lo {
                    return Err(RegexError::BadClass);
                }
                ranges.push((lo, hi));
                self.pos += 3;
            } else {
                chars.push(c);
                self.pos += 1;
            }
        }
        Ok(Ast::Class { negated, chars, ranges })
    }
}

// ---------------------------------------------------------------- NFA ----

#[derive(Debug, Clone)]
enum Trans {
    Char(char),
    Any,
    Class { negated: bool, chars: Vec<char>, ranges: Vec<(char, char)> },
}

impl Trans {
    fn matches(&self, c: char) -> bool {
        match self {
            Trans::Char(l) => *l == c,
            Trans::Any => true,
            Trans::Class { negated, chars, ranges } => {
                let inside =
                    chars.contains(&c) || ranges.iter().any(|&(lo, hi)| lo <= c && c <= hi);
                inside != *negated
            }
        }
    }
}

#[derive(Default)]
struct State {
    edges: Vec<(Trans, usize)>,
    eps: Vec<usize>,
}

/// A compiled pattern. `is_match` is anchored: the whole text must match.
pub struct Regex {
    states: Vec<State>,
    start: usize,
    accept: usize,
}

impl Regex {
    fn add_state(states: &mut Vec<State>) -> usize {
        states.push(State::default());
        states.len() - 1
    }

    /// Build a fragment for `ast`; returns (entry, exit).
    fn build(ast: &Ast, states: &mut Vec<State>) -> (usize, usize) {
        match ast {
            Ast::Empty => {
                let s = Self::add_state(states);
                let e = Self::add_state(states);
                states[s].eps.push(e);
                (s, e)
            }
            Ast::Char(c) => {
                let s = Self::add_state(states);
                let e = Self::add_state(states);
                states[s].edges.push((Trans::Char(*c), e));
                (s, e)
            }
            Ast::Any => {
                let s = Self::add_state(states);
                let e = Self::add_state(states);
                states[s].edges.push((Trans::Any, e));
                (s, e)
            }
            Ast::Class { negated, chars, ranges } => {
                let s = Self::add_state(states);
                let e = Self::add_state(states);
                states[s].edges.push((
                    Trans::Class {
                        negated: *negated,
                        chars: chars.clone(),
                        ranges: ranges.clone(),
                    },
                    e,
                ));
                (s, e)
            }
            Ast::Concat(items) => {
                let mut entry = None;
                let mut last_exit = None;
                for item in items {
                    let (s, e) = Self::build(item, states);
                    if let Some(prev) = last_exit {
                        let prev: usize = prev;
                        states[prev].eps.push(s);
                    } else {
                        entry = Some(s);
                    }
                    last_exit = Some(e);
                }
                (entry.unwrap(), last_exit.unwrap())
            }
            Ast::Alt(branches) => {
                let s = Self::add_state(states);
                let e = Self::add_state(states);
                for branch in branches {
                    let (bs, be) = Self::build(branch, states);
                    states[s].eps.push(bs);
                    states[be].eps.push(e);
                }
                (s, e)
            }
            Ast::Star(inner) => {
                let s = Self::add_state(states);
                let e = Self::add_state(states);
                let (is, ie) = Self::build(inner, states);
                states[s].eps.push(is);
                states[s].eps.push(e);
                states[ie].eps.push(is);
                states[ie].eps.push(e);
                (s, e)
            }
            Ast::Plus(inner) => {
                let s = Self::add_state(states);
                let e = Self::add_state(states);
                let (is, ie) = Self::build(inner, states);
                states[s].eps.push(is);
                states[ie].eps.push(is);
                states[ie].eps.push(e);
                (s, e)
            }
            Ast::Opt(inner) => {
                let s = Self::add_state(states);
                let e = Self::add_state(states);
                let (is, ie) = Self::build(inner, states);
                states[s].eps.push(is);
                states[s].eps.push(e);
                states[ie].eps.push(e);
                (s, e)
            }
        }
    }

    /// Compile `pattern` into an NFA.
    pub fn compile(pattern: &str) -> Result<Regex, RegexError> {
        let mut parser = Parser { chars: pattern.chars().collect(), pos: 0 };
        let ast = parser.alt()?;
        if parser.pos != parser.chars.len() {
            // concat/alt only stop early on ')'
            return Err(RegexError::UnbalancedParen);
        }
        let mut states = Vec::new();
        let (start, accept) = Self::build(&ast, &mut states);
        Ok(Regex { states, start, accept })
    }

    fn eps_closure(&self, set: &mut Vec<bool>, stack: &mut Vec<usize>) {
        while let Some(s) = stack.pop() {
            for &n in &self.states[s].eps {
                if !set[n] {
                    set[n] = true;
                    stack.push(n);
                }
            }
        }
    }

    /// Whether the ENTIRE `text` matches the pattern.
    pub fn is_match(&self, text: &str) -> bool {
        let mut current = vec![false; self.states.len()];
        let mut stack = vec![self.start];
        current[self.start] = true;
        self.eps_closure(&mut current, &mut stack);
        for c in text.chars() {
            let mut next = vec![false; self.states.len()];
            let mut stack = Vec::new();
            for (idx, active) in current.iter().enumerate() {
                if !active {
                    continue;
                }
                for (trans, to) in &self.states[idx].edges {
                    if trans.matches(c) && !next[*to] {
                        next[*to] = true;
                        stack.push(*to);
                    }
                }
            }
            self.eps_closure(&mut next, &mut stack);
            current = next;
        }
        current[self.accept]
    }
}
