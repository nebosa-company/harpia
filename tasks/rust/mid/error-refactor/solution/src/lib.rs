//! Server-config parsing with structured errors; the historical panicking
//! entry points delegate to the fallible ones.

/// Parsed server configuration.
#[derive(Debug, PartialEq, Clone)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub workers: u32,
    pub debug: bool,
}

/// Everything that can be wrong with a config document.
#[derive(Debug, PartialEq)]
pub enum ConfigError {
    /// A required key ("host" or "port") is absent.
    Missing(&'static str),
    /// An unrecognized key (trimmed).
    UnknownKey(String),
    /// Port text that does not parse as u16 (trimmed).
    InvalidPort(String),
    /// Workers text that does not parse as u32 (trimmed).
    InvalidWorkers(String),
    /// Bool text that is not true/false/1/0 case-insensitive (trimmed).
    InvalidBool(String),
    /// A non-comment, non-blank line without '=' (1-based).
    BadLine(usize),
}

impl std::fmt::Display for ConfigError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ConfigError::Missing(k) => write!(f, "missing required key `{k}`"),
            ConfigError::UnknownKey(k) => write!(f, "unknown key `{k}`"),
            ConfigError::InvalidPort(s) => write!(f, "invalid port `{s}`"),
            ConfigError::InvalidWorkers(s) => write!(f, "invalid workers `{s}`"),
            ConfigError::InvalidBool(s) => write!(f, "invalid bool `{s}`"),
            ConfigError::BadLine(n) => write!(f, "malformed line {n}"),
        }
    }
}

impl std::error::Error for ConfigError {}

/// Fallible config parsing; same rules as `parse_config`.
pub fn try_parse_config(src: &str) -> Result<ServerConfig, ConfigError> {
    let mut host: Option<String> = None;
    let mut port: Option<u16> = None;
    let mut workers: u32 = 4;
    let mut debug = false;
    for (idx, raw) in src.lines().enumerate() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let Some((key, value)) = line.split_once('=') else {
            return Err(ConfigError::BadLine(idx + 1));
        };
        let (key, value) = (key.trim(), value.trim());
        match key {
            "host" => host = Some(value.to_string()),
            "port" => port = Some(try_parse_port(value)?),
            "workers" => {
                workers = value
                    .parse()
                    .map_err(|_| ConfigError::InvalidWorkers(value.to_string()))?;
            }
            "debug" => debug = try_parse_bool(value)?,
            other => return Err(ConfigError::UnknownKey(other.to_string())),
        }
    }
    Ok(ServerConfig {
        host: host.ok_or(ConfigError::Missing("host"))?,
        port: port.ok_or(ConfigError::Missing("port"))?,
        workers,
        debug,
    })
}

/// Fallible port parsing.
pub fn try_parse_port(s: &str) -> Result<u16, ConfigError> {
    let t = s.trim();
    t.parse().map_err(|_| ConfigError::InvalidPort(t.to_string()))
}

/// Fallible bool parsing: true/false/1/0, case-insensitive.
pub fn try_parse_bool(s: &str) -> Result<bool, ConfigError> {
    let t = s.trim();
    match t.to_ascii_lowercase().as_str() {
        "true" | "1" => Ok(true),
        "false" | "0" => Ok(false),
        _ => Err(ConfigError::InvalidBool(t.to_string())),
    }
}

/// Parse `key = value` lines into a config. Panics on any invalid input.
pub fn parse_config(src: &str) -> ServerConfig {
    try_parse_config(src).unwrap_or_else(|e| panic!("{e}"))
}

/// Parse a TCP port. Panics when the text is not a valid port number.
pub fn parse_port(s: &str) -> u16 {
    try_parse_port(s).unwrap_or_else(|e| panic!("{e}"))
}

/// Parse a boolean flag: true/false/1/0, case-insensitive. Panics otherwise.
pub fn parse_bool(s: &str) -> bool {
    try_parse_bool(s).unwrap_or_else(|e| panic!("{e}"))
}
